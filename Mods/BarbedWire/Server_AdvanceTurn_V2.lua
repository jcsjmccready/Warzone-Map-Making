require("Utilities");

--Settings version 2 behaviour

---@class V2_PendingBarbedWire
---@field PlayerID PlayerID
---@field Message string
---@field TerritoryID TerritoryID

---@class V2_BarbedWire
---@field TerritoryID TerritoryID
---@field Triggered boolean
---@field FinalTurnTriggered integer | nil
---@field FinalTurnExpires integer | nil # nil if lifespan is unlimited

---@class V2_PrivateGameData
---@field PendingBarbedWire V2_PendingBarbedWire[]
---@field BarbedWires V2_BarbedWire[] # Every individual barbed wire piece currently in play, one entry per physical piece

V2 = {}

---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function V2.Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)

    if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, "CreateBarbedWire_")) then

        local targetTerritoryID = tonumber(string.sub(order.ModData, 18)) --[[@as TerritoryID]]
		if (game.ServerGame.LatestTurnStanding.Territories[targetTerritoryID].OwnerPlayerID ~= order.PlayerID) then
			return; --not our territory
		end

		-- store pending build orders for end of turn
		---@type V2_PendingBarbedWire
		local pendingBarbedWire = {
			PlayerID = order.PlayerID,
			Message = order.Description,
			TerritoryID = targetTerritoryID 
		};

		local privateGameData = Mod.PrivateGameData --[[@as V2_PrivateGameData]];
		if (privateGameData.PendingBarbedWire == nil) then privateGameData.PendingBarbedWire = {}; end;
		table.insert(privateGameData.PendingBarbedWire, pendingBarbedWire);

		Mod.PrivateGameData = privateGameData;
    end

	V2.HandleAttackTransferInTriggeredBarbedWire(game, order, result, skipThisOrder, addNewOrder);
	V2.HandleAttackTransferToBarbedWire(game, order, result, addNewOrder);
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function V2.Server_AdvanceTurn_End(game, addNewOrder)
	V2.BuildStructures(game, addNewOrder);
	-- must run before ResetTriggeredBarbedWire: a piece can be due to both reset and expire in the same
	-- turn, and we want it destroyed once as "expired" rather than reset-then-immediately-expired
	V2.ExpireBarbedWire(game, addNewOrder);
	V2.ResetTriggeredBarbedWire(game, addNewOrder);
end

---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function V2.HandleAttackTransferInTriggeredBarbedWire(game, order, result, skipThisOrder, addNewOrder)
	if (order.proxyType ~= 'GameOrderAttackTransfer') then
		return;
	end

	if (Mod.Settings.BarbedWireTanksIgnore and result.ActualArmies ~= nil and result.ActualArmies.SpecialUnits ~= nil) then
		local hasTank = false;
		for _, specialUnit in ipairs(result.ActualArmies.SpecialUnits) do
			if specialUnit ~= nil and specialUnit.proxyType == "CustomSpecialUnit" and specialUnit.Name == "Tank" then
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

	-- block this attack
	result.ActualArmies = WL.Armies.Create(0);
	local event = WL.GameOrderEvent.Create(order.PlayerID, 'Movement blocked by barbed wire', {}, {});
	event.TerritoryAnnotationsOpt = { [order.From] = WL.TerritoryAnnotation.Create("Armies stuck", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
	event.Icon = "Blocked"
	addNewOrder(event);
end

---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function V2.HandleAttackTransferToBarbedWire(game, order, result, addNewOrder)

	if (order.proxyType ~= 'GameOrderAttackTransfer') then
		return;
	end
	---@cast order GameOrderAttackTransfer

	local privateGameData = Mod.PrivateGameData --[[@as V2_PrivateGameData]];

	-- handle tank destroy logic - track structures to not create a new triggered barbed wire if it was destroyed by a tank
	local remainingStructuresTo = game.ServerGame.LatestTurnStanding.Territories[order.To].Structures;
	if (Mod.Settings.BarbedWireTanksDestroy and result.ActualArmies ~= nil and result.ActualArmies.SpecialUnits ~= nil) then
		local hasTank = false;
		for _, specialUnit in ipairs(result.ActualArmies.SpecialUnits) do
			if specialUnit ~= nil and specialUnit.proxyType == "CustomSpecialUnit" and specialUnit.Name == "Tank" then
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

				if (privateGameData.BarbedWires ~= nil) then
					removeWhere(privateGameData.BarbedWires, function(w) return w.TerritoryID == order.To; end);
				end

				local event = WL.GameOrderEvent.Create(order.PlayerID, 'Barbed wire destroyed', {}, {territoryModificationTo});
				event.TerritoryAnnotationsOpt = { [order.To] = WL.TerritoryAnnotation.Create("Barbed wire destroyed", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
				event.Icon = "Destroyed";
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

				if (privateGameData.BarbedWires ~= nil) then
					removeWhere(privateGameData.BarbedWires, function(w) return w.TerritoryID == order.From; end);
				end

				local event = WL.GameOrderEvent.Create(order.PlayerID, 'Barbed wire destroyed', {}, {territoryModificationFrom});
				event.TerritoryAnnotationsOpt = { [order.From] = WL.TerritoryAnnotation.Create("Barbed wire destroyed", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
				event.Icon = "Destroyed";
				addNewOrder(event, true);
			end

			-- commit any removals above now, since this function has early returns below that would otherwise skip the write-back
			Mod.PrivateGameData = privateGameData;
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

	local ownerTeam = WL.PlayerID.Neutral;
	if (game.ServerGame.Game.Players[territoryOwnerPlayerID] ~= nil) then
		ownerTeam = game.ServerGame.Game.Players[territoryOwnerPlayerID].Team;
	end

	if(attackerTeam ~= nil and ownerTeam ~= nil and attackerTeam ~=-1 and ownerTeam ~=-1 and attackerTeam == ownerTeam and Mod.Settings.BarbedWireAllyTriggers == false) then
		return;
	end;

	local structures = {};

	-- primed barbed wire now becomes triggered barbed wire
	local triggeredTerritoryId = order.To;

	-- tracking
	if (privateGameData.BarbedWires ~= nil) then
		local finalTurnTriggered = game.ServerGame.Game.TurnNumber + Mod.Settings.BarbedWireTriggerDuration;
		for _, wire in pairs(privateGameData.BarbedWires) do
			if (wire.TerritoryID == triggeredTerritoryId and not wire.Triggered) then
				wire.Triggered = true;
				wire.FinalTurnTriggered = finalTurnTriggered;
			end
		end
	end

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

	local event = WL.GameOrderEvent.Create(order.PlayerID, "Triggered Barbed Wire(s)", {}, {territoryModification});
	event.TerritoryAnnotationsOpt = { [order.To] = WL.TerritoryAnnotation.Create("Triggered Barbed Wire(s)", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
	event.Icon = "Triggered";
	addNewOrder(event, true);
	Mod.PrivateGameData = privateGameData;

end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function V2.ExpireBarbedWire(game, addNewOrder)
	local triggeredBarbedWireStructId = WL.StructureType.Custom("TriggeredBarbedWire");
	local primedBarbedWireStructId = WL.StructureType.Custom("PrimedBarbedWire");

	local privateGameData = Mod.PrivateGameData --[[@as V2_PrivateGameData]];
	local barbedWires = privateGameData.BarbedWires or {};
	local currentTurn = game.ServerGame.Game.TurnNumber;

	---@param wire V2_BarbedWire
	local function isDue(wire)
		return wire.FinalTurnExpires ~= nil and wire.FinalTurnExpires <= currentTurn;
	end

	-- count how many due pieces there are per territory, by state. lifespan expiry destroys either, regardless of state
	local duePrimedByTerritory = {};
	local dueTriggeredByTerritory = {};
	for _, wire in pairs(barbedWires) do
		if (isDue(wire)) then
			local tally = wire.Triggered and dueTriggeredByTerritory or duePrimedByTerritory;
			tally[wire.TerritoryID] = (tally[wire.TerritoryID] or 0) + 1;
		end
	end

	removeWhere(barbedWires, isDue);

	local anyExpired = false;
	local territoryModifications = {};
	local territoryAnnotations = {};
	for _, territory in pairs(game.ServerGame.LatestTurnStanding.Territories) do
		local duePrimed = duePrimedByTerritory[territory.ID];
		local dueTriggered = dueTriggeredByTerritory[territory.ID];

		local structures = territory.Structures;
		if ((duePrimed ~= nil or dueTriggered ~= nil) and structures ~= nil) then
			local changed = false;

			local existingPrimed = structures[primedBarbedWireStructId];
			if (duePrimed ~= nil and existingPrimed ~= nil and existingPrimed > 0) then
				-- clamp in case the structure count and tracked pieces ever disagree, so we never go negative
				local expiringCount = math.min(duePrimed, existingPrimed);
				structures[primedBarbedWireStructId] = existingPrimed - expiringCount;
				changed = true;
			end

			local existingTriggered = structures[triggeredBarbedWireStructId];
			if (dueTriggered ~= nil and existingTriggered ~= nil and existingTriggered > 0) then
				local expiringCount = math.min(dueTriggered, existingTriggered);
				structures[triggeredBarbedWireStructId] = existingTriggered - expiringCount;
				changed = true;
			end

			if (changed) then
				anyExpired = true;
				local territoryModification = WL.TerritoryModification.Create(territory.ID);
				territoryModification.SetStructuresOpt = structures;

				table.insert(territoryModifications, territoryModification);
				territoryAnnotations[territory.ID] = WL.TerritoryAnnotation.Create("Barbed wire expired", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany));
			end
		end
	end

	if (anyExpired) then
		local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, "Barbed Wire Expired", {}, territoryModifications);
		event.TerritoryAnnotationsOpt = territoryAnnotations;
		event.Icon = "Destroyed";
		addNewOrder(event);
	end

	privateGameData.BarbedWires = barbedWires;
	Mod.PrivateGameData = privateGameData;
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function V2.ResetTriggeredBarbedWire(game, addNewOrder)
	local triggeredBarbedWireStructId = WL.StructureType.Custom("TriggeredBarbedWire");
	local primedBarbedWireStructId = WL.StructureType.Custom("PrimedBarbedWire");

	local privateGameData = Mod.PrivateGameData --[[@as V2_PrivateGameData]];
	local barbedWires = privateGameData.BarbedWires or {};
	local currentTurn = game.ServerGame.Game.TurnNumber;

	---@param wire V2_BarbedWire
	local function isDue(wire)
		return wire.Triggered and wire.FinalTurnTriggered ~= nil and wire.FinalTurnTriggered <= currentTurn;
	end

	-- count how many due pieces there are per territory before mutating anything
	local dueCountByTerritory = {};
	for _, wire in pairs(barbedWires) do
		if (isDue(wire)) then
			dueCountByTerritory[wire.TerritoryID] = (dueCountByTerritory[wire.TerritoryID] or 0) + 1;
		end
	end

	if (Mod.Settings.BarbedWireSingleUse) then
		removeWhere(barbedWires, isDue);
	else
		-- resets back to primed - keep tracking the piece, just flip its state back
		for _, wire in pairs(barbedWires) do
			if (isDue(wire)) then
				wire.Triggered = false;
				wire.FinalTurnTriggered = nil;
			end
		end
	end

	local anyReset = false;
	local territoryModifications = {};
	for territoryId, dueCount in pairs(dueCountByTerritory) do
		local structures = game.ServerGame.LatestTurnStanding.Territories[territoryId].Structures;
		if (structures ~= nil and structures[triggeredBarbedWireStructId] ~= nil and structures[triggeredBarbedWireStructId] > 0) then
			-- clamp in case the structure count and tracked pieces ever disagree, so we never go negative
			local resettingCount = math.min(dueCount, structures[triggeredBarbedWireStructId]);

			structures[triggeredBarbedWireStructId] = structures[triggeredBarbedWireStructId] - resettingCount;
			if (not Mod.Settings.BarbedWireSingleUse) then
				structures[primedBarbedWireStructId] = (structures[primedBarbedWireStructId] or 0) + resettingCount;
			end

			anyReset = true;
			local territoryModification = WL.TerritoryModification.Create(territoryId);
			territoryModification.SetStructuresOpt = structures;

			table.insert(territoryModifications, territoryModification);
		end
	end

	if (anyReset) then
		local eventMessage = Mod.Settings.BarbedWireSingleUse and "Barbed Wire expires" or "Reset Barbed Wire";
		local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, eventMessage, {}, territoryModifications);
		event.Icon = Mod.Settings.BarbedWireSingleUse and "Destroyed" or "Reset";
		addNewOrder(event);
	end

	privateGameData.BarbedWires = barbedWires;
	Mod.PrivateGameData = privateGameData;
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function V2.BuildStructures(game, addNewOrder)

	local structureID = WL.StructureType.Custom("PrimedBarbedWire");

	local privateGameData = Mod.PrivateGameData --[[@as V2_PrivateGameData]];
	local pending = privateGameData.PendingBarbedWire;

	if (pending == nil) then return; end;

	-- Split pending builds into ones we can still build and ones we removed because ownership changed.
	local removedPendingBarbedWire = {};
	local remainingPendingBarbedWire = {};
	for _,pendingDms in pairs(pending) do
		if (pendingDms.PlayerID ~= game.ServerGame.LatestTurnStanding.Territories[pendingDms.TerritoryID].OwnerPlayerID) then
			table.insert(removedPendingBarbedWire, pendingDms);
		else
			table.insert(remainingPendingBarbedWire, pendingDms);
		end
	end

	pending = remainingPendingBarbedWire;

	-- We will now build a barbed wire for each pending barbed wire. However, we need to take care to ensure that if there are two build orders for the same territory that we build both of them,
	--	so we first group by the territory ID so we get all build orders for the same territory together.
	for territoryID,pendingBarbedWireGroup in pairs(groupBy(pending, function(t) return t.TerritoryID; end)) do

		local numBarbedWireToBuild = #pendingBarbedWireGroup;

		-- track each newly built piece individually so it can be found and removed on its own later
		if (privateGameData.BarbedWires == nil) then privateGameData.BarbedWires = {}; end;
		for _ = 1, numBarbedWireToBuild do
			---@type V2_BarbedWire
			local newBarbedWire = {
				TerritoryID = territoryID,
				Triggered = false,
				FinalTurnTriggered = nil,
				FinalTurnExpires = Mod.Settings.BarbedWireHasLimitedLifespan and (game.ServerGame.Game.TurnNumber + Mod.Settings.BarbedWireLifespan) or nil,
			};
			table.insert(privateGameData.BarbedWires, newBarbedWire);
		end

		local structures = game.ServerGame.LatestTurnStanding.Territories[territoryID].Structures;

		if (structures == nil) then structures = {}; end;
		if (structures[structureID] == nil) then
			structures[structureID] = numBarbedWireToBuild;
		else
			structures[structureID] = structures[structureID] + numBarbedWireToBuild;
		end

		local territoryModification = WL.TerritoryModification.Create(territoryID);
		territoryModification.SetStructuresOpt = structures;

		local pendingBarbedWire = first(pendingBarbedWireGroup);
		if (pendingBarbedWire ~= nil) then
			local event = WL.GameOrderEvent.Create(pendingBarbedWire.PlayerID, pendingBarbedWire.Message, {}, {territoryModification});

			local td = game.Map.Territories[territoryID];
			event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
			event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Build Barbed Wire", 8, GetColourIntegerFromHex(BUTTON_COLOURS.DarkGreen)) };
			event.Icon = "Build";

			addNewOrder(event);
		end
	end

	for territoryID,pendingBarbedWireGroup in pairs(groupBy(removedPendingBarbedWire, function(t) return t.TerritoryID; end)) do
		local pendingBarbedWire = first(pendingBarbedWireGroup);
		if (pendingBarbedWire ~= nil) then
			local event = WL.GameOrderEvent.Create(pendingBarbedWire.PlayerID, "Unable to build Barbed Wire on " .. game.Map.Territories[territoryID].Name, {}, {});

			local td = game.Map.Territories[territoryID];
			event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
			event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Unable to build Barbed Wire", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Red)) };
			event.Icon = "BuildFailed";

			addNewOrder(event);
		end
	end

	privateGameData.PendingBarbedWire = nil;
	Mod.PrivateGameData = privateGameData;
end
