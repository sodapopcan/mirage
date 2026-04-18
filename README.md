# Mirage

Web testing library for [Hologram](http://hologram.page)

## About

Mirage provides testing helpers very similar to that of [`PhoenixTest`](https://hex.pm/packages/phoenix_test).

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
  MyApp.Counter
  |> mount(props: %{count: 0})
  |> click_button("+")
  |> assert_has("span", "1")
end
```

Mirage tracks the state of the page under test, triggers actions, commands, and
follows any navigation or redirects, as well as everyone's favourite debugging
tool: `Mirage.open_browser/1`.

## Installation

```elixir
def deps do
  [
    {:mirage, "~> 0.0.1", only: :test, runtime: false}
  ]
end
```

To use Mirage, just `import` it into your tests or your custom `CaseTemplate`
implementation.

```elixir
import Mirage
```

## Note on adapted code

This project contains code adapted from
[Meeseeks](https://hex.pm/packages/meeseeks) specifically for parsing CSS
selectors.  See [lib/mirage/css.ex](lib/mirage/css.ex).

## Note on AI use

This library is currently super-alpha.  It was made with heavy LLM-assisted as
it's something that has been blocking progress on another project of mine.
I have not finished the full vetting process yet.
