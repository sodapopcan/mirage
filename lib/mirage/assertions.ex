defmodule Mirage.Assertions do
  @moduledoc false

  import ExUnit.Assertions

  alias Mirage.DOM
  alias Mirage.Query
  alias Mirage.Session

  def assert_page(session, page_module) do
    remove_prefix = fn mod ->
      mod
      |> to_string()
      |> String.replace(~r/^Elixir\./, "")
    end

    current_module = remove_prefix.(session.page_module)
    expected_module = remove_prefix.(page_module)

    assert session.page_module == page_module,
           "Expected current page to be #{expected_module} but was #{current_module}"

    session
  end

  def assert_has(session, selector, text_or_opts \\ [])

  def assert_has(session, selector, text) when is_binary(text) do
    assert_has(session, selector, text: text)
  end

  def assert_has(%Session{} = session, selector, opts)
      when is_binary(selector) and is_list(opts) do
    matches = find_matches(session, selector, opts)

    assert match?([_], matches),
           "Expected to find exactly 1 element matching #{describe(selector, opts)}, but found #{length(matches)}"

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
    matches = find_matches(session, selector, opts)

    assert match?([], matches),
           "Expected not to find an element matching #{describe(selector, opts)}, found #{length(matches)}"

    session
  end

  def refute_has(session, selector, text, opts) when is_binary(text) and is_list(opts) do
    refute_has(session, selector, Keyword.put(opts, :text, text))
  end

  defp find_matches(%Session{ast: ast, scope: scope}, selector, opts) do
    text = Keyword.get(opts, :text)
    value = Keyword.get(opts, :value)
    exact? = Keyword.get(opts, :exact, true)

    scoped_selector = scope_selector(scope, selector)
    results = Query.query_all(ast, scoped_selector)

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

  defp scope_selector(nil, selector), do: selector
  defp scope_selector(parent, selector), do: "#{parent} #{selector}"

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
