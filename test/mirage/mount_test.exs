defmodule Mirage.MountTest do
  use ExUnit.Case, async: true

  import Hologram.Template

  alias Mirage.Session

  describe "mount" do
    test "mounts a component and renders its template" do
      session =
        ~HOLO"""
        <Mirage.KillCounter cid="test" />
        """
        |> Mirage.mount()

      assert %Session{} = session
      assert session.page.state.kills == 0
      assert rendered_text(session.ast) =~ "0"
    end

    test "actions work on a mounted component" do
      session =
        ~HOLO"""
        <Mirage.KillCounter cid="test" />
        """
        |> Mirage.mount()
        |> Mirage.click("button", "Kill")

      assert session.page.state.kills == 1
      assert rendered_text(session.ast) =~ "1"
    end

    test "state persists across interactions" do
      session =
        ~HOLO"""
        <Mirage.KillCounter cid="test" />
        """
        |> Mirage.mount()
        |> Mirage.click("button", "Kill")
        |> Mirage.click("button", "Kill")
        |> Mirage.click("button", "Kill")

      assert session.page.state.kills == 3
    end

    test "mounts with default props when none given" do
      session =
        ~HOLO"""
        <Mirage.MountableCounter />
        """
        |> Mirage.mount()

      assert session.page.state.count == 0
    end

    test "populates from_context props via context tuple" do
      session =
        ~HOLO"""
        <Mirage.ContextCounter />
        """
        |> Mirage.mount({Mirage.ContextCounter, initial_count: 10})

      assert session.page.state.count == 10
    end

    test "populates multiple context values from same namespace" do
      session =
        ~HOLO"""
        <Mirage.ContextCounter />
        """
        |> Mirage.mount({Mirage.ContextCounter, initial_count: 42, label: "Kills"})

      assert session.page.state.count == 42
      assert session.page.state.label == "Kills"
    end

    test "renders slot content" do
      session =
        ~HOLO"""
        <Mirage.SlottedWrapper>
          <p>Slotted content</p>
        </Mirage.SlottedWrapper>
        """
        |> Mirage.mount()

      Mirage.assert_has(session, "div.wrapper")
      Mirage.assert_has(session, "h2", "Wrapper")
      Mirage.assert_has(session, "p", "Slotted content")
    end

    test "renders empty slot when none given" do
      session =
        ~HOLO"""
        <Mirage.SlottedWrapper />
        """
        |> Mirage.mount()

      Mirage.assert_has(session, "h2", "Wrapper")
      Mirage.refute_has(session, "p")
    end

    test "slot event targets the mounted component" do
      session =
        ~HOLO"""
        <Mirage.SlotDialog cid="dialog">
          <button $click={:close}>Close</button>
        </Mirage.SlotDialog>
        """
        |> Mirage.mount()
        |> Mirage.click("button", "Close")

      assert session.page.state.closed == true
    end

    test "slot can reference context-derived vars" do
      session =
        ~HOLO"""
        <Mirage.SlottedCard>
          <p>Card body for {@title}</p>
        </Mirage.SlottedCard>
        """
        |> Mirage.mount({Mirage.SlottedCard, title: "My Card"})

      Mirage.assert_has(session, "h3", "My Card")
      Mirage.assert_has(session, "p", "Card body for My Card")
    end
  end

  defp rendered_text(nodes) when is_list(nodes) do
    Enum.map_join(nodes, "", &rendered_text/1)
  end

  defp rendered_text({:text, text}), do: text
  defp rendered_text({:element, _tag, _attrs, children}), do: rendered_text(children)
  defp rendered_text({:public_comment, children}), do: rendered_text(children)
  defp rendered_text(_other), do: ""
end
