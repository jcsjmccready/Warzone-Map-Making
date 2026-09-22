require("Utilities");

---One phase of a player's Crunch Time run
---@class CrunchTimePhase
---@field Percent number # Signed percentage applied to the player's current income (e.g. 0.25 = +25%, -0.3 = -30%)
---@field FlatAmount number # Signed flat amount applied after the percentage (e.g. 3, -2)
---@field FinalTurn integer # The turn number on which this phase's income change is last applied; Crunch Time advances to the next phase (or ends, if this was the last one) in Server_AdvanceTurn_End of that turn

---A player's Crunch Time run, stored in the Mod.PrivateGameData.CrunchTime array. This is the authoritative,
---server-only copy that all behaviour is derived from. All phases (a rotation of Mod.Settings.Phases starting at
---whichever row the player chose, or row 1 if the map maker fixed the order) are computed up front at entry, so
---no separate duration bookkeeping is needed later - advancing just pops the front of Phases. A read-only mirror
---of just the Phases array is written to Mod.PlayerGameData[playerID].CrunchtimePhases (see
---SyncCrunchtimePlayerMirror below) purely so Client_PresentMenuUI.lua / Client_PresentPlayCardUI.lua can display
---a player's own status - nothing reads that mirror to drive behaviour
---@class CrunchTimeState
---@field PlayerID PlayerID # The player this Crunch Time run belongs to
---@field Phases CrunchTimePhase[] # Remaining phases in order; Phases[1] is always the currently active phase

---Server_AdvanceTurn_Order
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
    local crunchtimeData = nil;
    if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, CRUNCHTIME_MOD_DATA_PREFIX)) then
        -- entered via the Crunch Time card - only valid when the mod is configured for card entry, the client
        -- can't be trusted to have enforced that
        if (not Mod.Settings.TriggerTypeCard) then return; end
        crunchtimeData = order.ModData;
    elseif (order.proxyType == 'GameOrderCustom' and startsWith(order.Payload, CRUNCHTIME_MOD_DATA_PREFIX)) then
        -- entered via the mod menu - only valid when the mod is configured for menu entry
        if (not Mod.Settings.TriggerTypeMenu) then return; end
        crunchtimeData = order.Payload;
    else
        return;
    end

    local playerID = order.PlayerID;

    local privateData = Mod.PrivateGameData;
    ---@type CrunchTimeState[]
    local crunchtime = privateData.CrunchTime or {};

    local existingState = FindCrunchtimeState(crunchtime, playerID);
    if (existingState ~= nil) then
        -- already in Crunchtime - can't restart or stack it. This shouldn't normally be reachable (the card is
        -- single-use per player, and the menu hides the entry controls once active) but the client can't be
        -- fully trusted
        addNewOrder(WL.GameOrderEvent.Create(playerID, "Already in " .. PhaseEffectName(existingState.Phases[1].Percent) .. " - no effect.", { playerID }, {}));
        return;
    end

    ---@type PhaseRowSetting[]
    local configuredPhases = Mod.Settings.Phases or {};
    local numPhases = #configuredPhases;
    if (numPhases < 2) then return; end

    local rest = string.sub(crunchtimeData, string.len(CRUNCHTIME_MOD_DATA_PREFIX) + 1);
    local parts = split(rest, "_");
    local chosenStartIndex = tonumber(parts[1]) or 1;
    local chosenDuration = tonumber(parts[2]) or 0;

    -- the client can't be trusted to have picked a valid/allowed starting row - fall back to row 1 whenever the
    -- map maker fixed the order, or the client's chosen index doesn't point at a real row
    local startIndex = 1;
    if (Mod.Settings.PhaseOrderPlayerSelected and chosenStartIndex >= 1 and chosenStartIndex <= numPhases) then
        startIndex = chosenStartIndex;
    end

    -- build every phase of this run up front by rotating the configured rows to start at startIndex, computing
    -- each one's FinalTurn cumulatively. FinalTurn is the last turn a phase is granted income for (inclusive),
    -- so the very first phase's FinalTurn is (current turn + its duration - 1), not (current turn + duration)
    local phases = {};
    local finalTurn = game.Game.TurnNumber - 1;
    for i = 0, numPhases - 1 do
        local rowIndex = ((startIndex - 1 + i) % numPhases) + 1;
        local row = configuredPhases[rowIndex];

        local duration = row.Duration;
        if (Mod.Settings.UserSpecifiedDuration) then
            duration = chosenDuration;
        end
        if (duration == nil or duration < 1) then return; end

        finalTurn = finalTurn + duration;
        table.insert(phases, { Percent = row.Percent, FlatAmount = row.FlatAmount, FinalTurn = finalTurn });
    end

    ---@type CrunchTimeState
    local newState = {
        PlayerID = playerID,
        Phases = phases,
    };
    table.insert(crunchtime, newState);
    privateData.CrunchTime = crunchtime;
    Mod.PrivateGameData = privateData;
    SyncCrunchtimePlayerMirror(playerID, newState.Phases);

    local firstPhase = phases[1];
    local firstDuration = firstPhase.FinalTurn - game.Game.TurnNumber + 1;
    addNewOrder(WL.GameOrderEvent.Create(playerID, "Entered " .. PhaseEffectName(firstPhase.Percent) .. " - income will " .. (firstPhase.Percent >= 0 and "increase" or "decrease") .. " for " .. firstDuration .. " turn(s).", { playerID }, {}));
end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_End(game, addNewOrder)
    local privateData = Mod.PrivateGameData;
    ---@type CrunchTimeState[]
    local crunchtime = privateData.CrunchTime or {};
    local remaining = {};
    local standing = game.ServerGame.LatestTurnStanding;

    for _, state in ipairs(crunchtime) do
        local player = game.Game.PlayingPlayers[state.PlayerID];

        if (player == nil) then
            -- player is no longer playing (eliminated/left this turn or earlier) - drop their Crunchtime state
            -- without granting income for it, rather than crediting a player who's no longer around to use it
            SyncCrunchtimePlayerMirror(state.PlayerID, nil);
        else
            local currentPhase = state.Phases[1];
            GrantCrunchtimeIncome(game, standing, state.PlayerID, player, currentPhase.Percent, currentPhase.FlatAmount, addNewOrder);

            if (currentPhase.FinalTurn ~= game.Game.TurnNumber) then
                table.insert(remaining, state);
            else
                local endedPhase = table.remove(state.Phases, 1);

                if (#state.Phases > 0) then
                    local nextPhase = state.Phases[1];
                    table.insert(remaining, state);
                    SyncCrunchtimePlayerMirror(state.PlayerID, state.Phases);
                    addNewOrder(WL.GameOrderEvent.Create(state.PlayerID, PhaseEffectName(endedPhase.Percent) .. " has ended - " .. PhaseEffectName(nextPhase.Percent) .. " now begins, income will " .. (nextPhase.Percent >= 0 and "increase" or "decrease") .. " for " .. (nextPhase.FinalTurn - game.Game.TurnNumber) .. " turn(s).", { state.PlayerID }, {}));
                else
                    SyncCrunchtimePlayerMirror(state.PlayerID, nil);
                    addNewOrder(WL.GameOrderEvent.Create(state.PlayerID, PhaseEffectName(endedPhase.Percent) .. " has ended.", { state.PlayerID }, {}));
                end
            end
        end
    end

    privateData.CrunchTime = remaining;
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
            phasesCopy[i] = { Percent = phase.Percent, FlatAmount = phase.FlatAmount, FinalTurn = phase.FinalTurn };
        end
        myPlayerData.CrunchtimePhases = phasesCopy;
    end

    playerData[playerID] = myPlayerData;
    Mod.PlayerGameData = playerData;
end

--computes and grants this turn's income change for a player currently in Crunch Time; percent is calculated off
--the player's current income and rounded, then the flat amount is added on top (percent first, then flat).
--percent/flat may be negative, in which case the change is clamped so income never goes below 0
function GrantCrunchtimeIncome(game, standing, playerID, player, percent, flat, addNewOrder)
    local currentIncome = player.Income(0, standing, true, false).Total;
    local displayName = PhaseEffectName(percent);

    local percentPart = math.floor(currentIncome * percent + 0.5);
    local delta = percentPart + flat;
    delta = math.max(delta, -currentIncome); -- never take income below 0

    if (delta == 0) then return; end
    local verb = delta > 0 and "increased" or "decreased";
    local icon = delta > 0 and "IncomeGain" or "IncomeLoss";

    if (game.Settings.CommerceGame) then
        local currentGold = (standing.Resources[playerID] ~= nil) and (standing.Resources[playerID][WL.ResourceType.Gold] or 0) or 0;
        local goldDelta = delta;
        if (goldDelta < 0) then
            goldDelta = math.max(goldDelta, -currentGold);
        end
        if (goldDelta == 0) then return; end

        local event = WL.GameOrderEvent.Create(playerID, displayName .. " " .. verb .. " income by " .. math.abs(goldDelta) .. " gold", { playerID }, {});
        event.AddResourceOpt = { [playerID] = { [WL.ResourceType.Gold] = goldDelta } };
        event.Icon = icon;
        addNewOrder(event);
    else
        local event = WL.GameOrderEvent.Create(playerID, displayName .. " " .. verb .. " income by " .. math.abs(delta) .. " armies", { playerID }, {});
        event.IncomeMods = { WL.IncomeMod.Create(playerID, delta, displayName) };
        event.Icon = icon;
        addNewOrder(event);
    end
end
