# Game data (`Mod.*` tables)

## Storing IDs the mod will need again

- **Card-based mods**: the `CardID` returned by `addCard(...)` in `Client_SaveConfigureUI` must be
  saved onto `Mod.Settings` (e.g. `Mod.Settings.FlakGunCardID = flakGunCardId`), since that's the
  only place later hooks (`Server_AdvanceTurn_Order`, `Client_PresentPlayCardUI`, ...) can read it
  back from.
- **Structure-based mods**: a custom `WL.StructureType.Custom(name)` can only be resolved inside a
  server hook (calling it client-side throws `modContext.Token.ModExecuting is null`). Resolve every
  custom structure ID once in a server hook (`Server_StartGame` typically) and publish the results to
  `Mod.PublicGameData` so client hooks can read the IDs without re-resolving them. See
  `PointsofInterest/Application.lua` (`PointsOfInterestApplication.PublishStructureIDs`) and its
  `PointsOfInterestPublicGameData.StructureIDs` field.
- **Vanilla structure types are the exception** - they don't need a server hook or
  `Mod.PublicGameData` round-trip at all. `WL.StructureType[entry.EnumField]` resolves a vanilla
  structure directly from client-side code, so a client hook can look one up itself (see
  `CustomScenarioBuilderModOrchestrator/Orchestrator/Application/Utilities.lua`'s `GetVanillaStructureNames`).
  Only reach for the publish-from-server pattern above for a *modded* (`WL.StructureType.Custom`)
  structure ID.

## Never mutate game-data tables in place

`Mod.PrivateGameData`, `Mod.PublicGameData`, `Mod.PlayerGameData` and `Mod.Settings` must always be
read into a local, mutated through that local, then reassigned back as a whole:

```lua
local priv = Mod.PrivateGameData;
priv.X = ...;
Mod.PrivateGameData = priv;
```

Writing through a stale reference to a nested field (e.g. holding onto `priv` across a loop that
re-reads `Mod.PrivateGameData` itself, or mutating a field on a table fetched earlier without
reassigning) does not reliably persist. This mirrors the same snapshot behaviour as `game.Orders`
(see the "Orders is a snapshot" comments in commerce/menu UI code) and currently is only implied by
scattered comments across mods - treat it as a hard rule.
