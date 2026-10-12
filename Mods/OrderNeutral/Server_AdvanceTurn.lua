--todo: investigate "Cannot add more than 4 special units" error message

require("Utilities");

---Server_AdvanceTurn_Start hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Start(game, addNewOrder)
    RemoveExpiredVisionFogMods(addNewOrder);
end

---Server_AdvanceTurn_Order
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl)
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)

    if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, "CreateNeutralAttackTransferOrder_")) then

        if (order.CustomCardID == Mod.Settings.CardID and Mod.Settings.CardDuration > 1) then
            local privateGameData = Mod.PrivateGameData;
            if (privateGameData.PendingTemporaryCardStreaks == nil) then privateGameData.PendingTemporaryCardStreaks = {}; end;
            table.insert(privateGameData.PendingTemporaryCardStreaks, { PlayerID = order.PlayerID, RemainingTurns = Mod.Settings.CardDuration - 1 });
            Mod.PrivateGameData = privateGameData;
        end

        local ids = split(string.sub(order.ModData, string.len("CreateNeutralAttackTransferOrder_") + 1), "_");
        local fromTerritoryID = tonumber(ids[1]);
        local toTerritoryID = tonumber(ids[2]);
        local armyCountStr = ids[3];
        local specialUnitsStr = ids[4];

        local fromTerritory = game.ServerGame.LatestTurnStanding.Territories[fromTerritoryID];

        if (fromTerritory.OwnerPlayerID ~= WL.PlayerID.Neutral) then
            -- The territory is no longer neutral (eg. captured earlier this turn), so the order is no longer valid
            return;
        end

        if (game.Map.Territories[fromTerritoryID].ConnectedTo[toTerritoryID] == nil) then
            -- The client can't be trusted
            return;
        end

        --the client can't be trusted
        local availableArmies = fromTerritory.NumArmies.NumArmies;
        local maxSendableArmies = game.Settings.OneArmyStandsGuard and math.max(0, availableArmies - 1) or availableArmies;
        local armiesToSend = (armyCountStr == nil or armyCountStr == "ALL") and maxSendableArmies or math.max(0, math.min(maxSendableArmies, tonumber(armyCountStr) or 0));

        local specialUnitsToSend;
        if (specialUnitsStr == nil or specialUnitsStr == "ALL") then
            specialUnitsToSend = fromTerritory.NumArmies.SpecialUnits;
        elseif (specialUnitsStr == "NONE") then
            specialUnitsToSend = {};
        else
            local chosenSpecialUnitIDs = {};
            for _, unitID in ipairs(split(specialUnitsStr, ",")) do chosenSpecialUnitIDs[unitID] = true; end
            specialUnitsToSend = filter(fromTerritory.NumArmies.SpecialUnits, function(unit) return chosenSpecialUnitIDs[unit.ID] == true; end);
        end

        if (armiesToSend <= 0 and #specialUnitsToSend == 0) then
            local event = WL.GameOrderEvent.Create(order.PlayerID, order.Description .. " - failed, no armies were left to send", { order.PlayerID }, {});
            event.Icon = "Blocked";
            addNewOrder(event);
            return;
        end

        local toTerritory = game.ServerGame.LatestTurnStanding.Territories[toTerritoryID];
        local fromTerritoryName = game.Map.Territories[fromTerritoryID].Name;
        local toTerritoryName = game.Map.Territories[toTerritoryID].Name;

        if (toTerritory.OwnerPlayerID == WL.PlayerID.Neutral) then
            -- Transfer into the other neutral territory, no combat involved
            local armiesMoved = armiesToSend;
            local specialUnitsMoved = specialUnitsToSend;

            local fromMod = WL.TerritoryModification.Create(fromTerritoryID);
            fromMod.SetArmiesTo = availableArmies - armiesToSend;
            fromMod.RemoveSpecialUnitsOpt = map(specialUnitsMoved, function(unit) return unit.ID end);

            local toMod = WL.TerritoryModification.Create(toTerritoryID);
            toMod.AddArmies = armiesMoved;
            local extraSpecialUnitChunks = AssignAddSpecialUnits(toMod, specialUnitsMoved);

            local message = DescribeArmyMovement(armiesMoved, specialUnitsMoved) .. " transferred to " .. toTerritoryName .. " from " .. fromTerritoryName;
            local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, message, { order.PlayerID }, { fromMod, toMod });
            event.TerritoryAnnotationsOpt = {
                [fromTerritoryID] = WL.TerritoryAnnotation.Create("Ordered", 8, GetColourIntegerFromHex(BUTTON_COLOURS.DarkGray)),
                [toTerritoryID] = WL.TerritoryAnnotation.Create("Target", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Cordovan)),
            };
            event.Icon = "NeutralAttackTransfer";

            if (Mod.Settings.NeutralArmyGivesVision and Mod.Settings.VisionMethodManual) then
                GrantManualVisionOfTerritory(game, event, order.PlayerID, toTerritoryID);
            end

            addNewOrder(event);
            QueueExtraSpecialUnitEvents(toTerritoryID, extraSpecialUnitChunks, order.PlayerID, addNewOrder);

            if (Mod.Settings.NeutralArmyGivesVision and Mod.Settings.VisionMethodFreeReconCard) then
                GiveFreeReconOfTerritory(order.PlayerID, toTerritoryID, addNewOrder);
            end
        else
            -- not a neutral territory, ATTACK!
            local attackingArmies = armiesToSend;
            local attackingSpecialUnits = specialUnitsToSend;
            local attackingArmiesObj = WL.Armies.Create(attackingArmies, attackingSpecialUnits);
            local attackResult = process_manual_attack(game, attackingArmiesObj, toTerritory, nil, addNewOrder, false);

            local fromMod = WL.TerritoryModification.Create(fromTerritoryID);
            local toMod = WL.TerritoryModification.Create(toTerritoryID);

            local message;
            local extraFromChunks = {};
            local extraToChunks = {};
            if (attackResult.IsSuccessful) then
                fromMod.SetArmiesTo = availableArmies - armiesToSend;
                fromMod.RemoveSpecialUnitsOpt = map(attackingSpecialUnits, function(unit) return unit.ID end);

                toMod.SetOwnerOpt = WL.PlayerID.Neutral;
                toMod.SetArmiesTo = attackResult.AttackerResult.RemainingArmies;
                toMod.RemoveSpecialUnitsOpt = attackResult.DefenderResult.KilledSpecials;
                extraToChunks = AssignAddSpecialUnits(toMod, attackResult.AttackerResult.SurvivingSpecials);
                message = DescribeArmyMovement(attackingArmies, attackingSpecialUnits) .. " captured " .. toTerritoryName .. " from " .. fromTerritoryName;
            else
                fromMod.SetArmiesTo = (availableArmies - armiesToSend) + attackResult.AttackerResult.RemainingArmies;
                fromMod.RemoveSpecialUnitsOpt = attackResult.AttackerResult.KilledSpecials;
                extraFromChunks = AssignAddSpecialUnits(fromMod, attackResult.AttackerResult.ClonedSpecials);

                toMod.SetArmiesTo = attackResult.DefenderResult.RemainingArmies;
                toMod.RemoveSpecialUnitsOpt = attackResult.DefenderResult.KilledSpecials;
                extraToChunks = AssignAddSpecialUnits(toMod, attackResult.DefenderResult.ClonedSpecials);
                message = DescribeArmyMovement(attackingArmies, attackingSpecialUnits) .. " failed to capture " .. toTerritoryName .. " from " .. fromTerritoryName;
            end

            local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, message, { order.PlayerID }, { fromMod, toMod });
            event.TerritoryAnnotationsOpt = {
                [fromTerritoryID] = WL.TerritoryAnnotation.Create("Ordered", 8, GetColourIntegerFromHex(BUTTON_COLOURS.DarkGray)),
                [toTerritoryID] = WL.TerritoryAnnotation.Create("Target", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Cordovan)),
            };
            event.Icon = "NeutralAttackTransfer";
            local visionTargetTerritoryID = attackResult.IsSuccessful and toTerritoryID or fromTerritoryID;

            if (Mod.Settings.NeutralArmyGivesVision and Mod.Settings.VisionMethodManual) then
                GrantManualVisionOfTerritory(game, event, order.PlayerID, visionTargetTerritoryID);
            end

            addNewOrder(event);
            QueueExtraSpecialUnitEvents(fromTerritoryID, extraFromChunks, order.PlayerID, addNewOrder);
            QueueExtraSpecialUnitEvents(toTerritoryID, extraToChunks, order.PlayerID, addNewOrder);

            if (Mod.Settings.NeutralArmyGivesVision and Mod.Settings.VisionMethodFreeReconCard) then
                GiveFreeReconOfTerritory(order.PlayerID, visionTargetTerritoryID, addNewOrder);
            end
        end
    end

end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_End(game, addNewOrder)
    DiscardUnusedTemporaryCommandNeutralCards(game, addNewOrder);
    GiveTemporaryCommandNeutralCards(game, addNewOrder);
end

-- todo: we should see if we can put this into a commit hook
function DiscardUnusedTemporaryCommandNeutralCards(game, addNewOrder)
    for playerID, playerCards in pairs(game.ServerGame.LatestTurnStanding.Cards) do
        for cardInstanceID, cardInstance in pairs(playerCards.WholeCards) do
            if (cardInstance.CardID == Mod.Settings.TemporaryCardID) then
                addNewOrder(WL.GameOrderDiscard.Create(playerID, cardInstanceID));
            end
        end
    end
end

function GiveTemporaryCommandNeutralCards(game, addNewOrder)
    local privateGameData = Mod.PrivateGameData;
    local streaks = privateGameData.PendingTemporaryCardStreaks;
    if (streaks == nil) then return; end;

    local remainingStreaks = {};
    for _, streak in pairs(streaks) do
        local instance = WL.NoParameterCardInstance.Create(Mod.Settings.TemporaryCardID);
        addNewOrder(WL.GameOrderReceiveCard.Create(streak.PlayerID, { instance }));

        if (streak.RemainingTurns > 1) then
            table.insert(remainingStreaks, { PlayerID = streak.PlayerID, RemainingTurns = streak.RemainingTurns - 1 });
        end
    end

    privateGameData.PendingTemporaryCardStreaks = (#remainingStreaks > 0) and remainingStreaks or nil;
    Mod.PrivateGameData = privateGameData;
end
