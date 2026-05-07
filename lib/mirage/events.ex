defmodule Mirage.Events do
  @moduledoc false

  alias Hologram.Component
  alias Hologram.Server
  alias Mirage.DOM
  alias Mirage.Input
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

    # Fallback: buttons / input[type=submit] associated with a form that has $submit.
    # This includes buttons inside the form AND external buttons with a `form` attribute.
    targets =
      case with_click do
        [] ->
          forms_by_id = collect_forms_with_submit(ast)

          internal =
            ast
            |> find_submit_targets()
            |> Enum.filter(fn {node, _submit_attr, _form_target} ->
              text == nil or DOM.text_matches?(element_text(node), text, exact?)
            end)

          external =
            ast
            |> find_external_submit_buttons(forms_by_id)
            |> Enum.filter(fn {node, _submit_attr, _form_target} ->
              text == nil or DOM.text_matches?(element_text(node), text, exact?)
            end)

          (internal ++ external)
          |> Enum.map(fn {_node, submit_attr, form_target} ->
            {:form_submit, submit_attr, form_target}
          end)

        nodes ->
          Enum.map(nodes, &{:click, &1})
      end

    case targets do
      [] ->
        raise "No clickable element found matching #{describe(selector, opts)}"

      [{:click, node}] ->
        handle_click(session, node)

      [{:form_submit, submit_attr, form_target}] ->
        form_data =
          Input.collect_form_values(session.ast, "$submit", submit_attr, session.bookkeeping)

        dispatch_event(session, submit_attr, form_data, form_target)

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
  def dispatch_event(session, attr_value, event_data, default_target \\ nil)

  # Text syntax action, e.g. `$click="my_action"`.
  def dispatch_event(%Session{} = session, [{:text, name}], event_data, default_target)
      when is_binary(name) do
    run_action(session, String.to_existing_atom(name), %{event: event_data}, default_target)
  end

  # Bare atom action, e.g. `$click={:submit}`.
  def dispatch_event(%Session{} = session, [{:expression, {name}}], event_data, default_target)
      when is_atom(name) do
    run_action(session, name, %{event: event_data}, default_target)
  end

  # Action with params, e.g. `$click={:write_file, path: @tmp_path}`.
  # Also supports `target:` to dispatch to a stateful component.
  def dispatch_event(
        %Session{} = session,
        [{:expression, {name, params}}],
        event_data,
        default_target
      )
      when is_atom(name) and is_list(params) do
    {explicit_target, params} = Keyword.pop(params, :target)
    target = explicit_target || default_target
    run_action(session, name, Map.merge(Map.new(params), %{event: event_data}), target)
  end

  # Longhand action/command, e.g. `$click={action: :name}` or `$click={command: :name}`.
  # Optionally includes `target: "cid"` to dispatch to a stateful component.
  def dispatch_event(%Session{} = session, [{:expression, {spec}}], event_data, default_target)
      when is_list(spec) do
    explicit_target = Keyword.get(spec, :target)
    target = explicit_target || default_target

    cond do
      Keyword.has_key?(spec, :action) ->
        name = Keyword.fetch!(spec, :action)
        params = Keyword.get(spec, :params, %{})
        run_action(session, name, Map.merge(Map.new(params), %{event: event_data}), target)

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
  def dispatch_event(session, _other, _event_data, _default_target), do: session

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
      value -> dispatch_event(session, value, %{}, DOM.find_attr(attrs, "__mirage_target__"))
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
        form_target = DOM.find_attr(attrs, "__mirage_target__")

        children
        |> find_submit_buttons()
        |> Enum.map(fn btn -> {btn, submit_attr, form_target} end)
    end
  end

  defp find_submit_targets({:element, _tag, _attrs, children}) do
    find_submit_targets(children)
  end

  defp find_submit_targets(_), do: []

  defp find_submit_buttons(nodes) when is_list(nodes) do
    Enum.flat_map(nodes, &find_submit_buttons/1)
  end

  defp find_submit_buttons({:element, "button", attrs, _} = node) do
    if submit_button?(attrs), do: [node], else: []
  end

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

  # Collect all <form> elements with a $submit attr, keyed by their id.
  defp collect_forms_with_submit(nodes) when is_list(nodes) do
    Enum.reduce(nodes, %{}, fn node, acc -> Map.merge(acc, collect_forms_with_submit(node)) end)
  end

  defp collect_forms_with_submit({:element, "form", attrs, children}) do
    acc =
      case {DOM.find_attr(attrs, "id"), DOM.find_attr(attrs, "$submit")} do
        {nil, _} ->
          %{}

        {_, nil} ->
          %{}

        {id, submit_attr} ->
          form_target = DOM.find_attr(attrs, "__mirage_target__")
          %{DOM.attr_to_string(id) => {submit_attr, form_target}}
      end

    Enum.reduce(children, acc, fn node, a -> Map.merge(a, collect_forms_with_submit(node)) end)
  end

  defp collect_forms_with_submit({:element, _tag, _attrs, children}) do
    collect_forms_with_submit(children)
  end

  defp collect_forms_with_submit(_), do: %{}

  # Find buttons/input[type=submit] anywhere in the DOM that have a `form` attribute
  # matching a collected form id.
  defp find_external_submit_buttons(nodes, forms_by_id) when is_list(nodes) do
    Enum.flat_map(nodes, &find_external_submit_buttons(&1, forms_by_id))
  end

  defp find_external_submit_buttons({:element, "button", attrs, children} = node, forms_by_id) do
    own =
      case DOM.find_attr(attrs, "form") do
        nil ->
          []

        form_id_val ->
          form_id = DOM.attr_to_string(form_id_val)

          if submit_button?(attrs) do
            case Map.fetch(forms_by_id, form_id) do
              {:ok, {submit_attr, form_target}} -> [{node, submit_attr, form_target}]
              :error -> []
            end
          else
            []
          end
      end

    own ++ find_external_submit_buttons(children, forms_by_id)
  end

  defp find_external_submit_buttons({:element, "input", attrs, _children} = node, forms_by_id) do
    case DOM.find_attr(attrs, "form") do
      nil ->
        []

      form_id_val ->
        form_id = DOM.attr_to_string(form_id_val)

        is_submit =
          case DOM.find_attr(attrs, "type") do
            nil -> false
            type -> DOM.attr_to_string(type) == "submit"
          end

        case {is_submit, Map.fetch(forms_by_id, form_id)} do
          {true, {:ok, {submit_attr, form_target}}} -> [{node, submit_attr, form_target}]
          _ -> []
        end
    end
  end

  defp find_external_submit_buttons({:element, _tag, _attrs, children}, forms_by_id) do
    find_external_submit_buttons(children, forms_by_id)
  end

  defp find_external_submit_buttons(_, _forms_by_id), do: []

  # A <button> is a submit button if it has no type or type="submit".
  defp submit_button?(attrs) do
    case DOM.find_attr(attrs, "type") do
      nil -> true
      type -> DOM.attr_to_string(type) == "submit"
    end
  end

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
          {target_module, target_params} ->
            Mirage.visit(session, target_module, target_params)

          target_module ->
            Mirage.visit(session, target_module)
        end

      _ ->
        dispatch_from_node(session, node, "$click")
    end
  end

  # ---------------------------------------------------------------------------
  # Component init action drain
  # ---------------------------------------------------------------------------

  @doc false
  def drain_component_inits(%Session{bookkeeping: %{components: components}} = session) do
    init_actions =
      for {cid, {_module, component}} <- components,
          action = component.next_action,
          action != nil do
        {cid, action}
      end

    case init_actions do
      [] ->
        session

      actions ->
        session =
          Enum.reduce(actions, session, fn {cid, _action}, acc ->
            {module, component} = acc.bookkeeping.components[cid]
            clean = %{component | next_action: nil}
            put_in(acc, [Access.key(:bookkeeping), :components, cid], {module, clean})
          end)

        Enum.reduce(actions, session, fn {cid, action}, acc ->
          run_action(acc, action.name, action.params, cid)
        end)
    end
  end

  # ---------------------------------------------------------------------------
  # Private — action/command lifecycle
  # ---------------------------------------------------------------------------

  defp run_action(%Session{} = session, name, params, target) do
    {module, component, keep} = resolve_target(session, target)

    {new_component, new_server} =
      case module.action(name, params, component) do
        {%Component{} = c, %Server{} = s} -> {c, s}
        %Component{} = c -> {c, session.server}
        %Server{} = s -> {component, s}
      end

    next_action = new_component.next_action
    next_command = new_component.next_command
    next_page = new_component.next_page

    clean = %{new_component | next_action: nil, next_command: nil, next_page: nil}

    session =
      session
      |> keep.(clean)
      |> Map.put(:server, new_server)

    session =
      if cmd = next_command,
        do: run_command(session, cmd, retarget(cmd.target, target)),
        else: session

    session =
      if action = next_action,
        do: run_action(session, action.name, action.params, retarget(action.target, target)),
        else: session

    case next_page do
      nil ->
        re_render(session)

      {target_module, target_params} ->
        Mirage.visit(session, target_module, target_params)

      target_module ->
        Mirage.visit(session, target_module)
    end
  end

  defp retarget("page", _fallback), do: nil
  defp retarget(nil, fallback), do: fallback
  defp retarget(explicit, _fallback), do: explicit

  defp resolve_target(%Session{page_module: module, page: component}, nil) do
    {module, component, fn session, comp -> %{session | page: comp} end}
  end

  defp resolve_target(%Session{bookkeeping: %{components: components}} = session, target)
       when is_binary(target) do
    case Map.fetch(components, target) do
      {:ok, {module, component}} ->
        keep =
          if session.mounted_cid == target do
            fn session, comp ->
              session
              |> put_in([Access.key(:bookkeeping), :components, target], {module, comp})
              |> Map.put(:page, comp)
            end
          else
            fn session, comp ->
              put_in(session, [Access.key(:bookkeeping), :components, target], {module, comp})
            end
          end

        {module, component, keep}

      :error ->
        raise "No component found with cid: #{inspect(target)}"
    end
  end

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
            %Server{} = new_server -> new_server
            _ -> session.server
          end

        session = %{session | server: new_server}

        if action = new_server.next_action do
          run_action(session, action.name, action.params, retarget(action.target, target))
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
        %Server{} = new_server -> new_server
        _ -> server
      end

    session = %{session | server: new_server}

    if action = new_server.next_action do
      run_action(session, action.name, action.params, retarget(action.target, nil))
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
    context = Map.merge(runtime_context(), page.emitted_context)

    Process.put(:mirage_components, bookkeeping.components)

    root =
      if function_exported?(page_module, :__layout_module__, 0) do
        # Expand page content in the page's scope first so page events target
        # the page, not the layout.
        page_env = %{context: context, slots: [], target: nil}
        expanded_page = DOM.expand(page_dom, page_env, server)

        layout_props_dom =
          page_module.__layout_props__()
          |> Enum.into(%{cid: "layout"})
          |> Map.merge(page.state)
          |> Enum.map(fn {name, value} -> {to_string(name), [expression: {value}]} end)

        {:component, page_module.__layout_module__(), layout_props_dom,
         [{:preexpanded, expanded_page}]}
      else
        page_dom
      end

    env = %{context: context, slots: [], target: nil}
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
