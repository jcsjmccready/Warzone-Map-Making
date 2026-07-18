require("Utilities");


---@class CharmFearInstance # Active card expire behaviour enums
---@field TerritoryId number # TerritoryId of where the charm/fear is
---@field TurnEnd integer # final turn of the charm/fear instance
---@field TerritoryEffectStrength table<number, number> # territory id: % of armies effected
---@field PlayerOwnerId number # id of the player that created the instance

-- questions:
-- we need to check the logic for the falloff. Review the nuke config pattern and additive vs multiplicative 
-- implement forced attacks

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

		local territoryEffects = getTerritoriesWithFearCharmStrength(game, targetTerritoryID, Mod.Settings.FearDistance, Mod.Settings.FearFalloff);

		---@type CharmFearInstance
		local fearInstance = {
			TerritoryId = targetTerritoryID,
			TurnEnd = game.Game.TurnNumber + Mod.Settings.FearDuration-1, -- 1 turn duration means only this turn. i.e. Will go at the end of the current turn after triggering 
			TerritoryEffectStrength = territoryEffects,
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

		local territoryEffects = getTerritoriesWithFearCharmStrength(game, targetTerritoryID, Mod.Settings.CharmDistance, Mod.Settings.CharmFalloff);

		---@type CharmFearInstance
		local charmInstance = {
			TerritoryId = targetTerritoryID,
			TurnEnd = game.Game.TurnNumber + Mod.Settings.CharmDuration-1, -- 1 turn duration means only this turn. i.e. Will go at the end of the current turn after triggering 
			TerritoryEffectStrength = territoryEffects,
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

	for i, fear in ipairs(fears) do
		local fadingStructureID = WL.StructureType.Custom("FadingFear");
		local structureID = WL.StructureType.Custom("Fear");
		local existingStructures = game.ServerGame.LatestTurnStanding.Territories[fear.TerritoryId].Structures or {};

		local numberOfFears = 0;
		if (existingStructures[fadingStructureID] ~= nil) then
			numberOfFears = numberOfFears + existingStructures[fadingStructureID];
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
			addNewOrder(event, true);
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
			addNewOrder(event, true);
		else
			-- -- fear ongoing, RUN AWAY!
			-- for affectedTerritoryId, effectStrength in pairs(fear.TerritoryEffectStrength or {}) do
			-- 	local territoryStanding = game.ServerGame.LatestTurnStanding.Territories[affectedTerritoryId];
			-- 	if (territoryStanding ~= nil and territoryStanding.NumArmies ~= nil) then
			-- 		territoryPercentageArmiesFeared[affectedTerritoryId] = math.min(effectStrength, 1);
			-- 	end
			-- end
		end
	end

	-- create attacks for fears


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

function getTerritoriesWithFearCharmStrength (game, targetTerritoryID, intMaxDistance, stepDecay)
    local decay = math.max(0, math.min(1, stepDecay or 0));
    local territoryEffectStrength = { [targetTerritoryID] = 1.0 };
    local arrTerrProcessed = { [targetTerritoryID] = true }; --list of terrs already processed
    local arrTerrListToProcess = { targetTerritoryID }; --terrs remaining to be processed

	local intDepth = 0;

    while (intDepth < intMaxDistance and #arrTerrListToProcess > 0) do
        local intNextTerrID = {};
        local ringEffectStrength = math.max(0, 1.0 - ((intDepth + 1) * decay));

        for _, terrID in ipairs(arrTerrListToProcess) do
            for neighbourTerrID, _ in pairs (game.Map.Territories [terrID].ConnectedTo) do
                if not arrTerrProcessed [neighbourTerrID] then
                    arrTerrProcessed [neighbourTerrID] = true;
                    territoryEffectStrength[neighbourTerrID] = ringEffectStrength;
                    table.insert(intNextTerrID, neighbourTerrID);
                end
            end
        end

        arrTerrListToProcess = intNextTerrID;
        intDepth = intDepth + 1;
    end

    return territoryEffectStrength;
end