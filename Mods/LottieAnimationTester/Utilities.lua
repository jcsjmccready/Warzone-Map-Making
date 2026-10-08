function GetButtonColors()
    return {
        Blue = "#0000FF";
        Purple = "#59009D";
        Orange = "#FF7D00";
        DarkGray = "#606060";
        HotPink = "#FF697A";
        SeaGreen = "#00FF8C";
        Teal = "#009B9D";
        DarkMagenta = "#AC0059";
        Yellow = "#FFFF00";
        Ivory = "#FEFF9B";
        ElectricPurple = "#B70AFF";
        DeepPink = "#FF00B1";
        Aqua = "#4EFFFF";
        DarkGreen = "#008000";
        Red = "#FF0000";
        Green = "#00FF05";
        SaddleBrown = "#94652E";
        OrangeRed = "#FF4700";
        LightBlue = "#23A0FF";
        Orchid = "#FF87FF";
        Brown = "#943E3E";
        CopperRose = "#AD7E7E";
        Tan = "#FFAF56";
        Lime = "#8EBE57";
        TyrianPurple = "#990024";
        MardiGras = "#880085";
        RoyalBlue = "#4169E1";
        WildStrawberry = "#FF43A4";
        SmokyBlack = "#100C08";
        Goldenrod = "#DAA520";
        Cyan = "#00FFFF";
        Artichoke = "#8F9779";
        RainForest = "#00755E";
        Peach = "#FFE5B4";
        AppleGreen = "#8DB600";
        Viridian = "#40826D";
        Mahogany = "#C04000";
        PinkLace = "#FFDDF4";
        Bronze = "#CD7F32";
        WoodBrown = "#C19A6B";
        Tuscany = "#C09999";
        AcidGreen = "#B0BF1A";
        Amazon = "#3B7A57";
        ArmyGreen = "#4B5320";
        DonkeyBrown = "#664C28";
        Cordovan = "#893F45";
        Cinnamon = "#D2691E";
        Charcoal = "#36454F";
        Fuchsia = "#FF00FF";
        ScreaminGreen = "#76FF7A";
    };
end

TEXT_DEFAULT_COLOUR = "#CCCCCC";
BUTTON_COLOURS = GetButtonColors();
ERROR_COLOUR = BUTTON_COLOURS.Red;
SUBHEADING_COLOUR = BUTTON_COLOURS.Yellow;

-- Identifies this mod's orders/events and custom messages, since Server_AdvanceTurn_Order,
-- Client_Visual and Server_GameCustomMessage all see every mod's traffic and have to recognise
-- which of it is theirs. The GameOrderCustom trigger order's Payload is this literal marker;
-- the GameOrderEvent Server_AdvanceTurn_Order creates from it (see Client_Visual.lua for why that
-- extra step exists) carries it as its Message; and every SendGameCustomMessage payload table
-- carries it in a "Mod" field.
PAYLOAD_PREFIX = "LottieAnimationTester_";

-- GameOrderCustom.Payload has an undocumented, small server-side length cap ("StringTooLong"),
-- so the animation JSON (produced by Tools/ModAnimationConverter/lottie_to_warzone.py) is instead
-- sent to the server out-of-band via SendGameCustomMessage, split into chunks this size. The cap on
-- a SendGameCustomMessage payload itself is unverified - if chunks this size still get rejected,
-- lower this.
CHUNK_SIZE = 2000;

---Splits a string into chunks of at most chunkSize characters, preserving order.
---@param text string
---@param chunkSize integer
---@return string[]
function SplitIntoChunks(text, chunkSize)
    local chunks = {};
    local len = string.len(text);
    local i = 1;
    while i <= len do
        table.insert(chunks, string.sub(text, i, i + chunkSize - 1));
        i = i + chunkSize;
    end
    if (#chunks == 0) then table.insert(chunks, ""); end
    return chunks;
end


-- =====================================================
-- =================  CHUNKED UPLOAD  ==================
-- =====================================================
--
-- Chunks are sent one at a time, only once the previous chunk's server round-trip has completed:
-- TrySendNextChunk is called once to kick things off, and then again from inside each chunk's own
-- callback, so progress never depends on some other hook firing on a timer we don't control.
-- Client_PresentMenuUI only has to populate UploadQueue and keep UploadStatusLabel pointed at a
-- live label so progress is visible while the dialog is open (the upload itself keeps running even
-- if the dialog is closed mid-upload).
--
-- SendGameCustomMessage is documented as rate-limited to 5 calls every 5 seconds, but a previous
-- version of this code self-throttled to stay under that and got stuck after exactly 5 chunks in
-- single-player: each round-trip there is near-instant, so all 5 allowed sends fired immediately,
-- then nothing was left to retry the 6th once Client_GameRefresh turned out not to fire reliably
-- (see its own comment). No self-throttling is attempted now; if the real limit ever actually
-- rejects a call, that'll surface as an error from SendGameCustomMessage to handle then.

UploadQueue = {};
UploadInFlight = false;
UploadStatusLabel = nil;
UploadChunksSent = 0;
UploadTotalChunks = 0;

-- Points at the label showing which numbered submission (Mod.PublicGameData.AnimationSubmissionCount)
-- is currently stored, so re-opening the menu - or finishing an upload/clear in this session - can
-- keep it current. See RefreshLastSubmittedLabel.
LastSubmittedLabel = nil;

---Updates the status label if the dialog that owns it is still open.
---@param text string
function SetUploadStatus(text)
    if (UploadStatusLabel ~= nil and not UI.IsDestroyed(UploadStatusLabel)) then
        UploadStatusLabel.SetText(text).SetColor(BUTTON_COLOURS.DarkGray);
    end
end

---Sets LastSubmittedLabel directly, if that label is still live. Prefer this over
---RefreshLastSubmittedLabel right after an upload/clear completes: the server's setReturn
---response already carries the authoritative value, and re-reading Mod.PublicGameData
---immediately afterwards was observed to still return the pre-write value.
---
---Shown as a submission number ("#3") rather than a time: game.Game.ServerTime (and
---game.ServerGame.Game.ServerTime) both come back as the .NET default DateTime in single-player
---(no real networked server clock to report there), and a WL.TickCount()-based "X ago" can't
---update live while the dialog stays open anyway, so it'd just sit stuck at "0s ago".
---@param hasAnimation boolean
---@param submissionCount integer | nil
function ShowLastSubmitted(hasAnimation, submissionCount)
    if (LastSubmittedLabel == nil or UI.IsDestroyed(LastSubmittedLabel)) then return; end
    if (not hasAnimation) then
        LastSubmittedLabel.SetText("No animation currently stored.").SetColor(BUTTON_COLOURS.Orange);
    else
        -- submissionCount can be nil for an animation stored by an older version of this mod
        -- (before this field existed) that's still sitting in Mod.PublicGameData.
        LastSubmittedLabel.SetText("Currently stored animation: #" .. (submissionCount or "?") .. ".").SetColor(BUTTON_COLOURS.Orange);
    end
end

---Refreshes LastSubmittedLabel from a fresh read of Mod.PublicGameData.
---Use this when (re-)opening the menu; see ShowLastSubmitted for right after an upload/clear.
function RefreshLastSubmittedLabel()
    local pub = Mod.PublicGameData;
    ShowLastSubmitted(pub.AnimationJson ~= nil, pub.AnimationSubmissionCount);
end

---Queues a full chunked upload of jsonText, replacing any upload still in progress.
---@param jsonText string
function QueueChunkUpload(jsonText)
    local chunks = SplitIntoChunks(jsonText, CHUNK_SIZE);
    UploadQueue = {};
    UploadChunksSent = 0;
    UploadTotalChunks = #chunks;
    for i, chunk in ipairs(chunks) do
        table.insert(UploadQueue, {
            Mod = PAYLOAD_PREFIX,
            Action = "Chunk",
            Index = i,
            Total = #chunks,
            Data = chunk,
        });
    end
end

---Sends the next queued chunk if nothing is currently in flight. Called directly after queuing
---an upload and again from every chunk's own SendGameCustomMessage callback, so the upload drives
---itself forward via a guaranteed callback chain rather than depending on some other hook firing
---on a timer. Also called from Client_GameRefresh, purely as a harmless extra nudge in case the
---chain ever stalls for some other reason.
---@param game GameClientHook
function TrySendNextChunk(game)
    if (UploadInFlight or #UploadQueue == 0) then return; end

    local nextChunk = table.remove(UploadQueue, 1);
    UploadInFlight = true;

    game.SendGameCustomMessage("Uploading animation...", nextChunk, function(response)
        UploadInFlight = false;
        UploadChunksSent = UploadChunksSent + 1;
        if (#UploadQueue == 0) then
            SetUploadStatus("Upload complete (" .. UploadChunksSent .. "/" .. UploadTotalChunks .. " chunks). You can now add the testing order.");
            ShowLastSubmitted(response.HasAnimation, response.SubmissionCount);
        else
            SetUploadStatus("Uploading... (" .. UploadChunksSent .. "/" .. UploadTotalChunks .. ")");
            TrySendNextChunk(game); -- keep the chain going immediately rather than waiting on Client_GameRefresh
        end
    end);
end


-- =====================================================
-- ===================  JSON DECODER  ==================
-- =====================================================
--
-- A hand-written JSON decoder. We can't safely eval an arbitrary pasted Lua
-- table at runtime (load/loadstring are not available in the mod sandbox),
-- so the animation data is passed as JSON text instead and decoded by hand
-- here. Malformed input is handled by DecodeJson returning nil rather than
-- erroring, since this is parsing text a person pasted in by hand.

local parseValue; -- forward declaration; parseArray/parseObject call back into it

local function skipWhitespace(s, i)
    local _, e = string.find(s, "^[ \t\n\r]*", i);
    return e + 1;
end

local function parseNumber(s, i)
    local _, e, numStr = string.find(s, "^(-?%d+%.?%d*[eE]?[%+%-]?%d*)", i);
    if numStr == nil or numStr == "" then return nil, i; end
    return tonumber(numStr), e + 1;
end

local function parseString(s, i)
    local j = i + 1; -- skip opening '"'
    local buf = {};
    while true do
        local c = string.sub(s, j, j);
        if c == "" then
            return table.concat(buf), j; -- unterminated string; bail out gracefully
        elseif c == '"' then
            return table.concat(buf), j + 1;
        elseif c == "\\" then
            local esc = string.sub(s, j + 1, j + 1);
            if esc == "n" then table.insert(buf, "\n"); j = j + 2;
            elseif esc == "t" then table.insert(buf, "\t"); j = j + 2;
            elseif esc == "r" then table.insert(buf, "\r"); j = j + 2;
            elseif esc == '"' then table.insert(buf, '"'); j = j + 2;
            elseif esc == "\\" then table.insert(buf, "\\"); j = j + 2;
            elseif esc == "/" then table.insert(buf, "/"); j = j + 2;
            elseif esc == "u" then
                local hex = string.sub(s, j + 2, j + 5);
                local code = tonumber(hex, 16) or 0;
                -- Only basic ASCII is reconstructed; other codepoints become '?'.
                table.insert(buf, code < 128 and string.char(code) or "?");
                j = j + 6;
            else
                table.insert(buf, esc); j = j + 2;
            end
        else
            table.insert(buf, c);
            j = j + 1;
        end
    end
end

local function parseArray(s, i)
    local arr = {};
    i = skipWhitespace(s, i + 1); -- skip '['
    if string.sub(s, i, i) == "]" then return arr, i + 1; end
    while true do
        local value;
        value, i = parseValue(s, i);
        table.insert(arr, value);
        i = skipWhitespace(s, i);
        local c = string.sub(s, i, i);
        if c == "," then
            i = skipWhitespace(s, i + 1);
        elseif c == "]" then
            return arr, i + 1;
        else
            return arr, i + 1; -- malformed; stop rather than loop forever
        end
    end
end

local function parseObject(s, i)
    local obj = {};
    i = skipWhitespace(s, i + 1); -- skip '{'
    if string.sub(s, i, i) == "}" then return obj, i + 1; end
    while true do
        i = skipWhitespace(s, i);
        local key;
        key, i = parseString(s, i);
        i = skipWhitespace(s, i);
        i = i + 1; -- skip ':'
        i = skipWhitespace(s, i);
        local value;
        value, i = parseValue(s, i);
        obj[key] = value;
        i = skipWhitespace(s, i);
        local c = string.sub(s, i, i);
        if c == "," then
            i = skipWhitespace(s, i + 1);
        elseif c == "}" then
            return obj, i + 1;
        else
            return obj, i + 1; -- malformed; stop rather than loop forever
        end
    end
end

parseValue = function(s, i)
    i = skipWhitespace(s, i);
    local c = string.sub(s, i, i);
    if c == '"' then
        return parseString(s, i);
    elseif c == "{" then
        return parseObject(s, i);
    elseif c == "[" then
        return parseArray(s, i);
    elseif c == "t" and string.sub(s, i, i + 3) == "true" then
        return true, i + 4;
    elseif c == "f" and string.sub(s, i, i + 4) == "false" then
        return false, i + 5;
    elseif c == "n" and string.sub(s, i, i + 3) == "null" then
        return nil, i + 4;
    else
        return parseNumber(s, i);
    end
end

---Decodes a JSON string into a Lua table. Returns nil if jsonText is empty/nil.
---@param jsonText string
---@return table | nil
function DecodeJson(jsonText)
    -- No pcall here: it's nil in this sandbox (not exposed), same restriction category as
    -- load/loadstring. parseValue and friends are written to degrade gracefully on malformed
    -- input (stopping early, returning partial results) rather than relying on pcall to catch
    -- errors, so this should hold up to the pasted-by-hand text this is meant to decode.
    if (jsonText == nil or jsonText == "") then return nil; end
    local result, _ = parseValue(jsonText, 1);
    return result;
end
