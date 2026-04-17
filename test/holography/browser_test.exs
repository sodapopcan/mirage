defmodule Holography.BrowserTest do
  use ExUnit.Case, async: true

  alias Holography.Session

  describe "open_browser/2" do
    test "writes an HTML file and returns the session" do
      session = Holography.visit(Holography.ClickPage)

      session = Holography.open_browser(session, fn path -> send(self(), {:opened, path}) end)

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
end
