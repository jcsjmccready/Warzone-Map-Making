require("Utilities");
require("Server_AdvanceTurn_V1");
require("Server_AdvanceTurn_V2");

---Server_AdvanceTurn_Order
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
	local version = Mod.Settings.Version or 1;

	if (version < 2) then
		V1.Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder);
	else
		V2.Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder);
	end
end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_End(game, addNewOrder)
	local version = Mod.Settings.Version or 1;

	if (version < 2) then
		V1.Server_AdvanceTurn_End(game, addNewOrder);
	else
		V2.Server_AdvanceTurn_End(game, addNewOrder);
	end
end
