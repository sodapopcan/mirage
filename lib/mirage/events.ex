defmodule Mirage.Events do
  @moduledoc false

  alias Hologram.Component
  alias Hologram.Server
  alias Mirage.DOM
  alias Mirage.Query
  alias Mirage.Scoped
  alias Mirage.Session

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  def click(session, selector, text_or_opts \\ [])

  def click(session, selector, text) when is_binary(text) do
    click(session, selector, text: text)
  end

  def click(%Session{} = session, selector, opts) when is_binary(selector) and is_list(opts) do
    validate_opts!(opts)

    text = Keyword.get(opts, :text)
    exact? = Keyword.get(opts, :exact, true)
    ast = Scoped.query_ast(session)

    # Primary: elements that have a $click handler.
    with_click =
      ast
      |> Query.query_all(selector)
      |> Enum.filter(fn {:element, _, attrs, _} -> has_attr?(attrs, "$click") end)
      |> filter_by_text(text, exact?)

    # Fallback: buttons / input[type=submit] inside a form with $submit.
    targets =
      case with_click do
        [] ->
          ast
          |> find_submit_targets()
          |> Enum.filter(fn {node, _submit_attr} ->
            text == nil or DOM.text_matches?(element_text(node), text, exact?)
          end)
          |> Enum.map(fn {_node, submit_attr} -> {:form_submit, submit_attr} end)

        nodes ->
          Enum.map(nodes, &{:click, &1})
      end

    case targets do
      [] ->
        raise "No clickable element found matching #{describe(selector, opts)}"

      [{:click, node}] ->
        handle_click(session, node)

      [{:form_submit, submit_attr}] ->
        dispatch_event(session, submit_attr, %{})

      many ->
        raise "Ambiguous match: found #{length(many)} clickable elements matching #{describe(selector, opts)}"
    end
  end

  def click(session, selector, text, opts) when is_binary(text) and is_list(opts) do
    click(session, selector, Keyword.put(opts, :text, text))
  end

  def focus(session, selector, text_or_opts \\ [])

  def focus(session, selector, text) when is_binary(text) do
    focus(session, selector, text: text)
  end

  def focus(%Session{} = session, selector, opts) when is_binary(selector) and is_list(opts) do
    validate_opts!(opts)

    node = find_event_target!(session, "$focus", selector, opts)
    dispatch_from_node(session, node, "$focus")
  end

  def focus(session, selector, text, opts) when is_binary(text) and is_list(opts) do
    focus(session, selector, Keyword.put(opts, :text, text))
  end

  def blur(session, selector, text_or_opts \\ [])

  def blur(session, selector, text) when is_binary(text) do
    blur(session, selector, text: text)
  end

  def blur(%Session{} = session, selector, opts) when is_binary(selector) and is_list(opts) do
    validate_opts!(opts)

    node = find_event_target!(session, "$blur", selector, opts)
    dispatch_from_node(session, node, "$blur")
  end

  def blur(session, selector, text, opts) when is_binary(text) and is_list(opts) do
    blur(session, selector, Keyword.put(opts, :text, text))
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
  # Optionally includes `target: "cid"` to dispatch to a stateful component.
  def dispatch_event(%Session{} = session, [{:expression, {spec}}], extra)
      when is_list(spec) do
    target = Keyword.get(spec, :target)

    cond do
      Keyword.has_key?(spec, :action) ->
        name = Keyword.fetch!(spec, :action)
        params = Keyword.get(spec, :params, %{})
        run_action(session, name, Map.merge(Map.new(params), extra), target)

      Keyword.has_key?(spec, :command) ->
        name = Keyword.fetch!(spec, :command)
        params = Keyword.get(spec, :params, %{})
        cmd = %Component.Command{name: name, params: Map.new(params)}
        session = run_command(session, cmd, target)
        re_render(session)

      true ->
        session
    end
  end

  # Attribute values that aren't one of the known expression shapes are no-ops.
  def dispatch_event(session, _other, _extra), do: session

  # ---------------------------------------------------------------------------
  # Private — event targeting
  # ---------------------------------------------------------------------------

  defp find_event_target!(session, event_attr, selector, opts) do
    text = Keyword.get(opts, :text)
    exact? = Keyword.get(opts, :exact, true)

    matches =
      session
      |> Scoped.query_ast()
      |> Query.query_all(selector)
      |> Enum.filter(fn {:element, _, attrs, _} -> has_attr?(attrs, event_attr) end)

    matches =
      if text do
        Enum.filter(matches, fn node ->
          DOM.text_matches?(DOM.inner_text(node), text, exact?)
        end)
      else
        matches
      end

    event_name = String.trim_leading(event_attr, "$")

    case matches do
      [] ->
        raise "No #{event_name}able element found matching #{describe(selector, opts)}"

      [node] ->
        node

      [_ | _] = nodes ->
        raise "Ambiguous match: found #{length(nodes)} #{event_name}able elements matching #{describe(selector, opts)}"
    end
  end

  defp dispatch_from_node(session, {:element, _tag, attrs, _children}, event_attr) do
    case DOM.find_attr(attrs, event_attr) do
      nil -> session
      value -> dispatch_event(session, value, %{})
    end
  end

  # For most elements inner_text gives the display text; for input[type=submit]
  # the display text is the value attribute.
  defp element_text({:element, "input", attrs, _}) do
    case DOM.find_attr(attrs, "value") do
      nil -> ""
      v -> DOM.attr_to_string(v)
    end
  end

  defp element_text(node), do: DOM.inner_text(node)

  defp filter_by_text(nodes, nil, _exact?), do: nodes

  defp filter_by_text(nodes, text, exact?) do
    Enum.filter(nodes, fn node ->
      DOM.text_matches?(DOM.inner_text(node), text, exact?)
    end)
  end

  # Returns [{button_or_submit_input, form_submit_attr}] for every submit
  # button / input[type=submit] that lives inside a form with a $submit attr.
  defp find_submit_targets(nodes) when is_list(nodes) do
    Enum.flat_map(nodes, &find_submit_targets/1)
  end

  defp find_submit_targets({:element, "form", attrs, children}) do
    case DOM.find_attr(attrs, "$submit") do
      nil ->
        find_submit_targets(children)

      submit_attr ->
        children
        |> find_submit_buttons()
        |> Enum.map(fn btn -> {btn, submit_attr} end)
    end
  end

  defp find_submit_targets({:element, _tag, _attrs, children}) do
    find_submit_targets(children)
  end

  defp find_submit_targets(_), do: []

  defp find_submit_buttons(nodes) when is_list(nodes) do
    Enum.flat_map(nodes, &find_submit_buttons/1)
  end

  defp find_submit_buttons({:element, "button", _, _} = node), do: [node]

  defp find_submit_buttons({:element, "input", attrs, _} = node) do
    case DOM.find_attr(attrs, "type") do
      nil -> []
      type -> if DOM.attr_to_string(type) == "submit", do: [node], else: []
    end
  end

  defp find_submit_buttons({:element, _tag, _attrs, children}) do
    find_submit_buttons(children)
  end

  defp find_submit_buttons(_), do: []

  defp has_attr?(attrs, name) do
    Enum.any?(attrs, fn
      {^name, _value} -> true
      _ -> false
    end)
  end

  defp describe(selector, opts) do
    parts = [inspect(selector)]

    parts =
      case Keyword.get(opts, :text) do
        nil -> parts
        text -> parts ++ ["text: #{inspect(text)}"]
      end

    Enum.join(parts, ", ")
  end

  # Click has special handling for Hologram.UI.Link navigation.
  defp handle_click(session, {:element, _tag, attrs, _children} = node) do
    case DOM.find_attr(attrs, "$click") do
      [{:expression, {:__load_prefetched_page__, params}}] when is_list(params) ->
        case Keyword.fetch!(params, :to) do
          {target_module, target_params} -> Mirage.visit(target_module, Map.new(target_params))
          target_module -> Mirage.visit(target_module)
        end

      _ ->
        dispatch_from_node(session, node, "$click")
    end
  end

  # ---------------------------------------------------------------------------
  # Private — action/command lifecycle
  # ---------------------------------------------------------------------------

  defp run_action(session, name, params, target \\ nil)

  defp run_action(
         %Session{bookkeeping: %{components: components}} = session,
         name,
         params,
         target
       )
       when is_binary(target) do
    case Map.fetch(components, target) do
      {:ok, {module, component}} ->
        {new_component, new_server} =
          case module.action(name, params, component) do
            {%Component{} = c, %Server{} = s} -> {c, s}
            %Component{} = c -> {c, session.server}
            %Server{} = s -> {component, s}
          end

        next_action = new_component.next_action
        next_command = new_component.next_command

        clean_component =
          %{new_component | next_action: nil, next_command: nil, next_page: nil}

        session =
          session
          |> put_in([Access.key(:server)], new_server)
          |> put_in([Access.key(:bookkeeping), :components, target], {module, clean_component})

        session =
          if cmd = next_command do
            run_command(session, cmd, target)
          else
            session
          end

        session =
          if action = next_action do
            run_action(session, action.name, action.params, target)
          else
            session
          end

        re_render(session)

      :error ->
        raise "No component found with cid: #{inspect(target)}"
    end
  end

  defp run_action(
         %Session{page: component, page_module: page_module, server: server} = session,
         name,
         params,
         _target
       ) do
    {new_component, new_server} =
      case page_module.action(name, params, component) do
        {%Component{} = component, %Server{} = server} -> {component, server}
        %Component{} = component -> {component, server}
        %Server{} = server -> {component, server}
      end

    next_action = new_component.next_action
    next_command = new_component.next_command
    next_page = new_component.next_page

    clean_component =
      %{new_component | next_action: nil, next_command: nil, next_page: nil}

    session = %{session | page: clean_component, server: new_server}

    session =
      if cmd = next_command do
        run_command(session, cmd)
      else
        session
      end

    session =
      if action = next_action do
        run_action(session, action.name, action.params)
      else
        session
      end

    case next_page do
      nil ->
        re_render(session)

      {target_module, target_params} ->
        Mirage.visit(target_module, Map.new(target_params))

      target_module ->
        Mirage.visit(target_module)
    end
  end

  defp run_command(session, cmd, target \\ nil)

  defp run_command(
         %Session{bookkeeping: %{components: components}} = session,
         cmd,
         target
       )
       when is_binary(target) do
    case Map.fetch(components, target) do
      {:ok, {module, _component}} ->
        new_server =
          case module.command(cmd.name, cmd.params, session.server) do
            %Server{} = s -> s
            _ -> session.server
          end

        session = %{session | server: new_server}

        if action = new_server.next_action do
          run_action(session, action.name, action.params, target)
        else
          session
        end

      :error ->
        raise "No component found with cid: #{inspect(target)}"
    end
  end

  defp run_command(%Session{page_module: page_module, server: server} = session, cmd, _target) do
    new_server =
      case page_module.command(cmd.name, cmd.params, server) do
        %Server{} = s -> s
        _ -> server
      end

    session = %{session | server: new_server}

    if action = new_server.next_action do
      run_action(session, action.name, action.params)
    else
      session
    end
  end

  defp re_render(
         %Session{
           page: page,
           server: server,
           page_module: page_module,
           params: params,
           bookkeeping: bookkeeping
         } = session
       ) do
    vars = Map.merge(params, page.state)
    page_dom = page_module.template().(vars)

    root =
      if function_exported?(page_module, :__layout_module__, 0) do
        layout_props_dom =
          page_module.__layout_props__()
          |> Enum.into(%{cid: "layout"})
          |> Map.merge(page.state)
          |> Enum.map(fn {name, value} -> {to_string(name), [expression: {value}]} end)

        {:component, page_module.__layout_module__(), layout_props_dom, page_dom}
      else
        page_dom
      end

    context = Map.merge(runtime_context(), page.emitted_context)
    env = %{context: context, slots: []}

    Process.put(:mirage_components, bookkeeping.components)
    ast = DOM.expand(root, env, server)
    updated_components = Process.delete(:mirage_components) || %{}

    %{session | ast: ast, bookkeeping: %{bookkeeping | components: updated_components}}
  end

  defp runtime_context do
    %{
      {Hologram.Runtime, :initial_page?} => false,
      {Hologram.Runtime, :page_mounted?} => true,
      {Hologram.Runtime, :page_digest} => "test",
      {Hologram.Runtime, :csrf_token} => "test"
    }
  end

  def validate_opts!(opts) do
    Keyword.validate!(opts, [:text, :exact])
  end
end
