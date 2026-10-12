require("Utilities");
require("IO.ModAuth");
require("Api");
require("Application");

---Server_AdvanceTurn_Start hook.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Start(game, addNewOrder)
    IO.ModAuth.Reset(); -- guarantees auth tokens are reset
end

---Server_AdvanceTurn_Order
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl)
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
    -- authenticated orders, whether self-sent below or sent by another mod via IO.ModAuth.Send - see Api.lua
    if (DeadManSwitchApi.HandleOrder(order, game, addNewOrder, skipThisOrder)) then
        return;
    end

    if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, "CreateDMS_")) then
        local targetTerritoryID = tonumber(string.sub(order.ModData, 11));
        DeadManSwitchApplication.QueueDeadManSwitchBuild(order.PlayerID, targetTerritoryID, order.Description);
        return;
    end

    if (order.proxyType == 'GameOrderCustom' and startsWith(order.Payload, "CreateDMS_")) then
        local targetTerritoryID = tonumber(string.sub(order.Payload, 11));
        DeadManSwitchApplication.QueueDeadManSwitchBuild(order.PlayerID, targetTerritoryID, order.Message);
        return;
    end

    -- a successful attack against a territory protected by a Dead Man's Switch
    if (order.proxyType == 'GameOrderAttackTransfer' and result.IsAttack and result.IsSuccessful) then
        ---@cast order GameOrderAttackTransfer
        ---@cast result GameOrderAttackTransferResult
        DeadManSwitchApplication.HandleSuccessfulAttack(game, order, result, addNewOrder);
        return;
    end
end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_End(game, addNewOrder)
    DeadManSwitchApplication.BuildQueuedDeadManSwitches(game, addNewOrder);
    DeadManSwitchApplication.PlayPendingBlockades(addNewOrder);
    DeadManSwitchApplication.PlayPendingDiplomacy(addNewOrder);
end
