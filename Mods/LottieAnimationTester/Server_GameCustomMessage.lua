require("Utilities");

---Server_GameCustomMessage hook. Receives this mod's chunked animation uploads (see
---QueueChunkUpload/TrySendNextChunk in Utilities.lua for the client side) and reassembles
---them into Mod.PublicGameData once every chunk has arrived, since that's the only
---mod-data store Client_Visual (a client hook) can read. Also handles clearing it.
---
---setReturn always echoes back whether an animation is currently stored and its
---AnimationSubmissionCount, so the client can update its "latest stored animation" label
---directly from this response instead of trusting a fresh read of Mod.PublicGameData - reading
---it back immediately after writing it in the same round-trip was observed to still return the
---pre-write value (the client's mirror of mod data apparently isn't refreshed until the next
---full game-state sync, e.g. reopening the menu).
---@param game GameServerHook
---@param playerID PlayerID
---@param payload table
---@param setReturn fun(payload: table)
function Server_GameCustomMessage(game, playerID, payload, setReturn)
    if (payload == nil or payload.Mod ~= PAYLOAD_PREFIX) then
        return; -- not this mod's message
    end

    if (payload.Action == "Clear") then
        local priv = Mod.PrivateGameData;
        priv.AnimationChunks = nil;
        priv.AnimationTotalChunks = nil;
        Mod.PrivateGameData = priv;

        local pub = Mod.PublicGameData;
        pub.AnimationJson = nil; -- AnimationSubmissionCount is deliberately left as-is: it only
        Mod.PublicGameData = pub; -- ever counts up, so the next upload's number keeps climbing

        setReturn({ Success = true, HasAnimation = false });
        return;
    end

    if (payload.Action == "Chunk") then
        local priv = Mod.PrivateGameData;
        local chunks = priv.AnimationChunks or {};

        if (payload.Index == 1) then
            chunks = {}; -- first chunk of a fresh upload; discard any previous partial one
        end
        chunks[payload.Index] = payload.Data;

        if (payload.Index == payload.Total) then
            local full = table.concat(chunks, "", 1, payload.Total);
            priv.AnimationChunks = nil;
            priv.AnimationTotalChunks = nil;
            Mod.PrivateGameData = priv;

            -- NOTE: game.Game.ServerTime (and game.ServerGame.Game.ServerTime) both came back as the
            -- .NET default DateTime (0001-01-01) when testing in single-player, since there's no real
            -- networked server clock to report there, and a WL.TickCount()-based "X ago" display
            -- can't update live while the dialog stays open (it's a one-shot SetText, not a ticking
            -- clock), so it'd be stuck showing "0s ago" until the dialog was reopened. A simple
            -- monotonically-increasing submission counter sidesteps both problems.
            local submissionCount = (Mod.PublicGameData.AnimationSubmissionCount or 0) + 1;

            local pub = Mod.PublicGameData;
            pub.AnimationJson = full;
            pub.AnimationSubmissionCount = submissionCount;
            Mod.PublicGameData = pub;

            setReturn({ Success = true, Received = payload.Index, HasAnimation = true, SubmissionCount = submissionCount });
        else
            priv.AnimationChunks = chunks;
            priv.AnimationTotalChunks = payload.Total;
            Mod.PrivateGameData = priv;

            setReturn({ Success = true, Received = payload.Index });
        end
        return;
    end
end
