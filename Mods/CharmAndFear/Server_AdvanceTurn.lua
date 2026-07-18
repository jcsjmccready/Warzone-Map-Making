require("Utilities");


---@class CharmFearInstance # Active card expire behaviour enums
---@field TerritoryId number # TerritoryId of where the charm/fear is
---@field TurnEnd integer # final turn of the charm/fear instance
---@field AffectedTerritoryDistances table<number, number> # territory id: distance from the source territory along the fear/charm path
---@field PlayerOwnerId number # id of the player that created the instance

-- questions:
-- we need to check the logic for the falloff. Review the nuke config pattern and additive vs multiplicative 
-- implement forced attacks
-- handle muiltiple fears nearby - we shouldnt run from a lesser fear to a greater fear
-- non-deterministic fear path. Same fear will always fear in same path due to territory ordering

---Server_AdvanceTurn_Order
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)

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
			TurnEnd = game.Game.TurnNumber + Mod.Settings.FearDuration-1, -- 1 turn duration means only this turn. i.e. Will go at the end of the current turn after triggering 
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
		if(Mod.Settings.FearDuration == 1) then
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
		event.TerritoryAnnotationsOpt = { [targetTerritoryID] = WL.TerritoryAnnotation.Create("Charm", 8, GetColourIntegerFromHex(BUTTON_COLOURS.ElectricPurple)) };

		addNewOrder(event);

		local priv = Mod.PrivateGameData;
		local charms = priv.Charms or {};

		local territoryDistances = getTerritoriesAndDistance(game, targetTerritoryID, Mod.Settings.CharmDistance);

		---@type CharmFearInstance
		local charmInstance = {
			TerritoryId = targetTerritoryID,
			TurnEnd = game.Game.TurnNumber + Mod.Settings.CharmDuration-1, -- 1 turn duration means only this turn. i.e. Will go at the end of the current turn after triggering 
			AffectedTerritoryDistances = territoryDistances,
			PlayerOwnerId = tonumber(order.PlayerID) or WL.PlayerID.Neutral
		}
		table.insert(charms, charmInstance);
		priv.Charms = charms;
		Mod.PrivateGameData = priv;
    end

end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_End(game, addNewOrder)
	local priv = Mod.PrivateGameData;
	---@type [CharmFearInstance]
	local fears = priv.Fears or {};

	---@type table<number, number>
	local territoryPercentageArmiesFeared = {}

	--todo:
	-- remove the fears that have expired from mod data
	-- loop through fears in reverse so we can remove as we go
	-- store territory and upsert % armies feared
	-- store expiring fears
	-- end loop
	-- at this point we should have looped through all fears
	-- now create orders for army movement, if fear = 100% then include special units
	-- now create orders for fear expiry

	--todo: all of the above but also for charms

	-- iterate in reverse so we can remove
	for i = #fears, 1, -1 do
		local fear = fears[i];
		local fadingStructureID = WL.StructureType.Custom("FadingFear");
		local structureID = WL.StructureType.Custom("Fear");
		local existingStructures = game.ServerGame.LatestTurnStanding.Territories[fear.TerritoryId].Structures or {};

		-- fear ongoing, RUN AWAY!
		for affectedTerritoryId, distanceFromSource in pairs(fear.AffectedTerritoryDistances or {}) do
			local territoryStanding = game.ServerGame.LatestTurnStanding.Territories[affectedTerritoryId];
			if (territoryStanding ~= nil and territoryStanding.NumArmies ~= nil and territoryStanding.OwnerPlayerID ~= WL.PlayerID.Neutral) then
				local normalizedDistance = distanceFromSource or 0;
				local connectedTerritories = game.Map.Territories[affectedTerritoryId].ConnectedTo or {};
				local selectedTerritoryId = 0;

				--determine where the armies flee to

				if(normalizedDistance == Mod.Settings.FearDistance) then -- army runs out of fear range
					for neighbourTerritoryId, _ in pairs(connectedTerritories) do
						if (fear.AffectedTerritoryDistances[neighbourTerritoryId] == nil) then
							selectedTerritoryId = neighbourTerritoryId;
							break;
						end
					end
				else --army runs away from fear or to another of same distance if no better choice
					local bestNeighbourDistance = nil;
					for neighbourTerritoryId, _ in pairs(connectedTerritories) do
						local neighbourDistance = fear.AffectedTerritoryDistances[neighbourTerritoryId];
						if (neighbourDistance ~= nil and neighbourDistance > normalizedDistance) then
							if (bestNeighbourDistance == nil or neighbourDistance > bestNeighbourDistance) then
								selectedTerritoryId = neighbourTerritoryId;
								bestNeighbourDistance = neighbourDistance;
							end
						end
					end
				end

				-- create movement to selectedTerritoryId
				local territoryOwnerId = territoryStanding.OwnerPlayerID;
				local falloff = (Mod.Settings.FearFalloff or 0);
				local fearPercentage = math.floor((falloff ^ (distanceFromSource or 0)) * 100 + 0.5) / 100;
				local isEntireArmyFeared = fearPercentage >= 1;
				local areSuImmune = fearPercentage < (Mod.Settings.FearSpecialUnitThreshold or 0);

				print("fear %: ".. fearPercentage)
				local armies = nil;
				if(isEntireArmyFeared) then
					print("entire army feared")
					armies = WL.Armies.Create(territoryStanding.NumArmies.NumArmies, territoryStanding.NumArmies.SpecialUnits or {});
				else
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
					print("moveArmiesCount: " .. moveArmiesCount)
					armies = WL.Armies.Create(moveArmiesCount, selectedSpecialUnits);
				end

				if (selectedTerritoryId ~= 0 and armies ~= nil) then
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
			local structures = {};

			-- copy old structures and decrement the targeted structure count
			for key, value in pairs(existingStructures or {}) do
				structures[key] = value;
			end
			if (structures[fadingStructureID] ~= nil) then
				structures[fadingStructureID] = math.max(structures[fadingStructureID] - 1, 0);
			end
			local territoryModification = WL.TerritoryModification.Create(fear.TerritoryId);
			territoryModification.SetStructuresOpt = structures;

			local event = WL.GameOrderEvent.Create(fear.PlayerOwnerId, "Fear wears off in " .. game.Map.Territories[fear.TerritoryId].Name , {}, {territoryModification});
			event.TerritoryAnnotationsOpt = { [fear.TerritoryId] = WL.TerritoryAnnotation.Create("Fear wears off", 8, GetColourIntegerFromHex(BUTTON_COLOURS.ElectricPurple)) };
			addNewOrder(event);
			table.remove(fears, i);
		elseif (fear.TurnEnd == game.Game.TurnNumber + 1) then
			-- convert fear into fading fear
			local structures = {};

			-- copy old structures and convert one fear instance into a fading fear
			for key, value in pairs(existingStructures or {}) do
				structures[key] = value;
			end
			if (structures[structureID] ~= nil) then
				structures[structureID] = math.max(structures[structureID] - 1, 0);
			end
			if (structures[fadingStructureID] == nil) then
				structures[fadingStructureID] = 1;
			else
				structures[fadingStructureID] = structures[fadingStructureID] + 1;
			end
			local territoryModification = WL.TerritoryModification.Create(fear.TerritoryId);
			territoryModification.SetStructuresOpt = structures;

			local event = WL.GameOrderEvent.Create(fear.PlayerOwnerId, "Fear begins to fade in " .. game.Map.Territories[fear.TerritoryId].Name, {}, {territoryModification});
			event.TerritoryAnnotationsOpt = { [fear.TerritoryId] = WL.TerritoryAnnotation.Create("Fear fading", 8, GetColourIntegerFromHex(BUTTON_COLOURS.ElectricPurple)) };
			addNewOrder(event);
		end
	end

	-- ---@type [CharmFearInstance]
	-- local charms = priv.Charms or {};

	-- for i, charm in ipairs(charms) do
	-- 	if(charm.TurnEnd == game.Game.TurnNumber) then
	-- 		-- Charm has expired, remove the structure

	-- 		local structureID = WL.StructureType.Custom("FadingCharm");
	-- 		local existingStructures = game.ServerGame.LatestTurnStanding.Territories[charm.TerritoryId].Structures or {};

	-- 		local numberOfCharms = 0;
	-- 		if (existingStructures[structureID] ~= nil) then
	-- 			numberOfCharms = numberOfCharms + existingStructures[structureID];
	-- 		end

	-- 		local structures = {};

	-- 		-- copy old structures but skip dms
	-- 		for key, value in pairs(existingStructures or {}) do
	-- 			if(key ~= structureID) then
	-- 				structures[key] = value;
	-- 			end;
	-- 		end

	-- 		structures[structureID] = math.max(numberOfCharms - 1, 0);
	-- 		local territoryModification = WL.TerritoryModification.Create(charm.TerritoryId);
	-- 		territoryModification.SetStructuresOpt = structures;

	-- 		local event = WL.GameOrderEvent.Create(charm.PlayerOwnerId, "Charm wears off in " .. game.Map.Territories[charm.TerritoryId].Name , {}, {territoryModification});
	-- 		event.TerritoryAnnotationsOpt = { [charm.TerritoryId] = WL.TerritoryAnnotation.Create("Charm wears off", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Orchid)) };
	-- 		addNewOrder(event, true);
	-- 	end
	-- end

	priv.Fears = fears;
	-- priv.Charms = charms;
	Mod.PrivateGameData = priv;
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