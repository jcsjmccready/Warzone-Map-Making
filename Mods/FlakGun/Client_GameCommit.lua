require('Utilities')

---Reading a field a proxy object doesn't declare (e.g. CardInstanceID on a GameOrderDeploy) throws, so any
---check against a field that's only present on some order types must go through this first.
---@param proxyObject ProxyObject
---@param key string
---@return boolean
function HasReadableKey(proxyObject, key)
    for _, readableKey in ipairs(proxyObject.readableKeys) do
        if (readableKey == key) then return true; end
    end
    return false;
end

---@param game GameClientHook
---@return table<CardInstanceID, boolean>
function GetCardInstanceIDsAlreadyQueued(game)
    local queued = {};
    for _, order in pairs(game.Orders) do
        if (HasReadableKey(order, "CardInstanceID") and order.CardInstanceID ~= nil) then
            queued[order.CardInstanceID] = true;
        end
    end
    return queued;
end

---Inserts newOrder into list at the first position whose existing order's OccursInPhase is later than
---newOrder's own, instead of just appending at the end - the game rejects (OrdersInIncorrectOrder) a list
---whose orders aren't in non-decreasing phase order. OccursInPhase is read-only (the engine assigns it
---per order type), so newOrder is placed wherever its own OccursInPhase falls, or at the end if it's nil.
---@param list GameOrder[]
---@param newOrder GameOrder
function InsertOrderInPhaseOrder(list, newOrder)
    local index = #list + 1;
    if (newOrder.OccursInPhase ~= nil) then
        for i, order in ipairs(list) do
            if (order.OccursInPhase ~= nil and order.OccursInPhase > newOrder.OccursInPhase) then
                index = i;
                break;
            end
        end
    end
    table.insert(list, index, newOrder);
end

---Client_GameCommit hook. Discards any Temp. Flak Gun cards still sitting in the player's hand at commit time,
---so the player sees the discard happen instead of it only occurring silently at Server_AdvanceTurn_End (kept
---there as a safety net). Skips any card instance already referenced by a queued order (e.g. one being played
---this turn), so a card about to be played isn't discarded out from under it.
---@param game GameClientHook
---@param skipCommit fun()
function Client_GameCommit(game, skipCommit)
    if (game.Us == nil or Mod.Settings.FlakGunTemporaryCardID == nil) then return; end;

    local playerCards = game.LatestStanding.Cards[game.Us.ID];
    if (playerCards == nil) then return; end;

    local alreadyQueued = GetCardInstanceIDsAlreadyQueued(game);

    local orders = game.Orders;
    local anyDiscarded = false;
    for cardInstanceID, cardInstance in pairs(playerCards.WholeCards) do
        if (cardInstance.CardID == Mod.Settings.FlakGunTemporaryCardID and not alreadyQueued[cardInstanceID]) then
            local discardOrder = WL.GameOrderDiscard.Create(game.Us.ID, cardInstanceID);
            InsertOrderInPhaseOrder(orders, discardOrder);
            anyDiscarded = true;
        end
    end

    if (anyDiscarded) then
        game.Orders = orders;
    end
end
