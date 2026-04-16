defmodule HoloTestTest do
  use ExUnit.Case, async: true

  alias HoloTest.Session

  doctest HoloTest

  describe "click/3" do
    test "returns the session when a clickable element's text matches exactly" do
      session = HoloTest.visit(HoloTest.ClickPage)
      assert %Session{} = HoloTest.click(session, "Save changes now")
    end

    test "trims surrounding whitespace when matching exactly" do
      session = HoloTest.visit(HoloTest.ClickWhitespacePage)
      assert %Session{} = HoloTest.click(session, "Save")
    end

    test "concatenates text from descendant elements when computing inner text" do
      session = HoloTest.visit(HoloTest.ClickNestedTextPage)
      assert %Session{} = HoloTest.click(session, "Click me")
    end

    test "finds a clickable element nested deep in the tree" do
      session = HoloTest.visit(HoloTest.ClickDeepPage)
      assert %Session{} = HoloTest.click(session, "Go")
    end

    test "matches substrings when exact: false" do
      session = HoloTest.visit(HoloTest.ClickPage)
      assert %Session{} = HoloTest.click(session, "changes", exact: false)
    end

    test "does not match substrings when exact is the default" do
      session = HoloTest.visit(HoloTest.ClickPage)

      assert_raise RuntimeError, ~r/No clickable element found/, fn ->
        HoloTest.click(session, "changes")
      end
    end

    test "raises when no element has a $click attribute" do
      session = HoloTest.visit(HoloTest.ClickNoAttrPage)

      assert_raise RuntimeError, ~r/No clickable element found with text: "Save"/, fn ->
        HoloTest.click(session, "Save")
      end
    end

    test "ignores clickables written inside an HTML comment" do
      session = HoloTest.visit(HoloTest.ClickCommentPage)

      assert_raise RuntimeError, ~r/No clickable element found with text: "Hidden"/, fn ->
        HoloTest.click(session, "Hidden")
      end
    end

    test "raises when text does not match any clickable element" do
      session = HoloTest.visit(HoloTest.ClickPage)

      assert_raise RuntimeError, ~r/No clickable element found with text: "Cancel"/, fn ->
        HoloTest.click(session, "Cancel")
      end
    end

    test "raises when more than one clickable element matches the text" do
      session = HoloTest.visit(HoloTest.ClickAmbiguousPage)

      assert_raise RuntimeError,
                   ~r/Ambiguous match: found 2 clickable elements with text: "Save"/,
                   fn ->
                     HoloTest.click(session, "Save")
                   end
    end

    test "dispatches the clicked action — page state reflects the call" do
      session =
        HoloTest.ClickPage
        |> HoloTest.visit()
        |> HoloTest.click("Save changes now")

      assert session.page.state.clicked == true
    end
  end

  describe "click/3 — navigation" do
    test "clicking a Hologram.UI.Link navigates the session to the linked page" do
      session = HoloTest.visit(HoloTest.HomePage)

      # Before the click we're on the home page, not the "other" page.
      assert rendered_text(session.ast) =~ "link to other page"
      refute rendered_text(session.ast) =~ "I am the other page"

      # Click the link.
      session = HoloTest.click(session, "link to other page")

      # The session now reflects the linked page: its AST was re-expanded
      # from `HoloTest.AnotherPage`'s template.
      assert rendered_text(session.ast) =~ "I am the other page"
      refute rendered_text(session.ast) =~ "link to other page"
    end

    test "clicking a Hologram.UI.Link wrapped in a custom component still navigates" do
      session = HoloTest.visit(HoloTest.WrappedLinkPage)

      assert rendered_text(session.ast) =~ "wrapped link to other page"
      refute rendered_text(session.ast) =~ "I am the other page"

      session = HoloTest.click(session, "wrapped link to other page")

      assert rendered_text(session.ast) =~ "I am the other page"
      refute rendered_text(session.ast) =~ "wrapped link to other page"
    end
  end

  describe "click/3 — commands" do
    test "an action that emits a command runs the command server-side" do
      tmp_path =
        Path.join(System.tmp_dir!(), "holo_test_#{System.unique_integer([:positive])}.txt")

      on_exit(fn -> File.rm(tmp_path) end)

      session = HoloTest.visit(HoloTest.CommandPage, %{tmp_path: tmp_path})
      refute File.exists?(tmp_path)

      HoloTest.click(session, "write file")

      # The `:write_file` action emitted a `:write_file` command, which ran
      # server-side and wrote the payload to disk.
      assert File.read!(tmp_path) == "written by command"
    end
  end

  describe "fill_in/3" do
    test "fills an input wrapped by a label matching exactly" do
      session = HoloTest.visit(HoloTest.FillInPage)
      assert %Session{} = HoloTest.fill_in(session, "Name", with: "Alice")
    end

    test "fills an input referenced by `for` matching the input's id" do
      session = HoloTest.visit(HoloTest.FillInPage)
      assert %Session{} = HoloTest.fill_in(session, "Email", with: "a@b.c")
    end

    test "trims surrounding whitespace in the label when matching exactly" do
      session = HoloTest.visit(HoloTest.FillInWhitespaceLabelPage)
      assert %Session{} = HoloTest.fill_in(session, "Name", with: "Alice")
    end

    test "concatenates text from descendant elements when computing the label's text" do
      session = HoloTest.visit(HoloTest.FillInNestedLabelPage)
      assert %Session{} = HoloTest.fill_in(session, "First name", with: "Alice")
    end

    test "finds a label nested deep in the tree" do
      session = HoloTest.visit(HoloTest.FillInDeepLabelPage)
      assert %Session{} = HoloTest.fill_in(session, "Email", with: "a@b.c")
    end

    test "matches substrings when exact: false" do
      session = HoloTest.visit(HoloTest.FillInLabelTextPage)
      assert %Session{} = HoloTest.fill_in(session, "Email", with: "a@b.c", exact: false)
    end

    test "does not match substrings when exact is the default" do
      session = HoloTest.visit(HoloTest.FillInLabelTextPage)

      assert_raise RuntimeError, ~r/No input found with label: "Email"/, fn ->
        HoloTest.fill_in(session, "Email", with: "a@b.c")
      end
    end

    test "raises when no label matches" do
      session = HoloTest.visit(HoloTest.FillInPage)

      assert_raise RuntimeError, ~r/No input found with label: "Nonsense"/, fn ->
        HoloTest.fill_in(session, "Nonsense", with: "x")
      end
    end

    test "ignores labels written inside an HTML comment" do
      session = HoloTest.visit(HoloTest.FillInCommentPage)

      assert_raise RuntimeError, ~r/No input found with label: "Hidden"/, fn ->
        HoloTest.fill_in(session, "Hidden", with: "x")
      end
    end

    test "raises when more than one label matches" do
      session = HoloTest.visit(HoloTest.FillInAmbiguousLabelPage)

      assert_raise RuntimeError, ~r/Ambiguous match: found 2 labels matching: "Name"/, fn ->
        HoloTest.fill_in(session, "Name", with: "Alice")
      end
    end

    test "raises when a matching `for` label has no corresponding input" do
      session = HoloTest.visit(HoloTest.FillInOrphanLabelPage)

      assert_raise RuntimeError, ~r/No input with id="missing"/, fn ->
        HoloTest.fill_in(session, "Orphan", with: "x")
      end
    end

    test "requires a `with:` option" do
      session = HoloTest.visit(HoloTest.FillInPage)

      assert_raise KeyError, ~r/key :with not found/, fn ->
        HoloTest.fill_in(session, "Name", [])
      end
    end
  end

  describe "fill_in/3 — action dispatch" do
    test "triggers the input's $action, passing the filled value as :value" do
      session = HoloTest.visit(HoloTest.FillInPage)

      # Before: the page hasn't seen any input yet.
      refute session.page.state[:name]

      session = HoloTest.fill_in(session, "Name", with: "Alice")

      # The `:update_name` action ran and wrote `:name` into the page state.
      assert session.page.state.name == "Alice"
    end

    test "merges the filled value with params declared on the attribute" do
      session =
        HoloTest.FillInPage
        |> HoloTest.visit()
        |> HoloTest.fill_in("Email", with: "a@b.c")

      # `$action={:set_field, field: :email}` + `value: "a@b.c"` ⇒ state[:email].
      assert session.page.state.email == "a@b.c"
    end

    test "also triggers the enclosing form's $change action" do
      session =
        HoloTest.FillInPage
        |> HoloTest.visit()
        |> HoloTest.fill_in("Name", with: "Alice")

      # The form's `$change` handler appends each change to a log — both
      # the input's own action AND the form's change action fired.
      assert session.page.state.change_log == ["Alice"]
    end

    test "does not trigger a $change action when the input has no enclosing form" do
      session =
        HoloTest.FillInPage
        |> HoloTest.visit()
        |> HoloTest.fill_in("Comment", with: "hi")

      # The comment textarea is outside the <form>, so only its $action ran.
      assert session.page.state.comment == "hi"
      assert session.page.state.change_log == []
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
