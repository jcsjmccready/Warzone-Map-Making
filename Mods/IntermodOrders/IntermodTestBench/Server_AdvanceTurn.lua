require("IO.ModAuth");
require("IO.Reader");
require("IO.Writer");
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
    -- the handshake with whatever mod this bench is pretending to be, and orders it has authenticated with this mod
    local handled = IO.ModAuth.ProcessOrder(
        order,
        addNewOrder,
        skipThisOrder,
        function(senderModKey, data, authenticatedOrder) OnAuthenticatedOrderReceived(senderModKey, data, authenticatedOrder, addNewOrder); end
    );
    if (handled) then return; end

    -- an order made from this mod's menu, it asks this mod to send a made-up test order to whatever target the player entered
    if (order.proxyType == 'GameOrderCustom' and string.sub(order.Payload, 1, #SEND_ORDER_PREFIX) == SEND_ORDER_PREFIX) then
        SendSimulatedOrder(order, addNewOrder);
        return;
    end
end

---Decodes the menu's payload and forwards the data to whatever target mod key the player typed in
---@param order GameOrderCustom
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
function SendSimulatedOrder(order, addNewOrder)
    local payload = IO.Reader.Read(string.sub(order.Payload, #SEND_ORDER_PREFIX + 1), "table");
    if (type(payload) ~= "table" or type(payload.TargetModKey) ~= "string" or type(payload.Data) ~= "table") then
        AddLogOrder(order.PlayerID, THIS_MOD_KEY .. " could not read the simulated order's data", addNewOrder);
        return;
    end

    local sent = IO.ModAuth.Send(payload.TargetModKey, order.PlayerID, payload.Data, addNewOrder);
    if (not sent) then
        AddLogOrder(order.PlayerID, THIS_MOD_KEY .. " could not send the simulated order to " .. payload.TargetModKey, addNewOrder);
    end
end

---Called for each authenticated order sent to this mod, by the mod it called or by itself, it adds an order saying it arrived
---@param senderModKey ModKey
---@param data table -- the data sent with the order, without the auth headers
---@param order GameOrderCustom # The authenticated order
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
function OnAuthenticatedOrderReceived(senderModKey, data, order, addNewOrder)
    AddLogOrder(order.PlayerID, THIS_MOD_KEY .. " received an authenticated order from " .. senderModKey .. ": " .. IO.Writer.Write(data), addNewOrder);
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
