# CLAUDE.md — vox_lib

Agent reference for this resource. Read before editing. Keep current after every task.

## Purpose
HELIX-native UI + utility library — a clean-room equivalent of the ox_lib `lib.*` contract for HELIX (UE 5.7.4 / Lua 5.4).
UI tier (notify/textUI/alert/progress/input/context/menu/skillCheck/radial) + cinematic layer (weather/time/freecam) +
foundation (class/table/array/string/math/cache/print/locale/timer/waitFor/callback/hook). Consumer docs: `README.md`,
`docs/developer.md`, `docs/tech.md`.

## Dependencies
- **None external.** Pure Lua + HELIX runtime (`Timer`, `Sky()`, WebUI, `Input.BindKey`, UE reflection).
- Internal load order: `init.lua` (creates `lib`) → `modules/scheduler.lua` (optional) → `modules/class.lua` → rest. Canonical
  order is in `package.json`. `class` underpins `array` + `timer`.

## Events
- WebUI: Lua→page via `SendEvent` (`{name, args:[payload]}`); page→Lua via `hEvent(name, data)` → one-shot handlers in
  `modules/_dialog.lua`. Per-component events are `"<component>:show"` / `"<component>:response"` etc.
- `lib.callback` rides the net-event transport (native callbacks are broken on HELIX).

## Functions / Exports
- **NOT an exports resource** — functions don't cross HELIX's package boundary. `lib.*` lives in the consumer's own state
  (standalone package OR source-bundled). Full surface: `docs/developer.md`.

## Architecture
- `init.lua` — creates global `lib`, sets `lib._VERSION`.
- `modules/` — one file per capability; each attaches itself to `lib` on load. `_dialog.lua` = shared return-value plumbing
  (create WebUI → one-shot response handler → SendEvent → Wait-yield). `scheduler.lua` = optional `Wait`/`CreateThread` shim
  (guarded; no-ops if host provides them).
- `web/<component>/index.html` — WebUI per visual component; `web/_shared/helix-life.css` = shared theme.
- `dev/` — **dev-only**: `uitest.lua` (net-event `vox:ui` trigger per component + `/v*` chat commands), `_devsched.lua`
  (old standalone shim, superseded by `modules/scheduler.lua`), `weather_menu.lua`/`freecam_dev.lua` (`/weather`, `/freecam`).
- `design/`, `design-divergent/` — static design references (Kit A / Kit B galleries).

## Gotchas
- Return-value calls (`alertDialog`/`inputDialog`/`progressBar`/`skillCheck`) **yield** → call inside a thread.
- `Timer.SetTimeout` rejects `0` (scheduler clamps to ≥1ms).
- Halt-on-first-throw: don't throw in normal flow (`waitFor` returns `nil` on timeout by design).
- Chat-command registration is unreliable — `HConsole` inits *after* package load, so commands registered at load may no-op.
  The test harness uses the net-event path (`BroadcastEvent('vox:ui', '<name>')`) instead.
- `Input.BindKey` is press/release only (no mouse-delta); freecam mouse-look reads control rotation.

## Do Not
- Do **not** read or copy ox_lib source — this is clean-room from the public API docs only.
- Do **not** add references to internal/private projects, tooling, or world IDs — this repo is **PUBLIC** (MIT). Keep scrubbed.
- Do **not** ship `dev/` or the test-build manifest as production — `package.json` is the production manifest.

## Verification
- In-engine: deploy to a testbed world, boot it, and drive components from a server script / probe with
  `BroadcastEvent('vox:ui', '<component>')` (the `dev/uitest.lua` net-event harness). Close the world when done.
- UI tier verified 9/9 end-to-end; production manifest verified to load clean (all 25 modules, no errors).

## Changelog
- **1.1.0** — `modules/charcreator.lua`: Character Creator surface over HELIX's native cosmetics (`BPC_CharacterCreator`).
  Appearance capture/persist/reapply round-trip probe-verified live (`RetainCharacterCustomizationPreset:SaveToString` ↔
  `LoadFromString`+`ApplyCharacterCustomizationPreset`); contract `{Gender, Slots:{guid:{MaterialParameters}}}`. No web page
  (native UI). Docs: developer.md (Character Creator + persistence pattern), tech.md.
- **1.0.0** — UI tier complete + verified in-world + polished; cinematic layer (weather/time/freecam); production manifest +
  `modules/scheduler.lua`; full doc set. Public MIT repo `GrizzyVV/vox_lib-HELIX-`.
- 0.3.0 — foundation (Stages 1–3) + initial UI builds.

## Last Updated
2026-06-27
