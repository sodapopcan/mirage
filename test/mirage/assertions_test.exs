defmodule Mirage.AssertionsTest do
  use ExUnit.Case, async: true

  alias Mirage.Session
  alias ExUnit.AssertionError

  describe "assert_has — selector only" do
    test "passes when exactly one element matches" do
      session = Mirage.visit(Mirage.ClickPage)
      assert %Session{} = Mirage.assert_has(session, "button")
    end

    test "raises when no element matches" do
      session = Mirage.visit(Mirage.ClickPage)

      assert_raise AssertionError,
                   ~r/Expected to find exactly 1 element matching "nav".*found 0/,
                   fn ->
                     Mirage.assert_has(session, "nav")
                   end
    end

    test "raises when more than one element matches" do
      session = Mirage.visit(Mirage.AssertHasValuePage)

      assert_raise AssertionError,
                   ~r/Expected to find exactly 1 element matching "input".*found 3/,
                   fn ->
                     Mirage.assert_has(session, "input")
                   end
    end
  end

  describe "assert_has — :text" do
    test "passes when exactly one element has the given text" do
      session = Mirage.visit(Mirage.AssertHasTextPage)
      assert %Session{} = Mirage.assert_has(session, "li", text: "Item 1")
    end

    test "raises when no element has the given text" do
      session = Mirage.visit(Mirage.AssertHasTextPage)

      assert_raise AssertionError, ~r/found 0/, fn ->
        Mirage.assert_has(session, "li", text: "Missing")
      end
    end

    test "raises when multiple elements have the given text" do
      session = Mirage.visit(Mirage.ClickAmbiguousPage)

      assert_raise AssertionError, ~r/found 2/, fn ->
        Mirage.assert_has(session, "*", text: "Save")
      end
    end
  end

  describe "assert_has — :value" do
    test "passes when exactly one element has the given value" do
      session = Mirage.visit(Mirage.AssertHasValuePage)
      assert %Session{} = Mirage.assert_has(session, "input", value: "alice")
    end

    test "raises when no element has the given value" do
      session = Mirage.visit(Mirage.AssertHasValuePage)

      assert_raise AssertionError, ~r/found 0/, fn ->
        Mirage.assert_has(session, "input", value: "missing")
      end
    end
  end

  describe "assert_has — :text and :value combined" do
    test "can filter by both text and value" do
      session = Mirage.visit(Mirage.AssertHasValuePage)
      # inputs are void elements with no inner text — the combination narrows to zero
      assert_raise AssertionError, ~r/found 0/, fn ->
        Mirage.assert_has(session, "input", text: "alice", value: "alice")
      end
    end
  end

  describe "refute_has — selector only" do
    test "passes when no element matches" do
      session = Mirage.visit(Mirage.ClickPage)
      assert %Session{} = Mirage.refute_has(session, "nav")
    end

    test "raises when an element matches" do
      session = Mirage.visit(Mirage.ClickPage)

      assert_raise AssertionError,
                   ~r/Expected not to find an element matching "button".*found 1/,
                   fn ->
                     Mirage.refute_has(session, "button")
                   end
    end
  end

  describe "refute_has — :text" do
    test "passes when no element has the given text" do
      session = Mirage.visit(Mirage.AssertHasTextPage)
      assert %Session{} = Mirage.refute_has(session, "li", text: "Missing")
    end

    test "raises when an element has the given text" do
      session = Mirage.visit(Mirage.AssertHasTextPage)

      assert_raise AssertionError, ~r/Expected not to find/, fn ->
        Mirage.refute_has(session, "li", text: "Item 1")
      end
    end
  end

  describe "refute_has — :value" do
    test "passes when no element has the given value" do
      session = Mirage.visit(Mirage.AssertHasValuePage)
      assert %Session{} = Mirage.refute_has(session, "input", value: "missing")
    end

    test "raises when an element has the given value" do
      session = Mirage.visit(Mirage.AssertHasValuePage)

      assert_raise AssertionError, ~r/Expected not to find/, fn ->
        Mirage.refute_has(session, "input", value: "alice")
      end
    end
  end

  describe "pipelining" do
    test "assert_has and refute_has return session for chaining" do
      Mirage.visit(Mirage.AssertHasTextPage)
      |> Mirage.assert_has("h1", text: "I'm a header")
      |> Mirage.refute_has("h2")
    end
  end

  describe "assert_page" do
    test "asserts that we are on a specific page" do
      Mirage.HomePage
      |> Mirage.visit()
      |> Mirage.click("link to other page")
      |> Mirage.assert_page(Mirage.AnotherPage)
    end

    test "raises if we are not on the given page" do
      assert_raise AssertionError,
                   ~r/Expected current page to be Mirage.NotThisPage but was Mirage.HomePage/,
                   fn ->
                     Mirage.HomePage
                     |> Mirage.visit()
                     |> Mirage.assert_page(Mirage.NotThisPage)
                   end
    end
  end
end
