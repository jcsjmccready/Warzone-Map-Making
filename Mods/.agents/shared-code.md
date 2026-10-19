# Shared code: copy-paste, not import

Lua mods can't `require` across mod folders, so any code meant to be common has to be copied into
each mod that uses it. Treat these as living copies of the same source, not independent forks -
when one needs a fix, port the same fix into every mod carrying a copy of it.

- **`IO/` package** - every mod should carry it, even if it isn't calling into another mod yet.
  Copy `IO/IO.lua`, `IO/Util.lua`, `IO/Reader.lua`, `IO/Writer.lua`, `IO/ModAuth.lua` and
  `IO/ApiBase.lua` as-is from an existing mod (`PointsofInterest` or `DeadManSwitch` are current).
  The only thing that changes per mod is `IO.ModAuth.LOCAL_MOD_KEY` in `IO/ModAuth.lua`. This is
  generic ModAuth plumbing (authenticated cross-mod messaging) - it should never need
  project-specific edits; if it does, the fix belongs in every other mod's copy too.
  `LOCAL_MOD_KEY` must be `<ModName>_<AuthorHandle>` (e.g. `"BombShelter_Mgreedy"`), not just
  `<ModName>` - two authors shipping a same-named mod without the author suffix would collide.
- **`CommonUtils.lua`** - logic that's genuinely generic across mods (colour helpers, string/table
  helpers, geometry helpers, etc. - the stuff currently duplicated at the top of every mod's
  `Utilities.lua`) belongs in a `CommonUtils.lua` file, kept identical across mods by copy-paste, the
  same way `IO/` is. Keep it separate from each mod's own `Utilities.lua`, which should only hold
  logic specific to that mod. When adding something to `CommonUtils.lua`, update it in one mod first,
  then copy the updated file into every other mod that carries it. See
  `CustomScenarioBuilderModOrchestrator/Orchestrator/CommonUtils.lua` for the current copy.
