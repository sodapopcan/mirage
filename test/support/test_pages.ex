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

defmodule HoloTest.FillInPage do
  @moduledoc """
  Page fixture for `fill_in/3`. Has a form with two labelled inputs (one
  wrapping, one `for`-referenced) and a `$change` handler at the form
  level, plus a textarea *outside* the form whose `$change` fires without
  any form-level change.
  """
  use Hologram.Page

  route "/fill-in"
  layout HoloTest.TestLayout

  @impl Hologram.Page
  def init(_params, component, _server) do
    put_state(component,
      name: nil,
      email: nil,
      comment: nil,
      change_log: []
    )
  end

  def action(:update_name, %{value: value}, component) do
    put_state(component, name: value)
  end

  # Generic field-setter — proves that extra params declared on the
  # attribute (e.g. `field: :email`) are merged with the fill value.
  def action(:set_field, %{field: field, value: value}, component) do
    put_state(component, field, value)
  end

  def action(:update_comment, %{value: value}, component) do
    put_state(component, comment: value)
  end

  # Records a form-level change — used to assert `$change` fired.
  def action(:form_changed, %{value: value}, component) do
    put_state(component, change_log: component.state.change_log ++ [value])
  end

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <form $change={:form_changed}>
      <label>Name<input $change={:update_name} /></label>
      <label for="email">Email</label>
      <input id="email" $change={:set_field, field: :email} />
    </form>
    <label>Comment<textarea $change={:update_comment} /></label>
    """
  end
end

defmodule HoloTest.ClickPage do
  @moduledoc """
  Single clickable button with intentionally verbose text so the same page
  can drive exact-match, substring-match, and no-match scenarios.
  """
  use Hologram.Page

  route "/click"
  layout HoloTest.TestLayout

  def action(:save, _params, component), do: put_state(component, clicked: true)

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <button $click={:save}>Save changes now</button>
    """
  end
end

defmodule HoloTest.ClickWhitespacePage do
  @moduledoc """
  Uses an expression-bound string so leading/trailing whitespace around
  the button's text survives the template parser and exercises the trim
  in `text_matches?/3`.
  """
  use Hologram.Page

  route "/click-whitespace"
  layout HoloTest.TestLayout

  @impl Hologram.Page
  def init(_params, component, _server) do
    put_state(component, text: "  Save  ")
  end

  def action(:save, _params, component), do: component

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <button $click={:save}>{@text}</button>
    """
  end
end

defmodule HoloTest.ClickNestedTextPage do
  @moduledoc "Button text split across descendant elements."
  use Hologram.Page

  route "/click-nested-text"
  layout HoloTest.TestLayout

  def action(:submit, _params, component), do: component

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <button $click={:submit}><span>Click </span><span>me</span></button>
    """
  end
end

defmodule HoloTest.ClickDeepPage do
  @moduledoc "Clickable anchor nested several elements deep."
  use Hologram.Page

  route "/click-deep"
  layout HoloTest.TestLayout

  def action(:go, _params, component), do: component

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <div><section><a $click={:go}>Go</a></section></div>
    """
  end
end

defmodule HoloTest.ClickNoAttrPage do
  @moduledoc "Button without a `$click` attribute — nothing to click."
  use Hologram.Page

  route "/click-no-attr"
  layout HoloTest.TestLayout

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <button>Save</button>
    """
  end
end

defmodule HoloTest.ClickAmbiguousPage do
  @moduledoc "Two clickable elements sharing the same text."
  use Hologram.Page

  route "/click-ambiguous"
  layout HoloTest.TestLayout

  def action(:save, _params, component), do: component

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <button $click={:save}>Save</button>
    <a $click={:save}>Save</a>
    """
  end
end

defmodule HoloTest.ClickCommentPage do
  @moduledoc """
  The clickable button is inside an HTML comment — Hologram's parser
  treats everything between `<!--` and `-->` as text, so the button
  must not be reachable as a clickable.
  """
  use Hologram.Page

  route "/click-comment"
  layout HoloTest.TestLayout

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <!-- <button $click={:x}>Hidden</button> -->
    """
  end
end

defmodule HoloTest.FillInCommentPage do
  @moduledoc """
  Counterpart to `ClickCommentPage` for labels: a commented-out label
  must not be reachable via `fill_in/3`.
  """
  use Hologram.Page

  route "/fill-in-comment"
  layout HoloTest.TestLayout

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <!-- <label>Hidden<input $change={:x} /></label> -->
    """
  end
end

defmodule HoloTest.FillInLabelTextPage do
  @moduledoc """
  Single labelled input where the label text is longer than any single
  word — lets the same page cover exact-match, substring-match, and
  no-match variants of `fill_in/3`.
  """
  use Hologram.Page

  route "/fill-in-label-text"
  layout HoloTest.TestLayout

  def action(:update, _params, component), do: component

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <label>Email address<input $change={:update} /></label>
    """
  end
end

defmodule HoloTest.FillInWhitespaceLabelPage do
  @moduledoc """
  Expression-bound label text so surrounding whitespace survives parsing
  and exercises the trim in `text_matches?/3`.
  """
  use Hologram.Page

  route "/fill-in-whitespace-label"
  layout HoloTest.TestLayout

  @impl Hologram.Page
  def init(_params, component, _server) do
    put_state(component, text: "  Name  ")
  end

  def action(:update, _params, component), do: component

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <label>{@text}<input $change={:update} /></label>
    """
  end
end

defmodule HoloTest.FillInNestedLabelPage do
  @moduledoc "Label text split across descendant elements."
  use Hologram.Page

  route "/fill-in-nested-label"
  layout HoloTest.TestLayout

  def action(:update, _params, component), do: component

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <label><span>First </span><span>name</span><input $change={:update} /></label>
    """
  end
end

defmodule HoloTest.FillInDeepLabelPage do
  @moduledoc "Label nested several elements deep in the tree."
  use Hologram.Page

  route "/fill-in-deep-label"
  layout HoloTest.TestLayout

  def action(:update, _params, component), do: component

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <div><section><label>Email<input $change={:update} /></label></section></div>
    """
  end
end

defmodule HoloTest.FillInAmbiguousLabelPage do
  @moduledoc "Two labels with the same text."
  use Hologram.Page

  route "/fill-in-ambiguous-label"
  layout HoloTest.TestLayout

  def action(:update, _params, component), do: component

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <label>Name<input $change={:update} /></label>
    <label>Name<input $change={:update} /></label>
    """
  end
end

defmodule HoloTest.FillInOrphanLabelPage do
  @moduledoc "Label whose `for` attribute points at a non-existent input."
  use Hologram.Page

  route "/fill-in-orphan-label"
  layout HoloTest.TestLayout

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <label for="missing">Orphan</label>
    """
  end
end

defmodule HoloTest.AssertHasTextPage do
  @moduledoc false
  use Hologram.Page

  route "/assert-has-text"
  layout HoloTest.TestLayout

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <div>Item 1</div>
    <div>Item 2</div>
    <div>Item 3</div>
    """
  end
end

defmodule HoloTest.AssertHasValuePage do
  @moduledoc false
  use Hologram.Page

  route "/assert-has-value"
  layout HoloTest.TestLayout

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <input value="alice" />
    <input value="bob" />
    <input value="carol" />
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
