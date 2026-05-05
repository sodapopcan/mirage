defmodule Mirage.Assertions do
  @moduledoc false

  import ExUnit.Assertions

  alias Mirage.DOM
  alias Mirage.Input
  alias Mirage.Query
  alias Mirage.Scoped
  alias Mirage.Session

  def assert_page(session, page_module, expected_params \\ [])

  def assert_page(session, page_module, expected_params) do
    remove_prefix = fn mod ->
      mod
      |> to_string()
      |> String.replace(~r/^Elixir\./, "")
    end

    current_module = remove_prefix.(session.page_module)
    expected_module = remove_prefix.(page_module)

    assert session.page_module == page_module,
           "Expected current page to be #{expected_module} but was #{current_module}"

    for {key, value} <- expected_params do
      actual = Map.get(session.params, key)

      assert actual == value,
             "Expected param #{inspect(key)} to be #{inspect(value)} but was #{inspect(actual)}"
    end

    session
  end

  def assert_has(session, selector, text_or_opts \\ [])

  def assert_has(session, selector, text) when is_binary(text) do
    assert_has(session, selector, text: text)
  end

  def assert_has(%Session{} = session, selector, opts)
      when is_binary(selector) and is_list(opts) do
    validate_opts!(opts)

    matches = find_matches(session, selector, opts)
    count = Keyword.get(opts, :count, 1)

    noun = if count == 1, do: "element", else: "elements"

    assert length(matches) == count,
           "Expected to find exactly #{count} #{noun} matching #{describe(selector, opts)}, but found #{length(matches)}"

    session
  end

  def assert_has(session, selector, text, opts) when is_binary(text) and is_list(opts) do
    assert_has(session, selector, Keyword.put(opts, :text, text))
  end

  def refute_has(session, selector, text_or_opts \\ [])

  def refute_has(session, selector, text) when is_binary(text) do
    refute_has(session, selector, text: text)
  end

  def refute_has(%Session{} = session, selector, opts)
      when is_binary(selector) and is_list(opts) do
    validate_opts!(opts)

    matches = find_matches(session, selector, opts)

    assert match?([], matches),
           "Expected not to find an element matching #{describe(selector, opts)}, found #{length(matches)}"

    session
  end

  def refute_has(session, selector, text, opts) when is_binary(text) and is_list(opts) do
    refute_has(session, selector, Keyword.put(opts, :text, text))
  end

  defp find_matches(%Session{} = session, selector, opts) do
    text = Keyword.get(opts, :text)
    value = Keyword.get(opts, :value)
    label = Keyword.get(opts, :label)
    at = Keyword.get(opts, :at)
    exact? = Keyword.get(opts, :exact, true)

    results = Query.query_all(Scoped.query_ast(session), selector)

    results
    |> maybe_filter_at(at)
    |> maybe_filter_text(text, exact?)
    |> maybe_filter_value(value)
    |> maybe_filter_label(label, exact?, session)
  end

  defp maybe_filter_at(nodes, nil), do: nodes

  defp maybe_filter_at(nodes, index) when is_integer(index) do
    case Enum.at(nodes, index - 1) do
      nil -> []
      node -> [node]
    end
  end

  defp maybe_filter_text(nodes, nil, _exact?), do: nodes

  defp maybe_filter_text(nodes, text, true) do
    Enum.filter(nodes, fn node ->
      String.trim(DOM.inner_text(node)) == String.trim(text)
    end)
  end

  defp maybe_filter_text(nodes, text, false) do
    Enum.filter(nodes, fn node ->
      String.contains?(DOM.inner_text(node), String.trim(text))
    end)
  end

  defp maybe_filter_value(nodes, nil), do: nodes

  defp maybe_filter_value(nodes, value) do
    trimmed = String.trim(value)

    Enum.filter(nodes, fn {:element, _, attrs, _} ->
      String.trim(DOM.attr_to_string(DOM.find_attr(attrs, "value"))) == trimmed
    end)
  end

  defp maybe_filter_label(nodes, nil, _exact?, _session), do: nodes

  defp maybe_filter_label(nodes, label, exact?, session) do
    ast = Scoped.query_ast(session)
    {labels, inputs_by_id} = Input.collect_form_nodes(ast, nil)

    labelled_inputs =
      labels
      |> Enum.filter(fn {node, _wrapped, _form_change} ->
        DOM.text_matches?(DOM.inner_text(node), label, exact?)
      end)
      |> Enum.flat_map(fn {_label_node, wrapped, _fc} = entry ->
        case wrapped do
          {:element, _, _, _} ->
            [wrapped]

          nil ->
            case Input.resolve_input(entry, inputs_by_id, label) do
              {input, _form_change} -> [input]
              _ -> []
            end
        end
      end)

    Enum.filter(nodes, fn node -> node in labelled_inputs end)
  end

  def assert_disabled(%Session{} = session, label, opts \\ []) when is_binary(label) do
    exact? = Keyword.get(opts, :exact, true)
    input = find_labelled_input!(session, label, exact?)
    {:element, _, attrs, _} = input

    assert DOM.find_attr(attrs, "disabled") != nil,
           "Expected input with label #{inspect(label)} to be disabled, but it is not"

    session
  end

  def refute_disabled(%Session{} = session, label, opts \\ []) when is_binary(label) do
    exact? = Keyword.get(opts, :exact, true)
    input = find_labelled_input!(session, label, exact?)
    {:element, _, attrs, _} = input

    assert DOM.find_attr(attrs, "disabled") == nil,
           "Expected input with label #{inspect(label)} not to be disabled, but it is"

    session
  end

  def assert_readonly(%Session{} = session, label, opts \\ []) when is_binary(label) do
    exact? = Keyword.get(opts, :exact, true)
    input = find_labelled_input!(session, label, exact?)
    {:element, _, attrs, _} = input

    assert DOM.find_attr(attrs, "readonly") != nil,
           "Expected input with label #{inspect(label)} to be readonly, but it is not"

    session
  end

  def refute_readonly(%Session{} = session, label, opts \\ []) when is_binary(label) do
    exact? = Keyword.get(opts, :exact, true)
    input = find_labelled_input!(session, label, exact?)
    {:element, _, attrs, _} = input

    assert DOM.find_attr(attrs, "readonly") == nil,
           "Expected input with label #{inspect(label)} not to be readonly, but it is"

    session
  end

  defp find_labelled_input!(session, label, exact?) do
    ast = Scoped.query_ast(session)
    {labels, inputs_by_id} = Input.collect_form_nodes(ast, nil)

    matches =
      Enum.filter(labels, fn {node, _wrapped, _form_change} ->
        DOM.text_matches?(DOM.inner_text(node), label, exact?)
      end)

    case matches do
      [] ->
        raise "No input found with label: #{inspect(label)}"

      [entry] ->
        {input, _form_change} = Input.resolve_input(entry, inputs_by_id, label)
        input

      [_ | _] = many ->
        raise "Ambiguous match: found #{length(many)} labels matching: #{inspect(label)}"
    end
  end

  defp describe(selector, opts) do
    parts = [inspect(selector)]

    parts =
      case Keyword.get(opts, :at) do
        nil -> parts
        at -> parts ++ ["at: #{at}"]
      end

    parts =
      case Keyword.get(opts, :text) do
        nil -> parts
        text -> parts ++ ["text: #{inspect(text)}"]
      end

    parts =
      case Keyword.get(opts, :value) do
        nil -> parts
        value -> parts ++ ["value: #{inspect(value)}"]
      end

    parts =
      case Keyword.get(opts, :label) do
        nil -> parts
        label -> parts ++ ["label: #{inspect(label)}"]
      end

    parts =
      case Keyword.get(opts, :count) do
        nil -> parts
        count -> parts ++ ["count: #{count}"]
      end

    Enum.join(parts, ", ")
  end

  defp validate_opts!(opts) do
    Keyword.validate!(opts, [:text, :value, :at, :exact, :label, :count])
  end
end
