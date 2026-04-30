defmodule Mirage.DOM do
  @moduledoc false

  alias Hologram.Component
  alias Hologram.Reflection
  alias Hologram.Server

  @doc """
  Recursively expands a Hologram template DOM node, resolving components down
  to their underlying elements/text. Preserves `$`-prefixed attributes so that
  interaction testing (e.g. simulating clicks) remains possible.
  """
  def expand(nodes, env, server) when is_list(nodes) do
    nodes
    |> Enum.filter(& &1)
    |> Enum.map(&expand(&1, env, server))
    |> List.flatten()
  end

  def expand({:component, module, props, children}, env, server) do
    expanded_children = expand_slots(children, env.slots)

    props =
      props
      |> cast_props(module)
      |> inject_props_from_context(module, env.context)
      |> inject_default_prop_values(module)

    {component_struct, server} =
      if has_cid?(props) do
        cid = props[:cid]
        existing = Process.get(:mirage_components, %{})

        case Map.fetch(existing, cid) do
          {:ok, {^module, existing_component}} ->
            {existing_component, server}

          _ ->
            {comp, srv} = init_component(module, props, server)
            Process.put(:mirage_components, Map.put(existing, cid, {module, comp}))
            {comp, srv}
        end
      else
        {%Component{}, server}
      end

    vars = Map.merge(props, component_struct.state)
    merged_context = Map.merge(env.context, component_struct.emitted_context)
    template_dom = module.template().(vars)

    target = if has_cid?(props), do: props[:cid], else: env[:target]
    slot_target = env[:target]

    expand(
      template_dom,
      %{
        context: merged_context,
        slots: [default: expanded_children],
        target: target,
        slot_target: slot_target
      },
      server
    )
  end

  def expand({:element, "slot", _attrs, []}, env, server) do
    expand(env.slots[:default] || [], %{env | slots: [], target: env[:slot_target]}, server)
  end

  def expand({:element, tag, attrs_dom, children}, env, server) do
    attrs_dom = maybe_stamp_target(attrs_dom, env[:target])
    {:element, tag, attrs_dom, expand(children, env, server)}
  end

  def expand({:expression, {value}}, _env, _server) do
    {:text, to_string(value)}
  end

  def expand({:public_comment, children}, env, server) do
    {:public_comment, expand(children, env, server)}
  end

  def expand(other, _env, _server), do: other

  @event_attrs ~w($click $change $submit $focus $blur $select $input
                  $pointerdown $pointerup $pointermove $pointercancel
                  $mousemove $transitionend $transitionstart $transitionrun $transitioncancel)

  defp maybe_stamp_target(attrs, nil), do: attrs

  defp maybe_stamp_target(attrs, target) do
    has_event? = Enum.any?(attrs, fn {name, _} -> name in @event_attrs end)

    if has_event? do
      [{"__mirage_target__", target} | attrs]
    else
      attrs
    end
  end

  @doc """
  Calls the module's `init/3` if defined and normalizes the result to a
  `{%Component{}, %Server{}}` tuple.
  """
  def init_component(module, props, server) do
    result =
      if Reflection.has_function?(module, :init, 3) do
        module.init(props, %Component{}, server)
      else
        {%Component{}, server}
      end

    case result do
      {%Component{} = component_struct, %Server{} = mutated_server} ->
        {component_struct, mutated_server}

      %Component{} = component_struct ->
        {component_struct, server}

      %Server{} = mutated_server ->
        {%Component{}, mutated_server}
    end
  end

  @doc false
  def cast_props(props, module) do
    allowed =
      [
        "cid"
        | for({name, _, opts} <- module.__props__(), !opts[:from_context], do: to_string(name))
      ]

    props
    |> Enum.filter(fn {name, _} -> name in allowed end)
    |> Enum.map(&evaluate_prop_value/1)
    |> Enum.map(fn {name, value} -> {String.to_existing_atom(name), value} end)
    |> Enum.into(%{})
  end

  defp evaluate_prop_value({name, [expression: {value}]}), do: {name, value}
  defp evaluate_prop_value({name, [expression: value]}), do: {name, value}

  defp evaluate_prop_value({name, dom}) do
    str = dom |> Enum.map(&prop_part_to_string/1) |> Enum.join()
    {name, str}
  end

  defp prop_part_to_string({:text, text}), do: text
  defp prop_part_to_string({:expression, {value}}), do: to_string(value)

  @doc false
  def inject_props_from_context(props, module, context) do
    extras =
      for {name, _type, opts} <- module.__props__(),
          opts[:from_context] && Map.has_key?(context, opts[:from_context]),
          into: %{},
          do: {name, context[opts[:from_context]]}

    Map.merge(props, extras)
  end

  @doc false
  def inject_default_prop_values(props, module) do
    Enum.reduce(module.__props__(), props, fn {name, _type, opts}, acc ->
      if !Map.has_key?(acc, name) and Keyword.has_key?(opts, :default) do
        Map.put(acc, name, opts[:default])
      else
        acc
      end
    end)
  end

  defp expand_slots(nodes, slots) when is_list(nodes) do
    nodes |> Enum.map(&expand_slots(&1, slots)) |> List.flatten()
  end

  defp expand_slots({:component, module, props, children}, slots) do
    {:component, module, props, expand_slots(children, slots)}
  end

  defp expand_slots({:element, "slot", _, []}, slots), do: slots[:default]

  defp expand_slots({:element, tag, attrs_dom, children}, slots) do
    {:element, tag, attrs_dom, expand_slots(children, slots)}
  end

  defp expand_slots(node, _slots), do: node

  defp has_cid?(props), do: Map.has_key?(props, :cid)

  def inner_text(node) do
    case node do
      {:element, _tag, _attrs, children} -> inner_text(children)
      {:text, text} -> text
      nodes when is_list(nodes) -> Enum.map_join(nodes, "", &inner_text/1)
      _ -> ""
    end
  end

  def find_attr(attrs, name) do
    case Enum.find(attrs, fn {n, _} -> n == name end) do
      {^name, value} -> value
      _ -> nil
    end
  end

  def attr_to_string(value) when is_binary(value), do: value

  def attr_to_string(parts) when is_list(parts) do
    Enum.map_join(parts, "", fn
      {:text, t} -> t
      {:expression, {v}} when is_binary(v) or is_number(v) or is_atom(v) -> to_string(v)
      {:expression, {v}} -> inspect(v)
      _ -> ""
    end)
  end

  def attr_to_string(_other), do: ""

  @header_tags ~w(h1 h2 h3 h4 h5 h6)

  @doc """
  Returns the trimmed inner text of the first h1–h6 element found in a
  depth-first walk of the given node(s), or `nil` if none is found.
  """
  def first_header_text(nodes) when is_list(nodes) do
    Enum.find_value(nodes, &first_header_text/1)
  end

  def first_header_text({:element, tag, _attrs, children}) when tag in @header_tags do
    String.trim(inner_text(children))
  end

  def first_header_text({:element, _tag, _attrs, children}) do
    first_header_text(children)
  end

  def first_header_text(_other), do: nil

  @doc """
  Returns the trimmed inner text of the first `<legend>` element found in a
  depth-first walk of the given node(s), or `nil` if none is found.
  """
  def first_legend_text(nodes) when is_list(nodes) do
    Enum.find_value(nodes, &first_legend_text/1)
  end

  def first_legend_text({:element, "legend", _attrs, children}) do
    String.trim(inner_text(children))
  end

  def first_legend_text({:element, _tag, _attrs, children}) do
    first_legend_text(children)
  end

  def first_legend_text(_other), do: nil

  @doc false
  def text_matches?(actual, expected, exact?) do
    if exact? do
      String.trim(actual) == expected
    else
      String.contains?(actual, expected)
    end
  end
end
