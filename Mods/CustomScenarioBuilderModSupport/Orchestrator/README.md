# Custom Scenario Builder Mod Support (CSBMS)

## Purpose

Warzone's Custom Scenario builder lets lobby creators specify a start of game setup, but has no way to place a
*modded* structure or special unit at game start. CSBMS fills that gap: a game-maker configures a list of
territory/placement pairs (vanilla structure, modded structure, or modded special unit) in this mod's settings,
and CSBMS places them at the start of the game if using a Custom Scenario distribution.

**Only works with automatic territory distribution.** For a manual-distribution Custom Scenario game (where
players pick their own starting slot), the engine never carries CSBMS's placements through to the actual game -
nothing gets placed.

## How it works

At lobby creation, CSBMS places a `Placeholder` special unit on each configured territory - a stand-in for whatever was actually requested, since there's no way to create a modded special unit for a different mod. The Placeholder encodes what it's meant to become (`Type`, `PlacementName`, and for a modded structure its `StructureID`) in its own `ModData` field.

- **Vanilla/modded structures**: CSBMS resolves these itself directly (as it is possible), replacing the Placeholder with the real structure before any other mod's hooks run.
- **Special units**: CSBMS can only resolve a special unit itself if it has **Built-in Support** registered for
  that exact name (`Application/BuiltInSupport/`) - a small library of special units from mods that no longer
  receive updates. Otherwise, the mod that owns that special unit must integrate via `CustomScenarioBuilder.lua`
  (see Usage below) to replace the Placeholder with its own unit.

Two other pieces round out the mod:

- **Planning Mode**: lay out placements visually in a test game, export the result as text, and paste it into
  this mod's settings
- **In-game mod menu**: build (vanilla/built-in support), move, clone, or delete a structure/special unit directly on the map while Planning Mode is active.

## Usage (for mod developers)

If your mod has its own structure or special unit that a game-maker should be able to place via CSBMS, copy
`CustomScenarioBuilder.lua` (found in the parent directory to this) as-is into your mod (it's a generic, copy-paste integration file - nothing in it needs editing per mod). Its own header comment documents the contract in full:

- **Structures**: nothing to register - CSBMS resolves these on its own. Use
  `CustomScenarioBuilder.FindStructurePlacements` in `Server_StartGame` if your mod needs to know where its structures ended up. FYI, due to a race condition (the order of mods executing Server_StartGame is not knowable), the structures may still be in placeholder form. This method returns the value as if they have finished the replacement logic CSBMS carries out in its own `Server_StartGame`
- **Special units**: In `Server_StartGame` call `CustomScenarioBuilder.RegisterSpecialUnit(name, callback)` per special unit you wish CBSMS to support, then
  `CustomScenarioBuilder.ResolvePlacements(game, standing)` once. Your
  callback replaces the Placeholder with your own unit via `CustomScenarioBuilder.ReplacePlaceholder` If exported from a game using planning mode, the placeholders special unit fields will be the same as in the game.

For a working example of each, see the sibling example mods in this folder's parent directory:
- **`CustomStructureExample`** - a custom structure.
- **`SpecialUnitExample`** - a custom special unit
