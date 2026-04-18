defmodule Mirage.Query do
  @moduledoc false

  alias Mirage.DOM
  alias Meeseeks.Selector.Element

  alias Meeseeks.Selector.Element.{Namespace, Tag}

  alias Meeseeks.Selector.Element.Attribute.{
    Attribute,
    AttributePrefix,
    Value,
    ValueContains,
    ValueDash,
    ValueIncludes,
    ValuePrefix,
    ValueSuffix
  }

  alias Meeseeks.Selector.Element.PseudoClass.{
    FirstChild,
    FirstOfType,
    LastChild,
    LastOfType,
    Not,
    NthChild,
    NthLastChild,
    NthLastOfType,
    NthOfType
  }

  alias Meeseeks.Selector.Combinator.{
    ChildElements,
    DescendantElements,
    NextSiblingElement,
    NextSiblingElements
  }

  @doc """
  Returns all AST nodes matching the given CSS selector string.
  """
  def query_all(ast, selector) when is_binary(selector) do
    parsed = Meeseeks.Selector.CSS.compile_selectors(selector)
    nodes = List.wrap(ast)

    parsed
    |> List.wrap()
    |> Enum.flat_map(&find_in_tree(nodes, &1))
  end

  @doc """
  Returns a single AST node matching the CSS selector.

  Raises if no elements or more than one element match.
  """
  def query_one(ast, selector) when is_binary(selector) do
    case query_all(ast, selector) do
      [node] ->
        node

      [] ->
        raise "No element found matching selector: #{inspect(selector)}"

      nodes ->
        raise "Expected 1 element matching #{inspect(selector)}, found #{length(nodes)}"
    end
  end

  # ---------------------------------------------------------------------------
  # Tree walking
  # ---------------------------------------------------------------------------

  # Walk the full tree, collecting all elements that satisfy the complete
  # selector chain (compound selector + any combinators).
  defp find_in_tree(nodes, selector) when is_list(nodes) do
    siblings = elements_only(nodes)
    do_find_in_tree(nodes, selector, siblings, 0)
  end

  defp do_find_in_tree([], _selector, _siblings, _idx), do: []

  defp do_find_in_tree([{:element, _, _, children} = node | rest], selector, siblings, idx) do
    own =
      if match_compound?(node, selector, siblings, idx) do
        follow(node, siblings, idx, selector.combinator)
      else
        []
      end

    own ++
      find_in_tree(children, selector) ++
      do_find_in_tree(rest, selector, siblings, idx + 1)
  end

  defp do_find_in_tree([_ | rest], selector, siblings, idx) do
    do_find_in_tree(rest, selector, siblings, idx)
  end

  # Match only among direct children (for the `>` combinator).
  defp find_in_children(children, selector) do
    siblings = elements_only(children)
    do_find_in_children(children, selector, siblings, 0)
  end

  defp do_find_in_children([], _selector, _siblings, _idx), do: []

  defp do_find_in_children([{:element, _, _, _} = node | rest], selector, siblings, idx) do
    own =
      if match_compound?(node, selector, siblings, idx) do
        follow(node, siblings, idx, selector.combinator)
      else
        []
      end

    own ++ do_find_in_children(rest, selector, siblings, idx + 1)
  end

  defp do_find_in_children([_ | rest], selector, siblings, idx) do
    do_find_in_children(rest, selector, siblings, idx)
  end

  # ---------------------------------------------------------------------------
  # Combinator following
  # ---------------------------------------------------------------------------

  defp follow(node, _siblings, _idx, nil), do: [node]

  defp follow({:element, _, _, children}, _siblings, _idx, %DescendantElements{selector: sel}) do
    find_in_tree(children, sel)
  end

  defp follow({:element, _, _, children}, _siblings, _idx, %ChildElements{selector: sel}) do
    find_in_children(children, sel)
  end

  defp follow(_node, siblings, idx, %NextSiblingElement{selector: sel}) do
    case Enum.at(siblings, idx + 1) do
      nil ->
        []

      next ->
        if match_compound?(next, sel, siblings, idx + 1) do
          follow(next, siblings, idx + 1, sel.combinator)
        else
          []
        end
    end
  end

  defp follow(_node, siblings, idx, %NextSiblingElements{selector: sel}) do
    siblings
    |> Enum.drop(idx + 1)
    |> Enum.with_index(idx + 1)
    |> Enum.flat_map(fn {sib, sib_idx} ->
      if match_compound?(sib, sel, siblings, sib_idx) do
        follow(sib, siblings, sib_idx, sel.combinator)
      else
        []
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Compound selector matching
  # ---------------------------------------------------------------------------

  # A compound selector (e.g. `div.active[data-x]`) matches when ALL of its
  # simple selectors match the same element.
  defp match_compound?({:element, _, _, _} = node, %Element{selectors: selectors}, siblings, idx) do
    Enum.all?(selectors, &match_simple?(node, &1, siblings, idx))
  end

  # ---------------------------------------------------------------------------
  # Simple selector matching
  # ---------------------------------------------------------------------------

  # -- Tag --
  defp match_simple?(_, %Tag{value: "*"}, _, _), do: true
  defp match_simple?({:element, tag, _, _}, %Tag{value: t}, _, _), do: tag == t

  # -- Namespace (Hologram doesn't use namespaces — match `*`, reject others) --
  defp match_simple?(_, %Namespace{value: "*"}, _, _), do: true
  defp match_simple?(_, %Namespace{}, _, _), do: false

  # -- Attribute existence --
  defp match_simple?({:element, _, attrs, _}, %Attribute{attribute: name}, _, _) do
    has_attr?(attrs, name)
  end

  # -- Attribute prefix existence ([^data-]) --
  defp match_simple?({:element, _, attrs, _}, %AttributePrefix{attribute: prefix}, _, _) do
    Enum.any?(attrs, fn {name, _} -> String.starts_with?(name, prefix) end)
  end

  # -- Attribute exact value (also handles #id) --
  defp match_simple?({:element, _, attrs, _}, %Value{attribute: a, value: v}, _, _) do
    get_attr(attrs, a) == v
  end

  # -- Attribute value includes word (also handles .class) --
  defp match_simple?({:element, _, attrs, _}, %ValueIncludes{attribute: a, value: v}, _, _) do
    case get_attr(attrs, a) do
      nil -> false
      str -> v in String.split(str)
    end
  end

  # -- Attribute value dash match ([lang|=en]) --
  defp match_simple?({:element, _, attrs, _}, %ValueDash{attribute: a, value: v}, _, _) do
    case get_attr(attrs, a) do
      nil -> false
      str -> str == v or String.starts_with?(str, v <> "-")
    end
  end

  # -- Attribute value prefix ([href^=https]) --
  defp match_simple?({:element, _, attrs, _}, %ValuePrefix{attribute: a, value: v}, _, _) do
    case get_attr(attrs, a) do
      nil -> false
      str -> String.starts_with?(str, v)
    end
  end

  # -- Attribute value suffix ([src$=.png]) --
  defp match_simple?({:element, _, attrs, _}, %ValueSuffix{attribute: a, value: v}, _, _) do
    case get_attr(attrs, a) do
      nil -> false
      str -> String.ends_with?(str, v)
    end
  end

  # -- Attribute value contains ([href*=admin]) --
  defp match_simple?({:element, _, attrs, _}, %ValueContains{attribute: a, value: v}, _, _) do
    case get_attr(attrs, a) do
      nil -> false
      str -> String.contains?(str, v)
    end
  end

  # -- :first-child --
  defp match_simple?(_, %FirstChild{}, _siblings, idx), do: idx == 0

  # -- :last-child --
  defp match_simple?(_, %LastChild{}, siblings, idx), do: idx == length(siblings) - 1

  # -- :first-of-type --
  defp match_simple?({:element, tag, _, _}, %FirstOfType{}, siblings, idx) do
    index_of_type(tag, siblings, idx) == 0
  end

  # -- :last-of-type --
  defp match_simple?({:element, tag, _, _}, %LastOfType{}, siblings, idx) do
    index_of_type(tag, siblings, idx) == count_of_type(tag, siblings) - 1
  end

  # -- :nth-child --
  defp match_simple?(_, %NthChild{args: args}, _siblings, idx) do
    nth_match?(idx + 1, args)
  end

  # -- :nth-last-child --
  defp match_simple?(_, %NthLastChild{args: args}, siblings, idx) do
    nth_match?(length(siblings) - idx, args)
  end

  # -- :nth-of-type --
  defp match_simple?({:element, tag, _, _}, %NthOfType{args: args}, siblings, idx) do
    nth_match?(index_of_type(tag, siblings, idx) + 1, args)
  end

  # -- :nth-last-of-type --
  defp match_simple?({:element, tag, _, _}, %NthLastOfType{args: args}, siblings, idx) do
    nth_match?(count_of_type(tag, siblings) - index_of_type(tag, siblings, idx), args)
  end

  # -- :not --
  defp match_simple?(node, %Not{args: [selectors]}, siblings, idx) do
    not Enum.any?(selectors, &match_compound?(node, &1, siblings, idx))
  end

  # Catch-all for unrecognised selectors — don't match.
  defp match_simple?(_, _, _, _), do: false

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp elements_only(nodes) do
    Enum.filter(nodes, &match?({:element, _, _, _}, &1))
  end

  defp has_attr?(attrs, name) do
    Enum.any?(attrs, fn {n, _} -> n == name end)
  end

  defp get_attr(attrs, name) do
    case DOM.find_attr(attrs, name) do
      nil -> nil
      value -> DOM.attr_to_string(value)
    end
  end

  # 0-based index of this element among siblings of the same tag type.
  defp index_of_type(tag, siblings, elem_idx) do
    siblings
    |> Enum.take(elem_idx)
    |> Enum.count(fn {:element, t, _, _} -> t == tag end)
  end

  defp count_of_type(tag, siblings) do
    Enum.count(siblings, fn {:element, t, _, _} -> t == tag end)
  end

  # Meeseeks stores nth args as ["even"], ["odd"], [n], or [a, b] (for An+B).
  # The `index` parameter is 1-based.
  defp nth_match?(index, ["even"]), do: nth?(index, 2, 0)
  defp nth_match?(index, ["odd"]), do: nth?(index, 2, 1)
  defp nth_match?(index, [n]) when is_integer(n), do: nth?(index, 0, n)
  defp nth_match?(index, [a, b]) when is_integer(a) and is_integer(b), do: nth?(index, a, b)
  defp nth_match?(_, _), do: false

  defp nth?(index, 0, b), do: index == b

  defp nth?(index, a, b) do
    diff = index - b
    a * diff >= 0 and rem(diff, a) == 0
  end
end
