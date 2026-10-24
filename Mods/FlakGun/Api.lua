require("IO.ModAuth");
require("IO.ApiBase");
require("Interface");
require("Application");

----------------------------------------------------------------------------------------------------------------------
-- Flak Gun's public ModAuth API
--
-- To call any action below, send a ModAuth order such as the below:
--   IO.ModAuth.Send(IO.ModAuth.LOCAL_MOD_KEY for targetted mod, playerID, data, addNewOrder);
-- e.g. for FlakGunFireFlakGunDto: data = { Action = FlakGunActions.FireFlakGun, TerritoryID = 4 }.
----------------------------------------------------------------------------------------------------------------------

FLAK_GUN_API_VERSION = 1;

FlakGunApi = IO.ApiBase.New();

---@param data FlakGunFireFlakGunDto
---@param order GameOrderCustom
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
local function HandleFireFlakGun(data, order, game, addNewOrder)
	if (not FlakGunApi.ValidateFields(FlakGunActions.FireFlakGun, data, order, addNewOrder, {
		{ Name = "TerritoryID", Type = "number", Required = true },
	})) then return; end;

	FlakGunApplication.FireFlakGun(game, addNewOrder, order.PlayerID, data.TerritoryID, "Fired a Flak Gun via another mod", false);
end
FlakGunApi.Register(FlakGunActions.FireFlakGun, HandleFireFlakGun);
