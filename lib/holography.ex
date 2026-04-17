defmodule Holography do
  @moduledoc """
  Test framework for the Hologram web framework.

  The entry point is `visit/2`, which initializes a page and expands its
  template into a fully-resolved DOM that tests can make assertions against.
  """

  defmodule Session do
    @moduledoc """
    State container for a test.
    """

    alias Hologram.Component
    alias Hologram.Server

    defstruct [:page, :server, :ast, :page_module, :params]

    @type t :: %__MODULE__{
            page: Component.t(),
            server: Server.t(),
            ast: any(),
            page_module: module(),
            params: %{atom() => any()}
          }
  end

  alias Hologram.Component
  alias Hologram.Server
  alias Holography.DOM
  alias Holography.Session

  @doc """
  Visits a Hologram page module and returns a `Holography.Session` containing
  the initialized page struct and the expanded, layout-wrapped DOM.
  """
  @spec visit(module(), %{atom() => any()}) :: Session.t()
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
    context = Map.merge(runtime_context(), page.emitted_context)
    env = %{context: context, slots: []}
    ast = DOM.expand(root, env, server)

    %Session{page: page, server: server, ast: ast, page_module: page_module, params: params}
  end

  @doc """
  Trigger an element's `$click` event.

  Any actions or commands will be run.  If the click triggers a page navigation,
  the new page will be loaded into the `Holography.Session`.

  An element is matched by either its inner text or a test id.

  If the target element is a submit button, it will trigger the `$submit` event
  of its form.

  ## Examples

  ```
  HomePage
  |> visit()
  |> click("Sign up")
  ```

  ```
  SignUpPage
  |> visit()
  |> fill_in("Name", with: "Bender")
  |> fill_in("Password", with: "killallhumans")
  |> click("Go")
  ```

  ```
  GameBoard
  |> visit()
  |> click(tid(foobar))
  ```

  ## Options
  - `:exact` Set to `false` to match on a substring of an element.
    Default is `true` meaning you must provide an exact match.

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
    nodes |> find_clickables(text, exact?, []) |> :lists.reverse()
  end

  defp find_clickables([], _text, _exact?, acc), do: acc

  defp find_clickables([{:element, _tag, attrs, children} = node | rest], text, exact?, acc) do
    acc = find_clickables(children, text, exact?, acc)

    matches? =
      node
      |> DOM.inner_text()
      |> text_matches?(text, exact?)

    acc =
      if has_click_attr?(attrs) and matches? do
        [node | acc]
      else
        acc
      end

    find_clickables(rest, text, exact?, acc)
  end

  defp find_clickables([_ | rest], text, exact?, acc) do
    find_clickables(rest, text, exact?, acc)
  end

  defp has_click_attr?(attrs) do
    Enum.any?(attrs, fn
      {"$click", _value} -> true
      _ -> false
    end)
  end

  defp text_matches?(actual, expected, exact?) do
    if exact? do
      String.trim(actual) == expected
    else
      String.contains?(actual, expected)
    end
  end

  defp handle_click(session, {:element, _tag, attrs, _children}) do
    # Hologram.UI.Link expands `$click={:__load_prefetched_page__, to: @to}` —
    # in the resolved AST that shows up as `[expression: {:__load_prefetched_page__, [to: Target]}]`.
    case DOM.find_attr(attrs, "$click") do
      [{:expression, {:__load_prefetched_page__, params}}] when is_list(params) ->
        case Keyword.fetch!(params, :to) do
          {target_module, target_params} -> visit(target_module, Map.new(target_params))
          target_module -> visit(target_module)
        end

      value ->
        dispatch_event(session, value, %{})
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
        text_matches?(DOM.inner_text(node), label, exact?)
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
  Asserts that the session's DOM contains exactly one element matching the
  given CSS selector (and optional filters).

  Raises if no element matches or if more than one element matches.

      session |> assert_has("button")
      session |> assert_has("h1", text: "Welcome")
      session |> assert_has("input#email", value: "alice@example.com")

  ## Options

    * `:text` — also require the element's inner text (trimmed) to equal this value
    * `:value` — also require the element's `value` attribute to equal this value
  """
  @doc group: "Assertions"
  defdelegate assert_has(session, selector, text_or_opts \\ []), to: Holography.Assertions
  defdelegate assert_has(session, selector, text, opts), to: Holography.Assertions

  @doc """
  The opposite of `assert_has` — asserts that the session's DOM does *not*
  contain any element matching the given CSS selector (and optional filters).

      session |> refute_has(".error")
      session |> refute_has("p", text: "Deleted")
  """
  @doc group: "Assertions"
  defdelegate refute_has(session, selector, text_or_opts \\ []), to: Holography.Assertions
  defdelegate refute_has(session, selector, text, opts), to: Holography.Assertions

  @doc """
  Opens the current page HTML in the default browser.

      session
      |> fill_in("Name", with: "Alice")
      |> open_browser()
      |> assert_has("Alice")

  """
  @spec open_browser(Session.t(), (String.t() -> any())) :: Session.t()
  defdelegate open_browser(session), to: Holography.Browser
  defdelegate open_browser(session, open_fun), to: Holography.Browser

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
    collect_form_nodes(children, DOM.find_attr(attrs, "$change"))
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
      case DOM.find_attr(attrs, "id") do
        nil -> nested_inputs
        id -> Map.put(nested_inputs, DOM.attr_to_string(id), {node, form_change})
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
    case DOM.find_attr(attrs, "for") do
      nil ->
        raise "Label #{inspect(label_text)} has no wrapped input and no `for` attribute"

      for_attr ->
        id = DOM.attr_to_string(for_attr)

        case Map.fetch(by_id, id) do
          {:ok, match} ->
            match

          :error ->
            raise "No input with id=#{inspect(id)} found for label #{inspect(label_text)}"
        end
    end
  end

  defp trigger_input_action(session, {:element, _tag, attrs, _children}, value) do
    case DOM.find_attr(attrs, "$change") do
      nil -> session
      action -> dispatch_event(session, action, %{value: value})
    end
  end

  defp trigger_form_change(session, nil, _value), do: session

  defp trigger_form_change(session, form_change, value) do
    dispatch_event(session, form_change, %{value: value})
  end

  # Text syntax action, e.g. `$click="my_action"`.
  defp dispatch_event(%Session{} = session, [{:text, name}], extra)
       when is_binary(name) do
    run_action(session, String.to_existing_atom(name), extra)
  end

  # Bare atom action, e.g. `$click={:submit}`.
  defp dispatch_event(%Session{} = session, [{:expression, {name}}], extra)
       when is_atom(name) do
    run_action(session, name, extra)
  end

  # Action with params, e.g. `$click={:write_file, path: @tmp_path}`.
  defp dispatch_event(%Session{} = session, [{:expression, {name, params}}], extra)
       when is_atom(name) and is_list(params) do
    run_action(session, name, Map.merge(Map.new(params), extra))
  end

  # Longhand action/command, e.g. `$click={action: :name}` or `$click={command: :name}`.
  defp dispatch_event(%Session{} = session, [{:expression, {spec}}], extra)
       when is_list(spec) do
    cond do
      Keyword.has_key?(spec, :action) ->
        name = Keyword.fetch!(spec, :action)
        params = Keyword.get(spec, :params, %{})
        run_action(session, name, Map.merge(Map.new(params), extra))

      Keyword.has_key?(spec, :command) ->
        name = Keyword.fetch!(spec, :command)
        params = Keyword.get(spec, :params, %{})
        cmd = %Component.Command{name: name, params: Map.new(params)}
        session = run_command(session, cmd)
        re_render(session)

      true ->
        session
    end
  end

  # Attribute values that aren't one of the known expression shapes are no-ops.
  defp dispatch_event(session, _other, _extra), do: session

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

    # Capture the side-effect instructions before clearing them from the
    # component so they don't leak into chained actions.
    next_action = new_component.next_action
    next_command = new_component.next_command
    next_page = new_component.next_page

    clean_component =
      %{new_component | next_action: nil, next_command: nil, next_page: nil}

    session = %{session | page: clean_component, server: new_server}

    # 1. If the action emitted a command, run it server-side.
    #    The command may update the server and trigger a follow-up action.
    session =
      if cmd = next_command do
        run_command(session, cmd)
      else
        session
      end

    # 2. If the action chained another action, run it.
    session =
      if action = next_action do
        run_action(session, action.name, action.params)
      else
        session
      end

    # 3. If the action triggered a page navigation, visit the new page.
    case next_page do
      nil ->
        re_render(session)

      {target_module, target_params} ->
        visit(target_module, Map.new(target_params))

      target_module ->
        visit(target_module)
    end
  end

  defp run_command(%Session{page_module: page_module, server: server} = session, cmd) do
    new_server =
      case page_module.command(cmd.name, cmd.params, server) do
        %Server{} = s -> s
        _ -> server
      end

    session = %{session | server: new_server}

    # If the command triggered a follow-up action, run it on the page component.
    if action = new_server.next_action do
      run_action(session, action.name, action.params)
    else
      session
    end
  end

  defp re_render(
         %Session{page: page, server: server, page_module: page_module, params: params} = session
       ) do
    vars = Map.merge(params, page.state)
    page_dom = page_module.template().(vars)

    layout_props_dom =
      page_module.__layout_props__()
      |> Enum.into(%{cid: "layout"})
      |> Map.merge(page.state)
      |> Enum.map(fn {name, value} -> {to_string(name), [expression: {value}]} end)

    root = {:component, page_module.__layout_module__(), layout_props_dom, page_dom}
    context = Map.merge(runtime_context(), page.emitted_context)
    env = %{context: context, slots: []}
    ast = DOM.expand(root, env, server)

    %{session | ast: ast}
  end

  defp runtime_context do
    %{
      {Hologram.Runtime, :initial_page?} => false,
      {Hologram.Runtime, :page_mounted?} => true,
      {Hologram.Runtime, :page_digest} => "test",
      {Hologram.Runtime, :csrf_token} => "test"
    }
  end
end
