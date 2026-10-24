-- Quoted-string, "{key:value}" table format, hand-encoded for the Placeholder's ModData field.
---@param s string
---@return string
function EncodeQuotedString(s)
    local escaped = string.gsub(s, "\\", "\\\\");
    escaped = string.gsub(escaped, "\"", "\\\"");
    escaped = string.gsub(escaped, "\r", "\\r");
    escaped = string.gsub(escaped, "\n", "\\n");
    return "\"" .. escaped .. "\"";
end

---@param fields table<string, string>
---@return string
function EncodeFlatTable(fields)
    local pairsList = {};
    for key, value in pairs(fields) do
        table.insert(pairsList, EncodeQuotedString(key) .. ":" .. EncodeQuotedString(value));
    end
    return "{" .. table.concat(pairsList, ",") .. "}";
end

---@param placementType string
---@param placementName string | nil
---@param structureID string | nil # Type=Structure only - the raw custom EnumStructureType string ("c|<ModID>|<Name>"), nil for a vanilla structure or a SpecialUnit
---@param originalModData string | nil # Type=SpecialUnit only - the exported live unit's own ModData, restored onto a Built-in Support rebuild
---@return string
function EncodePlaceholderModData(placementType, placementName, structureID, originalModData)
    local fields = { Type = placementType };
    if (placementName ~= nil and placementName ~= "") then
        fields.PlacementName = placementName;
    end
    if (structureID ~= nil and structureID ~= "") then
        fields.StructureID = structureID;
    end
    if (originalModData ~= nil and originalModData ~= "") then
        fields.OriginalModData = originalModData;
    end
    return EncodeFlatTable(fields);
end

---Reads one quoted, backslash-escaped string starting at s[index] (which must be a quote).
---@param s string
---@param index integer
---@return string | nil value, integer | nil nextIndex # nextIndex is just past the closing quote. Both nil if malformed
function DecodeQuotedStringAt(s, index)
    if (string.sub(s, index, index) ~= "\"") then return nil, nil; end

    local chars = {};
    index = index + 1;
    while (index <= #s) do
        local c = string.sub(s, index, index);
        if (c == "\"") then
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

---Decodes a flat, string-keyed, string-valued table previously produced by EncodePlaceholderModData.
---@param s string
---@return table<string, string> | nil
function DecodeFlatTable(s)
    if (string.sub(s, 1, 1) ~= "{" or string.sub(s, #s, #s) ~= "}") then return nil; end

    local fields = {};
    local index = 2;
    while (index < #s) do
        local key, afterKey = DecodeQuotedStringAt(s, index);
        if (key == nil or string.sub(s, afterKey, afterKey) ~= ":") then return nil; end

        local value, afterValue = DecodeQuotedStringAt(s, afterKey + 1);
        if (value == nil) then return nil; end

        fields[key] = value;
        index = afterValue;
        if (string.sub(s, index, index) == ",") then index = index + 1; end
    end
    return fields;
end

---Decodes a Placeholder special unit's own ModData field. Returns nil if modData
---isn't a well-formed encoding.
---@param modData string | nil
---@return string | nil placementType
---@return string | nil placementName
---@return string | nil structureID # Type=Structure only - nil for a vanilla structure or a SpecialUnit
---@return string | nil originalModData # Type=SpecialUnit only - nil unless captured at export time
function DecodePlaceholderModData(modData)
    if (type(modData) ~= "string" or modData == "") then return nil, nil, nil, nil; end

    local fields = DecodeFlatTable(modData);
    if (fields == nil) then return nil, nil, nil, nil; end

    return fields.Type, fields.PlacementName, fields.StructureID, fields.OriginalModData;
end
