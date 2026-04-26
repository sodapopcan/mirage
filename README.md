# Mirage

[![Hex.pm](https://img.shields.io/hexpm/v/mirage.svg)](https://hex.pm/packages/mirage)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/mirage)

Browserless page and component testing library for
the [Hologram](http://hologram.page) framework.

## About

Mirage allows for browserless testing of hologram pages and components.  Its API
is very similar to that of
[`PhoenixTest`](https://hex.pm/packages/phoenix_test).

Here is a quick example:

```elixir
defmodule MyApp.HomePageTest do
  use MyApp.PageCase, async: true

  test "sign up", %{server: server} do
    server
    |> visit(MyApp.HomePage, my_param: "some-param")
    |> click_link("Sign-up")
    |> fill_in("Name", with: "Bender Bending Rodríguez")
    |> fill_in("Password", with: "wanna-kill-all-humans?")
    |> click_button("Submit")
    |> assert_page(MyApp.WelcomePage)
    |> assert_has("p", "Welcome, Bender!")
  end
end
```

You can also test components in isolation:

```elixir
defmodule MyApp.Components.PoplarTrackerTest do
  use MyApp.ComponentCase, async: true

  test "it counts" do
    ~HOLO"""
    <MyApp.Components.PoplarTracker cid="counter" eaten={0}>
      <p>{@user.name} eats too many poplars.</p>
    </MyApp.Components.PoplarTracker>
    """
    |> mount({MyApp, user: current_user})
    |> click_button("Eat a poplar")
    |> assert_has("p", "Number of poplars eaten: 1")
  end
end
```

Mirage works by initializing page and component modules directly and "faking"
events to call `action` and `command` calls behind the scenes.  It's similar to
doing:

```elixir
page = Counter.init(%{count: 0}, %Hologram.Component{}, %Hologram.Server{})
page = Counter.action(:count, %{}, page)
assert page.state.count == 1
```

only Mirage allows you to interact with the Hologram's virtual DOM.

## JavaScript testing

Note that Mirage does not handle JavaScript.  Of course, with Hologram being an
isomorphic framework, we write most of our JavaScript in Elixir anyway, so
Mirage can take you really far.  However, if you need to test any JS-interop
features you will need to write those tests in
[Wallaby](https://hex.pm/packages/wallaby) or
[PlaywrightEx](https://hex.pm/packages/playwright_ex).

## Installation

```elixir
def deps do
  [
    {:mirage, "~> 0.1.0", only: :test, runtime: false},
  ]
end
```

Mirage comes with two different extension points, `Mirage.Page` and
`Mirage.Component` for testing pages and component, respectively.

For each test you can `use` the appropriate one.  Each one `import`s all of
Mirage's test helpers otherwise the difference is that `Mirage.Page` puts a bare
`%Hologram.Server{}` into the test context, and `Mirage.Component` imports the
`~HOLO` sigil.

If you are using the Ecto sandbox, you will probably want to make your own
custom case for, at least, pages:


```elixir
defmodule MyApp.PageCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use Mirage.Page
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Frankly.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end
```

If you have components that interact with the database, you'll want to make one
for `MyApp.ComponentCase` as well.

## I'm Mr. Meeseeks, look at me!

This project contains code adapted from
[meeseeks](https://hex.pm/packages/meeseeks) specifically for parsing CSS
selectors.  See [lib/mirage/css.ex](lib/mirage/css.ex).

## Note on AI-use

This library is currently super-alpha.  It was made with heavy LLM assistance as
it's something that has been blocking progress on another project of mine.
I have not finished the full vetting process yet.
