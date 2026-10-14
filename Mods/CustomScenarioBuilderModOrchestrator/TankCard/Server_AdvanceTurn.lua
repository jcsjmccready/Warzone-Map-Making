require('Utilities');

function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
	if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, 'CreateTank_')) then
		local terrID = tonumber(string.sub(order.ModData, 12));

		local pendingTank = {};
		pendingTank.PlayerID = order.PlayerID;
		pendingTank.Message = order.Description;
		pendingTank.TerritoryID = terrID;

		local priv = Mod.PrivateGameData;
		if (priv.PendingTanks == nil) then priv.PendingTanks = {}; end;
		table.insert(priv.PendingTanks, pendingTank);
		Mod.PrivateGameData = priv;
	end
end

function Server_AdvanceTurn_End(game, addNewOrder)
	BuildTanks(game, addNewOrder);
end

function BuildTanks(game, addNewOrder)
	local priv = Mod.PrivateGameData;
	local pending = priv.PendingTanks;
	if (pending == nil) then return; end;

	for _, pendingTank in pairs(pending) do
		local territory = game.ServerGame.LatestTurnStanding.Territories[pendingTank.TerritoryID];

		-- Only build if the player still controls the territory
		if (territory ~= nil and territory.OwnerPlayerID == pendingTank.PlayerID) then
			local tank = BuildTank(pendingTank.PlayerID);

			local terrMod = WL.TerritoryModification.Create(pendingTank.TerritoryID);
			terrMod.AddSpecialUnits = { tank };

			local td = game.Map.Territories[pendingTank.TerritoryID];
			local event = WL.GameOrderEvent.Create(pendingTank.PlayerID, pendingTank.Message, {}, {terrMod});
			event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
			event.TerritoryAnnotationsOpt = { [pendingTank.TerritoryID] = WL.TerritoryAnnotation.Create("Tank built") };

			addNewOrder(event);
		end
	end

	priv.PendingTanks = nil;
	Mod.PrivateGameData = priv;
end
