require("IO.ModAuth");
require("ModConstants");

---Server_AdvanceTurn_Start hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
function Server_AdvanceTurn_Start(game, addNewOrder)
    IO.ModAuth.Reset(); -- guarantees auth tokens are reset
end

---Server_AdvanceTurn_Order
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl)
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
    -- the handshake with the other mod, and orders it has authenticated with this mod
    local handled = IO.ModAuth.ProcessOrder(
        order,
        addNewOrder,
        skipThisOrder,
        function(senderModKey, data, authenticatedOrder) OnAuthenticatedOrderReceived(senderModKey, data, authenticatedOrder, addNewOrder);end
    );
    if (handled) then return; end

    -- an order made from this mod's menu, it asks this mod to send a test order
    if (order.proxyType == 'GameOrderCustom') then
        if (order.Payload == SEND_ORDER_PAYLOAD) then
            SendOrderToOtherMod(order.PlayerID, addNewOrder);
        elseif (order.Payload == SEND_SELF_ORDER_PAYLOAD) then
            SendOrderToSelf(order.PlayerID, addNewOrder);
        end
    end
end

---Sends the other mod an authenticated test order
---@param playerID PlayerID # The player who made the order in the menu
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
function SendOrderToOtherMod(playerID, addNewOrder)
    local sent = IO.ModAuth.Send(OTHER_MOD_KEY, playerID, { Message = "Hello from " .. THIS_MOD_KEY }, addNewOrder);
    if (not sent) then
        AddLogOrder(playerID, THIS_MOD_KEY .. " could not send the test order to " .. OTHER_MOD_KEY, addNewOrder);
    end
end

---Sends this mod an authenticated test order
---@param playerID PlayerID # The player who made the order in the menu
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
function SendOrderToSelf(playerID, addNewOrder)
    local sent = IO.ModAuth.SendSelf(playerID, { Message = "Hello from " .. THIS_MOD_KEY .. " to itself" }, addNewOrder);
    if (not sent) then
        AddLogOrder(playerID, THIS_MOD_KEY .. " could not send the test order to itself", addNewOrder);
    end
end

---Called for each authenticated order sent to this mod, by the other mod or by itself, it adds an order saying it arrived
---@param senderModKey ModKey
---@param data table -- the data sent with the order, without the auth headers
---@param order GameOrderCustom # The authenticated order
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
function OnAuthenticatedOrderReceived(senderModKey, data, order, addNewOrder)
    -- only orders from this mod itself or the mod it is being tested with
    if (senderModKey ~= THIS_MOD_KEY and senderModKey ~= OTHER_MOD_KEY) then return; end

    AddLogOrder(order.PlayerID, THIS_MOD_KEY .. " received an authenticated order from " .. senderModKey .. ": " .. tostring(data.Message), addNewOrder);
end

---Adds an order whose message shows in the order list
---@param playerID PlayerID
---@param message string
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
function AddLogOrder(playerID, message, addNewOrder)
    addNewOrder(WL.GameOrderCustom.Create(playerID, message, RECEIPT_PAYLOAD, nil));
end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
function Server_AdvanceTurn_End(game, addNewOrder)
    ReportUnansweredAuths(game, addNewOrder);
end

---Adds an error event, shown to every player, for each mod this mod called that never answered
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
function ReportUnansweredAuths(game, addNewOrder)
    local unansweredModKeys = IO.ModAuth.GetUnansweredAuths();
    if (#unansweredModKeys == 0) then return; end

    local playerIDs = GetPlayingPlayerIDs(game);
    if (#playerIDs == 0) then return; end

    -- the end of the turn has no order to take a player from, so the events are made as the first player in the game
    for _, unansweredModKey in ipairs(unansweredModKeys) do
        local message = "ERROR: " .. THIS_MOD_KEY .. " never got an answer from " .. unansweredModKey .. ". Is it installed, and does it call ModAuth.ProcessOrder?";
        addNewOrder(WL.GameOrderEvent.Create(playerIDs[1], message, playerIDs, {}));
    end
end

---Returns the IDs of every player still playing the game
---@param game GameServerHook
---@return PlayerID[]
function GetPlayingPlayerIDs(game)
    local playerIDs = {};
    for playerID, _ in pairs(game.ServerGame.Game.PlayingPlayers) do
        table.insert(playerIDs, playerID);
    end
    return playerIDs;
end
