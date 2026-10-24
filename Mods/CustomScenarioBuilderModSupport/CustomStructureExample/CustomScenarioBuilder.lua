----------------------------------------------------------------------------------------------------------------------
-- CustomScenarioBuilder.lua
--
-- Generic, copy-paste integration point for the Custom Scenario Builder Mod Support (CSBMS) mod. Copy this
-- file as-is into any mod that wants its own structures/special units to be placeable through CSBMS's Placeholder
-- Placement configuration screen - nothing in this file should need editing.
--
-- CSBMS places a "Placeholder" custom special unit on every territory a game-maker configures there, as a stand-in
-- for a structure or special unit this mod will supply instead.

-- CUSTOM STRUCTURES
-- During the `Server_StartGame` hook, CSBMS will replace structure designated placeholders with the real structures
-- You can discover the territory ids and counts of these structures by calling `FindStructurePlacements`
-- e.g. CustomScenarioBuilder.FindStructurePlacements(standing, "CustomStructureExample");

-- This is recommended to be done in the `Server_StartGame` hook of your mod.
-- Due to a race condition (as CSBMS replaces structure type placeholders in the same hook), you cannot assume
-- that the structures have already been replaced when your mod's `Server_StartGame` hook runs. They will be however.

-- SPECIAL UNITS
-- CSBMS can not spin up your special units for you, so your mod must register a callback to do so.
-- The placeholder units will have all their fields filled out per what was exported. So you can map those fields to your own unit.
-- To register each type of special unit, call `RegisterSpecialUnit` in the `Server_StartGame` hook
-- This will provide a callback for each placeholder of that type, and you can then 
-- call `ReplacePlaceholder` to remove the placeholder and add your own special unit(s) in its place.
-- Lastly, ensure you call `ResolvePlacements` to invoke all the registrations.
--
-- e.g.
--   CustomScenarioBuilder.RegisterSpecialUnit("My Special Unit", function(placeholder, territoryStanding, placementName)
--       CustomScenarioBuilder.ReplacePlaceholder(placeholder, territoryStanding, {
--           AddSpecialUnits = { MyModApplication.BuildMySpecialUnit(placeholder.SpecialUnit) },
--       });
--   end);
--   CustomScenarioBuilder.ResolvePlacements(game, standing);
--
----------------------------------------------------------------------------------------------------------------------

CustomScenarioBuilder = {};

---@enum CustomScenarioBuilderPlacementType
CustomScenarioBuilder.PlacementType = {
    Structure = "Structure",
    SpecialUnit = "SpecialUnit",
};

-- Must match Custom Scenario Builder Mod Support's own special unit name: Placeholder
local PLACEHOLDER_NAME = "Placeholder";

local MOD_DATA_START_TABLE = "{";
local MOD_DATA_END_TABLE = "}";
local MOD_DATA_SEPARATOR = ",";
local MOD_DATA_KEY_VALUE_SEPARATOR = ":";
local MOD_DATA_QUOTE = "\"";

---@class CustomScenarioBuilderPlaceholder # A Placeholder special unit found on the map, standing in for the real thing - as close to a 1:1 stand-in as CSBMS can make it
---@field TerritoryID TerritoryID
---@field SpecialUnit CustomSpecialUnit # The Placeholder unit itself, still on the territory until CustomScenarioBuilder.Replace removes it
---@field ModData string | nil # The real unit's own exported ModData, if CSBMS captured one via a Planning Mode export - nil otherwise

---@class CustomScenarioBuilderReplaceOptions # What to put in a Placeholder's place, here for extendability
---@field AddSpecialUnits SpecialUnit[] | nil # Special unit(s) to add to the territory in the Placeholder's place - omit/empty to just remove the Placeholder with nothing replacing it

---@class CustomScenarioBuilderRegistration # Always SpecialUnit - a Structure Placeholder is never routed through a registration, CSBMS resolves it itself
---@field Name string | nil # nil matches any Placeholder regardless of its PlacementName
---@field Callback fun(placeholder: CustomScenarioBuilderPlaceholder, territoryStanding: TerritoryStanding, placementName: string | nil) # placementName is only useful when Name above is nil - otherwise it's always the same string the mod itself registered with

---@class CustomScenarioBuilderPrivateGameData
---@field CustomScenarioBuilderResolved boolean | nil # Used to ensure this code runs once per game.

---@type CustomScenarioBuilderRegistration[]
local registrations = {};

---Reads one quoted, backslash-escaped string starting at s[index] (which must be MOD_DATA_QUOTE).
---@param s string
---@param index integer
---@return string | nil value, integer | nil nextIndex # nextIndex is just past the closing quote. Both nil if malformed
local function DecodeQuotedStringAt(s, index)
    if (string.sub(s, index, index) ~= MOD_DATA_QUOTE) then return nil, nil; end

    local chars = {};
    index = index + 1;
    while (index <= #s) do
        local c = string.sub(s, index, index);
        if (c == MOD_DATA_QUOTE) then
            return table.concat(chars), index + 1;
        elseif (c == "\\") then
            local escapedChar = string.sub(s, index + 1, index + 1);
            if (escapedChar == "n") then
                table.insert(chars, "\n");
            elseif (escapedChar == "r") then
                table.insert(chars, "\r");
            else
                table.insert(chars, escapedChar); -- \\ -> \, \" -> "
            end
            index = index + 2;
        else
            table.insert(chars, c);
            index = index + 1;
        end
    end
    return nil, nil; -- ran off the end without a closing quote
end

---Decodes a flat, string-keyed, string-valued table previously produced by
---CustomScenarioBuilderModOrchestrator's EncodePlaceholderModData.
---@param s string
---@return table<string, string> | nil
local function DecodeFlatTable(s)
    if (string.sub(s, 1, 1) ~= MOD_DATA_START_TABLE or string.sub(s, #s, #s) ~= MOD_DATA_END_TABLE) then return nil; end

    local fields = {};
    local index = 2;
    while (index < #s) do
        local key, afterKey = DecodeQuotedStringAt(s, index);
        if (key == nil or string.sub(s, afterKey, afterKey) ~= MOD_DATA_KEY_VALUE_SEPARATOR) then return nil; end

        local value, afterValue = DecodeQuotedStringAt(s, afterKey + 1);
        if (value == nil) then return nil; end

        fields[key] = value;
        index = afterValue;
        if (string.sub(s, index, index) == MOD_DATA_SEPARATOR) then index = index + 1; end
    end
    return fields;
end

---Decodes a Placeholder special unit's ModData field. Returns nil if modData isn't a well-formed encoding (so not
---a Placeholder this mod can make sense of).
---@param modData string | nil
---@return CustomScenarioBuilderPlacementType | nil placementType
---@return string | nil placementName
---@return string | nil structureID # Type=Structure only
---@return string | nil originalModData # Type=SpecialUnit only - nil unless CSBMS captured one at export time
local function DecodeModData(modData)
    if (type(modData) ~= "string" or modData == "") then return nil, nil, nil, nil; end

    local fields = DecodeFlatTable(modData);
    if (fields == nil) then return nil, nil, nil, nil; end

    return fields.Type, fields.PlacementName, fields.StructureID, fields.OriginalModData;
end

---Registers a callback to run for every modded Special Unit placed with the given name via the Custom Scneario Builder Mod Support mod.
---Call this from this mod's own Server_StartGame hook, before CustomScenarioBuilder.ResolvePlacements
---@param name string | nil # Matched exactly against the PlacementName the game-maker typed into CSBMS's configuration screen. Pass nil to match every SpecialUnit Placeholder regardless of name
---@param callback fun(placeholder: CustomScenarioBuilderPlaceholder, territoryStanding: TerritoryStanding, placementName: string | nil) # Called once per Placeholder found whose name matches - already known to be meant for this mod, call CustomScenarioBuilder.ReplacePlaceholder
function CustomScenarioBuilder.RegisterSpecialUnit(name, callback)
    table.insert(registrations, { Name = name, Callback = callback });
end

---Removes a resolved SpecialUnit Placeholder from territoryStanding and adds this mod's own special unit(s) in
---its place. Only valid from Server_StartGame
---@param placeholder CustomScenarioBuilderPlaceholder
---@param territoryStanding TerritoryStanding
---@param options CustomScenarioBuilderReplaceOptions
function CustomScenarioBuilder.ReplacePlaceholder(placeholder, territoryStanding, options)
    local remainingSpecialUnits = {};
    for _, specialUnit in ipairs(territoryStanding.NumArmies.SpecialUnits or {}) do
        if (specialUnit.ID ~= placeholder.SpecialUnit.ID) then
            table.insert(remainingSpecialUnits, specialUnit);
        end
    end
    for _, specialUnit in ipairs(options.AddSpecialUnits or {}) do
        table.insert(remainingSpecialUnits, specialUnit);
    end
    territoryStanding.NumArmies = WL.Armies.Create(territoryStanding.NumArmies.NumArmies, remainingSpecialUnits);
end

---Scans the game's starting standing for SpecialUnit Placeholder special units and invokes every registered
---callback whose name matches. Call this once, from this mod's own Server_StartGame hook
---@param game GameServerHook
---@param standing GameStanding
function CustomScenarioBuilder.ResolvePlacements(game, standing)
    local priv = Mod.PrivateGameData or {} --[[@as CustomScenarioBuilderPrivateGameData]];
    if (priv.CustomScenarioBuilderResolved) then return; end

    for territoryID, territoryStanding in pairs(standing.Territories) do
        -- territoryStanding.NumArmies.SpecialUnits is read fresh on every iteration (rather than cached once
        -- before the loop) since CustomScenarioBuilder.Replace reassigns territoryStanding.NumArmies - any earlier
        -- Placeholder resolved on this same territory must not be seen again
        for _, specialUnit in ipairs(territoryStanding.NumArmies.SpecialUnits or {}) do
            if (specialUnit.Name == PLACEHOLDER_NAME) then
                local placementType, placementName, _, originalModData = DecodeModData(specialUnit.ModData);
                if (placementType == CustomScenarioBuilder.PlacementType.SpecialUnit) then
                    ---@type CustomScenarioBuilderPlaceholder
                    local placeholder = {
                        TerritoryID = territoryID,
                        SpecialUnit = specialUnit,
                        ModData = originalModData,
                    };
                    for _, registration in ipairs(registrations) do
                        if (registration.Name == nil or registration.Name == placementName) then
                            registration.Callback(placeholder, territoryStanding, placementName);
                        end
                    end
                end
            end
        end
    end

    priv.CustomScenarioBuilderResolved = true;
    Mod.PrivateGameData = priv;
end

---Finds every territory where a structure this mod supplies is present - as the realised structure, or
---as a still-unresolved Placeholder standing in for it, whichever is there 
---(mod execution order is not guaranteeable and both use the same hook, so we check both)
---@param standing GameStanding
---@param structureName string # the exact name this mod passes to WL.StructureType.Custom(name) for its own structure
---@return table<TerritoryID, integer> # TerritoryID -> how many of this structure (real or still a Placeholder) are on it
function CustomScenarioBuilder.FindStructurePlacements(standing, structureName)
    local structureIDString = tostring(WL.StructureType.Custom(structureName));

    local placements = {};
    for territoryID, territoryStanding in pairs(standing.Territories) do
        local count = 0;

        for existingStructureID, structureCount in pairs(territoryStanding.Structures or {}) do
            if (tostring(existingStructureID) == structureIDString) then
                count = count + structureCount;
            end
        end

        for _, specialUnit in ipairs(territoryStanding.NumArmies.SpecialUnits or {}) do
            if (specialUnit.Name == PLACEHOLDER_NAME) then
                local placementType, _, placeholderStructureID = DecodeModData(specialUnit.ModData);
                if (placementType == CustomScenarioBuilder.PlacementType.Structure and placeholderStructureID == structureIDString) then
                    count = count + 1;
                end
            end
        end

        if (count > 0) then
            placements[territoryID] = count;
        end
    end

    return placements;
end
