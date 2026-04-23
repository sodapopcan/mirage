defmodule Mirage.ComponentTest do
  use ExUnit.Case, async: true
  use Mirage.Component

  describe "use Mirage.Component" do
    test "~HOLO sigil is available without explicit import" do
      session =
        ~HOLO"""
        <Mirage.KillCounter cid="test" />
        """
        |> mount()

      assert_has(session, "span.kills", "0")
    end

    test "Mirage functions are available without explicit import" do
      ~HOLO"""
      <Mirage.KillCounter cid="test" />
      """
      |> mount()
      |> click("button", "Kill")
      |> assert_has("span.kills", "1")
    end

    test "mount and interact with a stateful component" do
      session =
        ~HOLO"""
        <Mirage.KillCounter cid="test" />
        """
        |> mount()
        |> click("button", "Kill")
        |> click("button", "Kill")

      assert session.page.state.kills == 2
      assert_has(session, "span.kills", "2")
    end

    test "mount with context" do
      ~HOLO"""
      <Mirage.ContextCounter />
      """
      |> mount({Mirage.ContextCounter, initial_count: 5})
      |> assert_has("span.count", "5")
    end

    test "mount with slot content" do
      ~HOLO"""
      <Mirage.SlottedWrapper>
        <p>Hello from slot</p>
      </Mirage.SlottedWrapper>
      """
      |> mount()
      |> assert_has("p", "Hello from slot")
    end

    test "refute_has works" do
      ~HOLO"""
      <Mirage.KillCounter cid="test" />
      """
      |> mount()
      |> refute_has("span.kills", "1")
    end

    test "within scopes assertions" do
      ~HOLO"""
      <Mirage.KillCounter cid="test" />
      """
      |> mount()
      |> within("#test", fn session ->
        assert_has(session, "button", "Kill")
      end)
    end
  end
end
