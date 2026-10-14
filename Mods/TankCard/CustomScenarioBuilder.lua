----------------------------------------------------------------------------------------------------------------------
-- CustomScenarioBuilder.lua
--
-- Generic, copy-paste integration point for the Custom Scenario Builder Mod Orchestrator (CSBMO) mod. Copy this
-- file as-is into any mod that wants its own structures/special units to be placeable through CSBMO's Placeholder
-- Placement configuration screen - nothing in this file should need editing per mod, same convention as IO/ModAuth.lua.
--
-- CSBMO places a "Placeholder" custom special unit on every territory a game-maker configures there, as a stand-in
-- for a structure or special unit this mod will supply instead. Mod.* storages (Settings/PrivateGameData/
-- PublicGameData) are private per mod, so CSBMO has no way to hand this mod data directly - instead, each
-- Placeholder's own ModData field (readable by any mod, since it lives on the shared game object, not in CSBMO's
-- storage) carries what the game-maker asked for: a Type ("Structure" or "SpecialUnit") and the free-text
-- PlacementName they typed into CSBMO's configuration screen. This mod decides relevance itself, by checking
-- PlacementName in its own registered callback.
--
-- Resolution happens in Server_StartGame, against the standing directly (no addNewOrder/order involved), so the
-- real structure/special unit is already there on turn 0 - the same reasoning PointsofInterest's own
-- PlaceInitialPointsOfInterest uses for mutating TerritoryStanding.Structures directly at this stage.
--
-- Usage, from this mod's own Server_StartGame hook (call both of these there, Register right before Resolve -
-- not at file-load time: this mod's own files only run their top-level code when something actually requires
-- them, so a Register sitting in some other file's top level only takes effect if Server_StartGame happens to
-- require that file too. Calling it explicitly here removes that trap entirely):
--
--   CustomScenarioBuilder.Register(CustomScenarioBuilder.PlacementType.Structure, "Dead Man's Switch", function(placeholder, territoryStanding)
--       CustomScenarioBuilder.ReplacePlaceholder(placeholder, territoryStanding, {
--           AddStructures = { [WL.StructureType.Custom("Dead Man's Switch")] = 1 },
--       });
--   end);
--   CustomScenarioBuilder.ResolvePlacements(game, standing);
--
-- Pass nil for name instead of a specific one to match every Placeholder of that Type, regardless of name.
----------------------------------------------------------------------------------------------------------------------

CustomScenarioBuilder = {};

---@enum CustomScenarioBuilderPlacementType
CustomScenarioBuilder.PlacementType = {
    Structure = "Structure",
    SpecialUnit = "SpecialUnit",
};

-- Must match CustomScenarioBuilderModOrchestrator's own PLACEHOLDER_NAME exactly - this is the contract between
-- that mod and this file.
local PLACEHOLDER_NAME = "Placeholder";

-- ModData is a flat, string-keyed, string-valued table written out as "{"key":"value",...}" - the same quoted-
-- string, brace/colon/comma table format the IO package's IO.Writer/IO.Reader use elsewhere in this codebase, but
-- written out by hand here (and in CustomScenarioBuilderModOrchestrator's own EncodePlaceholderModData) so a mod
-- carrying this file doesn't also have to carry the whole IO package just to read two string fields. Both sides
-- must stay in sync with this exact format.
local MOD_DATA_START_TABLE = "{";
local MOD_DATA_END_TABLE = "}";
local MOD_DATA_SEPARATOR = ",";
local MOD_DATA_KEY_VALUE_SEPARATOR = ":";
local MOD_DATA_QUOTE = "\"";

---@class CustomScenarioBuilderPlaceholder # A Placeholder special unit found on the map, decoded and ready to be matched/replaced
---@field Type CustomScenarioBuilderPlacementType # What the game-maker said this placeholder should eventually become
---@field PlacementName string | nil # The free-text name the game-maker typed into CSBMO's configuration screen - check this against this mod's own structure/special unit name to decide whether a given Placeholder is meant for this mod
---@field TerritoryID TerritoryID
---@field SpecialUnit CustomSpecialUnit # The Placeholder unit itself, still on the territory until CustomScenarioBuilder.Replace removes it

---@class CustomScenarioBuilderReplaceOptions # What to put in a Placeholder's place - at least one of these should be set
---@field AddSpecialUnits SpecialUnit[] | nil # Special unit(s) to add to the territory in the Placeholder's place
---@field AddStructures table<EnumStructureType, integer> | nil # Structure(s) to add to the territory in the Placeholder's place, keyed by WL.StructureType.Custom(...) (or a vanilla EnumStructureType), each value the count to add

---@class CustomScenarioBuilderRegistration
---@field Type CustomScenarioBuilderPlacementType
---@field Name string | nil # nil matches a Placeholder of this Type regardless of its PlacementName
---@field Callback fun(placeholder: CustomScenarioBuilderPlaceholder, territoryStanding: TerritoryStanding)

---@class CustomScenarioBuilderPrivateGameData
---@field CustomScenarioBuilderResolved boolean | nil # Used to ensure this code runs once per game.

---@type CustomScenarioBuilderRegistration[]
local registrations = {};

---Reads one quoted, backslash-escaped string starting at s[index] (which must be MOD_DATA_QUOTE).
---@param s string
---@param index integer
---@return string | nil value, integer | nil nextIndex # nextIndex is just past the closing quote. Both nil if malformed
local function DecodeModDataString(s, index)
    if (string.sub(s, index, index) ~= MOD_DATA_QUOTE) then return nil, nil; end

    local chars = {};
    local escaped = false;
    index = index + 1;
    while (index <= #s) do
        local c = string.sub(s, index, index);
        if (c == MOD_DATA_QUOTE and not escaped) then
            return table.concat(chars), index + 1;
        end
        escaped = (c == "\\") and not escaped;
        table.insert(chars, c);
        index = index + 1;
    end
    return nil, nil; -- ran off the end without a closing quote
end

---Decodes a flat, string-keyed, string-valued table previously produced by
---CustomScenarioBuilderModOrchestrator's EncodePlaceholderModData - see this file's header for the shared format.
---@param s string
---@return table<string, string> | nil
local function DecodeModDataTable(s)
    if (string.sub(s, 1, 1) ~= MOD_DATA_START_TABLE or string.sub(s, #s, #s) ~= MOD_DATA_END_TABLE) then return nil; end

    local fields = {};
    local index = 2;
    while (index < #s) do
        local key, afterKey = DecodeModDataString(s, index);
        if (key == nil or string.sub(s, afterKey, afterKey) ~= MOD_DATA_KEY_VALUE_SEPARATOR) then return nil; end

        local value, afterValue = DecodeModDataString(s, afterKey + 1);
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
local function DecodeModData(modData)
    if (type(modData) ~= "string" or modData == "") then return nil, nil; end

    local fields = DecodeModDataTable(modData);
    if (fields == nil) then return nil, nil; end

    return fields.Type, fields.PlacementName;
end

---Registers a callback to run for every Placeholder CSBMO placed with the given Type and name. Call this from
---this mod's own Server_StartGame hook, right before CustomScenarioBuilder.ResolvePlacements - not at file-load
---time: registrations only take effect for hooks that actually require the file doing the registering, which is
---easy to get wrong silently (no error, registrations list is just empty).
---@param placementType CustomScenarioBuilderPlacementType
---@param name string | nil # Matched exactly against the PlacementName the game-maker typed into CSBMO's configuration screen. Pass nil to match every Placeholder of this Type regardless of name
---@param callback fun(placeholder: CustomScenarioBuilderPlaceholder, territoryStanding: TerritoryStanding) # Called once per Placeholder found whose Type and name match - already known to be meant for this mod, call CustomScenarioBuilder.Replace
function CustomScenarioBuilder.Register(placementType, name, callback)
    table.insert(registrations, { Type = placementType, Name = name, Callback = callback });
end

---Removes a resolved Placeholder from territoryStanding and adds this mod's own structure and/or special unit in
---its place. Mutates territoryStanding directly (no order involved) - only valid from Server_StartGame, before the
---game's first turn has actually started.
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

    local structures = {};
    for structureID, count in pairs(territoryStanding.Structures or {}) do
        structures[structureID] = count;
    end
    for structureID, addedCount in pairs(options.AddStructures or {}) do
        structures[structureID] = (structures[structureID] or 0) + addedCount;
    end
    territoryStanding.Structures = structures;
end

---Scans the game's starting standing for Placeholder special units and invokes every registered callback whose
---Type matches. Call this once, from this mod's own Server_StartGame hook, before the game's first turn starts.
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
                local placementType, placementName = DecodeModData(specialUnit.ModData);
                if (placementType ~= nil) then
                    ---@type CustomScenarioBuilderPlaceholder
                    local placeholder = {
                        Type = placementType,
                        PlacementName = placementName,
                        TerritoryID = territoryID,
                        SpecialUnit = specialUnit,
                    };
                    for _, registration in ipairs(registrations) do
                        if (registration.Type == placementType and (registration.Name == nil or registration.Name == placementName)) then
                            registration.Callback(placeholder, territoryStanding);
                        end
                    end
                end
            end
        end
    end

    priv.CustomScenarioBuilderResolved = true;
    Mod.PrivateGameData = priv;
end
