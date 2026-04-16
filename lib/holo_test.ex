defmodule HoloTest do
  @moduledoc """
  Test framework for the Hologram web framework.

  The entry point is `visit/2`, which initializes a page and expands its
  template into a fully-resolved DOM that tests can make assertions against.
  """

  alias Hologram.Server
  alias HoloTest.DOM
  alias HoloTest.Session

  @doc """
  Visits a Hologram page module and returns a `HoloTest.Session` containing
  the initialized page struct and the expanded, layout-wrapped DOM.
  """
  @spec visit(module, %{atom => any}) :: Session.t()
  def visit(page_module, params \\ %{}) do
    {page_struct, server} = DOM.init_component(page_module, params, %Server{})

    vars = Map.merge(params, page_struct.state)
    page_dom = page_module.template().(vars)

    layout_props_dom =
      page_module.__layout_props__()
      |> Enum.into(%{cid: "layout"})
      |> Map.merge(page_struct.state)
      |> Enum.map(fn {name, value} -> {to_string(name), [expression: {value}]} end)

    root = {:component, page_module.__layout_module__(), layout_props_dom, page_dom}
    env = %{context: page_struct.emitted_context, slots: []}
    ast = DOM.expand(root, env, server)

    %Session{page: page_struct, ast: ast}
  end
end
