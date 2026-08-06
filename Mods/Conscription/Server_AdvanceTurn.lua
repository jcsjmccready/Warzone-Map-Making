require("Utilities");

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

        if (not PlayerFullyOwnsBonus(game.ServerGame.LatestTurnStanding, game.Map, bonusID, order.PlayerID)) then
            local event = WL.GameOrderEvent.Create(order.PlayerID, "Conscription failed: you no longer fully control that bonus", {}, {});
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
    local reductions = priv.BonusReductions or {};

    for _, item in ipairs(pending) do
        local bonus = game.Map.Bonuses[item.BonusID];

        if (bonus ~= nil) then
            if (not PlayerFullyOwnsBonus(standing, game.Map, item.BonusID, item.PlayerID)) then
                local failEvent = WL.GameOrderEvent.Create(item.PlayerID, "Conscription of " .. bonus.Name .. " failed: you no longer fully control it", {}, {});
                addNewOrder(failEvent);
            else
                local existingReduction = reductions[item.BonusID] or 0;
                local effectiveValueBefore = math.max(bonus.Amount - existingReduction, 0);

                -- the value decrease is never allowed to take the bonus below 0
                local desiredDecrease = math.max(
                    (Mod.Settings.FlatValueDecrease or 0) + (Mod.Settings.PercentValueDecrease or 0) * effectiveValueBefore,
                    Mod.Settings.MinimumValueDecrease or 0);
                local actualDecrease = math.min(desiredDecrease, effectiveValueBefore);

                local incomeGain = math.max(
                    (Mod.Settings.FlatIncomeGained or 0) + (Mod.Settings.PercentIncomeGained or 0) * effectiveValueBefore,
                    Mod.Settings.MinimumIncomeGained or 0);

                -- if the bonus was too close to 0 to take the full desired decrease, scale the income down by
                -- the same proportion - this is the one case where the configured minimum income is overridden
                if (desiredDecrease > 0 and actualDecrease < desiredDecrease) then
                    incomeGain = incomeGain * (actualDecrease / desiredDecrease);
                end

                local decreaseAmount = math.floor(actualDecrease + 0.5);
                incomeGain = math.floor(incomeGain + 0.5);

                reductions[item.BonusID] = math.min(existingReduction + decreaseAmount, bonus.Amount);

                local message = "Conscripted " .. bonus.Name .. ": bonus value permanently reduced by " .. decreaseAmount .. ", gained " .. incomeGain .. " income this turn";
                local event = WL.GameOrderEvent.Create(item.PlayerID, message, { item.PlayerID }, {});

                if (game.Settings.CommerceGame) then
                    event.AddResourceOpt = { [item.PlayerID] = { [WL.ResourceType.Gold] = incomeGain } };
                else
                    event.IncomeMods = { WL.IncomeMod.Create(item.PlayerID, incomeGain, "Conscription", item.BonusID) };
                end

                addNewOrder(event);
            end
        end
    end

    priv.BonusReductions = reductions;
    priv.PendingConscriptions = nil;
    Mod.PrivateGameData = priv;
end

---Every turn, re-applies each previously-conscripted bonus's permanent value reduction as a negative income
---modifier for whoever currently fully owns it (ownership may have changed hands since it was conscripted).
---There is no engine API to permanently change a bonus's own Amount, so the reduction is instead re-asserted
---every turn via a scoped IncomeMod - this is the same "re-apply every turn" pattern MonitoredProduction uses.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function ApplyPermanentBonusReductions(game, addNewOrder)
    local priv = Mod.PrivateGameData;
    local reductions = priv.BonusReductions;
    if (reductions == nil) then return; end;

    local standing = game.ServerGame.LatestTurnStanding;

    for bonusID, reduction in pairs(reductions) do
        if (reduction > 0) then
            local ownerID = GetBonusSoleOwner(standing, game.Map, bonusID);
            if (ownerID ~= nil) then
                local bonus = game.Map.Bonuses[bonusID];
                local event = WL.GameOrderEvent.Create(ownerID, bonus.Name .. " income reduced due to Conscription", { ownerID }, {});
                event.IncomeMods = { WL.IncomeMod.Create(ownerID, -reduction, "Conscription", bonusID) };
                addNewOrder(event);
            end
        end
    end
end

---Optional (Mod.Settings.NeutraliseFullyConscripted): once a bonus has been conscripted all the way down to 0
---value, a configurable % of its undefended territories go neutral each turn - representing the population no
---longer willing to fight for you. "Undefended" means at the compulsory minimum army (1 if the game's One Army
---Must Stand Guard setting is on, otherwise 0 - a territory sitting at 1 army under that setting is exactly as
---undefended as a territory sitting at 0 army when the setting is off). At least 1 applicable territory always
---goes neutral as long as the configured % is at least 1%. Bonuses that start at 0 value are excluded since they
---can never be "fully conscripted" in a meaningful sense.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function NeutraliseFullyConscriptedBonuses(game, addNewOrder)
    local priv = Mod.PrivateGameData;
    local reductions = priv.BonusReductions;
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
                if (territoryStanding ~= nil and territoryStanding.OwnerPlayerID ~= WL.PlayerID.Neutral
                    and territoryStanding.NumArmies ~= nil and territoryStanding.NumArmies.NumArmies <= unoccupiedThreshold) then
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
                    shuffle(applicableTerritoryIds);
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
        addNewOrder(event);
    end
end
