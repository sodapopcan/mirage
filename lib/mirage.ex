defmodule Mirage do
  @moduledoc """
  Test framework for the Hologram web framework.

  The entry point is `visit/2`, which initializes a page and expands its
  template into a fully-resolved DOM that tests can make assertions against.
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
        components: %{}
      }
    ]

    @typep bookkeeping :: %{
             checked_radios: map(),
             checked_checkboxes: map(),
             selected_options: map(),
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

  @doc """
  Entry point to create a session.

  Takes a `Hologram.Page` and, optional, any params.  It returns a session which
  the rest of `Mirage` can use.

  """
  @spec visit(module(), map()) :: Session.t()
  def visit(page_module, params \\ %{}) do
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
        components: components
      }
    }
  end

  @doc """
  Mount a component in isolation for testing.

  Takes a `Hologram.Component` module and an optional keyword list.  Returns a
  session that can be used with the rest of the `Mirage` API just like one
  created by `visit/2`, but without a page or layout wrapper.

  ## Options

    * `:props` — a map of props to pass to the component
    * `:context` — a map of context values; props declared with `from_context`
      will be populated from this map

  ## Example

      MyApp.Counter
      |> mount(props: %{cid: "counter"})
      |> click("button", "Increment")
      |> assert_has("span", "1")

  """
  @spec mount(module(), props: map(), context: map()) :: Session.t()
  def mount(component_module, opts \\ []) do
    Keyword.validate!(opts, [:props, :context])
    props = Keyword.get(opts, :props, %{})
    context = Keyword.get(opts, :context, %{})

    props =
      props
      |> DOM.inject_props_from_context(component_module, context)
      |> DOM.inject_default_prop_values(component_module)

    server = %Hologram.Server{}
    {component, server} = DOM.init_component(component_module, props, server)

    vars = Map.merge(props, component.state)
    template_dom = component_module.template().(vars)

    merged_context = Map.merge(runtime_context(), component.emitted_context)
    merged_context = Map.merge(merged_context, context)
    env = %{context: merged_context, slots: []}

    Process.delete(:mirage_components)
    ast = DOM.expand(template_dom, env, server)
    components = Process.delete(:mirage_components) || %{}

    %Session{
      page: component,
      server: server,
      ast: ast,
      page_module: component_module,
      params: props,
      bookkeeping: %{
        checked_radios: %{},
        checked_checkboxes: MapSet.new(),
        selected_options: %{},
        components: components
      }
    }
  end

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

  This is simply a short-hand for `Mirage.click/3` with `"a"` as its selector.

  """
  @spec click_link(Session.t(), String.t(), keyword(any())) :: Session.t()
  def click_link(session, text, opts \\ []) do
    click(session, "a", text, opts)
  end

  @doc """
  Click on a button by its text.

  If it's a button inside a form, it will trigger the form's `$submit` event.

  This is otherwise short-hand for `Mirage.click/3` with `"button"` as its selector.

  """
  @spec click_button(Session.t(), String.t(), keyword(any())) :: Session.t()
  def click_button(session, text, opts \\ []) do
    click(session, "button", text, opts)
  end

  @doc """
  Trigger a `$click` event on the element matching the given CSS selector.

  Any actions or commands will be run.  If the click triggers a page navigation,
  the new page will be loaded into the session.

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
  defdelegate focus(session, selector, text_or_opts \\ []), to: Events
  @doc false
  defdelegate focus(session, selector, text, opts), to: Events

  @doc """
  Trigger a blur event on an element.

  Accepts the same options as `Mirage.click/3`.
  """
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
  def fill_in(session, label, opts) do
    Keyword.validate!(opts, [:with, :exact])
    exact? = Keyword.get(opts, :exact, true)
    value = Keyword.fetch!(opts, :with)

    {labels, inputs_by_id} = Input.collect_form_nodes(Scoped.query_ast(session), nil)

    matches =
      Enum.filter(labels, fn {node, _wrapped, _form_change} ->
        DOM.text_matches?(DOM.inner_text(node), label, exact?)
      end)

    case matches do
      [] ->
        raise "No input found with label: #{inspect(label)}"

      [entry] ->
        {input, form_change} = Input.resolve_input(entry, inputs_by_id, label)
        Input.validate_interactive!(input, label)

        session
        |> Input.trigger_input_action(input, value)
        |> Input.trigger_form_change(form_change, value)

      [_ | _] = many ->
        raise "Ambiguous match: found #{length(many)} labels matching: #{inspect(label)}"
    end
  end

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
  """
  @doc group: "Assertions"
  @spec assert_page(Session.t(), module()) :: Session.t() | no_return()
  defdelegate assert_page(session, page), to: Mirage.Assertions

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
    visit(page_module, params)
  end

  @doc """
  Opens the current page HTML in the default browser.

      session
      |> fill_in("Name", with: "Philip")
      |> open_browser()
      |> assert_has("Philip")

  When using with a component (via `Mirage.mount/2`), the output will be wrapped
  in a thin layout bringing in your app's styles.

  """
  @spec open_browser(Session.t()) :: Session.t()
  defdelegate open_browser(session), to: Mirage.Browser

  @doc false
  defdelegate open_browser(session, open_fun), to: Mirage.Browser

  defp runtime_context do
    %{
      {Hologram.Runtime, :initial_page?} => false,
      {Hologram.Runtime, :page_mounted?} => true,
      {Hologram.Runtime, :page_digest} => "test",
      {Hologram.Runtime, :csrf_token} => "test"
    }
  end
end
