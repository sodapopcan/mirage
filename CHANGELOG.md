# Changelog

## v0.0.2 (Apr 18, 2026)

### Added

- `mount/2` — mount a component in isolation for testing, without a page or
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
