defmodule Mirage.Scoped do
  @moduledoc false

  alias Mirage.DOM
  alias Mirage.Query
  alias Mirage.Session

  def within(%Session{} = session, selector, fun)
      when is_binary(selector) and is_function(fun, 1) do
    node = find_scope_node!(query_ast(session), selector)
    prev_scope = session.scope
    result = fun.(%{session | scope: node})
    %{result | scope: prev_scope}
  end

  def within_article(%Session{} = session, header, fun)
      when is_binary(header) and is_function(fun, 1) do
    within_tag(session, "article", header, fun)
  end

  def within_section(%Session{} = session, header, fun)
      when is_binary(header) and is_function(fun, 1) do
    within_tag(session, "section", header, fun)
  end

  @doc false
  # Returns the AST to query against: the scoped node (as a single-element
  # list) when inside a within block, otherwise the full page AST.
  def query_ast(%Session{scope: nil, ast: ast}), do: ast
  def query_ast(%Session{scope: node}), do: [node]

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp within_tag(session, tag, header, fun) do
    matches =
      query_ast(session)
      |> Query.query_all(tag)
      |> Enum.filter(fn node -> DOM.first_header_text(node) == header end)

    case matches do
      [{:element, _, _, _} = node] ->
        prev_scope = session.scope
        result = fun.(%{session | scope: node})
        %{result | scope: prev_scope}

      [] ->
        raise "No <#{tag}> found with header #{inspect(header)}"

      many ->
        raise "Ambiguous match: found #{length(many)} <#{tag}> elements with header #{inspect(header)}"
    end
  end

  defp find_scope_node!(ast, selector) do
    case Query.query_all(ast, selector) do
      [node] ->
        node

      [] ->
        raise "Scope selector #{inspect(selector)} matched no elements"

      nodes ->
        raise "Scope selector #{inspect(selector)} matched #{length(nodes)} elements, expected 1"
    end
  end
end
