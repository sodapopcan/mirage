defmodule Mirage.EventsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Mirage.Session

  # ---------------------------------------------------------------------------
  # Shared behaviour across click, focus, and blur
  # ---------------------------------------------------------------------------

  for event <- [:click, :focus, :blur] do
    describe "#{event}/3" do
      test "dispatches the action — page state reflects the call" do
        session =
          Mirage.EventPage
          |> Mirage.visit()
          |> apply_event(unquote(event), "button", "Save changes now")

        assert session.page.state.triggered == true
      end

      test "finds an element nested deep in the tree" do
        session = Mirage.visit(Mirage.EventDeepPage)
        assert %Session{} = apply_event(session, unquote(event), "a", "Go")
      end

      test "raises when no element has the attribute" do
        session = Mirage.visit(Mirage.EventNoAttrPage)

        assert_raise RuntimeError, ~r/No #{unquote(event)}able element found/, fn ->
          apply_event(session, unquote(event), "button")
        end
      end

      test "ignores elements written inside an HTML comment" do
        session = Mirage.visit(Mirage.EventCommentPage)

        assert_raise RuntimeError, ~r/No #{unquote(event)}able element found/, fn ->
          apply_event(session, unquote(event), "button")
        end
      end

      test "raises when text does not match" do
        session = Mirage.visit(Mirage.EventPage)

        assert_raise RuntimeError, ~r/No #{unquote(event)}able element found/, fn ->
          apply_event(session, unquote(event), "button", "Cancel")
        end
      end

      test "raises when more than one element matches" do
        session = Mirage.visit(Mirage.EventAmbiguousPage)

        assert_raise RuntimeError, ~r/Ambiguous match: found 2/, fn ->
          apply_event(session, unquote(event), "*", "Save")
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Click-specific tests
  # ---------------------------------------------------------------------------

  describe "click/3 — navigation" do
    test "clicking a Hologram.UI.Link navigates the session to the linked page" do
      session = Mirage.visit(Mirage.HomePage)

      assert rendered_text(session.ast) =~ "link to other page"
      refute rendered_text(session.ast) =~ "I am the other page"

      session = Mirage.click(session, "a", "link to other page")

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

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp apply_event(session, :click, selector), do: Mirage.click(session, selector)
  defp apply_event(session, :focus, selector), do: Mirage.focus(session, selector)
  defp apply_event(session, :blur, selector), do: Mirage.blur(session, selector)

  defp apply_event(session, :click, selector, text), do: Mirage.click(session, selector, text)
  defp apply_event(session, :focus, selector, text), do: Mirage.focus(session, selector, text)
  defp apply_event(session, :blur, selector, text), do: Mirage.blur(session, selector, text)

  defp rendered_text(nodes) when is_list(nodes) do
    Enum.map_join(nodes, "", &rendered_text/1)
  end

  defp rendered_text({:text, text}), do: text
  defp rendered_text({:element, _tag, _attrs, children}), do: rendered_text(children)
  defp rendered_text({:public_comment, children}), do: rendered_text(children)
  defp rendered_text(_other), do: ""
end
