# Application / Endpoints / Interface layering

For any mod that exposes actions to other mods (or just wants its hook-handling logic kept out of
the hook files themselves), split the mod's own logic into three files on top of the `IO/` package
(see `shared-code.md`):

- **`Interface.lua`** - annotation-only. `---@enum` for the action names and `---@class ... Dto`
  definitions for each action's expected data shape. No functions, no logic - just the type
  definitions other files annotate against. (Today this lives inline at the top of `Api.lua` in
  `PointsofInterest`/`DeadManSwitch`; pull it out into its own file in new mods.)
- **`Application.lua`** - the actual business logic (`<ModName>Application.<Action>(...)`), callable
  both from this mod's own hooks (`Server_AdvanceTurn_Order`, `Client_SaveConfigureUI`, etc.) and from
  the endpoints layer below. Knows nothing about ModAuth or DTOs - just takes plain arguments and
  does the work (creating orders, reading/writing `Mod.PrivateGameData`/`Mod.PublicGameData`).
- **`Api.lua`** - the endpoints layer. Creates one `IO.ApiBase.New()` instance, and for each action
  registers a handler that validates the incoming DTO's fields (`api.ValidateFields`) then delegates
  into the matching `Application` function. `Server_AdvanceTurn_Order` routes incoming orders through
  this instance's `HandleOrder` before anything else.

Reference example: `PointsofInterest` (`Application.lua`, `Api.lua`) and `DeadManSwitch`
(`Application.lua`, `Api.lua`, `Actions/*.lua`) - note their DTO annotations currently live at the
top of `Api.lua` rather than in a separate `Interface.lua`; new mods should split that out.
