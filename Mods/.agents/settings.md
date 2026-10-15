# Settings

## Settings versioning

Every mod stores a version number on its own settings so later changes to what's stored can be
migrated instead of breaking existing games.

- Define `LATEST_SETTINGS_VERSION` as a global constant.
- Write `Mod.Settings.Version = LATEST_SETTINGS_VERSION` unconditionally in `Client_SaveConfigureUI`,
  every time settings are saved - not just when something relevant changed.
- Read it back with `local version = Mod.Settings.Version or 1` everywhere it's needed (`1` is the
  implicit version for games saved before `Version` existed at all).
- When a new setting is introduced, bump `LATEST_SETTINGS_VERSION` and add a note to VersionLog.md
  with what was added. We then have options dependent on the size of the update. We can freeze the
  mods files prior to the change and add a suffix to them with their version number. Then add the changed files
  in under their new version suffix. Use `Mod.Settings.Version` to determine which files to use.
  We can write a MigrateModSettings function and default the new setting to whatever the pre-existing behaviour was.

## Keep `alert(...)` messages plain

When `Client_SaveConfigureUI` rejects a save because a required field is missing, state the
requirement directly - don't add a flourish explaining why it matters or what breaks without it.

- Good: `alert("Every Placeholder Placement row needs a placement name")`
- Not: `alert("Every Placeholder Placement row needs a placement name - without one, nothing can
  ever resolve it to a real structure/special unit")`

The rationale belongs in a code comment near the validation, if it's not obvious, not in the dialog
the game-maker sees.

## Null out the inactive side of a mutually-exclusive settings toggle

`Client_SaveConfigureUI` can run more than once across a mod's lifetime in the same game's settings
(a creator can reopen configuration and resave). If a setting toggles between two mutually-exclusive
groups of fields (e.g. "acquire via card" vs "acquire via commerce"), saving while on one path must
explicitly null/default every field that belongs to the *other* path, not just skip writing them.

Leaving the inactive group's fields untouched means they keep whatever value they had from a
previous save where that path was active - a stale value sitting behind a guard
(`if (Mod.Settings.IsAcquiredByCommerce) then ... end`) that looks dead but will come back the
moment the toggle flips again, or get read by code that doesn't realize it's stale. This has
already caused erroneous behaviour. `BombShelter` does this correctly (`Clear_Card_Settings()` /
`Clear_Commerce_Settings()`, called depending on which mode is active); other mods with
toggle-gated sub-settings (e.g. `CharmAndFear`, `Conscription`) don't yet - bring them in line with
this when next touching them, rather than leaving the gap.
