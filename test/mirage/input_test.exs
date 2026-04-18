defmodule Mirage.InputTest do
  use ExUnit.Case, async: true

  alias Mirage.Session

  describe "choose/2" do
    test "dispatches $change with the radio button's value attribute" do
      session =
        Mirage.ChoosePage
        |> Mirage.visit()
        |> Mirage.choose("Yes")

      assert session.page.state.choice == "yes"
    end

    test "chooses among multiple options" do
      session =
        Mirage.ChoosePage
        |> Mirage.visit()
        |> Mirage.choose("No")

      assert session.page.state.choice == "no"
    end

    test "matches substrings when exact: false" do
      session =
        Mirage.ChoosePage
        |> Mirage.visit()
        |> Mirage.choose("Ye", exact: false)

      assert session.page.state.choice == "yes"
    end

    test "raises when no label matches" do
      session = Mirage.visit(Mirage.ChoosePage)

      assert_raise RuntimeError, ~r/No radio button found with label: "Maybe"/, fn ->
        Mirage.choose(session, "Maybe")
      end
    end

    test "raises when more than one label matches" do
      session = Mirage.visit(Mirage.ChooseAmbiguousPage)

      assert_raise RuntimeError, ~r/Ambiguous match: found 2 labels matching: "Option"/, fn ->
        Mirage.choose(session, "Option")
      end
    end
  end

  describe "choose/2 — wrapped label" do
    test "finds a radio input wrapped inside its label (text first)" do
      session =
        Mirage.ChoosePage
        |> Mirage.visit()
        |> Mirage.choose("Yes")

      assert session.page.state.choice == "yes"
    end

    test "finds a radio input when the input comes before the label text" do
      session =
        Mirage.ChooseInputFirstPage
        |> Mirage.visit()
        |> Mirage.choose("foo")

      assert session.page.state.choice == "foo"
    end
  end

  describe "choose/2 — form dispatch" do
    test "also triggers the enclosing form's $change action" do
      session =
        Mirage.ChooseFormPage
        |> Mirage.visit()
        |> Mirage.choose("Yes")

      assert session.page.state.choice == "yes"
      assert session.page.state.change_log == ["yes"]
    end

    test "does not trigger a form $change when the radio is outside a form" do
      session =
        Mirage.ChoosePage
        |> Mirage.visit()
        |> Mirage.choose("Yes")

      assert session.page.state.choice == "yes"
    end
  end

  describe "check/2" do
    test "dispatches $change with the checkbox's value attribute" do
      session =
        Mirage.CheckPage
        |> Mirage.visit()
        |> Mirage.check("Newsletter")

      assert session.page.state.newsletter == true
    end

    test "multiple checkboxes can be checked independently" do
      session =
        Mirage.CheckPage
        |> Mirage.visit()
        |> Mirage.check("Newsletter")
        |> Mirage.check("Terms")

      assert session.page.state.newsletter == true
      assert session.page.state.terms == true
    end

    test "matches substrings when exact: false" do
      session =
        Mirage.CheckPage
        |> Mirage.visit()
        |> Mirage.check("News", exact: false)

      assert session.page.state.newsletter == true
    end

    test "raises when no label matches" do
      session = Mirage.visit(Mirage.CheckPage)

      assert_raise RuntimeError, ~r/No checkbox found with label: "Missing"/, fn ->
        Mirage.check(session, "Missing")
      end
    end

    test "raises when more than one label matches" do
      session = Mirage.visit(Mirage.CheckAmbiguousPage)

      assert_raise RuntimeError, ~r/Ambiguous match: found 2 labels matching: "Accept"/, fn ->
        Mirage.check(session, "Accept")
      end
    end
  end

  describe "check/2 — open_browser" do
    test "injects checked on the checked checkbox" do
      Mirage.CheckPage
      |> Mirage.visit()
      |> Mirage.check("Newsletter")
      |> Mirage.open_browser(fn path -> send(self(), {:opened, path}) end)

      assert_receive {:opened, path}
      html = File.read!(path)

      assert html =~ ~r/name="newsletter"[^>]* checked/
      refute html =~ ~r/name="terms"[^>]* checked/

      File.rm(path)
    end

    test "multiple checked checkboxes all show checked" do
      Mirage.CheckPage
      |> Mirage.visit()
      |> Mirage.check("Newsletter")
      |> Mirage.check("Terms")
      |> Mirage.open_browser(fn path -> send(self(), {:opened, path}) end)

      assert_receive {:opened, path}
      html = File.read!(path)

      assert html =~ ~r/name="newsletter"[^>]* checked/
      assert html =~ ~r/name="terms"[^>]* checked/

      File.rm(path)
    end
  end

  describe "uncheck/2" do
    test "removes the checkbox from checked_checkboxes" do
      session =
        Mirage.CheckPage
        |> Mirage.visit()
        |> Mirage.check("Newsletter")
        |> Mirage.uncheck("Newsletter")

      refute MapSet.member?(session.checked_checkboxes, {"newsletter", "yes"})
    end

    test "dispatches $change when unchecking" do
      session =
        Mirage.CheckPage
        |> Mirage.visit()
        |> Mirage.check("Newsletter")
        |> Mirage.uncheck("Newsletter")

      assert %Session{} = session
    end

    test "matches substrings when exact: false" do
      session =
        Mirage.CheckPage
        |> Mirage.visit()
        |> Mirage.check("Newsletter")
        |> Mirage.uncheck("News", exact: false)

      refute MapSet.member?(session.checked_checkboxes, {"newsletter", "yes"})
    end

    test "raises when no label matches" do
      session = Mirage.visit(Mirage.CheckPage)

      assert_raise RuntimeError, ~r/No checkbox found with label: "Missing"/, fn ->
        Mirage.uncheck(session, "Missing")
      end
    end

    test "open_browser does not show checked after uncheck" do
      Mirage.CheckPage
      |> Mirage.visit()
      |> Mirage.check("Newsletter")
      |> Mirage.uncheck("Newsletter")
      |> Mirage.open_browser(fn path -> send(self(), {:opened, path}) end)

      assert_receive {:opened, path}
      html = File.read!(path)

      refute html =~ ~r/name="newsletter"[^>]* checked/

      File.rm(path)
    end
  end

  describe "select/3" do
    test "dispatches $change with the option's value attribute" do
      session =
        Mirage.SelectPage
        |> Mirage.visit()
        |> Mirage.select("Color", "Red")

      assert session.page.state.color == "red"
    end

    test "selects among multiple options" do
      session =
        Mirage.SelectPage
        |> Mirage.visit()
        |> Mirage.select("Color", "Blue")

      assert session.page.state.color == "blue"
    end

    test "matches substrings when exact: false" do
      session =
        Mirage.SelectPage
        |> Mirage.visit()
        |> Mirage.select("Color", "Gr", exact: false)

      assert session.page.state.color == "green"
    end

    test "raises when no label matches" do
      session = Mirage.visit(Mirage.SelectPage)

      assert_raise RuntimeError, ~r/No select found with label: "Size"/, fn ->
        Mirage.select(session, "Size", "Large")
      end
    end

    test "raises when no option matches" do
      session = Mirage.visit(Mirage.SelectPage)

      assert_raise RuntimeError, ~r/No option found with text: "Purple"/, fn ->
        Mirage.select(session, "Color", "Purple")
      end
    end

    test "raises when more than one label matches" do
      session = Mirage.visit(Mirage.SelectAmbiguousPage)

      assert_raise RuntimeError, ~r/Ambiguous match: found 2 labels matching: "Color"/, fn ->
        Mirage.select(session, "Color", "Red")
      end
    end
  end

  describe "select/3 — form dispatch" do
    test "also triggers the enclosing form's $change action" do
      session =
        Mirage.SelectFormPage
        |> Mirage.visit()
        |> Mirage.select("Color", "Red")

      assert session.page.state.color == "red"
      assert session.page.state.change_log == ["red"]
    end
  end

  describe "select/3 — multiselect" do
    test "accumulates selections across multiple calls" do
      session =
        Mirage.SelectMultiplePage
        |> Mirage.visit()
        |> Mirage.select("Fruits", "Apple")
        |> Mirage.select("Fruits", "Cherry")

      assert session.page.state.selections == ["apple", "cherry"]
    end

    test "open_browser marks all selected options" do
      Mirage.SelectMultiplePage
      |> Mirage.visit()
      |> Mirage.select("Fruits", "Apple")
      |> Mirage.select("Fruits", "Cherry")
      |> Mirage.open_browser(fn path -> send(self(), {:opened, path}) end)

      assert_receive {:opened, path}
      html = File.read!(path)

      assert html =~ ~r/value="apple"[^>]* selected/
      refute html =~ ~r/value="banana"[^>]* selected/
      assert html =~ ~r/value="cherry"[^>]* selected/

      File.rm(path)
    end
  end

  describe "select/3 — open_browser" do
    test "marks the selected option" do
      Mirage.SelectPage
      |> Mirage.visit()
      |> Mirage.select("Color", "Green")
      |> Mirage.open_browser(fn path -> send(self(), {:opened, path}) end)

      assert_receive {:opened, path}
      html = File.read!(path)

      assert html =~ ~r/value="green"[^>]* selected/
      refute html =~ ~r/value="red"[^>]* selected/
      refute html =~ ~r/value="blue"[^>]* selected/

      File.rm(path)
    end
  end
end
