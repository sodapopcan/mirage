defmodule Mirage.TestLayout do
  @moduledoc false
  use Hologram.Component

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <html>
    <head></head>
    <body><slot /></body>
    </html>
    """
  end
end

defmodule Mirage.AnotherPage do
  @moduledoc false
  use Hologram.Page

  route "/another"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <div>I am the other page.</div>
    """
  end
end

defmodule Mirage.HomePage do
  @moduledoc false
  use Hologram.Page

  route "/"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <Hologram.UI.Link to={Mirage.AnotherPage}>link to other page</Hologram.UI.Link>
    <a href="#" $click={:link}>I link to the same page</a>
    <button type="button" $click={:link}>I button to the same page</button>
    """
  end

  def action(:link, _params, component) do
    put_page(component, Mirage.AnotherPage)
  end
end

defmodule Mirage.LinkWrapper do
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

defmodule Mirage.WrappedLinkPage do
  @moduledoc false
  use Hologram.Page

  route "/wrapped"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <Mirage.LinkWrapper to={Mirage.AnotherPage}>wrapped link to other page</Mirage.LinkWrapper>
    """
  end
end

defmodule Mirage.FillInPage do
  @moduledoc """
  Page fixture for `fill_in/3`. Has a form with two labelled inputs (one
  wrapping, one `for`-referenced) and a `$change` handler at the form
  level, plus a textarea *outside* the form whose `$change` fires without
  any form-level change.
  """
  use Hologram.Page

  route "/fill-in"
  layout Mirage.TestLayout

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

defmodule Mirage.ClickPage do
  @moduledoc """
  Single clickable button with intentionally verbose text so the same page
  can drive exact-match, substring-match, and no-match scenarios.
  """
  use Hologram.Page

  route "/click"
  layout Mirage.TestLayout

  def action(:save, _params, component), do: put_state(component, clicked: true)

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <button $click={:save}>Save changes now</button>
    """
  end
end

defmodule Mirage.ClickWhitespacePage do
  @moduledoc """
  Uses an expression-bound string so leading/trailing whitespace around
  the button's text survives the template parser and exercises the trim
  in `text_matches?/3`.
  """
  use Hologram.Page

  route "/click-whitespace"
  layout Mirage.TestLayout

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

defmodule Mirage.ClickNestedTextPage do
  @moduledoc "Button text split across descendant elements."
  use Hologram.Page

  route "/click-nested-text"
  layout Mirage.TestLayout

  def action(:submit, _params, component), do: component

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <button $click={:submit}><span>Click </span><span>me</span></button>
    """
  end
end

defmodule Mirage.ClickDeepPage do
  @moduledoc "Clickable anchor nested several elements deep."
  use Hologram.Page

  route "/click-deep"
  layout Mirage.TestLayout

  def action(:go, _params, component), do: component

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <div><section><a $click={:go}>Go</a></section></div>
    """
  end
end

defmodule Mirage.ClickNoAttrPage do
  @moduledoc "Button without a `$click` attribute — nothing to click."
  use Hologram.Page

  route "/click-no-attr"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <button>Save</button>
    """
  end
end

defmodule Mirage.ClickAmbiguousPage do
  @moduledoc "Two clickable elements sharing the same text."
  use Hologram.Page

  route "/click-ambiguous"
  layout Mirage.TestLayout

  def action(:save, _params, component), do: component

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <button $click={:save}>Save</button>
    <a $click={:save}>Save</a>
    """
  end
end

defmodule Mirage.ClickCommentPage do
  @moduledoc """
  The clickable button is inside an HTML comment — Hologram's parser
  treats everything between `<!--` and `-->` as text, so the button
  must not be reachable as a clickable.
  """
  use Hologram.Page

  route "/click-comment"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <!-- <button $click={:x}>Hidden</button> -->
    """
  end
end

defmodule Mirage.FillInCommentPage do
  @moduledoc """
  Counterpart to `ClickCommentPage` for labels: a commented-out label
  must not be reachable via `fill_in/3`.
  """
  use Hologram.Page

  route "/fill-in-comment"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <!-- <label>Hidden<input $change={:x} /></label> -->
    """
  end
end

defmodule Mirage.ClickCommandPage do
  use Hologram.Page

  route "/command-page"
  layout Mirage.TestLayout

  def template do
    ~HOLO"""
    <button $click={command: :no_params}>No params</button>
    """
  end

  def command(:no_params, _params, server) do
    IO.puts("No params!")
    server
  end
end

defmodule Mirage.FillInLabelTextPage do
  @moduledoc """
  Single labelled input where the label text is longer than any single
  word — lets the same page cover exact-match, substring-match, and
  no-match variants of `fill_in/3`.
  """
  use Hologram.Page

  route "/fill-in-label-text"
  layout Mirage.TestLayout

  def action(:update, _params, component), do: component

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <label>Email address<input $change={:update} /></label>
    """
  end
end

defmodule Mirage.FillInWhitespaceLabelPage do
  @moduledoc """
  Expression-bound label text so surrounding whitespace survives parsing
  and exercises the trim in `text_matches?/3`.
  """
  use Hologram.Page

  route "/fill-in-whitespace-label"
  layout Mirage.TestLayout

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

defmodule Mirage.FillInNestedLabelPage do
  @moduledoc "Label text split across descendant elements."
  use Hologram.Page

  route "/fill-in-nested-label"
  layout Mirage.TestLayout

  def action(:update, _params, component), do: component

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <label><span>First </span><span>name</span><input $change={:update} /></label>
    """
  end
end

defmodule Mirage.FillInDeepLabelPage do
  @moduledoc "Label nested several elements deep in the tree."
  use Hologram.Page

  route "/fill-in-deep-label"
  layout Mirage.TestLayout

  def action(:update, _params, component), do: component

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <div><section><label>Email<input $change={:update} /></label></section></div>
    """
  end
end

defmodule Mirage.FillInAmbiguousLabelPage do
  @moduledoc "Two labels with the same text."
  use Hologram.Page

  route "/fill-in-ambiguous-label"
  layout Mirage.TestLayout

  def action(:update, _params, component), do: component

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <label>Name<input $change={:update} /></label>
    <label>Name<input $change={:update} /></label>
    """
  end
end

defmodule Mirage.FillInOrphanLabelPage do
  @moduledoc "Label whose `for` attribute points at a non-existent input."
  use Hologram.Page

  route "/fill-in-orphan-label"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <label for="missing">Orphan</label>
    """
  end
end

defmodule Mirage.AssertHasTextPage do
  @moduledoc false
  use Hologram.Page

  route "/assert-has-text"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <h1>I'm a header</h1>

    <ul>
      <li><span>Item</span> 1</li>
      <li><span>Item</span> 2</li>
      <li><span>Item</span> 3</li>
    </ul>
    """
  end
end

defmodule Mirage.AssertHasValuePage do
  @moduledoc false
  use Hologram.Page

  route "/assert-has-value"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <input value="alice" />
    <input value="bob" />
    <input value="carol" />
    """
  end
end

defmodule Mirage.CommandPage do
  @moduledoc false
  use Hologram.Page

  route "/command"
  layout Mirage.TestLayout

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

defmodule Mirage.LonghandActionPage do
  @moduledoc false
  use Hologram.Page

  route "/longhand-action"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def init(_params, component, _server) do
    put_state(component, count: 0)
  end

  def action(:increment, _params, component) do
    put_state(component, :count, component.state.count + 1)
  end

  def action(:add, %{amount: amount}, component) do
    put_state(component, :count, component.state.count + amount)
  end

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <button $click={action: :increment}>longhand increment</button>
    <button $click={action: :add, params: %{amount: 10}}>longhand add 10</button>
    <span id="count">{@count}</span>
    """
  end
end

defmodule Mirage.DirectCommandPage do
  @moduledoc false
  use Hologram.Page

  route "/direct-command"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def init(_params, component, _server) do
    put_state(component, status: "idle")
  end

  def action(:set_status, %{status: status}, component) do
    put_state(component, :status, status)
  end

  def command(:do_work, _params, server) do
    put_action(server, :set_status, status: "done")
  end

  def command(:do_work_with_params, %{label: label}, server) do
    put_action(server, :set_status, status: label)
  end

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <button $click={command: :do_work}>run command</button>
    <button $click={command: :do_work_with_params, params: %{label: "finished"}}>run param command</button>
    <span id="status">{@status}</span>
    """
  end
end

defmodule Mirage.ActionChainPage do
  @moduledoc false
  use Hologram.Page

  route "/action-chain"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def init(_params, component, _server) do
    put_state(component, log: [])
  end

  def action(:first, _params, component) do
    component
    |> put_state(:log, component.state.log ++ ["first"])
    |> put_action(:second)
  end

  def action(:second, _params, component) do
    put_state(component, :log, component.state.log ++ ["second"])
  end

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <button $click={:first}>chain</button>
    <span id="log">{Enum.join(@log, ",")}</span>
    """
  end
end

defmodule Mirage.PutPagePage do
  @moduledoc false
  use Hologram.Page

  route "/put-page"
  layout Mirage.TestLayout

  def action(:navigate, _params, component) do
    put_page(component, Mirage.AnotherPage)
  end

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <button $click={:navigate}>go to other page</button>
    """
  end
end

# ---------------------------------------------------------------------------
# within/3 test pages
# ---------------------------------------------------------------------------

defmodule Mirage.WithinPage do
  @moduledoc """
  Page with duplicate elements inside different containers, used to test
  `within/3` scoping.  Both the div and span contain an `a.nav` link with
  different text, so tests can verify that `within` narrows correctly.
  """
  use Hologram.Page

  route "/within"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def init(_params, component, _server) do
    put_state(component, clicked: nil)
  end

  def action(:div_link, _params, component), do: put_state(component, clicked: :div)
  def action(:span_link, _params, component), do: put_state(component, clicked: :span)

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <div class="sidebar">
      <a class="nav" $click={:div_link}>Sidebar link</a>
      <label>Sidebar input<input $change={:div_link} /></label>
    </div>
    <span class="main">
      <a class="nav" $click={:span_link}>Main link</a>
    </span>
    """
  end
end

defmodule Mirage.WithinArticlePage do
  @moduledoc """
  Page with two articles and two sections, each identified by a heading.
  Used by within_article/3 and within_section/3 tests.
  """
  use Hologram.Page

  route "/within-article"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def init(_params, component, _server) do
    put_state(component, clicked: nil)
  end

  def action(:first, _params, component), do: put_state(component, clicked: :first)
  def action(:second, _params, component), do: put_state(component, clicked: :second)

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <article>
      <h2>Blog Post</h2>
      <p>Blog content</p>
      <button $click={:first}>Like</button>
    </article>
    <article>
      <h2>News</h2>
      <p>News content</p>
      <button $click={:second}>Like</button>
    </article>
    <section>
      <h3>Settings</h3>
      <label>Email<input $change={:first} /></label>
    </section>
    <section>
      <h3>Profile</h3>
      <p>Profile info</p>
    </section>
    """
  end
end

defmodule Mirage.WithinNestedHeaderPage do
  @moduledoc """
  Page where the heading is nested inside another element within the
  article, to test depth-first header discovery.
  """
  use Hologram.Page

  route "/within-nested-header"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <article>
      <header><h1>Deep Title</h1></header>
      <p>Some content</p>
    </article>
    """
  end
end

# ---------------------------------------------------------------------------
# Shared event test pages (used for click, focus, blur)
# ---------------------------------------------------------------------------

defmodule Mirage.EventPage do
  @moduledoc """
  A page with buttons carrying all three event attributes.
  Used by the shared event tests.
  """
  use Hologram.Page

  route "/event"
  layout Mirage.TestLayout

  def action(:save, _params, component), do: put_state(component, triggered: true)

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <button $click={:save}>Save changes now</button>
    <button $focus={:save}>Save changes now</button>
    <button $blur={:save}>Save changes now</button>
    """
  end
end

defmodule Mirage.EventDeepPage do
  @moduledoc "Event target nested several elements deep."
  use Hologram.Page

  route "/event-deep"
  layout Mirage.TestLayout

  def action(:go, _params, component), do: component

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <div><section><a $click={:go}>Go</a></section></div>
    <div><section><a $focus={:go}>Go</a></section></div>
    <div><section><a $blur={:go}>Go</a></section></div>
    """
  end
end

defmodule Mirage.EventNoAttrPage do
  @moduledoc "Button without any event attribute."
  use Hologram.Page

  route "/event-no-attr"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <button>Save</button>
    """
  end
end

defmodule Mirage.EventAmbiguousPage do
  @moduledoc "Two elements with the same event and text."
  use Hologram.Page

  route "/event-ambiguous"
  layout Mirage.TestLayout

  def action(:save, _params, component), do: component

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <button $click={:save}>Save</button>
    <a $click={:save}>Save</a>
    <button $focus={:save}>Save</button>
    <a $focus={:save}>Save</a>
    <button $blur={:save}>Save</button>
    <a $blur={:save}>Save</a>
    """
  end
end

defmodule Mirage.EventCommentPage do
  @moduledoc "Event targets inside an HTML comment."
  use Hologram.Page

  route "/event-comment"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <!-- <button $click={:x}>Hidden</button> -->
    <!-- <button $focus={:x}>Hidden</button> -->
    <!-- <button $blur={:x}>Hidden</button> -->
    """
  end
end

# ---------------------------------------------------------------------------
# choose/2 test pages
# ---------------------------------------------------------------------------

defmodule Mirage.ChoosePage do
  @moduledoc "Page with two radio options under distinct labels."
  use Hologram.Page

  route "/choose"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def init(_params, component, _server) do
    put_state(component, choice: nil)
  end

  def action(:pick, %{value: value}, component) do
    put_state(component, choice: value)
  end

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <label>Yes<input type="radio" value="yes" $change={:pick} /></label>
    <label>No<input type="radio" value="no" $change={:pick} /></label>
    """
  end
end

defmodule Mirage.ChooseCheckedPage do
  @moduledoc "Radio buttons with checked bound to state, to test open_browser output."
  use Hologram.Page

  route "/choose-checked"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def init(_params, component, _server) do
    put_state(component, choice: nil)
  end

  def action(:pick, %{value: value}, component) do
    put_state(component, choice: value)
  end

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <label>Yes<input type="radio" value="yes" checked={@choice == "yes"} $change={:pick} /></label>
    <label>No<input type="radio" value="no" checked={@choice == "no"} $change={:pick} /></label>
    """
  end
end

defmodule Mirage.ChooseAmbiguousPage do
  @moduledoc "Two radio buttons sharing the same label text."
  use Hologram.Page

  route "/choose-ambiguous"
  layout Mirage.TestLayout

  def action(:pick, _params, component), do: component

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <label>Option<input type="radio" value="a" $change={:pick} /></label>
    <label>Option<input type="radio" value="b" $change={:pick} /></label>
    """
  end
end

defmodule Mirage.ChooseInputFirstPage do
  @moduledoc "Input comes before label text, like <label><input /> foo</label>."
  use Hologram.Page

  route "/choose-input-first"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def init(_params, component, _server) do
    put_state(component, choice: nil)
  end

  def action(:pick, %{value: value}, component) do
    put_state(component, choice: value)
  end

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <label>
      <input type="radio" value="foo" $change={:pick} /> foo
    </label>
    <label>
      <input type="radio" value="bar" $change={:pick} /> bar
    </label>
    """
  end
end

defmodule Mirage.ChooseFormPage do
  @moduledoc "Radio buttons inside a form with a $change handler."
  use Hologram.Page

  route "/choose-form"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def init(_params, component, _server) do
    put_state(component, choice: nil, change_log: [])
  end

  def action(:pick, %{value: value}, component) do
    put_state(component, choice: value)
  end

  def action(:form_changed, %{value: value}, component) do
    put_state(component, change_log: component.state.change_log ++ [value])
  end

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <form $change={:form_changed}>
      <label>Yes<input type="radio" value="yes" $change={:pick} /></label>
      <label>No<input type="radio" value="no" $change={:pick} /></label>
    </form>
    """
  end
end

# ---------------------------------------------------------------------------
# check/2 test pages
# ---------------------------------------------------------------------------

defmodule Mirage.CheckPage do
  @moduledoc "Page with two independent checkboxes under distinct labels."
  use Hologram.Page

  route "/check"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def init(_params, component, _server) do
    put_state(component, newsletter: false, terms: false)
  end

  def action(:toggle_newsletter, %{value: _value}, component) do
    put_state(component, newsletter: true)
  end

  def action(:toggle_terms, %{value: _value}, component) do
    put_state(component, terms: true)
  end

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <label>Newsletter<input type="checkbox" name="newsletter" value="yes" $change={:toggle_newsletter} /></label>
    <label>Terms<input type="checkbox" name="terms" value="yes" $change={:toggle_terms} /></label>
    """
  end
end

defmodule Mirage.CheckAmbiguousPage do
  @moduledoc "Two checkboxes sharing the same label text."
  use Hologram.Page

  route "/check-ambiguous"
  layout Mirage.TestLayout

  def action(:toggle, _params, component), do: component

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <label>Accept<input type="checkbox" name="a" value="yes" $change={:toggle} /></label>
    <label>Accept<input type="checkbox" name="b" value="yes" $change={:toggle} /></label>
    """
  end
end

# ---------------------------------------------------------------------------
# select/2 test pages
# ---------------------------------------------------------------------------

defmodule Mirage.FormSubmitPage do
  @moduledoc "Form with $submit on the form element and a plain button with no $click."
  use Hologram.Page

  route "/form-submit"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def init(_params, component, _server) do
    put_state(component, submitted: false)
  end

  def action(:submit, _params, component) do
    put_state(component, submitted: true)
  end

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <form $submit={:submit}>
      <button>Submit</button>
    </form>
    """
  end
end

defmodule Mirage.FormSubmitInputPage do
  @moduledoc "Form with $submit and an input[type=submit] with no $click."
  use Hologram.Page

  route "/form-submit-input"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def init(_params, component, _server) do
    put_state(component, submitted: false)
  end

  def action(:submit, _params, component) do
    put_state(component, submitted: true)
  end

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <form $submit={:submit}>
      <input type="submit" value="Go" />
    </form>
    """
  end
end

defmodule Mirage.SelectPage do
  @moduledoc "Page with a labelled select box and distinct options."
  use Hologram.Page

  route "/select"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def init(_params, component, _server) do
    put_state(component, color: nil)
  end

  def action(:pick_color, %{value: value}, component) do
    put_state(component, color: value)
  end

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <label>Color<select name="color" $change={:pick_color}>
      <option value="red">Red</option>
      <option value="green">Green</option>
      <option value="blue">Blue</option>
    </select></label>
    """
  end
end

defmodule Mirage.SelectMultiplePage do
  @moduledoc "Page with a labelled multiselect box."
  use Hologram.Page

  route "/select-multiple"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def init(_params, component, _server) do
    put_state(component, selections: [])
  end

  def action(:pick, %{value: value}, component) do
    put_state(component, selections: component.state.selections ++ [value])
  end

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <label>Fruits<select name="fruits" multiple $change={:pick}>
      <option value="apple">Apple</option>
      <option value="banana">Banana</option>
      <option value="cherry">Cherry</option>
    </select></label>
    """
  end
end

defmodule Mirage.SelectAmbiguousPage do
  @moduledoc "Two select boxes sharing the same label text."
  use Hologram.Page

  route "/select-ambiguous"
  layout Mirage.TestLayout

  def action(:pick, _params, component), do: component

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <label>Color<select name="a" $change={:pick}>
      <option value="1">Red</option>
    </select></label>
    <label>Color<select name="b" $change={:pick}>
      <option value="2">Blue</option>
    </select></label>
    """
  end
end

defmodule Mirage.SelectFormPage do
  @moduledoc "Select box inside a form with a $change handler."
  use Hologram.Page

  route "/select-form"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def init(_params, component, _server) do
    put_state(component, color: nil, change_log: [])
  end

  def action(:pick_color, %{value: value}, component) do
    put_state(component, color: value)
  end

  def action(:form_changed, %{value: value}, component) do
    put_state(component, change_log: component.state.change_log ++ [value])
  end

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <form $change={:form_changed}>
      <label>Color<select name="color" $change={:pick_color}>
        <option value="red">Red</option>
        <option value="green">Green</option>
      </select></label>
    </form>
    """
  end
end

defmodule Mirage.SelectTextPage do
  @moduledoc false
  use Hologram.Page

  route "/select-text"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def init(_params, component, server) do
    {put_state(component, selected: nil), server}
  end

  def action(:text_selected, %{text: text}, component) do
    put_state(component, selected: text)
  end

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <label>Bio<textarea $select={:text_selected}>Hello world</textarea></label>
    <label>Username<input type="text" value="alice" $select={:text_selected} /></label>
    <label>Secret<input type="password" $select={:text_selected} /></label>
    <label>Agree<input type="checkbox" value="yes" $change={:noop} /></label>
    <label>Pick<input type="radio" value="a" $change={:noop} /></label>
    <label>Fruit<select $change={:noop}><option>Apple</option></select></label>
    """
  end
end

defmodule Mirage.WithinFieldsetPage do
  @moduledoc false
  use Hologram.Page

  route "/within-fieldset"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def init(_params, component, _server) do
    put_state(component, clicked: nil)
  end

  def action(:first, _params, component), do: put_state(component, clicked: :first)
  def action(:second, _params, component), do: put_state(component, clicked: :second)

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <fieldset>
      <legend>Account</legend>
      <label>Username<input $change={:first} /></label>
      <button $click={:first}>Save</button>
    </fieldset>
    <fieldset>
      <legend>Billing</legend>
      <p>Billing info</p>
      <button $click={:second}>Pay</button>
    </fieldset>
    """
  end
end

defmodule Mirage.IfBlockPage do
  @moduledoc false
  use Hologram.Page

  route "/if-block"
  layout Mirage.TestLayout

  @impl Hologram.Page
  def init(_params, component, _server) do
    put_state(component, show: false, clicked: nil)
  end

  def action(:show, _params, component), do: put_state(component, show: true)
  def action(:hidden, _params, component), do: put_state(component, clicked: :hidden)
  def action(:visible, _params, component), do: put_state(component, clicked: :visible)

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <button $click={:show}>Show</button>
    {%if @show}
      <p>Visible content</p>
      <button $click={:hidden}>Hidden button</button>
      <label>Hidden input<input $change={:hidden} /></label>
    {/if}
    <p>Always here</p>
    <button $click={:visible}>Always clickable</button>
    """
  end
end
