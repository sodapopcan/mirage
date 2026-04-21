defmodule Mirage.BrowserTest do
  use ExUnit.Case, async: true

  alias Mirage.Session

  describe "open_browser/2 — radio checked state" do
    test "injects checked on the chosen radio when template has no checked binding" do
      Mirage.ChoosePage
      |> Mirage.visit()
      |> Mirage.choose("Yes")
      |> Mirage.open_browser(fn path -> send(self(), {:opened, path}) end)

      assert_receive {:opened, path}
      html = File.read!(path)

      assert html =~ ~r/value="yes"[^>]* checked/
      refute html =~ ~r/value="no"[^>]* checked/

      File.rm(path)
    end

    test "respects checked binding from template, does not double-add" do
      Mirage.ChooseCheckedPage
      |> Mirage.visit()
      |> Mirage.choose("Yes")
      |> Mirage.open_browser(fn path -> send(self(), {:opened, path}) end)

      assert_receive {:opened, path}
      html = File.read!(path)

      assert html =~ ~r/value="yes"[^>]* checked/
      refute html =~ ~r/value="no"[^>]* checked/

      File.rm(path)
    end
  end

  describe "open_browser/2" do
    test "writes an HTML file and returns the session" do
      session = Mirage.visit(Mirage.ClickPage)

      session = Mirage.open_browser(session, fn path -> send(self(), {:opened, path}) end)

      assert %Session{} = session
      assert_receive {:opened, path}
      assert File.exists?(path)

      html = File.read!(path)
      assert html =~ "<html>"
      assert html =~ "<body>"
      assert html =~ "Save changes now"

      File.rm(path)
    end
  end

  describe "open_browser/2 — mounted component" do
    test "wraps in a barebones HTML layout with centering CSS by default" do
      import Hologram.Template

      ~HOLO"""
      <Mirage.MountableCounter />
      """
      |> Mirage.mount()
      |> Mirage.open_browser(fn path -> send(self(), {:opened, path}) end)

      assert_receive {:opened, path}
      html = File.read!(path)

      assert html =~ "<!DOCTYPE html>"
      assert html =~ "<html>"
      assert html =~ "place-items: center"
      assert html =~ "0"

      File.rm(path)
    end

    test "center: false omits centering CSS" do
      import Hologram.Template

      ~HOLO"""
      <Mirage.MountableCounter />
      """
      |> Mirage.mount()
      |> Mirage.open_browser([center: false], fn path -> send(self(), {:opened, path}) end)

      assert_receive {:opened, path}
      html = File.read!(path)

      assert html =~ "<!DOCTYPE html>"
      refute html =~ "place-items: center"

      File.rm(path)
    end

    test "wrap: false skips the layout wrapper entirely" do
      import Hologram.Template

      ~HOLO"""
      <Mirage.MountableCounter />
      """
      |> Mirage.mount()
      |> Mirage.open_browser([wrap: false], fn path -> send(self(), {:opened, path}) end)

      assert_receive {:opened, path}
      html = File.read!(path)

      refute html =~ "<!DOCTYPE html>"
      refute html =~ "<html>"
      assert html =~ "0"

      File.rm(path)
    end
  end
end
