defmodule Mirage.ScopingTest do
  use ExUnit.Case, async: true

  describe "within/3" do
    test "scopes assert_has to descendants of the selector" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.WithinPage)
      |> Mirage.within("div.sidebar", fn session ->
        session
        |> Mirage.assert_has("a.nav", "Sidebar link")
        |> Mirage.refute_has("a.nav", "Main link")
      end)
    end

    test "scopes refute_has to descendants of the selector" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.WithinPage)
      |> Mirage.within("span.main", fn session ->
        session
        |> Mirage.assert_has("a.nav", "Main link")
        |> Mirage.refute_has("a.nav", "Sidebar link")
      end)
    end

    test "scopes click to descendants of the selector" do
      session =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.WithinPage)
        |> Mirage.within("div.sidebar", fn session ->
          Mirage.click(session, "a.nav", "Sidebar link")
        end)

      assert session.page.state.clicked == :div
    end

    test "click inside within does not find elements outside scope" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.WithinPage)

      assert_raise RuntimeError, ~r/No clickable element found/, fn ->
        Mirage.within(session, "span.main", fn session ->
          Mirage.click(session, "a.nav", "Sidebar link")
        end)
      end
    end

    test "scopes fill_in to descendants of the selector" do
      session =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.WithinPage)
        |> Mirage.within("div.sidebar", fn session ->
          Mirage.fill_in(session, "Sidebar input", with: "hello")
        end)

      assert session.page.state.clicked == :div
    end

    test "count is scoped to within" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.WithinPage)
      |> Mirage.within("div.sidebar", fn session ->
        Mirage.assert_has(session, "a.nav", count: 1)
      end)
    end

    test "restores scope to nil after the block returns" do
      result =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.WithinPage)
        |> Mirage.within("div.sidebar", fn session ->
          Mirage.assert_has(session, "a.nav", "Sidebar link")
        end)

      assert result.scope == nil
    end

    test "nests — inner within searches within the outer scope" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.WithinPage)
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
      %Hologram.Server{}
      |> Mirage.visit(Mirage.WithinPage)
      |> Mirage.within("div.sidebar", fn outer_session ->
        outer_scope = outer_session.scope

        inner_session =
          Mirage.within(outer_session, "a.nav", fn s -> s end)

        assert inner_session.scope == outer_scope
        inner_session
      end)
    end

    test "ast is unchanged inside a within block" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.WithinPage)
      original_ast = session.ast

      Mirage.within(session, "div.sidebar", fn scoped ->
        assert scoped.ast == original_ast
        scoped
      end)
    end

    test "raises when scope matches no elements" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.WithinPage)

      assert_raise RuntimeError, ~r/Scope selector.*matched no elements/, fn ->
        Mirage.within(session, "#nonexistent", fn session ->
          Mirage.assert_has(session, "a")
        end)
      end
    end

    test "raises when scope matches multiple elements" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.WithinPage)

      assert_raise RuntimeError, ~r/Scope selector.*matched 2 elements/, fn ->
        Mirage.within(session, "a.nav", fn session ->
          Mirage.assert_has(session, "a")
        end)
      end
    end
  end

  describe "within_article/3" do
    test "scopes to the article matching the header" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.WithinArticlePage)
      |> Mirage.within_article("Blog Post", fn session ->
        session
        |> Mirage.assert_has("p", "Blog content")
        |> Mirage.refute_has("p", "News content")
      end)
    end

    test "scopes click to the matching article" do
      session =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.WithinArticlePage)
        |> Mirage.within_article("News", fn session ->
          Mirage.click(session, "button", "Like")
        end)

      assert session.page.state.clicked == :second
    end

    test "click does not find elements in another article" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.WithinArticlePage)

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
      %Hologram.Server{}
      |> Mirage.visit(Mirage.WithinNestedHeaderPage)
      |> Mirage.within_article("Deep Title", fn session ->
        Mirage.assert_has(session, "p", "Some content")
      end)
    end

    test "raises when no article has the given header" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.WithinArticlePage)

      assert_raise RuntimeError, ~r/No <article> found with header "Nope"/, fn ->
        Mirage.within_article(session, "Nope", fn s -> s end)
      end
    end

    test "restores scope to nil after the block" do
      result =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.WithinArticlePage)
        |> Mirage.within_article("Blog Post", fn s -> s end)

      assert result.scope == nil
    end
  end

  describe "within_section/3" do
    test "scopes to the section matching the header" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.WithinArticlePage)
      |> Mirage.within_section("Settings", fn session ->
        session
        |> Mirage.assert_has("label", "Email")
        |> Mirage.refute_has("p", "Profile info")
      end)
    end

    test "scopes to a different section" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.WithinArticlePage)
      |> Mirage.within_section("Profile", fn session ->
        session
        |> Mirage.assert_has("p", "Profile info")
        |> Mirage.refute_has("label", "Email")
      end)
    end

    test "scopes fill_in to the matching section" do
      session =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.WithinArticlePage)
        |> Mirage.within_section("Settings", fn session ->
          Mirage.fill_in(session, "Email", with: "test@example.com")
        end)

      assert session.page.state.clicked == :first
    end

    test "raises when no section has the given header" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.WithinArticlePage)

      assert_raise RuntimeError, ~r/No <section> found with header "Nope"/, fn ->
        Mirage.within_section(session, "Nope", fn s -> s end)
      end
    end

    test "accepts a CSS selector to match a different element type" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.WithinSectionSelectorPage)
      |> Mirage.within_section("div[role=article]", "Alpha", fn session ->
        session
        |> Mirage.assert_has("p", "Alpha content")
        |> Mirage.refute_has("p", "Beta content")
      end)
    end

    test "scopes click with a custom selector" do
      session =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.WithinSectionSelectorPage)
        |> Mirage.within_section("div[role=article]", "Beta", fn session ->
          Mirage.click(session, "button", "Go")
        end)

      assert session.page.state.clicked == :second
    end
  end

  describe "within_fieldset/3" do
    test "scopes to the fieldset matching the legend" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.WithinFieldsetPage)
      |> Mirage.within_fieldset("Account", fn session ->
        session
        |> Mirage.assert_has("label", "Username")
        |> Mirage.refute_has("p", "Billing info")
      end)
    end

    test "scopes click to the matching fieldset" do
      session =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.WithinFieldsetPage)
        |> Mirage.within_fieldset("Billing", fn session ->
          Mirage.click(session, "button", "Pay")
        end)

      assert session.page.state.clicked == :second
    end

    test "scopes fill_in to the matching fieldset" do
      session =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.WithinFieldsetPage)
        |> Mirage.within_fieldset("Account", fn session ->
          Mirage.fill_in(session, "Username", with: "alice")
        end)

      assert session.page.state.clicked == :first
    end

    test "raises when no fieldset has the given legend" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.WithinFieldsetPage)

      assert_raise RuntimeError, ~r/No <fieldset> found with legend "Nope"/, fn ->
        Mirage.within_fieldset(session, "Nope", fn s -> s end)
      end
    end

    test "restores scope after the block" do
      result =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.WithinFieldsetPage)
        |> Mirage.within_fieldset("Account", fn s -> s end)

      assert result.scope == nil
    end
  end
end
