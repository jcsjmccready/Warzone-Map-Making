require("Utilities");

---Client_GameRefresh hook. Drives the chunked animation upload queue forward - see
---TrySendNextChunk and the surrounding comments in Utilities.lua for why uploading
---needs its own per-tick pump instead of just firing every chunk at once.
---@param game GameClientHook
function Client_GameRefresh(game)
    TrySendNextChunk(game);
end
