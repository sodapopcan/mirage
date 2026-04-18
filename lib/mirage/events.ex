defmodule Mirage.Events do
  @moduledoc false

  alias Hologram.Component
  alias Hologram.Server
  alias Mirage.DOM
  alias Mirage.Query
  alias Mirage.Session

  def click(session, selector, text_or_opts \\ [])

  def click(session, selector, text) when is_binary(text) do
    click(session, selector, text: text)
  end

  def click(%Session{} = session, selector, opts) when is_binary(selector) and is_list(opts) do
    text = Keyword.get(opts, :text)
    exact? = Keyword.get(opts, :exact, true)

    matches =
      session.ast
      |> Query.query_all(selector)
      |> Enum.filter(fn {:element, _, attrs, _} -> has_click_attr?(attrs) end)

    matches =
      if text do
        Enum.filter(matches, fn node ->
          DOM.text_matches?(DOM.inner_text(node), text, exact?)
        end)
      else
        matches
      end

    case matches do
      [] ->
        raise "No clickable element found matching #{describe_click(selector, opts)}"

      [node] ->
        handle_click(session, node)

      [_ | _] = nodes ->
        raise "Ambiguous match: found #{length(nodes)} clickable elements matching #{describe_click(selector, opts)}"
    end
  end

  @doc false
  @spec click(Session.t(), String.t(), String.t(), keyword()) :: Session.t()
  def click(session, selector, text, opts) when is_binary(text) and is_list(opts) do
    click(session, selector, Keyword.put(opts, :text, text))
  end

  @doc false
  # Text syntax action, e.g. `$click="my_action"`.
  def dispatch_event(%Session{} = session, [{:text, name}], extra)
      when is_binary(name) do
    run_action(session, String.to_existing_atom(name), extra)
  end

  # Bare atom action, e.g. `$click={:submit}`.
  def dispatch_event(%Session{} = session, [{:expression, {name}}], extra)
      when is_atom(name) do
    run_action(session, name, extra)
  end

  # Action with params, e.g. `$click={:write_file, path: @tmp_path}`.
  def dispatch_event(%Session{} = session, [{:expression, {name, params}}], extra)
      when is_atom(name) and is_list(params) do
    run_action(session, name, Map.merge(Map.new(params), extra))
  end

  # Longhand action/command, e.g. `$click={action: :name}` or `$click={command: :name}`.
  def dispatch_event(%Session{} = session, [{:expression, {spec}}], extra)
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
  def dispatch_event(session, _other, _extra), do: session

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp describe_click(selector, opts) do
    parts = [inspect(selector)]

    parts =
      case Keyword.get(opts, :text) do
        nil -> parts
        text -> parts ++ ["text: #{inspect(text)}"]
      end

    Enum.join(parts, ", ")
  end

  defp has_click_attr?(attrs) do
    Enum.any?(attrs, fn
      {"$click", _value} -> true
      _ -> false
    end)
  end

  defp handle_click(session, {:element, _tag, attrs, _children}) do
    # Hologram.UI.Link expands `$click={:__load_prefetched_page__, to: @to}` —
    # in the resolved AST that shows up as `[expression: {:__load_prefetched_page__, [to: Target]}]`.
    case DOM.find_attr(attrs, "$click") do
      [{:expression, {:__load_prefetched_page__, params}}] when is_list(params) ->
        case Keyword.fetch!(params, :to) do
          {target_module, target_params} -> Mirage.visit(target_module, Map.new(target_params))
          target_module -> Mirage.visit(target_module)
        end

      value ->
        dispatch_event(session, value, %{})
    end
  end

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
        Mirage.visit(target_module, Map.new(target_params))

      target_module ->
        Mirage.visit(target_module)
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
