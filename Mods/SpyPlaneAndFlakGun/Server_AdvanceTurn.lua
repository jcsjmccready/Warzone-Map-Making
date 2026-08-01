require("Utilities");

---Server_AdvanceTurn_Order hook
---TODO: gameplay effect for Spy Plane / Flak Gun not yet implemented - this mod currently only scaffolds the
---Configure UI (include checkboxes + standard card piece options) and card registration.
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
end
