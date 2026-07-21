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
            -- playing the original card starts its own independent countdown; if the player has other active
            -- CommandNeutral streaks running, this is in addition to those, not a replacement for them
            local privateGameData = Mod.PrivateGameData;
            if (privateGameData.PendingTemporaryCardStreaks == nil) then privateGameData.PendingTemporaryCardStreaks = {}; end;
            table.insert(privateGameData.PendingTemporaryCardStreaks, { PlayerID = order.PlayerID, RemainingTurns = Mod.Settings.CardDuration - 1 });
            Mod.PrivateGameData = privateGameData;
        end

        local ids = split(string.sub(order.ModData, string.len("CreateNeutralAttackTransferOrder_") + 1), "_");
        local fromTerritoryID = tonumber(ids[1]);
        local toTerritoryID = tonumber(ids[2]);

        local fromTerritory = game.ServerGame.LatestTurnStanding.Territories[fromTerritoryID];

        if (fromTerritory.OwnerPlayerID ~= WL.PlayerID.Neutral) then
            -- The territory is no longer neutral (eg. captured earlier this turn), so the order is no longer valid
            return;
        end

        if (fromTerritory.NumArmies.NumArmies <= 0) then
            -- No armies left on the neutral territory to issue the order with
            return;
        end

        if (game.Map.Territories[fromTerritoryID].ConnectedTo[toTerritoryID] == nil) then
            -- The client can't be trusted to only send legal orders, so verify adjacency ourselves
            return;
        end

        local toTerritory = game.ServerGame.LatestTurnStanding.Territories[toTerritoryID];
        local fromTerritoryName = game.Map.Territories[fromTerritoryID].Name;
        local toTerritoryName = game.Map.Territories[toTerritoryID].Name;

        if (toTerritory.OwnerPlayerID == WL.PlayerID.Neutral) then
            -- Transfer into the other neutral territory, no combat involved
            local armiesMoved = fromTerritory.NumArmies.NumArmies;
            local specialUnitsMoved = fromTerritory.NumArmies.SpecialUnits;

            local fromMod = WL.TerritoryModification.Create(fromTerritoryID);
            fromMod.SetArmiesTo = 0;
            fromMod.RemoveSpecialUnitsOpt = map(specialUnitsMoved, function(unit) return unit.ID end);

            local toMod = WL.TerritoryModification.Create(toTerritoryID);
            toMod.AddArmies = armiesMoved;
            toMod.AddSpecialUnits = specialUnitsMoved;

            local message = DescribeArmyMovement(armiesMoved, specialUnitsMoved) .. " transferred to " .. toTerritoryName .. " from " .. fromTerritoryName;
            local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, message, { order.PlayerID }, { fromMod, toMod });
            event.TerritoryAnnotationsOpt = {
                [fromTerritoryID] = WL.TerritoryAnnotation.Create("Ordered", 8, GetColourIntegerFromHex(BUTTON_COLOURS.DarkGray)),
                [toTerritoryID] = WL.TerritoryAnnotation.Create("Target", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Red)),
            };

            if (Mod.Settings.NeutralArmyGivesVision and Mod.Settings.VisionMethodManual) then
                GrantManualVisionOfTerritory(game, event, order.PlayerID, toTerritoryID);
            end

            addNewOrder(event);

            if (Mod.Settings.NeutralArmyGivesVision and Mod.Settings.VisionMethodFreeReconCard) then
                GiveFreeReconOfTerritory(order.PlayerID, toTerritoryID, addNewOrder);
            end
        else
            -- GameOrderAttackTransfer requires a real (non-neutral) PlayerID, so we can't use it for a neutral-owned
            -- source territory. Instead, manually resolve combat using the same damage calculation the engine uses.
            local attackingArmies = fromTerritory.NumArmies.NumArmies;
            local attackingSpecialUnits = fromTerritory.NumArmies.SpecialUnits;
            local attackResult = process_manual_attack(game, fromTerritory.NumArmies, toTerritory, nil, addNewOrder, false);

            local fromMod = WL.TerritoryModification.Create(fromTerritoryID);
            local toMod = WL.TerritoryModification.Create(toTerritoryID);

            local message;
            if (attackResult.IsSuccessful) then
                -- attack succeeds, neutral captures the territory. The entire attacking force (whether it died,
                -- survived undamaged, or survived damaged) leaves the source territory and arrives fresh at the
                -- destination, so remove all of it from the source rather than just the units that died/were hurt
                fromMod.SetArmiesTo = 0;
                fromMod.RemoveSpecialUnitsOpt = map(attackingSpecialUnits, function(unit) return unit.ID end);

                toMod.SetOwnerOpt = WL.PlayerID.Neutral;
                toMod.SetArmiesTo = attackResult.AttackerResult.RemainingArmies;
                toMod.RemoveSpecialUnitsOpt = attackResult.DefenderResult.KilledSpecials;
                toMod.AddSpecialUnits = attackResult.AttackerResult.SurvivingSpecials;
                message = DescribeArmyMovement(attackingArmies, attackingSpecialUnits) .. " captured " .. toTerritoryName .. " from " .. fromTerritoryName;
            else
                -- attack fails, surviving attackers return home and the defender holds the territory with whatever
                -- survived. Units that took no damage never left their territory, so only the ones that died or were
                -- damaged (and were cloned with their new health) need to be removed/re-added
                fromMod.SetArmiesTo = attackResult.AttackerResult.RemainingArmies;
                fromMod.RemoveSpecialUnitsOpt = attackResult.AttackerResult.KilledSpecials;
                fromMod.AddSpecialUnits = attackResult.AttackerResult.ClonedSpecials;

                toMod.SetArmiesTo = attackResult.DefenderResult.RemainingArmies;
                toMod.RemoveSpecialUnitsOpt = attackResult.DefenderResult.KilledSpecials;
                toMod.AddSpecialUnits = attackResult.DefenderResult.ClonedSpecials;
                message = DescribeArmyMovement(attackingArmies, attackingSpecialUnits) .. " failed to capture " .. toTerritoryName .. " from " .. fromTerritoryName;
            end

            local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, message, { order.PlayerID }, { fromMod, toMod });
            event.TerritoryAnnotationsOpt = {
                [fromTerritoryID] = WL.TerritoryAnnotation.Create("Ordered", 8, GetColourIntegerFromHex(BUTTON_COLOURS.DarkGray)),
                [toTerritoryID] = WL.TerritoryAnnotation.Create("Target", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Cordovan)),
            };

            local visionTargetTerritoryID = attackResult.IsSuccessful and toTerritoryID or fromTerritoryID;

            if (Mod.Settings.NeutralArmyGivesVision and Mod.Settings.VisionMethodManual) then
                GrantManualVisionOfTerritory(game, event, order.PlayerID, visionTargetTerritoryID);
            end

            addNewOrder(event);

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

--discards any Temporary Command Neutral cards still sitting unused in a player's hand, so they don't carry over
--into the next turn before this turn's active streaks hand out fresh ones
function DiscardUnusedTemporaryCommandNeutralCards(game, addNewOrder)
    for playerID, playerCards in pairs(game.ServerGame.LatestTurnStanding.Cards) do
        for cardInstanceID, cardInstance in pairs(playerCards.WholeCards) do
            if (cardInstance.CardID == Mod.Settings.TemporaryCardID) then
                addNewOrder(WL.GameOrderDiscard.Create(playerID, cardInstanceID));
            end
        end
    end
end

--gives out a Temporary Command Neutral card for each still-active CommandNeutral streak, one card per streak (a player
--with multiple active streaks receives multiple temporary cards), then ticks each streak's remaining turns down
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
