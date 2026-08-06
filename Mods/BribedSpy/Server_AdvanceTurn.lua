require("Utilities");

MOD_DATA_PREFIX = "BribeSpy_";

---@class BribedSpyInstance # An active multi-turn bribe tracked between turns
---@field TargetPlayerID PlayerID # The player being bribed
---@field FinalTurn integer # The last turn number the bribe should trigger for

---Server_AdvanceTurn_Order hook. Resolves a played Bribed Spy card the moment it's played - which happens during
---the Spying Cards (recon) phase, since that's the turn phase the card is played in. Triggers the bribe
---immediately for this turn, and if it lasts more than one turn, tracks it in private mod data so
---Server_AdvanceTurn_Start can keep re-triggering it on each subsequent turn until it expires.
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
        return; -- target is no longer playing (eg. eliminated since the card was played)
    end

    if (targetPlayerID == order.PlayerID and not Mod.Settings.AllowTargetingSelf) then
        return; -- self-targeting isn't allowed, and the client can't be trusted to have enforced that
    end

    TriggerBribe(game, targetPlayerID, addNewOrder);

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

---Server_AdvanceTurn_Start hook. Re-triggers every bribe that's still active going into this turn (the turn it
---was played on is handled directly by Server_AdvanceTurn_Order above, not here).
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Start(game, addNewOrder)
    local activeBribes = Mod.PrivateGameData.ActiveBribes or {};

    for _, bribe in ipairs(activeBribes) do
        if (game.Game.PlayingPlayers[bribe.TargetPlayerID] ~= nil) then
            TriggerBribe(game, bribe.TargetPlayerID, addNewOrder);
        end
    end
end

---Server_AdvanceTurn_End hook. Removes any tracked bribe whose final turn was this turn, since it's already
---triggered for the last time (via Server_AdvanceTurn_Start, above).
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
    Mod.PrivateGameData = priv;
end

--triggers a bribe for this turn: gives every playing player other than the bribed player a fresh Spy card and
--immediately plays it against the bribed player, then grants the bribed player their bonus income for the turn
function TriggerBribe(game, targetPlayerID, addNewOrder)
    local targetPlayer = game.Game.PlayingPlayers[targetPlayerID];
    if (targetPlayer == nil) then return; end

    for playerID, _ in pairs(game.Game.PlayingPlayers) do
        if (playerID ~= targetPlayerID) then
            local instance = WL.NoParameterCardInstance.Create(WL.CardID.Spy);
            addNewOrder(WL.GameOrderReceiveCard.Create(playerID, { instance }));
            addNewOrder(WL.GameOrderPlayCardSpy.Create(instance.ID, playerID, targetPlayerID));
        end
    end

    GrantBribeIncome(game, game.ServerGame.LatestTurnStanding, targetPlayerID, targetPlayer, addNewOrder);
end

--grants targetPlayerID bonus income for this turn: at least MinimumIncomeGain, or IncreasedIncomePercentage% of
--their current income, whichever is greater. Commerce games use gold as their currency, so the bonus is granted
--as gold there instead of as bonus reinforcement armies (which is what IncomeMod affects).
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
        addNewOrder(event);
    else
        local event = WL.GameOrderEvent.Create(targetPlayerID, "Bribed Spy granted " .. totalGain .. " bonus income", { targetPlayerID }, {});
        event.IncomeMods = { WL.IncomeMod.Create(targetPlayerID, totalGain, "Bribed Spy") };
        addNewOrder(event);
    end
end
