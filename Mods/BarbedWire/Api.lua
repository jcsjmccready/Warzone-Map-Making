require("IO.ModAuth");
require("IO.ApiBase");
require("Interface");
require("Application_V2");

----------------------------------------------------------------------------------------------------------------------
-- Barbed Wire's public ModAuth API
--
-- To call any action below, send a ModAuth order such as the below:
--   IO.ModAuth.Send(IO.ModAuth.LOCAL_MOD_KEY for targetted mod, playerID, data, addNewOrder);
-- e.g. for BarbedWireAddTrapDto: data = { Action = BarbedWireActions.AddTrap, TrapKey = "BarbedWire", TerritoryID = 4 }.
--
-- Only available on settings version 2+ - see Server_AdvanceTurn.lua.
----------------------------------------------------------------------------------------------------------------------

BARBED_WIRE_API_VERSION = 1;

BarbedWireApi = IO.ApiBase.New();

---Resolves data.TrapKey into a V2_TrapType, rejecting (with a message visible to the sender) if the key is
---unrecognized or that trap type is disabled in this game's configuration (Mod.Settings.Include<Key>).
---@param action BarbedWireAction
---@param data table
---@param order GameOrderCustom
---@param addNewOrder fun(order: GameOrder)
---@return V2_TrapType | nil
local function ResolveEnabledTrapType(action, data, order, addNewOrder)
	local trapType = V2.GetTrapTypeByKey(data.TrapKey);
	if (trapType == nil) then
		local message = IO.ModAuth.LOCAL_MOD_KEY .. " rejected " .. action .. ": unrecognized TrapKey '" .. tostring(data.TrapKey) .. "'";
		addNewOrder(WL.GameOrderEvent.Create(WL.PlayerID.Neutral, message, { order.PlayerID }, {}));
		return nil;
	end

	if (not V2.IsTrapTypeEnabled(trapType)) then
		local message = IO.ModAuth.LOCAL_MOD_KEY .. " rejected " .. action .. ": " .. trapType.Key .. " is not enabled";
		addNewOrder(WL.GameOrderEvent.Create(WL.PlayerID.Neutral, message, { order.PlayerID }, {}));
		return nil;
	end

	return trapType;
end

---@param data BarbedWireAddTrapDto
---@param order GameOrderCustom
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
local function HandleAddTrap(data, order, game, addNewOrder)
	if (not BarbedWireApi.ValidateFields(BarbedWireActions.AddTrap, data, order, addNewOrder, {
		{ Name = "TrapKey", Type = "string", Required = true },
		{ Name = "TerritoryID", Type = "number", Required = true },
		{ Name = "IsImmediate", Type = "boolean", Required = false },
	})) then return; end;

	local trapType = ResolveEnabledTrapType(BarbedWireActions.AddTrap, data, order, addNewOrder);
	if (trapType == nil) then return; end;

	if (data.IsImmediate) then
		V2.AddTrapImmediately(trapType, game, addNewOrder, order.PlayerID, data.TerritoryID, "Built a " .. trapType.DisplayName .. " via another mod");
	else
		V2.QueuePendingTrap(trapType, order.PlayerID, data.TerritoryID, "Built a " .. trapType.DisplayName .. " via another mod", false);
	end
end
BarbedWireApi.Register(BarbedWireActions.AddTrap, HandleAddTrap);

---Triggers a trap on a territory, independent of the normal attack/transfer flow
---@param data BarbedWireTriggerTrapDto
---@param order GameOrderCustom
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
local function HandleTriggerTrap(data, order, game, addNewOrder)
	if (not BarbedWireApi.ValidateFields(BarbedWireActions.TriggerTrap, data, order, addNewOrder, {
		{ Name = "TrapKey", Type = "string", Required = true },
		{ Name = "TerritoryID", Type = "number", Required = true },
	})) then return; end;

	local trapType = ResolveEnabledTrapType(BarbedWireActions.TriggerTrap, data, order, addNewOrder);
	if (trapType == nil) then return; end;

	V2.TriggerTrap(trapType, game, addNewOrder, data.TerritoryID, order.PlayerID);
end
BarbedWireApi.Register(BarbedWireActions.TriggerTrap, HandleTriggerTrap);

---Resets a triggered trap on a territory back to primed, independent of its normal trigger-duration expiry
---@param data BarbedWireResetTrapDto
---@param order GameOrderCustom
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
local function HandleResetTrap(data, order, game, addNewOrder)
	if (not BarbedWireApi.ValidateFields(BarbedWireActions.ResetTrap, data, order, addNewOrder, {
		{ Name = "TrapKey", Type = "string", Required = true },
		{ Name = "TerritoryID", Type = "number", Required = true },
	})) then return; end;

	local trapType = ResolveEnabledTrapType(BarbedWireActions.ResetTrap, data, order, addNewOrder);
	if (trapType == nil) then return; end;

	V2.ResetTrap(trapType, game, addNewOrder, data.TerritoryID, order.PlayerID);
end
BarbedWireApi.Register(BarbedWireActions.ResetTrap, HandleResetTrap);

---Removes any Primed/Triggered trap of the given type on a territory outright
---@param data BarbedWireDestroyTrapDto
---@param order GameOrderCustom
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
local function HandleDestroyTrap(data, order, game, addNewOrder)
	if (not BarbedWireApi.ValidateFields(BarbedWireActions.DestroyTrap, data, order, addNewOrder, {
		{ Name = "TrapKey", Type = "string", Required = true },
		{ Name = "TerritoryID", Type = "number", Required = true },
	})) then return; end;

	local trapType = ResolveEnabledTrapType(BarbedWireActions.DestroyTrap, data, order, addNewOrder);
	if (trapType == nil) then return; end;

	local primedStructId, triggeredStructId = V2.GetStructureIds(trapType);
	local privateGameData = Mod.PrivateGameData --[[@as V2_PrivateGameData]];
	local existingStructures = game.ServerGame.LatestTurnStanding.Territories[data.TerritoryID].Structures;

	local newStructures = V2.DestroyTrapAt(trapType, data.TerritoryID, existingStructures, primedStructId, triggeredStructId, privateGameData, order.PlayerID, addNewOrder);
	if (newStructures ~= nil) then
		Mod.PrivateGameData = privateGameData;
	end
end
BarbedWireApi.Register(BarbedWireActions.DestroyTrap, HandleDestroyTrap);
