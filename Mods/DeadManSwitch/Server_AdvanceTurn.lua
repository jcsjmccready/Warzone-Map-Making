require("Utilities.CommonUtils");
require("IO.ModAuth");
require("Actions.ManualDamage");
require("Actions.NukeKrinid");
require("Actions.VanillaCards");

---Server_AdvanceTurn_Start
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
function Server_AdvanceTurn_Start(game, addNewOrder)
	IO.ModAuth.Reset();
end

---Server_AdvanceTurn_Order
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
	-- this mod accepts no orders from other mods other than handshake orders
	if (IO.ModAuth.ProcessOrder(
        order,
        addNewOrder,
        skipThisOrder
    )) then return; end

	-- Create DMS action
    if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, CREATE_DMS_MOD_DATA_PREFIX)) then
		---@cast order GameOrderPlayCardCustom
        local targetTerritoryID = tonumber(string.sub(order.ModData, #CREATE_DMS_MOD_DATA_PREFIX + 1))
		if (targetTerritoryID == nil) then return; end; --ModData doesn't contain a territory ID

		---@cast targetTerritoryID TerritoryID
		local targetTerritory = game.ServerGame.LatestTurnStanding.Territories[targetTerritoryID];
		if (targetTerritory == nil or targetTerritory.OwnerPlayerID ~= order.PlayerID) then
			return; --not a real territory, or not our territory
		end

		QueueDmsCreate(order.PlayerID, order.Description, targetTerritoryID);
    end

	-- Check if this is an attack against a territory with a dms.
	if (order.proxyType == 'GameOrderAttackTransfer' and result.IsAttack and result.IsSuccessful) then
		---@cast order GameOrderAttackTransfer
		---@cast result GameOrderAttackTransferResult
		HandleSuccessfulAttack(game, order, result, addNewOrder);
	end
end

---Stores a DMS to be built at the end of the turn
---@param playerID PlayerID # The player building the DMS
---@param message string # The message shown when the DMS is built
---@param targetTerritoryID TerritoryID # The territory to build the DMS on
function QueueDmsCreate(playerID, message, targetTerritoryID)
	local pendingDMS = {};
	pendingDMS.PlayerID = playerID;
	pendingDMS.Message = message;
	pendingDMS.TerritoryID = targetTerritoryID;

	local privateGameData = Mod.PrivateGameData;
	if (privateGameData.PendingDMS == nil) then privateGameData.PendingDMS = {}; end;
	table.insert(privateGameData.PendingDMS, pendingDMS);

	Mod.PrivateGameData = privateGameData;
end

---Triggers the DMS actions if a successful attack captured a territory containing a DMS
---@param game GameServerHook
---@param order GameOrderAttackTransfer # The successful attack
---@param result GameOrderAttackTransferResult
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
function HandleSuccessfulAttack(game, order, result, addNewOrder)
	local structureID = WL.StructureType.Custom("Dead Man's Switch");
	local existingStructures = game.ServerGame.LatestTurnStanding.Territories[order.To].Structures;

	if (existingStructures == nil) then return; end;

	local numberOfDMS = 0;
	if (existingStructures[structureID] ~= nil) then
		numberOfDMS = numberOfDMS + existingStructures[structureID];
	end

	--If no DMS here, abort.
	if (numberOfDMS == 0) then return; end;

	--If an attack of 0, abort, so skipped orders don't destroy the DMS
	if (result.ActualArmies.IsEmpty) then return; end;

	-- abort if on same team and ally triggers is disabled
	local territoryOwnerPlayerID = game.ServerGame.LatestTurnStanding.Territories[order.To].OwnerPlayerID;
	local attackerTeam = game.ServerGame.Game.Players[order.PlayerID].Team;
	local ownerTeam = WL.PlayerID.Neutral;
	if (game.ServerGame.Game.Players[territoryOwnerPlayerID] ~= nil) then
		ownerTeam = game.ServerGame.Game.Players[territoryOwnerPlayerID].Team;
	end

	if(attackerTeam ~= nil and ownerTeam ~= nil
		and attackerTeam ~=-1 and ownerTeam ~=-1
		and attackerTeam == ownerTeam
		and Mod.Settings.AllyTriggers == false) then
		return;
	end;

	local structures = {};

	-- copy old structures but skip dms
	for key, value in pairs(existingStructures or {}) do
		if(key ~= structureID) then
			structures[key] = value;
		end;
	end

	structures[structureID] = 0;
	local territoryModification = WL.TerritoryModification.Create(order.To);
	territoryModification.SetStructuresOpt = structures;

	TriggerPrimaryActions(territoryModification, game, order, result, addNewOrder, numberOfDMS);
	TriggerSecondaryActions(territoryModification, game, order, result, addNewOrder, numberOfDMS);
end

---Adds the event that shows a DMS was triggered, applying the DMS territory modification
---@param order GameOrderAttackTransfer # The attack that triggered the DMS
---@param territoryModification TerritoryModification # The DMS territory modification to attach to the event
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean) # Adds a game order, the second argument skips it if the triggering order is skipped
function AddTriggeredEvent(order, territoryModification, addNewOrder)
	local event = WL.GameOrderEvent.Create(order.PlayerID, "Triggered a Dead Man's Switch", {}, {territoryModification});
	event.TerritoryAnnotationsOpt = { [order.To] = WL.TerritoryAnnotation.Create("Triggered DMS", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
	event.Icon = "Triggered";
	addNewOrder(event, true);
end

---Triggers the single primary action selected in the mod settings (damage, card or nuke)
---@param territoryModification TerritoryModification # The DMS territory modification (destroying the DMS)
---@param game GameServerHook
---@param order GameOrderAttackTransfer # The attack that triggered the DMS
---@param result GameOrderAttackTransferResult
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param numberOfDMS integer # How many DMS were on the captured territory
function TriggerPrimaryActions(territoryModification, game, order, result, addNewOrder, numberOfDMS)
	if (Mod.Settings.isDamageTypeBomb) then Actions.VanillaCards.Bomb.Trigger(territoryModification, game, order, result, addNewOrder, numberOfDMS);
	elseif (Mod.Settings.isDamageTypeBlockade) then Actions.VanillaCards.Blockade.Trigger(territoryModification, game, order, result, addNewOrder, numberOfDMS);
	elseif (Mod.Settings.isDamageTypeEmergencyBlockade) then Actions.VanillaCards.EmergencyBlockade.Trigger(territoryModification, game, order, result, addNewOrder, numberOfDMS);

	elseif (Mod.Settings.isDamageTypeFlat) then Actions.ManualDamage.Flat.Trigger(territoryModification, game, order, result, addNewOrder, numberOfDMS);
	elseif (Mod.Settings.isDamageTypePercent) then Actions.ManualDamage.Percent.Trigger(territoryModification, game, order, result, addNewOrder, numberOfDMS);

	elseif (Mod.Settings.isDamageTypeNuke) then Actions.NukeKrinid.Trigger(territoryModification, game, order, result, addNewOrder, numberOfDMS);
	end
end

---Triggers every secondary action enabled in the mod settings, these do not conflict with each other so can each be triggered.
---@param territoryModification TerritoryModification # The DMS territory modification (destroying the DMS)
---@param game GameServerHook
---@param order GameOrderAttackTransfer # The attack that triggered the DMS
---@param result GameOrderAttackTransferResult
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param numberOfDMS integer # How many DMS were on the captured territory
function TriggerSecondaryActions(territoryModification, game, order, result, addNewOrder, numberOfDMS)
	if (Mod.Settings.isDamageTypeSanction) then Actions.VanillaCards.Sanction.Trigger(territoryModification, game, order, result, addNewOrder, numberOfDMS); end

	if (Mod.Settings.isDamageTypeDiplomacy) then
		Actions.VanillaCards.Diplomacy.Trigger(territoryModification, game, order, result, addNewOrder, numberOfDMS);
	end

	if (Mod.Settings.isDamageTypeSpy) then
		Actions.VanillaCards.Spy.Trigger(territoryModification, game, order, result, addNewOrder, numberOfDMS);
	end
end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_End(game, addNewOrder)
	BuildStructures(game, addNewOrder);
	PlayEndOfTurnActions(game, addNewOrder);
	ReportUnansweredAuths(game, addNewOrder);
end

---Adds an error event, shown to every player, for each mod this mod called that never answered
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
function ReportUnansweredAuths(game, addNewOrder)
	local unansweredModKeys = IO.ModAuth.GetUnansweredAuths();
	if (#unansweredModKeys == 0) then return; end

	local playerIDs = GetPlayingPlayerIDs(game);
	if (#playerIDs == 0) then return; end

	for _, unansweredModKey in ipairs(unansweredModKeys) do
		local message = "MOD ERROR: DMS missing ACK from " .. unansweredModKey .. ". Is " .. unansweredModKey .. " enabled?";
		addNewOrder(WL.GameOrderEvent.Create(playerIDs[1], message, playerIDs, {}));
	end
end

---Returns the IDs of every player still playing the game
---@param game GameServerHook
---@return PlayerID[]
function GetPlayingPlayerIDs(game)
	local playerIDs = {};
	for playerID, _ in pairs(game.ServerGame.Game.PlayingPlayers) do
		table.insert(playerIDs, playerID);
	end
	return playerIDs;
end

---Plays any trigger actions that were queued during the turn to be played at the end of it
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
function PlayEndOfTurnActions(game, addNewOrder)
	Actions.VanillaCards.Blockade.PlayPending(addNewOrder);
	Actions.VanillaCards.Diplomacy.PlayPending(addNewOrder);
end

---Builds the DMS structures queued by played DMS cards, skipping territories that changed owner
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
function BuildStructures(game, addNewOrder)

	local structureID = WL.StructureType.Custom("Dead Man's Switch");

	local privateGameData = Mod.PrivateGameData;
	local pending = privateGameData.PendingDMS;

	if (pending == nil) then return; end;

	-- Split pending builds into ones we can still build and ones we removed because ownership changed.
	local removedPendingDMS = {};
	local remainingPendingDMS = {};
	for _,pendingDms in pairs(pending) do
		if (pendingDms.PlayerID ~= game.ServerGame.LatestTurnStanding.Territories[pendingDms.TerritoryID].OwnerPlayerID) then
			table.insert(removedPendingDMS, pendingDms);
		else
			table.insert(remainingPendingDMS, pendingDms);
		end
	end

	pending = remainingPendingDMS;

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
		if (pendingDms ~= nil) then
			local event = WL.GameOrderEvent.Create(pendingDms.PlayerID, pendingDms.Message, {}, {territoryModification});

			local td = game.Map.Territories[territoryID];
			event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
			event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Build DMS", 8, GetColourIntegerFromHex(BUTTON_COLOURS.DarkGreen)) };
			event.Icon = "Build";

			addNewOrder(event);
		end
	end

	for territoryID,pendingDmsGroup in pairs(groupBy(removedPendingDMS, function(t) return t.TerritoryID; end)) do
		local pendingDms = first(pendingDmsGroup);
		if (pendingDms ~= nil) then
			local event = WL.GameOrderEvent.Create(pendingDms.PlayerID, "Unable to build Dead Man's Switch on " .. game.Map.Territories[territoryID].Name, {}, {});

			local td = game.Map.Territories[territoryID];
			event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
			event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Unable to build DMS", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Red)) };
			event.Icon = "BuildFailed";

			addNewOrder(event);
		end
	end

	privateGameData.PendingDMS = nil;
	Mod.PrivateGameData = privateGameData;
end