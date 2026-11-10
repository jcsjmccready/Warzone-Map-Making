require("IO.ModAuth");
require("IO.ApiBase");
require("Interface");
require("Application");

----------------------------------------------------------------------------------------------------------------------
-- Spy Plane's public ModAuth API
--
-- To call any action below, send a ModAuth order such as the below:
--   IO.ModAuth.Send(IO.ModAuth.LOCAL_MOD_KEY for targetted mod, playerID, data, addNewOrder);
-- e.g. for SpyPlaneFlySpyPlaneDto: data = { Action = SpyPlaneActions.FlySpyPlane, StartTerritoryID = 4, EndTerritoryID = 9 }.
----------------------------------------------------------------------------------------------------------------------

SPY_PLANE_API_VERSION = 1;

SpyPlaneApi = IO.ApiBase.New();

---@param data SpyPlaneFlySpyPlaneDto
---@param order GameOrderCustom
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
local function HandleFlySpyPlane(data, order, game, addNewOrder)
	if (not SpyPlaneApi.ValidateFields(SpyPlaneActions.FlySpyPlane, data, order, addNewOrder, {
		{ Name = "StartTerritoryID", Type = "number", Required = true },
		{ Name = "EndTerritoryID", Type = "number", Required = true },
	})) then return; end;

	SpyPlaneApplication.FlySpyPlane(game, addNewOrder, order.PlayerID, data.StartTerritoryID, data.EndTerritoryID, "Flew a Spy Plane via another mod");
end
SpyPlaneApi.Register(SpyPlaneActions.FlySpyPlane, HandleFlySpyPlane);
