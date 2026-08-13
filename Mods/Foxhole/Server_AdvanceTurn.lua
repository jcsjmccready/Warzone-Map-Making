require("Utilities");

RESOLVE_BOMB_PREFIX = "Foxhole|ResolveBomb|";

---Server_AdvanceTurn_Order hook. Handles three unrelated things that all route through this same hook:
---1) Building a Foxhole from the Foxhole Card (GameOrderPlayCardCustom, "Foxhole_<territoryID>")
---2) Building a Foxhole from a Commerce purchase (GameOrderCustom, "Foxhole_<territoryID>")
---3) Reducing Bomb Card damage against a Foxhole - see HandleBombAgainstFoxhole for why this is a 2-step chain
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl)
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
    if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, "Foxhole_")) then
        local targetTerritoryID = tonumber(string.sub(order.ModData, 9));
        QueueFoxholeBuild(order.PlayerID, targetTerritoryID, false);
        return;
    end

    if (order.proxyType == 'GameOrderCustom' and startsWith(order.Payload, "Foxhole_")) then
        local targetTerritoryID = tonumber(string.sub(order.Payload, 9));
        QueueFoxholeBuild(order.PlayerID, targetTerritoryID, true);
        return;
    end

    if (order.proxyType == 'GameOrderCustom' and startsWith(order.Payload, RESOLVE_BOMB_PREFIX)) then
        ResolveBombAgainstFoxhole(game, addNewOrder, order);
        return;
    end

    HandleBombAgainstFoxhole(game, order, addNewOrder);
end

---Server_AdvanceTurn_End hook. Removes any Foxhole whose tracked duration has expired as of this turn, then builds
---every Foxhole queued this turn (via QueueFoxholeBuild) now that all of the turn's other orders - attacks,
---transfers, etc - have already resolved, so ownership is checked against the territory's final state for the turn
---rather than its state at the moment the order was submitted. Both expiry and building happen here (rather than
---expiry at Server_AdvanceTurn_Start) because Foxholes are built at end of turn - a 1-turn duration should span
---from the end of the turn it's built to the end of the next, giving it exactly one Start-of-turn where it can be
---bombed before it's removed. Expiring at Start would remove it before that turn's Bomb orders ever ran.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_End(game, addNewOrder)
    RemoveExpiredFoxholes(game, addNewOrder);
    BuildQueuedFoxholes(game, addNewOrder);
end

---Queues a Foxhole build request to be resolved in Server_AdvanceTurn_End, once the rest of the turn's orders
---have played out.
---@param playerID PlayerID
---@param targetTerritoryID TerritoryID
---@param isCommerce boolean
function QueueFoxholeBuild(playerID, targetTerritoryID, isCommerce)
    local priv = Mod.PrivateGameData;
    local pendingBuilds = priv.PendingFoxholeBuilds or {};

    table.insert(pendingBuilds, {
        PlayerID = playerID,
        TerritoryID = targetTerritoryID,
        IsCommerce = isCommerce,
    });

    priv.PendingFoxholeBuilds = pendingBuilds;
    Mod.PrivateGameData = priv;
end

---Builds every Foxhole queued this turn, re-validating ownership (and, for Commerce, the max-per-player cap)
---server-side since the client can never be trusted to have enforced it. Follows the same pending-build shape as
---BarbedWire/DeadManSwitch's BuildStructures: split into still-owned vs no-longer-owned, then group the still-owned
---ones by territory so multiple Foxholes queued on the same territory this turn stack into a single build (rather
---than each being computed against the same pre-turn structure count and clobbering each other).
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function BuildQueuedFoxholes(game, addNewOrder)
    local structureID = WL.StructureType.Custom("Foxhole");
    local priv = Mod.PrivateGameData;
    local pending = priv.PendingFoxholeBuilds;
    if (pending == nil) then return; end;

    local remainingPending = {};
    local removedPending = {};
    for _, build in pairs(pending) do
        local territory = game.ServerGame.LatestTurnStanding.Territories[build.TerritoryID];
        if (territory == nil or territory.OwnerPlayerID ~= build.PlayerID) then
            table.insert(removedPending, build);
        else
            table.insert(remainingPending, build);
        end
    end

    -- Enforce the Commerce max-per-player cap against a running total, since two Commerce builds queued by the
    -- same player this turn would otherwise both be checked against the same pre-turn count.
    local builtCountByPlayer = {};
    local allowedPending = {};
    local cappedPending = {};
    for _, build in pairs(remainingPending) do
        if (build.IsCommerce) then
            local maxAllowed = Mod.Settings.FoxholeMaxPerPlayer or 0;
            local existingCount = CountPlayerFoxholes(game.ServerGame.LatestTurnStanding, build.PlayerID, structureID);
            local builtSoFar = builtCountByPlayer[build.PlayerID] or 0;
            if (existingCount + builtSoFar >= maxAllowed) then
                table.insert(cappedPending, build);
            else
                builtCountByPlayer[build.PlayerID] = builtSoFar + 1;
                table.insert(allowedPending, build);
            end
        else
            table.insert(allowedPending, build);
        end
    end

    for territoryID, buildGroup in pairs(groupBy(allowedPending, function(b) return b.TerritoryID; end)) do
        local numToBuild = #buildGroup;
        local territory = game.ServerGame.LatestTurnStanding.Territories[territoryID];

        local structures = {};
        for key, value in pairs(territory.Structures or {}) do
            structures[key] = value;
        end
        structures[structureID] = (structures[structureID] or 0) + numToBuild;

        local territoryModification = WL.TerritoryModification.Create(territoryID);
        territoryModification.SetStructuresOpt = structures;

        local build = first(buildGroup);
        if (build ~= nil) then
            local td = game.Map.Territories[territoryID];
            local event = WL.GameOrderEvent.Create(build.PlayerID, "Built Foxhole(s) on " .. td.Name, {}, { territoryModification });
            event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
            event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Foxhole(s) built", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Cinnamon)) };
            event.Icon = "Build";
            addNewOrder(event);

            if (Mod.Settings.FoxholeHasDuration) then
                for _ = 1, numToBuild do
                    TrackFoxholeDuration(game, territoryID);
                end
            end
        end
    end

    for _, build in pairs(cappedPending) do
        local event = WL.GameOrderEvent.Create(build.PlayerID, "Unable to build Foxhole(s): you already own the maximum number of Foxholes", {}, {});
        event.TerritoryAnnotationsOpt = { [build.TerritoryID] = WL.TerritoryAnnotation.Create("Unable to build Foxhole(s)", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Red)) };
        event.Icon = "BuildFailed";
        addNewOrder(event);
    end

    for territoryID, buildGroup in pairs(groupBy(removedPending, function(b) return b.TerritoryID; end)) do
        local build = first(buildGroup);
        if (build ~= nil) then
            local td = game.Map.Territories[territoryID];
            local event = WL.GameOrderEvent.Create(build.PlayerID, "Unable to build Foxhole(s) on " .. td.Name .. ": you no longer control that territory", {}, {});
            event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
            event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Unable to build Foxhole(s)", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Red)) };
            event.Icon = "BuildFailed";
            addNewOrder(event);
        end
    end

    priv.PendingFoxholeBuilds = nil;
    Mod.PrivateGameData = priv;
end

---Tracks a Foxhole's expiry turn in private mod data so RemoveExpiredFoxholes can remove it once expired. The
---Foxhole is built at the end of this turn, so a duration of 1 should span to the end of next turn - the turn
---after this one is its one chance to be bombed - hence no "- 1" here (contrast the old Start-of-turn expiry).
---@param game GameServerHook
---@param territoryID TerritoryID
function TrackFoxholeDuration(game, territoryID)
    local priv = Mod.PrivateGameData;
    local activeFoxholes = priv.ActiveFoxholes or {};

    table.insert(activeFoxholes, {
        TerritoryID = territoryID,
        FinalTurn = game.Game.TurnNumber + (Mod.Settings.FoxholeDurationTurns or 1),
    });

    priv.ActiveFoxholes = activeFoxholes;
    Mod.PrivateGameData = priv;
end

---Removes the tracked entry for territoryID, if any - used when a Foxhole is destroyed by a Bomb before its
---duration naturally expired, so RemoveExpiredFoxholes doesn't try to remove it a second time later.
---@param territoryID TerritoryID
function UntrackFoxholeDuration(territoryID)
    local priv = Mod.PrivateGameData;
    local activeFoxholes = priv.ActiveFoxholes;
    if (activeFoxholes == nil) then return; end;

    local remaining = {};
    for _, entry in ipairs(activeFoxholes) do
        if (entry.TerritoryID ~= territoryID) then
            table.insert(remaining, entry);
        end
    end

    priv.ActiveFoxholes = remaining;
    Mod.PrivateGameData = priv;
end

---Removes every tracked Foxhole whose duration has expired as of the end of this turn.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function RemoveExpiredFoxholes(game, addNewOrder)
    local priv = Mod.PrivateGameData;
    local activeFoxholes = priv.ActiveFoxholes;
    if (activeFoxholes == nil or #activeFoxholes == 0) then return; end;
    local structureID = WL.StructureType.Custom("Foxhole");

    local standing = game.ServerGame.LatestTurnStanding;
    local remaining = {};
    local territoryModifications = {};

    for _, entry in ipairs(activeFoxholes) do
        if (game.Game.TurnNumber >= entry.FinalTurn) then
            local territory = standing.Territories[entry.TerritoryID];
            if (territory ~= nil and territory.Structures ~= nil and (territory.Structures[structureID] or 0) > 0) then
                local structures = {};
                for key, value in pairs(territory.Structures) do
                    structures[key] = value;
                end
                structures[structureID] = structures[structureID] - 1;

                local territoryModification = WL.TerritoryModification.Create(entry.TerritoryID);
                territoryModification.SetStructuresOpt = structures;
                table.insert(territoryModifications, territoryModification);
            end
        else
            table.insert(remaining, entry);
        end
    end

    if (#territoryModifications > 0) then
        local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, "Foxhole(s) duration expired", {}, territoryModifications);
        event.Icon = "Destroyed";
        addNewOrder(event);
    end

    priv.ActiveFoxholes = remaining;
    Mod.PrivateGameData = priv;
end

---Step 1 of Foxhole's Bomb Card damage reduction. GameOrderPlayCardBombResult exposes no data about how much
---damage the engine's own Bomb effect did, so damage can't be read-then-adjusted after the fact. Instead, when a
---Bomb targets a Foxhole territory, this lets the Bomb resolve normally (does not skip the order) and chains a
---follow-up GameOrderCustom carrying the pre-bomb army count. addNewOrder queues that follow-up to run
---immediately after the Bomb's own effect finishes (before the rest of the turn's orders), so by the time it's
---processed in ResolveBombAgainstFoxhole below, LatestTurnStanding already reflects the Bomb's real damage.
---@param game GameServerHook
---@param order GameOrder
---@param addNewOrder fun(order: GameOrder)
function HandleBombAgainstFoxhole(game, order, addNewOrder)
    if (order.proxyType ~= 'GameOrderPlayCardBomb') then return; end;

    local territory = game.ServerGame.LatestTurnStanding.Territories[order.TargetTerritoryID];
    if (territory == nil or territory.Structures == nil) then return; end;
    
    local structureID = WL.StructureType.Custom("Foxhole");
    if ((territory.Structures[structureID] or 0) <= 0) then return; end;

    local armiesBefore = territory.NumArmies.NumArmies;
    local payload = RESOLVE_BOMB_PREFIX .. order.TargetTerritoryID .. "|" .. armiesBefore;
    addNewOrder(WL.GameOrderCustom.Create(order.PlayerID, "Foxhole absorbing Bomb damage", payload, nil));
end

---Step 2 of Foxhole's Bomb Card damage reduction, see HandleBombAgainstFoxhole above. Compares the territory's
---armies now (post-Bomb) against the pre-Bomb count carried in the payload to find out how much the Bomb actually
---destroyed, then restores (1 - FoxholeDamagePercent) of that loss - vanilla Bomb behaviour is preserved exactly,
---just scaled down, since we never had to reimplement its formula. Optionally destroys the Foxhole afterward.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
---@param order GameOrder
function ResolveBombAgainstFoxhole(game, addNewOrder, order)
    local territoryID, armiesBeforeStr = string.match(order.Payload, "^" .. RESOLVE_BOMB_PREFIX .. "(%d+)|(%d+)$");
    if (territoryID == nil) then return; end;
    territoryID = tonumber(territoryID);
    local armiesBefore = tonumber(armiesBeforeStr);

    local standing = game.ServerGame.LatestTurnStanding;
    local territory = standing.Territories[territoryID];
    if (territory == nil) then return; end;

    local armiesAfter = territory.NumArmies.NumArmies;
    local armiesLost = armiesBefore - armiesAfter;

    local territoryModifications = {};
    local message = nil;

    if (armiesLost > 0) then
        local damagePercent = Mod.Settings.FoxholeDamagePercent or 0.5;
        local armiesToRestore = math.floor(armiesLost * (1 - damagePercent) + 0.5);

        if (armiesToRestore > 0) then
            local territoryModification = WL.TerritoryModification.Create(territoryID);
            territoryModification.AddArmies = armiesToRestore;
            table.insert(territoryModifications, territoryModification);
            message = "Foxhole absorbed Bomb damage, restoring " .. armiesToRestore .. " armies";
        end
    end

    local structureID = WL.StructureType.Custom("Foxhole");
    if (Mod.Settings.FoxholeDestroyedOnBomb and territory.Structures ~= nil and (territory.Structures[structureID] or 0) > 0) then
        local structures = {};
        for key, value in pairs(territory.Structures) do
            structures[key] = value;
        end
        structures[structureID] = structures[structureID] - 1;

        local territoryModification = WL.TerritoryModification.Create(territoryID);
        territoryModification.SetStructuresOpt = structures;
        table.insert(territoryModifications, territoryModification);

        if (message ~= nil) then
            message = message .. ". The Foxhole was destroyed";
        else
            message = "Foxhole destroyed by Bomb";
        end
        UntrackFoxholeDuration(territoryID);
    end

    if (#territoryModifications > 0) then
        local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, message, {}, territoryModifications);
        event.Icon = "Triggered";
        addNewOrder(event);
    end
end
