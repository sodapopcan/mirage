# Changelog

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
