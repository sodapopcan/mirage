defmodule MirageTest do
  use ExUnit.Case, async: true

  alias Mirage.Session

  doctest Mirage

  describe "visit/3" do
    test "returns a session" do
      assert %Session{} = Mirage.visit(%Hologram.Server{}, Mirage.ClickPage)
    end

    test "sets page_module" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.ClickPage)
      assert session.page_module == Mirage.ClickPage
    end

    test "accepts params as keyword list" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.CommandPage, tmp_path: "/tmp/hello")
      assert session.params == %{tmp_path: "/tmp/hello"}
    end

    test "defaults params to empty map" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.ClickPage)
      assert session.params == %{}
    end

    test "renders the page template" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.ClickPage)
      Mirage.assert_has(session, "button")
    end

    test "runs page init" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.ClickPage)
      refute Map.has_key?(session.page.state, :clicked)
    end
  end

  describe "drain init lifecycle" do
    test "drains next_action set during init" do
      Mirage.visit(%Hologram.Server{}, Mirage.InitNextActionPage)
      |> Mirage.assert_has("p", "finalized")
    end

    test "drains chained next_actions" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.InitChainedActionPage)

      assert session.page.state.steps == [:one, :two]
    end

    test "drains next_command set during init" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.InitNextCommandPage)

      assert Hologram.Server.get_session(session.server, :loaded) == true
    end

    test "navigates when chained action sets next_page" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.InitChainedActionNavigatePage)

      assert session.page_module == Mirage.AnotherPage
    end

    test "navigates when init sets next_page" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.InitNextPagePage)

      assert session.page_module == Mirage.AnotherPage
    end

    test "navigates with params when init sets next_page" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.InitNextPageWithParamsPage)

      assert session.page_module == Mirage.CommandPage
      assert session.params == %{tmp_path: "/tmp/redirected"}
    end
  end

  describe "component init actions" do
    test "drains next_action set during component init" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.InitActionComponentPage)
      |> Mirage.assert_has(".count", "42")
    end

    test "component state reflects init action when queried" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.InitActionComponentPage)

      {_module, component} = session.bookkeeping.components["counter"]
      assert component.state.count == 42
    end
  end

  describe "visit with a pre-configured server" do
    test "server is available during page init" do
      %Hologram.Server{}
      |> Hologram.Server.put_session(:greeting, "hello")
      |> Mirage.visit(Mirage.PreparePage)
      |> Mirage.assert_has("p", "Greeting: hello")
    end

    test "without pre-configured server, server has no session data" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.PreparePage)
      |> Mirage.assert_has("p", "Greeting: none")
    end

    test "visit params still work with a pre-configured server" do
      session =
        %Hologram.Server{}
        |> Hologram.Server.put_session(:greeting, "hi")
        |> Mirage.visit(Mirage.PreparePage, some_param: "value")

      assert session.params == %{some_param: "value"}
    end
  end

  describe "reload/1" do
    test "resets page state" do
      session =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.ClickPage)
        |> Mirage.click("button", "Save changes now")

      assert session.page.state.clicked == true

      session = Mirage.reload(session)
      refute Map.has_key?(session.page.state, :clicked)
    end

    test "preserves params across reload" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.CommandPage, tmp_path: "/tmp/test")
      session = Mirage.reload(session)

      assert session.params == %{tmp_path: "/tmp/test"}
      assert session.page_module == Mirage.CommandPage
    end
  end

  describe "click_link/2" do
    test "clicks on a link" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.HomePage)
      |> Mirage.click_link("I link to the same page")
      |> Mirage.assert_page(Mirage.AnotherPage)
    end

    test "accepts opts" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.HomePage)
      |> Mirage.click_link("I link to", exact: false)
      |> Mirage.assert_page(Mirage.AnotherPage)
    end
  end

  describe "click_button/2" do
    test "clicks on a button" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.HomePage)
      |> Mirage.click_button("I button to the same page")
      |> Mirage.assert_page(Mirage.AnotherPage)
    end

    test "accepts opts" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.HomePage)
      |> Mirage.click_button("I button to", exact: false)
      |> Mirage.assert_page(Mirage.AnotherPage)
    end

    test "dispatches form $submit when button has no $click" do
      session =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.FormSubmitPage)
        |> Mirage.click_button("Submit")

      assert session.page.state.submitted == true
      assert session.page.state.submit_data["token"] == "abc123"
    end

    test "dispatches form $submit for input[type=submit] with no $click" do
      session =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.FormSubmitInputPage)
        |> Mirage.click_button("Go")

      assert session.page.state.submitted == true
    end

    test "dispatches form $submit for external button with form attribute" do
      session =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.FormSubmitExternalButtonPage)
        |> Mirage.click_button("Submit")

      assert session.page.state.submitted == true
      assert session.page.state.submit_data["name"] == "alice"
    end

    test "dispatches form $submit for external input[type=submit] with form attribute" do
      session =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.FormSubmitExternalInputPage)
        |> Mirage.click_button("Go")

      assert session.page.state.submitted == true
    end
  end

  describe "fill_in/3" do
    test "fills an input wrapped by a label matching exactly" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInPage)
      assert %Session{} = Mirage.fill_in(session, "Name", with: "Alice")
    end

    test "fills an input referenced by `for` matching the input's id" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInPage)
      assert %Session{} = Mirage.fill_in(session, "Email", with: "a@b.c")
    end

    test "trims surrounding whitespace in the label when matching exactly" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInWhitespaceLabelPage)
      assert %Session{} = Mirage.fill_in(session, "Name", with: "Alice")
    end

    test "concatenates text from descendant elements when computing the label's text" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInNestedLabelPage)
      assert %Session{} = Mirage.fill_in(session, "First name", with: "Alice")
    end

    test "finds a label nested deep in the tree" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInDeepLabelPage)
      assert %Session{} = Mirage.fill_in(session, "Email", with: "a@b.c")
    end

    test "matches substrings when exact: false" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInLabelTextPage)
      assert %Session{} = Mirage.fill_in(session, "Email", with: "a@b.c", exact: false)
    end

    test "does not match substrings when exact is the default" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInLabelTextPage)

      assert_raise RuntimeError, ~r/No input found with label: "Email"/, fn ->
        Mirage.fill_in(session, "Email", with: "a@b.c")
      end
    end

    test "raises when no label matches" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInPage)

      assert_raise RuntimeError, ~r/No input found with label: "Nonsense"/, fn ->
        Mirage.fill_in(session, "Nonsense", with: "x")
      end
    end

    test "ignores labels written inside an HTML comment" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInCommentPage)

      assert_raise RuntimeError, ~r/No input found with label: "Hidden"/, fn ->
        Mirage.fill_in(session, "Hidden", with: "x")
      end
    end

    test "raises when more than one label matches" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInAmbiguousLabelPage)

      assert_raise RuntimeError, ~r/Ambiguous match: found 2 labels matching: "Name"/, fn ->
        Mirage.fill_in(session, "Name", with: "Alice")
      end
    end

    test "raises when a matching `for` label has no corresponding input" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInOrphanLabelPage)

      assert_raise RuntimeError, ~r/No input with id="missing"/, fn ->
        Mirage.fill_in(session, "Orphan", with: "x")
      end
    end

    test "requires a `with:` option" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInPage)

      assert_raise KeyError, ~r/key :with not found/, fn ->
        Mirage.fill_in(session, "Name", [])
      end
    end
  end

  describe "fill_in_hidden/3" do
    test "fills a hidden input by name and triggers $change" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.FillInHiddenPage)
      |> Mirage.fill_in_hidden("token", with: "new_token")
      |> Mirage.assert_has("p", "new_token")
    end

    test "fills a hidden input outside a form" do
      session =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.FillInHiddenPage)
        |> Mirage.fill_in_hidden("outside_form", with: "updated")

      assert session.page.state.token == "updated"
    end

    test "triggers form $change with collected form data" do
      session =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.FillInHiddenPage)
        |> Mirage.fill_in_hidden("token", with: "new_token")

      assert [form_data] = session.page.state.form_log
      assert form_data["token"] == "new_token"
    end

    test "raises when no hidden input matches name" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInHiddenPage)

      assert_raise RuntimeError, ~r/No hidden input found with name: "nope"/, fn ->
        Mirage.fill_in_hidden(session, "nope", with: "x")
      end
    end

    test "raises when input with name is not hidden" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInHiddenPage)

      assert_raise RuntimeError, ~r/is not hidden/, fn ->
        Mirage.fill_in_hidden(session, "visible", with: "x")
      end
    end

    test "raises for disabled hidden input" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInHiddenPage)

      assert_raise RuntimeError, ~r/is disabled/, fn ->
        Mirage.fill_in_hidden(session, "disabled_hidden", with: "x")
      end
    end

    test "raises for readonly hidden input" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInHiddenPage)

      assert_raise RuntimeError, ~r/is readonly/, fn ->
        Mirage.fill_in_hidden(session, "readonly_hidden", with: "x")
      end
    end
  end

  describe "non-interactive inputs" do
    test "fill_in raises for type=hidden input" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/is hidden/, fn ->
        Mirage.fill_in(session, "Hidden input", with: "x")
      end
    end

    test "fill_in raises for input with hidden attribute" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/is hidden/, fn ->
        Mirage.fill_in(session, "Hidden attr", with: "x")
      end
    end

    test "fill_in raises for disabled input" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/is disabled/, fn ->
        Mirage.fill_in(session, "Disabled input", with: "x")
      end
    end

    test "fill_in raises for readonly input" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/is readonly/, fn ->
        Mirage.fill_in(session, "Readonly input", with: "x")
      end
    end

    test "fill_in raises for disabled textarea" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/is disabled/, fn ->
        Mirage.fill_in(session, "Disabled textarea", with: "x")
      end
    end

    test "fill_in raises for readonly textarea" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/is readonly/, fn ->
        Mirage.fill_in(session, "Readonly textarea", with: "x")
      end
    end

    test "fill_in still works for normal input" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.NonInteractivePage)
      assert %Session{} = Mirage.fill_in(session, "Normal input", with: "hello")
    end

    test "select raises for disabled select" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/is disabled/, fn ->
        Mirage.select(session, "Disabled select", "A")
      end
    end

    test "select raises for hidden select" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/is hidden/, fn ->
        Mirage.select(session, "Hidden select", "A")
      end
    end

    test "choose raises for disabled radio" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/is disabled/, fn ->
        Mirage.choose(session, "Disabled radio")
      end
    end

    test "check raises for disabled checkbox" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/is disabled/, fn ->
        Mirage.check(session, "Disabled checkbox")
      end
    end

    test "uncheck raises for disabled checkbox" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/is disabled/, fn ->
        Mirage.uncheck(session, "Disabled checkbox")
      end
    end
  end

  describe "fill_in/3 — action dispatch" do
    test "triggers the input's $change, passing the filled value as :value" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInPage)

      # Before: the page hasn't seen any input yet.
      refute session.page.state[:name]

      session = Mirage.fill_in(session, "Name", with: "Alice")

      # The `:update_name` action ran and wrote `:name` into the page state.
      assert session.page.state.name == "Alice"
    end

    test "merges the filled value with params declared on the attribute" do
      session =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.FillInPage)
        |> Mirage.fill_in("Email", with: "a@b.c")

      # `$change={:set_field, field: :email}` + `value: "a@b.c"` ⇒ state[:email].
      assert session.page.state.email == "a@b.c"
    end

    test "also triggers the enclosing form's $change action with form data" do
      session =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.FillInPage)
        |> Mirage.fill_in("Name", with: "Alice")

      # The form's `$change` handler receives all named field values.
      assert [form_data] = session.page.state.change_log
      assert form_data["name"] == "Alice"
      assert form_data["email"] == ""
    end

    test "does not trigger a $change action when the input has no enclosing form" do
      session =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.FillInPage)
        |> Mirage.fill_in("Comment", with: "hi")

      # The comment textarea is outside the <form>, so only its $change ran.
      assert session.page.state.comment == "hi"
      assert session.page.state.change_log == []
    end
  end

  describe "validate_opts!" do
    test "fill_in rejects unknown options" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.FillInPage)

      assert_raise ArgumentError, ~r/unknown keys \[:bogus\]/, fn ->
        Mirage.fill_in(session, "Name", with: "Alice", bogus: true)
      end
    end

    test "click rejects unknown options" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.ClickPage)

      assert_raise ArgumentError, ~r/unknown keys \[:bogus\]/, fn ->
        Mirage.click(session, "button", bogus: true)
      end
    end

    test "assert_has rejects unknown options" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.ClickPage)

      assert_raise ArgumentError, ~r/unknown keys \[:bogus\]/, fn ->
        Mirage.assert_has(session, "button", bogus: true)
      end
    end

    test "refute_has rejects unknown options" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.ClickPage)

      assert_raise ArgumentError, ~r/unknown keys \[:bogus\]/, fn ->
        Mirage.refute_has(session, "nav", bogus: true)
      end
    end

    test "focus rejects unknown options" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.ClickPage)

      assert_raise ArgumentError, ~r/unknown keys \[:bogus\]/, fn ->
        Mirage.focus(session, "button", bogus: true)
      end
    end

    test "blur rejects unknown options" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.ClickPage)

      assert_raise ArgumentError, ~r/unknown keys \[:bogus\]/, fn ->
        Mirage.blur(session, "button", bogus: true)
      end
    end

    test "choose rejects unknown options" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.NonInteractivePage)

      assert_raise ArgumentError, ~r/unknown keys \[:bogus\]/, fn ->
        Mirage.choose(session, "whatever", bogus: true)
      end
    end

    test "check rejects unknown options" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.NonInteractivePage)

      assert_raise ArgumentError, ~r/unknown keys \[:bogus\]/, fn ->
        Mirage.check(session, "whatever", bogus: true)
      end
    end

    test "uncheck rejects unknown options" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.NonInteractivePage)

      assert_raise ArgumentError, ~r/unknown keys \[:bogus\]/, fn ->
        Mirage.uncheck(session, "whatever", bogus: true)
      end
    end

    test "select rejects unknown options" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.NonInteractivePage)

      assert_raise ArgumentError, ~r/unknown keys \[:bogus\]/, fn ->
        Mirage.select(session, "whatever", "opt", bogus: true)
      end
    end

    test "select_text rejects unknown options" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.NonInteractivePage)

      assert_raise ArgumentError, ~r/unknown keys \[:bogus\]/, fn ->
        Mirage.select_text(session, "whatever", bogus: true)
      end
    end
  end

  describe "implicit component targeting" do
    test "clicking a button inside a component targets that component" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.ImplicitTargetPage)
      |> Mirage.click("button", "Add")
      |> Mirage.assert_has(".count", "43")
    end

    test "clicking a button inside a component does not affect page state" do
      session =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.ImplicitTargetPage)
        |> Mirage.click("button", "Add")

      assert session.page.state.page_data == "untouched"
    end

    test "clicking a page-level button still targets the page" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.ImplicitTargetPage)
      |> Mirage.click("button", "Page Button")
      |> Mirage.assert_has("#page-data", "page_action_ran")
    end

    test "form $submit inside a component targets that component" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.ImplicitTargetPage)
      |> Mirage.fill_in("Name", with: "Alice")
      |> Mirage.click("button", "Save")
      |> Mirage.assert_has(".submitted", "Alice")
    end

    test "form $change inside a component targets that component" do
      session =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.ImplicitTargetPage)
        |> Mirage.fill_in("Name", with: "Bob")

      {_module, component} = session.bookkeeping.components["form_counter"]
      assert component.state.name == "Bob"
    end

    test "multiple clicks accumulate on the component" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.ImplicitTargetPage)
      |> Mirage.click("button", "Add")
      |> Mirage.click("button", "Add")
      |> Mirage.click("button", "Add")
      |> Mirage.assert_has(".count", "45")
    end
  end

  describe "assert_disabled/2" do
    test "passes for a disabled input" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.NonInteractivePage)
      |> Mirage.assert_disabled("Disabled input")
    end

    test "raises for an enabled input" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.NonInteractivePage)

      assert_raise ExUnit.AssertionError, ~r/to be disabled/, fn ->
        Mirage.assert_disabled(session, "Readonly input")
      end
    end

    test "raises when no input matches label" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/No input found/, fn ->
        Mirage.assert_disabled(session, "Nonexistent")
      end
    end
  end

  describe "refute_disabled/2" do
    test "passes for a non-disabled input" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.NonInteractivePage)
      |> Mirage.refute_disabled("Readonly input")
    end

    test "raises for a disabled input" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.NonInteractivePage)

      assert_raise ExUnit.AssertionError, ~r/not to be disabled/, fn ->
        Mirage.refute_disabled(session, "Disabled input")
      end
    end
  end

  describe "assert_readonly/2" do
    test "passes for a readonly input" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.NonInteractivePage)
      |> Mirage.assert_readonly("Readonly input")
    end

    test "raises for a non-readonly input" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.NonInteractivePage)

      assert_raise ExUnit.AssertionError, ~r/to be readonly/, fn ->
        Mirage.assert_readonly(session, "Disabled input")
      end
    end

    test "raises when no input matches label" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.NonInteractivePage)

      assert_raise RuntimeError, ~r/No input found/, fn ->
        Mirage.assert_readonly(session, "Nonexistent")
      end
    end
  end

  describe "refute_readonly/2" do
    test "passes for a non-readonly input" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.NonInteractivePage)
      |> Mirage.refute_readonly("Disabled input")
    end

    test "raises for a readonly input" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.NonInteractivePage)

      assert_raise ExUnit.AssertionError, ~r/not to be readonly/, fn ->
        Mirage.refute_readonly(session, "Readonly input")
      end
    end
  end

  describe "action retargeting" do
    test "component action with target: page dispatches to the page" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.RetargetPage)
      |> Mirage.click("button", "Notify")
      |> Mirage.assert_has("#notif", "counter")
    end

    test "component state still updates before retargeted action" do
      session =
        %Hologram.Server{}
        |> Mirage.visit(Mirage.RetargetPage)
        |> Mirage.click("button", "Notify")

      {_module, component} = session.bookkeeping.components["rc"]
      assert component.state.count == 1
    end
  end

  describe "{%if} blocks" do
    test "elements inside a false if block are not visible" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.IfBlockPage)
      |> Mirage.refute_has("p", "Visible content")
      |> Mirage.assert_has("p", "Always here")
    end

    test "click cannot reach a button inside a false if block" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.IfBlockPage)

      assert_raise RuntimeError, ~r/No clickable element found/, fn ->
        Mirage.click(session, "button", "Hidden button")
      end
    end

    test "fill_in cannot reach an input inside a false if block" do
      session = Mirage.visit(%Hologram.Server{}, Mirage.IfBlockPage)

      assert_raise RuntimeError, ~r/No input found with label/, fn ->
        Mirage.fill_in(session, "Hidden input", with: "x")
      end
    end

    test "elements appear after the condition becomes true" do
      %Hologram.Server{}
      |> Mirage.visit(Mirage.IfBlockPage)
      |> Mirage.click("button", "Show")
      |> Mirage.assert_has("p", "Visible content")
      |> Mirage.assert_has("button", "Hidden button")
    end
  end
end
