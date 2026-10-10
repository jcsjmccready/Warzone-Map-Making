require("Utilities");

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

---@param playerID PlayerID
---@param territoryID TerritoryID
---@param territoryModification TerritoryModification
local function AddDmsTriggeredEvent(playerID, territoryID, territoryModification, addNewOrder)
    local event = WL.GameOrderEvent.Create(playerID, "Triggered a Dead Man's Switch", {}, { territoryModification });
    event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Triggered DMS", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
    event.Icon = "Triggered";
    addNewOrder(event, true);
end

---@param playerID PlayerID
---@param territoryModification TerritoryModification
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param cardName string
local function AddDmsCancelledCardActionEvent(playerID, territoryModification, addNewOrder, cardName)
    -- this should be impossible to reach but safety net, in case the required card isn't enabled in the game settings
    addNewOrder(WL.GameOrderEvent.Create(playerID, cardName .. " card not available - DMS action cancelled", {}, { territoryModification }), true);
end

---Applies whichever single damage-type effect is configured. attackerPlayerID receives/plays every card this triggers.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param territoryID TerritoryID
---@param attackerPlayerID PlayerID
---@param territoryModification TerritoryModification
---@param armiesOnArrival integer # Armies left on the territory immediately after the capture, before any Dead Man's Switch damage
---@param numberOfDMS integer
local function TriggerPrimaryAction(game, addNewOrder, territoryID, attackerPlayerID, territoryModification, armiesOnArrival, numberOfDMS)
    if (Mod.Settings.isDamageTypeBomb) then
        -- unable to programatically play cards without them being enabled
        if game.Settings.Cards ~= nil and game.Settings.Cards[WL.CardID.Bomb] ~= nil then
            AddDmsTriggeredEvent(attackerPlayerID, territoryID, territoryModification, addNewOrder);

            for _ = 1, numberOfDMS do
                local instance = WL.NoParameterCardInstance.Create(WL.CardID.Bomb);
                addNewOrder(WL.GameOrderReceiveCard.Create(attackerPlayerID, { instance }));
                addNewOrder(WL.GameOrderPlayCardBomb.Create(instance.ID, attackerPlayerID, territoryID));
            end
        else
            AddDmsCancelledCardActionEvent(attackerPlayerID, territoryModification, addNewOrder, "Bomb");
        end
    elseif (Mod.Settings.isDamageTypeFlat) then
        local damageAmount = Mod.Settings.FlatDamage * numberOfDMS;
        territoryModification.SetArmiesTo = math.max(0, armiesOnArrival - damageAmount);

        AddDmsTriggeredEvent(attackerPlayerID, territoryID, territoryModification, addNewOrder);

    elseif (Mod.Settings.isDamageTypeBlockade) then
        -- unable to programatically play cards without them being enabled
        if game.Settings.Cards ~= nil and game.Settings.Cards[WL.CardID.Blockade] ~= nil then
            AddDmsTriggeredEvent(attackerPlayerID, territoryID, territoryModification, addNewOrder);

            -- blockade cards are normally played at the end of the turn, so store them for end of turn instead of playing them immediately
            local priv = Mod.PrivateGameData --[[@as DeadManSwitchPrivateGameData]];
            local pendingBlockade = priv.PendingBlockade or {};

            for _ = 1, numberOfDMS do
                table.insert(pendingBlockade, { PlayerID = attackerPlayerID, TerritoryID = territoryID });
            end

            priv.PendingBlockade = pendingBlockade;
            Mod.PrivateGameData = priv;
        else
            AddDmsCancelledCardActionEvent(attackerPlayerID, territoryModification, addNewOrder, "Blockade");
        end
    elseif (Mod.Settings.isDamageTypeEmergencyBlockade) then
        -- unable to programatically play cards without them being enabled
        if game.Settings.Cards ~= nil and game.Settings.Cards[WL.CardID.EmergencyBlockade] ~= nil then
            AddDmsTriggeredEvent(attackerPlayerID, territoryID, territoryModification, addNewOrder);

            for _ = 1, numberOfDMS do
                local instance = WL.NoParameterCardInstance.Create(WL.CardID.EmergencyBlockade);
                addNewOrder(WL.GameOrderReceiveCard.Create(attackerPlayerID, { instance }));
                addNewOrder(WL.GameOrderPlayCardAbandon.Create(instance.ID, attackerPlayerID, territoryID));
            end
        else
            AddDmsCancelledCardActionEvent(attackerPlayerID, territoryModification, addNewOrder, "Emergency Blockade");
        end
    elseif (Mod.Settings.isDamageTypePercent) then
        local remainingArmies = armiesOnArrival;

        for _ = 1, numberOfDMS do
            remainingArmies = math.max(0, math.floor(remainingArmies * (1 - Mod.Settings.PercentageDamage) + 0.5));
        end

        local minimumRemainingArmies = math.max(0, armiesOnArrival - (Mod.Settings.PercentageMinDamage * numberOfDMS));
        territoryModification.SetArmiesTo = math.max(0, math.min(remainingArmies, minimumRemainingArmies));

        AddDmsTriggeredEvent(attackerPlayerID, territoryID, territoryModification, addNewOrder);
    else
        -- no primary damage type configured - still have to apply territoryModification, or the switch itself never gets removed
        AddDmsTriggeredEvent(attackerPlayerID, territoryID, territoryModification, addNewOrder);
    end
end

---Applies every independent toggle effect, which can stack with each other and with the primary damage type above.
---attackerPlayerID is both the sender and target of these cards (they're played against themselves, mirroring the
---original Dead Man's Switch behaviour where the attacking and newly-defending player are the same person).
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param territoryID TerritoryID
---@param attackerPlayerID PlayerID
---@param territoryModification TerritoryModification
---@param numberOfDMS integer
local function TriggerSecondaryActions(game, addNewOrder, territoryID, attackerPlayerID, territoryModification, numberOfDMS)
    if (Mod.Settings.isDamageTypeSanction) then
        -- unable to programatically play cards without them being enabled
        if game.Settings.Cards ~= nil and game.Settings.Cards[WL.CardID.Sanctions] ~= nil then
            for _ = 1, numberOfDMS do
                local instance = WL.NoParameterCardInstance.Create(WL.CardID.Sanctions);
                addNewOrder(WL.GameOrderReceiveCard.Create(attackerPlayerID, { instance }));
                addNewOrder(WL.GameOrderPlayCardSanctions.Create(instance.ID, attackerPlayerID, attackerPlayerID));
            end
        else
            AddDmsCancelledCardActionEvent(attackerPlayerID, territoryModification, addNewOrder, "Sanction");
        end
    end

    if (Mod.Settings.isDamageTypeDiplomacy) then
        -- unable to programatically play cards without them being enabled
        if game.Settings.Cards ~= nil and game.Settings.Cards[WL.CardID.Diplomacy] ~= nil then
            -- diplomacy cards are normally played at the end of the turn, so store them for end of turn instead of playing them immediately
            local priv = Mod.PrivateGameData --[[@as DeadManSwitchPrivateGameData]];
            local pendingDiplomacy = priv.PendingDiplomacy or {};

            for _ = 1, numberOfDMS do
                table.insert(pendingDiplomacy, { PlayerID = attackerPlayerID, PlayerOne = attackerPlayerID, PlayerTwo = attackerPlayerID });
            end

            priv.PendingDiplomacy = pendingDiplomacy;
            Mod.PrivateGameData = priv;
        else
            AddDmsCancelledCardActionEvent(attackerPlayerID, territoryModification, addNewOrder, "Diplomacy");
        end
    end

    if (Mod.Settings.isDamageTypeSpy) then
        -- unable to programatically play cards without them being enabled
        if game.Settings.Cards ~= nil and game.Settings.Cards[WL.CardID.Spy] ~= nil then
            for _ = 1, numberOfDMS do
                local instance = WL.NoParameterCardInstance.Create(WL.CardID.Spy);
                addNewOrder(WL.GameOrderReceiveCard.Create(attackerPlayerID, { instance }));
                addNewOrder(WL.GameOrderPlayCardSpy.Create(instance.ID, attackerPlayerID, attackerPlayerID));
            end
        else
            AddDmsCancelledCardActionEvent(attackerPlayerID, territoryModification, addNewOrder, "Spy");
        end
    end
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

    TriggerPrimaryAction(game, addNewOrder, territoryID, attackerPlayerID, territoryModification, data.ArmiesOnArrival, numberOfDMS);
    TriggerSecondaryActions(game, addNewOrder, territoryID, attackerPlayerID, territoryModification, numberOfDMS);
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
    local priv = Mod.PrivateGameData --[[@as DeadManSwitchPrivateGameData]];
    local pending = priv.PendingBlockade;
    if (pending == nil) then return; end;

    for _, pendingBlockade in pairs(pending) do
        local instance = WL.NoParameterCardInstance.Create(WL.CardID.Blockade);
        addNewOrder(WL.GameOrderReceiveCard.Create(pendingBlockade.PlayerID, { instance }));
        addNewOrder(WL.GameOrderPlayCardBlockade.Create(instance.ID, pendingBlockade.PlayerID, pendingBlockade.TerritoryID));
    end

    priv.PendingBlockade = nil;
    Mod.PrivateGameData = priv;
end

---@param addNewOrder fun(order: GameOrder)
function DeadManSwitchApplication.PlayPendingDiplomacy(addNewOrder)
    local priv = Mod.PrivateGameData --[[@as DeadManSwitchPrivateGameData]];
    local pending = priv.PendingDiplomacy;
    if (pending == nil) then return; end;

    for _, pendingDiplomacy in pairs(pending) do
        local instance = WL.NoParameterCardInstance.Create(WL.CardID.Diplomacy);
        addNewOrder(WL.GameOrderReceiveCard.Create(pendingDiplomacy.PlayerID, { instance }));
        addNewOrder(WL.GameOrderPlayCardDiplomacy.Create(instance.ID, pendingDiplomacy.PlayerID, pendingDiplomacy.PlayerOne, pendingDiplomacy.PlayerTwo));
    end

    priv.PendingDiplomacy = nil;
    Mod.PrivateGameData = priv;
end
