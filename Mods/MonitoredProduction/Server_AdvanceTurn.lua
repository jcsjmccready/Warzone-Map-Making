require("Utilities");

---Server_AdvanceTurn_End hook. Grants bonus income for every turn a player has an active Reconnaissance effect
---covering one of their own (friendly) territories - the whole point of playing Reconnaissance on your own
---territory here isn't vision (you already have that), it's to activate the income bonus on it and its neighbours.
---Evaluated at the end of the turn (after this turn's own card plays have resolved into LatestTurnStanding) so
---that playing Reconnaissance on turn 1 grants the bonus income for the start of turn 2, not turn 3.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_End(game, addNewOrder)
    ApplyMonitoredProductionIncome(game, addNewOrder);
end

--scans this turn's active cards for Reconnaissance effects, and for every friendly territory they cover, grants
--the configured income bonus (gold per city / gold per territory-with-a-city / gold-or-troops per territory)
function ApplyMonitoredProductionIncome(game, addNewOrder)
    local strength = Mod.Settings.EffectStrength or 0;
    if (strength <= 0) then return; end

    local standing = game.ServerGame.LatestTurnStanding;
    local activeCards = standing.ActiveCards or {};

    -- accumulate totals per player so we send one event per player instead of one per territory
    local goldByPlayer = {};
    local armiesByPlayer = {};

    for _, activeCard in ipairs(activeCards) do
        local cardOrder = activeCard.Card;
        if (cardOrder ~= nil and cardOrder.proxyType == 'GameOrderPlayCardReconnaissance') then
            local casterID = cardOrder.PlayerID;
            local coveredTerritories = GetTerritoryAndAdjacentIDs(game, cardOrder.TargetTerritory);

            for _, territoryID in ipairs(coveredTerritories) do
                local territory = standing.Territories[territoryID];

                --only territories owned by the player who cast the Reconnaissance count as "friendly"
                if (territory ~= nil and territory.OwnerPlayerID == casterID) then
                    if (Mod.Settings.MonitorCities) then
                        local cityCount = (territory.Structures ~= nil) and (territory.Structures[WL.StructureType.City] or 0) or 0;

                        if (cityCount > 0) then
                            if (Mod.Settings.CityIncomeModePerCity) then
                                goldByPlayer[casterID] = (goldByPlayer[casterID] or 0) + (strength * cityCount);
                            elseif (Mod.Settings.CityIncomeModePerTerritoryWithCity) then
                                goldByPlayer[casterID] = (goldByPlayer[casterID] or 0) + strength;
                            end
                        end
                    elseif (Mod.Settings.MonitorTerritories) then
                        --commerce games use gold; non-commerce games have no gold resource, so grant bonus
                        --reinforcement armies instead
                        if (game.Settings.CommerceGame) then
                            goldByPlayer[casterID] = (goldByPlayer[casterID] or 0) + strength;
                        else
                            armiesByPlayer[casterID] = (armiesByPlayer[casterID] or 0) + strength;
                        end
                    end
                end
            end
        end
    end

    for playerID, amount in pairs(goldByPlayer) do
        local event = WL.GameOrderEvent.Create(playerID, "Monitored Production granted " .. amount .. " gold", { playerID }, {});
        event.AddResourceOpt = { [playerID] = { [WL.ResourceType.Gold] = amount } };
        addNewOrder(event);
    end

    for playerID, amount in pairs(armiesByPlayer) do
        local event = WL.GameOrderEvent.Create(playerID, "Monitored Production granted " .. amount .. " bonus reinforcements", { playerID }, {});
        event.IncomeMods = { WL.IncomeMod.Create(playerID, amount, "Monitored Production") };
        addNewOrder(event);
    end
end
