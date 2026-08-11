require("Utilities");

RESOLVE_BOMB_PREFIX = "Foxhole|ResolveBomb|";

---Server_AdvanceTurn_Start hook. Removes any Foxhole whose tracked duration has expired going into this turn.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Start(game, addNewOrder)
    MigrateModSettings();
    RemoveExpiredFoxholes(game, addNewOrder);
end

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
    MigrateModSettings();

    if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, "Foxhole_")) then
        local targetTerritoryID = tonumber(string.sub(order.ModData, 9));
        BuildFoxhole(game, addNewOrder, order.PlayerID, targetTerritoryID, "Built a Foxhole", false);
        return;
    end

    if (order.proxyType == 'GameOrderCustom' and startsWith(order.Payload, "Foxhole_")) then
        local targetTerritoryID = tonumber(string.sub(order.Payload, 9));
        BuildFoxhole(game, addNewOrder, order.PlayerID, targetTerritoryID, "Built a Foxhole", true);
        return;
    end

    if (order.proxyType == 'GameOrderCustom' and startsWith(order.Payload, RESOLVE_BOMB_PREFIX)) then
        ResolveBombAgainstFoxhole(game, addNewOrder, order);
        return;
    end

    HandleBombAgainstFoxhole(game, order, addNewOrder);
end

---Builds a Foxhole on targetTerritoryID for playerID, re-validating ownership (and, for Commerce, the
---max-per-player cap) server-side since the client can never be trusted to have enforced it. Applied immediately
---rather than deferred to Server_AdvanceTurn_End - there's no reason to wait since nothing else this turn can
---affect whether the build should succeed beyond current ownership, which is checked right here.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
---@param playerID PlayerID
---@param targetTerritoryID TerritoryID
---@param message string
---@param isCommerce boolean
function BuildFoxhole(game, addNewOrder, playerID, targetTerritoryID, message, isCommerce)
    local standing = game.ServerGame.LatestTurnStanding;
    local territory = standing.Territories[targetTerritoryID];

    if (territory == nil or territory.OwnerPlayerID ~= playerID) then
        local event = WL.GameOrderEvent.Create(playerID, "Unable to build Foxhole: you no longer control that territory", {}, {});
        event.Icon = "BuildFailed";
        addNewOrder(event);
        return;
    end

    if (isCommerce) then
        local maxAllowed = Mod.Settings.FoxholeMaxPerPlayer or 0;
        if (CountPlayerFoxholes(standing, playerID) >= maxAllowed) then
            local event = WL.GameOrderEvent.Create(playerID, "Unable to build Foxhole: you already own the maximum number of Foxholes", {}, {});
            event.Icon = "BuildFailed";
            addNewOrder(event);
            return;
        end
    end

    local structures = {};
    for key, value in pairs(territory.Structures or {}) do
        structures[key] = value;
    end
    structures[FOXHOLE_STRUCTURE_ID] = (structures[FOXHOLE_STRUCTURE_ID] or 0) + 1;

    local territoryModification = WL.TerritoryModification.Create(targetTerritoryID);
    territoryModification.SetStructuresOpt = structures;

    local event = WL.GameOrderEvent.Create(playerID, message, {}, { territoryModification });
    event.Icon = "Build";
    addNewOrder(event);

    if (Mod.Settings.FoxholeHasDuration) then
        TrackFoxholeDuration(game, targetTerritoryID);
    end
end

---Tracks a Foxhole's expiry turn in private mod data so Server_AdvanceTurn_Start can remove it once expired.
---@param game GameServerHook
---@param territoryID TerritoryID
function TrackFoxholeDuration(game, territoryID)
    local priv = Mod.PrivateGameData;
    local activeFoxholes = priv.ActiveFoxholes or {};

    table.insert(activeFoxholes, {
        TerritoryID = territoryID,
        FinalTurn = game.Game.TurnNumber + (Mod.Settings.FoxholeDurationTurns or 1) - 1,
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

---Removes every tracked Foxhole whose duration has expired as of this turn.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function RemoveExpiredFoxholes(game, addNewOrder)
    local priv = Mod.PrivateGameData;
    local activeFoxholes = priv.ActiveFoxholes;
    if (activeFoxholes == nil or #activeFoxholes == 0) then return; end;

    local standing = game.ServerGame.LatestTurnStanding;
    local remaining = {};
    local territoryModifications = {};

    for _, entry in ipairs(activeFoxholes) do
        if (game.Game.TurnNumber > entry.FinalTurn) then
            local territory = standing.Territories[entry.TerritoryID];
            if (territory ~= nil and territory.Structures ~= nil and (territory.Structures[FOXHOLE_STRUCTURE_ID] or 0) > 0) then
                local structures = {};
                for key, value in pairs(territory.Structures) do
                    structures[key] = value;
                end
                structures[FOXHOLE_STRUCTURE_ID] = structures[FOXHOLE_STRUCTURE_ID] - 1;

                local territoryModification = WL.TerritoryModification.Create(entry.TerritoryID);
                territoryModification.SetStructuresOpt = structures;
                table.insert(territoryModifications, territoryModification);
            end
        else
            table.insert(remaining, entry);
        end
    end

    if (#territoryModifications > 0) then
        local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, "Foxhole duration expired", {}, territoryModifications);
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
    if ((territory.Structures[FOXHOLE_STRUCTURE_ID] or 0) <= 0) then return; end;

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

    if (Mod.Settings.FoxholeDestroyedOnBomb and territory.Structures ~= nil and (territory.Structures[FOXHOLE_STRUCTURE_ID] or 0) > 0) then
        local structures = {};
        for key, value in pairs(territory.Structures) do
            structures[key] = value;
        end
        structures[FOXHOLE_STRUCTURE_ID] = structures[FOXHOLE_STRUCTURE_ID] - 1;

        local territoryModification = WL.TerritoryModification.Create(territoryID);
        territoryModification.SetStructuresOpt = structures;
        table.insert(territoryModifications, territoryModification);

        if (message ~= nil) then
            message = message .. ", and the Foxhole was destroyed";
        else
            message = "Foxhole destroyed by Bomb";
        end
        UntrackFoxholeDuration(territoryID);
    end

    if (#territoryModifications > 0) then
        local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, message, {}, territoryModifications);
        event.Icon = "Destroyed";
        addNewOrder(event);
    end
end
