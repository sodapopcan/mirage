defmodule HoloTestTest do
  use ExUnit.Case, async: true

  alias HoloTest.Session

  doctest HoloTest

  describe "click/3" do
    test "returns the session when a clickable element's text matches exactly" do
      ast = [
        {:element, "button", [{"$click", "save"}], [{:text, "Save"}]}
      ]

      session = %Session{ast: ast}
      assert HoloTest.click(session, "Save") == session
    end

    test "trims surrounding whitespace when matching exactly" do
      ast = [
        {:element, "button", [{"$click", "save"}], [{:text, "  Save  "}]}
      ]

      assert %Session{} = HoloTest.click(%Session{ast: ast}, "Save")
    end

    test "concatenates text from descendant elements when computing inner text" do
      ast = [
        {:element, "button", [{"$click", "submit"}],
         [
           {:element, "span", [], [{:text, "Click "}]},
           {:element, "span", [], [{:text, "me"}]}
         ]}
      ]

      assert %Session{} = HoloTest.click(%Session{ast: ast}, "Click me")
    end

    test "finds a clickable element nested deep in the tree" do
      ast = [
        {:element, "div", [],
         [
           {:element, "section", [],
            [
              {:element, "a", [{"$click", "go"}], [{:text, "Go"}]}
            ]}
         ]}
      ]

      assert %Session{} = HoloTest.click(%Session{ast: ast}, "Go")
    end

    test "ignores clicks in comments" do
      ast = [
        {:public_comment,
         [
           {:element, "button", [{"$click", "x"}], [{:text, "Hidden"}]}
         ]}
      ]

      assert_raise RuntimeError, ~r/No clickable element found/, fn ->
        HoloTest.click(%Session{ast: ast}, "Hidden")
      end
    end

    test "matches substrings when exact: false" do
      ast = [
        {:element, "button", [{"$click", "save"}], [{:text, "Save changes now"}]}
      ]

      assert %Session{} = HoloTest.click(%Session{ast: ast}, "changes", exact: false)
    end

    test "does not match substrings when exact is the default" do
      ast = [
        {:element, "button", [{"$click", "save"}], [{:text, "Save changes now"}]}
      ]

      assert_raise RuntimeError, ~r/No clickable element found/, fn ->
        HoloTest.click(%Session{ast: ast}, "changes")
      end
    end

    test "raises when no element has a $click attribute" do
      ast = [
        {:element, "button", [], [{:text, "Save"}]}
      ]

      assert_raise RuntimeError, ~r/No clickable element found with text: "Save"/, fn ->
        HoloTest.click(%Session{ast: ast}, "Save")
      end
    end

    test "raises when text does not match any clickable element" do
      ast = [
        {:element, "button", [{"$click", "save"}], [{:text, "Save"}]}
      ]

      assert_raise RuntimeError, ~r/No clickable element found with text: "Cancel"/, fn ->
        HoloTest.click(%Session{ast: ast}, "Cancel")
      end
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

  # Recursively collects all text content from an expanded DOM AST so tests
  # can assert against the rendered page without caring about structure.
  defp rendered_text(nodes) when is_list(nodes),
    do: Enum.map_join(nodes, "", &rendered_text/1)

  defp rendered_text({:text, text}), do: text
  defp rendered_text({:element, _tag, _attrs, children}), do: rendered_text(children)
  defp rendered_text({:public_comment, children}), do: rendered_text(children)
  defp rendered_text(_other), do: ""
end
