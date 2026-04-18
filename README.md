# Mirage

Testing framework for [Hologram](http://hologram.page)

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
    {:mirage, "~> 0.1.0"}
  ]
end
```

## To do

- [ ] Pointer events
- [ ] `type/2` function
  - Simulate the user typing.  Will trigger change events as well as key events
  when they are available.
