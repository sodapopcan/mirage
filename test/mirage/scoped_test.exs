defmodule Mirage.ScopingTest do
  use ExUnit.Case, async: true

  describe "within/3" do
    test "scopes assert_has to descendants of the selector" do
      Mirage.WithinPage
      |> Mirage.visit()
      |> Mirage.within("div.sidebar", fn session ->
        session
        |> Mirage.assert_has("a.nav", "Sidebar link")
        |> Mirage.refute_has("a.nav", "Main link")
      end)
    end

    test "scopes refute_has to descendants of the selector" do
      Mirage.WithinPage
      |> Mirage.visit()
      |> Mirage.within("span.main", fn session ->
        session
        |> Mirage.assert_has("a.nav", "Main link")
        |> Mirage.refute_has("a.nav", "Sidebar link")
      end)
    end

    test "scopes click to descendants of the selector" do
      session =
        Mirage.WithinPage
        |> Mirage.visit()
        |> Mirage.within("div.sidebar", fn session ->
          Mirage.click(session, "a.nav", "Sidebar link")
        end)

      assert session.page.state.clicked == :div
    end

    test "click inside within does not find elements outside scope" do
      session = Mirage.visit(Mirage.WithinPage)

      assert_raise RuntimeError, ~r/No clickable element found/, fn ->
        Mirage.within(session, "span.main", fn session ->
          Mirage.click(session, "a.nav", "Sidebar link")
        end)
      end
    end

    test "scopes fill_in to descendants of the selector" do
      session =
        Mirage.WithinPage
        |> Mirage.visit()
        |> Mirage.within("div.sidebar", fn session ->
          Mirage.fill_in(session, "Sidebar input", with: "hello")
        end)

      assert session.page.state.clicked == :div
    end

    test "restores scope to nil after the block returns" do
      result =
        Mirage.WithinPage
        |> Mirage.visit()
        |> Mirage.within("div.sidebar", fn session ->
          Mirage.assert_has(session, "a.nav", "Sidebar link")
        end)

      assert result.scope == nil
    end

    test "nests — inner within searches within the outer scope" do
      Mirage.WithinPage
      |> Mirage.visit()
      |> Mirage.within("div.sidebar", fn session ->
        # span.main is not inside div.sidebar, so it won't be found
        assert_raise RuntimeError, ~r/Scope selector.*matched no elements/, fn ->
          Mirage.within(session, "span.main", fn session ->
            Mirage.click(session, "a.nav")
          end)
        end

        session
      end)
    end

    test "nested within restores to outer scope, not nil" do
      Mirage.WithinPage
      |> Mirage.visit()
      |> Mirage.within("div.sidebar", fn outer_session ->
        outer_scope = outer_session.scope

        inner_session =
          Mirage.within(outer_session, "a.nav", fn s -> s end)

        assert inner_session.scope == outer_scope
        inner_session
      end)
    end

    test "ast is unchanged inside a within block" do
      session = Mirage.visit(Mirage.WithinPage)
      original_ast = session.ast

      Mirage.within(session, "div.sidebar", fn scoped ->
        assert scoped.ast == original_ast
        scoped
      end)
    end

    test "raises when scope matches no elements" do
      session = Mirage.visit(Mirage.WithinPage)

      assert_raise RuntimeError, ~r/Scope selector.*matched no elements/, fn ->
        Mirage.within(session, "#nonexistent", fn session ->
          Mirage.assert_has(session, "a")
        end)
      end
    end

    test "raises when scope matches multiple elements" do
      session = Mirage.visit(Mirage.WithinPage)

      assert_raise RuntimeError, ~r/Scope selector.*matched 2 elements/, fn ->
        Mirage.within(session, "a.nav", fn session ->
          Mirage.assert_has(session, "a")
        end)
      end
    end
  end

  describe "within_article/3" do
    test "scopes to the article matching the header" do
      Mirage.WithinArticlePage
      |> Mirage.visit()
      |> Mirage.within_article("Blog Post", fn session ->
        session
        |> Mirage.assert_has("p", "Blog content")
        |> Mirage.refute_has("p", "News content")
      end)
    end

    test "scopes click to the matching article" do
      session =
        Mirage.WithinArticlePage
        |> Mirage.visit()
        |> Mirage.within_article("News", fn session ->
          Mirage.click(session, "button", "Like")
        end)

      assert session.page.state.clicked == :second
    end

    test "click does not find elements in another article" do
      session = Mirage.visit(Mirage.WithinArticlePage)

      Mirage.within_article(session, "Blog Post", fn session ->
        session
        |> Mirage.refute_has("p", "News content")
        |> Mirage.assert_has("p", "Blog content")
      end)

      session =
        Mirage.within_article(session, "Blog Post", fn session ->
          Mirage.click(session, "button", "Like")
        end)

      assert session.page.state.clicked == :first
    end

    test "finds a heading nested inside another element" do
      Mirage.WithinNestedHeaderPage
      |> Mirage.visit()
      |> Mirage.within_article("Deep Title", fn session ->
        Mirage.assert_has(session, "p", "Some content")
      end)
    end

    test "raises when no article has the given header" do
      session = Mirage.visit(Mirage.WithinArticlePage)

      assert_raise RuntimeError, ~r/No <article> found with header "Nope"/, fn ->
        Mirage.within_article(session, "Nope", fn s -> s end)
      end
    end

    test "restores scope to nil after the block" do
      result =
        Mirage.WithinArticlePage
        |> Mirage.visit()
        |> Mirage.within_article("Blog Post", fn s -> s end)

      assert result.scope == nil
    end
  end

  describe "within_section/3" do
    test "scopes to the section matching the header" do
      Mirage.WithinArticlePage
      |> Mirage.visit()
      |> Mirage.within_section("Settings", fn session ->
        session
        |> Mirage.assert_has("label", "Email")
        |> Mirage.refute_has("p", "Profile info")
      end)
    end

    test "scopes to a different section" do
      Mirage.WithinArticlePage
      |> Mirage.visit()
      |> Mirage.within_section("Profile", fn session ->
        session
        |> Mirage.assert_has("p", "Profile info")
        |> Mirage.refute_has("label", "Email")
      end)
    end

    test "scopes fill_in to the matching section" do
      session =
        Mirage.WithinArticlePage
        |> Mirage.visit()
        |> Mirage.within_section("Settings", fn session ->
          Mirage.fill_in(session, "Email", with: "test@example.com")
        end)

      assert session.page.state.clicked == :first
    end

    test "raises when no section has the given header" do
      session = Mirage.visit(Mirage.WithinArticlePage)

      assert_raise RuntimeError, ~r/No <section> found with header "Nope"/, fn ->
        Mirage.within_section(session, "Nope", fn s -> s end)
      end
    end

    test "accepts a CSS selector to match a different element type" do
      Mirage.WithinSectionSelectorPage
      |> Mirage.visit()
      |> Mirage.within_section("div[role=article]", "Alpha", fn session ->
        session
        |> Mirage.assert_has("p", "Alpha content")
        |> Mirage.refute_has("p", "Beta content")
      end)
    end

    test "scopes click with a custom selector" do
      session =
        Mirage.WithinSectionSelectorPage
        |> Mirage.visit()
        |> Mirage.within_section("div[role=article]", "Beta", fn session ->
          Mirage.click(session, "button", "Go")
        end)

      assert session.page.state.clicked == :second
    end
  end

  describe "within_fieldset/3" do
    test "scopes to the fieldset matching the legend" do
      Mirage.WithinFieldsetPage
      |> Mirage.visit()
      |> Mirage.within_fieldset("Account", fn session ->
        session
        |> Mirage.assert_has("label", "Username")
        |> Mirage.refute_has("p", "Billing info")
      end)
    end

    test "scopes click to the matching fieldset" do
      session =
        Mirage.WithinFieldsetPage
        |> Mirage.visit()
        |> Mirage.within_fieldset("Billing", fn session ->
          Mirage.click(session, "button", "Pay")
        end)

      assert session.page.state.clicked == :second
    end

    test "scopes fill_in to the matching fieldset" do
      session =
        Mirage.WithinFieldsetPage
        |> Mirage.visit()
        |> Mirage.within_fieldset("Account", fn session ->
          Mirage.fill_in(session, "Username", with: "alice")
        end)

      assert session.page.state.clicked == :first
    end

    test "raises when no fieldset has the given legend" do
      session = Mirage.visit(Mirage.WithinFieldsetPage)

      assert_raise RuntimeError, ~r/No <fieldset> found with legend "Nope"/, fn ->
        Mirage.within_fieldset(session, "Nope", fn s -> s end)
      end
    end

    test "restores scope after the block" do
      result =
        Mirage.WithinFieldsetPage
        |> Mirage.visit()
        |> Mirage.within_fieldset("Account", fn s -> s end)

      assert result.scope == nil
    end
  end
end
