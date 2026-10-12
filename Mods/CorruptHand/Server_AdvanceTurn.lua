require("Utilities");

---@class BuddingCounter # A single tracked Budding Corruption card, incubating towards maturing into Corruption
---@field PlayerID PlayerID
---@field CardInstanceID CardInstanceID
---@field TurnMatures integer

---@class CorruptedPoolEntry # A single card taken from a player that's still owed back to them
---@field ID integer # Stable identifier for this entry, unique within its player's pool for the rest of the game. Used instead of array position so a client's "recover this specific card" selection stays valid even if other entries are added to or removed from the pool (by another Corrupted card played the same turn) before this one resolves
---@field CardID CardID
---@field IntField integer | nil # A generic integer parameter for cards that need one (eg. Armies for a reinforcement card instance); nil if the corrupted card didn't need one. Needed to reconstruct the card in full if this entry is ever recovered at 100%

---@class ActiveCorruption # A single tracked Corruption card actively corrupting its owner's other cards
---@field PlayerID PlayerID
---@field CardInstanceID CardInstanceID

---@class PendingRecovery # A recovery requested this turn (by playing or discarding a Corrupted card), resolved
---@field PlayerID PlayerID
---@field Type "Random" | "Selected" # Resolve Selected before Random
---@field EntryID integer | nil # The CorruptedPoolEntry.ID requested, if using "Selected"

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
    -- we want to corrupt a card the same turn we get a corruption, so the 0 maturity config actually has a chance to do something - order matters
    ProgressMaturedBuddingCorruptions(game, addNewOrder);
    CorruptCardsForActiveCorruptions(game, addNewOrder);

    -- order last to protect recovered cards to avoid a negative feedback loop for players
    ResolvePendingRecoveries(game, addNewOrder);
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

    -- player discarded an active corruption, it stops corrupting further cards
    local activeCorruptions = privateGameData.ActiveCorruptions or {};
    local remainingActiveCorruptions = {};
    for _, active in ipairs(activeCorruptions) do
        if (not (active.PlayerID == order.PlayerID and active.CardInstanceID == order.CardInstanceID)) then
            table.insert(remainingActiveCorruptions, active);
        end
    end
    privateGameData.ActiveCorruptions = remainingActiveCorruptions;

    Mod.PrivateGameData = privateGameData;

    -- player discarded a corrupted card - if random recovery is enabled the random option still triggers.no kindness for player chosen tho
    local playerCards = game.ServerGame.LatestTurnStanding.Cards[order.PlayerID];
    local discardedInstance = playerCards ~= nil and playerCards.WholeCards[order.CardInstanceID];
    if (discardedInstance ~= nil and discardedInstance.CardID == Mod.Settings.CorruptedCardID and Mod.Settings.RecoveryAllowRandom) then
        QueuePendingRecovery(order.PlayerID, "Random", nil);
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

    local privateGameData = Mod.PrivateGameData;
    local activeCorruptions = privateGameData.ActiveCorruptions or {};

    ---@type ActiveCorruption
    local activeCorruption = { PlayerID = playerID, CardInstanceID = instance.ID };
    table.insert(activeCorruptions, activeCorruption);

    privateGameData.ActiveCorruptions = activeCorruptions;
    Mod.PrivateGameData = privateGameData;
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

-- generates ids for corrupted pool entry ids to simplify user selection of cards to recover
function GetNextCorruptedPoolEntryID(playerID)
    local allPlayerGameData = Mod.PlayerGameData;
    local playerGameData = allPlayerGameData[playerID] or {};

    local nextID = (playerGameData.NextCorruptedPoolEntryID or 0) + 1;
    playerGameData.NextCorruptedPoolEntryID = nextID;

    allPlayerGameData[playerID] = playerGameData;
    Mod.PlayerGameData = allPlayerGameData;
    return nextID;
end

function PopRandomCorruptedPoolEntry(playerID)
    local pool = GetCorruptedPool(playerID);
    if (#pool == 0) then
        return nil;
    end

    local index = math.random(#pool);
    local entry = pool[index];
    table.remove(pool, index);
    SetCorruptedPool(playerID, pool);
    return entry;
end

function PopCorruptedPoolEntryByID(playerID, entryID)
    local pool = GetCorruptedPool(playerID);
    for index, entry in ipairs(pool) do
        if (entry.ID == entryID) then
            table.remove(pool, index);
            SetCorruptedPool(playerID, pool);
            return entry;
        end
    end
    return nil;
end

---@param type "Random" | "Selected"
function QueuePendingRecovery(playerID, type, entryID)
    local privateGameData = Mod.PrivateGameData;
    local pending = privateGameData.PendingRecoveries or {};

    ---@type PendingRecovery
    local request = { PlayerID = playerID, Type = type, EntryID = entryID };
    table.insert(pending, request);

    privateGameData.PendingRecoveries = pending;
    Mod.PrivateGameData = privateGameData;
end

---@param game GameServerHook
---@param entry CorruptedPoolEntry
function AwardCorruptedCardRecovery(game, playerID, entry, percent, addNewOrder)
    local cardName = GetCardDisplayName(game, entry.CardID);

    -- whole card logic
    if (percent >= 1) then
        local instance;
        if (entry.IntField ~= nil) then
            instance = WL.ReinforcementCardInstance.Create(entry.IntField);
        else
            instance = WL.NoParameterCardInstance.Create(entry.CardID);
        end
        addNewOrder(WL.GameOrderReceiveCard.Create(playerID, { instance }));
        addNewOrder(WL.GameOrderEvent.Create(playerID, "Corrupted removed from card: recovered " .. cardName .. " in full", { playerID }, {}));
        return;
    end

    -- partial card logic
    local cardSettings = game.Settings.Cards[entry.CardID];
    local numPieces = (cardSettings ~= nil and cardSettings.NumPieces) or 1;
    local piecesAwarded = math.max(math.floor(percent * numPieces + 0.5), 1);

    local event = WL.GameOrderEvent.Create(playerID, "Corrupted removed from card: recovered " .. piecesAwarded .. "/" .. numPieces .. " pieces of " .. cardName, { playerID }, {});
    event.AddCardPiecesOpt = { [playerID] = { [entry.CardID] = piecesAwarded } };
    addNewOrder(event);
end

---@param game GameServerHook
---@param order GameOrder
---@param addNewOrder fun(order: GameOrder)
function HandleCorruptedPlayed(game, order, addNewOrder)
    if (order.ModData == "RecoverRandom" and Mod.Settings.RecoveryAllowRandom) then
        QueuePendingRecovery(order.PlayerID, "Random", nil);
    elseif (startsWith(order.ModData, "RecoverSelected_") and Mod.Settings.RecoveryAllowPlayerSelected) then
        local entryID = tonumber(string.sub(order.ModData, string.len("RecoverSelected_") + 1));
        QueuePendingRecovery(order.PlayerID, "Selected", entryID);
    end
end

function ProgressMaturedBuddingCorruptions(game, addNewOrder)
    local counters = (Mod.PrivateGameData or {}).BuddingCounters or {};
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

    local privateGameData = Mod.PrivateGameData;
    privateGameData.BuddingCounters = remaining;
    Mod.PrivateGameData = privateGameData;
end

function CorruptCardsForActiveCorruptions(game, addNewOrder)
    local perSource = Mod.Settings.CardsCorruptedPerTurnPerSource or 1;

    local activeCorruptions = Mod.PrivateGameData.ActiveCorruptions or {};
    local numCorruptionCardsByPlayer = {};
    for _, active in ipairs(activeCorruptions) do
        numCorruptionCardsByPlayer[active.PlayerID] = (numCorruptionCardsByPlayer[active.PlayerID] or 0) + 1;
    end

    for playerID, numCorruptionCards in pairs(numCorruptionCardsByPlayer) do
        local playerCards = game.ServerGame.LatestTurnStanding.Cards[playerID];

        if (playerCards ~= nil) then
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
                    -- do we need to consider mod cards having custom data on them.. somehow?
                    -- todo: review.

                    ---@type CorruptedPoolEntry
                    local poolEntry = { ID = GetNextCorruptedPoolEntryID(playerID), CardID = picked.Instance.CardID, IntField = intField };
                    table.insert(pool, poolEntry);

                    local corruptedInstance = WL.NoParameterCardInstance.Create(Mod.Settings.CorruptedCardID);
                    addNewOrder(WL.GameOrderReceiveCard.Create(playerID, { corruptedInstance }));
                end

                SetCorruptedPool(playerID, pool);
            end
        end
    end
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function ResolvePendingRecoveries(game, addNewOrder)
    local pending = (Mod.PrivateGameData or {}).PendingRecoveries or {};
    if (#pending == 0) then
        return;
    end

    for _, request in ipairs(pending) do
        if (request.Type == "Selected") then
            local entry = PopCorruptedPoolEntryByID(request.PlayerID, request.EntryID);
            if (entry ~= nil) then
                AwardCorruptedCardRecovery(game, request.PlayerID, entry, Mod.Settings.RecoveryPlayerSelectedPercent or 0, addNewOrder);
            end
        end
    end

    -- as we update the tracked data with each pop, this should allow random to pick from the non-player selected cases
    for _, request in ipairs(pending) do
        if (request.Type == "Random") then
            local entry = PopRandomCorruptedPoolEntry(request.PlayerID);
            if (entry ~= nil) then
                AwardCorruptedCardRecovery(game, request.PlayerID, entry, Mod.Settings.RecoveryRandomPercent or 0, addNewOrder);
            end
        end
    end

    local privateGameData = Mod.PrivateGameData;
    privateGameData.PendingRecoveries = nil;
    Mod.PrivateGameData = privateGameData;
end
