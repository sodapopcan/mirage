defmodule MirageTest do
  use ExUnit.Case, async: true

  alias Mirage.Session

  doctest Mirage

  describe "visit/2" do
    test "returns a session" do
      assert %Session{} = Mirage.visit(Mirage.ClickPage)
    end

    test "sets page_module" do
      session = Mirage.visit(Mirage.ClickPage)
      assert session.page_module == Mirage.ClickPage
    end

    test "accepts params as keyword list" do
      session = Mirage.visit(Mirage.CommandPage, tmp_path: "/tmp/hello")
      assert session.params == %{tmp_path: "/tmp/hello"}
    end

    test "defaults params to empty map" do
      session = Mirage.visit(Mirage.ClickPage)
      assert session.params == %{}
    end

    test "renders the page template" do
      session = Mirage.visit(Mirage.ClickPage)
      Mirage.assert_has(session, "button")
    end

    test "runs page init" do
      session = Mirage.visit(Mirage.ClickPage)
      refute Map.has_key?(session.page.state, :clicked)
    end
  end

  describe "reload/1" do
    test "resets page state" do
      session =
        Mirage.ClickPage
        |> Mirage.visit()
        |> Mirage.click("button", "Save changes now")

      assert session.page.state.clicked == true

      session = Mirage.reload(session)
      refute Map.has_key?(session.page.state, :clicked)
    end

    test "preserves params across reload" do
      session = Mirage.visit(Mirage.CommandPage, tmp_path: "/tmp/test")
      session = Mirage.reload(session)

      assert session.params == %{tmp_path: "/tmp/test"}
      assert session.page_module == Mirage.CommandPage
    end
  end

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
      assert session.page.state.submit_data["token"] == "abc123"
    end

    test "dispatches form $submit for input[type=submit] with no $click" do
      session =
        Mirage.FormSubmitInputPage
        |> Mirage.visit()
        |> Mirage.click_button("Go")

      assert session.page.state.submitted == true
    end

    test "dispatches form $submit for external button with form attribute" do
      session =
        Mirage.FormSubmitExternalButtonPage
        |> Mirage.visit()
        |> Mirage.click_button("Submit")

      assert session.page.state.submitted == true
      assert session.page.state.submit_data["name"] == "alice"
    end

    test "dispatches form $submit for external input[type=submit] with form attribute" do
      session =
        Mirage.FormSubmitExternalInputPage
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

  describe "non-interactive inputs" do
    test "fill_in raises for type=hidden input" do
      session = Mirage.visit(Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/is hidden/, fn ->
        Mirage.fill_in(session, "Hidden input", with: "x")
      end
    end

    test "fill_in raises for input with hidden attribute" do
      session = Mirage.visit(Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/is hidden/, fn ->
        Mirage.fill_in(session, "Hidden attr", with: "x")
      end
    end

    test "fill_in raises for disabled input" do
      session = Mirage.visit(Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/is disabled/, fn ->
        Mirage.fill_in(session, "Disabled input", with: "x")
      end
    end

    test "fill_in raises for readonly input" do
      session = Mirage.visit(Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/is readonly/, fn ->
        Mirage.fill_in(session, "Readonly input", with: "x")
      end
    end

    test "fill_in raises for disabled textarea" do
      session = Mirage.visit(Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/is disabled/, fn ->
        Mirage.fill_in(session, "Disabled textarea", with: "x")
      end
    end

    test "fill_in raises for readonly textarea" do
      session = Mirage.visit(Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/is readonly/, fn ->
        Mirage.fill_in(session, "Readonly textarea", with: "x")
      end
    end

    test "fill_in still works for normal input" do
      session = Mirage.visit(Mirage.NonInteractivePage)
      assert %Session{} = Mirage.fill_in(session, "Normal input", with: "hello")
    end

    test "select raises for disabled select" do
      session = Mirage.visit(Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/is disabled/, fn ->
        Mirage.select(session, "Disabled select", "A")
      end
    end

    test "select raises for hidden select" do
      session = Mirage.visit(Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/is hidden/, fn ->
        Mirage.select(session, "Hidden select", "A")
      end
    end

    test "choose raises for disabled radio" do
      session = Mirage.visit(Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/is disabled/, fn ->
        Mirage.choose(session, "Disabled radio")
      end
    end

    test "check raises for disabled checkbox" do
      session = Mirage.visit(Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/is disabled/, fn ->
        Mirage.check(session, "Disabled checkbox")
      end
    end

    test "uncheck raises for disabled checkbox" do
      session = Mirage.visit(Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/is disabled/, fn ->
        Mirage.uncheck(session, "Disabled checkbox")
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

    test "also triggers the enclosing form's $change action with form data" do
      session =
        Mirage.FillInPage
        |> Mirage.visit()
        |> Mirage.fill_in("Name", with: "Alice")

      # The form's `$change` handler receives all named field values.
      assert [form_data] = session.page.state.change_log
      assert form_data["name"] == "Alice"
      assert form_data["email"] == ""
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

  describe "validate_opts!" do
    test "fill_in rejects unknown options" do
      session = Mirage.visit(Mirage.FillInPage)

      assert_raise ArgumentError, ~r/unknown keys \[:bogus\]/, fn ->
        Mirage.fill_in(session, "Name", with: "Alice", bogus: true)
      end
    end

    test "click rejects unknown options" do
      session = Mirage.visit(Mirage.ClickPage)

      assert_raise ArgumentError, ~r/unknown keys \[:bogus\]/, fn ->
        Mirage.click(session, "button", bogus: true)
      end
    end

    test "assert_has rejects unknown options" do
      session = Mirage.visit(Mirage.ClickPage)

      assert_raise ArgumentError, ~r/unknown keys \[:bogus\]/, fn ->
        Mirage.assert_has(session, "button", bogus: true)
      end
    end

    test "refute_has rejects unknown options" do
      session = Mirage.visit(Mirage.ClickPage)

      assert_raise ArgumentError, ~r/unknown keys \[:bogus\]/, fn ->
        Mirage.refute_has(session, "nav", bogus: true)
      end
    end

    test "focus rejects unknown options" do
      session = Mirage.visit(Mirage.ClickPage)

      assert_raise ArgumentError, ~r/unknown keys \[:bogus\]/, fn ->
        Mirage.focus(session, "button", bogus: true)
      end
    end

    test "blur rejects unknown options" do
      session = Mirage.visit(Mirage.ClickPage)

      assert_raise ArgumentError, ~r/unknown keys \[:bogus\]/, fn ->
        Mirage.blur(session, "button", bogus: true)
      end
    end

    test "choose rejects unknown options" do
      session = Mirage.visit(Mirage.NonInteractivePage)

      assert_raise ArgumentError, ~r/unknown keys \[:bogus\]/, fn ->
        Mirage.choose(session, "whatever", bogus: true)
      end
    end

    test "check rejects unknown options" do
      session = Mirage.visit(Mirage.NonInteractivePage)

      assert_raise ArgumentError, ~r/unknown keys \[:bogus\]/, fn ->
        Mirage.check(session, "whatever", bogus: true)
      end
    end

    test "uncheck rejects unknown options" do
      session = Mirage.visit(Mirage.NonInteractivePage)

      assert_raise ArgumentError, ~r/unknown keys \[:bogus\]/, fn ->
        Mirage.uncheck(session, "whatever", bogus: true)
      end
    end

    test "select rejects unknown options" do
      session = Mirage.visit(Mirage.NonInteractivePage)

      assert_raise ArgumentError, ~r/unknown keys \[:bogus\]/, fn ->
        Mirage.select(session, "whatever", "opt", bogus: true)
      end
    end

    test "select_text rejects unknown options" do
      session = Mirage.visit(Mirage.NonInteractivePage)

      assert_raise ArgumentError, ~r/unknown keys \[:bogus\]/, fn ->
        Mirage.select_text(session, "whatever", bogus: true)
      end
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
