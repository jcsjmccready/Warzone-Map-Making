BuiltInSupport = {};

---A special unit CSBMS itself knows how to build - no integration from the other mod needed, since CSBMS already
---holds a copy of its image and knows its exact stats.
---@class BuiltInSupportUnit
---@field ModName string # the mod this unit's card/special unit normally comes from
---@field ModAuthor string
---@field ModID integer # the source mod's Warzone workshop mod ID
---@field Build fun(ownerID: PlayerID): CustomSpecialUnit

---@type table<string, BuiltInSupportUnit> # PlacementName -> how to build it
BuiltInSupport.Units = {};

---Registers a special unit CSBMS can build and place itself when resolving a SpecialUnit Placeholder with this
---exact PlacementName - unlike a mod integrating via CustomScenarioBuilder.lua, that mod's own Server_StartGame
---hook doesn't need to Register/ReplacePlaceholder for this unit at all, CSBMS handles it entirely on its own.
---@param name string # exact PlacementName to match (what a game-maker types into the Placement Name field)
---@param modName string
---@param modAuthor string
---@param modID integer
---@param build fun(ownerID: PlayerID): CustomSpecialUnit
function BuiltInSupport.Register(name, modName, modAuthor, modID, build)
    BuiltInSupport.Units[name] = { ModName = modName, ModAuthor = modAuthor, ModID = modID, Build = build };
end

---@param name string | nil
---@return BuiltInSupportUnit | nil
function BuiltInSupport.Find(name)
    if (name == nil) then return nil; end
    return BuiltInSupport.Units[name];
end

---@return { Name: string, ModName: string, ModAuthor: string, ModID: integer }[] # sorted alphabetically by Name
function BuiltInSupport.ListUnits()
    local list = {};
    for name, unit in pairs(BuiltInSupport.Units) do
        table.insert(list, { Name = name, ModName = unit.ModName, ModAuthor = unit.ModAuthor, ModID = unit.ModID });
    end
    table.sort(list, function(a, b) return string.lower(a.Name) < string.lower(b.Name); end);
    return list;
end

-- Every mod CSBMS has built-in support for is required here, not by each file that calls BuiltInSupport.Find/
-- PlacementHasBuiltInSupport - so adding a new one is a single line added to this file, not a new require
-- sprinkled across every consumer. Must come after Register is defined above - each of these calls it immediately.
require("Application.BuiltInSupport.Diplomat");
