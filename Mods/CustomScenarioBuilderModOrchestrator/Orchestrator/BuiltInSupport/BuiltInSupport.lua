BuiltInSupport = {};

---A special unit CSBMO itself knows how to build - no integration from the other mod needed, since CSBMO already
---holds a copy of its image (see SpecialUnitImages) and knows its exact stats.
---@class BuiltInSupportUnit
---@field Build fun(ownerID: PlayerID): CustomSpecialUnit

---@type table<string, BuiltInSupportUnit> # PlacementName -> how to build it
BuiltInSupport.Units = {};

---Registers a special unit CSBMO can build and place itself when resolving a SpecialUnit Placeholder with this
---exact PlacementName - unlike a mod integrating via CustomScenarioBuilder.lua, that mod's own Server_StartGame
---hook doesn't need to Register/ReplacePlaceholder for this unit at all, CSBMO handles it entirely on its own.
---@param name string # exact PlacementName to match (what a game-maker types into the Placement Name field)
---@param build fun(ownerID: PlayerID): CustomSpecialUnit
function BuiltInSupport.Register(name, build)
    BuiltInSupport.Units[name] = { Build = build };
end

---@param name string | nil
---@return BuiltInSupportUnit | nil
function BuiltInSupport.Find(name)
    if (name == nil) then return nil; end
    return BuiltInSupport.Units[name];
end

-- Every mod CSBMO has built-in support for is required here, not by each file that calls BuiltInSupport.Find/
-- PlacementHasBuiltInSupport - so adding a new one is a single line added to this file, not a new require
-- sprinkled across every consumer. Must come after Register is defined above - each of these calls it immediately.
require("BuiltInSupport.Diplomat");
