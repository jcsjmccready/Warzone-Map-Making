# Warzone mod conventions

Conventions for building/editing mods under `Mods/`. Each mod is a self-contained folder of Lua
hook files uploaded independently to Warzone - there is no shared build step, so "shared code"
below means "kept in sync by hand," not "imported."

Detailed rules live in `.agents/`, split into focused files by topic. Read the relevant file(s)
below *before* doing the matching kind of work, rather than relying on memory of this index alone -
this list only summarizes what's in each file and when it applies.

- **[.agents/settings.md](.agents/settings.md)** - Read before touching `Client_SaveConfigureUI.lua`,
  `Client_PresentConfigureUI.lua`, or anything that reads `Mod.Settings`. Covers the settings-version
  convention (`Mod.Settings.Version`, migrations), keeping validation `alert(...)` messages plain, and
  the rule that a mutually-exclusive settings toggle must null out the inactive side on every save.
- **[.agents/game-data.md](.agents/game-data.md)** - Read before writing to or reading from
  `Mod.Settings`, `Mod.PrivateGameData`, `Mod.PublicGameData` or `Mod.PlayerGameData` anywhere (hooks,
  `Application.lua`, etc.). Covers where card IDs and custom structure type IDs must be stored, and
  the read-mutate-reassign-whole-table rule for every one of these tables.
- **[.agents/validation.md](.agents/validation.md)** - Read before adding or changing any check on a
  vanilla card dependency (Airlift, Spy, Blockade, ...), whether in `Client_CreateGame.lua` or in
  server code that plays a vanilla card programmatically. Covers the double-check requirement and the
  standard rejection message.
- **[.agents/shared-code.md](.agents/shared-code.md)** - Read before adding the `IO/` package to a
  mod, changing anything inside an existing mod's `IO/` folder, or adding/editing `CommonUtils.lua`.
  Covers which files are copy-pasted verbatim across mods, what's allowed to vary per mod
  (`IO.ModAuth.LOCAL_MOD_KEY` and its naming convention), and the "fix it everywhere it's copied"
  rule.
- **[.agents/architecture.md](.agents/architecture.md)** - Read before building or modifying a mod
  that exposes actions to other mods (or wants its hook logic kept out of the hook files). Covers the
  `Interface.lua` / `Application.lua` / `Api.lua` split and how they relate to the `IO/` package.
- **[.agents/assets.md](.agents/assets.md)** - Read before adding or replacing any mod image
  (`CardImages`, `OrderIcons`, `StructureImages`, `UIImages`, `Icon.png`, `Feature.png`), or when
  scaffolding a new mod folder. Covers required pixel dimensions and the mandatory `LICENSE` /
  `ModDescription.txt` files.
- **[.agents/api-reference.md](.agents/api-reference.md)** - Read whenever unsure what a hook
  receives, what fields a `WL.*` class exposes, or what a hook is allowed to do. Points at
  `Mods/Annotations.lua` as the canonical API reference and clarifies it should never be copied into
  individual mod folders.
- **[.agents/comments.md](.agents/comments.md)** - Read before writing or editing any comment in a
  mod's Lua code. Covers what a comment is allowed to say (a single current fact, not past reasoning
  or cross-references) and how terse function/field doc comments must be.
- **[.agents/style.md](.agents/style.md)** - Read before writing or editing any `UI.Create*` builder
  chain. Covers the one-`.Method()`-per-line formatting required once a chain has 3+ links.
