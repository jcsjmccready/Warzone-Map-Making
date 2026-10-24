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

	-- Flak Guns only intercept airlifts fired during the same turn they're set up, so the active list never
	-- carries over from one turn to the next
	local priv = Mod.PrivateGameData --[[@as FlakGunPrivateGameData]];
	priv.ActiveFlakGuns = {};
	Mod.PrivateGameData = priv;
end

---Server_AdvanceTurn_Order hook
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
	-- authenticated orders, whether self-sent or sent by another mod via IO.ModAuth.Send - see Api.lua
	if (FlakGunApi.HandleOrder(order, game, addNewOrder, skipThisOrder)) then
		return;
	end

	if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, "ShootFlakGun_")) then
		---@cast order GameOrderPlayCardCustom
		local targetTerritoryID = tonumber(string.sub(order.ModData, string.len("ShootFlakGun_") + 1)) or 0;
		local isOriginalCard = order.CustomCardID == Mod.Settings.FlakGunCardID;
		FlakGunApplication.FireFlakGun(game, addNewOrder, order.PlayerID, targetTerritoryID, order.Description, isOriginalCard);
		return;
	end

	if (order.proxyType == 'GameOrderPlayCardAirlift') then
		---@cast order GameOrderPlayCardAirlift
		---@cast result GameOrderPlayCardAirliftResult
		FlakGunApplication.HandleAirliftTargetedByFlakGun(game, order, result, skipThisOrder, addNewOrder);
	end
end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_End(game, addNewOrder)
	FlakGunApplication.DiscardUnusedTemporaryFlakGunCards(game, addNewOrder); -- safety net
	FlakGunApplication.GiveTemporaryFlakGunCards(game, addNewOrder);
end
