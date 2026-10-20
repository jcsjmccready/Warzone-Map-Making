require("Application.Utilities");
require("Application.PlaceholderModData");

-- Planning Mode's export format - one JSON-like line per territory, e.g. {"TerritoryName":"Meowth","Values":[...]}.
---@param value string | table[] # a plain string, or an array of flat string-keyed, string-valued tables
---@return string
local function EncodeExportValue(value)
    if (type(value) == "string") then
        return EncodeQuotedString(value);
    end

    local items = {};
    for _, item in ipairs(value) do
        table.insert(items, EncodeFlatTable(item));
    end
    return "[" .. table.concat(items, ",") .. "]";
end

---@param fields table<string, string | table[]>
---@return string
local function EncodeExportObject(fields)
    local pairsList = {};
    for key, value in pairs(fields) do
        table.insert(pairsList, EncodeQuotedString(key) .. ":" .. EncodeExportValue(value));
    end
    return "{" .. table.concat(pairsList, ",") .. "}";
end

local DecodeExportValueAt, DecodeExportObjectAt, DecodeExportArrayAt; -- forward declared, these mutually recurse

---@param s string
---@param index integer
---@return string | table[] | nil value, integer | nil nextIndex
function DecodeExportValueAt(s, index)
    local c = string.sub(s, index, index);
    if (c == "\"") then return DecodeQuotedStringAt(s, index); end
    if (c == "[") then return DecodeExportArrayAt(s, index); end
    return nil, nil;
end

---@param s string
---@param index integer
---@return table<string, string | table[]> | nil value, integer | nil nextIndex
function DecodeExportObjectAt(s, index)
    if (string.sub(s, index, index) ~= "{") then return nil, nil; end
    index = index + 1;

    local fields = {};
    if (string.sub(s, index, index) == "}") then return fields, index + 1; end

    while (true) do
        local key, afterKey = DecodeQuotedStringAt(s, index);
        if (key == nil or string.sub(s, afterKey, afterKey) ~= ":") then return nil, nil; end

        local value, afterValue = DecodeExportValueAt(s, afterKey + 1);
        if (value == nil) then return nil, nil; end

        fields[key] = value;
        index = afterValue;
        if (string.sub(s, index, index) == ",") then
            index = index + 1;
        elseif (string.sub(s, index, index) == "}") then
            return fields, index + 1;
        else
            return nil, nil;
        end
    end
end

---@param s string
---@param index integer
---@return table[] | nil value, integer | nil nextIndex
function DecodeExportArrayAt(s, index)
    if (string.sub(s, index, index) ~= "[") then return nil, nil; end
    index = index + 1;

    local items = {};
    if (string.sub(s, index, index) == "]") then return items, index + 1; end

    while (true) do
        local item, afterItem = DecodeExportObjectAt(s, index);
        if (item == nil) then return nil, nil; end

        table.insert(items, item);
        index = afterItem;
        if (string.sub(s, index, index) == ",") then
            index = index + 1;
        elseif (string.sub(s, index, index) == "]") then
            return items, index + 1;
        else
            return nil, nil;
        end
    end
end

---Serializes a list of placements into a pasteable string for Planning Mode - one line per distinct TerritoryName.
---@param placements PlaceholderPlacementSetting[]
---@return string
function SerializePlacementData(placements)
    local order = {}; -- TerritoryName, in first-seen order
    local byTerritory = {}; -- TerritoryName -> { Type: "S" | "U", Name: string }[]
    for _, placement in ipairs(placements) do
        local group = byTerritory[placement.TerritoryName];
        if (group == nil) then
            group = {};
            byTerritory[placement.TerritoryName] = group;
            table.insert(order, placement.TerritoryName);
        end

        local placementType = placement.Type or DEFAULT_PLACEMENT_TYPE;
        local valueEntry = { Type = (placementType == "Structure") and "S" or "U", Name = placement.PlacementName or "" };
        for key, value in pairs(placement.SpecialUnitFields or {}) do
            valueEntry[key] = value;
        end
        table.insert(group, valueEntry);
    end

    local lines = {};
    for _, territoryName in ipairs(order) do
        table.insert(lines, EncodeExportObject({ TerritoryName = territoryName, Values = byTerritory[territoryName] }));
    end
    return table.concat(lines, "\n");
end

---Parses a string produced by SerializePlacementData back into a list of placements. Returns nil if any
---non-blank line isn't well-formed.
---@param text string
---@return PlaceholderPlacementSetting[] | nil
function DeserializePlacementData(text)
    local placements = {};
    for _, line in ipairs(SplitLines(text or "")) do
        if (line ~= "") then
            local object, nextIndex = DecodeExportObjectAt(line, 1);
            if (object == nil or nextIndex ~= #line + 1) then return nil; end

            local territoryName = object.TerritoryName;
            local values = object.Values;
            if (type(territoryName) ~= "string" or territoryName == "" or type(values) ~= "table") then return nil; end

            for _, value in ipairs(values) do
                local typeChar = value.Type;
                local name = value.Name;
                if ((typeChar ~= "S" and typeChar ~= "U") or type(name) ~= "string") then return nil; end

                local placementName = name;
                local structureID = nil;
                local specialUnitFields = nil;
                if (typeChar == "S") then
                    local customName = CustomStructureToDisplayName(name);
                    if (customName ~= nil) then
                        structureID = name;
                        placementName = customName;
                    end
                else
                    specialUnitFields = {};
                    for _, descriptor in ipairs(SPECIAL_UNIT_FIELD_DESCRIPTORS) do
                        local fieldValue = value[descriptor.Key];
                        if (fieldValue ~= nil) then specialUnitFields[descriptor.Key] = tostring(fieldValue); end
                    end
                end

                table.insert(placements, {
                    Type = (typeChar == "S") and "Structure" or "SpecialUnit",
                    TerritoryName = territoryName,
                    PlacementName = (placementName ~= "") and placementName or nil,
                    StructureID = structureID,
                    SpecialUnitFields = specialUnitFields,
                });
            end
        end
    end
    return placements;
end
