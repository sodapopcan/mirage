defmodule Holography.Assertions do
  @moduledoc false

  alias Holography.DOM
  alias Holography.Query
  alias Holography.Session

  def assert_has(session, selector, text_or_opts \\ [])

  def assert_has(session, selector, text) when is_binary(text),
    do: assert_has(session, selector, text: text)

  def assert_has(%Session{} = session, selector, opts) when is_binary(selector) and is_list(opts) do
    matches = find_matches(session.ast, selector, opts)

    case matches do
      [] ->
        raise "Expected to find an element matching #{describe(selector, opts)}, but found none"

      [_node] ->
        session

      nodes ->
        raise "Expected to find 1 element matching #{describe(selector, opts)}, but found #{length(nodes)}"
    end
  end

  def assert_has(session, selector, text, opts) when is_binary(text) and is_list(opts),
    do: assert_has(session, selector, Keyword.put(opts, :text, text))

  def refute_has(session, selector, text_or_opts \\ [])

  def refute_has(session, selector, text) when is_binary(text),
    do: refute_has(session, selector, text: text)

  def refute_has(%Session{} = session, selector, opts) when is_binary(selector) and is_list(opts) do
    matches = find_matches(session.ast, selector, opts)

    case matches do
      [] ->
        session

      nodes ->
        raise "Expected not to find an element matching #{describe(selector, opts)}, but found #{length(nodes)}"
    end
  end

  def refute_has(session, selector, text, opts) when is_binary(text) and is_list(opts),
    do: refute_has(session, selector, Keyword.put(opts, :text, text))

  defp find_matches(ast, selector, opts) do
    text = Keyword.get(opts, :text)
    value = Keyword.get(opts, :value)
    exact? = Keyword.get(opts, :exact, true)

    results = Query.query_all(ast, selector)

    results
    |> maybe_filter_text(text, exact?)
    |> maybe_filter_value(value)
  end

  defp maybe_filter_text(nodes, nil, _exact?), do: nodes

  defp maybe_filter_text(nodes, text, true) do
    Enum.filter(nodes, fn node ->
      String.trim(DOM.inner_text(node)) == text
    end)
  end

  defp maybe_filter_text(nodes, text, false) do
    Enum.filter(nodes, fn node ->
      String.contains?(DOM.inner_text(node), text)
    end)
  end

  defp maybe_filter_value(nodes, nil), do: nodes

  defp maybe_filter_value(nodes, value) do
    Enum.filter(nodes, fn {:element, _, attrs, _} ->
      DOM.attr_to_string(DOM.find_attr(attrs, "value")) == value
    end)
  end

  defp describe(selector, opts) do
    parts = [inspect(selector)]

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

    Enum.join(parts, ", ")
  end
end
