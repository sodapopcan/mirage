defmodule Mirage.EventsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Hologram.Component
  alias Hologram.Server
  alias Mirage.Session

  describe "click/3" do
    test "returns the session when a clickable element's text matches exactly" do
      session =
        Mirage.ClickPage
        |> Mirage.visit()
        |> Mirage.click("button", "Save changes now")

      assert %Session{
        page_module: Mirage.ClickPage,
        page: %Component{},
        server: %Server{},
        ast: [_]
      } = session
    end

    test "trims surrounding whitespace when matching exactly" do
      session = Mirage.visit(Mirage.ClickWhitespacePage)
      assert %Session{} = Mirage.click(session, "button", "Save")
    end

    test "concatenates text from descendant elements when computing inner text" do
      session = Mirage.visit(Mirage.ClickNestedTextPage)
      assert %Session{} = Mirage.click(session, "button", "Click me")
    end

    test "finds a clickable element nested deep in the tree" do
      session = Mirage.visit(Mirage.ClickDeepPage)
      assert %Session{} = Mirage.click(session, "a", "Go")
    end

    test "matches substrings when exact: false" do
      session = Mirage.visit(Mirage.ClickPage)
      assert %Session{} = Mirage.click(session, "button", "changes", exact: false)
    end

    test "does not match substrings when exact is the default" do
      session = Mirage.visit(Mirage.ClickPage)

      assert_raise RuntimeError, ~r/No clickable element found/, fn ->
        Mirage.click(session, "button", "changes")
      end
    end

    test "raises when no element has a $click attribute" do
      session = Mirage.visit(Mirage.ClickNoAttrPage)

      assert_raise RuntimeError, ~r/No clickable element found matching "button"/, fn ->
        Mirage.click(session, "button")
      end
    end

    test "ignores clickables written inside an HTML comment" do
      session = Mirage.visit(Mirage.ClickCommentPage)

      assert_raise RuntimeError, ~r/No clickable element found matching "button"/, fn ->
        Mirage.click(session, "button")
      end
    end

    test "raises when text does not match any clickable element" do
      session = Mirage.visit(Mirage.ClickPage)

      assert_raise RuntimeError, ~r/No clickable element found matching "button", text: "Cancel"/, fn ->
        Mirage.click(session, "button", "Cancel")
      end
    end

    test "raises when more than one clickable element matches the text" do
      session = Mirage.visit(Mirage.ClickAmbiguousPage)

      assert_raise RuntimeError,
                   ~r/Ambiguous match: found 2 clickable elements/,
                   fn ->
                     Mirage.click(session, "*", "Save")
                   end
    end

    test "dispatches the clicked action — page state reflects the call" do
      session =
        Mirage.ClickPage
        |> Mirage.visit()
        |> Mirage.click("button", "Save changes now")

      assert session.page.state.clicked == true
    end
  end

  describe "click/3 — navigation" do
    test "clicking a Hologram.UI.Link navigates the session to the linked page" do
      session = Mirage.visit(Mirage.HomePage)

      # Before the click we're on the home page, not the "other" page.
      assert rendered_text(session.ast) =~ "link to other page"
      refute rendered_text(session.ast) =~ "I am the other page"

      # Click the link.
      session = Mirage.click(session, "a", "link to other page")

      # The session now reflects the linked page: its AST was re-expanded
      # from `Mirage.AnotherPage`'s template.
      assert rendered_text(session.ast) =~ "I am the other page"
      refute rendered_text(session.ast) =~ "link to other page"
    end

    test "clicking a Hologram.UI.Link wrapped in a custom component still navigates" do
      session = Mirage.visit(Mirage.WrappedLinkPage)

      assert rendered_text(session.ast) =~ "wrapped link to other page"
      refute rendered_text(session.ast) =~ "I am the other page"

      session = Mirage.click(session, "a", "wrapped link to other page")

      assert rendered_text(session.ast) =~ "I am the other page"
      refute rendered_text(session.ast) =~ "wrapped link to other page"
    end
  end

  describe "click/3 — commands" do
    test "an action that emits a command runs the command server-side" do
      tmp_path =
        Path.join(System.tmp_dir!(), "mirage_#{System.unique_integer([:positive])}.txt")

      on_exit(fn -> File.rm(tmp_path) end)

      session = Mirage.visit(Mirage.CommandPage, %{tmp_path: tmp_path})
      refute File.exists?(tmp_path)

      Mirage.click(session, "button", "write file")

      # The `:write_file` action emitted a `:write_file` command, which ran
      # server-side and wrote the payload to disk.
      assert File.read!(tmp_path) == "written by command"
    end

    test "clicks a command with no params" do
      assert capture_io(fn ->
        Mirage.ClickCommandPage
        |> Mirage.visit()
        |> Mirage.click("button", "No params")
      end) == "No params!\n"
    end
  end

  describe "click/3 — longhand action syntax" do
    test "longhand action without params" do
      session =
        Mirage.LonghandActionPage
        |> Mirage.visit()
        |> Mirage.click("button", "longhand increment")

      assert session.page.state.count == 1
    end

    test "longhand action with params" do
      session =
        Mirage.LonghandActionPage
        |> Mirage.visit()
        |> Mirage.click("button", "longhand add 10")

      assert session.page.state.count == 10
    end
  end

  describe "click/3 — direct command from event attribute" do
    test "command without params triggers the command and its follow-up action" do
      session =
        Mirage.DirectCommandPage
        |> Mirage.visit()
        |> Mirage.click("button", "run command")

      assert session.page.state.status == "done"
    end

    test "command with params" do
      session =
        Mirage.DirectCommandPage
        |> Mirage.visit()
        |> Mirage.click("button", "run param command")

      assert session.page.state.status == "finished"
    end
  end

  describe "click/3 — action chaining" do
    test "an action that calls put_action chains to the next action" do
      session =
        Mirage.ActionChainPage
        |> Mirage.visit()
        |> Mirage.click("button", "chain")

      assert session.page.state.log == ["first", "second"]
    end
  end

  describe "click/3 — put_page navigation" do
    test "an action that calls put_page navigates to the target page" do
      session =
        Mirage.PutPagePage
        |> Mirage.visit()
        |> Mirage.click("button", "go to other page")

      assert session.page_module == Mirage.AnotherPage
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
