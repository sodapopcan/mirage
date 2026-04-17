defmodule HoloTest do
  @moduledoc """
  Test framework for the Hologram web framework.

  The entry point is `visit/2`, which initializes a page and expands its
  template into a fully-resolved DOM that tests can make assertions against.
  """

  defmodule Session do
    @moduledoc """
    Represents a test session — the state of a page after a `HoloTest.visit/2`.
    """

    alias Hologram.Component
    alias Hologram.Server

    defstruct [:page, :server, :ast, :page_module]

    @type t :: %__MODULE__{
            page: Component.t(),
            server: Server.t(),
            ast: any(),
            page_module: module()
          }
  end

  alias Hologram.Component
  alias Hologram.Page
  alias Hologram.Server
  alias HoloTest.DOM
  alias HoloTest.Session

  @doc """
  Visits a Hologram page module and returns a `HoloTest.Session` containing
  the initialized page struct and the expanded, layout-wrapped DOM.
  """
  @spec visit(Page.t(), %{atom() => any()}) :: Session.t()
  def visit(page_module, params \\ %{}) do
    {page, server} = DOM.init_component(page_module, params, %Server{})

    vars = Map.merge(params, page.state)
    page_dom = page_module.template().(vars)

    layout_props_dom =
      page_module.__layout_props__()
      |> Enum.into(%{cid: "layout"})
      |> Map.merge(page.state)
      |> Enum.map(fn {name, value} -> {to_string(name), [expression: {value}]} end)

    root = {:component, page_module.__layout_module__(), layout_props_dom, page_dom}
    env = %{context: page.emitted_context, slots: []}
    ast = DOM.expand(root, env, server)

    %Session{page: page, server: server, ast: ast, page_module: page_module}
  end

  @doc """
  Finds and "clicks" an element that has a `$click` attribute and whose inner
  text (with all descendant tags stripped) matches `text`.

  If the click triggers a page navigation (`Hologram.UI.Link`), the session
  is replaced with one for the linked page. If the click's action emits a
  command, that command is executed server-side before returning.

  Matches exactly by default; pass `exact: false` to match substrings instead.
  Raises if no matching clickable element is found, or if more than one
  matches (ambiguous match).
  """
  @spec click(Session.t(), String.t(), keyword()) :: Session.t()
  def click(session, text, opts \\ []) do
    exact? = Keyword.get(opts, :exact, true)

    case find_clickables(session.ast, text, exact?) do
      [] ->
        raise "No clickable element found with text: #{inspect(text)}"

      [node] ->
        handle_click(session, node)

      [_ | _] = nodes ->
        raise "Ambiguous match: found #{length(nodes)} clickable elements with text: #{inspect(text)}"
    end
  end

  defp find_clickables(nodes, text, exact?) when is_list(nodes) do
    Enum.flat_map(nodes, &find_clickables(&1, text, exact?))
  end

  defp find_clickables({:element, _tag, attrs, children} = node, text, exact?) do
    nested = find_clickables(children, text, exact?)

    if has_click_attr?(attrs) and text_matches?(inner_text(node), text, exact?) do
      [node | nested]
    else
      nested
    end
  end

  defp find_clickables(_other, _text, _exact?), do: []

  defp has_click_attr?(attrs) do
    Enum.any?(attrs, fn
      {"$click", _value} -> true
      _ -> false
    end)
  end

  defp inner_text(node) do
    case node do
      {:element, _tag, _attrs, children} -> inner_text(children)
      {:text, text} -> text
      nodes when is_list(nodes) -> Enum.map_join(nodes, "", &inner_text/1)
      _ -> ""
    end
  end

  defp text_matches?(actual, expected, true), do: String.trim(actual) == expected
  defp text_matches?(actual, expected, false), do: String.contains?(actual, expected)

  defp handle_click(session, {:element, _tag, attrs, _children}) do
    # Hologram.UI.Link expands `$click={:__load_prefetched_page__, to: @to}` —
    # in the resolved AST that shows up as `[expression: {:__load_prefetched_page__, [to: Target]}]`.
    case find_attr(attrs, "$click") do
      [{:expression, {:__load_prefetched_page__, params}}] when is_list(params) ->
        visit(Keyword.fetch!(params, :to))

      value ->
        dispatch_action(session, value, %{})
    end
  end

  @doc """
  Finds an input by its associated label and triggers the input's `$change`
  and (if the input is inside a `<form>` with a `$change` attribute) the
  form's `$change` action. Each action receives `%{value: value}` merged
  into any params declared on the attribute itself; keys declared in `with:`
  win on conflict.

  Labels may be associated with their input either by wrapping the input
  (`<label>Name <input/></label>`) or via a `for` attribute matching the
  input's `id`.

  Matches exactly by default; pass `exact: false` to match substrings.
  Raises if no matching label is found, or if more than one matches.
  """
  @spec fill_in(Session.t(), String.t(), keyword()) :: Session.t()
  def fill_in(session, label, opts) do
    exact? = Keyword.get(opts, :exact, true)
    value = Keyword.fetch!(opts, :with)

    {labels, inputs_by_id} = collect_form_nodes(session.ast, nil)

    matches =
      Enum.filter(labels, fn {node, _wrapped, _form_change} ->
        text_matches?(inner_text(node), label, exact?)
      end)

    case matches do
      [] ->
        raise "No input found with label: #{inspect(label)}"

      [entry] ->
        {input, form_change} = resolve_input(entry, inputs_by_id, label)

        session
        |> trigger_input_action(input, value)
        |> trigger_form_change(form_change, value)

      [_ | _] = many ->
        raise "Ambiguous match: found #{length(many)} labels matching: #{inspect(label)}"
    end
  end

  @doc """
  Asserts that the session's DOM contains a matching node.

  Text is passed as the second argument; for value matching pass
  `value:` as an option instead:

      session |> assert_has("Hello")
      session |> assert_has("Item 1", at: 1)
      session |> assert_has(value: "alice", at: 1)

  Pass `:at` (1-based) to select the nth element in document order and assert
  that it has the expected text or value. This verifies ordering — e.g.
  `assert_has("A", at: 1) |> assert_has("B", at: 2)` proves "A" appears
  before "B" in the DOM.

  Without `:at`, the assertion passes when at least one match exists.
  """
  @spec assert_has(Session.t(), String.t() | keyword(), keyword()) :: Session.t()
  def assert_has(session, text_or_opts, opts \\ [])

  def assert_has(%Session{} = session, text, opts) when is_binary(text) do
    if Keyword.has_key?(opts, :value) do
      raise ArgumentError, "assert_has/3 accepts text or :value, not both"
    end

    assert_text(session.ast, text, Keyword.get(opts, :at))
    session
  end

  def assert_has(%Session{} = session, opts, []) when is_list(opts) do
    value = Keyword.get(opts, :value)
    at = Keyword.get(opts, :at)

    if is_nil(value) do
      raise ArgumentError, "assert_has/2 requires text or :value"
    end

    assert_value(session.ast, value, at)
    session
  end

  @doc """
  The opposite of `assert_has` — asserts that the session's DOM does *not*
  contain a matching node. Accepts the same arguments.
  """
  @spec refute_has(Session.t(), String.t() | keyword(), keyword()) :: Session.t()
  def refute_has(session, text_or_opts, opts \\ [])

  def refute_has(%Session{} = session, text, opts) when is_binary(text) do
    if Keyword.has_key?(opts, :value) do
      raise ArgumentError, "refute_has/3 accepts text or :value, not both"
    end

    refute_text(session.ast, text, Keyword.get(opts, :at))
    session
  end

  def refute_has(%Session{} = session, opts, []) when is_list(opts) do
    value = Keyword.get(opts, :value)
    at = Keyword.get(opts, :at)

    if is_nil(value) do
      raise ArgumentError, "refute_has/2 requires text or :value"
    end

    refute_value(session.ast, value, at)
    session
  end

  defp assert_text(ast, text, nil) do
    if collect_elements(ast) |> Enum.all?(&(String.trim(inner_text(&1)) != text)) do
      raise "No element found with text: #{inspect(text)}"
    end
  end

  defp assert_text(ast, text, at) when is_integer(at) do
    elements = collect_elements(ast)
    count = length(elements)

    if at < 1 or at > count do
      raise "Expected element at position #{at} but only found #{count} elements"
    end

    element = Enum.at(elements, at - 1)
    actual = String.trim(inner_text(element))

    if actual != text do
      raise "Expected element at position #{at} to have text #{inspect(text)} but found #{inspect(actual)}"
    end
  end

  defp assert_value(ast, value, nil) do
    if collect_inputs(ast) |> Enum.all?(&(input_value(&1) != value)) do
      raise "No element found with value: #{inspect(value)}"
    end
  end

  defp assert_value(ast, value, at) when is_integer(at) do
    inputs = collect_inputs(ast)
    count = length(inputs)

    if at < 1 or at > count do
      raise "Expected input at position #{at} but only found #{count} inputs"
    end

    actual = input_value(Enum.at(inputs, at - 1))

    if actual != value do
      raise "Expected input at position #{at} to have value #{inspect(value)} but found #{inspect(actual)}"
    end
  end

  defp refute_text(ast, text, nil) do
    if collect_elements(ast) |> Enum.any?(&(String.trim(inner_text(&1)) == text)) do
      raise "Expected no element with text: #{inspect(text)}"
    end
  end

  defp refute_text(ast, text, at) when is_integer(at) do
    elements = collect_elements(ast)
    count = length(elements)

    if at >= 1 and at <= count do
      actual = String.trim(inner_text(Enum.at(elements, at - 1)))

      if actual == text do
        raise "Expected element at position #{at} not to have text #{inspect(text)}"
      end
    end
  end

  defp refute_value(ast, value, nil) do
    if collect_inputs(ast) |> Enum.any?(&(input_value(&1) == value)) do
      raise "Expected no input with value: #{inspect(value)}"
    end
  end

  defp refute_value(ast, value, at) when is_integer(at) do
    inputs = collect_inputs(ast)
    count = length(inputs)

    if at >= 1 and at <= count do
      actual = input_value(Enum.at(inputs, at - 1))

      if actual == value do
        raise "Expected input at position #{at} not to have value #{inspect(value)}"
      end
    end
  end

  defp input_value({:element, _tag, attrs, _children}) do
    attr_to_string(find_attr(attrs, "value"))
  end

  defp collect_elements(nodes) when is_list(nodes) do
    Enum.flat_map(nodes, &collect_elements/1)
  end

  defp collect_elements({:element, _tag, _attrs, children} = node) do
    [node | collect_elements(children)]
  end

  defp collect_elements(_other), do: []

  defp collect_inputs(nodes) when is_list(nodes) do
    Enum.flat_map(nodes, &collect_inputs/1)
  end

  defp collect_inputs({:element, tag, _attrs, children} = node)
       when tag in ["input", "textarea", "select"] do
    [node | collect_inputs(children)]
  end

  defp collect_inputs({:element, _tag, _attrs, children}) do
    collect_inputs(children)
  end

  defp collect_inputs(_other), do: []

  # Walks the AST once, tracking the nearest enclosing `<form>`'s `$change`
  # attribute. Returns `{labels, inputs_by_id}` where:
  #   * labels = [{label_node, wrapped_input_or_nil, form_change_or_nil}, ...]
  #   * inputs_by_id = %{"id" => {input_node, form_change_or_nil}}
  defp collect_form_nodes(nodes, form_change) when is_list(nodes) do
    Enum.reduce(nodes, {[], %{}}, fn node, {labels, inputs} ->
      {l, i} = collect_form_nodes(node, form_change)
      {labels ++ l, Map.merge(inputs, i)}
    end)
  end

  defp collect_form_nodes({:element, "form", attrs, children}, _form_change) do
    collect_form_nodes(children, find_attr(attrs, "$change"))
  end

  defp collect_form_nodes({:element, "label", _attrs, children} = node, form_change) do
    {nested_labels, nested_inputs} = collect_form_nodes(children, form_change)
    wrapped = find_nested_input(children)
    {[{node, wrapped, form_change} | nested_labels], nested_inputs}
  end

  defp collect_form_nodes({:element, tag, attrs, children} = node, form_change)
       when tag in ["input", "textarea", "select"] do
    {nested_labels, nested_inputs} = collect_form_nodes(children, form_change)

    inputs =
      case find_attr(attrs, "id") do
        nil -> nested_inputs
        id -> Map.put(nested_inputs, attr_to_string(id), {node, form_change})
      end

    {nested_labels, inputs}
  end

  defp collect_form_nodes({:element, _tag, _attrs, children}, form_change) do
    collect_form_nodes(children, form_change)
  end

  defp collect_form_nodes(_other, _form_change), do: {[], %{}}

  defp find_nested_input(nodes) when is_list(nodes) do
    Enum.find_value(nodes, &find_nested_input/1)
  end

  defp find_nested_input({:element, tag, _attrs, _children} = node)
       when tag in ["input", "textarea", "select"],
       do: node

  defp find_nested_input({:element, _tag, _attrs, children}), do: find_nested_input(children)
  defp find_nested_input(_other), do: nil

  defp resolve_input({_label, {:element, _, _, _} = input, form_change}, _by_id, _label_text) do
    {input, form_change}
  end

  defp resolve_input({{:element, "label", attrs, _children}, nil, _fc}, by_id, label_text) do
    case find_attr(attrs, "for") do
      nil ->
        raise "Label #{inspect(label_text)} has no wrapped input and no `for` attribute"

      for_attr ->
        id = attr_to_string(for_attr)

        case Map.fetch(by_id, id) do
          {:ok, match} ->
            match

          :error ->
            raise "No input with id=#{inspect(id)} found for label #{inspect(label_text)}"
        end
    end
  end

  defp trigger_input_action(session, {:element, _tag, attrs, _children}, value) do
    case find_attr(attrs, "$change") do
      nil -> session
      action -> dispatch_action(session, action, %{value: value})
    end
  end

  defp trigger_form_change(session, nil, _value), do: session

  defp trigger_form_change(session, form_change, value) do
    dispatch_action(session, form_change, %{value: value})
  end

  # Action with params, e.g. `$click={:write_file, path: @tmp_path}`.
  defp dispatch_action(%Session{} = session, [{:expression, {name, params}}], extra)
       when is_atom(name) and is_list(params) do
    run_action(session, name, Map.merge(Map.new(params), extra))
  end

  # Bare atom action, e.g. `$click={:submit}` — evaluated as a 1-tuple.
  defp dispatch_action(%Session{} = session, [{:expression, {name}}], extra)
       when is_atom(name) do
    run_action(session, name, extra)
  end

  # Attribute values that aren't one of the known expression shapes (e.g.
  # a literal string like `$click="foo"`) are treated as no-ops.
  defp dispatch_action(session, _other, _extra), do: session

  defp find_attr(attrs, name) do
    case Enum.find(attrs, fn {n, _} -> n == name end) do
      {^name, value} -> value
      _ -> nil
    end
  end

  defp attr_to_string(value) when is_binary(value), do: value

  defp attr_to_string(parts) when is_list(parts) do
    Enum.map_join(parts, "", fn
      {:text, t} -> t
      {:expression, {v}} -> to_string(v)
      _ -> ""
    end)
  end

  defp attr_to_string(_other), do: ""

  defp run_action(
         %Session{page: component, page_module: page_module, server: server} = session,
         name,
         params
       ) do
    {new_component, new_server} =
      case page_module.action(name, params, component) do
        {%Component{} = component, %Server{} = server} -> {component, server}
        %Component{} = component -> {component, server}
        %Server{} = server -> {component, server}
      end

    # If the action emitted a command, run it server-side.
    if cmd = new_component.next_command do
      page_module.command(cmd.name, cmd.params, new_server)
    end

    %{session | page: new_component}
  end
end
