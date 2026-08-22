require("Utilities");

--- todo: Improve struct art to be more noticiable.
--- Check events, might not want them all

---Server_AdvanceTurn_Order hook. Records a pending Conscription (does not resolve it yet - the actual effect is
---only applied at Server_AdvanceTurn_End, once the whole turn including attacks has resolved, so that we validate
---the player still fully owns the bonus at that point rather than only at the moment they played the card.
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
    if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, "Conscript_")) then
        local bonusID = tonumber(string.sub(order.ModData, 11));
        local bonus = game.Map.Bonuses[bonusID];

        if (bonus ~= nil and bonus.Amount < 0) then
            local event = WL.GameOrderEvent.Create(order.PlayerID, "Conscription failed: " .. bonus.Name .. " has a negative value and cannot be conscripted", {}, {});
            event.Icon = "Blocked";
            addNewOrder(event);
            return;
        end

        if (not PlayerFullyOwnsBonus(game.ServerGame.LatestTurnStanding, game.Map, bonusID, order.PlayerID)) then
            local event = WL.GameOrderEvent.Create(order.PlayerID, "Conscription failed: you no longer fully control that bonus", {}, {});
            event.Icon = "Blocked";
            addNewOrder(event);
            return;
        end

        local pending = {};
        pending.PlayerID = order.PlayerID;
        pending.BonusID = bonusID;

        local priv = Mod.PrivateGameData;
        if (priv.PendingConscriptions == nil) then priv.PendingConscriptions = {}; end;
        table.insert(priv.PendingConscriptions, pending);
        Mod.PrivateGameData = priv;
    end
end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_End(game, addNewOrder)
    ResolvePendingConscriptions(game, addNewOrder);
    ApplyPermanentBonusReductions(game, addNewOrder);

    if (Mod.Settings.NeutraliseFullyConscripted) then
        NeutraliseFullyConscriptedBonuses(game, addNewOrder);
    end
end

---Resolves every Conscription played this turn: re-validates the player still fully owns the bonus now that the
---whole turn (including attacks) has played out, then permanently reduces the bonus's value and grants the
---player a one-turn income boost.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function ResolvePendingConscriptions(game, addNewOrder)
    local priv = Mod.PrivateGameData;
    local pending = priv.PendingConscriptions;
    if (pending == nil or #pending == 0) then return; end;

    local standing = game.ServerGame.LatestTurnStanding;
    local pub = Mod.PublicGameData;
    local reductions = pub.BonusReductions or {};

    -- shared across every item resolved this call, so bonuses that overlap on a territory see each other's
    -- structure edits instead of each re-reading the stale standing and clobbering one another
    local structuresByTerritory = {};
    local allTerritoryModifications = {};

    for _, item in ipairs(pending) do
        local bonus = game.Map.Bonuses[item.BonusID];

        if (bonus ~= nil) then
            if (not PlayerFullyOwnsBonus(standing, game.Map, item.BonusID, item.PlayerID)) then
                local failEvent = WL.GameOrderEvent.Create(item.PlayerID, "Conscription of " .. bonus.Name .. " failed: you no longer fully control it", {}, {});
                failEvent.Icon = "Blocked";
                addNewOrder(failEvent);
            else
                local existingReduction = reductions[item.BonusID] or 0;
                local effectiveValueBefore = math.max(bonus.Amount - existingReduction, 0);

                local decreaseAmount, incomeGain = CalculateConscriptionEffect(effectiveValueBefore);

                reductions[item.BonusID] = math.min(existingReduction + decreaseAmount, bonus.Amount);

                ApplyConscriptionStructuresForBonus(game, structuresByTerritory, allTerritoryModifications, bonus, reductions[item.BonusID]);

                local message = "Conscripted " .. bonus.Name .. ": bonus value permanently reduced by " .. decreaseAmount .. ", gained " .. incomeGain .. " income this turn";
                local event = WL.GameOrderEvent.Create(item.PlayerID, message, { item.PlayerID }, {});
                event.Icon = "IncomeGain";

                if (game.Settings.CommerceGame) then
                    event.AddResourceOpt = { [item.PlayerID] = { [WL.ResourceType.Gold] = incomeGain } };
                else
                    event.IncomeMods = { WL.IncomeMod.Create(item.PlayerID, incomeGain, "Conscription") };
                end

                addNewOrder(event);
            end
        end
    end

    if (#allTerritoryModifications > 0) then
        -- WL.PlayerID.Neutral + empty visibleTo ({} = visible to everyone) since these are real map changes,
        -- not private info for the conscribing player - the per-item income events above stay player-scoped
        local structuresEvent = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, "Conscription structures updated", {}, allTerritoryModifications);
        structuresEvent.Icon = "Build";
        addNewOrder(structuresEvent);
    end

    pub.BonusReductions = reductions;
    Mod.PublicGameData = pub;

    priv.PendingConscriptions = nil;
    Mod.PrivateGameData = priv;
end

---Places/upgrades the conscription tier structure (25/50/75/100%) on every territory in a bonus, based on how
---much of its value has been permanently taken. Never downgrades a territory's structure - since a territory can
---belong to more than one bonus, its structure always reflects the highest tier reached by any of them.
---@param game GameServerHook
---@param structuresByTerritory table<TerritoryID, table<EnumStructureType, integer>>
---@param territoryModificationsOut TerritoryModification[]
---@param bonus BonusDetails
---@param reduction integer
function ApplyConscriptionStructuresForBonus(game, structuresByTerritory, territoryModificationsOut, bonus, reduction)
    if (bonus.Amount <= 0) then return; end;

    local percent = reduction / bonus.Amount;
    local tier = GetConscriptionTierForPercent(percent);
    if (tier == nil) then return; end;

    for _, terrID in ipairs(bonus.Territories) do
        local structures = GetTerritoryStructures(game, structuresByTerritory, terrID);
        local currentTier = GetAppliedConscriptionTier(structures);
        local currentThreshold = (currentTier ~= nil) and currentTier.Threshold or 0;

        if (tier.Threshold > currentThreshold) then
            if (currentTier ~= nil) then
                structures[WL.StructureType.Custom(currentTier.StructureName)] = 0;
            end
            structures[WL.StructureType.Custom(tier.StructureName)] = 1;

            local territoryModification = WL.TerritoryModification.Create(terrID);
            territoryModification.SetStructuresOpt = CopyStructures(structures);
            table.insert(territoryModificationsOut, territoryModification);
        end
    end
end

---Every turn, re-applies each previously-conscripted bonus's permanent value reduction as a negative income
---modifier for whoever currently fully owns it (ownership may have changed hands since it was conscripted).
---There is no engine API to permanently change a bonus's own Amount, so the reduction is instead re-asserted
---every turn via an IncomeMod - this is the same "re-apply every turn" pattern MonitoredProduction uses.
---Grouped into one order per player (rather than one per conscripted bonus) to avoid spamming the order log -
---since the IncomeMod isn't scoped to a bonus, every bonus's reduction for a player can just be summed into a
---single combined IncomeMod on one event.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function ApplyPermanentBonusReductions(game, addNewOrder)
    local reductions = Mod.PublicGameData.BonusReductions;
    if (reductions == nil) then return; end;

    local standing = game.ServerGame.LatestTurnStanding;
    local totalByPlayer = {};

    for bonusID, reduction in pairs(reductions) do
        if (reduction > 0) then
            local ownerID = GetBonusSoleOwner(standing, game.Map, bonusID);
            if (ownerID ~= nil) then
                totalByPlayer[ownerID] = (totalByPlayer[ownerID] or 0) + reduction;
            end
        end
    end

    for playerID, total in pairs(totalByPlayer) do
        local event = WL.GameOrderEvent.Create(playerID, "Income reduced by " .. total .. " due to Conscription", { playerID }, {});
        event.IncomeMods = { WL.IncomeMod.Create(playerID, -total, "Conscription") };
        event.Icon = "IncomeLoss";
        addNewOrder(event);
    end
end

---Optional (Mod.Settings.NeutraliseFullyConscripted): once a bonus has been conscripted all the way down to 0
---value, a configurable % of its undefended territories go neutral each turn - representing the population no
---longer willing to fight for you. "Undefended" means at the compulsory minimum army (1 if the game's One Army
---Must Stand Guard setting is on, otherwise 0 - a territory sitting at 1 army under that setting is exactly as
---undefended as a territory sitting at 0 army when the setting is off) and has no special units garrisoned on
---it either. At least 1 applicable territory always
---goes neutral as long as the configured % is at least 1%. Bonuses that start at 0 value are excluded since they
---can never be "fully conscripted" in a meaningful sense.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function NeutraliseFullyConscriptedBonuses(game, addNewOrder)
    local reductions = Mod.PublicGameData.BonusReductions;
    if (reductions == nil) then return; end;

    local standing = game.ServerGame.LatestTurnStanding;
    local territoryModifications = {};

    local unoccupiedThreshold = 0;
    if (game.Settings.OneArmyStandsGuard) then
        unoccupiedThreshold = 1;
    end

    local percentPerTurn = Mod.Settings.NeutralisePercentPerTurn or 0;

    for bonusID, reduction in pairs(reductions) do
        local bonus = game.Map.Bonuses[bonusID];
        if (bonus ~= nil and bonus.Amount > 0 and reduction >= bonus.Amount) then
            local applicableTerritoryIds = {};
            for _, terrID in ipairs(bonus.Territories) do
                local territoryStanding = standing.Territories[terrID];
                local hasSpecialUnits = territoryStanding ~= nil and territoryStanding.NumArmies ~= nil
                    and territoryStanding.NumArmies.SpecialUnits ~= nil and #territoryStanding.NumArmies.SpecialUnits > 0;

                if (territoryStanding ~= nil and territoryStanding.OwnerPlayerID ~= WL.PlayerID.Neutral
                    and territoryStanding.NumArmies ~= nil and territoryStanding.NumArmies.NumArmies <= unoccupiedThreshold
                    and not hasSpecialUnits) then
                    table.insert(applicableTerritoryIds, terrID);
                end
            end

            local numApplicable = #applicableTerritoryIds;
            if (numApplicable > 0) then
                local numToNeutralise = math.floor(percentPerTurn * numApplicable);
                if (numToNeutralise < 1 and percentPerTurn >= 0.01) then
                    numToNeutralise = 1;
                end
                numToNeutralise = math.min(numToNeutralise, numApplicable);

                if (numToNeutralise > 0) then
                    shuffleInPlace(applicableTerritoryIds);
                    for i = 1, numToNeutralise do
                        local territoryModification = WL.TerritoryModification.Create(applicableTerritoryIds[i]);
                        territoryModification.SetOwnerOpt = WL.PlayerID.Neutral;
                        table.insert(territoryModifications, territoryModification);
                    end
                end
            end
        end
    end

    if (#territoryModifications > 0) then
        local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, "Fully conscripted territories rebel and go neutral", {}, territoryModifications);
        event.Icon = "Triggered";
        addNewOrder(event);
    end
end
