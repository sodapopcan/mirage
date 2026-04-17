defmodule Mirage.QueryTest do
  use ExUnit.Case, async: true

  alias Mirage.Query

  # Helper to build element tuples concisely.
  defp el(tag, attrs \\ [], children \\ []) do
    attrs = Enum.map(attrs, fn {k, v} -> {k, [{:text, v}]} end)
    {:element, tag, attrs, children}
  end

  describe "query_all/2" do
    test "tag selector" do
      ast = [el("div", [], [el("p"), el("span"), el("p")])]

      assert [
               {:element, "p", _, _},
               {:element, "p", _, _}
             ] = Query.query_all(ast, "p")
    end

    test "universal selector" do
      ast = [el("div", [], [el("p"), el("span")])]
      # * matches all elements: div, p, span
      assert length(Query.query_all(ast, "*")) == 3
    end

    test "id selector" do
      ast = [
        el("div", [], [
          el("p", [{"id", "first"}]),
          el("p", [{"id", "second"}])
        ])
      ]

      assert [
               {:element, "p", [{"id", [{:text, "first"}]}], _}
             ] = Query.query_all(ast, "#first")
    end

    test "class selector" do
      ast = [
        el("div", [], [
          el("p", [{"class", "active"}]),
          el("p", [{"class", "inactive"}]),
          el("p", [{"class", "active highlight"}])
        ])
      ]

      results = Query.query_all(ast, ".active")
      assert length(results) == 2
    end

    test "compound selector (tag + class + id)" do
      ast = [
        el("div", [{"id", "main"}, {"class", "container"}]),
        el("div", [{"id", "other"}, {"class", "container"}]),
        el("span", [{"id", "main"}, {"class", "container"}])
      ]

      assert [
               {:element, "div", _, _}
             ] = Query.query_all(ast, "div#main.container")
    end

    test "comma-separated selectors (selector list)" do
      ast = [el("p"), el("span"), el("div")]

      results = Query.query_all(ast, "p, span")
      assert length(results) == 2

      tags = Enum.map(results, fn {:element, tag, _, _} -> tag end)
      assert "p" in tags
      assert "span" in tags
    end

    test "returns empty list when nothing matches" do
      ast = [el("div")]
      assert [] == Query.query_all(ast, "p")
    end
  end

  describe "attribute selectors" do
    test "[attr] — existence" do
      ast = [
        el("input", [{"type", "text"}]),
        el("input")
      ]

      assert [
               {:element, "input", [{"type", _}], _}
             ] = Query.query_all(ast, "[type]")
    end

    test "[attr=val] — exact value" do
      ast = [
        el("input", [{"type", "text"}]),
        el("input", [{"type", "hidden"}])
      ]

      assert [
               {:element, "input", [{"type", [{:text, "text"}]}], _}
             ] = Query.query_all(ast, "[type=text]")
    end

    test "[attr~=val] — word in whitespace-separated list" do
      ast = [
        el("div", [{"class", "foo bar baz"}]),
        el("div", [{"class", "foobar"}])
      ]

      assert [
               {:element, "div", [{"class", [{:text, "foo bar baz"}]}], _}
             ] = Query.query_all(ast, "[class~=bar]")
    end

    test "[attr|=val] — exact or prefix with hyphen" do
      ast = [
        el("p", [{"lang", "en"}]),
        el("p", [{"lang", "en-US"}]),
        el("p", [{"lang", "fr"}])
      ]

      assert length(Query.query_all(ast, "[lang|=en]")) == 2
    end

    test "[attr^=val] — starts with" do
      ast = [
        el("a", [{"href", "https://example.com"}]),
        el("a", [{"href", "http://example.com"}])
      ]

      assert [
               {:element, "a", [{"href", [{:text, "https://example.com"}]}], _}
             ] = Query.query_all(ast, "[href^=https]")
    end

    test "[attr$=val] — ends with" do
      ast = [
        el("img", [{"src", "photo.png"}]),
        el("img", [{"src", "photo.jpg"}])
      ]

      assert [
               {:element, "img", [{"src", [{:text, "photo.png"}]}], _}
             ] = Query.query_all(ast, "[src$=png]")
    end

    test "[attr*=val] — contains" do
      ast = [
        el("a", [{"href", "/admin/users"}]),
        el("a", [{"href", "/public/home"}])
      ]

      assert [
               {:element, "a", [{"href", [{:text, "/admin/users"}]}], _}
             ] = Query.query_all(ast, "[href*=admin]")
    end

    test "[^attrPrefix] — attribute name prefix" do
      ast = [
        el("div", [{"data-id", "1"}, {"data-name", "foo"}]),
        el("div", [{"class", "plain"}])
      ]

      assert [
               {:element, "div", [{"data-id", _}, {"data-name", _}], _}
             ] = Query.query_all(ast, "[^data-]")
    end
  end

  describe "combinators" do
    test "descendant combinator (space)" do
      ast = [
        el("div", [], [
          el("p", [], [
            el("span", [{"class", "deep"}])
          ])
        ])
      ]

      assert [
               {:element, "span", _, _}
             ] = Query.query_all(ast, "div span")
    end

    test "child combinator (>)" do
      ast = [
        el("ul", [], [
          el("li", [{"class", "direct"}]),
          el("div", [], [
            el("li", [{"class", "nested"}])
          ])
        ])
      ]

      results = Query.query_all(ast, "ul > li")
      assert length(results) == 1
      [{:element, "li", attrs, _}] = results
      assert [{"class", [{:text, "direct"}]}] = attrs
    end

    test "adjacent sibling combinator (+)" do
      ast = [
        el("h1"),
        el("p", [{"class", "first"}]),
        el("p", [{"class", "second"}])
      ]

      results = Query.query_all(ast, "h1 + p")
      assert length(results) == 1
      [{:element, "p", attrs, _}] = results
      assert [{"class", [{:text, "first"}]}] = attrs
    end

    test "general sibling combinator (~)" do
      ast = [
        el("h1"),
        el("p", [{"class", "first"}]),
        el("p", [{"class", "second"}])
      ]

      results = Query.query_all(ast, "h1 ~ p")
      assert length(results) == 2
    end

    test "chained combinators" do
      ast = [
        el("div", [], [
          el("ul", [], [
            el("li", [{"class", "a"}]),
            el("li", [{"class", "b"}])
          ])
        ])
      ]

      results = Query.query_all(ast, "div > ul > li")
      assert length(results) == 2
    end

    test "descendant does not match self" do
      ast = [el("div")]
      assert [] == Query.query_all(ast, "div div")
    end
  end

  describe "pseudo-classes" do
    setup do
      ast = [
        el("ul", [], [
          el("li", [{"class", "a"}]),
          el("li", [{"class", "b"}]),
          el("li", [{"class", "c"}]),
          el("li", [{"class", "d"}])
        ])
      ]

      {:ok, ast: ast}
    end

    test ":first-child", %{ast: ast} do
      [result] = Query.query_all(ast, "li:first-child")
      {:element, "li", [{"class", [{:text, "a"}]}], _} = result
    end

    test ":last-child", %{ast: ast} do
      [result] = Query.query_all(ast, "li:last-child")
      {:element, "li", [{"class", [{:text, "d"}]}], _} = result
    end

    test ":nth-child(2)", %{ast: ast} do
      [result] = Query.query_all(ast, "li:nth-child(2)")
      {:element, "li", [{"class", [{:text, "b"}]}], _} = result
    end

    test ":nth-child(even)", %{ast: ast} do
      results = Query.query_all(ast, "li:nth-child(even)")
      assert length(results) == 2

      classes =
        Enum.map(results, fn {:element, _, [{_, [{:text, c}]}], _} -> c end)

      assert classes == ["b", "d"]
    end

    test ":nth-child(odd)", %{ast: ast} do
      results = Query.query_all(ast, "li:nth-child(odd)")
      assert length(results) == 2

      classes =
        Enum.map(results, fn {:element, _, [{_, [{:text, c}]}], _} -> c end)

      assert classes == ["a", "c"]
    end

    test ":nth-last-child(1) matches last element", %{ast: ast} do
      [result] = Query.query_all(ast, "li:nth-last-child(1)")
      {:element, "li", [{"class", [{:text, "d"}]}], _} = result
    end

    test ":not()" do
      ast = [
        el("p", [{"class", "keep"}]),
        el("p", [{"class", "skip"}]),
        el("p")
      ]

      results = Query.query_all(ast, "p:not(.skip)")
      assert length(results) == 2
    end
  end

  describe ":first-of-type / :last-of-type / :nth-of-type" do
    test ":first-of-type matches first element of its tag among siblings" do
      ast = [
        el("div"),
        el("p", [{"class", "first-p"}]),
        el("span"),
        el("p", [{"class", "second-p"}])
      ]

      [result] = Query.query_all(ast, "p:first-of-type")
      {:element, "p", [{"class", [{:text, "first-p"}]}], _} = result
    end

    test ":last-of-type matches last element of its tag among siblings" do
      ast = [
        el("p", [{"class", "first-p"}]),
        el("span"),
        el("p", [{"class", "second-p"}])
      ]

      [result] = Query.query_all(ast, "p:last-of-type")
      {:element, "p", [{"class", [{:text, "second-p"}]}], _} = result
    end

    test ":nth-of-type(2)" do
      ast = [
        el("div"),
        el("p", [{"class", "first-p"}]),
        el("div"),
        el("p", [{"class", "second-p"}])
      ]

      [result] = Query.query_all(ast, "p:nth-of-type(2)")
      {:element, "p", [{"class", [{:text, "second-p"}]}], _} = result
    end

    test ":nth-last-of-type(1) matches last of type" do
      ast = [
        el("p", [{"class", "first-p"}]),
        el("span"),
        el("p", [{"class", "second-p"}])
      ]

      [result] = Query.query_all(ast, "p:nth-last-of-type(1)")
      {:element, "p", [{"class", [{:text, "second-p"}]}], _} = result
    end
  end

  describe "query_one/2" do
    test "returns the single matching element" do
      ast = [el("div", [{"id", "only"}])]

      assert {:element, "div", _, _} = Query.query_one(ast, "#only")
    end

    test "raises when no element matches" do
      ast = [el("div")]

      assert_raise RuntimeError, ~r/No element found/, fn ->
        Query.query_one(ast, "#missing")
      end
    end

    test "raises when multiple elements match" do
      ast = [el("p"), el("p")]

      assert_raise RuntimeError, ~r/Expected 1 element/, fn ->
        Query.query_one(ast, "p")
      end
    end
  end

  describe "integration with Mirage.visit" do
    test "queries expanded page AST by tag" do
      session = Mirage.visit(Mirage.ClickPage)
      results = Query.query_all(session.ast, "button")
      assert length(results) == 1
    end

    test "queries expanded page AST by attribute" do
      session = Mirage.visit(Mirage.AssertHasValuePage)
      results = Query.query_all(session.ast, "input[value=alice]")
      assert length(results) == 1
    end

    test "queries nested structure with descendant combinator" do
      session = Mirage.visit(Mirage.AssertHasTextPage)
      results = Query.query_all(session.ast, "ul li")
      assert length(results) == 3
    end

    test "queries with child combinator" do
      session = Mirage.visit(Mirage.AssertHasTextPage)
      spans_in_li = Query.query_all(session.ast, "li > span")
      assert length(spans_in_li) == 3
    end
  end
end
