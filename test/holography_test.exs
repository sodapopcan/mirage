defmodule HolographyTest do
  use ExUnit.Case, async: true

  alias Holography.Session
  alias Hologram.Server
  alias Hologram.Component

  doctest Holography

  describe "click/3" do
    test "returns the session when a clickable element's text matches exactly" do
      session =
        Holography.ClickPage
        |> Holography.visit()
        |> Holography.click("Save changes now")

      assert %Session{
        page_module: Holography.ClickPage,
        page: %Component{},
        server: %Server{},
        ast: [_]
      } = session
    end

    test "trims surrounding whitespace when matching exactly" do
      session = Holography.visit(Holography.ClickWhitespacePage)
      assert %Session{} = Holography.click(session, "Save")
    end

    test "concatenates text from descendant elements when computing inner text" do
      session = Holography.visit(Holography.ClickNestedTextPage)
      assert %Session{} = Holography.click(session, "Click me")
    end

    test "finds a clickable element nested deep in the tree" do
      session = Holography.visit(Holography.ClickDeepPage)
      assert %Session{} = Holography.click(session, "Go")
    end

    test "matches substrings when exact: false" do
      session = Holography.visit(Holography.ClickPage)
      assert %Session{} = Holography.click(session, "changes", exact: false)
    end

    test "does not match substrings when exact is the default" do
      session = Holography.visit(Holography.ClickPage)

      assert_raise RuntimeError, ~r/No clickable element found/, fn ->
        Holography.click(session, "changes")
      end
    end

    test "raises when no element has a $click attribute" do
      session = Holography.visit(Holography.ClickNoAttrPage)

      assert_raise RuntimeError, ~r/No clickable element found with text: "Save"/, fn ->
        Holography.click(session, "Save")
      end
    end

    test "ignores clickables written inside an HTML comment" do
      session = Holography.visit(Holography.ClickCommentPage)

      assert_raise RuntimeError, ~r/No clickable element found with text: "Hidden"/, fn ->
        Holography.click(session, "Hidden")
      end
    end

    test "raises when text does not match any clickable element" do
      session = Holography.visit(Holography.ClickPage)

      assert_raise RuntimeError, ~r/No clickable element found with text: "Cancel"/, fn ->
        Holography.click(session, "Cancel")
      end
    end

    test "raises when more than one clickable element matches the text" do
      session = Holography.visit(Holography.ClickAmbiguousPage)

      assert_raise RuntimeError,
                   ~r/Ambiguous match: found 2 clickable elements with text: "Save"/,
                   fn ->
                     Holography.click(session, "Save")
                   end
    end

    test "dispatches the clicked action — page state reflects the call" do
      session =
        Holography.ClickPage
        |> Holography.visit()
        |> Holography.click("Save changes now")

      assert session.page.state.clicked == true
    end
  end

  describe "click/3 — navigation" do
    test "clicking a Hologram.UI.Link navigates the session to the linked page" do
      session = Holography.visit(Holography.HomePage)

      # Before the click we're on the home page, not the "other" page.
      assert rendered_text(session.ast) =~ "link to other page"
      refute rendered_text(session.ast) =~ "I am the other page"

      # Click the link.
      session = Holography.click(session, "link to other page")

      # The session now reflects the linked page: its AST was re-expanded
      # from `Holography.AnotherPage`'s template.
      assert rendered_text(session.ast) =~ "I am the other page"
      refute rendered_text(session.ast) =~ "link to other page"
    end

    test "clicking a Hologram.UI.Link wrapped in a custom component still navigates" do
      session = Holography.visit(Holography.WrappedLinkPage)

      assert rendered_text(session.ast) =~ "wrapped link to other page"
      refute rendered_text(session.ast) =~ "I am the other page"

      session = Holography.click(session, "wrapped link to other page")

      assert rendered_text(session.ast) =~ "I am the other page"
      refute rendered_text(session.ast) =~ "wrapped link to other page"
    end
  end

  describe "click/3 — commands" do
    test "an action that emits a command runs the command server-side" do
      tmp_path =
        Path.join(System.tmp_dir!(), "holography_#{System.unique_integer([:positive])}.txt")

      on_exit(fn -> File.rm(tmp_path) end)

      session = Holography.visit(Holography.CommandPage, %{tmp_path: tmp_path})
      refute File.exists?(tmp_path)

      Holography.click(session, "write file")

      # The `:write_file` action emitted a `:write_file` command, which ran
      # server-side and wrote the payload to disk.
      assert File.read!(tmp_path) == "written by command"
    end
  end

  describe "fill_in/3" do
    test "fills an input wrapped by a label matching exactly" do
      session = Holography.visit(Holography.FillInPage)
      assert %Session{} = Holography.fill_in(session, "Name", with: "Alice")
    end

    test "fills an input referenced by `for` matching the input's id" do
      session = Holography.visit(Holography.FillInPage)
      assert %Session{} = Holography.fill_in(session, "Email", with: "a@b.c")
    end

    test "trims surrounding whitespace in the label when matching exactly" do
      session = Holography.visit(Holography.FillInWhitespaceLabelPage)
      assert %Session{} = Holography.fill_in(session, "Name", with: "Alice")
    end

    test "concatenates text from descendant elements when computing the label's text" do
      session = Holography.visit(Holography.FillInNestedLabelPage)
      assert %Session{} = Holography.fill_in(session, "First name", with: "Alice")
    end

    test "finds a label nested deep in the tree" do
      session = Holography.visit(Holography.FillInDeepLabelPage)
      assert %Session{} = Holography.fill_in(session, "Email", with: "a@b.c")
    end

    test "matches substrings when exact: false" do
      session = Holography.visit(Holography.FillInLabelTextPage)
      assert %Session{} = Holography.fill_in(session, "Email", with: "a@b.c", exact: false)
    end

    test "does not match substrings when exact is the default" do
      session = Holography.visit(Holography.FillInLabelTextPage)

      assert_raise RuntimeError, ~r/No input found with label: "Email"/, fn ->
        Holography.fill_in(session, "Email", with: "a@b.c")
      end
    end

    test "raises when no label matches" do
      session = Holography.visit(Holography.FillInPage)

      assert_raise RuntimeError, ~r/No input found with label: "Nonsense"/, fn ->
        Holography.fill_in(session, "Nonsense", with: "x")
      end
    end

    test "ignores labels written inside an HTML comment" do
      session = Holography.visit(Holography.FillInCommentPage)

      assert_raise RuntimeError, ~r/No input found with label: "Hidden"/, fn ->
        Holography.fill_in(session, "Hidden", with: "x")
      end
    end

    test "raises when more than one label matches" do
      session = Holography.visit(Holography.FillInAmbiguousLabelPage)

      assert_raise RuntimeError, ~r/Ambiguous match: found 2 labels matching: "Name"/, fn ->
        Holography.fill_in(session, "Name", with: "Alice")
      end
    end

    test "raises when a matching `for` label has no corresponding input" do
      session = Holography.visit(Holography.FillInOrphanLabelPage)

      assert_raise RuntimeError, ~r/No input with id="missing"/, fn ->
        Holography.fill_in(session, "Orphan", with: "x")
      end
    end

    test "requires a `with:` option" do
      session = Holography.visit(Holography.FillInPage)

      assert_raise KeyError, ~r/key :with not found/, fn ->
        Holography.fill_in(session, "Name", [])
      end
    end
  end

  describe "fill_in/3 — action dispatch" do
    test "triggers the input's $change, passing the filled value as :value" do
      session = Holography.visit(Holography.FillInPage)

      # Before: the page hasn't seen any input yet.
      refute session.page.state[:name]

      session = Holography.fill_in(session, "Name", with: "Alice")

      # The `:update_name` action ran and wrote `:name` into the page state.
      assert session.page.state.name == "Alice"
    end

    test "merges the filled value with params declared on the attribute" do
      session =
        Holography.FillInPage
        |> Holography.visit()
        |> Holography.fill_in("Email", with: "a@b.c")

      # `$change={:set_field, field: :email}` + `value: "a@b.c"` ⇒ state[:email].
      assert session.page.state.email == "a@b.c"
    end

    test "also triggers the enclosing form's $change action" do
      session =
        Holography.FillInPage
        |> Holography.visit()
        |> Holography.fill_in("Name", with: "Alice")

      # The form's `$change` handler appends each change to a log — both
      # the input's own action AND the form's change action fired.
      assert session.page.state.change_log == ["Alice"]
    end

    test "does not trigger a $change action when the input has no enclosing form" do
      session =
        Holography.FillInPage
        |> Holography.visit()
        |> Holography.fill_in("Comment", with: "hi")

      # The comment textarea is outside the <form>, so only its $change ran.
      assert session.page.state.comment == "hi"
      assert session.page.state.change_log == []
    end
  end

  describe "click/3 — longhand action syntax" do
    test "longhand action without params" do
      session =
        Holography.LonghandActionPage
        |> Holography.visit()
        |> Holography.click("longhand increment")

      assert session.page.state.count == 1
    end

    test "longhand action with params" do
      session =
        Holography.LonghandActionPage
        |> Holography.visit()
        |> Holography.click("longhand add 10")

      assert session.page.state.count == 10
    end
  end

  describe "click/3 — direct command from event attribute" do
    test "command without params triggers the command and its follow-up action" do
      session =
        Holography.DirectCommandPage
        |> Holography.visit()
        |> Holography.click("run command")

      assert session.page.state.status == "done"
    end

    test "command with params" do
      session =
        Holography.DirectCommandPage
        |> Holography.visit()
        |> Holography.click("run param command")

      assert session.page.state.status == "finished"
    end
  end

  describe "click/3 — action chaining" do
    test "an action that calls put_action chains to the next action" do
      session =
        Holography.ActionChainPage
        |> Holography.visit()
        |> Holography.click("chain")

      assert session.page.state.log == ["first", "second"]
    end
  end

  describe "click/3 — put_page navigation" do
    test "an action that calls put_page navigates to the target page" do
      session =
        Holography.PutPagePage
        |> Holography.visit()
        |> Holography.click("go to other page")

      assert session.page_module == Holography.AnotherPage
      assert rendered_text(session.ast) =~ "I am the other page"
    end
  end

  # Recursively collects all text content from an expanded DOM AST so tests
  # can assert against the rendered page without caring about structure.
  defp rendered_text(nodes) when is_list(nodes) do
    Enum.map_join(nodes, "", &rendered_text/1)
  end

  defp rendered_text({:text, text}), do: text
  defp rendered_text({:element, _tag, _attrs, children}), do: rendered_text(children)
  defp rendered_text({:public_comment, children}), do: rendered_text(children)
  defp rendered_text(_other), do: ""
end
