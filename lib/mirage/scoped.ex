defmodule Mirage.Scoped do
  @moduledoc false

  alias Mirage.DOM
  alias Mirage.Query
  alias Mirage.Session

  def within(%Session{} = session, selector, fun) when is_binary(selector) and is_function(fun, 1) do
    new_scope = scope_selector(session.scope, selector)
    validate_scope!(session.ast, new_scope)
    scoped = %{session | scope: new_scope}
    result = fun.(scoped)
    %{result | scope: session.scope}
  end

  def within_article(%Session{} = session, header, fun)
      when is_binary(header) and is_function(fun, 1) do
    within_tag(session, "article", header, fun)
  end

  def within_section(%Session{} = session, header, fun)
      when is_binary(header) and is_function(fun, 1) do
    within_tag(session, "section", header, fun)
  end

  # ---------------------------------------------------------------------------
  # Helpers used by other modules (Events, Assertions, Mirage)
  # ---------------------------------------------------------------------------

  @doc false
  def scope_selector(nil, selector), do: selector
  def scope_selector(parent, selector), do: "#{parent} #{selector}"

  @doc false
  def scoped_ast(%Session{ast: ast, scope: nil}), do: ast
  def scoped_ast(%Session{ast: ast, scope: scope}), do: [validate_scope!(ast, scope)]

  @doc false
  def validate_scope!(ast, scope) do
    case Query.query_all(ast, scope) do
      [node] -> node
      [] -> raise "Scope selector #{inspect(scope)} matched no elements"
      nodes -> raise "Scope selector #{inspect(scope)} matched #{length(nodes)} elements, expected 1"
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp within_tag(session, tag, header, fun) do
    ast = scoped_ast(session)
    matches = Query.query_all(ast, tag)

    match =
      Enum.filter(matches, fn node ->
        DOM.first_header_text(node) == header
      end)

    case match do
      [{:element, _, _, _} = node] ->
        prev_ast = session.ast
        prev_scope = session.scope
        scoped = %{session | ast: [node], scope: nil}
        result = fun.(scoped)
        %{result | ast: prev_ast, scope: prev_scope}

      [] ->
        raise "No <#{tag}> found with header #{inspect(header)}"

      many ->
        raise "Ambiguous match: found #{length(many)} <#{tag}> elements with header #{inspect(header)}"
    end
  end
end
