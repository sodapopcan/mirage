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
  end

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
      session =
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
      session =
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
end
