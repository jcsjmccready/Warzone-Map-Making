require("Utilities");
require("IO.ModAuth");
require("Api");
require("Application");

---Server_AdvanceTurn_Start hook.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Start(game, addNewOrder)
    IO.ModAuth.Reset(); -- guarantees auth tokens are reset
    PointsOfInterestApplication.ApplyInitialPointOfInterestVisibility(game, addNewOrder);
end

---Server_AdvanceTurn_Order hook. Builds a Point of Interest when a purchase order is processed
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl)
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
    -- authenticated orders, whether self-sent or sent by another mod via IO.ModAuth.Send - see Api.lua
    if (PointsOfInterestApi.HandleOrder(order, game, addNewOrder, skipThisOrder)) then
        return;
    end

    if (order.proxyType ~= 'GameOrderCustom') then
        return;
    end

    local name, territoryID = ParseBuildPayload(order.Payload);
    if (name == nil) then
        return;
    end

    local territoryDetails = game.Map.Territories[territoryID];
    if (not IsNatoName(name) or territoryDetails == nil) then
        -- malformed order; skipping it means the player isn't charged for it
        skipThisOrder(WL.ModOrderControl.Skip);
        return;
    end

    PointsOfInterestApplication.AddPointOfInterest(game, addNewOrder, order.PlayerID, name, territoryID);
end
