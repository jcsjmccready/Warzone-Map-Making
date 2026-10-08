require("Utilities");

---Server_AdvanceTurn_Order
---@param game GameServerHook
---@param order GameOrder
---@param orderResult GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_Order(game, order, orderResult, skipThisOrder, addNewOrder)
    if (order.proxyType ~= 'GameOrderCustom' or order.Payload ~= PAYLOAD_PREFIX) then
        return;
    end

    -- A GameOrderCustom order is never itself played/animated - per Warzone's own example mods
    -- (e.g. the airlift card), it exists purely to trigger server logic that creates a
    -- GameOrderEvent via addNewOrder, and THAT event is what Client_Visual actually receives and
    -- renders. There's no real state change to apply here (the animation data already arrived
    -- separately via Server_GameCustomMessage), so this event has empty TerritoryModifications -
    -- just enough identity (Message) for Client_Visual to recognise and draw it. VisibleToOpt is
    -- set explicitly to the ordering player: leaving it empty only works for events whose
    -- TerritoryModifications imply who should see them, which doesn't apply to a pure-visual event.
    local event = WL.GameOrderEvent.Create(order.PlayerID, PAYLOAD_PREFIX, { order.PlayerID }, {});
    addNewOrder(event);
end
