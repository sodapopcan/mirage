# Changelog

## v0.6.2 (May 5, 2026)

### Added

- `assert_disabled/2` / `refute_disabled/2` — assert whether an input
  (found by label text) is disabled.
- `assert_readonly/2` / `refute_readonly/2` — assert whether an input
  (found by label text) is readonly.

## v0.6.1 (May 1, 2026)

### Fixed

- Chained actions and commands now respect `action.target` / `command.target`.
  Previously `next_action` and `next_command` set during a component action
  always reused the original target, ignoring `target: "page"` or explicit
  component cids.

## v0.6.0 (Apr 30, 2026)

### Added

- Implicit component targeting — event handlers (`$click`, `$change`,
  `$submit`, etc.) inside a stateful component's template now automatically
  target that component. Matches Hologram's `defaultTarget` behaviour so
  explicit `target:` is only needed when dispatching across component
  boundaries.
- Component init action draining — `next_action` set during a component's
  `init/3` is now drained after page render and `mount/2`, matching page-level
  init drain behaviour.

## v0.5.0 (Apr 26, 2026)

### Breaking

`visit` now takes a `%Hologram.Session{}` as its first arg.  This allows for
setting cookie and session data.

### Added

- `use Mirage.Page` — extension module that imports Mirage and sets up an ExUnit
  `setup` block providing `%{server: %Hologram.Server{}}` in test context.
- `use Mirage.Component` — extension module that imports Mirage and `sigil_HOLO`
  for component-level tests.
- Init lifecycle drain — `visit/3` now drains `next_command`, `next_action`
  (recursive), and `next_page` set during `init/3`, matching Hologram's runtime
  behaviour.
- `fill_in_hidden/3` — fill in a hidden input by its `name` attribute. Validates
  the input is actually hidden and not disabled or readonly. Triggers `$change`
  on both the input and its enclosing form.

## v0.0.7 (Apr 21, 2026)

### Fixed

- Server state now persists across client-side navigation (link clicks and
  action redirects no longer reset the server).
- Shorthand event syntax now supports `target:` option
  (e.g. `$click={:my_action, target: "cid"}`).

### Changed

- `assert_has` and `refute_has` now trim whitespace (including newlines) when
  comparing `:text` and `:value` options.

## v0.0.6 (Apr 21, 2026)

### Changed

- Form-level `$change` now receives all named field values in the event data,
  matching Hologram's runtime behaviour.
- Form `$submit` now includes all named field values in the event data
  (e.g. hidden inputs, filled text fields, checked radios).
- `open_browser`'s `:wrap` is now used to control the minimal layout wrapped
  around components. `:center` is now used to center the component in the
  viewport.

### Added

- `filled_inputs` bookkeeping — tracks values set via `fill_in` so form data
  collection works even for inputs without a `value` binding in the template.

## v0.0.5 (Apr 20, 2026)

### Added

- `:count` option for `assert_has`: assert exact number of matching elements
  (e.g. `assert_has(session, "li", count: 3)`).
- `:label` option for `assert_has` and `refute_has`: filter elements by their
  associated `<label>` text
  (e.g. `assert_has(session, "input", label: "Email", value: "foo@bar.com")`).
- `click`/`click_button` now finds submit buttons outside a `<form>` that
  reference it via the HTML `form` attribute.
- `open_browser` now centres mounted components by default.  Disable per-call
  with `open_browser(session, wrap: false)` or globally with `config :mirage,
  open_browser: [wrap: false]`.

### Fixes
- `~HOLO` sigil was not being exported from `Mirage`.

## v0.0.4 (Apr 20, 2026)

### Added

- `assert_page/3` — optional keyword list of expected params to assert against
  after navigation.

### Changed

- `mount/2` redesigned around `~HOLO` templates. Props, cid, and slot content are
  declared in markup; context is the only argument to `mount`.  Accepts a single
  `{Namespace, key: value}` tuple or a list of tuples for multiple namespaces.
- `visit/2` now takes a keyword list instead of a map.

## v0.0.3 (Apr 18, 2026)

### Added

- `:at` option for `assert_has` and `refute_has` — match by 1-based position
  among all elements matching the selector.
- Option validation — all functions that accept options now raise
  `ArgumentError` for unknown keys (via `Keyword.validate!/2`).
- `open_browser/1` wraps mounted components in a bare HTML layout with your
  app's stylesheets.

## v0.0.2 (Apr 18, 2026)

### Added

- `mount/4` — mount a component in isolation for testing, without a page or
  layout. Accepts `:props` and `:context` options; context values populate
  `from_context` props.
- `reload/1` — revisit the current page with the current params, resetting all
  client-side state.
- `within_section/4` — accepts an optional CSS selector argument to scope to
  elements other than `<section>` (e.g. `div[role=article]`).
- Target support — event attributes with `target: "cid"` now dispatch actions
  and commands to stateful child components identified by their `cid`.

### Changed

- `fill_in`, `choose`, `check`, `uncheck`, `select`, and `select_text` now
  raise when the matched input is hidden (`hidden` attribute or
  `type="hidden"`), disabled, or readonly.

## v0.0.1 (Apr 18, 2026)

Initial release.
