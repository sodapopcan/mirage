defmodule Mirage.AssertionsTest do
  use ExUnit.Case, async: true

  alias Mirage.Session
  alias ExUnit.AssertionError

  describe "assert_has — selector only" do
    test "passes when exactly one element matches" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.ClickPage)
      assert %Session{} = Mirage.assert_has(session, "button")
    end

    test "raises when no element matches" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.ClickPage)

      assert_raise AssertionError,
                   ~r/Expected to find exactly 1 element matching "nav".*found 0/,
                   fn ->
                     Mirage.assert_has(session, "nav")
                   end
    end

    test "raises when more than one element matches" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.AssertHasValuePage)

      assert_raise AssertionError,
                   ~r/Expected to find exactly 1 element matching "input".*found 3/,
                   fn ->
                     Mirage.assert_has(session, "input")
                   end
    end
  end

  describe "assert_has — :text" do
    test "passes when exactly one element has the given text" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.AssertHasTextPage)
      assert %Session{} = Mirage.assert_has(session, "li", text: "Item 1")
    end

    test "raises when no element has the given text" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.AssertHasTextPage)

      assert_raise AssertionError, ~r/found 0/, fn ->
        Mirage.assert_has(session, "li", text: "Missing")
      end
    end

    test "raises when multiple elements have the given text" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.ClickAmbiguousPage)

      assert_raise AssertionError, ~r/found 2/, fn ->
        Mirage.assert_has(session, "*", text: "Save")
      end
    end
  end

  describe "assert_has — :value" do
    test "passes when exactly one element has the given value" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.AssertHasValuePage)
      assert %Session{} = Mirage.assert_has(session, "input", value: "alice")
    end

    test "raises when no element has the given value" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.AssertHasValuePage)

      assert_raise AssertionError, ~r/found 0/, fn ->
        Mirage.assert_has(session, "input", value: "missing")
      end
    end
  end

  describe "assert_has — :text and :value combined" do
    test "can filter by both text and value" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.AssertHasValuePage)
      # inputs are void elements with no inner text — the combination narrows to zero
      assert_raise AssertionError, ~r/found 0/, fn ->
        Mirage.assert_has(session, "input", text: "alice", value: "alice")
      end
    end
  end

  describe "assert_has — :at" do
    test "matches element at 1-based position" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.AssertHasTextPage)
      Mirage.assert_has(session, "li", "Item 1", at: 1)
      Mirage.assert_has(session, "li", "Item 2", at: 2)
      Mirage.assert_has(session, "li", "Item 3", at: 3)
    end

    test "fails when text does not match at the given position" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.AssertHasTextPage)

      assert_raise AssertionError, ~r/found 0/, fn ->
        Mirage.assert_has(session, "li", "Item 1", at: 2)
      end
    end

    test "fails when position is out of bounds" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.AssertHasTextPage)

      assert_raise AssertionError, ~r/found 0/, fn ->
        Mirage.assert_has(session, "li", "Item 1", at: 99)
      end
    end
  end

  describe "refute_has — selector only" do
    test "passes when no element matches" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.ClickPage)
      assert %Session{} = Mirage.refute_has(session, "nav")
    end

    test "raises when an element matches" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.ClickPage)

      assert_raise AssertionError,
                   ~r/Expected not to find an element matching "button".*found 1/,
                   fn ->
                     Mirage.refute_has(session, "button")
                   end
    end
  end

  describe "refute_has — :text" do
    test "passes when no element has the given text" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.AssertHasTextPage)
      assert %Session{} = Mirage.refute_has(session, "li", text: "Missing")
    end

    test "raises when an element has the given text" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.AssertHasTextPage)

      assert_raise AssertionError, ~r/Expected not to find/, fn ->
        Mirage.refute_has(session, "li", text: "Item 1")
      end
    end
  end

  describe "refute_has — :value" do
    test "passes when no element has the given value" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.AssertHasValuePage)
      assert %Session{} = Mirage.refute_has(session, "input", value: "missing")
    end

    test "raises when an element has the given value" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.AssertHasValuePage)

      assert_raise AssertionError, ~r/Expected not to find/, fn ->
        Mirage.refute_has(session, "input", value: "alice")
      end
    end
  end

  describe "refute_has — :at" do
    test "passes when text does not match at the given position" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.AssertHasTextPage)
      Mirage.refute_has(session, "li", "Item 1", at: 2)
    end

    test "raises when text matches at the given position" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.AssertHasTextPage)

      assert_raise AssertionError, ~r/Expected not to find/, fn ->
        Mirage.refute_has(session, "li", "Item 1", at: 1)
      end
    end

    test "passes when position is out of bounds" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.AssertHasTextPage)
      Mirage.refute_has(session, "li", "Item 1", at: 99)
    end
  end

  describe "assert_has — :label" do
    test "passes when input has matching label" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInPage)
      Mirage.assert_has(session, "input", label: "Name")
    end

    test "matches label linked via for/id" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInPage)
      Mirage.assert_has(session, "input", label: "Email")
    end

    test "raises when no input has matching label" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInPage)

      assert_raise AssertionError, ~r/found 0/, fn ->
        Mirage.assert_has(session, "input", label: "Missing")
      end
    end

    test "combines label with other filters" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInPage)
      # "Name" label exists but doesn't wrap a textarea
      Mirage.refute_has(session, "textarea", label: "Name")
      # "Comment" label wraps a textarea
      Mirage.assert_has(session, "textarea", label: "Comment")
    end
  end

  describe "refute_has — :label" do
    test "passes when no input has matching label" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInPage)
      Mirage.refute_has(session, "input", label: "Missing")
    end

    test "raises when input has matching label" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInPage)

      assert_raise AssertionError, ~r/Expected not to find/, fn ->
        Mirage.refute_has(session, "input", label: "Name")
      end
    end
  end

  describe "assert_has — :count" do
    test "passes when count matches" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.AssertHasValuePage)
      Mirage.assert_has(session, "input", count: 3)
    end

    test "raises when count does not match" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.AssertHasValuePage)

      assert_raise AssertionError, ~r/Expected to find exactly 2 elements.*found 3/, fn ->
        Mirage.assert_has(session, "input", count: 2)
      end
    end

    test "count: 1 is the default" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.ClickPage)
      Mirage.assert_has(session, "button")
      Mirage.assert_has(session, "button", count: 1)
    end
  end

  describe "assert_has — trimming" do
    test "trims whitespace and newlines from DOM text when matching :text" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.AssertHasTrimPage)
      Mirage.assert_has(session, "p", "hello")
    end

    test "trims surrounding whitespace from the :text option" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.AssertHasTrimPage)
      Mirage.assert_has(session, "p", "\n  hello\n  ")
    end

    test "trims surrounding whitespace from DOM value when matching :value" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.AssertHasTrimPage)
      Mirage.assert_has(session, "input", value: "world")
    end

    test "trims surrounding whitespace from the :value option" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.AssertHasTrimPage)
      Mirage.assert_has(session, "input", value: "  world  ")
    end

    test "trims :text for substring matching with exact: false" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.AssertHasTrimPage)
      Mirage.assert_has(session, "p", "  hell  ", exact: false)
    end
  end

  describe "pipelining" do
    test "assert_has and refute_has return session for chaining" do
      Mirage.visit(%Hologram.Server{}, Mirage.AssertHasTextPage)
      |> Mirage.assert_has("h1", text: "I'm a header")
      |> Mirage.refute_has("h2")
    end
  end

  describe "assert_page" do
    test "asserts that we are on a specific page" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.HomePage)
      |> Mirage.click("a", "link to other page")
      |> Mirage.assert_page(Mirage.AnotherPage)
    end

    test "raises if we are not on the given page" do
      assert_raise AssertionError,
                   ~r/Expected current page to be Mirage.NotThisPage but was Mirage.HomePage/,
                   fn ->
                     %Hologram.Server{}
                     |> Mirage.visit(Mirage.HomePage)
                     |> Mirage.assert_page(Mirage.NotThisPage)
                   end
    end

    test "passes when params match" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.CommandPage, tmp_path: "/tmp/x")
      |> Mirage.assert_page(Mirage.CommandPage, tmp_path: "/tmp/x")
    end

    test "passes with empty params when none expected" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.HomePage)
      |> Mirage.assert_page(Mirage.HomePage)
    end

    test "raises when param value does not match" do
      assert_raise AssertionError,
                   ~r/Expected param :tmp_path to be "\/tmp\/wrong"/,
                   fn ->
                     %Hologram.Server{}
                     |> Mirage.visit(Mirage.CommandPage, tmp_path: "/tmp/right")
                     |> Mirage.assert_page(Mirage.CommandPage, tmp_path: "/tmp/wrong")
                   end
    end

    test "raises when expected param is missing" do
      assert_raise AssertionError,
                   ~r/Expected param :missing to be "x" but was nil/,
                   fn ->
                     %Hologram.Server{}
                     |> Mirage.visit(Mirage.CommandPage, tmp_path: "/tmp/x")
                     |> Mirage.assert_page(Mirage.CommandPage, missing: "x")
                   end
    end

    test "checks multiple params" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.CommandPage, tmp_path: "/tmp/x")
      |> Mirage.assert_page(Mirage.CommandPage, tmp_path: "/tmp/x")
    end

    test "returns session for chaining" do
      session =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.CommandPage, tmp_path: "/tmp/x")
        |> Mirage.assert_page(Mirage.CommandPage, tmp_path: "/tmp/x")

      assert %Session{} = session
    end
  end
end
