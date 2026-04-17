defmodule Holography.Assertions do
  @moduledoc false

  alias Holography.DOM
  alias Holography.Query
  alias Holography.Session

  def assert_has(%Session{} = session, selector, opts \\ []) when is_binary(selector) do
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

  def refute_has(%Session{} = session, selector, opts \\ []) when is_binary(selector) do
    matches = find_matches(session.ast, selector, opts)

    case matches do
      [] ->
        session

      nodes ->
        raise "Expected not to find an element matching #{describe(selector, opts)}, but found #{length(nodes)}"
    end
  end

  defp find_matches(ast, selector, opts) do
    text = Keyword.get(opts, :text)
    value = Keyword.get(opts, :value)

    results = Query.query_all(ast, selector)

    results
    |> maybe_filter_text(text)
    |> maybe_filter_value(value)
  end

  defp maybe_filter_text(nodes, nil), do: nodes

  defp maybe_filter_text(nodes, text) do
    Enum.filter(nodes, fn node ->
      String.trim(DOM.inner_text(node)) == text
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
