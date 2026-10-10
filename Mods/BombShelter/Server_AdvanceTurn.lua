require("Utilities");
require("IO.ModAuth");
require("Api");
require("Application");

----------------------------------------------------------------------------------------------------------------------
-- This file is BombShelter's API layer: it only recognizes what an incoming order is asking for (a legacy card/commerce
-- build order, a bomb card, or an authenticated ModAuth order) and calls the matching BombShelterApplication.* function
-- with plain, already-extracted arguments. The actual game-state mutations live in Application.lua.
----------------------------------------------------------------------------------------------------------------------

---Server_AdvanceTurn_Start hook.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Start(game, addNewOrder)
    IO.ModAuth.Reset(); -- guarantees auth tokens are reset
end

---Server_AdvanceTurn_Order hook. Recognizes four unrelated order shapes that all route through this same hook:
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl)
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
    -- authenticated orders, whether self-sent by BombShelterApplication.HandleBombAgainstBombShelter or sent by another
    -- mod via IO.ModAuth.Send - see Api.lua
    if (BombShelterApi.HandleOrder(order, game, addNewOrder, skipThisOrder)) then
        return;
    end

    if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, "BombShelter_")) then
        local targetTerritoryID = tonumber(string.sub(order.ModData, 13));
        BombShelterApplication.QueueBombShelterBuild(order.PlayerID, targetTerritoryID);
        return;
    end

    if (order.proxyType == 'GameOrderCustom' and startsWith(order.Payload, "BombShelter_")) then
        local targetTerritoryID = tonumber(string.sub(order.Payload, 13));
        BombShelterApplication.QueueBombShelterBuild(order.PlayerID, targetTerritoryID);
        return;
    end

    if (order.proxyType == 'GameOrderPlayCardBomb') then
        BombShelterApplication.HandleBombAgainstBombShelter(game, order, addNewOrder);
        return;
    end
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_End(game, addNewOrder)
    BombShelterApplication.RemoveExpiredBombShelters(game, addNewOrder);
    BombShelterApplication.BuildQueuedBombShelters(game, addNewOrder);
end
