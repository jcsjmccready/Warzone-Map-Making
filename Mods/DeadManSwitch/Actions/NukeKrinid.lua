require("Actions.Actions");
require("Utilities.CommonUtils");
require("IO.ModAuth");

Actions.NukeKrinid = {};

local NUKE_MOD_KEY = "Nuke_Krinid";

---The data the Nuke mod receives as the authenticated order
---@class NukeInvokeData
---@field Action "Invoke"
---@field Nuker PlayerID
---@field Nukee PlayerID
---@field TerritoryID TerritoryID

---Asks the Nuke mod by Krinid to fire a nuke on the captured territory for each DMS, the nuke is sent once it has answered our ModAuth call
---@param territoryModification TerritoryModification
---@param game GameServerHook
---@param order GameOrderAttackTransfer
---@param result GameOrderAttackTransferResult
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param numberOfDMS integer
function Actions.NukeKrinid.Trigger(territoryModification, game, order, result, addNewOrder, numberOfDMS)
	local defendingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.To].OwnerPlayerID;
	local attackingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.From].OwnerPlayerID;

	-- GameOrderCustom can't be issued as neutral, so if the DMS's territory was already neutral, let the attacker nuke themself instead
	local nukingPlayer = defendingPlayer;
	if (defendingPlayer == WL.PlayerID.Neutral) then nukingPlayer = attackingPlayer; end

	AddTriggeredEvent(order, territoryModification, addNewOrder);

	---@type NukeInvokeData
	local invoke = { Action = "Invoke", Nuker = attackingPlayer, Nukee = defendingPlayer, TerritoryID = order.To };

	for _ = 1, numberOfDMS do
		-- the nuke is only sent once the Nuke mod has answered this call, see ModAuth
		local sent = IO.ModAuth.Send(NUKE_MOD_KEY, nukingPlayer, invoke, addNewOrder);
		if(not sent) then
			local failEvent = WL.GameOrderEvent.Create(order.PlayerID, "Error sending nuke request", {}, {territoryModification});
			failEvent.Icon = "TriggeredFailed";
			addNewOrder(failEvent, true);
		end
	end
end