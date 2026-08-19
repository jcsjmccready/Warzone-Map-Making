require("Utilities");

---@class BuddingCounter # A single tracked Budding Corruption card, incubating towards maturing into Corruption
---@field PlayerID PlayerID
---@field CardInstanceID CardInstanceID
---@field TurnMatures integer

---@class CorruptedPoolEntry # A single card taken from a player that's still owed back to them
---@field CardID CardID # The CardID of the card that was corrupted
---@field IntField integer | nil # A generic integer parameter for cards that need one (eg. Armies for a reinforcement card instance); nil if the corrupted card didn't need one. Needed to reconstruct the card in full if this entry is ever recovered at 100%

---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl)
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
    if (order.proxyType == 'GameOrderDiscard') then
        HandleDiscard(game, order, addNewOrder);
        return;
    end

    if (order.proxyType ~= 'GameOrderPlayCardCustom') then
        return;
    end

    if (order.CustomCardID == Mod.Settings.CorruptHandCardID and startsWith(order.ModData, "Corrupt_")) then
        HandleCorruptHandPlayed(game, order, addNewOrder);
    elseif (order.CustomCardID == Mod.Settings.CorruptedCardID) then
        HandleCorruptedPlayed(game, order, addNewOrder);
    end
end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_End(game, addNewOrder)
    -- ordering of functions: we want to corrupt a card the same turn we get a corruption, so the 0 maturity config actually has a chance to do something
    ProgressMaturedBuddingCorruptions(game, addNewOrder);
    CorruptCardsForActiveCorruptions(game, addNewOrder);
end

---@param game GameServerHook
---@param order GameOrder
---@param addNewOrder fun(order: GameOrder)
function HandleDiscard(game, order, addNewOrder)
    local privateGameData = Mod.PrivateGameData;

    local counters = privateGameData.BuddingCounters or {};

    -- player discarded budding corruption, update tracking data
    local remaining = {};
    for _, counter in ipairs(counters) do
        if (not (counter.PlayerID == order.PlayerID and counter.CardInstanceID == order.CardInstanceID)) then
            table.insert(remaining, counter);
        end
    end
    privateGameData.BuddingCounters = remaining;
    Mod.PrivateGameData = privateGameData;

    -- player discarded a corrupted card - if random recovery is enabled the random option still triggers. No kindness for player chosen tho
    local playerCards = game.ServerGame.LatestTurnStanding.Cards[order.PlayerID];
    local discardedInstance = playerCards ~= nil and playerCards.WholeCards[order.CardInstanceID];
    if (discardedInstance ~= nil and discardedInstance.CardID == Mod.Settings.CorruptedCardID) then
        local pool = GetCorruptedPool(order.PlayerID);
        if (#pool > 0) then
            local entry = PopEntryFromCorruptedPoolAtIndex(order.PlayerID, math.random(#pool));
            if (entry ~= nil and Mod.Settings.RecoveryAllowRandom) then
                AwardCorruptedCardRecovery(game, order.PlayerID, entry, Mod.Settings.RecoveryRandomPercent or 0, addNewOrder);
            end
        end
    end
end

---@param game GameServerHook
---@param order GameOrder
---@param addNewOrder fun(order: GameOrder)
function HandleCorruptHandPlayed(game, order, addNewOrder)
    local targetPlayerID = tonumber(string.sub(order.ModData, string.len("Corrupt_") + 1));

    -- check still alive
    if (game.ServerGame.Game.PlayingPlayers[targetPlayerID] == nil) then
        return;
    end

    if ((Mod.Settings.TurnsUntilCorruption or 0) <= 0) then
        GrantActiveCorruption(targetPlayerID, addNewOrder);
    else
        GrantBuddingCorruption(game, targetPlayerID, addNewOrder);
    end
end

---@param game GameServerHook
function GrantBuddingCorruption(game, playerID, addNewOrder)
    local instance = WL.NoParameterCardInstance.Create(Mod.Settings.BuddingCorruptionCardID);
    addNewOrder(WL.GameOrderReceiveCard.Create(playerID, { instance }));

    local privateGameData = Mod.PrivateGameData;
    local counters = privateGameData.BuddingCounters or {};

    ---@type BuddingCounter
    local counter = {
        PlayerID = playerID,
        CardInstanceID = instance.ID,
        TurnMatures = game.Game.TurnNumber + Mod.Settings.TurnsUntilCorruption
    };

    table.insert(counters, counter);

    privateGameData.BuddingCounters = counters;
    Mod.PrivateGameData = privateGameData;
end

function GrantActiveCorruption(playerID, addNewOrder)
    local instance = WL.NoParameterCardInstance.Create(Mod.Settings.CorruptionCardID);
    addNewOrder(WL.GameOrderReceiveCard.Create(playerID, { instance }));
end

function GetCorruptedPool(playerID)
    local allPlayerGameData = Mod.PlayerGameData;
    local playerGameData = allPlayerGameData[playerID] or {};
    return playerGameData.CorruptedPool or {};
end

function SetCorruptedPool(playerID, pool)
    local allPlayerGameData = Mod.PlayerGameData;
    local playerGameData = allPlayerGameData[playerID] or {};
    playerGameData.CorruptedPool = pool;
    allPlayerGameData[playerID] = playerGameData;
    Mod.PlayerGameData = allPlayerGameData;
end

function PopEntryFromCorruptedPoolAtIndex(playerID, index)
    local pool = GetCorruptedPool(playerID);
    local entry = pool[index];
    if (entry == nil) then
        return nil;
    end

    table.remove(pool, index);
    SetCorruptedPool(playerID, pool);
    return entry;
end

---@param game GameServerHook
---@param entry CorruptedPoolEntry
function AwardCorruptedCardRecovery(game, playerID, entry, percent, addNewOrder)
    -- whole card logic
    if (percent >= 1) then
        local instance;
        if (entry.IntField ~= nil) then
            instance = WL.ReinforcementCardInstance.Create(entry.IntField);
        else
            instance = WL.NoParameterCardInstance.Create(entry.CardID);
        end
        addNewOrder(WL.GameOrderReceiveCard.Create(playerID, { instance }));
        addNewOrder(WL.GameOrderEvent.Create(playerID,  "Corrupted removed from card", { playerID }, {}));
        return;
    end

    -- partial card logic
    local cardSettings = game.Settings.Cards[entry.CardID];
    local numPieces = (cardSettings ~= nil and cardSettings.NumPieces) or 1;
    local piecesAwarded = math.max(math.floor(percent * numPieces + 0.5), 1);

    local event = WL.GameOrderEvent.Create(playerID, "Corrupted removed from card", { playerID }, {});
    event.AddCardPiecesOpt = { [playerID] = { [entry.CardID] = piecesAwarded } };
    addNewOrder(event);
end

---@param game GameServerHook
---@param order GameOrder
---@param addNewOrder fun(order: GameOrder)
function HandleCorruptedPlayed(game, order, addNewOrder)
    local pool = GetCorruptedPool(order.PlayerID);
    if (#pool == 0) then
        return; -- shouldn't happen but safety net
    end

    local index, percent;
    if (order.ModData == "RecoverRandom" and Mod.Settings.RecoveryAllowRandom) then
        index = math.random(#pool);
        percent = Mod.Settings.RecoveryRandomPercent or 0;
    elseif (startsWith(order.ModData, "RecoverSelected_") and Mod.Settings.RecoveryAllowPlayerSelected) then
        index = tonumber(string.sub(order.ModData, string.len("RecoverSelected_") + 1));
        percent = Mod.Settings.RecoveryPlayerSelectedPercent or 0;
    else
        return;
    end

    local entry = PopEntryFromCorruptedPoolAtIndex(order.PlayerID, index);
    if (entry == nil) then
        return;
    end

    AwardCorruptedCardRecovery(game, order.PlayerID, entry, percent, addNewOrder);
end

function ProgressMaturedBuddingCorruptions(game, addNewOrder)
    local privateGameData = Mod.PrivateGameData;
    local counters = privateGameData.BuddingCounters or {};
    local remaining = {};

    for _, counter in ipairs(counters) do
        local playerCards = game.ServerGame.LatestTurnStanding.Cards[counter.PlayerID];
        local stillHeld = playerCards ~= nil and playerCards.WholeCards[counter.CardInstanceID] ~= nil;

        if (stillHeld) then
            if (game.Game.TurnNumber >= counter.TurnMatures) then
                addNewOrder(WL.GameOrderDiscard.Create(counter.PlayerID, counter.CardInstanceID));
                GrantActiveCorruption(counter.PlayerID, addNewOrder);
            else
                table.insert(remaining, counter);
            end
        end
    end

    privateGameData.BuddingCounters = remaining;
    Mod.PrivateGameData = privateGameData;
end

function CorruptCardsForActiveCorruptions(game, addNewOrder)
    local perSource = Mod.Settings.CardsCorruptedPerTurnPerSource or 1;

    for playerID, playerCards in pairs(game.ServerGame.LatestTurnStanding.Cards) do
        local numCorruptionCards = 0;
        for _, cardInstance in pairs(playerCards.WholeCards) do
            if (cardInstance.CardID == Mod.Settings.CorruptionCardID) then
                numCorruptionCards = numCorruptionCards + 1;
            end
        end

        if (numCorruptionCards > 0) then
            local playerCorruptibleCards = GetCorruptibleCards(playerCards);
            shuffleInPlace(playerCorruptibleCards);

            local numToCorrupt = math.min(numCorruptionCards * perSource, #playerCorruptibleCards);
            if (numToCorrupt > 0) then
                local pool = GetCorruptedPool(playerID);

                for i = 1, numToCorrupt do
                    local picked = playerCorruptibleCards[i];
                    addNewOrder(WL.GameOrderDiscard.Create(playerID, picked.InstanceID));

                    -- extend this as new cards have int fields
                    local intField = nil;
                    if (picked.Instance.proxyType == 'ReinforcementCardInstance') then
                        intField = picked.Instance.Armies;
                    end

                    ---@type CorruptedPoolEntry
                    local poolEntry = { CardID = picked.Instance.CardID, IntField = intField };
                    table.insert(pool, poolEntry);

                    local corruptedInstance = WL.NoParameterCardInstance.Create(Mod.Settings.CorruptedCardID);
                    addNewOrder(WL.GameOrderReceiveCard.Create(playerID, { corruptedInstance }));
                end

                SetCorruptedPool(playerID, pool);
            end
        end
    end
end
