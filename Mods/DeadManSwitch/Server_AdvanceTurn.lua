require("Utilities");

-- todo:
-- add config option for choice being bomb card is played
-- add config option for dealing damage
-- add config option for neutralise
-- add team support with config option to disable team support
-- consider if actual armies includes special units
-- art
-- commerce support
-- remove request a dms annotation, add an annotation if the dms is not built because the player lost control of the territory


function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)

    if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, "CreateDMS_")) then

        local targetTerritoryID = tonumber(string.sub(order.ModData, 11))
		if (game.ServerGame.LatestTurnStanding.Territories[targetTerritoryID].OwnerPlayerID ~= order.PlayerID) then
			return; --not our territory
		end

		-- store pending build orders for end of turn
		local pendingDMS = {};
		pendingDMS.PlayerID = order.PlayerID;
		pendingDMS.Message = order.Description;
		pendingDMS.TerritoryID = targetTerritoryID;

		local privateGameData = Mod.PrivateGameData;
		if (privateGameData.PendingDMS == nil) then privateGameData.PendingDMS = {}; end;
		table.insert(privateGameData.PendingDMS, pendingDMS);

		Mod.PrivateGameData = privateGameData;
    end


	-- --Check if this is an attack against a territory with a fort.
	if (order.proxyType == 'GameOrderAttackTransfer' and result.IsAttack and result.IsSuccessful) then
        local structureID = WL.StructureType.Custom("DmsStructure");
        local structures = game.ServerGame.LatestTurnStanding.Territories[order.To].Structures;

		if (structures == nil) then return; end;

        local numberOfDMS = 0;
		if (structures[structureID] ~= nil) then
			numberOfDMS = numberOfDMS + structures[structureID];
		end

		--If no DMS here, abort.
		if (numberOfDMS == 0) then return; end;

        --If an attack of 0, abort, so skipped orders don't destroy the DMS
		if (result.ActualArmies.IsEmpty) then return; end;

        structures[structureID] = structures[structureID] - 1;

        local territoryModification = WL.TerritoryModification.Create(order.To);
		territoryModification.SetStructuresOpt = structures;
		addNewOrder(WL.GameOrderEvent.Create(order.PlayerID, "Triggered a Dead Man's Switch", {}, {territoryModification}), true);

        local defendingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.To].OwnerPlayerID;

		-- unable to programatically play cards without them being enabled
        if game.Settings.Cards ~= nil and game.Settings.Cards[WL.CardID.Bomb] ~= nil then
            local instance = WL.NoParameterCardInstance.Create(WL.CardID.Bomb);
            addNewOrder(WL.GameOrderReceiveCard.Create(defendingPlayer, {instance}));
            addNewOrder(WL.GameOrderPlayCardBomb.Create(instance.ID, defendingPlayer, order.To));
		else
			addNewOrder(WL.GameOrderEvent.Create(order.PlayerID, "Bomb card not available - DMS cancelled", {}, {territoryModification}), true); -- this should be impossible to reach but safety net
        end
    end
end

function Server_AdvanceTurn_End(game, addNewOrder)
	BuildStructures(game, addNewOrder);
end


function BuildStructures(game, addNewOrder)

	local structureID = WL.StructureType.Custom("DmsStructure");

	local privateGameData = Mod.PrivateGameData;
	local pending = privateGameData.PendingDMS;

	if (pending == nil) then return; end;

	-- Remove any pending builds where the player lost control of the territory, so we don't build a DMS for the new owner
	removeWhere(pending, function(t) return t.PlayerID ~= game.ServerGame.LatestTurnStanding.Territories[t.TerritoryID].OwnerPlayerID; end);

	-- We will now build a DMS for each pending DMS. However, we need to take care to ensure that if there are two build orders for the same territory that we build both of them,
	--	so we first group by the territory ID so we get all build orders for the same territory together.
	for territoryID,pendingDmsGroup in pairs(groupBy(pending, function(t) return t.TerritoryID; end)) do

		local numDmsToBuild = #pendingDmsGroup;

		local structures = game.ServerGame.LatestTurnStanding.Territories[territoryID].Structures;

		if (structures == nil) then structures = {}; end;
		if (structures[structureID] == nil) then
			structures[structureID] = numDmsToBuild;
		else
			structures[structureID] = structures[structureID] + numDmsToBuild;
		end


		local territoryModification = WL.TerritoryModification.Create(territoryID);
		territoryModification.SetStructuresOpt = structures;

		local pendingDms = first(pendingDmsGroup);

		local event = WL.GameOrderEvent.Create(pendingDms.PlayerID, pendingDms.Message, {}, {territoryModification});

		local td = game.Map.Territories[territoryID];
		event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
		event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Build Dead Man's Switch") };

		addNewOrder(event);
	end

	privateGameData.PendingDMS = nil;
	Mod.PrivateGameData = privateGameData;
end