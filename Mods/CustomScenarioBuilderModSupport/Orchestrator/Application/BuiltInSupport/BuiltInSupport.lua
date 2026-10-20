BuiltInSupport = {};

---A special unit CSBMS itself knows how to build
---@class BuiltInSupportUnit
---@field ModName string # the mod this unit's card/special unit normally comes from
---@field ModAuthor string
---@field ModID integer # the source mod's Warzone workshop mod ID
---@field ImageFilename string
---@field Fields table<string, string> # SPECIAL_UNIT_FIELD_DESCRIPTORS keys, stringified - also previewed (disabled) in the Edit view when added via Add from Template

---@type table<string, BuiltInSupportUnit> # PlacementName -> its data
BuiltInSupport.Units = {};

---Registers a special unit CSBMS can build and place itself when resolving a SpecialUnit Placeholder with this
---exact PlacementName - unlike a mod integrating via CustomScenarioBuilder.lua, that mod's own Server_StartGame
---hook doesn't need to Register/ReplacePlaceholder for this unit at all, CSBMS handles it entirely on its own.
---@param name string # exact PlacementName to match (what a game-maker types into the Placement Name field)
---@param modName string
---@param modAuthor string
---@param modID integer
---@param imageFilename string
---@param fields table<string, string> # SPECIAL_UNIT_FIELD_DESCRIPTORS keys, stringified
function BuiltInSupport.Register(name, modName, modAuthor, modID, imageFilename, fields)
    BuiltInSupport.Units[name] = { ModName = modName, ModAuthor = modAuthor, ModID = modID, ImageFilename = imageFilename, Fields = fields };
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

---Builds the actual CustomSpecialUnit for a registered unit, from its stored Fields
---@param name string
---@param ownerID PlayerID
---@param originalModData string | nil # a previously-exported live unit's own ModData, restored onto this rebuild
---@return CustomSpecialUnit
function BuiltInSupport.Build(name, ownerID, originalModData)
    local unit = BuiltInSupport.Units[name];
    local builder = WL.CustomSpecialUnitBuilder.Create(ownerID);
    builder.Name = name;
    builder.ImageFilename = unit.ImageFilename;
    ApplySpecialUnitFields(builder, unit.Fields);
    if (originalModData ~= nil and originalModData ~= "") then
        builder.ModData = originalModData;
    end
    return builder.Build();
end

-- Every mod CSBMS has built-in support for is required here
require("Application.BuiltInSupport.Diplomat");
require("Application.BuiltInSupport.ArmyRecruiter");
require("Application.BuiltInSupport.Capitalist");
require("Application.BuiltInSupport.ConstructionWorker");
require("Application.BuiltInSupport.Tank");
require("Application.BuiltInSupport.CaptureTheFlag");
