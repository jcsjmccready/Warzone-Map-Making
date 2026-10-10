require("Utilities");
require("Actions.ManualDamage");
require("Actions.VanillaCards");

----------------------------------------------------------------------------------------------------------------------
-- The DTOs below are Dead Man's Switch's public ModAuth API shapes (see Api.lua), kept here instead so Api.lua can
-- require Application.lua without Application.lua needing to require Api.lua back - a real circular require crashes
-- the mod on load.
----------------------------------------------------------------------------------------------------------------------

---@enum DeadManSwitchAction
DeadManSwitchActions = {
    AddDeadManSwitch = "AddDeadManSwitch",
    TriggerDeadManSwitch = "TriggerDeadManSwitch",
    DestroyDeadManSwitch = "DestroyDeadManSwitch",
};

---Builds a Dead Man's Switch on a territory. End of turn by default
---@class DeadManSwitchAddDeadManSwitchDto
---@field Action "AddDeadManSwitch"
---@field TerritoryID TerritoryID # Required. The territory to build on.
---@field IsImmediate boolean | nil # Optional. Defaults to false (queued for end of turn, the standard behaviour).

---@class DeadManSwitchTriggerDeadManSwitchDto
---@field Action "TriggerDeadManSwitch"
---@field TerritoryID TerritoryID # Required. The territory being captured/triggered.
---@field AttackerPlayerID PlayerID # Required. The player who captured the territory and is on the receiving end of the retaliation effects.
---@field ArmiesOnArrival integer # Required. Armies left on the territory immediately after the capture, before any Dead Man's Switch damage. Used by the flat/percent damage types.
---@field NumSwitches integer | nil # Optional. Defaults to however many Dead Man's Switch instances are on the territory.

---Removes one Dead Man's Switch instance on a territory outright
---@class DeadManSwitchDestroyDeadManSwitchDto
---@field Action "DestroyDeadManSwitch"
---@field TerritoryID TerritoryID # Required. The territory to destroy a switch on.

DeadManSwitchApplication = {};

---@class DeadManSwitchPendingBuild # One queued build, not yet resolved into an actual structure
---@field PlayerID PlayerID # The player who queued it, re-checked for ownership at build time
---@field TerritoryID TerritoryID
---@field Message string # Shown in the order list for the build order itself

---@class DeadManSwitchPendingBlockade
---@field PlayerID PlayerID
---@field TerritoryID TerritoryID

---@class DeadManSwitchPendingDiplomacy
---@field PlayerID PlayerID
---@field PlayerOne PlayerID
---@field PlayerTwo PlayerID

---@class DeadManSwitchPrivateGameData
---@field PendingDMS DeadManSwitchPendingBuild[] | nil # Cleared at the end of every turn once BuildQueuedDeadManSwitches resolves them
---@field PendingBlockade DeadManSwitchPendingBlockade[] | nil # Cleared once PlayPendingBlockades resolves them
---@field PendingDiplomacy DeadManSwitchPendingDiplomacy[] | nil # Cleared once PlayPendingDiplomacy resolves them

---@param standing GameStanding
---@param playerID PlayerID
---@param structureID EnumStructureType
---@param alreadyCounted integer | nil # defaults to 0
---@return boolean
local function IsOverCommerceCap(standing, playerID, structureID, alreadyCounted)
    local isCommerceMode = Mod.Settings.isAcquiringTypeCard ~= nil and not Mod.Settings.isAcquiringTypeCard;
    if (not isCommerceMode) then return false; end;

    local maxAllowed = Mod.Settings.MaxPerPlayer or 0;
    local existingCount = CountPlayerStructures(standing, playerID, structureID);
    return existingCount + (alreadyCounted or 0) >= maxAllowed;
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
---@param territoryID TerritoryID
---@param playerID PlayerID
---@param message string
---@param numToBuild integer
local function BuildDeadManSwitchNow(game, addNewOrder, territoryID, playerID, message, numToBuild)
    local structureID = WL.StructureType.Custom("Dead Man's Switch");

    local structures = game.ServerGame.LatestTurnStanding.Territories[territoryID].Structures or {};
    local copiedStructures = {};
    for key, value in pairs(structures) do
        copiedStructures[key] = value;
    end
    copiedStructures[structureID] = (copiedStructures[structureID] or 0) + numToBuild;

    local territoryModification = WL.TerritoryModification.Create(territoryID);
    territoryModification.SetStructuresOpt = copiedStructures;

    local td = game.Map.Territories[territoryID];
    local event = WL.GameOrderEvent.Create(playerID, message, {}, { territoryModification });
    event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
    event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("DMS(s) built", 8, GetColourIntegerFromHex(BUTTON_COLOURS.DarkGreen)) };
    event.Icon = "Build";
    addNewOrder(event);
end

---Queues a Dead Man's Switch to be built on the target territory at the end of the turn.
---@param playerID PlayerID
---@param targetTerritoryID TerritoryID
---@param message string # Shown in the order list for the eventual build order
function DeadManSwitchApplication.QueueDeadManSwitchBuild(playerID, targetTerritoryID, message)
    local priv = Mod.PrivateGameData --[[@as DeadManSwitchPrivateGameData]];
    local pending = priv.PendingDMS or {};

    table.insert(pending, {
        PlayerID = playerID,
        TerritoryID = targetTerritoryID,
        Message = message,
    });

    priv.PendingDMS = pending;
    Mod.PrivateGameData = priv;
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function DeadManSwitchApplication.BuildQueuedDeadManSwitches(game, addNewOrder)
    local structureID = WL.StructureType.Custom("Dead Man's Switch");
    local priv = Mod.PrivateGameData --[[@as DeadManSwitchPrivateGameData]];
    local pending = priv.PendingDMS;
    if (pending == nil) then return; end;

    -- Split pending builds into ones we can still build and ones we removed because ownership changed.
    local removedPending = {};
    local remainingPending = {};
    for _, build in pairs(pending) do
        local territory = game.ServerGame.LatestTurnStanding.Territories[build.TerritoryID];
        if (territory == nil or territory.OwnerPlayerID ~= build.PlayerID) then
            table.insert(removedPending, build);
        else
            table.insert(remainingPending, build);
        end
    end

    -- MaxPerPlayer only applies when the mod is configured for Commerce acquisition. Enforce it against a running
    -- total, since two builds queued by the same player this turn would otherwise both be checked against the
    -- same pre-turn count.
    local builtCountByPlayer = {};
    local allowedPending = {};
    local cappedPending = {};
    for _, build in pairs(remainingPending) do
        local builtSoFar = builtCountByPlayer[build.PlayerID] or 0;
        if (IsOverCommerceCap(game.ServerGame.LatestTurnStanding, build.PlayerID, structureID, builtSoFar)) then
            table.insert(cappedPending, build);
        else
            builtCountByPlayer[build.PlayerID] = builtSoFar + 1;
            table.insert(allowedPending, build);
        end
    end

    -- success build logic - build everything queued for the same territory together
    for territoryID, buildGroup in pairs(groupBy(allowedPending, function(b) return b.TerritoryID; end)) do
        local build = first(buildGroup);
        if (build ~= nil) then
            BuildDeadManSwitchNow(game, addNewOrder, territoryID, build.PlayerID, build.Message, #buildGroup);
        end
    end

    -- limit hit logic
    for _, build in pairs(cappedPending) do
        local event = WL.GameOrderEvent.Create(build.PlayerID, "Unable to build Dead Man's Switch: you already own the maximum number of Dead Man's Switches", {}, {});
        event.TerritoryAnnotationsOpt = { [build.TerritoryID] = WL.TerritoryAnnotation.Create("Unable to build DMS", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Red)) };
        event.Icon = "BuildFailed";
        addNewOrder(event);
    end

    -- ownership lost logic
    for territoryID, buildGroup in pairs(groupBy(removedPending, function(b) return b.TerritoryID; end)) do
        local build = first(buildGroup);
        if (build ~= nil) then
            local td = game.Map.Territories[territoryID];
            local event = WL.GameOrderEvent.Create(build.PlayerID, "Unable to build Dead Man's Switch on " .. td.Name, {}, {});
            event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
            event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Unable to build DMS", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Red)) };
            event.Icon = "BuildFailed";
            addNewOrder(event);
        end
    end

    priv.PendingDMS = nil;
    Mod.PrivateGameData = priv;
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
---@param playerID PlayerID
---@param territoryID TerritoryID
function DeadManSwitchApplication.AddDeadManSwitchImmediately(game, addNewOrder, playerID, territoryID)
    local territory = game.ServerGame.LatestTurnStanding.Territories[territoryID];
    if (territory == nil or territory.OwnerPlayerID ~= playerID) then
        local event = WL.GameOrderEvent.Create(playerID, "Unable to build Dead Man's Switch: you don't control that territory", {}, {});
        event.Icon = "BuildFailed";
        addNewOrder(event);
        return;
    end

    local structureID = WL.StructureType.Custom("Dead Man's Switch");
    if (IsOverCommerceCap(game.ServerGame.LatestTurnStanding, playerID, structureID)) then
        local event = WL.GameOrderEvent.Create(playerID, "Unable to build Dead Man's Switch: you already own the maximum number of Dead Man's Switches", {}, {});
        event.Icon = "BuildFailed";
        addNewOrder(event);
        return;
    end

    BuildDeadManSwitchNow(game, addNewOrder, territoryID, playerID, "Built a Dead Man's Switch via another mod", 1);
end

---Triggers the single primary action selected in the mod settings
---@param territoryModification TerritoryModification # The DMS territory modification (destroying the DMS)
---@param game GameServerHook
---@param context DeadManSwitchTriggerContext
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param numberOfDMS integer # How many DMS were on the captured territory
local function TriggerPrimaryAction(territoryModification, game, context, addNewOrder, numberOfDMS)
    if (Mod.Settings.isDamageTypeBomb) then Actions.VanillaCards.Bomb.Trigger(territoryModification, game, context, addNewOrder, numberOfDMS);
    elseif (Mod.Settings.isDamageTypeFlat) then Actions.ManualDamage.Flat.Trigger(territoryModification, game, context, addNewOrder, numberOfDMS);
    elseif (Mod.Settings.isDamageTypeBlockade) then Actions.VanillaCards.Blockade.Trigger(territoryModification, game, context, addNewOrder, numberOfDMS);
    elseif (Mod.Settings.isDamageTypeEmergencyBlockade) then Actions.VanillaCards.EmergencyBlockade.Trigger(territoryModification, game, context, addNewOrder, numberOfDMS);
    elseif (Mod.Settings.isDamageTypePercent) then Actions.ManualDamage.Percent.Trigger(territoryModification, game, context, addNewOrder, numberOfDMS);
    elseif (Mod.Settings.isDamageTypeGift) then Actions.VanillaCards.Gift.Trigger(territoryModification, game, context, addNewOrder, numberOfDMS);
    else
        -- no primary damage type configured somehow - still have to apply territoryModification, or the DMS never gets removed
        AddTriggeredEvent(context, territoryModification, addNewOrder);
    end
end

---Triggers every secondary action enabled in the mod settings, these do not conflict with each other so can each be triggered.
---@param territoryModification TerritoryModification # The DMS territory modification (destroying the DMS)
---@param game GameServerHook
---@param context DeadManSwitchTriggerContext
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param numberOfDMS integer # How many DMS were on the captured territory
local function TriggerSecondaryActions(territoryModification, game, context, addNewOrder, numberOfDMS)
    if (Mod.Settings.isDamageTypeSanction) then Actions.VanillaCards.Sanction.Trigger(territoryModification, game, context, addNewOrder, numberOfDMS); end
    if (Mod.Settings.isDamageTypeDiplomacy) then Actions.VanillaCards.Diplomacy.Trigger(territoryModification, game, context, addNewOrder, numberOfDMS); end
    if (Mod.Settings.isDamageTypeSpy) then Actions.VanillaCards.Spy.Trigger(territoryModification, game, context, addNewOrder, numberOfDMS); end
end

---Triggers the Dead Man's Switch(es) on a territory if a successful attack captured one that has them.
---@param game GameServerHook
---@param order GameOrderAttackTransfer
---@param result GameOrderAttackTransferResult
---@param addNewOrder fun(order: GameOrder)
function DeadManSwitchApplication.HandleSuccessfulAttack(game, order, result, addNewOrder)
    local structureID = WL.StructureType.Custom("Dead Man's Switch");
    local existingStructures = game.ServerGame.LatestTurnStanding.Territories[order.To].Structures;
    if (existingStructures == nil) then return; end;

    local numberOfDMS = existingStructures[structureID] or 0;
    if (numberOfDMS == 0) then return; end; --no DMS here, abort

    if (result.ActualArmies.IsEmpty) then return; end; --an attack of 0, abort, so skipped orders don't destroy the DMS

    -- abort if on same team and ally triggers is disabled
    local territoryOwnerPlayerID = game.ServerGame.LatestTurnStanding.Territories[order.To].OwnerPlayerID;
    local attackerTeam = game.ServerGame.Game.Players[order.PlayerID].Team;
    local ownerTeam = WL.PlayerID.Neutral;
    if (game.ServerGame.Game.Players[territoryOwnerPlayerID] ~= nil) then
        ownerTeam = game.ServerGame.Game.Players[territoryOwnerPlayerID].Team;
    end

    if (attackerTeam ~= nil and ownerTeam ~= nil and attackerTeam ~= -1 and ownerTeam ~= -1 and attackerTeam == ownerTeam and Mod.Settings.AllyTriggers == false) then
        return;
    end;

    ---@type DeadManSwitchTriggerDeadManSwitchDto
    local data = {
        Action = DeadManSwitchActions.TriggerDeadManSwitch,
        TerritoryID = order.To,
        AttackerPlayerID = order.PlayerID,
        ArmiesOnArrival = result.ActualArmies.NumArmies - result.AttackingArmiesKilled.NumArmies,
        NumSwitches = numberOfDMS,
    };
    DeadManSwitchApplication.TriggerDeadManSwitch(game, addNewOrder, data);
end

---Triggers the Dead Man's Switch(es) on a territory: clears them and applies whatever retaliation effect(s) are configured.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param data DeadManSwitchTriggerDeadManSwitchDto
function DeadManSwitchApplication.TriggerDeadManSwitch(game, addNewOrder, data)
    local territoryID = data.TerritoryID;
    local attackerPlayerID = data.AttackerPlayerID;
    if (territoryID == nil or attackerPlayerID == nil) then return; end;

    local standing = game.ServerGame.LatestTurnStanding;
    local territory = standing.Territories[territoryID];
    if (territory == nil or territory.Structures == nil) then return; end;

    -- this is reachable from other mods, so re-check here
    local structureID = WL.StructureType.Custom("Dead Man's Switch");
    local existingCount = territory.Structures[structureID] or 0;
    if (existingCount <= 0) then return; end;

    local numberOfDMS = data.NumSwitches or existingCount;

    local structures = {};
    for key, value in pairs(territory.Structures) do
        structures[key] = value;
    end
    structures[structureID] = 0;

    local territoryModification = WL.TerritoryModification.Create(territoryID);
    territoryModification.SetStructuresOpt = structures;

    ---@type DeadManSwitchTriggerContext
    local context = {
        TerritoryID = territoryID,
        AttackerPlayerID = attackerPlayerID,
        DefendingPlayerID = territory.OwnerPlayerID,
        ArmiesOnArrival = data.ArmiesOnArrival,
    };

    TriggerPrimaryAction(territoryModification, game, context, addNewOrder, numberOfDMS);
    TriggerSecondaryActions(territoryModification, game, context, addNewOrder, numberOfDMS);
end

---Destroys one Dead Man's Switch on a territory, independent of any capture.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
---@param data DeadManSwitchDestroyDeadManSwitchDto
function DeadManSwitchApplication.DestroyDeadManSwitch(game, addNewOrder, data)
    local territoryID = data.TerritoryID;
    if (territoryID == nil) then return; end;

    local territory = game.ServerGame.LatestTurnStanding.Territories[territoryID];
    if (territory == nil or territory.Structures == nil) then return; end;

    local structureID = WL.StructureType.Custom("Dead Man's Switch");
    if ((territory.Structures[structureID] or 0) <= 0) then return; end;

    local structures = {};
    for key, value in pairs(territory.Structures) do
        structures[key] = value;
    end
    structures[structureID] = structures[structureID] - 1;

    local territoryModification = WL.TerritoryModification.Create(territoryID);
    territoryModification.SetStructuresOpt = structures;

    local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, "The Dead Man's Switch was destroyed.", {}, { territoryModification });
    event.Icon = "Destroyed";
    addNewOrder(event);
end

---@param addNewOrder fun(order: GameOrder)
function DeadManSwitchApplication.PlayPendingBlockades(addNewOrder)
    Actions.VanillaCards.Blockade.PlayPending(addNewOrder);
end

---@param addNewOrder fun(order: GameOrder)
function DeadManSwitchApplication.PlayPendingDiplomacy(addNewOrder)
    Actions.VanillaCards.Diplomacy.PlayPending(addNewOrder);
end
