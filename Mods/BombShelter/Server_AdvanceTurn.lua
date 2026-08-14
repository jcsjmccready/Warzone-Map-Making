require("Utilities");

RESOLVE_BOMB_PREFIX = "BombShelter|ResolveBomb|";

---Server_AdvanceTurn_Order hook. Handles three unrelated things that all route through this same hook:
---1) Building a Bomb Shelter from the Bomb Shelter Card (GameOrderPlayCardCustom, "BombShelter_<territoryID>")
---2) Building a Bomb Shelter from a Commerce purchase (GameOrderCustom, "BombShelter_<territoryID>")
---3) Reducing Bomb Card damage against a Bomb Shelter - see HandleBombAgainstBombShelter for why this is a 2-step chain
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

---Server_AdvanceTurn_End hook. Removes any Bomb Shelter whose tracked duration has expired as of this turn, then
---builds every Bomb Shelter queued this turn (via QueueBombShelterBuild) now that all of the turn's other orders -
---attacks, transfers, etc - have already resolved, so ownership is checked against the territory's final state for
---the turn rather than its state at the moment the order was submitted. Both expiry and building happen here
---(rather than expiry at Server_AdvanceTurn_Start) because Bomb Shelters are built at end of turn - a 1-turn
---duration should span from the end of the turn it's built to the end of the next, giving it exactly one
---Start-of-turn where it can be bombed before it's removed. Expiring at Start would remove it before that turn's
---Bomb orders ever ran.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_End(game, addNewOrder)
    RemoveExpiredBombShelters(game, addNewOrder);
    BuildQueuedBombShelters(game, addNewOrder);
end

---Queues a Bomb Shelter build request to be resolved in Server_AdvanceTurn_End, once the rest of the turn's orders
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

---Builds every Bomb Shelter queued this turn, re-validating ownership (and, for Commerce, the max-per-player cap)
---server-side since the client can never be trusted to have enforced it. Follows the same pending-build shape as
---BarbedWire/DeadManSwitch's BuildStructures: split into still-owned vs no-longer-owned, then group the still-owned
---ones by territory so multiple Bomb Shelters queued on the same territory this turn stack into a single build
---(rather than each being computed against the same pre-turn structure count and clobbering each other).
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
            event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Bomb Shelter(s) built", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Cinnamon)) };
            event.Icon = "Build";
            addNewOrder(event);

            if (Mod.Settings.BombShelterHasDuration) then
                for _ = 1, numToBuild do
                    TrackBombShelterDuration(game, territoryID);
                end
            end
        end
    end

    for _, build in pairs(cappedPending) do
        local event = WL.GameOrderEvent.Create(build.PlayerID, "Unable to build Bomb Shelter(s): you already own the maximum number of Bomb Shelters", {}, {});
        event.TerritoryAnnotationsOpt = { [build.TerritoryID] = WL.TerritoryAnnotation.Create("Unable to build Bomb Shelter(s)", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Red)) };
        event.Icon = "BuildFailed";
        addNewOrder(event);
    end

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

    priv.PendingBombShelterBuilds = nil;
    Mod.PrivateGameData = priv;
end

---Tracks a Bomb Shelter's expiry turn in private mod data so RemoveExpiredBombShelters can remove it once expired.
---The Bomb Shelter is built at the end of this turn, so a duration of 1 should span to the end of next turn - the
---turn after this one is its one chance to be bombed - hence no "- 1" here (contrast the old Start-of-turn expiry).
---@param game GameServerHook
---@param territoryID TerritoryID
function TrackBombShelterDuration(game, territoryID)
    local priv = Mod.PrivateGameData;
    local activeBombShelters = priv.ActiveBombShelters or {};

    table.insert(activeBombShelters, {
        TerritoryID = territoryID,
        FinalTurn = game.Game.TurnNumber + (Mod.Settings.BombShelterDurationTurns or 1),
    });

    priv.ActiveBombShelters = activeBombShelters;
    Mod.PrivateGameData = priv;
end

---Removes the single tracked entry for territoryID closest to expiry (i.e. the oldest Bomb Shelter there), if any -
---used when a Bomb destroys one Bomb Shelter on a territory that may have several stacked. Only ever removes one
---entry: a Bomb only ever destroys one Bomb Shelter (see the "- 1" in ResolveBombAgainstBombShelter), so if
---multiple are tracked for this territory, removing all of them would desync the tracking from the actual
---structure count, leaving the remaining Bomb Shelter(s) untracked and never expiring.
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

---Removes every tracked Bomb Shelter whose duration has expired as of the end of this turn. Expired entries are
---grouped by territory (like BuildQueuedBombShelters) rather than decremented one at a time against
---LatestTurnStanding, since that snapshot isn't refreshed between iterations of a single hook call - if two
---Bomb Shelters on the same territory expired the same turn, decrementing individually would compute both from the
---same starting count and only actually remove one.
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

    local territoryModifications = {};
    for territoryID, expiredGroup in pairs(groupBy(expired, function(e) return e.TerritoryID; end)) do
        local territory = standing.Territories[territoryID];
        if (territory ~= nil and territory.Structures ~= nil and (territory.Structures[structureID] or 0) > 0) then
            local structures = {};
            for key, value in pairs(territory.Structures) do
                structures[key] = value;
            end
            structures[structureID] = math.max(0, structures[structureID] - #expiredGroup);

            local territoryModification = WL.TerritoryModification.Create(territoryID);
            territoryModification.SetStructuresOpt = structures;
            table.insert(territoryModifications, territoryModification);
        end
    end

    if (#territoryModifications > 0) then
        local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, "Bomb Shelter(s) duration expired", {}, territoryModifications);
        event.Icon = "Destroyed";
        addNewOrder(event);
    end

    priv.ActiveBombShelters = remaining;
    Mod.PrivateGameData = priv;
end

---Step 1 of Bomb Shelter's Bomb Card damage reduction. GameOrderPlayCardBombResult exposes no data about how much
---damage the engine's own Bomb effect did, so damage can't be read-then-adjusted after the fact. Instead, when a
---Bomb targets a Bomb Shelter territory, this lets the Bomb resolve normally (does not skip the order) and chains a
---follow-up GameOrderCustom carrying the pre-bomb army count. addNewOrder queues that follow-up to run
---immediately after the Bomb's own effect finishes (before the rest of the turn's orders), so by the time it's
---processed in ResolveBombAgainstBombShelter below, LatestTurnStanding already reflects the Bomb's real damage.
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
    addNewOrder(WL.GameOrderCustom.Create(order.PlayerID, "Bomb Shelter absorbing Bomb damage", payload, nil));
end

---Step 2 of Bomb Shelter's Bomb Card damage reduction, see HandleBombAgainstBombShelter above. Compares the
---territory's armies now (post-Bomb) against the pre-Bomb count carried in the payload to find out how much the
---Bomb actually destroyed, then restores (1 - BombShelterDamagePercent) of that loss - vanilla Bomb behaviour is
---preserved exactly, just scaled down, since we never had to reimplement its formula. Optionally destroys the
---Bomb Shelter afterward.
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

    local armiesAfter = territory.NumArmies.NumArmies;
    local armiesLost = armiesBefore - armiesAfter;

    local territoryModifications = {};
    local message = nil;

    if (armiesLost > 0) then
        local damagePercent = Mod.Settings.BombShelterDamagePercent or 0.5;
        local armiesToRestore = math.floor(armiesLost * (1 - damagePercent) + 0.5);

        if (armiesToRestore > 0) then
            local territoryModification = WL.TerritoryModification.Create(territoryID);
            territoryModification.AddArmies = armiesToRestore;
            table.insert(territoryModifications, territoryModification);
            message = "Bomb Shelter absorbed Bomb damage, restoring " .. armiesToRestore .. " armies";
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
