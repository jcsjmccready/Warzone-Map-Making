require('Utilities')

---Client_PresentPlayCardUI
---@param game GameClientHook
---@param cardInstance CardInstance # Read-only data about the card that the player is attempting to play
---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM) # Function that when invoked, will make the player play the card
---@param closeCardsDialog fun() # Function that when invoked will close this cards dialog
function Client_PresentPlayCardUI(game, cardInstance, playCard, closeCardsDialog)
    if (cardInstance.CardID ~= Mod.Settings.BribedSpyCardID) then
        return;
    end

    Game = game;

    --If this dialog is already open, close the previous one.
    if (Close ~= nil) then
        Close();
    end

    closeCardsDialog();

    TargetPlayerID = nil;
    TargetPlayerName = nil;

    game.CreateDialog(function(rootParent, setMaxSize, setScrollable, game, close)
        Close = close;
        setMaxSize(400, 320);
        setScrollable(false, true);
        local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

        UI.CreateLabel(vert).SetText("Select a player to bribe. Everyone will be given a Spy card to play against them, and they'll gain increased income while the bribe lasts.");

        InstructionLabel = UI.CreateLabel(vert).SetText("");

        playerListHeading = UI.CreateVerticalLayoutGroup(vert).SetFlexibleWidth(1);
        Create_PlayerList_UI(playerListHeading);

        PlayCardBtn = UI.CreateButton(vert)
            .SetText("Bribe")
            .SetInteractable(false)
            .SetColor(BUTTON_COLOURS.DarkGreen)
            .SetOnClick(function()
                if (TargetPlayerID == nil) then
                    InstructionLabel.SetText("You must select a player first").SetColor(ERROR_COLOUR);
                    return;
                end

                local message = "Bribe " .. TargetPlayerName;
                local modData = "BribeSpy_" .. TargetPlayerID;

                local jumpTerritoryID = first(GetPlayerTerritoryIDs(Game.LatestStanding.Territories, TargetPlayerID));
                if (jumpTerritoryID == nil) then
                    jumpTerritoryID = first(GetPlayerTerritoryIDs(Game.LatestStanding.Territories, Game.Us.ID));
                end

                local jumpToSpot;
                if (jumpTerritoryID ~= nil) then
                    local td = game.Map.Territories[jumpTerritoryID];
                    jumpToSpot = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
                end

                if (playCard(message, modData, WL.TurnPhase.SpyingCards, {}, jumpToSpot)) then
                    close();
                end
            end);
    end);
end

function Create_PlayerList_UI(rootParent)
    for playerID, player in pairs(Game.Game.PlayingPlayers) do
        if (playerID ~= Game.Us.ID or Mod.Settings.AllowTargetingSelf) then
            local playerName = player.DisplayName(nil, false);
            UI.CreateButton(rootParent)
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
