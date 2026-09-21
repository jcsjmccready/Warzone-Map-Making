require("IO.Util");

local Reader = {
    Index = 1;
    String = "";
    Length = 0;
};

function Reader.ReadString()
    if not Reader.ReadNextIfEqual(IO.TokenType.START_STRING) then
        Reader.CreateError("Start of string expected, got " .. Reader.GetNext(), "Reader.ReadString");
        return;
    end

    local s = "";
    local escaped = false;
    local safeBreak = false;

    while Reader.IsValid() do
        local c = Reader.GetNext();        -- Get next character

        if c == IO.TokenType.END_STRING and not escaped then       -- Not escaped? Break out of the loop
            safeBreak = true;
            Reader.ReadNextSymbol();
            break;
        end

        if c == "\\" then
            escaped = not escaped;     -- Set escaped
        else
            escaped = false;        -- Reset escaped
        end
        
        s = s .. c;             -- Append and read the character
        Reader.ReadNextSymbol();
    end

    if safeBreak then
        return s;
    else
        Reader.CreateError("Unsafe loop stoppage", "Reader.ReadString");
    end
end

---Reads an object and turns it into a table
---@return table | nil
function Reader.ReadTable()
    if not Reader.ReadNextIfEqual(IO.TokenType.START_TABLE) then
        Reader.CreateError("Start of table expected, got " .. Reader.GetNext(), "Reader.ReadTable");
        return;
    end

    local t = {};

    if Reader.GetNext() ~= IO.TokenType.END_TABLE then
        while Reader.IsValid() do
            local key, value = Reader.ReadPair();
    
            if key == nil then
                Reader.CreateError("Key value was nil", "Reader.ReadTable");
                return;
            end
    
            if value == nil then
                Reader.CreateError("Value was nil", "Reader.ReadTable");
                return;
            end
            
            if t[key] ~= nil then
                Reader.CreateError("Duplicate keys found: " .. key, "Reader.ReadTable");
                return;
            end
    
            t[key] = value;

            if not Reader.ReadNextIfEqual(IO.TokenType.SEPARATOR) then
                break;
            end
        end
    end

    if not Reader.ReadNextIfEqual(IO.TokenType.END_TABLE) then
        Reader.CreateError("End of table expected, got " .. Reader.GetNext(), "Reader.ReadTable");
        return;
    end

    return t;
end

function Reader.ReadArray(f)
    if not Reader.ReadNextIfEqual(IO.TokenType.START_ARRAY) then
        Reader.CreateError("Start of array expected, got " .. Reader.GetNext(), "Reader.ReadArray");
        return;
    end

    local l = {};

    if Reader.GetNext() ~= IO.TokenType.END_ARRAY then
        while Reader.IsValid() do
            local e = Reader.ReadNext();

            if e == nil then
                Reader.CreateError(string.format("Array element #%d is nil", #l), "Reader.ReadArray");
                return;
            end

            table.insert(l, e);

            if not Reader.ReadNextIfEqual(IO.TokenType.SEPARATOR) then
                break;
            end
        end
    end

    if not Reader.ReadNextIfEqual(IO.TokenType.END_ARRAY) then
        Reader.CreateError("End of array expected, got " .. Reader.GetNext(), "Reader.ReadArray");
        return;
    end

    return l;
end

function Reader.ReadBoolean()
    if Reader.GetNextToken("true") == "true" then
        Reader.ReadNextToken("true");
        return true;
    elseif Reader.GetNextToken("false") == "false" then
        Reader.ReadNextToken("false");
        return false;
    else
        Reader.CreateError("Expected 'true' or 'false', first character is " .. Reader.GetNext(), "Reader.ReadBoolean");
        return;
    end
end

local lookupTable = {
    [IO.TokenType.START_STRING] = Reader.ReadString;
    [IO.TokenType.START_TABLE] = Reader.ReadTable;
    [IO.TokenType.START_ARRAY] = Reader.ReadArray;
    t = Reader.ReadBoolean;
    f = Reader.ReadBoolean;
}

function Reader.GetNext()
    if Reader.Index > Reader.Length then
        Reader.CreateError("Index out of range", "getNext");
        return "";
    end
    return string.sub(Reader.String, Reader.Index, Reader.Index);
end

function Reader.ReadNextSymbol()
    Reader.Index = Reader.Index + 1;
end

---When the next symbol is equal to the passed symbol, consumes the symbol and returns true. Otherwise it will just return false
---@param c string
---@return boolean
function Reader.ReadNextIfEqual(c)
    if Reader.GetNext() == c then
        Reader.Index = Reader.Index + 1;
        return true;
    end
    return false;
end

function Reader.GetNextToken(t)
    local len = #t - 1;
    if Reader.Index + len > Reader.Length then
        Reader.CreateError("Index out of range", "getNextToken");
        return "";
    end
    return string.sub(Reader.String, Reader.Index, Reader.Index + len);
end

function Reader.ReadNextToken(t)
    Reader.Index = Reader.Index + #t;
end

function Reader.IsValid()
    return Reader.Error == nil;
end

---Reads the next part of the string
---@return boolean|number|string|table|nil
function Reader.ReadNext()
    return (lookupTable[Reader.GetNext()] or Reader.ReadNumber)();
end

function Reader.ReadPair()
    local key = Reader.ReadNext();

    if key == nil then
        Reader.CreateError("Key value was nil", "Reader.ReadPair");
        return;
    end

    if not Reader.ReadNextIfEqual(IO.TokenType.KEY_VALUE_SEPARATOR) then
        Reader.CreateError("Key-value separator expected, got " .. Reader.GetNext(), "Reader.ReadPair");
        return;
    end

    return key, Reader.ReadNext();
end

function Reader.ReadNumber()
    local s = "";
    local decimal = false;
    
    while Reader.IsValid do
        local c = Reader.GetNext();

        -- 48 = '0' | 57 = '9'
        if string.byte(c) >= 48 and string.byte(c) <= 57 then
            s = s .. c;
        elseif c == "." then
            if decimal then     -- Can not have multiple decimal points
                Reader.CreateError("Second decimal point found", "Reader.ReadNumber");
                return;
            end
            
            decimal = true;
            s = s .. c;
        elseif c == "-" then
            s = s .. c;
        else
            break;
        end

        Reader.ReadNextSymbol();
    end

    local n = tonumber(s);
    if n ~= nil then
        return n;
    else
        Reader.CreateError(string.format("Could not convert '%s' to a number", s), "Reader.ReadNumber");
        return;
    end
end

function Reader.ReadSeparator()

end

function Reader.CreateError(err, func)
    Reader.Error = Reader.Error or string.format("ERROR: %s in '%s' at index %d", tostring(err), tostring(func), Reader.Index);
end

---Reads and returns a Message
---@return boolean | string | number | table | nil
function Reader.ReadMessage()
    if not Reader.ReadNextIfEqual(IO.TokenType.START_MESSAGE) then
        Reader.CreateError("Start of message expected, got " .. Reader.GetNext(), "Reader.ReadMessage");
        return;
    end

    local mes = Reader.ReadNext();

    if mes == nil then
        Reader.CreateError("Expected a Message object, got nil", "Reader.ReadMessage");
        return;
    end
    
    if not Reader.ReadNextIfEqual(IO.TokenType.END_MESSAGE) then
        Reader.CreateError("End of message expected, got " .. Reader.GetNext(), "Reader.ReadMessage");
        return;
    end

    return mes;
end

IO.Reader = {};

---@generic T
---@param s string
---@param class `T`
---@return T | nil
function IO.Reader.Read(s, class)
    Reader.String = s;
    Reader.Index = 1;
    Reader.Length = #s;
    Reader.Error = nil;

    local r = Reader.ReadMessage();
    return r;
end

function IO.Reader.GetError()
    return Reader.Error or "There is no error";
end