require('Utilities');

function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
	if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, 'CreateSpecialUnitExample_')) then
		local terrID = tonumber(string.sub(order.ModData, 26));

		local pendingSpecialUnitExample = {};
		pendingSpecialUnitExample.PlayerID = order.PlayerID;
		pendingSpecialUnitExample.Message = order.Description;
		pendingSpecialUnitExample.TerritoryID = terrID;

		local priv = Mod.PrivateGameData;
		if (priv.PendingSpecialUnitExamples == nil) then priv.PendingSpecialUnitExamples = {}; end;
		table.insert(priv.PendingSpecialUnitExamples, pendingSpecialUnitExample);
		Mod.PrivateGameData = priv;
	end
end

function Server_AdvanceTurn_End(game, addNewOrder)
	BuildSpecialUnitExamples(game, addNewOrder);
end

function BuildSpecialUnitExamples(game, addNewOrder)
	local priv = Mod.PrivateGameData;
	local pending = priv.PendingSpecialUnitExamples;
	if (pending == nil) then return; end;

	for _, pendingSpecialUnitExample in pairs(pending) do
		local territory = game.ServerGame.LatestTurnStanding.Territories[pendingSpecialUnitExample.TerritoryID];

		-- Only build if the player still controls the territory
		if (territory ~= nil and territory.OwnerPlayerID == pendingSpecialUnitExample.PlayerID) then
			local specialUnitExample = BuildSpecialUnitExample(pendingSpecialUnitExample.PlayerID);

			local terrMod = WL.TerritoryModification.Create(pendingSpecialUnitExample.TerritoryID);
			terrMod.AddSpecialUnits = { specialUnitExample };

			local td = game.Map.Territories[pendingSpecialUnitExample.TerritoryID];
			local event = WL.GameOrderEvent.Create(pendingSpecialUnitExample.PlayerID, pendingSpecialUnitExample.Message, {}, {terrMod});
			event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
			event.TerritoryAnnotationsOpt = { [pendingSpecialUnitExample.TerritoryID] = WL.TerritoryAnnotation.Create("SpecialUnitExample built") };

			addNewOrder(event);
		end
	end

	priv.PendingSpecialUnitExamples = nil;
	Mod.PrivateGameData = priv;
end
