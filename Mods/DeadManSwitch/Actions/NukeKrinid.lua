require("Actions.Actions");

Actions.NukeKrinid = {};

---Fires a nuke on the captured territory for each DMS, via the Nuke mod by Krinid
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

	for _ = 1, numberOfDMS do
		local payload = "Nuke|Invoke|" .. attackingPlayer .. "|" .. defendingPlayer .. "|" .. order.To;
		addNewOrder(WL.GameOrderCustom.Create(nukingPlayer, "Firing Nuke", payload, nil));
	end
end
