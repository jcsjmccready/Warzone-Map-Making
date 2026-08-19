require('Utilities')

---Client_PresentPlayCardUI
---@param game GameClientHook
---@param cardInstance CardInstance # Read-only data about the card that the player is attempting to play
---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM) # Function that when invoked, will make the player play the card
---@param closeCardsDialog fun() # Function that when invoked will close this cards dialog
function Client_PresentPlayCardUI(game, cardInstance, playCard, closeCardsDialog)
    if (cardInstance.CardID == Mod.Settings.CorruptHandCardID) then
        PresentCorruptHandUI(game, playCard, closeCardsDialog);
    elseif (cardInstance.CardID == Mod.Settings.CorruptedCardID) then
        PresentCorruptedUI(game, playCard, closeCardsDialog);
    elseif (cardInstance.CardID == Mod.Settings.CorruptionCardID) then
        PresentCorruptionUI(game, cardInstance, closeCardsDialog);
    elseif (cardInstance.CardID == Mod.Settings.BuddingCorruptionCardID) then
        PresentCorruptionUI(game, cardInstance, closeCardsDialog);
    end
end

function PresentCorruptionUI(game, cardInstance, closeCardsDialog)
    closeCardsDialog();

    local orders = game.Orders;
    table.insert(orders, WL.GameOrderDiscard.Create(game.Us.ID, cardInstance.ID));
    game.Orders = orders;
end

function PresentCorruptHandUI(game, playCard, closeCardsDialog)
    Game = game;
    TargetPlayerID = nil;
    TargetPlayerName = nil;

    if (Close ~= nil) then
        Close();
    end

    closeCardsDialog();

    game.CreateDialog(function(rootParent, setMaxSize, setScrollable, game, close)
        Close = close;
        setMaxSize(400, 200);
        setScrollable(false, true);

        local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

        SelectPlayerBtn = UI.CreateButton(vert)
            .SetText("Select Player")
            .SetOnClick(SelectPlayerClicked)
            .SetFlexibleWidth(1);

        InstructionLabel = UI.CreateLabel(vert).SetText("");

        PlayCardBtn = UI.CreateButton(vert)
            .SetText("Corrupt Hand")
            .SetInteractable(false)
            .SetColor(BUTTON_COLOURS.DarkGreen)
            .SetFlexibleWidth(1)
            .SetOnClick(function()
                if (TargetPlayerID == nil) then
                    InstructionLabel.SetText("You must select a player first").SetColor(ERROR_COLOUR);
                    return;
                end

                if (playCard("Corrupt Hand played", "Corrupt_" .. TargetPlayerID, WL.TurnPhase.SpyingCards, {}, nil)) then
                    close();
                end
            end);
    end);
end

function SelectPlayerClicked()
    local options = {};
    local TESTING_MODE = true;
    for playerID, player in pairs(Game.Game.PlayingPlayers) do
        if (TESTING_MODE or playerID ~= Game.Us.ID) then
            local playerName = player.DisplayName(nil, false);
            table.insert(options, { text = playerName, selected = function() PlayerListItemClicked(playerID, playerName); end });
        end
    end
    UI.PromptFromList("Choose a player to corrupt", options);
end

function PlayerListItemClicked(playerID, playerName)
    TargetPlayerID = playerID;
    TargetPlayerName = playerName;
    SelectPlayerBtn.SetText("Selected player: " .. playerName);
    InstructionLabel.SetText("");
    PlayCardBtn.SetInteractable(true);
end

function PresentCorruptedUI(game, playCard, closeCardsDialog)
    SelectedPoolIndex = nil;
    SelectedPoolLabel = nil;

    if (Close ~= nil) then
        Close();
    end

    closeCardsDialog();

    game.CreateDialog(function(rootParent, setMaxSize, setScrollable, game, close)
        Close = close;
        setMaxSize(420, 260);
        setScrollable(false, true);

        local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
        UI.CreateLabel(vert).SetText("Play this Corrupted card to recover something from your corrupted pool.");

        if (Mod.Settings.RecoveryAllowRandom) then
            local randomPercent = Mod.Settings.RecoveryRandomPercent or 0;
            local randomText = "Recover A Random Card";
            if (randomPercent < 1) then
                randomText = randomText .. " (" .. (randomPercent * 100) .. "% of pieces)";
            end

            UI.CreateButton(vert)
                .SetText(randomText)
                .SetColor(BUTTON_COLOURS.DarkGreen)
                .SetFlexibleWidth(1)
                .SetOnClick(function()
                    if (playCard("Corrupted card played", "RecoverRandom", WL.TurnPhase.SpyingCards, {}, nil)) then
                        close();
                    end
                end);
        end

        if (Mod.Settings.RecoveryAllowPlayerSelected) then
            SelectPoolCardBtn = UI.CreateButton(vert)
                .SetText("Select A Card To Recover")
                .SetOnClick(function() SelectPoolCardClicked(game); end)
                .SetFlexibleWidth(1);

            PoolInstructionLabel = UI.CreateLabel(vert).SetText("");

            RecoverSelectedBtn = UI.CreateButton(vert)
                .SetText("Recover Selected Card")
                .SetInteractable(false)
                .SetColor(BUTTON_COLOURS.DarkGreen)
                .SetFlexibleWidth(1)
                .SetOnClick(function()
                    if (SelectedPoolIndex == nil) then
                        PoolInstructionLabel.SetText("You must select a card first").SetColor(ERROR_COLOUR);
                        return;
                    end

                    if (playCard("Corrupted card played", "RecoverSelected_" .. SelectedPoolIndex, WL.TurnPhase.SpyingCards, {}, nil)) then
                        close();
                    end
                end);
        end
    end);
end

--pops up the same "Select From List" mechanic used to pick a Corrupt Hand target, listing the player's own
--corrupted pool by card name (read from Mod.PlayerGameData, which the engine already scopes to just this player)
function SelectPoolCardClicked(game)
    local percent = Mod.Settings.RecoveryPlayerSelectedPercent or 0;
    local pool = Mod.PlayerGameData.CorruptedPool or {};

    local options = {};
    for index, entry in ipairs(pool) do
        local label = GetCardDisplayName(game, entry.CardID);
        if (percent < 1) then
            local pieces, numPieces = GetPiecesForRecoveryPercent(game, entry.CardID, percent);
            label = label .. " (" .. pieces .. "/" .. numPieces .. " pieces)";
        end
        table.insert(options, { text = label, selected = function() PoolCardSelected(index, label); end });
    end
    UI.PromptFromList("Choose a card to recover", options);
end

function PoolCardSelected(index, label)
    SelectedPoolIndex = index;
    SelectedPoolLabel = label;
    SelectPoolCardBtn.SetText("Selected: " .. label);
    PoolInstructionLabel.SetText("");
    RecoverSelectedBtn.SetInteractable(true);
end
