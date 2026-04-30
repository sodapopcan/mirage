defmodule Mirage.Input do
  @moduledoc false

  alias Mirage.DOM
  alias Mirage.Events
  alias Mirage.Scoped

  def fill_in(session, label, opts) do
    Keyword.validate!(opts, [:with, :exact])
    exact? = Keyword.get(opts, :exact, true)
    value = Keyword.fetch!(opts, :with)

    {labels, inputs_by_id} = collect_form_nodes(Scoped.query_ast(session), nil)

    matches =
      Enum.filter(labels, fn {node, _wrapped, _form_change} ->
        DOM.text_matches?(DOM.inner_text(node), label, exact?)
      end)

    case matches do
      [] ->
        raise "No input found with label: #{inspect(label)}"

      [entry] ->
        {input, form_change} = resolve_input(entry, inputs_by_id, label)
        validate_interactive!(input, label)

        session
        |> trigger_input_action(input, value)
        |> update_filled_inputs(input, value)
        |> trigger_form_change(form_change)

      [_ | _] = many ->
        raise "Ambiguous match: found #{length(many)} labels matching: #{inspect(label)}"
    end
  end

  defp update_filled_inputs(session, {:element, _, attrs, _}, value) do
    case DOM.find_attr(attrs, "name") do
      nil ->
        session

      name_attr ->
        update_bookkeeping(
          session,
          :filled_inputs,
          &Map.put(&1, DOM.attr_to_string(name_attr), value)
        )
    end
  end

  def fill_in_hidden(session, name, opts) when is_binary(name) do
    Keyword.validate!(opts, [:with])
    value = Keyword.fetch!(opts, :with)

    ast = Scoped.query_ast(session)
    hidden_inputs = find_hidden_inputs_by_name(ast, name)

    case hidden_inputs do
      [] ->
        raise "No hidden input found with name: #{inspect(name)}"

      [{input, form_change}] ->
        validate_hidden!(input, name)

        session
        |> trigger_input_action(input, value)
        |> update_filled_inputs(input, value)
        |> trigger_form_change(form_change)

      [_ | _] = many ->
        raise "Ambiguous match: found #{length(many)} hidden inputs with name: #{inspect(name)}"
    end
  end

  def choose(session, label, opts \\ []) do
    validate_opts!(opts)

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
        validate_interactive!(input, label)
        {:element, _, attrs, _} = input

        name =
          case DOM.find_attr(attrs, "name") do
            nil -> nil
            value -> DOM.attr_to_string(value)
          end

        value =
          case DOM.find_attr(attrs, "value") do
            nil -> ""
            value -> DOM.attr_to_string(value)
          end

        session
        |> trigger_input_action(input, value)
        |> update_bookkeeping(:checked_radios, &Map.put(&1, name, value))
        |> trigger_form_change(form_change)

      [_ | _] = many ->
        raise "Ambiguous match: found #{length(many)} labels matching: #{inspect(label)}"
    end
  end

  def check(session, label, opts \\ []) do
    validate_opts!(opts)

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
        validate_interactive!(input, label)
        {:element, _, attrs, _} = input

        name =
          case DOM.find_attr(attrs, "name") do
            nil -> nil
            value -> DOM.attr_to_string(value)
          end

        value =
          case DOM.find_attr(attrs, "value") do
            nil -> "on"
            value -> DOM.attr_to_string(value)
          end

        session
        |> trigger_input_action(input, value)
        |> update_bookkeeping(:checked_checkboxes, &MapSet.put(&1, {name, value}))
        |> trigger_form_change(form_change)

      [_ | _] = many ->
        raise "Ambiguous match: found #{length(many)} labels matching: #{inspect(label)}"
    end
  end

  def uncheck(session, label, opts \\ []) do
    validate_opts!(opts)

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
        validate_interactive!(input, label)
        {:element, _, attrs, _} = input

        name =
          case DOM.find_attr(attrs, "name") do
            nil -> nil
            name -> DOM.attr_to_string(name)
          end

        value =
          case DOM.find_attr(attrs, "value") do
            nil -> "on"
            value -> DOM.attr_to_string(value)
          end

        session
        |> trigger_input_action(input, value)
        |> update_bookkeeping(:checked_checkboxes, &MapSet.delete(&1, {name, value}))
        |> trigger_form_change(form_change)

      [_ | _] = many ->
        raise "Ambiguous match: found #{length(many)} labels matching: #{inspect(label)}"
    end
  end

  def select(session, label, option_text, opts \\ []) do
    validate_opts!(opts)

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
        validate_interactive!(select_node, label)
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
                value -> DOM.attr_to_string(value)
              end

            multiple? = DOM.find_attr(attrs, "multiple") != nil

            session
            |> trigger_input_action(select_node, value)
            |> update_bookkeeping(:selected_options, fn current ->
              existing = Map.get(current, name, MapSet.new())
              new_set = if multiple?, do: MapSet.put(existing, value), else: MapSet.new([value])
              Map.put(current, name, new_set)
            end)
            |> trigger_form_change(form_change)

          [_ | _] = many ->
            raise "Ambiguous match: found #{length(many)} options matching: #{inspect(option_text)}"
        end

      [_ | _] = many ->
        raise "Ambiguous match: found #{length(many)} labels matching: #{inspect(label)}"
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
        value -> DOM.attr_to_string(value)
      end

    [{text, value}]
  end

  defp collect_options({:element, "optgroup", _attrs, children}), do: collect_options(children)
  defp collect_options(_other), do: []

  def select_text(session, label, text_or_opts \\ [])

  def select_text(session, label, text) when is_binary(text) do
    select_text(session, label, text, [])
  end

  def select_text(session, label, opts) when is_list(opts) do
    select_text(session, label, nil, opts)
  end

  def select_text(session, label, text, opts) when is_list(opts) do
    validate_opts!(opts)

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
        validate_interactive!(input, label)
        validate_text_input!(input, label)

        selected = text || input_value(input)
        {:element, _, attrs, _} = input

        case DOM.find_attr(attrs, "$select") do
          nil -> session
          action -> Events.dispatch_event(session, action, %{text: selected}, DOM.find_attr(attrs, "__mirage_target__"))
        end

      [_ | _] = many ->
        raise "Ambiguous match: found #{length(many)} labels matching: #{inspect(label)}"
    end
  end

  @text_input_types ~w(text email password search tel url number)

  defp validate_text_input!({:element, "textarea", _, _}, _label), do: :ok

  defp validate_text_input!({:element, "input", attrs, _}, label) do
    type = input_type(attrs)

    unless type in @text_input_types do
      raise "Label #{inspect(label)} points to an input[type=#{type}], which does not accept text selection"
    end

    :ok
  end

  defp validate_text_input!({:element, "select", _, _}, label) do
    raise "Label #{inspect(label)} points to a <select>, which does not accept text selection"
  end

  defp input_value({:element, "textarea", _attrs, children}) do
    DOM.inner_text({:element, "textarea", [], children})
  end

  defp input_value({:element, "input", attrs, _}) do
    case DOM.find_attr(attrs, "value") do
      nil -> ""
      value -> DOM.attr_to_string(value)
    end
  end

  # ---------------------------------------------------------------------------
  # Shared helpers
  # ---------------------------------------------------------------------------

  # Walks the AST once, tracking the nearest enclosing `<form>`'s `$change`
  # attribute. Returns `{labels, inputs_by_id}` where:
  #   * labels = [{label_node, wrapped_input_or_nil, form_change_or_nil}, ...]
  #   * inputs_by_id = %{"id" => {input_node, form_change_or_nil}}
  def collect_form_nodes(nodes, form_change) when is_list(nodes) do
    Enum.reduce(nodes, {[], %{}}, fn node, {labels, inputs} ->
      {l, i} = collect_form_nodes(node, form_change)
      {labels ++ l, Map.merge(inputs, i)}
    end)
  end

  def collect_form_nodes({:element, "form", attrs, children}, _form_change) do
    collect_form_nodes(children, DOM.find_attr(attrs, "$change"))
  end

  def collect_form_nodes({:element, "label", _attrs, children} = node, form_change) do
    {nested_labels, nested_inputs} = collect_form_nodes(children, form_change)
    wrapped = find_nested_input(children)
    {[{node, wrapped, form_change} | nested_labels], nested_inputs}
  end

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

  def collect_form_nodes({:element, _tag, _attrs, children}, form_change) do
    collect_form_nodes(children, form_change)
  end

  def collect_form_nodes(_other, _form_change), do: {[], %{}}

  defp find_nested_input(nodes) when is_list(nodes) do
    Enum.find_value(nodes, &find_nested_input/1)
  end

  defp find_nested_input({:element, tag, _attrs, _children} = node)
       when tag in ["input", "textarea", "select"],
       do: node

  defp find_nested_input({:element, _tag, _attrs, children}), do: find_nested_input(children)
  defp find_nested_input(_other), do: nil

  def resolve_input({_label, {:element, _, _, _} = input, form_change}, _by_id, _label_text) do
    {input, form_change}
  end

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

  def trigger_input_action(session, {:element, _tag, attrs, _children}, value) do
    case DOM.find_attr(attrs, "$change") do
      nil -> session
      action -> Events.dispatch_event(session, action, %{value: value}, DOM.find_attr(attrs, "__mirage_target__"))
    end
  end

  def trigger_form_change(session, nil), do: session

  def trigger_form_change(session, form_change) do
    form_data = collect_form_values(session.ast, "$change", form_change, session.bookkeeping)
    form_target = find_form_target(session.ast, form_change)
    Events.dispatch_event(session, form_change, form_data, form_target)
  end

  defp find_form_target(nodes, form_change) when is_list(nodes) do
    Enum.find_value(nodes, &find_form_target(&1, form_change))
  end

  defp find_form_target({:element, "form", attrs, children}, form_change) do
    if DOM.find_attr(attrs, "$change") == form_change do
      DOM.find_attr(attrs, "__mirage_target__")
    else
      find_form_target(children, form_change)
    end
  end

  defp find_form_target({:element, _tag, _attrs, children}, form_change) do
    find_form_target(children, form_change)
  end

  defp find_form_target(_, _), do: nil

  defp validate_hidden!({:element, "input", attrs, _}, name) do
    type = input_type(attrs)

    cond do
      type != "hidden" && DOM.find_attr(attrs, "hidden") == nil ->
        raise "Input with name #{inspect(name)} is not hidden"

      DOM.find_attr(attrs, "disabled") != nil ->
        raise "Hidden input with name #{inspect(name)} is disabled and cannot be filled"

      DOM.find_attr(attrs, "readonly") != nil ->
        raise "Hidden input with name #{inspect(name)} is readonly and cannot be filled"

      true ->
        :ok
    end
  end

  defp find_hidden_inputs_by_name(nodes, name, form_change \\ nil)

  defp find_hidden_inputs_by_name(nodes, name, form_change) when is_list(nodes) do
    Enum.flat_map(nodes, &find_hidden_inputs_by_name(&1, name, form_change))
  end

  defp find_hidden_inputs_by_name({:element, "form", attrs, children}, name, _form_change) do
    find_hidden_inputs_by_name(children, name, DOM.find_attr(attrs, "$change"))
  end

  defp find_hidden_inputs_by_name({:element, "input", attrs, _} = node, name, form_change) do
    input_name =
      case DOM.find_attr(attrs, "name") do
        nil -> nil
        attr_value -> DOM.attr_to_string(attr_value)
      end

    if input_name == name, do: [{node, form_change}], else: []
  end

  defp find_hidden_inputs_by_name({:element, _tag, _attrs, children}, name, form_change) do
    find_hidden_inputs_by_name(children, name, form_change)
  end

  defp find_hidden_inputs_by_name(_other, _name, _form_change), do: []

  @doc false
  def validate_interactive!({:element, tag, attrs, _}, label) do
    cond do
      DOM.find_attr(attrs, "hidden") != nil ->
        raise "Input with label #{inspect(label)} is hidden and cannot be interacted with"

      tag == "input" && input_type(attrs) == "hidden" ->
        raise "Input with label #{inspect(label)} is hidden and cannot be interacted with"

      DOM.find_attr(attrs, "disabled") != nil ->
        raise "Input with label #{inspect(label)} is disabled and cannot be interacted with"

      DOM.find_attr(attrs, "readonly") != nil ->
        raise "Input with label #{inspect(label)} is readonly and cannot be interacted with"

      true ->
        :ok
    end
  end

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

  defp input_type(attrs) do
    case DOM.find_attr(attrs, "type") do
      nil -> "text"
      v -> DOM.attr_to_string(v)
    end
  end

  defp update_bookkeeping(session, key, fun) do
    update_in(session.bookkeeping[key], fun)
  end

  defp validate_opts!(opts) do
    Keyword.validate!(opts, [:exact])
  end

  # ---------------------------------------------------------------------------
  # Form value collection
  # ---------------------------------------------------------------------------

  @doc false
  def collect_form_values(ast, attr_name, attr_value, bookkeeping) do
    case find_form_children(ast, attr_name, attr_value) do
      nil -> %{}
      children -> extract_field_values(children, bookkeeping)
    end
  end

  defp find_form_children(nodes, attr_name, attr_value) when is_list(nodes) do
    Enum.find_value(nodes, &find_form_children(&1, attr_name, attr_value))
  end

  defp find_form_children({:element, "form", attrs, children}, attr_name, attr_value) do
    if DOM.find_attr(attrs, attr_name) == attr_value do
      children
    else
      find_form_children(children, attr_name, attr_value)
    end
  end

  defp find_form_children({:element, _tag, _attrs, children}, attr_name, attr_value) do
    find_form_children(children, attr_name, attr_value)
  end

  defp find_form_children(_, _, _), do: nil

  defp extract_field_values(nodes, bookkeeping) when is_list(nodes) do
    Enum.reduce(nodes, %{}, fn node, acc ->
      Map.merge(acc, extract_field_values(node, bookkeeping))
    end)
  end

  defp extract_field_values({:element, "input", attrs, _}, bookkeeping) do
    case field_name(attrs) do
      nil ->
        %{}

      name ->
        type = input_type(attrs)

        cond do
          type == "checkbox" ->
            value = field_value(attrs, "on")

            if MapSet.member?(bookkeeping.checked_checkboxes, {name, value}),
              do: %{name => value},
              else: %{}

          type == "radio" ->
            case Map.get(bookkeeping.checked_radios, name) do
              nil -> %{}
              v -> %{name => v}
            end

          type in ["submit", "button", "image", "reset"] ->
            %{}

          type == "hidden" ->
            value = Map.get(bookkeeping.filled_inputs, name, field_value(attrs, ""))
            %{name => value}

          true ->
            value = Map.get(bookkeeping.filled_inputs, name, field_value(attrs, ""))
            %{name => value}
        end
    end
  end

  defp extract_field_values({:element, "textarea", attrs, children}, bookkeeping) do
    case field_name(attrs) do
      nil ->
        %{}

      name ->
        default = DOM.inner_text({:element, "textarea", [], children})
        value = Map.get(bookkeeping.filled_inputs, name, default)
        %{name => value}
    end
  end

  defp extract_field_values({:element, "select", attrs, _children}, bookkeeping) do
    case field_name(attrs) do
      nil ->
        %{}

      name ->
        case Map.get(bookkeeping.selected_options, name) do
          nil -> %{}
          selected -> %{name => MapSet.to_list(selected) |> List.first()}
        end
    end
  end

  defp extract_field_values({:element, _tag, _attrs, children}, bookkeeping) do
    extract_field_values(children, bookkeeping)
  end

  defp extract_field_values(_, _), do: %{}

  defp field_name(attrs) do
    case DOM.find_attr(attrs, "name") do
      nil -> nil
      v -> DOM.attr_to_string(v)
    end
  end

  defp field_value(attrs, default) do
    case DOM.find_attr(attrs, "value") do
      nil -> default
      v -> DOM.attr_to_string(v)
    end
  end
end
