require("Utilities");
require("IO.ModAuth");
require("Interface");
require("Application");
require("Api");

---Server_AdvanceTurn_Start hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_Start(game, addNewOrder)
	IO.ModAuth.Reset(); -- guarantees auth tokens are reset

	SpyPlaneApplication.RemoveExpiredSpyPlaneVisionFogMods(addNewOrder);
	SpyPlaneApplication.AdvanceActiveSpyPlaneFlights(game, addNewOrder);
end

---Server_AdvanceTurn_Order hook
---TODO: Spy Plane's Segment-based Steps flight style not yet implemented (Distance-based Steps grants vision one
---strip at a time as the plane advances each turn; Instant grants it all at once).
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
	-- authenticated orders, whether self-sent or sent by another mod via IO.ModAuth.Send - see Api.lua
	if (SpyPlaneApi.HandleOrder(order, game, addNewOrder, skipThisOrder)) then
		return;
	end

	if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, "FlySpyPlane_")) then
		---@cast order GameOrderPlayCardCustom
		local ids = split(string.sub(order.ModData, string.len("FlySpyPlane_") + 1), "_");
		local startTerritoryID = tonumber(ids[1]) or 0;
		local endTerritoryID = tonumber(ids[2]) or 0;
		SpyPlaneApplication.FlySpyPlane(game, addNewOrder, order.PlayerID, startTerritoryID, endTerritoryID, order.Description);
	end

	if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, "FlySpyPlaneCircle_")) then
		---@cast order GameOrderPlayCardCustom
		local ids = split(string.sub(order.ModData, string.len("FlySpyPlaneCircle_") + 1), "_");
		local centerTerritoryID = tonumber(ids[1]) or 0;
		local radius = tonumber(ids[2]) or 1;
		local direction = tonumber(ids[3]) or 1;
		SpyPlaneApplication.FlySpyPlaneCircle(game, addNewOrder, order.PlayerID, centerTerritoryID, radius, direction, order.Description);
	end
end
