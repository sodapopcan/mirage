defmodule MirageTest do
  use ExUnit.Case, async: true

  alias Mirage.Session

  doctest Mirage

  describe "click_link/2" do
    test "clicks on a link" do
      Mirage.HomePage
      |> Mirage.visit()
      |> Mirage.click_link("I link to the same page")
      |> Mirage.assert_page(Mirage.AnotherPage)
    end

    test "accepts opts" do
      Mirage.HomePage
      |> Mirage.visit()
      |> Mirage.click_link("I link to", exact: false)
      |> Mirage.assert_page(Mirage.AnotherPage)
    end
  end

  describe "click_button/2" do
    test "clicks on a button" do
      Mirage.HomePage
      |> Mirage.visit()
      |> Mirage.click_button("I button to the same page")
      |> Mirage.assert_page(Mirage.AnotherPage)
    end

    test "accepts opts" do
      Mirage.HomePage
      |> Mirage.visit()
      |> Mirage.click_button("I button to", exact: false)
      |> Mirage.assert_page(Mirage.AnotherPage)
    end

    test "dispatches form $submit when button has no $click" do
      session =
        Mirage.FormSubmitPage
        |> Mirage.visit()
        |> Mirage.click_button("Submit")

      assert session.page.state.submitted == true
    end

    test "dispatches form $submit for input[type=submit] with no $click" do
      session =
        Mirage.FormSubmitInputPage
        |> Mirage.visit()
        |> Mirage.click_button("Go")

      assert session.page.state.submitted == true
    end
  end

  describe "fill_in/3" do
    test "fills an input wrapped by a label matching exactly" do
      session = Mirage.visit(Mirage.FillInPage)
      assert %Session{} = Mirage.fill_in(session, "Name", with: "Alice")
    end

    test "fills an input referenced by `for` matching the input's id" do
      session = Mirage.visit(Mirage.FillInPage)
      assert %Session{} = Mirage.fill_in(session, "Email", with: "a@b.c")
    end

    test "trims surrounding whitespace in the label when matching exactly" do
      session = Mirage.visit(Mirage.FillInWhitespaceLabelPage)
      assert %Session{} = Mirage.fill_in(session, "Name", with: "Alice")
    end

    test "concatenates text from descendant elements when computing the label's text" do
      session = Mirage.visit(Mirage.FillInNestedLabelPage)
      assert %Session{} = Mirage.fill_in(session, "First name", with: "Alice")
    end

    test "finds a label nested deep in the tree" do
      session = Mirage.visit(Mirage.FillInDeepLabelPage)
      assert %Session{} = Mirage.fill_in(session, "Email", with: "a@b.c")
    end

    test "matches substrings when exact: false" do
      session = Mirage.visit(Mirage.FillInLabelTextPage)
      assert %Session{} = Mirage.fill_in(session, "Email", with: "a@b.c", exact: false)
    end

    test "does not match substrings when exact is the default" do
      session = Mirage.visit(Mirage.FillInLabelTextPage)

      assert_raise RuntimeError, ~r/No input found with label: "Email"/, fn ->
        Mirage.fill_in(session, "Email", with: "a@b.c")
      end
    end

    test "raises when no label matches" do
      session = Mirage.visit(Mirage.FillInPage)

      assert_raise RuntimeError, ~r/No input found with label: "Nonsense"/, fn ->
        Mirage.fill_in(session, "Nonsense", with: "x")
      end
    end

    test "ignores labels written inside an HTML comment" do
      session = Mirage.visit(Mirage.FillInCommentPage)

      assert_raise RuntimeError, ~r/No input found with label: "Hidden"/, fn ->
        Mirage.fill_in(session, "Hidden", with: "x")
      end
    end

    test "raises when more than one label matches" do
      session = Mirage.visit(Mirage.FillInAmbiguousLabelPage)

      assert_raise RuntimeError, ~r/Ambiguous match: found 2 labels matching: "Name"/, fn ->
        Mirage.fill_in(session, "Name", with: "Alice")
      end
    end

    test "raises when a matching `for` label has no corresponding input" do
      session = Mirage.visit(Mirage.FillInOrphanLabelPage)

      assert_raise RuntimeError, ~r/No input with id="missing"/, fn ->
        Mirage.fill_in(session, "Orphan", with: "x")
      end
    end

    test "requires a `with:` option" do
      session = Mirage.visit(Mirage.FillInPage)

      assert_raise KeyError, ~r/key :with not found/, fn ->
        Mirage.fill_in(session, "Name", [])
      end
    end
  end

  describe "fill_in/3 — action dispatch" do
    test "triggers the input's $change, passing the filled value as :value" do
      session = Mirage.visit(Mirage.FillInPage)

      # Before: the page hasn't seen any input yet.
      refute session.page.state[:name]

      session = Mirage.fill_in(session, "Name", with: "Alice")

      # The `:update_name` action ran and wrote `:name` into the page state.
      assert session.page.state.name == "Alice"
    end

    test "merges the filled value with params declared on the attribute" do
      session =
        Mirage.FillInPage
        |> Mirage.visit()
        |> Mirage.fill_in("Email", with: "a@b.c")

      # `$change={:set_field, field: :email}` + `value: "a@b.c"` ⇒ state[:email].
      assert session.page.state.email == "a@b.c"
    end

    test "also triggers the enclosing form's $change action" do
      session =
        Mirage.FillInPage
        |> Mirage.visit()
        |> Mirage.fill_in("Name", with: "Alice")

      # The form's `$change` handler appends each change to a log — both
      # the input's own action AND the form's change action fired.
      assert session.page.state.change_log == ["Alice"]
    end

    test "does not trigger a $change action when the input has no enclosing form" do
      session =
        Mirage.FillInPage
        |> Mirage.visit()
        |> Mirage.fill_in("Comment", with: "hi")

      # The comment textarea is outside the <form>, so only its $change ran.
      assert session.page.state.comment == "hi"
      assert session.page.state.change_log == []
    end
  end

  describe "{%if} blocks" do
    test "elements inside a false if block are not visible" do
      Mirage.IfBlockPage
      |> Mirage.visit()
      |> Mirage.refute_has("p", "Visible content")
      |> Mirage.assert_has("p", "Always here")
    end

    test "click cannot reach a button inside a false if block" do
      session = Mirage.visit(Mirage.IfBlockPage)

      assert_raise RuntimeError, ~r/No clickable element found/, fn ->
        Mirage.click(session, "button", "Hidden button")
      end
    end

    test "fill_in cannot reach an input inside a false if block" do
      session = Mirage.visit(Mirage.IfBlockPage)

      assert_raise RuntimeError, ~r/No input found with label/, fn ->
        Mirage.fill_in(session, "Hidden input", with: "x")
      end
    end

    test "elements appear after the condition becomes true" do
      Mirage.IfBlockPage
      |> Mirage.visit()
      |> Mirage.click("button", "Show")
      |> Mirage.assert_has("p", "Visible content")
      |> Mirage.assert_has("button", "Hidden button")
    end
  end
end
