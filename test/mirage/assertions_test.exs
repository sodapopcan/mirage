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

  describe "assert_has — :at" do
    test "matches element at 1-based position" do
      session = Mirage.visit(Mirage.AssertHasTextPage)
      Mirage.assert_has(session, "li", "Item 1", at: 1)
      Mirage.assert_has(session, "li", "Item 2", at: 2)
      Mirage.assert_has(session, "li", "Item 3", at: 3)
    end

    test "fails when text does not match at the given position" do
      session = Mirage.visit(Mirage.AssertHasTextPage)

      assert_raise AssertionError, ~r/found 0/, fn ->
        Mirage.assert_has(session, "li", "Item 1", at: 2)
      end
    end

    test "fails when position is out of bounds" do
      session = Mirage.visit(Mirage.AssertHasTextPage)

      assert_raise AssertionError, ~r/found 0/, fn ->
        Mirage.assert_has(session, "li", "Item 1", at: 99)
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

  describe "refute_has — :at" do
    test "passes when text does not match at the given position" do
      session = Mirage.visit(Mirage.AssertHasTextPage)
      Mirage.refute_has(session, "li", "Item 1", at: 2)
    end

    test "raises when text matches at the given position" do
      session = Mirage.visit(Mirage.AssertHasTextPage)

      assert_raise AssertionError, ~r/Expected not to find/, fn ->
        Mirage.refute_has(session, "li", "Item 1", at: 1)
      end
    end

    test "passes when position is out of bounds" do
      session = Mirage.visit(Mirage.AssertHasTextPage)
      Mirage.refute_has(session, "li", "Item 1", at: 99)
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
      |> Mirage.click("a", "link to other page")
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

    test "passes when params match" do
      Mirage.CommandPage
      |> Mirage.visit(tmp_path: "/tmp/x")
      |> Mirage.assert_page(Mirage.CommandPage, tmp_path: "/tmp/x")
    end

    test "passes with empty params when none expected" do
      Mirage.HomePage
      |> Mirage.visit()
      |> Mirage.assert_page(Mirage.HomePage)
    end

    test "raises when param value does not match" do
      assert_raise AssertionError,
                   ~r/Expected param :tmp_path to be "\/tmp\/wrong"/,
                   fn ->
                     Mirage.CommandPage
                     |> Mirage.visit(tmp_path: "/tmp/right")
                     |> Mirage.assert_page(Mirage.CommandPage, tmp_path: "/tmp/wrong")
                   end
    end

    test "raises when expected param is missing" do
      assert_raise AssertionError,
                   ~r/Expected param :missing to be "x" but was nil/,
                   fn ->
                     Mirage.CommandPage
                     |> Mirage.visit(tmp_path: "/tmp/x")
                     |> Mirage.assert_page(Mirage.CommandPage, missing: "x")
                   end
    end

    test "checks multiple params" do
      Mirage.CommandPage
      |> Mirage.visit(tmp_path: "/tmp/x")
      |> Mirage.assert_page(Mirage.CommandPage, tmp_path: "/tmp/x")
    end

    test "returns session for chaining" do
      session =
        Mirage.CommandPage
        |> Mirage.visit(tmp_path: "/tmp/x")
        |> Mirage.assert_page(Mirage.CommandPage, tmp_path: "/tmp/x")

      assert %Session{} = session
    end
  end
end
