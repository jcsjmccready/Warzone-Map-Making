require("Utilities");

---@class MonitoringRules # The settings for one card type (Reconnaissance or Surveillance)
---@field Strength integer # Income change per monitored item owned by the caster or their team, can be negative
---@field OpponentStrength integer # Income change per monitored item owned by an opponent, can be negative
---@field MonitorCities boolean | nil # True if cities are monitored
---@field MonitorTerritories boolean | nil # True if territories are monitored
---@field PerCity boolean | nil # When monitoring cities, true if the strength applies per city
---@field PerTerritoryWithCity boolean | nil # When monitoring cities, true if the strength applies once per territory with a city

---@class MonitoringTotals # The accumulated effect of all active cards
---@field changeByPlayer table<PlayerID, integer> # Net income change per player, before reductions are capped at 0
---@field opponentCasterIDs table<PlayerID, boolean> # The set of players whose cards affected at least one opponent

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_End(game, addNewOrder)
    MigrateModSettings();
    ApplyMonitoredProductionIncome(game, addNewOrder);
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function ApplyMonitoredProductionIncome(game, addNewOrder)
    local standing = game.ServerGame.LatestTurnStanding;
    local totals = AccumulateTotals(game, standing);
    ApplyTotals(game, standing, totals, addNewOrder);
end

--sums the net income change from every active Reconnaissance and Surveillance card, per player, so we send one event per player
---@param game GameServerHook
---@param standing GameStanding
---@return MonitoringTotals
function AccumulateTotals(game, standing)
    local activeCards = standing.ActiveCards or {};

    ---@type MonitoringTotals
    local totals = {
        changeByPlayer = {};
        opponentCasterIDs = {};
    };

    if (Mod.Settings.ReconnaissanceEnabled or Mod.Settings.MonitorCities or Mod.Settings.MonitorTerritories) then
        ---@type MonitoringRules
        local rules = {
            Strength = Mod.Settings.EffectStrength or 0;
            OpponentStrength = Mod.Settings.OpponentEffectStrength or 0;
            MonitorCities = Mod.Settings.MonitorCities;
            MonitorTerritories = Mod.Settings.MonitorTerritories;
            PerCity = Mod.Settings.CityIncomeModePerCity;
            PerTerritoryWithCity = Mod.Settings.CityIncomeModePerTerritoryWithCity;
        };

        if (rules.Strength ~= 0 or rules.OpponentStrength ~= 0) then
            for _, activeCard in ipairs(activeCards) do
                local cardOrder = activeCard.Card;
                if (cardOrder ~= nil and cardOrder.proxyType == 'GameOrderPlayCardReconnaissance') then
                    local coveredTerritories = GetTerritoryAndAdjacentIDs(game, cardOrder.TargetTerritory);
                    AccumulateCardEffect(game, standing, cardOrder.PlayerID, coveredTerritories, rules, totals);
                end
            end
        end
    end

    if (Mod.Settings.SurveillanceEnabled) then
        ---@type MonitoringRules
        local rules = {
            Strength = Mod.Settings.SurveillanceEffectStrength or 0;
            OpponentStrength = Mod.Settings.SurveillanceOpponentEffectStrength or 0;
            MonitorCities = Mod.Settings.SurveillanceMonitorCities;
            MonitorTerritories = Mod.Settings.SurveillanceMonitorTerritories;
            PerCity = Mod.Settings.SurveillanceCityIncomeModePerCity;
            PerTerritoryWithCity = Mod.Settings.SurveillanceCityIncomeModePerTerritoryWithCity;
        };

        if (rules.Strength ~= 0 or rules.OpponentStrength ~= 0) then
            for _, activeCard in ipairs(activeCards) do
                local cardOrder = activeCard.Card;
                if (cardOrder ~= nil and cardOrder.proxyType == 'GameOrderPlayCardSurveillance') then
                    local coveredTerritories = game.Map.Bonuses[cardOrder.TargetBonus].Territories;
                    AccumulateCardEffect(game, standing, cardOrder.PlayerID, coveredTerritories, rules, totals);
                end
            end
        end
    end

    return totals;
end

--creates one event per player from their net income change, plus one event per player whose cards affected an opponent
---@param game GameServerHook
---@param standing GameStanding
---@param totals MonitoringTotals
---@param addNewOrder fun(order: GameOrder)
function ApplyTotals(game, standing, totals, addNewOrder)
    -- gold in commerce games, otherwise armies
    local isCommerce = game.Settings.CommerceGame;

    for playerID, change in pairs(totals.changeByPlayer) do
        local event;

        if (change > 0) then
            if (isCommerce) then
                event = WL.GameOrderEvent.Create(playerID, "Monitored Production granted " .. change .. " gold", { playerID }, {});
                event.AddResourceOpt = { [playerID] = { [WL.ResourceType.Gold] = change } };
            else
                event = WL.GameOrderEvent.Create(playerID, "Monitored Production granted " .. change .. " bonus armies", { playerID }, {});
                event.IncomeMods = { WL.IncomeMod.Create(playerID, change, "Monitored Production") };
            end
            event.Icon = "IncomeGain";
        elseif (change < 0) then
            -- reductions are capped so they can never take a player below 0
            local current;
            if (isCommerce) then
                current = standing.NumResources(playerID, WL.ResourceType.Gold);
            else
                local player = game.ServerGame.Game.PlayingPlayers[playerID];
                current = (player ~= nil) and player.Income(0, standing, false, false).Total or 0;
            end

            local loss = math.min(-change, math.max(current, 0));

            if (loss > 0) then
                if (isCommerce) then
                    event = WL.GameOrderEvent.Create(playerID, "Monitored Production reduced gold by " .. loss, { playerID }, {});
                    event.AddResourceOpt = { [playerID] = { [WL.ResourceType.Gold] = -loss } };
                else
                    event = WL.GameOrderEvent.Create(playerID, "Monitored Production reduced income by " .. loss .. " armies", { playerID }, {});
                    event.IncomeMods = { WL.IncomeMod.Create(playerID, -loss, "Monitored Production") };
                end
                event.Icon = "IncomeLoss";
            end
        end

        if (event ~= nil) then
            addNewOrder(event);
        end
    end

    -- deliberately doesn't say who was affected or by how much, just confirms the card had an effect
    local opponentEffectIcon = GetOpponentEffectIcon();
    for casterID, _ in pairs(totals.opponentCasterIDs) do
        local event = WL.GameOrderEvent.Create(casterID, "Monitored Production affected an opponent's income", { casterID }, {});
        event.Icon = opponentEffectIcon;
        addNewOrder(event);
    end
end

--adds the effect of one card to totals: territories owned by the caster or their team change by rules.Strength, and
--opponents' territories change by rules.OpponentStrength
---@param game GameServerHook
---@param standing GameStanding
---@param casterID PlayerID # The player who played the card
---@param coveredTerritories TerritoryID[] # The territories the card covers
---@param rules MonitoringRules
---@param totals MonitoringTotals # Updated in place
function AccumulateCardEffect(game, standing, casterID, coveredTerritories, rules, totals)
    for _, territoryID in ipairs(coveredTerritories) do
        local territory = standing.Territories[territoryID];

        if (territory ~= nil and not territory.IsNeutral) then
            local territoryOwnerID = territory.OwnerPlayerID;
            local isFriendly = IsSameTeam(game, casterID, territoryOwnerID);
            local strength = isFriendly and rules.Strength or rules.OpponentStrength;
            local amount = strength * GetMonitoredInstances(territory, rules);

            if (amount ~= 0) then
                if (not isFriendly) then
                    totals.opponentCasterIDs[casterID] = true;
                end

                totals.changeByPlayer[territoryOwnerID] = (totals.changeByPlayer[territoryOwnerID] or 0) + amount;
            end
        end
    end
end

--returns how many times the effect strength applies to this territory under the given monitoring rules
---@param territory TerritoryStanding
---@param rules MonitoringRules
---@return integer
function GetMonitoredInstances(territory, rules)
    if (rules.MonitorCities) then
        local cityCount = (territory.Structures ~= nil) and (territory.Structures[WL.StructureType.City] or 0) or 0;

        if (cityCount > 0) then
            if (rules.PerCity) then
                return cityCount;
            elseif (rules.PerTerritoryWithCity) then
                return 1;
            end
        end
    elseif (rules.MonitorTerritories) then
        return 1;
    end

    return 0;
end

--true when both players are the same player, or share a team (Team -1 means no team)
---@param game GameServerHook
---@param playerID PlayerID
---@param otherPlayerID PlayerID
---@return boolean
function IsSameTeam(game, playerID, otherPlayerID)
    if (playerID == otherPlayerID) then
        return true;
    end

    local players = game.ServerGame.Game.Players;
    local player, otherPlayer = players[playerID], players[otherPlayerID];

    return player ~= nil and otherPlayer ~= nil and player.Team ~= -1 and player.Team == otherPlayer.Team;
end

--IncomeLoss if every enabled card type only reduces opponents' income, IncomeGain if every one only increases it,
--otherwise the neutral Income icon
---@return string
function GetOpponentEffectIcon()
    local opponentStrengths = {};

    if (Mod.Settings.ReconnaissanceEnabled or Mod.Settings.MonitorCities or Mod.Settings.MonitorTerritories) then
        table.insert(opponentStrengths, Mod.Settings.OpponentEffectStrength or 0);
    end

    if (Mod.Settings.SurveillanceEnabled) then
        table.insert(opponentStrengths, Mod.Settings.SurveillanceOpponentEffectStrength or 0);
    end

    local hasNegative, hasPositive = false, false;
    for _, strength in ipairs(opponentStrengths) do
        if (strength < 0) then
            hasNegative = true;
        elseif (strength > 0) then
            hasPositive = true;
        end
    end

    if (hasNegative and not hasPositive) then
        return "IncomeLoss";
    elseif (hasPositive and not hasNegative) then
        return "IncomeGain";
    end
    return "Income";
end
