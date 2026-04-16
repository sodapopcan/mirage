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

    defstruct [:page, :ast, :page_module]

    @type t :: %__MODULE__{
            page: Component.t() | nil,
            ast: any(),
            page_module: module() | nil
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

    %Session{page: page, ast: ast, page_module: page_module}
  end

  @doc """
  Finds and "clicks" an element that has a `$click` attribute and whose inner
  text (with all descendant tags stripped) matches `text`.

  If the click triggers a page navigation (`Hologram.UI.Link`), the session
  is replaced with one for the linked page. If the click's action emits a
  command, that command is executed server-side before returning.

  Matches exactly by default; pass `exact: false` to match substrings instead.
  Raises if no matching clickable element is found.
  """
  @spec click(Session.t(), String.t(), keyword()) :: Session.t()
  def click(session, text, opts \\ []) do
    exact? = Keyword.get(opts, :exact, true)

    case find_clickable(session.ast, text, exact?) do
      nil ->
        raise "No clickable element found with text: #{inspect(text)}"

      node ->
        handle_click(session, node)
    end
  end

  defp find_clickable(nodes, text, exact?) when is_list(nodes) do
    Enum.find_value(nodes, &find_clickable(&1, text, exact?))
  end

  defp find_clickable({:element, _tag, attrs, children} = node, text, exact?) do
    if has_click_attr?(attrs) and text_matches?(inner_text(node), text, exact?) do
      node
    else
      find_clickable(children, text, exact?)
    end
  end

  # Public comments aren't interactive content — don't recurse into them.
  defp find_clickable({:public_comment, _children}, _text, _exact?), do: nil

  defp find_clickable(_other, _text, _exact?), do: nil

  defp has_click_attr?(attrs) do
    Enum.any?(attrs, fn
      {"$click", _value} -> true
      _ -> false
    end)
  end

  defp inner_text({:element, _tag, _attrs, children}), do: inner_text(children)
  defp inner_text({:text, text}), do: text
  defp inner_text(nodes) when is_list(nodes), do: Enum.map_join(nodes, "", &inner_text/1)
  defp inner_text(_other), do: ""

  defp text_matches?(actual, expected, true), do: String.trim(actual) == expected
  defp text_matches?(actual, expected, false), do: String.contains?(actual, expected)

  defp handle_click(session, {:element, _tag, attrs, _children}) do
    click_value =
      Enum.find_value(attrs, fn
        {"$click", value} -> value
        _ -> nil
      end)

    dispatch_click(session, click_value)
  end

  # Hologram.UI.Link expands `$click={:__load_prefetched_page__, to: @to}` —
  # in the resolved AST that shows up as `[expression: {:__load_prefetched_page__, [to: Target]}]`.
  defp dispatch_click(_session, [{:expression, {:__load_prefetched_page__, params}}])
       when is_list(params) do
    visit(Keyword.fetch!(params, :to))
  end

  # Action with params, e.g. `$click={:write_file, path: @tmp_path}`.
  defp dispatch_click(%Session{} = session, [{:expression, {name, params}}])
       when is_atom(name) and is_list(params) do
    run_action(session, name, Map.new(params))
  end

  # Bare atom action, e.g. `$click={:submit}` — evaluated as a 1-tuple.
  defp dispatch_click(%Session{} = session, [{:expression, {name}}])
       when is_atom(name) do
    run_action(session, name, %{})
  end

  # Anything else (literal strings, shapes we don't model) is a no-op: the
  # session is returned as-is. This is what the basic click/3 tests rely on.
  defp dispatch_click(session, _other), do: session

  # Without a known page module there's no `action/3` to dispatch into, so
  # the click is a no-op on the session.
  defp run_action(%Session{page_module: nil} = session, _name, _params), do: session

  defp run_action(%Session{page_module: page_module} = session, name, params) do
    component = session.page || %Component{}
    server = %Server{}

    result =
      if function_exported?(page_module, :action, 3) do
        page_module.action(name, params, component)
      else
        component
      end

    {new_component, new_server} =
      case result do
        {%Component{} = c, %Server{} = s} -> {c, s}
        %Component{} = c -> {c, server}
        %Server{} = s -> {component, s}
      end

    # If the action emitted a command, run it server-side.
    if cmd = new_component.next_command do
      page_module.command(cmd.name, cmd.params, new_server)
    end

    %{session | page: new_component}
  end
end
