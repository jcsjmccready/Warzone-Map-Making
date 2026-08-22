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
        setMaxSize(400, 200);
        local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
        local buttonsHGroup = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
        TargetPlayerBtn = UI.CreateButton(buttonsHGroup)
            .SetText("Select Player")
            .SetOnClick(TargetPlayerClicked)
            .SetFlexibleWidth(0.3);

        InstructionLabel = UI.CreateLabel(vert).SetText("");

        PlayCardBtn = UI.CreateButton(buttonsHGroup)
            .SetText("Bribe")
            .SetInteractable(false)
            .SetColor(BUTTON_COLOURS.DarkGreen)
            .SetFlexibleWidth(0.7)
            .SetOnClick(function()
                if (TargetPlayerID == nil) then
                    InstructionLabel.SetText("You must select a player first").SetColor(ERROR_COLOUR);
                    return;
                end

                local message = "Bribed " .. TargetPlayerName .. "'s Spy for " .. Mod.Settings.BribeDuration .. " turn(s)";
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

function TargetPlayerClicked()
    local players = filter(Game.Game.Players, function(p)
        return p.State == WL.GamePlayerState.Playing and (p.ID ~= Game.Us.ID or Mod.Settings.AllowTargetingSelf);
    end);
    local options = map(players, function(p)
        local playerName = p.DisplayName(nil, false);
        return { text = playerName, selected = function() PlayerListItemClicked(p.ID, playerName); end };
    end);
    UI.PromptFromList("Select the player you'd like to bribe", options);
end

function PlayerListItemClicked(playerID, playerName)
    TargetPlayerID = playerID;
    TargetPlayerName = playerName;
    InstructionLabel.SetText("Selected player: " .. playerName).SetColor(TEXT_DEFAULT_COLOUR);
    PlayCardBtn.SetInteractable(true);
end
