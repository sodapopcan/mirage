defmodule HoloTest.AssertionsTest do
  use ExUnit.Case, async: true

  alias HoloTest.Session

  describe "assert_has — text" do
    test "passes when an element's inner text matches" do
      session = HoloTest.visit(HoloTest.AssertHasTextPage)
      assert %Session{} = HoloTest.assert_has(session, "Item 1")
    end

    test "raises when no element's inner text matches" do
      session = HoloTest.visit(HoloTest.AssertHasTextPage)

      assert_raise RuntimeError, ~r/No element found with text: "Missing"/, fn ->
        HoloTest.assert_has(session, "Missing")
      end
    end

    test ":at verifies ordering — items in correct positions pass" do
      HoloTest.visit(HoloTest.AssertHasTextPage)
      |> HoloTest.assert_has("Item 1", at: 1)
      |> HoloTest.assert_has("Item 2", at: 2)
      |> HoloTest.assert_has("Item 3", at: 3)
    end

    test ":at raises when the element at that position has different text" do
      session = HoloTest.visit(HoloTest.AssertHasTextPage)

      assert_raise RuntimeError,
                   ~r/Expected element at position 1 to have text "Item 2" but found "Item 1"/,
                   fn ->
                     HoloTest.assert_has(session, "Item 2", at: 1)
                   end
    end

    test ":at raises when position is out of range" do
      session = HoloTest.visit(HoloTest.AssertHasTextPage)

      assert_raise RuntimeError, ~r/Expected element at position 99 but only found/, fn ->
        HoloTest.assert_has(session, "Item 1", at: 99)
      end
    end
  end

  describe "assert_has — :value" do
    test "passes when an input's value attribute matches" do
      session = HoloTest.visit(HoloTest.AssertHasValuePage)
      assert %Session{} = HoloTest.assert_has(session, value: "alice")
    end

    test "raises when no input's value matches" do
      session = HoloTest.visit(HoloTest.AssertHasValuePage)

      assert_raise RuntimeError, ~r/No element found with value: "missing"/, fn ->
        HoloTest.assert_has(session, value: "missing")
      end
    end

    test ":at verifies ordering — inputs in correct positions pass" do
      HoloTest.visit(HoloTest.AssertHasValuePage)
      |> HoloTest.assert_has(value: "alice", at: 1)
      |> HoloTest.assert_has(value: "bob", at: 2)
      |> HoloTest.assert_has(value: "carol", at: 3)
    end

    test ":at raises when the input at that position has a different value" do
      session = HoloTest.visit(HoloTest.AssertHasValuePage)

      assert_raise RuntimeError,
                   ~r/Expected input at position 1 to have value "bob" but found "alice"/,
                   fn ->
                     HoloTest.assert_has(session, value: "bob", at: 1)
                   end
    end

    test ":at raises when position is out of range" do
      session = HoloTest.visit(HoloTest.AssertHasValuePage)

      assert_raise RuntimeError, ~r/Expected input at position 99 but only found/, fn ->
        HoloTest.assert_has(session, value: "alice", at: 99)
      end
    end
  end

  describe "assert_has — validation" do
    test "raises when text and :value are both given" do
      session = HoloTest.visit(HoloTest.AssertHasTextPage)

      assert_raise ArgumentError, ~r/accepts text or :value, not both/, fn ->
        HoloTest.assert_has(session, "Item 1", value: "x")
      end
    end

    test "raises when neither text nor :value is given" do
      session = HoloTest.visit(HoloTest.AssertHasTextPage)

      assert_raise ArgumentError, ~r/requires text or :value/, fn ->
        HoloTest.assert_has(session, [])
      end
    end
  end

  describe "refute_has — text" do
    test "passes when no element's inner text matches" do
      session = HoloTest.visit(HoloTest.AssertHasTextPage)
      assert %Session{} = HoloTest.refute_has(session, "Missing")
    end

    test "raises when an element's inner text matches" do
      session = HoloTest.visit(HoloTest.AssertHasTextPage)

      assert_raise RuntimeError, ~r/Expected no element with text: "Item 1"/, fn ->
        HoloTest.refute_has(session, "Item 1")
      end
    end

    test ":at passes when the element at that position has different text" do
      session = HoloTest.visit(HoloTest.AssertHasTextPage)
      assert %Session{} = HoloTest.refute_has(session, "Item 2", at: 1)
    end

    test ":at raises when the element at that position has the given text" do
      session = HoloTest.visit(HoloTest.AssertHasTextPage)

      assert_raise RuntimeError, ~r/Expected element at position 1 not to have text "Item 1"/, fn ->
        HoloTest.refute_has(session, "Item 1", at: 1)
      end
    end

    test ":at passes when position is out of range" do
      session = HoloTest.visit(HoloTest.AssertHasTextPage)
      assert %Session{} = HoloTest.refute_has(session, "Item 1", at: 99)
    end
  end

  describe "refute_has — :value" do
    test "passes when no input's value matches" do
      session = HoloTest.visit(HoloTest.AssertHasValuePage)
      assert %Session{} = HoloTest.refute_has(session, value: "missing")
    end

    test "raises when an input's value matches" do
      session = HoloTest.visit(HoloTest.AssertHasValuePage)

      assert_raise RuntimeError, ~r/Expected no input with value: "alice"/, fn ->
        HoloTest.refute_has(session, value: "alice")
      end
    end

    test ":at passes when the input at that position has a different value" do
      session = HoloTest.visit(HoloTest.AssertHasValuePage)
      assert %Session{} = HoloTest.refute_has(session, value: "bob", at: 1)
    end

    test ":at raises when the input at that position has the given value" do
      session = HoloTest.visit(HoloTest.AssertHasValuePage)

      assert_raise RuntimeError, ~r/Expected input at position 1 not to have value "alice"/, fn ->
        HoloTest.refute_has(session, value: "alice", at: 1)
      end
    end

    test ":at passes when position is out of range" do
      session = HoloTest.visit(HoloTest.AssertHasValuePage)
      assert %Session{} = HoloTest.refute_has(session, value: "alice", at: 99)
    end
  end

end
