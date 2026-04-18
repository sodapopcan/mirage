defmodule Mirage.WithinTest do
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

    test "restores scope after the block returns" do
      session =
        Mirage.WithinPage
        |> Mirage.visit()
        |> Mirage.within("div.sidebar", fn session ->
          Mirage.assert_has(session, "a.nav", "Sidebar link")
        end)

      assert session.scope == nil
    end

    test "nests — inner within appends to the outer selector" do
      Mirage.WithinPage
      |> Mirage.visit()
      |> Mirage.within("div.sidebar", fn session ->
        # span.main is not inside div.sidebar, so the nested scope is invalid
        assert_raise RuntimeError, ~r/Scope selector.*matched no elements/, fn ->
          Mirage.within(session, "span.main", fn session ->
            Mirage.click(session, "a.nav")
          end)
        end

        session
      end)
    end

    test "nested within restores to outer scope, not nil" do
      session =
        Mirage.WithinPage
        |> Mirage.visit()
        |> Mirage.within("div.sidebar", fn session ->
          inner =
            Mirage.within(session, "a.nav", fn s -> s end)

          assert inner.scope == "div.sidebar"
          inner
        end)

      assert session.scope == nil
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
end
