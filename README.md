# Mirage

Web testing library for [Hologram](http://hologram.page)

## About

Mirage provides testing helpers very similar to that of [`PhoenixTest`](https://hex.pm/packages/phoenix_test).

Here is a quick example:

```elixir
MyApp.HomePage
|> visit(%{my_param: "Some param"})
|> click_link("Sign-up")
|> fill_in("Name", with: "Bender Bending Rodríguez")
|> fill_in("Password", with: "wanna-kill-all-humans?")
|> click_button("Submit")
|> assert_page(MyApp.WelcomePage)
|> assert_has("p", "Welcome, Bender!")
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

## Note on adapted code

This project contains code adapted from
[Meeseeks](https://hex.pm/packages/meeseeks) specifically for parsing CSS
selectors.  See [lib/mirage/css.ex](lib/mirage/css.ex).

## Note on AI use

This library is currently super-alpha.  It was made with heavy LLM-assisted as
it's something that has been blocking progress on another project of mine.
I have not finished the full vetting process yet.
