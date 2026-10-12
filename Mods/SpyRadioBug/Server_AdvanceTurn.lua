require("Utilities");

---@class SpyBug # A single tracked Spy Radio Bug
---@field TerritoryId number # TerritoryId the bug is hidden on
---@field CreatorId number # PlayerID of whoever planted the bug
---@field OwnerId number # PlayerID of whoever currently owns that territory (ie. who's being spied on)
---@field Colour string # Hex colour string (from BUTTON_COLOURS), unique among this owner's other undiscovered bugs

--curated set of visually distinct colours, cycled per territory owner so a player with multiple undiscovered bugs
--on their territories can be told apart once bug-detection/radio-wave annotations are implemented
BUG_COLOUR_PALETTE = {
    "ElectricPurple", "DeepPink", "Aqua", "OrangeRed", "Goldenrod", "Cyan", "Lime", "RoyalBlue",
    "Orchid", "Fuchsia", "Tan", "TyrianPurple", "SeaGreen", "HotPink", "LightBlue",
};

--fallback colour for the "Bug Transmits" reminder shown to a bug's creator, used only if the bugged player's own
--in-game colour is somehow unavailable. Normally the reminder uses that player's colour instead (not the bug's
--own per-territory-owner colour, which is reserved for the territory owner's radio wave annotations)
BUG_TRANSMITS_FALLBACK_COLOUR = "Ivory";

--returns playerID's in-game colour as a 24-bit int, or the fallback colour if unavailable for some reason
function GetPlayerColourInt(game, playerID)
    local player = game.Game.Players[playerID];
    if (player ~= nil and player.Color ~= nil) then
        return player.Color.IntColor;
    end
    return GetColourIntegerFromHex(BUTTON_COLOURS[BUG_TRANSMITS_FALLBACK_COLOUR]);
end

---Server_AdvanceTurn_Start hook. Removes the Custom Vision FogMods granted last turn (Server_AdvanceTurn_End
---re-grants fresh ones for whichever bugs are still active, so vision only actually lasts while the bug does)
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Start(game, addNewOrder)
    RemoveExpiredCustomVisionFogMods(addNewOrder);
end

--removes any Custom Vision FogMods added last turn
function RemoveExpiredCustomVisionFogMods(addNewOrder)
    local privateGameData = Mod.PrivateGameData;
    local pendingIDs = privateGameData.PendingVisionFogModIDs;
    if (pendingIDs == nil or #pendingIDs == 0) then return; end;

    local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, "Spy Radio Bug vision expired", {}, {});
    event.RemoveFogModsOpt = pendingIDs;
    addNewOrder(event);

    privateGameData.PendingVisionFogModIDs = nil;
    Mod.PrivateGameData = privateGameData;
end

---Server_AdvanceTurn_Order
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl)
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
    if (order.proxyType ~= 'GameOrderPlayCardCustom') then
        return;
    end

    if (startsWith(order.ModData, "CreateBug_")) then
        local targetTerritoryID = tonumber(string.sub(order.ModData, string.len("CreateBug_") + 1));
        HandleCreateBug(game, order, targetTerritoryID);
    elseif (startsWith(order.ModData, "CreateBugForPlayer_")) then
        local targetPlayerID = tonumber(string.sub(order.ModData, string.len("CreateBugForPlayer_") + 1));

        --the client can't be trusted to have picked a legal target, and territory ownership may have changed
        --since the card was played, so re-resolve which of the target player's territories to use now
        local candidateTerritoryIDs = GetPlayerTerritoryIDs(game.ServerGame.LatestTurnStanding.Territories, targetPlayerID);
        if (#candidateTerritoryIDs == 0) then
            return; -- target player has no territories left (eg. eliminated), nothing to bug
        end

        local targetTerritoryID = randomFromArray(candidateTerritoryIDs);
        HandleCreateBug(game, order, targetTerritoryID);
    elseif (startsWith(order.ModData, "SearchForBug_")) then
        local targetTerritoryID = tonumber(string.sub(order.ModData, string.len("SearchForBug_") + 1));
        HandleSearchForBug(game, order, targetTerritoryID, addNewOrder);
    end
end

--creates and tracks a new bug on targetTerritoryID, provided it's still a legal target (owned by an enemy, not
--the creator and not neutral) by the time the order resolves
---@param game GameServerHook
---@param order GameOrder
---@param targetTerritoryID TerritoryID
function HandleCreateBug(game, order, targetTerritoryID)
    local territory = game.ServerGame.LatestTurnStanding.Territories[targetTerritoryID];
    if (territory == nil) then return; end

    local ownerID = territory.OwnerPlayerID;
    if (ownerID == order.PlayerID or ownerID == WL.PlayerID.Neutral) then
        -- no longer (or never was) a legal enemy target, eg. the creator captured it themselves since ordering
        return;
    end

    local privateGameData = Mod.PrivateGameData;
    local bugs = privateGameData.Bugs or {};

    ---@type SpyBug
    local bug = {
        TerritoryId = targetTerritoryID,
        CreatorId = order.PlayerID,
        OwnerId = ownerID,
        Colour = GetBugColourForOwner(bugs, ownerID, nil),
    };
    table.insert(bugs, bug);

    privateGameData.Bugs = bugs;
    Mod.PrivateGameData = privateGameData;
end

--resolves a Temporary Sweeper card played on targetTerritoryID: searches it and everything within SweeperRadius
--of it for any of the searching player's own hidden bugs, and destroys whatever it finds. A player can only ever
--be given sweeper cards for bugs on their own territories, but ownership (and so which bugs are "theirs") can
--have changed since the card was played, so everything is re-checked against the current standing here.
---@param game GameServerHook
---@param order GameOrder
---@param targetTerritoryID TerritoryID
---@param addNewOrder fun(order: GameOrder)
function HandleSearchForBug(game, order, targetTerritoryID, addNewOrder)
    local territory = game.ServerGame.LatestTurnStanding.Territories[targetTerritoryID];
    if (territory == nil or territory.OwnerPlayerID ~= order.PlayerID) then
        -- the client can't be trusted to only search a territory they still control
        return;
    end

    local privateGameData = Mod.PrivateGameData;
    local bugs = privateGameData.Bugs or {};
    local distances = GetTerritoryDistances(game, targetTerritoryID, Mod.Settings.SweeperRadius or 0);

    local foundBugs = {};
    local remainingBugs = {};
    for _, bug in ipairs(bugs) do
        if (bug.OwnerId == order.PlayerID and distances[bug.TerritoryId] ~= nil) then
            table.insert(foundBugs, bug);
        else
            table.insert(remainingBugs, bug);
        end
    end

    privateGameData.Bugs = remainingBugs;
    Mod.PrivateGameData = privateGameData;

    local territoryName = game.Map.Territories[targetTerritoryID].Name;

    if (#foundBugs == 0) then
        local nothingFoundEvent = WL.GameOrderEvent.Create(order.PlayerID, "Your sweep of " .. territoryName .. " found nothing", { order.PlayerID }, {});
        nothingFoundEvent.TerritoryAnnotationsOpt = { [targetTerritoryID] = WL.TerritoryAnnotation.Create("Swept - Nothing Found", 8, GetColourIntegerFromHex(BUTTON_COLOURS.DarkGray)) };
        addNewOrder(nothingFoundEvent);
        return;
    end

    for _, bug in ipairs(foundBugs) do
        local bugColour = GetColourIntegerFromHex(bug.Colour);

        local foundEvent = WL.GameOrderEvent.Create(order.PlayerID, "Your sweep of " .. territoryName .. " found and destroyed a Spy Radio Bug!", { order.PlayerID }, {});
        foundEvent.TerritoryAnnotationsOpt = { [bug.TerritoryId] = WL.TerritoryAnnotation.Create("Bug Found!", 8, bugColour) };
        addNewOrder(foundEvent);

        local destroyedEvent = WL.GameOrderEvent.Create(bug.CreatorId, "Your Spy Radio Bug on " .. game.Map.Territories[bug.TerritoryId].Name .. " was discovered and destroyed", { bug.CreatorId }, {});
        destroyedEvent.TerritoryAnnotationsOpt = { [bug.TerritoryId] = WL.TerritoryAnnotation.Create("Bug Destroyed", 8, bugColour) };
        addNewOrder(destroyedEvent);
    end
end

--picks a colour from BUG_COLOUR_PALETTE that isn't already used by another bug tracked against ownerId (so bugs
--on the same player's territories stay visually distinct; colours can repeat across different owners). excludeBug
--is left out of the "already used" check, since it's normally the bug we're (re)assigning a colour to. Falls
--back to reusing the first palette colour once every one is already in use for that owner.
function GetBugColourForOwner(bugs, ownerId, excludeBug)
    local usedColours = {};
    for _, otherBug in ipairs(bugs) do
        if (otherBug ~= excludeBug and otherBug.OwnerId == ownerId) then
            usedColours[otherBug.Colour] = true;
        end
    end

    for _, colourName in ipairs(BUG_COLOUR_PALETTE) do
        local colour = BUTTON_COLOURS[colourName];
        if (not usedColours[colour]) then
            return colour;
        end
    end

    return BUTTON_COLOURS[BUG_COLOUR_PALETTE[1]]; -- every colour already in use for this owner, just reuse one
end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_End(game, addNewOrder)
    UpdateBugOwnership(game, addNewOrder);

    GrantBugOwnerVisibility(game, addNewOrder);
    GrantBugCreatorVisionOfTargets(game, addNewOrder);
    CreateRadioWaveAnnotations(game, addNewOrder);

    DiscardUnusedTempSweeperCards(game, addNewOrder);
    GiveTempSweeperCards(game, addNewOrder);
end

--reminds each bug's creator where their bug is (they may well have several planted across different enemies by
--now), by annotating the bugged territory with "Bug Transmits" in the bugged player's own in-game colour (eg. a
--bug on a pink player gets a pink annotation), visible only to the creator. This deliberately does not use the
--bug's own per-territory-owner colour, which is reserved for the territory owner's side of things (telling their
--bugs apart from each other via the radio wave annotations)
function GrantBugOwnerVisibility(game, addNewOrder)
    local privateGameData = Mod.PrivateGameData;
    local bugs = privateGameData.Bugs or {};

    for _, bug in ipairs(bugs) do
        if (bug.OwnerId ~= WL.PlayerID.Neutral) then
            local event = WL.GameOrderEvent.Create(bug.CreatorId, "Bug Transmits", { bug.CreatorId }, {});
            event.TerritoryAnnotationsOpt = { [bug.TerritoryId] = WL.TerritoryAnnotation.Create("Bug Transmits", 8, GetPlayerColourInt(game, bug.OwnerId)) };
            addNewOrder(event);
        end
    end
end

--dispatches to whichever visibility method is configured (Autoplay Spy Card or Custom Vision), granting the
--creator of each active bug vision of who they're spying on
function GrantBugCreatorVisionOfTargets(game, addNewOrder)
    if (Mod.Settings.VisibilityGainedAutoplaySpyCard) then
        AutoplaySpyCardsForBugs(game, addNewOrder);
    elseif (Mod.Settings.VisibilityGainedCustomVision) then
        GrantCustomVisionForBugs(game, addNewOrder);
    end
end

--gives each bug's creator a Spy card and immediately plays it against the territory owner they're spying on. A
--creator with several bugs on the same enemy only gets/plays one Spy card for that enemy, not one per bug
function AutoplaySpyCardsForBugs(game, addNewOrder)
    local privateGameData = Mod.PrivateGameData;
    local bugs = privateGameData.Bugs or {};
    local alreadySpiedPairs = {};

    for _, bug in ipairs(bugs) do
        if (bug.OwnerId ~= WL.PlayerID.Neutral) then
            local pairKey = bug.CreatorId .. "_" .. bug.OwnerId;
            if (not alreadySpiedPairs[pairKey]) then
                alreadySpiedPairs[pairKey] = true;

                local instance = WL.NoParameterCardInstance.Create(WL.CardID.Spy);
                addNewOrder(WL.GameOrderReceiveCard.Create(bug.CreatorId, { instance }));
                addNewOrder(WL.GameOrderPlayCardSpy.Create(instance.ID, bug.CreatorId, bug.OwnerId));
            end
        end
    end
end

--manually grants each bug's creator vision of the bugged territory and any of the bugged player's other
--territories within CustomVisionRadius of it (never other players' or neutral territories that happen to fall
--within that radius), restricted to just the creator, via a high priority FogMod. Removed again by
--RemoveExpiredCustomVisionFogMods at the start of next turn, and re-granted here for whatever's still active -
--so vision only lasts while the bug remains undiscovered and the territory belongs to a real player
function GrantCustomVisionForBugs(game, addNewOrder)
    local privateGameData = Mod.PrivateGameData;
    local bugs = privateGameData.Bugs or {};
    local pendingFogModIDs = {};
    local allTerritories = game.ServerGame.LatestTurnStanding.Territories;

    for _, bug in ipairs(bugs) do
        if (bug.OwnerId ~= WL.PlayerID.Neutral) then
            local nearbyTerritoryIDs = GetTerritoriesWithinDistance(game, bug.TerritoryId, Mod.Settings.CustomVisionRadius or 0);
            local territories = filter(nearbyTerritoryIDs, function(territoryID)
                local territory = allTerritories[territoryID];
                return territory ~= nil and territory.OwnerPlayerID == bug.OwnerId;
            end);

            local fogMod = WL.FogMod.Create("Spy Radio Bug - custom vision", WL.StandingFogLevel.Visible, 9000, territories, { bug.CreatorId });

            local event = WL.GameOrderEvent.Create(bug.CreatorId, "Spy Radio Bug vision", { bug.CreatorId }, {});
            event.FogModsOpt = { fogMod };
            addNewOrder(event);

            table.insert(pendingFogModIDs, fogMod.ID);
        end
    end

    privateGameData.PendingVisionFogModIDs = pendingFogModIDs;
    Mod.PrivateGameData = privateGameData;
end

--refreshes every tracked bug's OwnerId to match its territory's current owner. If the territory has gone
--neutral, the bug is marked as belonging to Neutral so other logic knows to leave it alone until someone
--claims the territory again. If a bug was marked as belonging to Neutral and the territory has since been
--claimed by a real player, it resumes belonging to whoever claimed it. Whenever a bug changes hands to a real
--player, its colour is re-checked against that player's other bugs and reassigned if it now collides.
--If the new owner is the bug's own creator (they recaptured the territory they'd hidden it on), the bug is
--removed entirely instead - there's no point spying on your own territory - and they're compensated with
--RecaptureCardPieces pieces towards a future Spy Radio Bug Card.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function UpdateBugOwnership(game, addNewOrder)
    local privateGameData = Mod.PrivateGameData;
    local bugs = privateGameData.Bugs or {};
    local remainingBugs = {};

    for _, bug in ipairs(bugs) do
        local territory = game.ServerGame.LatestTurnStanding.Territories[bug.TerritoryId];
        if (territory == nil) then
            table.insert(remainingBugs, bug);
        else
            local newOwnerId = territory.OwnerPlayerID;
            if (newOwnerId == bug.CreatorId) then
                AwardRecaptureCardPieces(bug.CreatorId, addNewOrder);
                -- bug is not added back to remainingBugs, so it's removed
            else
                if (newOwnerId ~= bug.OwnerId) then
                    bug.OwnerId = newOwnerId;
                    if (newOwnerId ~= WL.PlayerID.Neutral) then
                        bug.Colour = GetBugColourForOwner(bugs, newOwnerId, bug);
                    end
                end
                table.insert(remainingBugs, bug);
            end
        end
    end

    privateGameData.Bugs = remainingBugs;
    Mod.PrivateGameData = privateGameData;
end

--awards RecaptureCardPieces pieces of the Spy Radio Bug Card to playerID, since a bug they'd planted was just
--removed because they recaptured its territory themselves
function AwardRecaptureCardPieces(playerID, addNewOrder)
    local pieces = Mod.Settings.RecaptureCardPieces or 0;
    if (pieces <= 0) then return; end

    local event = WL.GameOrderEvent.Create(playerID, "Recovered " .. pieces .. " Spy Radio Bug card piece(s) from your reclaimed bug", { playerID }, {});
    event.AddCardPiecesOpt = { [playerID] = { [Mod.Settings.BugCardID] = pieces } };
    addNewOrder(event);
end

--lets each bugged player know something's nearby without giving away exactly where: picks a random territory
--they own at RadioDetectionRadius distance from the bug, falling back to progressively closer distances if none
--of their territories are that far out, down to (and guaranteed to include, as a last resort) the bugged
--territory itself. Annotates that territory with "Radio Wave Detected" in the bug's colour, visible only to them.
function CreateRadioWaveAnnotations(game, addNewOrder)
    local privateGameData = Mod.PrivateGameData;
    local bugs = privateGameData.Bugs or {};
    local territories = game.ServerGame.LatestTurnStanding.Territories;

    for _, bug in ipairs(bugs) do
        if (bug.OwnerId ~= WL.PlayerID.Neutral) then
            local annotationTerritoryID = FindRadioDetectionTerritory(game, bug, territories);

            local event = WL.GameOrderEvent.Create(bug.OwnerId, "A radio wave was detected", { bug.OwnerId }, {});
            event.TerritoryAnnotationsOpt = { [annotationTerritoryID] = WL.TerritoryAnnotation.Create("Radio Wave Detected", 8, GetColourIntegerFromHex(bug.Colour)) };
            addNewOrder(event);
        end
    end
end

--finds a territory to place bug's radio wave annotation on: a random one of bug.OwnerId's territories at exactly
--RadioDetectionRadius distance from the bug, or progressively closer distances if none exist that far out. Since
--the bugged territory itself is at distance 0 and always belongs to bug.OwnerId, this always finds something.
function FindRadioDetectionTerritory(game, bug, territories)
    local distances = GetTerritoryDistances(game, bug.TerritoryId, Mod.Settings.RadioDetectionRadius or 0);

    for distance = (Mod.Settings.RadioDetectionRadius or 0), 0, -1 do
        local candidates = {};
        for territoryID, territoryDistance in pairs(distances) do
            if (territoryDistance == distance) then
                local territory = territories[territoryID];
                if (territory ~= nil and territory.OwnerPlayerID == bug.OwnerId) then
                    table.insert(candidates, territoryID);
                end
            end
        end
        if (#candidates > 0) then
            return randomFromArray(candidates);
        end
    end

    return bug.TerritoryId; -- safety net; the distance-0 pass above should always have already returned this
end

--discards any Temporary Sweeper cards still sitting unused in a player's hand, so they don't carry over into
--the next turn before this turn's bug ownership hands out a fresh batch
function DiscardUnusedTempSweeperCards(game, addNewOrder)
    for playerID, playerCards in pairs(game.ServerGame.LatestTurnStanding.Cards) do
        for cardInstanceID, cardInstance in pairs(playerCards.WholeCards) do
            if (cardInstance.CardID == Mod.Settings.TempSweeperCardID) then
                addNewOrder(WL.GameOrderDiscard.Create(playerID, cardInstanceID));
            end
        end
    end
end

--gives every player one Temporary Sweeper card per bug currently sitting on one of their territories. Bugs
--currently marked as belonging to Neutral are skipped - nobody to give a sweeper card to until it's claimed
function GiveTempSweeperCards(game, addNewOrder)
    local privateGameData = Mod.PrivateGameData;
    local bugs = privateGameData.Bugs or {};

    for _, bug in ipairs(bugs) do
        if (bug.OwnerId ~= WL.PlayerID.Neutral) then
            local instance = WL.NoParameterCardInstance.Create(Mod.Settings.TempSweeperCardID);
            addNewOrder(WL.GameOrderReceiveCard.Create(bug.OwnerId, { instance }));
        end
    end
end
