require("IO.IO");

---@enum EnumToken
IO.TokenType = {
    START_STRING = "\"";
    END_STRING = "\"";
    START_TABLE = "{";
    END_TABLE = "}";
    START_ARRAY = "[";
    END_ARRAY = "]";
    SEPARATOR = ",";
    KEY_VALUE_SEPARATOR = ":";
    START_MESSAGE = "(";
    END_MESSAGE = ")";
}

IO.Util = {};

---Returns true if the table is empty, false otherwise
---@param t table
---@return boolean
function IO.Util.TableIsEmpty(t)
    for _, _ in pairs(t) do
        return false;
    end
    return true;
end

---Returns true if the passed table is an array, false otherwise
---@param t table
---@return boolean
function IO.Util.IsArray(t)
    local keys = {};
    for k, _ in pairs(t) do
        if type(k) ~= "number" then return false; end
        table.insert(keys, k);
    end
    table.sort(keys);
    for k, v in pairs(keys) do
        if k ~= v then return false; end
    end
    return true;
end