require("Utilities");

-- change what phase this mod fear/charms in
-- new art for feature

---@class CharmFearInstance # Active card expire behaviour enums
---@field TerritoryId number # TerritoryId of where the charm/fear is
---@field TurnEnd integer # final turn of the charm/fear instance
---@field AffectedTerritoryDistances table<number, number> # territory id: distance from the source territory along the fear/charm path
---@field PlayerOwnerId number # id of the player that created the instance

---Server_AdvanceTurn_Order
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)

	-- resolve charm/fear the moment the Attacks phase starts: after Deploys/reinforcements have landed,
	-- but before any Attack/Transfer order this turn has a chance to run
	if (order.OccursInPhase == WL.TurnPhase.Attacks and Mod.PrivateGameData.ResolvedForTurn ~= game.Game.TurnNumber) then
		ResolveCharmAndFear(game, addNewOrder);
		local priv = Mod.PrivateGameData;
		priv.ResolvedForTurn = game.Game.TurnNumber;
		Mod.PrivateGameData = priv;
	end

    if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, "CreateFear_")) then
        local targetTerritoryID = tonumber(string.sub(order.ModData, 12)) or 0
		local structureID = WL.StructureType.Custom("Fear");
		if(Mod.Settings.FearDuration == 1) then
			structureID = WL.StructureType.Custom("FadingFear");
		end
		local structures = game.ServerGame.LatestTurnStanding.Territories[targetTerritoryID].Structures;

		if (structures == nil) then structures = {}; end;
		if (structures[structureID] == nil) then
			structures[structureID] = 1;
		else
			structures[structureID] = structures[structureID] + 1;
		end

		local territoryModification = WL.TerritoryModification.Create(targetTerritoryID);
		territoryModification.SetStructuresOpt = structures;
		local event = WL.GameOrderEvent.Create(order.PlayerID, order.Description, {}, {territoryModification});

		local td = game.Map.Territories[targetTerritoryID];
		event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
		event.TerritoryAnnotationsOpt = { [targetTerritoryID] = WL.TerritoryAnnotation.Create("Fear", 8, GetColourIntegerFromHex(BUTTON_COLOURS.ElectricPurple)) };

		addNewOrder(event);

		local priv = Mod.PrivateGameData;
		local fears = priv.Fears or {};

		local territoryDistances = getTerritoriesAndDistance(game, targetTerritoryID, Mod.Settings.FearDistance);

		---@type CharmFearInstance
		local fearInstance = {
			TerritoryId = targetTerritoryID,
			TurnEnd = game.Game.TurnNumber + Mod.Settings.FearDuration - 1,
			AffectedTerritoryDistances = territoryDistances,
			PlayerOwnerId = tonumber(order.PlayerID) or WL.PlayerID.Neutral
		}
		table.insert(fears, fearInstance);
		priv.Fears = fears;
		Mod.PrivateGameData = priv;
    end

     if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, "CreateCharm_")) then
        local targetTerritoryID = tonumber(string.sub(order.ModData, 13)) or 0;
		local structureID = WL.StructureType.Custom("Charm");
		if(Mod.Settings.CharmDuration == 1) then
			structureID = WL.StructureType.Custom("FadingCharm");
		end
		local structures = game.ServerGame.LatestTurnStanding.Territories[targetTerritoryID].Structures;

		if (structures == nil) then structures = {}; end;
		if (structures[structureID] == nil) then
			structures[structureID] = 1;
		else
			structures[structureID] = structures[structureID] + 1;
		end

		local territoryModification = WL.TerritoryModification.Create(targetTerritoryID);
		territoryModification.SetStructuresOpt = structures;
		local event = WL.GameOrderEvent.Create(order.PlayerID, order.Description, {}, {territoryModification});

		local td = game.Map.Territories[targetTerritoryID];
		event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
		event.TerritoryAnnotationsOpt = { [targetTerritoryID] = WL.TerritoryAnnotation.Create("Charm", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Orchid)) };

		addNewOrder(event);

		local priv = Mod.PrivateGameData;
		local charms = priv.Charms or {};

		local territoryDistances = getTerritoriesAndDistance(game, targetTerritoryID, Mod.Settings.CharmDistance);

		---@type CharmFearInstance
		local charmInstance = {
			TerritoryId = targetTerritoryID,
			TurnEnd = game.Game.TurnNumber + Mod.Settings.CharmDuration - 1, -- 1 turn duration means only this turn. i.e. Will go at the end of the current turn after triggering 
			AffectedTerritoryDistances = territoryDistances,
			PlayerOwnerId = tonumber(order.PlayerID) or WL.PlayerID.Neutral
		}
		table.insert(charms, charmInstance);
		priv.Charms = charms;
		Mod.PrivateGameData = priv;
    end
end

---Resolves fear/charm army movement and expiry/fading. Called from Server_AdvanceTurn_Order right as the
---Attacks phase starts (after Deploys, before any Attack/Transfer order this turn), with Server_AdvanceTurn_End
---as a fallback for turns that have no Attack/Transfer order at all.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function ResolveCharmAndFear(game, addNewOrder)
	local priv = Mod.PrivateGameData;
	---@type [CharmFearInstance]
	local fears = priv.Fears or {};

	local structuresByTerritory = {};

	-- iterate in reverse so we can remove
	for i = #fears, 1, -1 do
		local fear = fears[i];
		local fadingStructureID = WL.StructureType.Custom("FadingFear");
		local structureID = WL.StructureType.Custom("Fear");
		local existingStructures = GetTerritoryStructures(game, structuresByTerritory, fear.TerritoryId);

		-- fear ongoing, RUN AWAY!
		for affectedTerritoryId, distanceFromSource in pairs(fear.AffectedTerritoryDistances or {}) do
			local territoryStanding = game.ServerGame.LatestTurnStanding.Territories[affectedTerritoryId];
			local anyArmy = (territoryStanding.NumArmies.NumArmies > 0 or 
				(territoryStanding.NumArmies.SpecialUnits ~= nil and #territoryStanding.NumArmies.SpecialUnits > 0));

			if (territoryStanding ~= nil and territoryStanding.NumArmies ~= nil 
				and territoryStanding.OwnerPlayerID ~= WL.PlayerID.Neutral
				and anyArmy) then
				local normalizedDistance = distanceFromSource or 0;
				local connectedTerritories = game.Map.Territories[affectedTerritoryId].ConnectedTo or {};
				local selectedTerritoryId = 0;

				--determine where the armies flee to
				local selectableOptions = {};
				if(normalizedDistance == Mod.Settings.FearDistance) then -- army runs out of fear range
					for neighbourTerritoryId, _ in pairs(connectedTerritories) do
						if (fear.AffectedTerritoryDistances[neighbourTerritoryId] == nil) then
							table.insert(selectableOptions, neighbourTerritoryId);
							break;
						end
					end
				else --army runs away from fear or to another of same distance if no better choice
					local bestNeighbourDistance = 0;
					for neighbourTerritoryId, _ in pairs(connectedTerritories) do
						local neighbourDistance = fear.AffectedTerritoryDistances[neighbourTerritoryId];
						if (neighbourDistance ~= nil and neighbourDistance > normalizedDistance) then
							if (bestNeighbourDistance == nil or neighbourDistance >= bestNeighbourDistance) then
								if(neighbourDistance > bestNeighbourDistance) then
									selectableOptions = { neighbourTerritoryId };
									bestNeighbourDistance = neighbourDistance;
								elseif(neighbourDistance == bestNeighbourDistance) then
									table.insert(selectableOptions, neighbourTerritoryId);
								end
							end
						end
					end
				end
				if (#selectableOptions > 0) then
					local chosenIndex = math.random(1, #selectableOptions);
					selectedTerritoryId = selectableOptions[chosenIndex];
				end

				-- create movement to selectedTerritoryId
				local territoryOwnerId = territoryStanding.OwnerPlayerID;
				local falloff = (Mod.Settings.FearFalloff or 0);
				local fearPercentage = math.floor(((1 - falloff) ^ (distanceFromSource or 0)) * 100 + 0.5) / 100;
				local areSuImmune = fearPercentage <= (Mod.Settings.FearSpecialUnitThreshold or 0);

				local selectedSpecialUnits = nil;
				if (not areSuImmune and territoryStanding.NumArmies.SpecialUnits ~= nil) then
					selectedSpecialUnits = {};
					for _, specialUnit in ipairs(territoryStanding.NumArmies.SpecialUnits) do
						if (math.random() < fearPercentage) then
							table.insert(selectedSpecialUnits, specialUnit);
						end
					end
				end

				local moveArmiesCount = math.max(0, math.floor(territoryStanding.NumArmies.NumArmies * fearPercentage + 0.5));
				armies = WL.Armies.Create(moveArmiesCount, selectedSpecialUnits);

				local isMovingAnything = moveArmiesCount > 0 or (selectedSpecialUnits ~= nil and #selectedSpecialUnits > 0);
				if (selectedTerritoryId ~= 0 and armies ~= nil and isMovingAnything) then
					local moveOrder = WL.GameOrderAttackTransfer.Create(territoryOwnerId, affectedTerritoryId, selectedTerritoryId, WL.AttackTransferEnum.AttackTransfer, false, armies, false);
					local visibleTo = { territoryOwnerId };
					local event = WL.GameOrderEvent.Create(territoryOwnerId, "Feared", visibleTo, {});
					event.TerritoryAnnotationsOpt = { [affectedTerritoryId] = WL.TerritoryAnnotation.Create("Feared", 8, GetColourIntegerFromHex(BUTTON_COLOURS.ElectricPurple)) };
					addNewOrder(event);
					addNewOrder(moveOrder);
				end
			end
		end

		if(fear.TurnEnd == game.Game.TurnNumber) then
			-- Fear has expired, decrement the structure count by 1
			if (existingStructures[fadingStructureID] ~= nil) then
				existingStructures[fadingStructureID] = math.max(existingStructures[fadingStructureID] - 1, 0);
			end
			local territoryModification = WL.TerritoryModification.Create(fear.TerritoryId);
			territoryModification.SetStructuresOpt = CopyStructures(existingStructures);

			local event = WL.GameOrderEvent.Create(fear.PlayerOwnerId, "Fear wears off in " .. game.Map.Territories[fear.TerritoryId].Name , {}, {territoryModification});
			event.TerritoryAnnotationsOpt = { [fear.TerritoryId] = WL.TerritoryAnnotation.Create("Fear wears off", 8, GetColourIntegerFromHex(BUTTON_COLOURS.ElectricPurple)) };
			addNewOrder(event);
			table.remove(fears, i);
		elseif (fear.TurnEnd == game.Game.TurnNumber + 1) then
			-- convert fear into fading fear
			if (existingStructures[structureID] ~= nil) then
				existingStructures[structureID] = math.max(existingStructures[structureID] - 1, 0);
			end
			if (existingStructures[fadingStructureID] == nil) then
				existingStructures[fadingStructureID] = 1;
			else
				existingStructures[fadingStructureID] = existingStructures[fadingStructureID] + 1;
			end
			local territoryModification = WL.TerritoryModification.Create(fear.TerritoryId);
			territoryModification.SetStructuresOpt = CopyStructures(existingStructures);

			local event = WL.GameOrderEvent.Create(fear.PlayerOwnerId, "Fear begins to fade in " .. game.Map.Territories[fear.TerritoryId].Name, {}, {territoryModification});
			event.TerritoryAnnotationsOpt = { [fear.TerritoryId] = WL.TerritoryAnnotation.Create("Fear fading", 8, GetColourIntegerFromHex(BUTTON_COLOURS.ElectricPurple)) };
			addNewOrder(event);
		end
	end

	---@type [CharmFearInstance]
	local charms = priv.Charms or {};

	for i = #charms, 1, -1 do
		local charm = charms[i];
		local fadingStructureID = WL.StructureType.Custom("FadingCharm");
		local structureID = WL.StructureType.Custom("Charm");
		local existingStructures = GetTerritoryStructures(game, structuresByTerritory, charm.TerritoryId);

		for affectedTerritoryId, distanceFromSource in pairs(charm.AffectedTerritoryDistances or {}) do
			local territoryStanding = game.ServerGame.LatestTurnStanding.Territories[affectedTerritoryId];
			
			local anyArmy = (territoryStanding.NumArmies.NumArmies > 0 or 
				(territoryStanding.NumArmies.SpecialUnits ~= nil and #territoryStanding.NumArmies.SpecialUnits > 0));

			if (territoryStanding ~= nil and territoryStanding.NumArmies ~= nil 
				and territoryStanding.OwnerPlayerID ~= WL.PlayerID.Neutral and anyArmy) then
				local normalizedDistance = distanceFromSource or 0;
				local connectedTerritories = game.Map.Territories[affectedTerritoryId].ConnectedTo or {};
				local selectedTerritoryId = 0;

				if (normalizedDistance > 0) then
					local bestNeighbourDistance = nil;
					for neighbourTerritoryId, _ in pairs(connectedTerritories) do
						local neighbourDistance = charm.AffectedTerritoryDistances[neighbourTerritoryId];
						if (neighbourDistance ~= nil and neighbourDistance < normalizedDistance) then
							if (bestNeighbourDistance == nil or neighbourDistance < bestNeighbourDistance) then
								selectedTerritoryId = neighbourTerritoryId;
								bestNeighbourDistance = neighbourDistance;
							end
						end
					end
				end

				local territoryOwnerId = territoryStanding.OwnerPlayerID;
				local falloff = (Mod.Settings.CharmFalloff or 0);
				local charmPercentage = math.floor(((1 - falloff) ^ (distanceFromSource or 0)) * 100 + 0.5) / 100;
				local areSuImmune = charmPercentage <= (Mod.Settings.CharmSpecialUnitThreshold or 0);

				local selectedSpecialUnits = nil;
				if (not areSuImmune and territoryStanding.NumArmies.SpecialUnits ~= nil) then
					selectedSpecialUnits = {};
					for _, specialUnit in ipairs(territoryStanding.NumArmies.SpecialUnits) do
						if (math.random() < charmPercentage) then
							table.insert(selectedSpecialUnits, specialUnit);
						end
					end
				end

				local moveArmiesCount = math.max(0, math.floor(territoryStanding.NumArmies.NumArmies * charmPercentage + 0.5));
				local armies = WL.Armies.Create(moveArmiesCount, selectedSpecialUnits);

				local isMovingAnything = moveArmiesCount > 0 or (selectedSpecialUnits ~= nil and #selectedSpecialUnits > 0);
				if (selectedTerritoryId ~= 0 and armies ~= nil and isMovingAnything) then
					local moveOrder = WL.GameOrderAttackTransfer.Create(territoryOwnerId, affectedTerritoryId, selectedTerritoryId, WL.AttackTransferEnum.AttackTransfer, false, armies, false);
					local visibleTo = { territoryOwnerId };
					local event = WL.GameOrderEvent.Create(territoryOwnerId, "Charmed", visibleTo, {});
					event.TerritoryAnnotationsOpt = { [affectedTerritoryId] = WL.TerritoryAnnotation.Create("Charmed", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Orchid)) };
					addNewOrder(event);
					addNewOrder(moveOrder);
				end
			end
		end

		if(charm.TurnEnd == game.Game.TurnNumber) then
			if (existingStructures[fadingStructureID] ~= nil) then
				existingStructures[fadingStructureID] = math.max(existingStructures[fadingStructureID] - 1, 0);
			end
			local territoryModification = WL.TerritoryModification.Create(charm.TerritoryId);
			territoryModification.SetStructuresOpt = CopyStructures(existingStructures);

			local event = WL.GameOrderEvent.Create(charm.PlayerOwnerId, "Charm wears off in " .. game.Map.Territories[charm.TerritoryId].Name , {}, {territoryModification});
			event.TerritoryAnnotationsOpt = { [charm.TerritoryId] = WL.TerritoryAnnotation.Create("Charm wears off", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Orchid)) };
			addNewOrder(event);
			table.remove(charms, i);
		elseif (charm.TurnEnd == game.Game.TurnNumber + 1) then
			if (existingStructures[structureID] ~= nil) then
				existingStructures[structureID] = math.max(existingStructures[structureID] - 1, 0);
			end
			if (existingStructures[fadingStructureID] == nil) then
				existingStructures[fadingStructureID] = 1;
			else
				existingStructures[fadingStructureID] = existingStructures[fadingStructureID] + 1;
			end
			local territoryModification = WL.TerritoryModification.Create(charm.TerritoryId);
			territoryModification.SetStructuresOpt = CopyStructures(existingStructures);

			local event = WL.GameOrderEvent.Create(charm.PlayerOwnerId, "Charm begins to fade in " .. game.Map.Territories[charm.TerritoryId].Name, {}, {territoryModification});
			event.TerritoryAnnotationsOpt = { [charm.TerritoryId] = WL.TerritoryAnnotation.Create("Charm fading", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Orchid)) };
			addNewOrder(event);
		end
	end

	priv.Fears = fears;
	priv.Charms = charms;
	Mod.PrivateGameData = priv;
end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_End(game, addNewOrder)
	-- fallback for turns with no Attack/Transfer order at all, since Server_AdvanceTurn_Order then never
	-- sees an Attacks-phase order to trigger ResolveCharmAndFear from
	local priv = Mod.PrivateGameData;
	if (priv.ResolvedForTurn ~= game.Game.TurnNumber) then
		ResolveCharmAndFear(game, addNewOrder);
		priv = Mod.PrivateGameData;
		priv.ResolvedForTurn = game.Game.TurnNumber;
		Mod.PrivateGameData = priv;
	end
end

function getTerritoriesAndDistance (game, targetTerritoryID, intMaxDistance)
    local territoryDistances = { [targetTerritoryID] = 0 };
    local arrTerrProcessed = { [targetTerritoryID] = true }; --list of terrs already processed
    local arrTerrListToProcess = { targetTerritoryID }; --terrs remaining to be processed

	local intDepth = 0;

    while (intDepth < intMaxDistance and #arrTerrListToProcess > 0) do
        local intNextTerrID = {};

        for _, terrID in ipairs(arrTerrListToProcess) do
            for neighbourTerrID, _ in pairs (game.Map.Territories [terrID].ConnectedTo or {}) do
                if not arrTerrProcessed [neighbourTerrID] then
                    arrTerrProcessed [neighbourTerrID] = true;
                    territoryDistances[neighbourTerrID] = intDepth + 1;
                    table.insert(intNextTerrID, neighbourTerrID);
                end
            end
        end

        arrTerrListToProcess = intNextTerrID;
        intDepth = intDepth + 1;
    end

    return territoryDistances;
end

---Returns the (mutable, cached) structures table for a territory, seeded from LatestTurnStanding the first
---time it's requested for a given structuresByTerritory cache. Callers mutate the returned table in place.
---@param game GameServerHook
---@param structuresByTerritory table<TerritoryID, table<EnumStructureType, integer>>
---@param territoryId TerritoryID
function GetTerritoryStructures(game, structuresByTerritory, territoryId)
	local structures = structuresByTerritory[territoryId];
	if (structures == nil) then
		structures = {};
		for key, value in pairs(game.ServerGame.LatestTurnStanding.Territories[territoryId].Structures or {}) do
			structures[key] = value;
		end
		structuresByTerritory[territoryId] = structures;
	end
	return structures;
end

---Returns a shallow copy of a structures table.
---@param structures table<EnumStructureType, integer>
function CopyStructures(structures)
	local copy = {};
	for key, value in pairs(structures) do
		copy[key] = value;
	end
	return copy;
end