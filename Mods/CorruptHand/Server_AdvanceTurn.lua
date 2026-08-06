require("Utilities");

---Server_AdvanceTurn_Order hook. Handles the two cards a player can actively play: Corrupt Hand (start
---corrupting an enemy's hand) and Corrupted (recover something from your own corrupted pool).
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl)
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
    if (order.proxyType ~= 'GameOrderPlayCardCustom') then
        return;
    end

    if (order.CustomCardID == Mod.Settings.CorruptHandCardID and startsWith(order.ModData, "Corrupt_")) then
        HandleCorruptHandPlayed(game, order, addNewOrder);
    elseif (order.CustomCardID == Mod.Settings.CorruptedCardID and order.ModData == "RecoverCorrupted") then
        HandleCorruptedPlayed(game, order, addNewOrder);
    end
end

--starts a new corruption against order.ModData's target player, provided they're still a legal target (the
--client can't be trusted to have picked one still playing, or not the player themself)
---@param game GameServerHook
---@param order GameOrder
---@param addNewOrder fun(order: GameOrder)
function HandleCorruptHandPlayed(game, order, addNewOrder)
    local targetPlayerID = tonumber(string.sub(order.ModData, string.len("Corrupt_") + 1));

    if (targetPlayerID == order.PlayerID or game.ServerGame.Game.PlayingPlayers[targetPlayerID] == nil) then
        return;
    end

    if ((Mod.Settings.TurnsUntilCorruption or 0) <= 0) then
        GrantCorruption(targetPlayerID, addNewOrder);
    else
        GrantBuddingCorruption(targetPlayerID, addNewOrder);
    end
end

--gives playerID a Budding Corruption card and starts tracking its countdown to maturing into Corruption
function GrantBuddingCorruption(playerID, addNewOrder)
    local instance = WL.NoParameterCardInstance.Create(Mod.Settings.BuddingCorruptionCardID);
    addNewOrder(WL.GameOrderReceiveCard.Create(playerID, { instance }));

    local privateGameData = Mod.PrivateGameData;
    local counters = privateGameData.BuddingCounters or {};
    table.insert(counters, { PlayerID = playerID, CardInstanceID = instance.ID, TurnsRemaining = Mod.Settings.TurnsUntilCorruption });
    privateGameData.BuddingCounters = counters;
    Mod.PrivateGameData = privateGameData;
end

--gives playerID a Corruption card directly (either TurnsUntilCorruption is 0, or a Budding Corruption just matured)
function GrantCorruption(playerID, addNewOrder)
    local instance = WL.NoParameterCardInstance.Create(Mod.Settings.CorruptionCardID);
    addNewOrder(WL.GameOrderReceiveCard.Create(playerID, { instance }));
end

--resolves playing a Corrupted card: pops one random entry from the player's own corrupted pool and, depending on
--RecoveryModeFullRandomCard, either gives it back as a whole card or refunds a % of pieces towards it
---@param game GameServerHook
---@param order GameOrder
---@param addNewOrder fun(order: GameOrder)
function HandleCorruptedPlayed(game, order, addNewOrder)
    local privateGameData = Mod.PrivateGameData;
    local pools = privateGameData.CorruptedPool or {};
    local pool = pools[order.PlayerID] or {};

    if (#pool == 0) then
        return; -- shouldn't happen (a Corrupted card is only ever granted alongside a matching pool entry)
    end

    local index = math.random(#pool);
    local entry = pool[index];
    table.remove(pool, index);
    pools[order.PlayerID] = pool;
    privateGameData.CorruptedPool = pools;
    Mod.PrivateGameData = privateGameData;

    if (Mod.Settings.RecoveryModeFullRandomCard) then
        local instance;
        if (entry.Armies ~= nil) then
            instance = WL.ReinforcementCardInstance.Create(entry.Armies);
        else
            instance = WL.NoParameterCardInstance.Create(entry.CardID);
        end
        addNewOrder(WL.GameOrderReceiveCard.Create(order.PlayerID, { instance }));
        addNewOrder(WL.GameOrderEvent.Create(order.PlayerID, "Recovered a corrupted card", { order.PlayerID }, {}));
    else
        local cardSettings = game.Settings.Cards[entry.CardID];
        local numPieces = (cardSettings ~= nil and cardSettings.NumPieces) or 1;
        local piecesAwarded = math.max(math.floor((Mod.Settings.PartialPiecesPercent or 0) * numPieces + 0.5), 1);

        local event = WL.GameOrderEvent.Create(order.PlayerID, "Recovered " .. piecesAwarded .. " piece(s) towards a corrupted card", { order.PlayerID }, {});
        event.AddCardPiecesOpt = { [order.PlayerID] = { [entry.CardID] = piecesAwarded } };
        addNewOrder(event);
    end
end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_End(game, addNewOrder)
    TickBuddingCorruptions(game, addNewOrder);
    CorruptCardsForActiveCorruptions(game, addNewOrder);
end

--counts down every tracked Budding Corruption card by one turn. If its owner has since discarded it, the
--corruption is simply dropped (stops spreading, matching the discard rule). Once a counter reaches 0, the
--Budding Corruption card is discarded and replaced with a full Corruption card. A card that matures this way
--doesn't start corrupting anything until next turn's end, since Corrupt Cards For Active Corruptions below only
--sees cards already present in this turn's standing.
function TickBuddingCorruptions(game, addNewOrder)
    local privateGameData = Mod.PrivateGameData;
    local counters = privateGameData.BuddingCounters or {};
    local remaining = {};

    for _, counter in ipairs(counters) do
        local playerCards = game.ServerGame.LatestTurnStanding.Cards[counter.PlayerID];
        local stillHeld = playerCards ~= nil and playerCards.WholeCards[counter.CardInstanceID] ~= nil;

        if (stillHeld) then
            counter.TurnsRemaining = counter.TurnsRemaining - 1;
            if (counter.TurnsRemaining <= 0) then
                addNewOrder(WL.GameOrderDiscard.Create(counter.PlayerID, counter.CardInstanceID));
                GrantCorruption(counter.PlayerID, addNewOrder);
            else
                table.insert(remaining, counter);
            end
        end
    end

    privateGameData.BuddingCounters = remaining;
    Mod.PrivateGameData = privateGameData;
end

--for every player holding one or more Corruption cards, corrupts CardsCorruptedPerTurnPerSource eligible cards
--per Corruption card they hold: the target card is discarded, its type recorded in the player's corrupted pool
--(for later recovery via a Corrupted card), and a Corrupted card is given in its place. Players with no eligible
--cards left are simply skipped that turn.
function CorruptCardsForActiveCorruptions(game, addNewOrder)
    local perSource = Mod.Settings.CardsCorruptedPerTurnPerSource or 1;
    local privateGameData = Mod.PrivateGameData;
    local pools = privateGameData.CorruptedPool or {};

    for playerID, playerCards in pairs(game.ServerGame.LatestTurnStanding.Cards) do
        local numCorruptionCards = 0;
        for _, cardInstance in pairs(playerCards.WholeCards) do
            if (cardInstance.CardID == Mod.Settings.CorruptionCardID) then
                numCorruptionCards = numCorruptionCards + 1;
            end
        end

        if (numCorruptionCards > 0) then
            local eligible = GetCorruptibleCards(playerCards);
            shuffle(eligible);

            local numToCorrupt = math.min(numCorruptionCards * perSource, #eligible);
            if (numToCorrupt > 0) then
                local pool = pools[playerID] or {};

                for i = 1, numToCorrupt do
                    local picked = eligible[i];
                    addNewOrder(WL.GameOrderDiscard.Create(playerID, picked.InstanceID));

                    -- Armies is only a valid field on reinforcement card instances; reading it off any other
                    -- instance type isn't safe, so it's only captured when the instance is actually one of those
                    local armies = nil;
                    if (picked.Instance.proxyType == 'ReinforcementCardInstance') then
                        armies = picked.Instance.Armies;
                    end
                    table.insert(pool, { CardID = picked.Instance.CardID, Armies = armies });

                    local corruptedInstance = WL.NoParameterCardInstance.Create(Mod.Settings.CorruptedCardID);
                    addNewOrder(WL.GameOrderReceiveCard.Create(playerID, { corruptedInstance }));
                end

                pools[playerID] = pool;
            end
        end
    end

    privateGameData.CorruptedPool = pools;
    Mod.PrivateGameData = privateGameData;
end
