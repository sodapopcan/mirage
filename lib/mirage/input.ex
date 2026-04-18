defmodule Mirage.Input do
  @moduledoc false

  alias Mirage.DOM
  alias Mirage.Events
  alias Mirage.Scoped

  def choose(session, label, opts \\ []) do
    exact? = Keyword.get(opts, :exact, true)

    {labels, inputs_by_id} = collect_form_nodes(Scoped.query_ast(session), nil)

    matches =
      Enum.filter(labels, fn {node, _wrapped, _form_change} ->
        DOM.text_matches?(DOM.inner_text(node), label, exact?)
      end)

    case matches do
      [] ->
        raise "No radio button found with label: #{inspect(label)}"

      [entry] ->
        {input, form_change} = resolve_input(entry, inputs_by_id, label)
        {:element, _, attrs, _} = input

        name =
          case DOM.find_attr(attrs, "name") do
            nil -> nil
            v -> DOM.attr_to_string(v)
          end

        value =
          case DOM.find_attr(attrs, "value") do
            nil -> ""
            v -> DOM.attr_to_string(v)
          end

        session
        |> trigger_input_action(input, value)
        |> trigger_form_change(form_change, value)
        |> Map.update!(:checked_radios, &Map.put(&1, name, value))

      [_ | _] = many ->
        raise "Ambiguous match: found #{length(many)} labels matching: #{inspect(label)}"
    end
  end

  def check(session, label, opts \\ []) do
    exact? = Keyword.get(opts, :exact, true)

    {labels, inputs_by_id} = collect_form_nodes(Scoped.query_ast(session), nil)

    matches =
      Enum.filter(labels, fn {node, _wrapped, _form_change} ->
        DOM.text_matches?(DOM.inner_text(node), label, exact?)
      end)

    case matches do
      [] ->
        raise "No checkbox found with label: #{inspect(label)}"

      [entry] ->
        {input, form_change} = resolve_input(entry, inputs_by_id, label)
        {:element, _, attrs, _} = input

        name =
          case DOM.find_attr(attrs, "name") do
            nil -> nil
            v -> DOM.attr_to_string(v)
          end

        value =
          case DOM.find_attr(attrs, "value") do
            nil -> "on"
            v -> DOM.attr_to_string(v)
          end

        session
        |> trigger_input_action(input, value)
        |> trigger_form_change(form_change, value)
        |> Map.update!(:checked_checkboxes, &MapSet.put(&1, {name, value}))

      [_ | _] = many ->
        raise "Ambiguous match: found #{length(many)} labels matching: #{inspect(label)}"
    end
  end

  def uncheck(session, label, opts \\ []) do
    exact? = Keyword.get(opts, :exact, true)

    {labels, inputs_by_id} = collect_form_nodes(Scoped.query_ast(session), nil)

    matches =
      Enum.filter(labels, fn {node, _wrapped, _form_change} ->
        DOM.text_matches?(DOM.inner_text(node), label, exact?)
      end)

    case matches do
      [] ->
        raise "No checkbox found with label: #{inspect(label)}"

      [entry] ->
        {input, form_change} = resolve_input(entry, inputs_by_id, label)
        {:element, _, attrs, _} = input

        name =
          case DOM.find_attr(attrs, "name") do
            nil -> nil
            v -> DOM.attr_to_string(v)
          end

        value =
          case DOM.find_attr(attrs, "value") do
            nil -> "on"
            v -> DOM.attr_to_string(v)
          end

        session
        |> trigger_input_action(input, value)
        |> trigger_form_change(form_change, value)
        |> Map.update!(:checked_checkboxes, &MapSet.delete(&1, {name, value}))

      [_ | _] = many ->
        raise "Ambiguous match: found #{length(many)} labels matching: #{inspect(label)}"
    end
  end

  def select(session, label, option_text, opts \\ []) do
    exact? = Keyword.get(opts, :exact, true)

    {labels, inputs_by_id} = collect_form_nodes(Scoped.query_ast(session), nil)

    label_matches =
      Enum.filter(labels, fn {node, _wrapped, _form_change} ->
        DOM.text_matches?(label_text_without_inputs(node), label, exact?)
      end)

    case label_matches do
      [] ->
        raise "No select found with label: #{inspect(label)}"

      [entry] ->
        {select_node, form_change} = resolve_input(entry, inputs_by_id, label)
        {:element, _, attrs, children} = select_node

        option_matches =
          Enum.filter(collect_options(children), fn {text, _value} ->
            DOM.text_matches?(text, option_text, exact?)
          end)

        case option_matches do
          [] ->
            raise "No option found with text: #{inspect(option_text)}"

          [{_text, value}] ->
            name =
              case DOM.find_attr(attrs, "name") do
                nil -> nil
                v -> DOM.attr_to_string(v)
              end

            multiple? = DOM.find_attr(attrs, "multiple") != nil

            session
            |> trigger_input_action(select_node, value)
            |> trigger_form_change(form_change, value)
            |> Map.update!(:selected_options, fn current ->
              existing = Map.get(current, name, MapSet.new())
              new_set = if multiple?, do: MapSet.put(existing, value), else: MapSet.new([value])
              Map.put(current, name, new_set)
            end)

          [_ | _] = many ->
            raise "Ambiguous match: found #{length(many)} options matching: #{inspect(option_text)}"
        end

      [_ | _] = many ->
        raise "Ambiguous match: found #{length(many)} labels matching: #{inspect(label)}"
    end
  end

  def select_text(session, label, text_or_opts \\ [])

  def select_text(session, label, text) when is_binary(text) do
    select_text(session, label, text, [])
  end

  def select_text(session, label, opts) when is_list(opts) do
    select_text(session, label, nil, opts)
  end

  def select_text(session, label, text, opts) when is_list(opts) do
    exact? = Keyword.get(opts, :exact, true)

    {labels, inputs_by_id} = collect_form_nodes(Scoped.query_ast(session), nil)

    matches =
      Enum.filter(labels, fn {node, _wrapped, _form_change} ->
        DOM.text_matches?(label_text_without_inputs(node), label, exact?)
      end)

    case matches do
      [] ->
        raise "No text input found with label: #{inspect(label)}"

      [entry] ->
        {input, _form_change} = resolve_input(entry, inputs_by_id, label)
        validate_text_input!(input, label)

        selected = text || input_value(input)
        {:element, _, attrs, _} = input

        case DOM.find_attr(attrs, "$select") do
          nil -> session
          action -> Events.dispatch_event(session, action, %{text: selected})
        end

      [_ | _] = many ->
        raise "Ambiguous match: found #{length(many)} labels matching: #{inspect(label)}"
    end
  end

  # ---------------------------------------------------------------------------
  # Shared helpers (used by Mirage.fill_in as well)
  # ---------------------------------------------------------------------------

  # Walks the AST once, tracking the nearest enclosing `<form>`'s `$change`
  # attribute. Returns `{labels, inputs_by_id}` where:
  #   * labels = [{label_node, wrapped_input_or_nil, form_change_or_nil}, ...]
  #   * inputs_by_id = %{"id" => {input_node, form_change_or_nil}}
  @doc false
  def collect_form_nodes(nodes, form_change) when is_list(nodes) do
    Enum.reduce(nodes, {[], %{}}, fn node, {labels, inputs} ->
      {l, i} = collect_form_nodes(node, form_change)
      {labels ++ l, Map.merge(inputs, i)}
    end)
  end

  @doc false
  def collect_form_nodes({:element, "form", attrs, children}, _form_change) do
    collect_form_nodes(children, DOM.find_attr(attrs, "$change"))
  end

  @doc false
  def collect_form_nodes({:element, "label", _attrs, children} = node, form_change) do
    {nested_labels, nested_inputs} = collect_form_nodes(children, form_change)
    wrapped = find_nested_input(children)
    {[{node, wrapped, form_change} | nested_labels], nested_inputs}
  end

  @doc false
  def collect_form_nodes({:element, tag, attrs, children} = node, form_change)
      when tag in ["input", "textarea", "select"] do
    {nested_labels, nested_inputs} = collect_form_nodes(children, form_change)

    inputs =
      case DOM.find_attr(attrs, "id") do
        nil -> nested_inputs
        id -> Map.put(nested_inputs, DOM.attr_to_string(id), {node, form_change})
      end

    {nested_labels, inputs}
  end

  @doc false
  def collect_form_nodes({:element, _tag, _attrs, children}, form_change) do
    collect_form_nodes(children, form_change)
  end

  @doc false
  def collect_form_nodes(_other, _form_change), do: {[], %{}}

  @doc false
  def resolve_input({_label, {:element, _, _, _} = input, form_change}, _by_id, _label_text) do
    {input, form_change}
  end

  @doc false
  def resolve_input({{:element, "label", attrs, _children}, nil, _fc}, by_id, label_text) do
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

  @doc false
  def trigger_input_action(session, {:element, _tag, attrs, _children}, value) do
    case DOM.find_attr(attrs, "$change") do
      nil -> session
      action -> Events.dispatch_event(session, action, %{value: value})
    end
  end

  @doc false
  def trigger_form_change(session, nil, _value), do: session

  @doc false
  def trigger_form_change(session, form_change, value) do
    Events.dispatch_event(session, form_change, %{value: value})
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp find_nested_input(nodes) when is_list(nodes) do
    Enum.find_value(nodes, &find_nested_input/1)
  end

  defp find_nested_input({:element, tag, _attrs, _children} = node)
       when tag in ["input", "textarea", "select"],
       do: node

  defp find_nested_input({:element, _tag, _attrs, children}), do: find_nested_input(children)
  defp find_nested_input(_other), do: nil

  # Computes the visible text of a label node, excluding any nested form
  # control elements. Necessary for select labels whose inner_text would
  # otherwise include all option texts.
  defp label_text_without_inputs(node) do
    case node do
      {:element, tag, _, _} when tag in ["input", "select", "textarea"] ->
        ""

      {:element, _, _, children} ->
        label_text_without_inputs(children)

      {:text, text} ->
        text

      nodes when is_list(nodes) ->
        Enum.map_join(nodes, "", &label_text_without_inputs/1)

      _ ->
        ""
    end
  end

  defp collect_options(nodes) when is_list(nodes) do
    Enum.flat_map(nodes, &collect_options/1)
  end

  defp collect_options({:element, "option", attrs, _children} = node) do
    text = String.trim(DOM.inner_text(node))

    value =
      case DOM.find_attr(attrs, "value") do
        nil -> text
        v -> DOM.attr_to_string(v)
      end

    [{text, value}]
  end

  defp collect_options({:element, "optgroup", _attrs, children}), do: collect_options(children)
  defp collect_options(_other), do: []

  defp input_value({:element, "textarea", _attrs, children}) do
    DOM.inner_text({:element, "textarea", [], children})
  end

  defp input_value({:element, "input", attrs, _}) do
    case DOM.find_attr(attrs, "value") do
      nil -> ""
      v -> DOM.attr_to_string(v)
    end
  end

  @text_input_types ~w(text email password search tel url number)

  defp validate_text_input!({:element, "textarea", _, _}, _label), do: :ok

  defp validate_text_input!({:element, "input", attrs, _}, label) do
    type =
      case DOM.find_attr(attrs, "type") do
        nil -> "text"
        v -> DOM.attr_to_string(v)
      end

    unless type in @text_input_types do
      raise "Label #{inspect(label)} points to an input[type=#{type}], which does not accept text selection"
    end

    :ok
  end

  defp validate_text_input!({:element, "select", _, _}, label) do
    raise "Label #{inspect(label)} points to a <select>, which does not accept text selection"
  end
end
