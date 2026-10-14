require("Utilities");
require("Application");

---Server_AdvanceTurn_Order hook. Queues a Tank build when the Tank card's order is played.
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl)
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
    if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, "CreateTank_")) then
        local targetTerritoryID = tonumber(string.sub(order.ModData, 12));
        TankCardApplication.QueueTankBuild(order.PlayerID, targetTerritoryID, order.Description);
        return;
    end
end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_End(game, addNewOrder)
    TankCardApplication.BuildQueuedTanks(game, addNewOrder);
end
