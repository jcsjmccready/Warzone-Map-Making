require("Utilities");

MOD_DATA_PREFIX = "BribeSpy_";

---@class BribedSpyInstance
---@field TargetPlayerID PlayerID
---@field FinalTurn integer # The last turn number the bribe should trigger for

---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl)
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
    if (order.proxyType ~= 'GameOrderPlayCardCustom') then
        return;
    end

    if (not startsWith(order.ModData, MOD_DATA_PREFIX)) then
        return;
    end

    local targetPlayerID = tonumber(string.sub(order.ModData, string.len(MOD_DATA_PREFIX) + 1));

    if (game.Game.PlayingPlayers[targetPlayerID] == nil) then
        return; -- target is no longer playing. Likely dead
    end

    if (targetPlayerID == order.PlayerID and not Mod.Settings.AllowTargetingSelf) then
        return; -- self-targeting isn't allowed, and the client can't be trusted to have enforced that
    end

    local alreadySpiedThisTurn = MarkSpiedThisTurn(targetPlayerID);
    TriggerBribe(game, targetPlayerID, addNewOrder, alreadySpiedThisTurn);

    local duration = Mod.Settings.BribeDuration or 1;
    if (duration > 1) then
        local priv = Mod.PrivateGameData;
        local activeBribes = priv.ActiveBribes or {};

        ---@type BribedSpyInstance
        local bribe = {
            TargetPlayerID = targetPlayerID,
            FinalTurn = game.Game.TurnNumber + duration - 1,
        };
        table.insert(activeBribes, bribe);

        priv.ActiveBribes = activeBribes;
        Mod.PrivateGameData = priv;
    end
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Start(game, addNewOrder)
    local activeBribes = Mod.PrivateGameData.ActiveBribes or {};

    for _, bribe in ipairs(activeBribes) do
        if (game.Game.PlayingPlayers[bribe.TargetPlayerID] ~= nil) then
            local alreadySpiedThisTurn = MarkSpiedThisTurn(bribe.TargetPlayerID);
            TriggerBribe(game, bribe.TargetPlayerID, addNewOrder, alreadySpiedThisTurn);
        end
    end
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_End(game, addNewOrder)
    local priv = Mod.PrivateGameData;
    local activeBribes = priv.ActiveBribes or {};
    local remainingBribes = {};

    for _, bribe in ipairs(activeBribes) do
        if (bribe.FinalTurn ~= game.Game.TurnNumber) then
            table.insert(remainingBribes, bribe);
        end
    end

    priv.ActiveBribes = remainingBribes;
    priv.SpiedThisTurn = nil;
    Mod.PrivateGameData = priv;
end

function TriggerBribe(game, targetPlayerID, addNewOrder, skipSpyCards)
    local targetPlayer = game.Game.PlayingPlayers[targetPlayerID];
    if (targetPlayer == nil) then return; end

    if (not skipSpyCards) then
        for playerID, _ in pairs(game.Game.PlayingPlayers) do
            if (playerID ~= targetPlayerID) then
                local instance = WL.NoParameterCardInstance.Create(WL.CardID.Spy);
                addNewOrder(WL.GameOrderReceiveCard.Create(playerID, { instance }));
                addNewOrder(WL.GameOrderPlayCardSpy.Create(instance.ID, playerID, targetPlayerID));
            end
        end
    end

    GrantBribeIncome(game, game.ServerGame.LatestTurnStanding, targetPlayerID, targetPlayer, addNewOrder);
end

-- tracks which targets have already had spy cards played against them this turn - no point doubling up
function MarkSpiedThisTurn(targetPlayerID)
    local priv = Mod.PrivateGameData;
    local spiedTargets = priv.SpiedThisTurn or {};

    local alreadySpied = spiedTargets[targetPlayerID] or false;
    spiedTargets[targetPlayerID] = true;

    priv.SpiedThisTurn = spiedTargets;
    Mod.PrivateGameData = priv;

    return alreadySpied;
end

function GrantBribeIncome(game, standing, targetPlayerID, targetPlayer, addNewOrder)
    local minimumGain = Mod.Settings.MinimumIncomeGain or 0;
    local percentage = Mod.Settings.IncreasedIncomePercentage or 0;

    local currentIncome = targetPlayer.Income(0, standing, true, false).Total;
    local percentageGain = math.floor((currentIncome * percentage / 100) + 0.5);

    local totalGain = math.max(minimumGain, percentageGain);
    if (totalGain <= 0) then return; end

    if (game.Settings.CommerceGame) then
        local event = WL.GameOrderEvent.Create(targetPlayerID, "Bribed Spy granted " .. totalGain .. " bonus gold", { targetPlayerID }, {});
        event.AddResourceOpt = { [targetPlayerID] = { [WL.ResourceType.Gold] = totalGain } };
        event.Icon = "Income";
        addNewOrder(event);
    else
        local event = WL.GameOrderEvent.Create(targetPlayerID, "Bribed Spy granted " .. totalGain .. " bonus income", { targetPlayerID }, {});
        event.IncomeMods = { WL.IncomeMod.Create(targetPlayerID, totalGain, "Bribed Spy") };
        event.Icon = "Income";
        addNewOrder(event);
    end
end
