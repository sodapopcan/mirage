defmodule Mirage.Mount do
  @moduledoc false

  alias Mirage.DOM
  alias Mirage.Events
  alias Mirage.Session

  # mount(template_fn)
  def mount(template_fn) when is_function(template_fn) do
    do_mount(template_fn, [])
  end

  # mount(template_fn, {NS, key: val})
  def mount(template_fn, {namespace, ctx_props})
      when is_function(template_fn) and is_atom(namespace) and is_list(ctx_props) do
    do_mount(template_fn, [{namespace, ctx_props}])
  end

  # mount(template_fn, [{NS1, key: val}, {NS2, key: val}])
  def mount(template_fn, contexts)
      when is_function(template_fn) and is_list(contexts) do
    do_mount(template_fn, contexts)
  end

  defp do_mount(template_fn, context_tuples) do
    context = build_context(context_tuples)
    vars = context_to_vars(context)

    {:component, module, props_dom, children} =
      template_fn.(vars) |> unwrap_component()

    merged_context = Map.merge(runtime_context(), context)

    # Cast and inject props, then init the component ourselves
    props =
      props_dom
      |> DOM.cast_props(module)
      |> DOM.inject_props_from_context(module, merged_context)
      |> DOM.inject_default_prop_values(module)

    server = %Hologram.Server{}
    {component, server} = DOM.init_component(module, props, server)

    # Expand the component's template with state
    component_vars = Map.merge(props, component.state)
    template_dom = module.template().(component_vars)

    expanded_context = Map.merge(merged_context, component.emitted_context)

    # Slot = children from the markup, expanded with context vars
    slot_dom = DOM.expand(children, %{context: expanded_context, slots: [], target: nil}, server)
    env = %{context: expanded_context, slots: [default: slot_dom], target: nil}

    Process.delete(:mirage_components)

    # Store this component if it has a cid
    if props[:cid] do
      Process.put(:mirage_components, %{props[:cid] => {module, component}})
    end

    ast = DOM.expand(template_dom, env, server)
    components = Process.delete(:mirage_components) || %{}

    %Session{
      page: component,
      server: server,
      ast: ast,
      page_module: module,
      params: props,
      bookkeeping: %{
        checked_radios: %{},
        checked_checkboxes: MapSet.new(),
        selected_options: %{},
        filled_inputs: %{},
        components: components
      }
    }
    |> Events.drain_component_inits()
  end

  defp unwrap_component([{:component, _, _, _} = node]), do: node
  defp unwrap_component({:component, _, _, _} = node), do: node

  defp unwrap_component(other) do
    raise ArgumentError,
          "mount expects a ~HOLO template containing a single component, got: #{inspect(other)}"
  end

  defp build_context(tuples) do
    for {namespace, ctx_props} <- tuples,
        {key, value} <- ctx_props,
        into: %{} do
      {{namespace, key}, value}
    end
  end

  defp context_to_vars(context) do
    for {{_namespace, key}, value} <- context, into: %{} do
      {key, value}
    end
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
