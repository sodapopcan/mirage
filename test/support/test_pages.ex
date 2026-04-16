defmodule HoloTest.TestLayout do
  @moduledoc false
  use Hologram.Component

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <slot />
    """
  end
end

defmodule HoloTest.AnotherPage do
  @moduledoc false
  use Hologram.Page

  route "/another"
  layout HoloTest.TestLayout

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <div>I am the other page.</div>
    """
  end
end

defmodule HoloTest.HomePage do
  @moduledoc false
  use Hologram.Page

  route "/"
  layout HoloTest.TestLayout

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <Hologram.UI.Link to={HoloTest.AnotherPage}>link to other page</Hologram.UI.Link>
    """
  end
end

defmodule HoloTest.LinkWrapper do
  @moduledoc """
  Thin custom component that wraps `Hologram.UI.Link`, forwarding its `to`
  prop and slot content. Used to verify that links still work when nested
  inside user-defined components.
  """
  use Hologram.Component

  prop :to, [:module, :string, :tuple]

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <Hologram.UI.Link to={@to}><slot /></Hologram.UI.Link>
    """
  end
end

defmodule HoloTest.WrappedLinkPage do
  @moduledoc false
  use Hologram.Page

  route "/wrapped"
  layout HoloTest.TestLayout

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <HoloTest.LinkWrapper to={HoloTest.AnotherPage}>wrapped link to other page</HoloTest.LinkWrapper>
    """
  end
end

defmodule HoloTest.CommandPage do
  @moduledoc false
  use Hologram.Page

  route "/command"
  layout HoloTest.TestLayout

  @doc """
  Action handler: emits a `:write_file` command that performs the side effect
  server-side. Invoked when the user clicks the button in the template.
  """
  def action(:write_file, %{path: path}, component) do
    put_command(component, :write_file, path: path)
  end

  @doc """
  Command handler: writes a fixed payload to the given path. Runs server-side.
  """
  def command(:write_file, %{path: path}, server) do
    File.write!(path, "written by command")
    server
  end

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <button $click={:write_file, path: @tmp_path}>write file</button>
    """
  end
end
