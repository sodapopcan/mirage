# Mirage

[![Hex.pm](https://img.shields.io/hexpm/v/mirage.svg)](https://hex.pm/packages/mirage)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/mirage)

Web testing library for [Hologram](http://hologram.page)

## About

Mirage allows for headless testing of hologram pages and components.  Its
API is very similar to that of [`PhoenixTest`](https://hex.pm/packages/phoenix_test).

Here is a quick example:

```elixir
test "it works" do
  MyApp.HomePage
  |> visit(%{my_param: "Some param"})
  |> click_link("Sign-up")
  |> fill_in("Name", with: "Bender Bending Rodríguez")
  |> fill_in("Password", with: "wanna-kill-all-humans?")
  |> click_button("Submit")
  |> assert_page(MyApp.WelcomePage)
  |> assert_has("p", "Welcome, Bender!")
end
```

You can also test components in isolation:

```elixir
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
```

Mirage tracks the page under test, triggers actions, commands, and follows any
navigation or redirects.  It also includes everyone's favourite debugging tool:
`open_browser/1`!

## Installation

```elixir
def deps do
  [
    {:mirage, "~> 0.0.1", only: :test, runtime: false},
  ]
end
```

To use Mirage, just `import` it into your tests:

```elixir
defmodule MyApp.MyTest do
  use ExUnit.Case
  import Mirage

  test "it works" do
    MyApp.HomePage
    |> visit()
    # ...
  end
end
```

Or use a custom case:

```elixir
defmodule MyApp.FeatureCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Mirage
    end
  end
end

defmodule MyApp.MyTest do
  use MyApp.FeatureCase

  # ...
end
```

## I'm Mr. Meeseeks, look at me!

This project contains code adapted from
[meeseeks](https://hex.pm/packages/meeseeks) specifically for parsing CSS
selectors.  See [lib/mirage/css.ex](lib/mirage/css.ex).

## Note on AI use

This library is currently super-alpha.  It was made with heavy LLM assistance as
it's something that has been blocking progress on another project of mine.
I have not finished the full vetting process yet.
