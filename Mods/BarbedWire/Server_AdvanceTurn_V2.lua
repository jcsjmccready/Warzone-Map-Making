require("Utilities");

--Settings version 2 behaviour

---@class V2_TrapSettings
---@field TriggerDuration integer # Turns a triggered trap keeps blocking movement before it resets/destroys
---@field AllyTriggers boolean # Whether allies (not just enemies) can trigger this trap
---@field TrapsArmies boolean # Whether a triggered trap blocks normal armies moving out
---@field TrapsSpecialUnits boolean # Whether a triggered trap blocks special units moving out
---@field CancelsAirlifts boolean # Whether a primed or triggered trap cancels airlifts out of the territory
---@field BombDestroys boolean # Whether a bomb played on the territory destroys the trap
---@field OnlyTriggersOnTrappableUnits boolean # Whether the trap only triggers if the successful attack involved units it would trap (armies and/or special units, per the Traps* flags)
---@field SingleUse boolean # Whether the trap is destroyed (rather than reset to primed) once its trigger duration ends
---@field HasLimitedLifespan boolean # Whether primed/triggered pieces expire after a set number of turns
---@field Lifespan integer | nil # Turns before a piece expires - only meaningful when HasLimitedLifespan is true
---@field IsImmuneUnitEnabled boolean # Whether the immune unit gets special treatment (ignore or destroy) rather than being trapped like any other special unit
---@field ImmuneUnitName string # Name of the custom special unit that gets the immune unit behaviour below - only meaningful when IsImmuneUnitEnabled is true
---@field ImmuneUnitIgnores boolean # The immune unit ignores this trap entirely - only meaningful when IsImmuneUnitEnabled is true
---@field ImmuneUnitDestroys boolean # The immune unit destroys this trap on entry/exit - only meaningful when IsImmuneUnitEnabled is true

---@class V2_TrapType
---@field Key string # "BarbedWire" | "Caltrop" - the one distinguisher (see above)
---@field DisplayName string # e.g. "Barbed Wire" - used in player-facing messages
---@field PrimedStructureName string # name passed to WL.StructureType.Custom for the primed structure
---@field TriggeredStructureName string # name passed to WL.StructureType.Custom for the triggered structure

---@class V2_PendingTrap
---@field PlayerID PlayerID
---@field Message string
---@field TerritoryID TerritoryID
---@field IsCommerce boolean # True if bought via the Commerce menu - subject to <Prefix>MaxPerPlayer, re-checked at build time

---@class V2_TrapPiece
---@field TerritoryID TerritoryID
---@field Triggered boolean
---@field FinalTurnTriggered integer | nil
---@field FinalTurnExpires integer | nil # nil if lifespan is unlimited

---@class V2_PrivateGameData
---@field PendingTraps table<string, V2_PendingTrap[]> # Pending builds, keyed by V2_TrapType.Key
---@field Traps table<string, V2_TrapPiece[]> # Every individual trap piece currently in play (one entry per physical piece), keyed by V2_TrapType.Key

V2 = {}

V2.BarbedWireTrapType = {
	Key = "BarbedWire",
	DisplayName = "Barbed Wire",
	PrimedStructureName = "PrimedBarbedWire",
	TriggeredStructureName = "TriggeredBarbedWire",
};

V2.CaltropTrapType = {
	Key = "Caltrop",
	DisplayName = "Caltrop",
	PrimedStructureName = "PrimedCaltrop",
	TriggeredStructureName = "TriggeredCaltrop",
};

V2.AllTrapTypes = { V2.BarbedWireTrapType, V2.CaltropTrapType };

---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function V2.Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)

	if (order.proxyType == 'GameOrderPlayCardCustom') then
		local modData = (order --[[@as GameOrderPlayCardCustom]]).ModData;
		for _, trapType in ipairs(V2.AllTrapTypes) do
			local prefix = V2.GetCardModDataPrefix(trapType);
			if (startsWith(modData, prefix)) then
				local targetTerritoryID = tonumber(string.sub(modData, #prefix + 1)) --[[@as TerritoryID]]
				V2.QueuePendingTrap(trapType, order.PlayerID, targetTerritoryID, (order --[[@as GameOrderPlayCardCustom]]).Description, false);
				return;
			end
		end
	end

	if (order.proxyType == 'GameOrderCustom') then
		local payload = (order --[[@as GameOrderCustom]]).Payload;
		for _, trapType in ipairs(V2.AllTrapTypes) do
			local prefix = V2.GetCommercePayloadPrefix(trapType);
			if (startsWith(payload, prefix)) then
				---@cast order GameOrderCustom
				local targetTerritoryID = tonumber(string.sub(payload, #prefix + 1)) --[[@as TerritoryID]]
				V2.QueuePendingTrap(trapType, order.PlayerID, targetTerritoryID, "Built a " .. trapType.DisplayName, true);
				return;
			end
		end
	end

	if (order.proxyType == 'GameOrderAttackTransfer') then
		V2.HandleAttackTransfer(game, order, result, skipThisOrder, addNewOrder);
	elseif (order.proxyType == 'GameOrderPlayCardBomb') then
		V2.HandleBombOnTraps(V2.AllTrapTypes, game, order, addNewOrder);
	elseif (order.proxyType == 'GameOrderPlayCardAirlift') then
		V2.HandleAirliftFromTrap(game, order, skipThisOrder, addNewOrder);
	end
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function V2.Server_AdvanceTurn_End(game, addNewOrder)
	for _, trapType in ipairs(V2.AllTrapTypes) do
		V2.BuildTrapStructures(trapType, game, addNewOrder);
		V2.ExpireTrap(trapType, game, addNewOrder);
		V2.ResetTriggeredTrap(trapType, game, addNewOrder);
	end
end

---Everything an attack/transfer order does with traps: blocked by triggered traps at order.From, then
---immune-unit-destroy and triggering of traps at order.To.
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function V2.HandleAttackTransfer(game, order, result, skipThisOrder, addNewOrder)
	V2.HandleAttackTransferFromTriggeredTraps(V2.AllTrapTypes, game, order, result, skipThisOrder, addNewOrder);
	V2.HandleAttackTransferToTraps(V2.AllTrapTypes, game, order, result, addNewOrder);
end

---@param trapTypes V2_TrapType[]
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
---@return boolean tookOverOrder true if this fully took over resolving the order (skipped it) - the caller must not run further trap logic against `result` for this order
function V2.HandleAttackTransferFromTriggeredTraps(trapTypes, game, order, result, skipThisOrder, addNewOrder)
	---@cast order GameOrderAttackTransfer
	---@cast result GameOrderAttackTransferResult

	if (result.ActualArmies == nil) then return false; end;

	local existingStructures = game.ServerGame.LatestTurnStanding.Territories[order.From].Structures;
	if (existingStructures == nil) then return false; end;

	-- Which trap types are triggered on order.From and actually apply to this stack. A trap that ignores
	-- immune units doesn't apply at all (not even to the other units) when its immune unit is moving.
	local trapsArmies = false;
	local trapsSpecialUnits = false;
	local blockingTrapNames = {};
	for _, trapType in ipairs(trapTypes) do
		local _, triggeredStructId = V2.GetStructureIds(trapType);
		if ((existingStructures[triggeredStructId] or 0) > 0) then
			local trapSettings = V2.GetTrapSettings(trapType);
			if (not (trapSettings.ImmuneUnitIgnores and V2.HasImmuneUnit(trapSettings, result.ActualArmies.SpecialUnits))) then
				-- most restrictive wins: something is trapped if any applicable trap traps it
				trapsArmies = trapsArmies or trapSettings.TrapsArmies;
				trapsSpecialUnits = trapsSpecialUnits or trapSettings.TrapsSpecialUnits;
				table.insert(blockingTrapNames, trapType.DisplayName);
			end
		end
	end

	if (#blockingTrapNames == 0) then return false; end;
	local blockedBy = table.concat(blockingTrapNames, " and ");

	local blockingArmies = trapsArmies and result.ActualArmies.NumArmies > 0;
	local blockingSpecialUnits = trapsSpecialUnits and #result.ActualArmies.SpecialUnits > 0;

	-- nothing the traps here are configured to trap is actually in the moving stack
	if (not blockingArmies and not blockingSpecialUnits) then return false; end;

	local remainingNumArmies = trapsArmies and 0 or result.ActualArmies.NumArmies;
	local remainingSpecialUnits = trapsSpecialUnits and {} or result.ActualArmies.SpecialUnits;

	if (remainingNumArmies == 0 and #remainingSpecialUnits == 0) then
		-- everything present is trapped: a simple full block. WZ hasn't finished processing this order yet,
		-- so overwriting ActualArmies here is enough - WZ recomputes the rest of the order (casualties,
		-- success) against this smaller force itself.
		result.ActualArmies = WL.Armies.Create(0);
		local event = WL.GameOrderEvent.Create(order.PlayerID, 'Movement blocked by ' .. blockedBy, {}, {});
		event.TerritoryAnnotationsOpt = { [order.From] = WL.TerritoryAnnotation.Create("Armies trapped", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
		event.Icon = "Blocked"
		addNewOrder(event);
		return false;
	end

	-- Only part of the stack is trapped. We can't just shrink ActualArmies and let WZ carry on: WZ would
	-- resolve the attack's casualties/success using the REDUCED force's numbers alone as if that's all
	-- that ever existed, silently discarding the trapped units instead of leaving them behind at the
	-- source. Take over entirely instead: skip the order, and manually resolve it as an attack/transfer
	-- of only the untrapped portion via process_manual_attack, leaving the trapped portion at order.From.
	skipThisOrder(WL.ModOrderControl.SkipAndSupressSkippedMessage);
	V2.ResolvePartialTrapBlock(blockedBy, game, order, result, remainingNumArmies, remainingSpecialUnits, addNewOrder);
	return true;
end

---Manually resolves an attack/transfer order that a triggered trap has only partially blocked: the units
---in remainingNumArmies/remainingSpecialUnits move as normal (fighting if order.To is hostile), while
---everything else in the original order.ActualArmies stays behind at order.From, trapped.
---@param blockedBy string # names of the trap(s) doing the blocking, for the event message
---@param game GameServerHook
---@param order GameOrderAttackTransfer
---@param result GameOrderAttackTransferResult
---@param remainingNumArmies integer
---@param remainingSpecialUnits SpecialUnit[]
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function V2.ResolvePartialTrapBlock(blockedBy, game, order, result, remainingNumArmies, remainingSpecialUnits, addNewOrder)
	local fromTerritory = game.ServerGame.LatestTurnStanding.Territories[order.From];
	local toTerritory = game.ServerGame.LatestTurnStanding.Territories[order.To];
	local fromTerritoryName = game.Map.Territories[order.From].Name;
	local toTerritoryName = game.Map.Territories[order.To].Name;

	local trappedNumArmies = result.ActualArmies.NumArmies - remainingNumArmies;
	local trappedNumSpecialUnits = #result.ActualArmies.SpecialUnits - #remainingSpecialUnits;
	local trappedDescription = DescribeArmyMovement(trappedNumArmies, {}) .. (trappedNumSpecialUnits > 0 and (" and " .. trappedNumSpecialUnits .. " special unit(s)") or "");

	local fromMod = WL.TerritoryModification.Create(order.From);
	local toMod = WL.TerritoryModification.Create(order.To);
	local message;
	local extraFromChunks = {};
	local extraToChunks = {};

	if (not result.IsAttack) then
		-- transfer - can simply move
		fromMod.SetArmiesTo = fromTerritory.NumArmies.NumArmies - remainingNumArmies;
		fromMod.RemoveSpecialUnitsOpt = map(remainingSpecialUnits, function(unit) return unit.ID end);

		toMod.AddArmies = remainingNumArmies;
		extraToChunks = AssignAddSpecialUnits(toMod, remainingSpecialUnits);

		message = DescribeArmyMovement(remainingNumArmies, remainingSpecialUnits) .. " transferred to " .. toTerritoryName .. " from " .. fromTerritoryName;
	else
		local movingArmies = WL.Armies.Create(remainingNumArmies, remainingSpecialUnits);
		local attackResult = process_manual_attack(game, movingArmies, toTerritory, nil, addNewOrder, false);

		if (attackResult.IsSuccessful) then
			fromMod.SetArmiesTo = fromTerritory.NumArmies.NumArmies - remainingNumArmies;
			fromMod.RemoveSpecialUnitsOpt = map(remainingSpecialUnits, function(unit) return unit.ID end);

			toMod.SetOwnerOpt = order.PlayerID;
			toMod.SetArmiesTo = attackResult.AttackerResult.RemainingArmies;
			toMod.RemoveSpecialUnitsOpt = attackResult.DefenderResult.KilledSpecials;
			extraToChunks = AssignAddSpecialUnits(toMod, attackResult.AttackerResult.SurvivingSpecials);

			message = DescribeArmyMovement(remainingNumArmies, remainingSpecialUnits) .. " captured " .. toTerritoryName .. " from " .. fromTerritoryName;
		else
			fromMod.SetArmiesTo = (fromTerritory.NumArmies.NumArmies - remainingNumArmies) + attackResult.AttackerResult.RemainingArmies;
			fromMod.RemoveSpecialUnitsOpt = attackResult.AttackerResult.KilledSpecials;
			extraFromChunks = AssignAddSpecialUnits(fromMod, attackResult.AttackerResult.ClonedSpecials);

			toMod.SetArmiesTo = attackResult.DefenderResult.RemainingArmies;
			toMod.RemoveSpecialUnitsOpt = attackResult.DefenderResult.KilledSpecials;
			extraToChunks = AssignAddSpecialUnits(toMod, attackResult.DefenderResult.ClonedSpecials);

			message = DescribeArmyMovement(remainingNumArmies, remainingSpecialUnits) .. " failed to capture " .. toTerritoryName .. " from " .. fromTerritoryName;
		end
	end

	local event = WL.GameOrderEvent.Create(order.PlayerID, message .. " (" .. trappedDescription .. " trapped by " .. blockedBy .. ")", {}, { fromMod, toMod });
	event.TerritoryAnnotationsOpt = { [order.From] = WL.TerritoryAnnotation.Create("Partially trapped", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
	event.Icon = "Blocked";
	addNewOrder(event);

	QueueExtraSpecialUnitEvents(order.From, extraFromChunks, order.PlayerID, addNewOrder);
	QueueExtraSpecialUnitEvents(order.To, extraToChunks, order.PlayerID, addNewOrder);
end

---@param trapTypes V2_TrapType[]
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function V2.HandleAttackTransferToTraps(trapTypes, game, order, result, addNewOrder)
	---@cast order GameOrderAttackTransfer
	---@cast result GameOrderAttackTransferResult

	-- Nothing moving (0 armies and 0 special units): skip both phases below, nothing for either to do.
	if (result.ActualArmies == nil or result.ActualArmies.IsEmpty) then
		return;
	end

	local remainingStructuresTo = game.ServerGame.LatestTurnStanding.Territories[order.To].Structures;
	for _, trapType in ipairs(trapTypes) do
		remainingStructuresTo = V2.HandleImmuneUnitDestroyTrap(trapType, game, order, result, remainingStructuresTo, addNewOrder);
	end

	V2.HandleTrapTriggers(trapTypes, game, order, result, remainingStructuresTo, addNewOrder);
end

---If <Prefix>ImmuneUnitDestroys is on and the moving stack includes its immune unit, destroys any trap at both ends of
---the order (it attacks into order.To and comes from order.From).
---@param trapType V2_TrapType
---@param game GameServerHook
---@param order GameOrderAttackTransfer
---@param result GameOrderAttackTransferResult
---@param remainingStructuresTo table<EnumStructureType, integer> | nil # order.To's structures so far (earlier trap types' destruction already applied)
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
---@return table<EnumStructureType, integer> | nil remainingStructuresTo the (possibly trap-cleared) structures at order.To, for HandleTrapTriggers to use
function V2.HandleImmuneUnitDestroyTrap(trapType, game, order, result, remainingStructuresTo, addNewOrder)
	local trapSettings = V2.GetTrapSettings(trapType);
	if (not (trapSettings.ImmuneUnitDestroys and result.ActualArmies ~= nil and result.ActualArmies.SpecialUnits ~= nil)) then
		return remainingStructuresTo;
	end

	if (not V2.HasImmuneUnit(trapSettings, result.ActualArmies.SpecialUnits)) then
		return remainingStructuresTo;
	end

	local primedStructId, triggeredStructId = V2.GetStructureIds(trapType);
	local privateGameData = Mod.PrivateGameData --[[@as V2_PrivateGameData]];

	local newStructuresTo = V2.DestroyTrapAt(trapType, order.To, remainingStructuresTo, primedStructId, triggeredStructId, privateGameData, order.PlayerID, addNewOrder);
	if (newStructuresTo ~= nil) then
		remainingStructuresTo = newStructuresTo;
	end

	local existingStructuresFrom = game.ServerGame.LatestTurnStanding.Territories[order.From].Structures;
	V2.DestroyTrapAt(trapType, order.From, existingStructuresFrom, primedStructId, triggeredStructId, privateGameData, order.PlayerID, addNewOrder);

	-- commit any removals above now, since HandleTrapTrigger has early returns that would otherwise skip the write-back
	Mod.PrivateGameData = privateGameData;

	return remainingStructuresTo;
end

---Whether specialUnit is the immune unit for this trap (the one that gets the special ignore/destroy behaviour) - matched by its name
---(trapSettings.ImmuneUnitName).
---@param trapSettings V2_TrapSettings
---@param specialUnit SpecialUnit
---@return boolean
function V2.IsImmuneUnit(trapSettings, specialUnit)
	return specialUnit ~= nil
		and specialUnit.proxyType == "CustomSpecialUnit"
		and (specialUnit --[[@as CustomSpecialUnit]]).Name == trapSettings.ImmuneUnitName;
end

---@param trapSettings V2_TrapSettings
---@param specialUnits SpecialUnit[]
---@return boolean # true if any of specialUnits is an immune unit for this trap (see V2.IsImmuneUnit)
function V2.HasImmuneUnit(trapSettings, specialUnits)
	for _, specialUnit in ipairs(specialUnits) do
		if (V2.IsImmuneUnit(trapSettings, specialUnit)) then
			return true;
		end
	end
	return false;
end

---Whether armies contains anything a trap with these settings would trap: armies if it traps armies,
---special units if it traps special units (immune units excluded when they ignore the trap).
---@param trapSettings V2_TrapSettings
---@param armies Armies
---@return boolean
function V2.HasTrappableUnits(trapSettings, armies)
	if (trapSettings.TrapsArmies and armies.NumArmies > 0) then
		return true;
	end

	if (trapSettings.TrapsSpecialUnits and armies.SpecialUnits ~= nil) then
		local immuneUnitIgnores = trapSettings.IsImmuneUnitEnabled and trapSettings.ImmuneUnitIgnores;
		for _, specialUnit in ipairs(armies.SpecialUnits) do
			if (not (immuneUnitIgnores and V2.IsImmuneUnit(trapSettings, specialUnit))) then
				return true;
			end
		end
	end

	return false;
end

---Converts primed traps at order.To into triggered traps, if the order successfully captured the territory
---@param trapTypes V2_TrapType[]
---@param game GameServerHook
---@param order GameOrderAttackTransfer
---@param result GameOrderAttackTransferResult
---@param remainingStructuresTo table<EnumStructureType, integer> | nil
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function V2.HandleTrapTriggers(trapTypes, game, order, result, remainingStructuresTo, addNewOrder)
	if (not result.IsAttack or not result.IsSuccessful) then
		return;
	end

	-- (ActualArmies emptiness is already ruled out by HandleAttackTransferToTraps before this is called)
	local existingStructures = remainingStructuresTo;
	if (existingStructures == nil) then return; end;

	local territoryOwnerPlayerID = game.ServerGame.LatestTurnStanding.Territories[order.To].OwnerPlayerID;
	local attackerTeam = game.ServerGame.Game.Players[order.PlayerID].Team;

	local ownerTeam = WL.PlayerID.Neutral;
	if (game.ServerGame.Game.Players[territoryOwnerPlayerID] ~= nil) then
		ownerTeam = game.ServerGame.Game.Players[territoryOwnerPlayerID].Team;
	end

	local isSameTeam =
		attackerTeam ~= nil and attackerTeam ~= -1
		and ownerTeam ~= nil and ownerTeam ~= -1
		and attackerTeam == ownerTeam;

	local privateGameData = Mod.PrivateGameData --[[@as V2_PrivateGameData]];
	local finalTurnBase = game.ServerGame.Game.TurnNumber;

	-- copy old structures once, then flip each triggering trap's primed count to triggered
	local structures = {};
	for key, value in pairs(existingStructures) do
		structures[key] = value;
	end

	local triggeredNames = {};
	for _, trapType in ipairs(trapTypes) do
		local primedStructId, triggeredStructId = V2.GetStructureIds(trapType);
		local numberOfPrimed = existingStructures[primedStructId] or 0;
		local trapSettings = V2.GetTrapSettings(trapType);

		-- skip if no primed trap here, or on same team and ally triggers is disabled
		if (numberOfPrimed > 0
			and (not isSameTeam or trapSettings.AllyTriggers)
			and (not trapSettings.OnlyTriggersOnTrappableUnits or V2.HasTrappableUnits(trapSettings, result.ActualArmies))) then
			local finalTurnTriggered = finalTurnBase + trapSettings.TriggerDuration;
			for _, piece in pairs(V2.GetTrapPieces(privateGameData, trapType)) do
				if (piece.TerritoryID == order.To and not piece.Triggered) then
					piece.Triggered = true;
					piece.FinalTurnTriggered = finalTurnTriggered;
				end
			end

			structures[primedStructId] = 0;
			structures[triggeredStructId] = numberOfPrimed;
			table.insert(triggeredNames, trapType.DisplayName .. "(s)");
		end
	end

	if (#triggeredNames == 0) then return; end;

	local message = "Triggered " .. table.concat(triggeredNames, " + ");

	local territoryModification = WL.TerritoryModification.Create(order.To);
	territoryModification.SetStructuresOpt = structures;

	local event = WL.GameOrderEvent.Create(order.PlayerID, message, {}, {territoryModification});
	event.TerritoryAnnotationsOpt = { [order.To] = WL.TerritoryAnnotation.Create(message, 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
	event.Icon = "Triggered";
	addNewOrder(event, true);
	Mod.PrivateGameData = privateGameData;
end

---Destroys, on the bombed territory, every trap whose <Prefix>BombDestroys is on.
---@param trapTypes V2_TrapType[]
---@param game GameServerHook
---@param order GameOrder
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function V2.HandleBombOnTraps(trapTypes, game, order, addNewOrder)
	local targetTerritoryID = (order --[[@as GameOrderPlayCardBomb]]).TargetTerritoryID;

	local privateGameData = Mod.PrivateGameData --[[@as V2_PrivateGameData]];
	-- chained so each trap type's destruction builds on the previous one's structures
	local structures = game.ServerGame.LatestTurnStanding.Territories[targetTerritoryID].Structures;
	local destroyedAny = false;

	for _, trapType in ipairs(trapTypes) do
		if (V2.GetTrapSettings(trapType).BombDestroys) then
			local primedStructId, triggeredStructId = V2.GetStructureIds(trapType);
			local newStructures = V2.DestroyTrapAt(trapType, targetTerritoryID, structures, primedStructId, triggeredStructId, privateGameData, order.PlayerID, addNewOrder);
			if (newStructures ~= nil) then
				structures = newStructures;
				destroyedAny = true;
			end
		end
	end

	if (destroyedAny) then
		Mod.PrivateGameData = privateGameData;
	end
end

---@param game GameServerHook
---@param order GameOrder
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function V2.HandleAirliftFromTrap(game, order, skipThisOrder, addNewOrder)
	---@cast order GameOrderPlayCardAirlift

	-- primed and triggered structures both cancel airlifts
	local trapStructIds = {};
	for _, trapType in ipairs(V2.AllTrapTypes) do
		if (V2.GetTrapSettings(trapType).CancelsAirlifts) then
			local primedStructId, triggeredStructId = V2.GetStructureIds(trapType);
			table.insert(trapStructIds, primedStructId);
			table.insert(trapStructIds, triggeredStructId);
		end
	end

	if (#trapStructIds == 0) then
		return;
	end

	local existingStructures = game.ServerGame.LatestTurnStanding.Territories[order.FromTerritoryID].Structures;
	if (existingStructures == nil) then
		return;
	end

	local isTrapped = false;
	for _, structId in ipairs(trapStructIds) do
		if ((existingStructures[structId] or 0) > 0) then
			isTrapped = true;
			break;
		end
	end

	if (not isTrapped) then
		return;
	end

	skipThisOrder(WL.ModOrderControl.SkipAndSupressSkippedMessage);

	local event = WL.GameOrderEvent.Create(order.PlayerID, 'Airlift cancelled by barbed wire/caltrop', {}, {});
	event.TerritoryAnnotationsOpt = { [order.FromTerritoryID] = WL.TerritoryAnnotation.Create("Airlift cancelled", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
	event.Icon = "Blocked";
	addNewOrder(event);
end

---@param trapType V2_TrapType
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function V2.ExpireTrap(trapType, game, addNewOrder)
	local primedStructId, triggeredStructId = V2.GetStructureIds(trapType);

	local privateGameData = Mod.PrivateGameData --[[@as V2_PrivateGameData]];
	local pieces = V2.GetTrapPieces(privateGameData, trapType);
	local currentTurn = game.ServerGame.Game.TurnNumber;

	---@param piece V2_TrapPiece
	local function isDue(piece)
		return piece.FinalTurnExpires ~= nil and piece.FinalTurnExpires <= currentTurn;
	end

	-- count how many due pieces there are per territory, by state. lifespan expiry destroys either, regardless of state
	local duePrimedByTerritory = {};
	local dueTriggeredByTerritory = {};
	for _, piece in pairs(pieces) do
		if (isDue(piece)) then
			local tally = piece.Triggered and dueTriggeredByTerritory or duePrimedByTerritory;
			tally[piece.TerritoryID] = (tally[piece.TerritoryID] or 0) + 1;
		end
	end

	removeWhere(pieces, isDue);

	local anyExpired = false;
	local territoryModifications = {};
	local territoryAnnotations = {};
	for _, territory in pairs(game.ServerGame.LatestTurnStanding.Territories) do
		local duePrimed = duePrimedByTerritory[territory.ID];
		local dueTriggered = dueTriggeredByTerritory[territory.ID];

		local structures = territory.Structures;
		if ((duePrimed ~= nil or dueTriggered ~= nil) and structures ~= nil) then
			local changed = false;

			local existingPrimed = structures[primedStructId];
			if (duePrimed ~= nil and existingPrimed ~= nil and existingPrimed > 0) then
				-- clamp in case the structure count and tracked pieces ever disagree, so we never go negative
				local expiringCount = math.min(duePrimed, existingPrimed);
				structures[primedStructId] = existingPrimed - expiringCount;
				changed = true;
			end

			local existingTriggered = structures[triggeredStructId];
			if (dueTriggered ~= nil and existingTriggered ~= nil and existingTriggered > 0) then
				local expiringCount = math.min(dueTriggered, existingTriggered);
				structures[triggeredStructId] = existingTriggered - expiringCount;
				changed = true;
			end

			if (changed) then
				anyExpired = true;
				local territoryModification = WL.TerritoryModification.Create(territory.ID);
				territoryModification.SetStructuresOpt = structures;

				table.insert(territoryModifications, territoryModification);
				territoryAnnotations[territory.ID] = WL.TerritoryAnnotation.Create(trapType.DisplayName .. " expired", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany));
			end
		end
	end

	if (anyExpired) then
		local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, trapType.DisplayName .. " Expired", {}, territoryModifications);
		event.TerritoryAnnotationsOpt = territoryAnnotations;
		event.Icon = "Destroyed";
		addNewOrder(event);
	end

	Mod.PrivateGameData = privateGameData;
end

---@param trapType V2_TrapType
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function V2.ResetTriggeredTrap(trapType, game, addNewOrder)
	local primedStructId, triggeredStructId = V2.GetStructureIds(trapType);
	local trapSettings = V2.GetTrapSettings(trapType);

	local privateGameData = Mod.PrivateGameData --[[@as V2_PrivateGameData]];
	local pieces = V2.GetTrapPieces(privateGameData, trapType);
	local currentTurn = game.ServerGame.Game.TurnNumber;

	---@param piece V2_TrapPiece
	local function isDue(piece)
		return piece.Triggered and piece.FinalTurnTriggered ~= nil and piece.FinalTurnTriggered <= currentTurn;
	end

	-- count how many due pieces there are per territory before mutating anything
	local dueCountByTerritory = {};
	for _, piece in pairs(pieces) do
		if (isDue(piece)) then
			dueCountByTerritory[piece.TerritoryID] = (dueCountByTerritory[piece.TerritoryID] or 0) + 1;
		end
	end

	if (trapSettings.SingleUse) then
		removeWhere(pieces, isDue);
	else
		-- resets back to primed - keep tracking the piece, just flip its state back
		for _, piece in pairs(pieces) do
			if (isDue(piece)) then
				piece.Triggered = false;
				piece.FinalTurnTriggered = nil;
			end
		end
	end

	local anyReset = false;
	local territoryModifications = {};
	for territoryId, dueCount in pairs(dueCountByTerritory) do
		local structures = game.ServerGame.LatestTurnStanding.Territories[territoryId].Structures;
		if (structures ~= nil and (structures[triggeredStructId] or 0) > 0) then
			-- clamp in case the structure count and tracked pieces ever disagree, so we never go negative
			local resettingCount = math.min(dueCount, structures[triggeredStructId]);

			structures[triggeredStructId] = structures[triggeredStructId] - resettingCount;
			if (not trapSettings.SingleUse) then
				structures[primedStructId] = (structures[primedStructId] or 0) + resettingCount;
			end

			anyReset = true;
			local territoryModification = WL.TerritoryModification.Create(territoryId);
			territoryModification.SetStructuresOpt = structures;

			table.insert(territoryModifications, territoryModification);
		end
	end

	if (anyReset) then
		local eventMessage = trapSettings.SingleUse and (trapType.DisplayName .. " expires") or ("Reset " .. trapType.DisplayName);
		local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, eventMessage, {}, territoryModifications);
		event.Icon = trapSettings.SingleUse and "Destroyed" or "Reset";
		addNewOrder(event);
	end

	Mod.PrivateGameData = privateGameData;
end

---@param trapType V2_TrapType
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function V2.BuildTrapStructures(trapType, game, addNewOrder)
	local primedStructId, triggeredStructId = V2.GetStructureIds(trapType);

	local privateGameData = Mod.PrivateGameData --[[@as V2_PrivateGameData]];
	local pending = privateGameData.PendingTraps ~= nil and privateGameData.PendingTraps[trapType.Key] or nil;

	if (pending == nil) then return; end;

	-- Split pending builds into ones we can still build and ones we removed because ownership changed.
	local removedPending = {};
	local remainingPending = {};
	for _,pendingDms in pairs(pending) do
		if (pendingDms.PlayerID ~= game.ServerGame.LatestTurnStanding.Territories[pendingDms.TerritoryID].OwnerPlayerID) then
			table.insert(removedPending, pendingDms);
		else
			table.insert(remainingPending, pendingDms);
		end
	end

	-- Enforce the Commerce max-per-player cap against a running total, since two Commerce builds queued by the
	-- same player this turn would otherwise both be checked against the same pre-turn count. Card-acquired
	-- pending builds are never capped.
	local trapSettings = V2.GetTrapSettings(trapType);
	local builtCountByPlayer = {};
	local allowedPending = {};
	local cappedPending = {};
	for _, pendingDms in pairs(remainingPending) do
		if (pendingDms.IsCommerce) then
			local maxAllowed = Mod.Settings[trapType.Key .. "MaxPerPlayer"] or 0;
			local existingCount = CountPlayerTrapPieces(game.ServerGame.LatestTurnStanding, pendingDms.PlayerID, primedStructId, triggeredStructId);
			local builtSoFar = builtCountByPlayer[pendingDms.PlayerID] or 0;
			if (existingCount + builtSoFar >= maxAllowed) then
				table.insert(cappedPending, pendingDms);
			else
				builtCountByPlayer[pendingDms.PlayerID] = builtSoFar + 1;
				table.insert(allowedPending, pendingDms);
			end
		else
			table.insert(allowedPending, pendingDms);
		end
	end

	pending = allowedPending;

	-- We will now build a piece for each pending build. However, we need to take care to ensure that if there are two build orders for the same territory that we build both of them,
	--	so we first group by the territory ID so we get all build orders for the same territory together.
	for territoryID,pendingGroup in pairs(groupBy(pending, function(t) return t.TerritoryID; end)) do

		local numToBuild = #pendingGroup;

		-- track each newly built piece individually so it can be found and removed on its own later
		local trapPieces = V2.GetTrapPieces(privateGameData, trapType);
		for _ = 1, numToBuild do
			---@type V2_TrapPiece
			local newPiece = {
				TerritoryID = territoryID,
				Triggered = false,
				FinalTurnTriggered = nil,
				FinalTurnExpires = trapSettings.HasLimitedLifespan and (game.ServerGame.Game.TurnNumber + (trapSettings.Lifespan or 2)) or nil,
			};
			table.insert(trapPieces, newPiece);
		end

		local structures = game.ServerGame.LatestTurnStanding.Territories[territoryID].Structures;

		if (structures == nil) then structures = {}; end;
		structures[primedStructId] = (structures[primedStructId] or 0) + numToBuild;

		local territoryModification = WL.TerritoryModification.Create(territoryID);
		territoryModification.SetStructuresOpt = structures;

		local pendingDms = first(pendingGroup);
		if (pendingDms ~= nil) then
			local event = WL.GameOrderEvent.Create(pendingDms.PlayerID, pendingDms.Message, {}, {territoryModification});

			local td = game.Map.Territories[territoryID];
			event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
			event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Build " .. trapType.DisplayName, 8, GetColourIntegerFromHex(BUTTON_COLOURS.DarkGreen)) };
			event.Icon = "Build";

			addNewOrder(event);
		end
	end

	for territoryID,pendingGroup in pairs(groupBy(removedPending, function(t) return t.TerritoryID; end)) do
		local pendingDms = first(pendingGroup);
		if (pendingDms ~= nil) then
			local event = WL.GameOrderEvent.Create(pendingDms.PlayerID, "Unable to build " .. trapType.DisplayName .. " on " .. game.Map.Territories[territoryID].Name, {}, {});

			local td = game.Map.Territories[territoryID];
			event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
			event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Unable to build " .. trapType.DisplayName, 8, GetColourIntegerFromHex(BUTTON_COLOURS.Red)) };
			event.Icon = "BuildFailed";

			addNewOrder(event);
		end
	end

	for _, pendingDms in pairs(cappedPending) do
		local event = WL.GameOrderEvent.Create(pendingDms.PlayerID, "Unable to build " .. trapType.DisplayName .. ": you already own the maximum number", {}, {});
		event.TerritoryAnnotationsOpt = { [pendingDms.TerritoryID] = WL.TerritoryAnnotation.Create("Unable to build " .. trapType.DisplayName, 8, GetColourIntegerFromHex(BUTTON_COLOURS.Red)) };
		event.Icon = "BuildFailed";
		addNewOrder(event);
	end

	privateGameData.PendingTraps[trapType.Key] = nil;
	Mod.PrivateGameData = privateGameData;
end

---@param trapType V2_TrapType
---@param playerID PlayerID
---@param targetTerritoryID TerritoryID
---@param message string
---@param isCommerce boolean
function V2.QueuePendingTrap(trapType, playerID, targetTerritoryID, message, isCommerce)
	---@type V2_PendingTrap
	local pendingTrap = {
		PlayerID = playerID,
		Message = message,
		TerritoryID = targetTerritoryID,
		IsCommerce = isCommerce,
	};

	local privateGameData = Mod.PrivateGameData --[[@as V2_PrivateGameData]];
	table.insert(V2.GetPendingTraps(privateGameData, trapType), pendingTrap);

	Mod.PrivateGameData = privateGameData;
end

---Destroys any Primed/Triggered trap on territoryID, if present: zeroes those structures, removes
---matching tracked pieces from privateGameData.Traps[trapType.Key], and fires a "<Trap> destroyed" event.
---@param trapType V2_TrapType
---@param territoryID TerritoryID
---@param existingStructures table<EnumStructureType, integer> | nil
---@param primedStructId EnumStructureType
---@param triggeredStructId EnumStructureType
---@param privateGameData V2_PrivateGameData
---@param playerID PlayerID
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
---@return table<EnumStructureType, integer> | nil newStructures the territory's structures with the trap zeroed out, or nil if there was nothing to destroy
function V2.DestroyTrapAt(trapType, territoryID, existingStructures, primedStructId, triggeredStructId, privateGameData, playerID, addNewOrder)
	local hasTrap =
		existingStructures ~= nil and
		((existingStructures[triggeredStructId] or 0) > 0 or (existingStructures[primedStructId] or 0) > 0);

	if (not hasTrap) then
		return nil;
	end
	---@cast existingStructures table<EnumStructureType, integer>

	local newStructures = {};
	newStructures[primedStructId] = 0;
	newStructures[triggeredStructId] = 0;

	-- copy old structures but skip the trap
	for key, value in pairs(existingStructures) do
		if (key ~= primedStructId and key ~= triggeredStructId) then
			newStructures[key] = value;
		end
	end

	local territoryModification = WL.TerritoryModification.Create(territoryID);
	territoryModification.SetStructuresOpt = newStructures;

	removeWhere(V2.GetTrapPieces(privateGameData, trapType), function(w) return w.TerritoryID == territoryID; end);

	local event = WL.GameOrderEvent.Create(playerID, trapType.DisplayName .. ' destroyed', {}, {territoryModification});
	event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create(trapType.DisplayName .. " destroyed", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
	event.Icon = "Destroyed";
	addNewOrder(event, true);

	return newStructures;
end

---@param trapType V2_TrapType
---@return V2_TrapSettings
function V2.GetTrapSettings(trapType)
	local prefix = trapType.Key;

	---@type V2_TrapSettings
	return {
		TriggerDuration = Mod.Settings[prefix .. "TriggerDuration"] or 1,
		AllyTriggers = Mod.Settings[prefix .. "AllyTriggers"] or false,
		TrapsArmies = Mod.Settings[prefix .. "TrapsArmies"] or false,
		TrapsSpecialUnits = Mod.Settings[prefix .. "TrapsSpecialUnits"] or false,
		CancelsAirlifts = Mod.Settings[prefix .. "CancelsAirlifts"] or false,
		BombDestroys = Mod.Settings[prefix .. "BombDestroys"] or false,
		OnlyTriggersOnTrappableUnits = Mod.Settings[prefix .. "OnlyTriggersOnTrappableUnits"] or false,
		SingleUse = Mod.Settings[prefix .. "SingleUse"] or false,
		HasLimitedLifespan = Mod.Settings[prefix .. "HasLimitedLifespan"] or false,
		Lifespan = Mod.Settings[prefix .. "Lifespan"],
		IsImmuneUnitEnabled = Mod.Settings[prefix .. "IsImmuneUnitEnabled"] or false,
		ImmuneUnitName = Mod.Settings[prefix .. "ImmuneUnitName"] or "Tank",
		ImmuneUnitIgnores = Mod.Settings[prefix .. "ImmuneUnitIgnores"] or false,
		ImmuneUnitDestroys = Mod.Settings[prefix .. "ImmuneUnitDestroys"] or false,
	};
end

---@param trapType V2_TrapType
---@return EnumStructureType primedStructId
---@return EnumStructureType triggeredStructId
function V2.GetStructureIds(trapType)
	return WL.StructureType.Custom(trapType.PrimedStructureName), WL.StructureType.Custom(trapType.TriggeredStructureName);
end

---@param trapType V2_TrapType
---@return string # GameOrderPlayCardCustom.ModData prefix for this trap's card build order, e.g. "CreateBarbedWire_"
function V2.GetCardModDataPrefix(trapType)
	return "Create" .. trapType.Key .. "_";
end

---@param trapType V2_TrapType
---@return string # GameOrderCustom.Payload prefix for this trap's Commerce build order, e.g. "CreateBarbedWireCommerce_"
function V2.GetCommercePayloadPrefix(trapType)
	return "Create" .. trapType.Key .. "Commerce_";
end

---@param privateGameData V2_PrivateGameData
---@param trapType V2_TrapType
---@return V2_PendingTrap[] # created and stored if this trap has none yet
function V2.GetPendingTraps(privateGameData, trapType)
	if (privateGameData.PendingTraps == nil) then privateGameData.PendingTraps = {}; end
	if (privateGameData.PendingTraps[trapType.Key] == nil) then privateGameData.PendingTraps[trapType.Key] = {}; end
	return privateGameData.PendingTraps[trapType.Key];
end

---@param privateGameData V2_PrivateGameData
---@param trapType V2_TrapType
---@return V2_TrapPiece[] # created and stored if this trap has none yet
function V2.GetTrapPieces(privateGameData, trapType)
	if (privateGameData.Traps == nil) then privateGameData.Traps = {}; end
	if (privateGameData.Traps[trapType.Key] == nil) then privateGameData.Traps[trapType.Key] = {}; end
	return privateGameData.Traps[trapType.Key];
end
