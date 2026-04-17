defmodule Holography.AssertionsTest do
  use ExUnit.Case, async: true

  alias Holography.Session

  describe "assert_has — selector only" do
    test "passes when exactly one element matches" do
      session = Holography.visit(Holography.ClickPage)
      assert %Session{} = Holography.assert_has(session, "button")
    end

    test "raises when no element matches" do
      session = Holography.visit(Holography.ClickPage)

      assert_raise RuntimeError, ~r/Expected to find an element matching "nav".*found none/, fn ->
        Holography.assert_has(session, "nav")
      end
    end

    test "raises when more than one element matches" do
      session = Holography.visit(Holography.AssertHasValuePage)

      assert_raise RuntimeError, ~r/Expected to find 1 element matching "input".*found 3/, fn ->
        Holography.assert_has(session, "input")
      end
    end
  end

  describe "assert_has — :text" do
    test "passes when exactly one element has the given text" do
      session = Holography.visit(Holography.AssertHasTextPage)
      assert %Session{} = Holography.assert_has(session, "li", text: "Item 1")
    end

    test "raises when no element has the given text" do
      session = Holography.visit(Holography.AssertHasTextPage)

      assert_raise RuntimeError, ~r/found none/, fn ->
        Holography.assert_has(session, "li", text: "Missing")
      end
    end

    test "raises when multiple elements have the given text" do
      session = Holography.visit(Holography.ClickAmbiguousPage)

      assert_raise RuntimeError, ~r/found 2/, fn ->
        Holography.assert_has(session, "*", text: "Save")
      end
    end
  end

  describe "assert_has — :value" do
    test "passes when exactly one element has the given value" do
      session = Holography.visit(Holography.AssertHasValuePage)
      assert %Session{} = Holography.assert_has(session, "input", value: "alice")
    end

    test "raises when no element has the given value" do
      session = Holography.visit(Holography.AssertHasValuePage)

      assert_raise RuntimeError, ~r/found none/, fn ->
        Holography.assert_has(session, "input", value: "missing")
      end
    end
  end

  describe "assert_has — :text and :value combined" do
    test "can filter by both text and value" do
      session = Holography.visit(Holography.AssertHasValuePage)
      # inputs are void elements with no inner text — the combination narrows to zero
      assert_raise RuntimeError, ~r/found none/, fn ->
        Holography.assert_has(session, "input", text: "alice", value: "alice")
      end
    end
  end

  describe "refute_has — selector only" do
    test "passes when no element matches" do
      session = Holography.visit(Holography.ClickPage)
      assert %Session{} = Holography.refute_has(session, "nav")
    end

    test "raises when an element matches" do
      session = Holography.visit(Holography.ClickPage)

      assert_raise RuntimeError, ~r/Expected not to find an element matching "button".*found 1/, fn ->
        Holography.refute_has(session, "button")
      end
    end
  end

  describe "refute_has — :text" do
    test "passes when no element has the given text" do
      session = Holography.visit(Holography.AssertHasTextPage)
      assert %Session{} = Holography.refute_has(session, "li", text: "Missing")
    end

    test "raises when an element has the given text" do
      session = Holography.visit(Holography.AssertHasTextPage)

      assert_raise RuntimeError, ~r/Expected not to find/, fn ->
        Holography.refute_has(session, "li", text: "Item 1")
      end
    end
  end

  describe "refute_has — :value" do
    test "passes when no element has the given value" do
      session = Holography.visit(Holography.AssertHasValuePage)
      assert %Session{} = Holography.refute_has(session, "input", value: "missing")
    end

    test "raises when an element has the given value" do
      session = Holography.visit(Holography.AssertHasValuePage)

      assert_raise RuntimeError, ~r/Expected not to find/, fn ->
        Holography.refute_has(session, "input", value: "alice")
      end
    end
  end

  describe "pipelining" do
    test "assert_has and refute_has return session for chaining" do
      Holography.visit(Holography.AssertHasTextPage)
      |> Holography.assert_has("h1", text: "I'm a header")
      |> Holography.refute_has("h2")
    end
  end
end
