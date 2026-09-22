require("Utilities");

---One phase of a player's Crunch Time run
---@class CrunchTimePhase
---@field Phase "Increase" | "Decrease" # Which direction this phase applies
---@field FinalTurn integer # The turn number on which this phase's income change is last applied; Crunch Time advances to the next phase (or ends, if this was the last one) in Server_AdvanceTurn_End of that turn

---A player's Crunch Time run, stored in the Mod.PrivateGameData.Crunchtime array. This is the authoritative,
---server-only copy that all behaviour is derived from. Both phases are computed up front at entry, so no separate
---duration bookkeeping is needed later - advancing just pops the front of Phases. A read-only mirror of just the
---Phases array is written to Mod.PlayerGameData[playerID].CrunchtimePhases (see SyncCrunchtimePlayerMirror below)
---purely so Client_PresentMenuUI.lua / Client_PresentPlayCardUI.lua can display a player's own status - nothing
---reads that mirror to drive behaviour
---@class CrunchTimeState
---@field PlayerID PlayerID # The player this Crunch Time run belongs to
---@field Phases CrunchTimePhase[] # Remaining phases in order; Phases[1] is always the currently active phase

---Server_AdvanceTurn_Start hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_Start(game, addNewOrder)
    ---@type CrunchTimeState[]
    local crunchtime = Mod.PrivateGameData.Crunchtime or {};
    local standing = game.ServerGame.LatestTurnStanding;

    for _, state in ipairs(crunchtime) do
        local player = game.Game.PlayingPlayers[state.PlayerID];
        if (player ~= nil) then
            GrantCrunchtimeIncome(game, standing, state.PlayerID, player, state.Phases[1].Phase, addNewOrder);
        end
    end
end

---Server_AdvanceTurn_Order
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
    local crunchtimeData = nil;
    if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, CRUNCHTIME_MOD_DATA_PREFIX)) then
        if (not Mod.Settings.TriggerTypeCard) then return; end
        crunchtimeData = order.ModData;
    elseif (order.proxyType == 'GameOrderCustom' and startsWith(order.Payload, CRUNCHTIME_MOD_DATA_PREFIX)) then
        if (not Mod.Settings.TriggerTypeMenu) then return; end
        crunchtimeData = order.Payload;
    else
        return;
    end

    local playerID = order.PlayerID;

    local privateData = Mod.PrivateGameData;
    ---@type CrunchTimeState[]
    local crunchtime = privateData.Crunchtime or {};

    local existingState = FindCrunchtimeState(crunchtime, playerID);
    if (existingState ~= nil) then
        addNewOrder(WL.GameOrderEvent.Create(playerID, "Already in " .. PhaseDisplayName(existingState.Phases[1].Phase) .. " - no effect.", { playerID }, {}));
        return;
    end

    local rest = string.sub(crunchtimeData, string.len(CRUNCHTIME_MOD_DATA_PREFIX) + 1);
    local parts = split(rest, "_");
    local startPhase = parts[1];
    local chosenDuration = tonumber(parts[2]) or 0;

    if (startPhase ~= "Increase" and startPhase ~= "Decrease") then return; end
    local otherPhase = (startPhase == "Increase") and "Decrease" or "Increase";

    local firstDuration = GetPhaseDuration(startPhase, chosenDuration);
    if (firstDuration == nil or firstDuration < 1) then return; end
    local secondDuration = GetPhaseDuration(otherPhase, chosenDuration);
    if (secondDuration == nil or secondDuration < 1) then return; end

    local firstFinalTurn = game.Game.TurnNumber + firstDuration;
    local secondFinalTurn = firstFinalTurn + secondDuration;

    ---@type CrunchTimeState
    local newState = {
        PlayerID = playerID,
        Phases = {
            { Phase = startPhase, FinalTurn = firstFinalTurn },
            { Phase = otherPhase, FinalTurn = secondFinalTurn },
        },
    };
    table.insert(crunchtime, newState);
    privateData.Crunchtime = crunchtime;
    Mod.PrivateGameData = privateData;
    SyncCrunchtimePlayerMirror(playerID, newState.Phases);

    addNewOrder(WL.GameOrderEvent.Create(playerID, "Entered " .. PhaseDisplayName(startPhase) .. " - income will " .. (startPhase == "Increase" and "increase" or "decrease") .. " for " .. firstDuration .. " turn(s).", { playerID }, {}));
end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_End(game, addNewOrder)
    local privateData = Mod.PrivateGameData;
    ---@type CrunchTimeState[]
    local crunchtime = privateData.Crunchtime or {};
    local remaining = {};

    for _, state in ipairs(crunchtime) do
        if (game.Game.PlayingPlayers[state.PlayerID] == nil) then
            -- player is no longer playing (eliminated/left) - drop their Crunchtime state
            SyncCrunchtimePlayerMirror(state.PlayerID, nil);
        elseif (state.Phases[1].FinalTurn ~= game.Game.TurnNumber) then
            table.insert(remaining, state);
        else
            local endedPhase = table.remove(state.Phases, 1);

            if (#state.Phases > 0) then
                local nextPhase = state.Phases[1];
                table.insert(remaining, state);
                SyncCrunchtimePlayerMirror(state.PlayerID, state.Phases);
                addNewOrder(WL.GameOrderEvent.Create(state.PlayerID, PhaseDisplayName(endedPhase.Phase) .. " has ended - " .. PhaseDisplayName(nextPhase.Phase) .. " now begins, income will " .. (nextPhase.Phase == "Increase" and "increase" or "decrease") .. " for " .. (nextPhase.FinalTurn - game.Game.TurnNumber) .. " turn(s).", { state.PlayerID }, {}));
            else
                SyncCrunchtimePlayerMirror(state.PlayerID, nil);
                addNewOrder(WL.GameOrderEvent.Create(state.PlayerID, PhaseDisplayName(endedPhase.Phase) .. " has ended.", { state.PlayerID }, {}));
            end
        end
    end

    privateData.Crunchtime = remaining;
    Mod.PrivateGameData = privateData;
end

---Writes a read-only copy of a player's Phases array to Mod.PlayerGameData[playerID].CrunchtimePhases for use in mod menu
---@param playerID PlayerID
---@param phases CrunchTimePhase[] | nil
function SyncCrunchtimePlayerMirror(playerID, phases)
    local playerData = Mod.PlayerGameData;
    local myPlayerData = playerData[playerID] or {};

    if (phases == nil) then
        myPlayerData.CrunchtimePhases = nil;
    else
        local phasesCopy = {};
        for i, phase in ipairs(phases) do
            phasesCopy[i] = { Phase = phase.Phase, FinalTurn = phase.FinalTurn };
        end
        myPlayerData.CrunchtimePhases = phasesCopy;
    end

    playerData[playerID] = myPlayerData;
    Mod.PlayerGameData = playerData;
end

--computes and grants (or removes, for the decrease phase) this turn's income change for a player currently in
--Crunchtime; percent is calculated off the player's current income and rounded, then the flat amount is added
--on top (per-phase order: percent first, then flat)
function GrantCrunchtimeIncome(game, standing, playerID, player, phase, addNewOrder)
    local currentIncome = player.Income(0, standing, true, false).Total;
    local displayName = PhaseDisplayName(phase);

    local percent, flat, verb;
    if (phase == "Increase") then
        percent = Mod.Settings.IncreasePercent or 0;
        flat = Mod.Settings.IncreaseFlatAmount or 0;
        verb = "increased";
    else
        percent = Mod.Settings.DecreasePercent or 0;
        flat = Mod.Settings.DecreaseFlatAmount or 0;
        verb = "decreased";
    end

    local percentPart = math.floor(currentIncome * percent + 0.5);
    local delta = percentPart + flat;

    if (phase == "Decrease") then
        delta = -delta;
        delta = math.max(delta, -currentIncome); -- never take income below 0
    end

    if (delta == 0) then return; end

    if (game.Settings.CommerceGame) then
        local currentGold = (standing.Resources[playerID] ~= nil) and (standing.Resources[playerID][WL.ResourceType.Gold] or 0) or 0;
        local goldDelta = delta;
        if (goldDelta < 0) then
            goldDelta = math.max(goldDelta, -currentGold);
        end
        if (goldDelta == 0) then return; end

        local event = WL.GameOrderEvent.Create(playerID, displayName .. " " .. verb .. " income by " .. goldDelta .. " gold", { playerID }, {});
        event.AddResourceOpt = { [playerID] = { [WL.ResourceType.Gold] = goldDelta } };
        event.Icon = "Income";
        addNewOrder(event);
    else
        local event = WL.GameOrderEvent.Create(playerID, displayName .. " " .. verb .. " income by " .. delta .. " armies", { playerID }, {});
        event.IncomeMods = { WL.IncomeMod.Create(playerID, delta, displayName) };
        event.Icon = "Income";
        addNewOrder(event);
    end
end
