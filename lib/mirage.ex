defmodule Mirage do
  @moduledoc """
  Browserless test framework for the Hologram web framework.

  Mirage initializes a page or component and expands its template into
  a fully-resolved DOM that tests can make assertions and trigger events
  against.

  """

  defmodule Session do
    @moduledoc """
    State container for a test.
    """

    defstruct [
      :page,
      :server,
      :ast,
      :page_module,
      :params,
      :scope,
      bookkeeping: %{
        checked_radios: %{},
        checked_checkboxes: MapSet.new(),
        selected_options: %{},
        filled_inputs: %{},
        components: %{}
      }
    ]

    @typep bookkeeping :: %{
             checked_radios: map(),
             checked_checkboxes: map(),
             selected_options: map(),
             filled_inputs: map(),
             components: map()
           }

    @type t :: %__MODULE__{
            page: any(),
            server: any(),
            ast: any(),
            page_module: module(),
            params: map(),
            scope: tuple() | nil,
            bookkeeping: bookkeeping()
          }
  end

  alias Mirage.DOM
  alias Mirage.Events
  alias Mirage.Input
  alias Mirage.Scoped
  alias Mirage.Session

  defmacro sigil_HOLO(term, modifiers) do
    quote do
      require Hologram.Template
      Hologram.Template.sigil_HOLO(unquote(term), unquote(modifiers))
    end
  end

  @doc """
  Entry point to create a session.

  Takes a `Hologram.Page` and, optional, any params.  It returns a session which
  the rest of `Mirage` can use.

  """
  @spec visit(module(), keyword()) :: Session.t()
  def visit(page_module, params \\ []) do
    params = Map.new(params)
    {page, server} = DOM.init_component(page_module, params, %Hologram.Server{})

    vars = Map.merge(params, page.state)
    page_dom = page_module.template().(vars)

    layout_props_dom =
      page_module.__layout_props__()
      |> Enum.into(%{cid: "layout"})
      |> Map.merge(page.state)
      |> Enum.map(fn {name, value} -> {to_string(name), [expression: {value}]} end)

    root = {:component, page_module.__layout_module__(), layout_props_dom, page_dom}
    context = Map.merge(runtime_context(), page.emitted_context)
    env = %{context: context, slots: []}

    Process.delete(:mirage_components)
    ast = DOM.expand(root, env, server)
    components = Process.delete(:mirage_components) || %{}

    %Session{
      page: page,
      server: server,
      ast: ast,
      page_module: page_module,
      params: params,
      bookkeeping: %{
        checked_radios: %{},
        checked_checkboxes: MapSet.new(),
        selected_options: %{},
        filled_inputs: %{},
        components: components
      }
    }
  end

  @doc """
  Mount a component in isolation.

  Pass a `~HOLO` template containing a single component.  Props, cid, and slot
  content are all declared in the markup itself:

      ~HOLO\"\"\"
      <MyApp.Components.PoplarTracker cid="counter" eaten={0} />
      \"\"\"
      |> mount()
      |> click("button", "Eat a poplar")
      |> assert_has("p", "Number of poplars eaten: 1")

  Context can be provided as a `{Namespace, key: value}` tuple.  Props declared
  with `from_context` will be populated from matching context values.

      ~HOLO\"\"\"
      <MyApp.Components.PoplarTracker cid="counter">
        <p>{@user.name} eats too many poplars</p>
      </MyApp.Components.PoplarTracker>
      \"\"\"
      |> mount({MyApp, user: current_user, theme: "dark"})

  For multiple namespaces, use a list of tuples:

      ~HOLO\"\"\"
      <MyApp.Dashboard cid="dash" />
      \"\"\"
      |> mount([{MyApp, user: current_user}, {Themes, mode: "dark"}])

  """
  @spec mount(function(), {module(), keyword()} | [{module(), keyword()}]) :: Session.t()
  defdelegate mount(template_fn, context \\ []), to: Mirage.Mount

  @doc """
  Scopes all operations within the given block to descendants of the element
  matching `selector`.

      session
      |> within(".sidebar", fn session ->
        session
        |> assert_has("a", "Home")
        |> click_link("Home")
      end)

  """
  @spec within(Session.t(), String.t(), (Session.t() -> Session.t())) :: Session.t()
  defdelegate within(session, selector, fun), to: Scoped

  @doc """
  Scopes to the `<article>` whose first heading (`h1` - `h6`) matches `header`.

      session
      |> within_article("Blog Post", fn session ->
        assert_has(session, "p", "Post content")
      end)

  """
  @spec within_article(Session.t(), String.t(), (Session.t() -> Session.t())) :: Session.t()
  defdelegate within_article(session, header, fun), to: Scoped

  @doc """
  Scopes to the `<section>` whose first heading (`h1` - `h6`) matches `header`.

      session
      |> within_section("Settings", fn session ->
        assert_has(session, "Send me update", "No")
      end)

  This can also be used more generally when given a CSS selector as the second
  argument.

      session
      |> within_section("div[role=article]", "My header", fn session ->
        assert_has(session, "p", "content")
      end)

  """
  @spec within_section(Session.t(), String.t(), String.t(), (Session.t() -> Session.t())) ::
          Session.t()
  def within_section(session, selector \\ "section", header, fun) do
    Scoped.within_section(session, selector, header, fun)
  end

  @doc """
  Scopes to the `<fieldset>` whose `<legend>` matches `legend`.

      session
      |> within_fieldset("Account", fn session ->
        assert_has(session, "input#username")
      end)

  """
  @spec within_fieldset(Session.t(), String.t(), (Session.t() -> Session.t())) :: Session.t()
  defdelegate within_fieldset(session, legend, fun), to: Scoped

  @doc """
  Click on a link by its text.

  This is simply a shorthand for `Mirage.click/3` with `"a"` as its selector.

  """
  @spec click_link(Session.t(), String.t(), keyword(any())) :: Session.t()
  def click_link(session, text, opts \\ []) do
    click(session, "a", text, opts)
  end

  @doc """
  Click on a button by its text.

  If it's a submit button belonging to a form, it will trigger that form's
  `$submit` event.

  This is otherwise shorthand for `Mirage.click/3` with `"button"` as its selector.

  """
  @spec click_button(Session.t(), String.t(), keyword(any())) :: Session.t()
  def click_button(session, text, opts \\ []) do
    click(session, "button", text, opts)
  end

  @doc """
  Trigger a `$click` event on the element matching the given CSS selector.

  Any actions or commands will be run.  If the click triggers a page navigation,
  the new page will be loaded into the session.  When clicking a submit button
  that belongs to a form, that form's `$submit` event will be triggered.

  Raises if no matching element with a `$click` handler is found, or if more
  than one matches.

  ## Examples

      SignUpPage
      |> visit()
      |> fill_in("Name", with: "Bender")
      |> fill_in("Password", with: "killallhumans")
      |> click("button", "Submit")
      |> assert_page(WelcomePage)

      HomePage
      |> visit()
      |> click("button", "Log out")

  ## Options

    * `:text` - Match on the element's inner text.
    * `:exact` - Set to `false` to match on a substring of an element's text.
      Default is `true` meaning you must provide an exact match.

  """
  @spec click(Session.t(), String.t(), String.t() | keyword()) :: Session.t()
  defdelegate click(session, selector, text_or_opts \\ []), to: Events
  @doc false
  defdelegate click(session, selector, text, opts), to: Events

  @doc """
  Trigger a focus event on an element.

  Accepts the same options as `Mirage.click/3`.

  """
  @spec focus(Session.t(), String.t(), String.t() | keyword()) :: Session.t()
  defdelegate focus(session, selector, text_or_opts \\ []), to: Events
  @doc false
  defdelegate focus(session, selector, text, opts), to: Events

  @doc """
  Trigger a blur event on an element.

  Accepts the same options as `Mirage.click/3`.
  """
  @spec blur(Session.t(), String.t(), String.t() | keyword()) :: Session.t()
  defdelegate blur(session, selector, text_or_opts \\ []), to: Events
  @doc false
  defdelegate blur(session, selector, text, opts), to: Events

  @doc """
  Fill in an `input` or `textarea` by its label.

  Finds an input by its associated label and triggers the input's `$change`
  and as well as its form's `$change` event (if it has one).

  Labels may be associated with their input either by wrapping the input
  (`<label>Name <input/></label>`) or via a `for` attribute matching the
  input's `id`.

  Matches exactly by default; pass `exact: false` to match substrings.
  Raises if no matching label is found, or if more than one matches.

  """
  @spec fill_in(Session.t(), String.t(), keyword()) :: Session.t()
  defdelegate fill_in(session, label, opts), to: Input

  @doc """
  Selects a radio button by its associated label.

  Triggers the input's `$change` event as well as its form's `$change` event (if
  there is one).

  Labels may wrap the input or reference it via a `for`/`id` pair.

  Matches exactly by default; pass `exact: false` to match substrings.
  Raises if no matching radio button is found, or if more than one matches.

  ## Example

      Profile
      |> visit()
      |> choose("robot")
      |> assert_has("p", "Your gender is 'robot'")

  """
  @spec choose(Session.t(), String.t(), keyword()) :: Session.t()
  defdelegate choose(session, label, opts \\ []), to: Input

  @doc """
  Checks a checkbox by its associated label text.

  Triggers the input's `$change` as well as its form's `$change` event (if it
  has one).

  Matches exactly by default; pass `exact: false` to match substrings.
  Raises if no matching radio button is found, or if more than one matches.

  """
  @spec check(Session.t(), String.t(), keyword()) :: Session.t()
  defdelegate check(session, label, opts \\ []), to: Input

  @doc """
  Unchecks a checkbox by its associated label.

  Trigger's the input's `$change` event as well as its form's `$change` event
  (if it has one).

  Matches exactly by default; pass `exact: false` to match substrings.
  Raises if no matching radio button is found, or if more than one matches.

  """
  @spec uncheck(Session.t(), String.t(), keyword()) :: Session.t()
  defdelegate uncheck(session, label, opts \\ []), to: Input

  @doc """
  Selects an option in a `<select>` box by its label.

  Triggers the select's `$change` event with the option's `value`
  attribute (defaulting to the option's inner text when no `value` attribute
  is present).

  Labels may wrap the select element or reference it via a `for`/`id` pair.

  Works with multi-selects.

  Matches exactly by default; pass `exact: false` to match substrings.
  Raises if no matching label or option is found, or if more than one matches.

  ## Example

      EditProfilePage
      |> visit()
      |> select("Company", "Planet Express")
      |> assert_has("p", "You work for 'Planet Express'")

  """
  @spec select(Session.t(), String.t(), String.t(), keyword()) :: Session.t()
  defdelegate select(session, label, option_text, opts \\ []), to: Input

  @doc """
  Triggers a `$select` event on a text input or textarea by its label selecting
  the text given to `option_text`.

  When `text` is omitted, all text in the input is selected.

  Raises if the label does not point to an input that accepts text (i.e. raises
  for checkboxes, radios, selects, and non-text input types).

  ## Examples

      session
      |> fill_in("Bio", with: "I'm a bending unit. I bend girders.")
      |> select_text("Bio", "girder")

      session
      |> fill_in("Bio", with: "My hobbies include smoking cigars, drinking, and killing all humans")
      |> select_text("Bio")

  """
  @spec select_text(Session.t(), String.t(), String.t() | keyword()) :: Session.t()
  defdelegate select_text(session, label, text_or_opts \\ []), to: Input
  @doc false
  defdelegate select_text(session, label, text, opts), to: Input

  @doc """
  Asserts that the session's DOM contains exactly one element matching the
  given CSS selector (and optional filters).

  Raises if no element matches or if more than one element matches.

      session
      |> assert_has("button")
      |> assert_has("h1", "Welcome")
      |> assert_has("input#email", value: "bender@planetexpress.com")

  ## Options

    * `:text` — also require the element's inner text (trimmed) to equal this value
    * `:value` — also require the element's `value` attribute to equal this value
    * `:at` — match only the element at this 1-based position among all nodes
      matching the selector

  """
  @doc group: "Assertions"
  defdelegate assert_has(session, selector, text_or_opts \\ []), to: Mirage.Assertions
  @doc false
  defdelegate assert_has(session, selector, text, opts), to: Mirage.Assertions

  @doc """
  Asserts that the session's DOM does *not* contain any element matching the
  given CSS selector (and optional filters).

      session
      |> refute_has(".error")
      |> refute_has("p", text: "Deleted")

  Accepts the same options as `assert_has/3`.
  """
  @doc group: "Assertions"
  defdelegate refute_has(session, selector, text_or_opts \\ []), to: Mirage.Assertions
  @doc false
  defdelegate refute_has(session, selector, text, opts), to: Mirage.Assertions

  @doc """
  Asserts that we are on a specific page.  Useful after redirect.

  Optionally takes a keyword list of expected params:

      session
      |> click_link("Profile")
      |> assert_page(ProfilePage, user_id: 42)

  """
  @doc group: "Assertions"
  @spec assert_page(Session.t(), module(), keyword()) :: Session.t() | no_return()
  defdelegate assert_page(session, page, expected_params \\ []), to: Mirage.Assertions

  @doc """
  "Reloads" the current page by revisiting it with the current params.

  All client-side state (component state, checked radios, etc.) is reset,
  just like a real browser reload.

      session
      |> fill_in("Name", with: "Leela")
      |> reload()
      |> refute_has("input", value: "Leela")

  """
  @spec reload(Session.t()) :: Session.t()
  def reload(%Session{page_module: page_module, params: params}) do
    visit(page_module, Keyword.new(params))
  end

  @doc """
  Opens the current page HTML in the default browser.

      session
      |> fill_in("Name", with: "Philip")
      |> open_browser()
      |> assert_has("Philip")

  When using with a component (via `Mirage.mount/2`), the output will be wrapped
  in a thin layout bringing in your app's styles as well as a small bit of CSS that
  center's the component in the viewport.

  ## Options

    * `:wrap` - When `false`, skips the layout wrapper entirely and outputs
      raw component HTML.  Defaults to `true`.
    * `:center` - When `false`, omits the centering CSS.  Defaults to `true`.

  Both options can be configured globally:

      # config/test.exs
      config :mirage, open_browser: [center: false, wrap: false]

  """
  @spec open_browser(Session.t(), keyword() | function()) :: Session.t()
  defdelegate open_browser(session, opts_or_open_fun \\ []), to: Mirage.Browser

  @doc false
  defdelegate open_browser(session, opts, open_fun), to: Mirage.Browser

  defp runtime_context do
    %{
      {Hologram.Runtime, :initial_page?} => false,
      {Hologram.Runtime, :page_mounted?} => true,
      {Hologram.Runtime, :page_digest} => "test",
      {Hologram.Runtime, :csrf_token} => "test"
    }
  end
end
