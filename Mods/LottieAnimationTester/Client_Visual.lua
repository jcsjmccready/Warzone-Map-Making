require("Utilities");

---Called on the client when it needs to draw a visual for one of this mod's orders.
---A GameOrderCustom order is never itself played/animated - Server_AdvanceTurn_Order creates a
---GameOrderEvent from it (Message = PAYLOAD_PREFIX), and THAT event is what shows up here. The
---event carries no state (empty TerritoryModifications) - the real animation JSON arrives
---separately via the chunked upload in Utilities.lua/Server_GameCustomMessage.lua, landing in
---Mod.PublicGameData, which is what's decoded here into the mesh/frame data Warzone needs.
---@param game GameClientHook
---@param order GameOrder
---@param visual Visual
function Client_Visual(game, order, visual)
    -- Unconditional: fires for every order of every type/mod, so if this never prints, the
    -- Client_Visual hook itself isn't running at all - a different problem than anything below.
    -- Mod.PublicGameData can't be used for this (it's "only writable in server hooks", and this
    -- is a client hook), so print() - the same mechanism Util/Timer.lua in the mod template uses
    -- for debug output - is the only logging channel available here.
    print("[LottieAnimationTester] Client_Visual called for order.proxyType=" .. tostring(order.proxyType) .. " Message=" .. tostring(order.Message));

    if (order.proxyType ~= 'GameOrderEvent' or order.Message ~= PAYLOAD_PREFIX) then
        return; -- not one of this mod's events
    end
    print("[LottieAnimationTester] order matched - this is one of this mod's visual events");

    local jsonText = Mod.PublicGameData.AnimationJson;
    print("[LottieAnimationTester] Mod.PublicGameData.AnimationJson length=" .. tostring(jsonText ~= nil and string.len(jsonText) or nil));
    local data = DecodeJson(jsonText);
    if (data == nil or data.Triangles == nil or data.Frames == nil) then
        print("[LottieAnimationTester] DecodeJson failed or produced incomplete data - nothing to draw");
        return; -- nothing uploaded yet, or it failed to decode
    end
    print("[LottieAnimationTester] decoded " .. #data.Triangles .. " triangle indices, " .. #data.Frames .. " frames");

    -- Anchor to the very first territory the map defines, rather than data.AnchorPoint's raw map
    -- coordinates: lottie_to_warzone.py always emits {0, 0}, which on most maps isn't anywhere
    -- near the visible territories, so the animation would render off-screen. game.Map.Territories
    -- is static map data (unlike game.LatestStanding, it doesn't depend on ownership/standing
    -- state being populated a particular way), so this is about as few ways to fail as possible.
    local anchorTerritoryID = nil;
    for territoryID, _ in pairs(game.Map.Territories) do
        anchorTerritoryID = territoryID;
        break;
    end

    if (anchorTerritoryID ~= nil) then
        print("[LottieAnimationTester] anchoring to territory " .. tostring(anchorTerritoryID));
        visual.SetAnchorTerritory(anchorTerritoryID);
    else
        local anchor = data.AnchorPoint or { 0, 0 };
        print("[LottieAnimationTester] no territories found on game.Map - falling back to AnchorPoint " .. anchor[1] .. "," .. anchor[2]);
        visual.SetAnchorPoint(anchor[1], anchor[2]);
    end

    visual.SetTriangles(data.Triangles)
        .SetFrames(data.Frames)
        .SetDuration(data.Duration or 1500);
    print("[LottieAnimationTester] visual fully configured and handed back to Warzone");
end
