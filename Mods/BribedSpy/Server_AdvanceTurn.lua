require("Utilities");

MOD_DATA_PREFIX = "BribeSpy_";

---Server_AdvanceTurn_Order hook. Resolves a played Bribed Spy card: gives every other player in the game a Spy
---card and immediately plays it against the bribed player. The bribe itself stays "active" (tracked via the
---card's own ActiveOrderDuration/ActiveCardExpireBehavior configured in Client_SaveConfigureUI) so
---Server_AdvanceTurn_End can keep granting the bribed player bonus income for as long as it lasts.
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
    HandleBribeSpy(game, order, targetPlayerID, addNewOrder);
end

--gives every playing player other than the bribed player a Spy card and immediately plays it against the bribed
--player. The client can't be trusted to have respected AllowTargetingSelf, so that's re-checked here.
---@param game GameServerHook
---@param order GameOrder
---@param targetPlayerID PlayerID
---@param addNewOrder fun(order: GameOrder)
function HandleBribeSpy(game, order, targetPlayerID, addNewOrder)
    if (game.Game.PlayingPlayers[targetPlayerID] == nil) then
        return; -- target is no longer playing (eg. eliminated since the card was played)
    end

    if (targetPlayerID == order.PlayerID and not Mod.Settings.AllowTargetingSelf) then
        return; -- self-targeting isn't allowed, and the client can't be trusted to have enforced that
    end

    for playerID, _ in pairs(game.Game.PlayingPlayers) do
        if (playerID ~= targetPlayerID) then
            local instance = WL.NoParameterCardInstance.Create(WL.CardID.Spy);
            addNewOrder(WL.GameOrderReceiveCard.Create(playerID, { instance }));
            addNewOrder(WL.GameOrderPlayCardSpy.Create(instance.ID, playerID, targetPlayerID));
        end
    end
end

---Server_AdvanceTurn_End hook. Grants the bribed player bonus income for every turn the bribe remains active.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_End(game, addNewOrder)
    ApplyBribedSpyIncome(game, addNewOrder);
end

--scans this turn's active cards for our own active Bribed Spy plays, and grants each bribed player their bonus
--income for as long as their bribe stays active
function ApplyBribedSpyIncome(game, addNewOrder)
    local standing = game.ServerGame.LatestTurnStanding;
    local activeCards = standing.ActiveCards or {};

    for _, activeCard in ipairs(activeCards) do
        local cardOrder = activeCard.Card;
        if (cardOrder ~= nil and cardOrder.proxyType == 'GameOrderPlayCardCustom' and startsWith(cardOrder.ModData, MOD_DATA_PREFIX)) then
            local targetPlayerID = tonumber(string.sub(cardOrder.ModData, string.len(MOD_DATA_PREFIX) + 1));
            local targetPlayer = game.Game.PlayingPlayers[targetPlayerID];
            if (targetPlayer ~= nil) then
                GrantBribeIncome(game, standing, targetPlayerID, targetPlayer, addNewOrder);
            end
        end
    end
end

--grants targetPlayerID bonus income for this turn: at least MinimumIncomeGain, or IncreasedIncomePercentage% of
--their current income, whichever is greater
function GrantBribeIncome(game, standing, targetPlayerID, targetPlayer, addNewOrder)
    local minimumGain = Mod.Settings.MinimumIncomeGain or 0;
    local percentage = Mod.Settings.IncreasedIncomePercentage or 0;

    local currentIncome = targetPlayer.Income(0, standing, true, false).Total;
    local percentageGain = math.floor((currentIncome * percentage / 100) + 0.5);

    local totalGain = math.max(minimumGain, percentageGain);
    if (totalGain <= 0) then return; end

    local event = WL.GameOrderEvent.Create(targetPlayerID, "Bribed Spy granted " .. totalGain .. " bonus income", { targetPlayerID }, {});
    event.IncomeMods = { WL.IncomeMod.Create(targetPlayerID, totalGain, "Bribed Spy") };
    addNewOrder(event);
end
