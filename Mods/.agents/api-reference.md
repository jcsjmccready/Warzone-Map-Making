# Annotations / API reference

`Mods/Annotations.lua` is the single, canonical reference for Warzone's own API (every hook
signature, `WL.*` class, `Game`/`GameServerHook`/`GameClientHook` field, etc.) - it's an editor-time
type-hint file, not something the mod runtime loads, so **don't copy it into individual mod
folders**. When working on any mod and unsure what a hook receives, what fields a `WL.*` class
exposes, or what a hook is allowed to do, read `Mods/Annotations.lua` rather than guessing or
inferring from other mods' usage alone. If a mod folder already has its own copy, it's stale/
redundant - remove it rather than keeping it in sync.

A mod's own custom classes/DTOs go in that mod's `Interface.lua` (see `architecture.md`), not
`Annotations.lua`.
