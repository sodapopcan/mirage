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

    alias Hologram.Component
    alias Hologram.Server

    defstruct [
      :page,
      :server,
      :ast,
      :page_module,
      :params,
      :scope,
      checked_radios: %{},
      checked_checkboxes: MapSet.new(),
      selected_options: %{}
    ]

    @type t :: %__MODULE__{
            page: Component.t(),
            server: Server.t(),
            ast: any(),
            page_module: module(),
            params: %{atom() => any()},
            scope: {:element, String.t(), list(), list()} | nil,
            checked_radios: %{optional(String.t() | nil) => String.t()},
            checked_checkboxes: MapSet.t({String.t() | nil, String.t()}),
            selected_options: %{optional(String.t() | nil) => MapSet.t(String.t())}
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
  @spec visit(module(), %{atom() => any()}) :: Session.t()
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
    ast = DOM.expand(root, env, server)

    %Session{page: page, server: server, ast: ast, page_module: page_module, params: params}
  end

  @doc """
  Scopes all operations within the given block to descendants of the element
  matching `selector`.

      session
      |> within(".sidebar", fn session ->
        session
        |> assert_has("a", "Home")
        |> click("a", "Home")
      end)

  """
  defdelegate within(session, selector, fun), to: Scoped

  @doc """
  Scopes to the `<article>` whose first heading (h1–h6) matches `header`.

      session
      |> within_article("Blog Post", fn session ->
        session |> assert_has("p", "Post content")
      end)

  """
  defdelegate within_article(session, header, fun), to: Scoped

  @doc """
  Scopes to the `<section>` whose first heading (h1–h6) matches `header`.

      session
      |> within_section("Settings", fn session ->
        session |> assert_has("input#email")
      end)

  """
  defdelegate within_section(session, header, fun), to: Scoped

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

  This is simply a short-hand for `Mirage.click/3` with `"button"` as its selector.
  Also handles `<input type="submit">` inside a form with a `$submit` handler.

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

  ```
  HomePage
  |> visit()
  |> click("button")
  ```

  ```
  SignUpPage
  |> visit()
  |> fill_in("Name", with: "Bender")
  |> fill_in("Password", with: "killallhumans")
  |> click("button", "Submit")
  |> assert_page(WelcomePage)
  ```

  ## Options
  - `:text` Match on the element's inner text.
  - `:exact` Set to `false` to match on a substring of an element's text.
    Default is `true` meaning you must provide an exact match.

  """
  @doc group: "Events"
  @spec click(Session.t(), String.t(), String.t() | keyword()) :: Session.t()
  defdelegate click(session, selector, text_or_opts \\ []), to: Events
  @doc false
  defdelegate click(session, selector, text, opts), to: Events

  @doc """
  Trigger a focus event on an element.

  Accepts the same options as `Mirage.click/3`.
  """
  @doc group: "Events"
  defdelegate focus(session, selector, text_or_opts \\ []), to: Events
  @doc false
  defdelegate focus(session, selector, text, opts), to: Events

  @doc """
  Trigger a blur event on an element.

  Accepts the same options as `Mirage.click/3`.
  """
  @doc group: "Events"
  defdelegate blur(session, selector, text_or_opts \\ []), to: Events
  @doc false
  defdelegate blur(session, selector, text, opts), to: Events

  @doc """
  Finds an input by its associated label and triggers the input's `$change`
  and (if the input is inside a `<form>` with a `$change` attribute) the
  form's `$change` action. Each action receives `%{value: value}` merged
  into any params declared on the attribute itself; keys declared in `with:`
  win on conflict.

  Labels may be associated with their input either by wrapping the input
  (`<label>Name <input/></label>`) or via a `for` attribute matching the
  input's `id`.

  Matches exactly by default; pass `exact: false` to match substrings.
  Raises if no matching label is found, or if more than one matches.
  """
  @spec fill_in(Session.t(), String.t(), keyword()) :: Session.t()
  def fill_in(session, label, opts) do
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

        session
        |> Input.trigger_input_action(input, value)
        |> Input.trigger_form_change(form_change, value)

      [_ | _] = many ->
        raise "Ambiguous match: found #{length(many)} labels matching: #{inspect(label)}"
    end
  end

  @doc """
  Selects a radio button by its associated label text and dispatches the
  input's `$change` event with the radio's `value` attribute.

  Labels may wrap the input or reference it via a `for`/`id` pair.

  Matches exactly by default; pass `exact: false` to match substrings.
  Raises if no matching radio button is found, or if more than one matches.

  ## Example

  ```elixir
  visit(SignUpPage)
  |> choose("Female")
  |> assert_has("p", "Selected: female")
  ```
  """
  @spec choose(Session.t(), String.t(), keyword()) :: Session.t()
  defdelegate choose(session, label, opts \\ []), to: Input

  @doc """
  Checks a checkbox by its associated label text and dispatches the input's
  `$change` event with the checkbox's `value` attribute (defaulting to `"on"`).

  Accepts the same options as `choose/3`.
  """
  @spec check(Session.t(), String.t(), keyword()) :: Session.t()
  defdelegate check(session, label, opts \\ []), to: Input

  @doc """
  Unchecks a checkbox by its associated label text and dispatches the input's
  `$change` event with the checkbox's `value` attribute (defaulting to `"on"`).

  Accepts the same options as `choose/3`.
  """
  @spec uncheck(Session.t(), String.t(), keyword()) :: Session.t()
  defdelegate uncheck(session, label, opts \\ []), to: Input

  @doc """
  Selects an option in a `<select>` box identified by its associated label
  text, and dispatches the select's `$change` event with the option's `value`
  attribute (defaulting to the option's inner text when no `value` attribute
  is present).

  Labels may wrap the select element or reference it via a `for`/`id` pair.

  For multiselect boxes (those with a `multiple` attribute), each call
  accumulates another selection rather than replacing the previous one.

  Matches exactly by default; pass `exact: false` to match substrings.
  Raises if no matching label or option is found, or if more than one matches.

  ## Example

  ```elixir
  visit(SignUpPage)
  |> select("Color", "Red")
  |> assert_has("p", "Selected: red")
  ```
  """
  @spec select(Session.t(), String.t(), String.t(), keyword()) :: Session.t()
  defdelegate select(session, label, option_text, opts \\ []), to: Input

  @doc """
  Triggers a `$select` event on a text input or textarea identified by its
  associated label text.

  The event receives `%{text: text}` where `text` is the string passed as the
  third argument, representing the text the user selected.

  Raises if the label does not point to an input that accepts text (i.e. raises
  for checkboxes, radios, selects, and non-text input types).

  ## Example

      session
      |> fill_in("Bio", with: "Hello world")
      |> select_text("Bio", "world")

  """
  @spec select_text(Session.t(), String.t(), String.t(), keyword()) :: Session.t()
  defdelegate select_text(session, label, text, opts \\ []), to: Input

  @doc """
  Asserts that the session's DOM contains exactly one element matching the
  given CSS selector (and optional filters).

  Raises if no element matches or if more than one element matches.

      session
      |> assert_has("button")
      |> assert_has("h1", "Welcome")
      |> assert_has("input#email", value: "alice@example.com")

  ## Options

    * `:text` — also require the element's inner text (trimmed) to equal this value
    * `:value` — also require the element's `value` attribute to equal this value

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
  Opens the current page HTML in the default browser.

      session
      |> fill_in("Name", with: "Alice")
      |> open_browser()
      |> assert_has("Alice")

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
