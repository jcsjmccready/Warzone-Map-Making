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
    end
end

--target selection dialog for the Corrupt Hand card: pick any other player to secretly start corrupting
function PresentCorruptHandUI(game, playCard, closeCardsDialog)
    Game = game;
    TargetPlayerID = nil;
    TargetPlayerName = nil;
    playerListContent = nil;

    if (Close ~= nil) then
        Close();
    end

    closeCardsDialog();

    game.CreateDialog(function(rootParent, setMaxSize, setScrollable, game, close)
        Close = close;
        setMaxSize(400, 300);
        setScrollable(false, true);

        local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
        UI.CreateLabel(vert).SetText("Select an enemy player to secretly begin corrupting their hand.");

        InstructionLabel = UI.CreateLabel(vert).SetText("");
        playerListHeading = UI.CreateVerticalLayoutGroup(vert).SetFlexibleWidth(1);
        Create_PlayerList_UI(playerListHeading);

        PlayCardBtn = UI.CreateButton(vert)
            .SetText("Corrupt")
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

function Create_PlayerList_UI(rootParent)
    if (playerListContent ~= nil and not UI.IsDestroyed(playerListContent)) then
        UI.Destroy(playerListContent);
    end
    playerListContent = UI.CreateVerticalLayoutGroup(rootParent);

    local allowSelf = true; -- REMOVE THIS BEFORE PRODUCTION
    for playerID, player in pairs(Game.Game.PlayingPlayers) do
        if (allowSelf or playerID ~= Game.Us.ID) then
            local playerName = player.DisplayName(nil, false);
            UI.CreateButton(playerListContent)
                .SetText(playerName)
                .SetColor(player.Color.HtmlColor)
                .SetOnClick(function() PlayerListItemClicked(playerID, playerName); end);
        end
    end
end

function PlayerListItemClicked(playerID, playerName)
    TargetPlayerID = playerID;
    TargetPlayerName = playerName;
    InstructionLabel.SetText("Selected player: " .. playerName).SetColor(TEXT_DEFAULT_COLOUR);
    PlayCardBtn.SetInteractable(true);
end

--simple confirm dialog for playing a Corrupted card, which has no target to pick - resolving it just recovers
--something from the player's own corrupted pool
function PresentCorruptedUI(game, playCard, closeCardsDialog)
    if (Close ~= nil) then
        Close();
    end

    closeCardsDialog();

    game.CreateDialog(function(rootParent, setMaxSize, setScrollable, game, close)
        Close = close;
        setMaxSize(400, 160);
        setScrollable(false, true);

        local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
        UI.CreateLabel(vert).SetText("Play this Corrupted card to recover what was lost.");

        UI.CreateButton(vert)
            .SetText("Play")
            .SetColor(BUTTON_COLOURS.DarkGreen)
            .SetFlexibleWidth(1)
            .SetOnClick(function()
                if (playCard("Corrupted card played", "RecoverCorrupted", WL.TurnPhase.SpyingCards, {}, nil)) then
                    close();
                end
            end);
    end);
end
