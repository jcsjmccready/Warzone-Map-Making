require('Utilities');

function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
	--Check if we see a Build CustomStructureExample event, and build it immediately if so.
	if (order.proxyType == 'GameOrderCustom' and startsWith(order.Payload, 'BuildCustomStructureExample_')) then  --look for the order that we inserted in Client_PresentMenuUI
		--Extract territory ID from the payload
		local terrID = tonumber(string.sub(order.Payload, 29));

		local structureID = WL.StructureType.Custom("CustomStructureExample"); --matches to StructureImages/CustomStructureExample.png
		local structures = game.ServerGame.LatestTurnStanding.Territories[terrID].Structures;
		if (structures == nil) then structures = {}; end;
		structures[structureID] = (structures[structureID] or 0) + 1;

		local terrMod = WL.TerritoryModification.Create(terrID);
		terrMod.SetStructuresOpt = structures;

		local event = WL.GameOrderEvent.Create(order.PlayerID, "Built CustomStructureExample", {}, {terrMod});

		local td = game.Map.Territories[terrID];
		event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
		event.TerritoryAnnotationsOpt = { [terrID] = WL.TerritoryAnnotation.Create("Built CustomStructureExample") };

		addNewOrder(event);
	end
end
