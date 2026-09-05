require("Utilities");

RESOLVE_BOMB_PREFIX = "BombShelter|ResolveBomb|";

---Server_AdvanceTurn_Order hook. Handles three unrelated things that all route through this same hook:
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl)
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
    if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, "BombShelter_")) then
        local targetTerritoryID = tonumber(string.sub(order.ModData, 13));
        QueueBombShelterBuild(order.PlayerID, targetTerritoryID, false);
        return;
    end

    if (order.proxyType == 'GameOrderCustom' and startsWith(order.Payload, "BombShelter_")) then
        local targetTerritoryID = tonumber(string.sub(order.Payload, 13));
        QueueBombShelterBuild(order.PlayerID, targetTerritoryID, true);
        return;
    end

    if (order.proxyType == 'GameOrderCustom' and startsWith(order.Payload, RESOLVE_BOMB_PREFIX)) then
        ResolveBombAgainstBombShelter(game, addNewOrder, order);
        return;
    end

    HandleBombAgainstBombShelter(game, order, addNewOrder);
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_End(game, addNewOrder)
    RemoveExpiredBombShelters(game, addNewOrder);
    BuildQueuedBombShelters(game, addNewOrder);
end

---have played out.
---@param playerID PlayerID
---@param targetTerritoryID TerritoryID
---@param isCommerce boolean
function QueueBombShelterBuild(playerID, targetTerritoryID, isCommerce)
    local priv = Mod.PrivateGameData;
    local pendingBuilds = priv.PendingBombShelterBuilds or {};

    table.insert(pendingBuilds, {
        PlayerID = playerID,
        TerritoryID = targetTerritoryID,
        IsCommerce = isCommerce,
    });

    priv.PendingBombShelterBuilds = pendingBuilds;
    Mod.PrivateGameData = priv;
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function BuildQueuedBombShelters(game, addNewOrder)
    local structureID = WL.StructureType.Custom("Bomb Shelter");
    local priv = Mod.PrivateGameData;
    local pending = priv.PendingBombShelterBuilds;
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
            local maxAllowed = Mod.Settings.BombShelterMaxPerPlayer or 0;
            local existingCount = CountPlayerBombShelters(game.ServerGame.LatestTurnStanding, build.PlayerID, structureID);
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

    -- success build logic
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
            local event = WL.GameOrderEvent.Create(build.PlayerID, "Built Bomb Shelter(s) on " .. td.Name, {}, { territoryModification });
            event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
            event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Bomb Shelter(s) built", 8, GetColourIntegerFromHex(BUTTON_COLOURS.DarkGreen)) };
            event.Icon = "Build";
            addNewOrder(event);

            if (Mod.Settings.BombShelterHasDuration) then
                for _ = 1, numToBuild do
                    TrackBombShelterDuration(game, territoryID, build.PlayerID);
                end
            end
        end
    end

    -- limit hit logic
    for _, build in pairs(cappedPending) do
        local event = WL.GameOrderEvent.Create(build.PlayerID, "Unable to build Bomb Shelter(s): you already own the maximum number of Bomb Shelters", {}, {});
        event.TerritoryAnnotationsOpt = { [build.TerritoryID] = WL.TerritoryAnnotation.Create("Unable to build Bomb Shelter(s)", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Red)) };
        event.Icon = "BuildFailed";
        addNewOrder(event);
    end

    -- ownership lost logic
    for territoryID, buildGroup in pairs(groupBy(removedPending, function(b) return b.TerritoryID; end)) do
        local build = first(buildGroup);
        if (build ~= nil) then
            local td = game.Map.Territories[territoryID];
            local event = WL.GameOrderEvent.Create(build.PlayerID, "Unable to build Bomb Shelter(s) on " .. td.Name .. ": you no longer control that territory", {}, {});
            event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
            event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Unable to build Bomb Shelter(s)", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Red)) };
            event.Icon = "BuildFailed";
            addNewOrder(event);
        end
    end

    -- TrackBombShelterDuration uses priv, so we need to refetch
    local finalPriv = Mod.PrivateGameData;
    finalPriv.PendingBombShelterBuilds = nil;
    Mod.PrivateGameData = finalPriv;
end

---@param game GameServerHook
---@param territoryID TerritoryID
---@param playerID PlayerID
function TrackBombShelterDuration(game, territoryID, playerID)
    local priv = Mod.PrivateGameData;
    local activeBombShelters = priv.ActiveBombShelters or {};

    table.insert(activeBombShelters, {
        TerritoryID = territoryID,
        FinalTurn = game.Game.TurnNumber + (Mod.Settings.BombShelterDurationTurns or 1),
        PlayerID = playerID,
    });

    priv.ActiveBombShelters = activeBombShelters;
    Mod.PrivateGameData = priv;
end

---@param territoryID TerritoryID
function UntrackBombShelterDuration(territoryID)
    local priv = Mod.PrivateGameData;
    local activeBombShelters = priv.ActiveBombShelters;
    if (activeBombShelters == nil) then return; end;

    local oldestIndex = nil;
    for i, entry in ipairs(activeBombShelters) do
        if (entry.TerritoryID == territoryID) then
            if (oldestIndex == nil or entry.FinalTurn < activeBombShelters[oldestIndex].FinalTurn) then
                oldestIndex = i;
            end
        end
    end

    if (oldestIndex ~= nil) then
        table.remove(activeBombShelters, oldestIndex);
        priv.ActiveBombShelters = activeBombShelters;
        Mod.PrivateGameData = priv;
    end
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function RemoveExpiredBombShelters(game, addNewOrder)
    local priv = Mod.PrivateGameData;
    local activeBombShelters = priv.ActiveBombShelters;
    if (activeBombShelters == nil or #activeBombShelters == 0) then return; end;
    local structureID = WL.StructureType.Custom("Bomb Shelter");

    local standing = game.ServerGame.LatestTurnStanding;
    local remaining = {};
    local expired = {};

    for _, entry in ipairs(activeBombShelters) do
        if (game.Game.TurnNumber >= entry.FinalTurn) then
            table.insert(expired, entry);
        else
            table.insert(remaining, entry);
        end
    end

    for territoryID, expiredGroup in pairs(groupBy(expired, function(e) return e.TerritoryID; end)) do
        local territory = standing.Territories[territoryID];
        if (territory ~= nil and territory.Structures ~= nil and (territory.Structures[structureID] or 0) > 0) then
            local finalStructures = {};
            for key, value in pairs(territory.Structures) do
                finalStructures[key] = value;
            end
            finalStructures[structureID] = math.max(0, finalStructures[structureID] - #expiredGroup);

            local td = game.Map.Territories[territoryID];
            local currentOwnerPlayerID = territory.OwnerPlayerID;

            for _, entry in ipairs(expiredGroup) do
                local visibleTo = { currentOwnerPlayerID };
                if (entry.PlayerID ~= currentOwnerPlayerID) then
                    table.insert(visibleTo, entry.PlayerID);
                end

                local territoryModification = WL.TerritoryModification.Create(territoryID);
                territoryModification.SetStructuresOpt = finalStructures;

                local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, "Bomb Shelter on " .. td.Name .. " expired", visibleTo, { territoryModification });
                event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
                event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Bomb Shelter expired", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Red)) };
                event.Icon = "Destroyed";
                addNewOrder(event);
            end
        end
    end

    priv.ActiveBombShelters = remaining;
    Mod.PrivateGameData = priv;
end

-- Future proofing - instead of just skipping orders we add an order to track the damage and handle it later.
---@param game GameServerHook
---@param order GameOrder
---@param addNewOrder fun(order: GameOrder)
function HandleBombAgainstBombShelter(game, order, addNewOrder)
    if (order.proxyType ~= 'GameOrderPlayCardBomb') then return; end;

    local territory = game.ServerGame.LatestTurnStanding.Territories[order.TargetTerritoryID];
    if (territory == nil or territory.Structures == nil) then return; end;

    local structureID = WL.StructureType.Custom("Bomb Shelter");
    if ((territory.Structures[structureID] or 0) <= 0) then return; end;

    local armiesBefore = territory.NumArmies.NumArmies;
    local payload = RESOLVE_BOMB_PREFIX .. order.TargetTerritoryID .. "|" .. armiesBefore;
    addNewOrder(WL.GameOrderCustom.Create(order.PlayerID, "Bomb Shelter modifying Bomb damage", payload, nil));
end

-- Use tracking payload created in HandleBombAgainstBombShelter to modify dmg
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
---@param order GameOrder
function ResolveBombAgainstBombShelter(game, addNewOrder, order)
    local territoryID, armiesBeforeStr = string.match(order.Payload, "^" .. RESOLVE_BOMB_PREFIX .. "(%d+)|(%d+)$");
    if (territoryID == nil) then return; end;
    territoryID = tonumber(territoryID);
    local armiesBefore = tonumber(armiesBeforeStr);

    local standing = game.ServerGame.LatestTurnStanding;
    local territory = standing.Territories[territoryID];
    if (territory == nil) then return; end;

    local armiesAfter = territory.NumArmies.NumArmies; -- realistically this is just half the before but future proof configurable bombs
    local armiesLost = armiesBefore - armiesAfter;

    local territoryModifications = {};
    local message = nil;

    if (armiesBefore > 0) then
        local damagePercent = Mod.Settings.BombShelterDamagePercent or 0.5;
        local targetArmiesLost = math.min(armiesBefore, math.floor(armiesBefore * damagePercent + 0.5));
        local armiesDiff = armiesLost - targetArmiesLost;

        if (armiesDiff > 0) then
            local territoryModification = WL.TerritoryModification.Create(territoryID);
            territoryModification.AddArmies = armiesDiff;
            table.insert(territoryModifications, territoryModification);
            message = "Bomb Shelter modified Bomb damage, adding " .. armiesDiff .. " armies";
        elseif (armiesDiff < 0) then
            local extraArmies = math.min(-armiesDiff, math.max(0, armiesAfter));

            if (extraArmies > 0) then
                local territoryModification = WL.TerritoryModification.Create(territoryID);
                territoryModification.AddArmies = -extraArmies;
                table.insert(territoryModifications, territoryModification);
                message = "Bomb Shelter increased Bomb damage, destroying an additional " .. extraArmies .. " armies";
            end
        end
    end

    local structureID = WL.StructureType.Custom("Bomb Shelter");
    if (Mod.Settings.BombShelterDestroyedOnBomb and territory.Structures ~= nil and (territory.Structures[structureID] or 0) > 0) then
        local structures = {};
        for key, value in pairs(territory.Structures) do
            structures[key] = value;
        end
        structures[structureID] = structures[structureID] - 1;

        local territoryModification = WL.TerritoryModification.Create(territoryID);
        territoryModification.SetStructuresOpt = structures;
        table.insert(territoryModifications, territoryModification);

        if (message ~= nil) then
            message = message .. ". The Bomb Shelter was destroyed";
        else
            message = "The Bomb Shelter was destroyed.";
        end
        UntrackBombShelterDuration(territoryID);
    end

    if (#territoryModifications > 0) then
        local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, message, {}, territoryModifications);
        event.Icon = "Triggered";
        addNewOrder(event);
    end
end
