require("IO.Util");

local Writer = {};

---Returns the table or array stringified
---@param t table|any[]
---@return string
function Writer.TableOrArray(t)
    if IO.Util.TableIsEmpty(t) or not IO.Util.IsArray(t) then
        return Writer.WriteObject(t);
    else
        return Writer.WriteArray(t);
    end
end

function Writer.WriteString(s)
    return "\"" .. string.gsub(string.gsub(tostring(s), "\\", "\\\\"), "\"", "\\\"") .. "\"";
end

local lookupTable = {
    string = Writer.WriteString;
    number = tostring;
    boolean = tostring;
    table = Writer.TableOrArray;
};

---Returns the stringified key-value pair
---@param key string|number
---@param value any
---@return string
function Writer.WritePair(key, value)
    return string.format("%s%s%s", key, IO.TokenType.KEY_VALUE_SEPARATOR, value);
end

---Returns the pairs concatenated to one string
---@param ... string
---@return string
function Writer.WritePairs(...)
    return table.concat({...}, IO.TokenType.SEPARATOR);
end

---Returns the object stringified
---@param obj table
---@return string
function Writer.WriteObject(obj)
    local l = {};
    for key, value in pairs(obj) do
        table.insert(l, Writer.WritePair(lookupTable[type(key)](key), lookupTable[type(value)](value)));
    end
    return IO.TokenType.START_TABLE .. Writer.WritePairs(table.unpack(l)) .. IO.TokenType.END_TABLE;
end

---Returns the array stringified
---@param arr any[]
---@return string
function Writer.WriteArray(arr)
    local l = {};
    for _, value in pairs(arr) do
        table.insert(l, lookupTable[type(value)](value));
    end
    return IO.TokenType.START_ARRAY .. Writer.WritePairs(table.unpack(l)) .. IO.TokenType.END_ARRAY;
end

IO.Writer = {};

---Returns the message turned into a string
---@param message table | any[]
---@return string
function IO.Writer.Write(message)
    return IO.TokenType.START_MESSAGE ..
        Writer.TableOrArray(message) ..
        IO.TokenType.END_MESSAGE;
end