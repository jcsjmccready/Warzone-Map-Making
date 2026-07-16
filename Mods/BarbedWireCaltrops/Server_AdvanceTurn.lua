require("Utilities");

-- todo: implement tank caltrop trigger logic
-- todo: imeplement tank caltrop move block logic

---Server_AdvanceTurn_Order
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)

    if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, "CreateBarbedWire_")) then

        local targetTerritoryID = tonumber(string.sub(order.ModData, 18))
		if (game.ServerGame.LatestTurnStanding.Territories[targetTerritoryID].OwnerPlayerID ~= order.PlayerID) then
			return; --not our territory
		end

		-- store pending build orders for end of turn
		local pendingBarbedWire = {};
		pendingBarbedWire.PlayerID = order.PlayerID;
		pendingBarbedWire.Message = order.Description;
		pendingBarbedWire.TerritoryID = targetTerritoryID;

		local privateGameData = Mod.PrivateGameData;
		if (privateGameData.PendingBarbedWire == nil) then privateGameData.PendingBarbedWire = {}; end;
		table.insert(privateGameData.PendingBarbedWire, pendingBarbedWire);

		Mod.PrivateGameData = privateGameData;
    end

	-- if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, "CreateTankCaltrop_")) then

    --     local targetTerritoryID = tonumber(string.sub(order.ModData, 19))
	-- 	if (game.ServerGame.LatestTurnStanding.Territories[targetTerritoryID].OwnerPlayerID ~= order.PlayerID) then
	-- 		return; --not our territory
	-- 	end

	-- 	-- store pending build orders for end of turn
	-- 	local pendingTankCaltrop = {};
	-- 	pendingTankCaltrop.PlayerID = order.PlayerID;
	-- 	pendingTankCaltrop.Message = order.Description;
	-- 	pendingTankCaltrop.TerritoryID = targetTerritoryID;

	-- 	local privateGameData = Mod.PrivateGameData;
	-- 	if (privateGameData.PendingTankCaltrop == nil) then privateGameData.PendingTankCaltrop = {}; end;
	-- 	table.insert(privateGameData.PendingTankCaltrop, pendingTankCaltrop);

	-- 	Mod.PrivateGameData = privateGameData;
    -- end

	HandleAttackTransferInTriggeredStructure(game, order, result, skipThisOrder, addNewOrder);
	HandleAttackTransferToStructure(game, order, result, addNewOrder);
end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_End(game, addNewOrder)
	BuildStructures(game, addNewOrder);
	ResetTriggeredStructures(game, addNewOrder);
end

---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function HandleAttackTransferInTriggeredStructure(game, order, result, skipThisOrder, addNewOrder)
	if (order.proxyType ~= 'GameOrderAttackTransfer') then
		return;
	end

	if (Mod.Settings.BarbedWireTanksIgnore and result.ActualArmies ~= nil and result.ActualArmies.SpecialUnits ~= nil) then
		local hasTank = false;
		for _, specialUnit in ipairs(result.ActualArmies.SpecialUnits) do
			if specialUnit ~= nil and specialUnit.Name == "Tank" then
				hasTank = true;
				break;
			end
		end

		if hasTank then
			return; -- tanks ignore barbed wire, so don't block movement
		end
	end

	-- movement blocking logic below

    local triggeredBarbedWireStructId = WL.StructureType.Custom("TriggeredBarbedWire");
    local existingStructures = game.ServerGame.LatestTurnStanding.Territories[order.From].Structures;

	if (existingStructures == nil) then return; end;


    local numberOfTriggeredBarbedWire = 0;
	if (existingStructures[triggeredBarbedWireStructId] ~= nil) then
		numberOfTriggeredBarbedWire = numberOfTriggeredBarbedWire + existingStructures[triggeredBarbedWireStructId];
	end

	--If no barbed wire here, abort.
	if (numberOfTriggeredBarbedWire == 0) then return; end;

	-- block this attack by skipping
	skipThisOrder(WL.ModOrderControl.SkipAndSupressSkippedMessage); --suppress the meaningless/detailless 'Mod skipped order' message, since the above message provides the details
	local event = WL.GameOrderEvent.Create(order.PlayerID, 'Movement blocked by barbed wire', {}, {});
	event.TerritoryAnnotationsOpt = { [order.From] = WL.TerritoryAnnotation.Create("Armies stuck", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
	addNewOrder(event);
end

---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function HandleAttackTransferToStructure(game, order, result, addNewOrder)

	if (order.proxyType ~= 'GameOrderAttackTransfer') then
		return;
	end

	-- handle tank destroy logic - track structures to not create a new triggered barbed wire if it was destroyed by a tank
	local remainingStructuresTo = game.ServerGame.LatestTurnStanding.Territories[order.To].Structures;
	if (Mod.Settings.TanksDestroy and result.ActualArmies ~= nil and result.ActualArmies.SpecialUnits ~= nil) then
		local hasTank = false;
		for _, specialUnit in ipairs(result.ActualArmies.SpecialUnits) do
			if specialUnit ~= nil and specialUnit.Name == "Tank" then
				hasTank = true;
				break;
			end
		end

		if (hasTank) then
			local triggeredBarbedWireStructId = WL.StructureType.Custom("TriggeredBarbedWire");
			local primedBarbedWireStructId = WL.StructureType.Custom("PrimedBarbedWire");
			
			-- tank removes any barbed wire structures on the territory it attacks
			local existingStructuresTo = game.ServerGame.LatestTurnStanding.Territories[order.To].Structures;
			local isExistingBarbedWireTo = 
				existingStructuresTo ~= nil and
				((existingStructuresTo[triggeredBarbedWireStructId] ~= nil and existingStructuresTo[triggeredBarbedWireStructId] > 0) 
				or (existingStructuresTo[primedBarbedWireStructId] ~= nil and existingStructuresTo[primedBarbedWireStructId] > 0));
			if(isExistingBarbedWireTo) then
				local structuresTo = {};
				structuresTo[primedBarbedWireStructId] = 0;
				structuresTo[triggeredBarbedWireStructId] = 0;

				-- copy old structures but skip wire
				for key, value in pairs(existingStructuresTo or {}) do
					if(key ~= primedBarbedWireStructId and key ~= triggeredBarbedWireStructId) then
						structuresTo[key] = value;
					end
				end
				
				local territoryModificationTo = WL.TerritoryModification.Create(order.To);
				territoryModificationTo.SetStructuresOpt = structuresTo;
				remainingStructuresTo = structuresTo;
				
				local event = WL.GameOrderEvent.Create(order.PlayerID, 'Barbed wire destroyed', {}, {territoryModificationTo});
				event.TerritoryAnnotationsOpt = { [order.To] = WL.TerritoryAnnotation.Create("Barbed wire destroyed", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
				addNewOrder(event, true);
			end
			
			-- tank removes any barbed wire structures on the territory it attacks from
			local existingStructuresFrom = game.ServerGame.LatestTurnStanding.Territories[order.From].Structures;
			local isExistingBarbedWireFrom = 
				existingStructuresFrom ~= nil and
				((existingStructuresFrom[triggeredBarbedWireStructId] ~= nil and existingStructuresFrom[triggeredBarbedWireStructId] > 0) 
				or (existingStructuresFrom[primedBarbedWireStructId] ~= nil and existingStructuresFrom[primedBarbedWireStructId] > 0));
			if(isExistingBarbedWireFrom) then
				local structuresFrom = {};
				structuresFrom[primedBarbedWireStructId] = 0;
				structuresFrom[triggeredBarbedWireStructId] = 0;

				-- copy old structures but skip wire
				for key, value in pairs(existingStructuresFrom or {}) do
					if(key ~= primedBarbedWireStructId and key ~= triggeredBarbedWireStructId) then
						structuresFrom[key] = value;
					end
				end
				
				local territoryModificationFrom = WL.TerritoryModification.Create(order.From);
				territoryModificationFrom.SetStructuresOpt = structuresFrom;
				
				local event = WL.GameOrderEvent.Create(order.PlayerID, 'Barbed wire destroyed', {}, {territoryModificationFrom});
				event.TerritoryAnnotationsOpt = { [order.From] = WL.TerritoryAnnotation.Create("Barbed wire destroyed", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
				addNewOrder(event, true);
			end
		end
	end

	-- change primed barbed wire to triggered barbed wire if the territory was attacked and the attack was successful
	if (not result.IsAttack or not result.IsSuccessful) then
		return;
	end

    local primedBarbedWireStructId = WL.StructureType.Custom("PrimedBarbedWire");
    local existingStructures = remainingStructuresTo;

	if (existingStructures == nil) then return; end;

    local numberOfPrimedBarbedWire = 0;
	if (existingStructures[primedBarbedWireStructId] ~= nil) then
		numberOfPrimedBarbedWire = numberOfPrimedBarbedWire + existingStructures[primedBarbedWireStructId];
	end

	--If no barbed wire here, abort.
	if (numberOfPrimedBarbedWire == 0) then return; end;

    --If an attack of 0, abort, so skipped orders don't trigger the barbed wire
	if (result.ActualArmies.IsEmpty) then return; end;

	-- abort if on same team and ally triggers is disabled
    local territoryOwnerPlayerID = game.ServerGame.LatestTurnStanding.Territories[order.To].OwnerPlayerID;
    local attackerTeam = game.ServerGame.Game.Players[order.PlayerID].Team;
    local ownerTeam = game.ServerGame.Game.Players[territoryOwnerPlayerID].Team;
	if(attackerTeam ~= nil and ownerTeam ~= nil and attackerTeam ~=-1 and ownerTeam ~=-1 and attackerTeam == ownerTeam and Mod.Settings.BarbedWireAllyTriggers == false) then
		return;
	end;

	local structures = {};

	-- primed barbed wire now becomes triggered barbed wire
	-- store triggered ids to not reset them at the end of the turn.
	local triggeredTerritoryId = order.To;
	local privateGameData = Mod.PrivateGameData;
	if (privateGameData.TriggeredBarbedWireTerritoryIds == nil) then privateGameData.TriggeredBarbedWireTerritoryIds = {}; end;
	table.insert(privateGameData.TriggeredBarbedWireTerritoryIds, triggeredTerritoryId);

	-- copy old structures but skip wire
	for key, value in pairs(existingStructures or {}) do
		if(key ~= primedBarbedWireStructId) then
			structures[key] = value;
		end
	end

	structures[primedBarbedWireStructId] = 0;
    local triggeredBarbedWireStructId = WL.StructureType.Custom("TriggeredBarbedWire");
	structures[triggeredBarbedWireStructId] = numberOfPrimedBarbedWire;

	local territoryModification = WL.TerritoryModification.Create(order.To);
	territoryModification.SetStructuresOpt = structures;

	local event = WL.GameOrderEvent.Create(order.PlayerID, "Triggered a Barbed Wire", {}, {territoryModification});
	event.TerritoryAnnotationsOpt = { [order.To] = WL.TerritoryAnnotation.Create("Triggered Barbed Wire", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
	addNewOrder(event, true);
	Mod.PrivateGameData = privateGameData;

end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function ResetTriggeredStructures(game, addNewOrder)
	local privateGameData = Mod.PrivateGameData;

	if(Mod.Settings.IncludeBarbedWire) then
		local primedStructId = WL.StructureType.Custom("PrimedBarbedWire");
		local triggeredStructId = WL.StructureType.Custom("TriggeredBarbedWire");
		local triggeredTerritoryIds = privateGameData.TriggeredBarbedWireTerritoryIds or {};
		ResetStructure(game, addNewOrder, primedStructId, triggeredStructId, "Barbed Wire", triggeredTerritoryIds)
		privateGameData.TriggeredBarbedWireTerritoryIds = nil;
	end
	if(Mod.Settings.IncludeTankCaltrop) then
		local primedStructId = WL.StructureType.Custom("PrimedTankCaltrop");
		local triggeredStructId = WL.StructureType.Custom("TriggeredTankCaltrop");
		local triggeredTerritoryIds = privateGameData.TriggeredTankCaltropTerritoryIds or {};

		ResetStructure(game, addNewOrder, primedStructId, triggeredStructId, "Tank Caltrop", triggeredTerritoryIds);
		privateGameData.TriggeredTankCaltropTerritoryIds = nil;
	end

	Mod.PrivateGameData = privateGameData;
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
---@param primedStructId EnumValue
---@param triggeredStructId EnumValue
---@param structName string
---@param triggeredTerritoryIds any
function ResetStructure(game, addNewOrder, primedStructId, triggeredStructId, structName, triggeredTerritoryIds)
	local anyReset = false;
	local triggeredTerritorySet = {};

	for _, territoryId in pairs(triggeredTerritoryIds) do
		triggeredTerritorySet[territoryId] = true;
	end

	local territoryModifications = {};
	for _, territory in pairs(game.ServerGame.LatestTurnStanding.Territories) do
		if not triggeredTerritorySet[territory.ID] then
			local structures = territory.Structures;
			if (structures ~= nil and structures[triggeredStructId] ~= nil and structures[triggeredStructId] > 0) then
				structures[primedStructId] = (structures[primedStructId] or 0) + structures[triggeredStructId];
				structures[triggeredStructId] = 0;
				anyReset = true;
				local territoryModification = WL.TerritoryModification.Create(territory.ID);
				territoryModification.SetStructuresOpt = structures;

				table.insert(territoryModifications, territoryModification);
			end
		end
	end
	if (anyReset) then
		local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, "Reset ".. structName, {}, territoryModifications);
		addNewOrder(event);
	end
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function BuildStructures(game, addNewOrder)
	local privateGameData = Mod.PrivateGameData;
	if(Mod.Settings.IncludeBarbedWire) then
		BuildStructureType(game, addNewOrder, privateGameData.PendingBarbedWire, WL.StructureType.Custom("PrimedBarbedWire"), "Barbed Wire");
		privateGameData.PendingBarbedWire = nil;
	end
	if(Mod.Settings.IncludeTankCaltrop) then
		BuildStructureType(game, addNewOrder, privateGameData.PendingTankCaltrop, WL.StructureType.Custom("PrimedTankCaltrop"), "Tank Caltrop");
		privateGameData.PendingTankCaltrop = nil;
	end

	Mod.PrivateGameData = privateGameData;
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function BuildStructureType(game, addNewOrder, pending, structureID, structureName)
	if (pending == nil) then return; end;

	-- Split pending builds into ones we can still build and ones we removed because ownership changed.
	local removedPendingStructure = {};
	local remainingPendingStructure = {};
	for _,pendingDms in pairs(pending) do
		if (pendingDms.PlayerID ~= game.ServerGame.LatestTurnStanding.Territories[pendingDms.TerritoryID].OwnerPlayerID) then
			table.insert(removedPendingStructure, pendingDms);
		else
			table.insert(remainingPendingStructure, pendingDms);
		end
	end

	pending = remainingPendingStructure;

	-- We will now build a structure for each pending structure. However, we need to take care to ensure that if there are two build orders for the same territory that we build both of them,
	--	so we first group by the territory ID so we get all build orders for the same territory together.
	for territoryID,pendingStructureGroup in pairs(groupBy(pending, function(t) return t.TerritoryID; end)) do

		local numStructureToBuild = #pendingStructureGroup;

		local structures = game.ServerGame.LatestTurnStanding.Territories[territoryID].Structures;

		if (structures == nil) then structures = {}; end;
		if (structures[structureID] == nil) then
			structures[structureID] = numStructureToBuild;
		else
			structures[structureID] = structures[structureID] + numStructureToBuild;
		end

		local territoryModification = WL.TerritoryModification.Create(territoryID);
		territoryModification.SetStructuresOpt = structures;

		local pendingStructure = first(pendingStructureGroup);
		if (pendingStructure ~= nil) then
			local event = WL.GameOrderEvent.Create(pendingStructure.PlayerID, pendingStructure.Message, {}, {territoryModification});

			local td = game.Map.Territories[territoryID];
			event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
			event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Build ".. structureName, 8, GetColourIntegerFromHex(BUTTON_COLOURS.DarkGreen)) };

			addNewOrder(event);
		end
	end

	for territoryID,pendingStructureGroup in pairs(groupBy(removedPendingStructure, function(t) return t.TerritoryID; end)) do
		local pendingStructure = first(pendingStructureGroup);
		if (pendingStructure ~= nil) then
			local event = WL.GameOrderEvent.Create(pendingStructure.PlayerID, "Unable to build " .. structureName .. " on " .. game.Map.Territories[territoryID].Name, {}, {});

			local td = game.Map.Territories[territoryID];
			event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
			event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Unable to build " .. structureName, 8, GetColourIntegerFromHex(BUTTON_COLOURS.Red)) };

			addNewOrder(event);
		end
	end
end