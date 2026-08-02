require('Utilities')

---Client_PresentPlayCardUI
---@param game GameClientHook
---@param cardInstance CardInstance # Read-only data about the card that the player is attempting to play
---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM) # Function that when invoked, will make the player play the card
---@param closeCardsDialog fun() # Function that when invoked will close this cards dialog
function Client_PresentPlayCardUI(game, cardInstance, playCard, closeCardsDialog)
    Game = game;

    --the Bug card can target either a specific enemy territory, or an enemy player (in which case one of their
    --territories is chosen for you when the order resolves). The Temporary Sweeper card only ever targets one of
    --your own territories (to search it for a hidden bug), so it has no "select player" option.
    cardAction = "ERROR";
    modDataPrefix = "ERROR";
    requiresEnemyTerritory = false;
    allowsPlayerSelection = false;
    if(cardInstance.CardID == Mod.Settings.BugCardID) then
        cardAction = "Bug";
        modDataPrefix = "CreateBug_";
        requiresEnemyTerritory = true;
        allowsPlayerSelection = true;
    elseif(cardInstance.CardID == Mod.Settings.TempSweeperCardID) then
        cardAction = "Sweep";
        modDataPrefix = "SearchForBug_";
        requiresEnemyTerritory = false;
    end

    --If this dialog is already open, close the previous one. This prevents two copies of it from being open at once which can cause errors due to only saving one instance of TargetTerritoryBtn
    if (Close ~= nil) then
        Close();
    end

    closeCardsDialog();

    --reset selection state each time the dialog is (re)opened
    TargetTerritoryID = nil;
    TargetTerritoryName = nil;
    TargetPlayerID = nil;
    TargetPlayerName = nil;
    playerListContent = nil;

    game.CreateDialog(function(rootParent, setMaxSize, setScrollable, game, close)
        Close = close;
        setMaxSize(400, allowsPlayerSelection and 320 or 200);
        setScrollable(false, true);
        local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1); --set flexible width so things don't jump around while we change InstructionLabel
        local buttonsHGroup = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
        TargetTerritoryBtn = UI.CreateButton(buttonsHGroup)
            .SetText("Select Territory")
            .SetOnClick(TargetTerritoryClicked)
            .SetFlexibleWidth(allowsPlayerSelection and 0.3 or 0.3);

        if (allowsPlayerSelection) then
            SelectPlayerBtn = UI.CreateButton(buttonsHGroup)
                .SetText("Select Player")
                .SetOnClick(SelectPlayerClicked)
                .SetFlexibleWidth(0.3);
        end

        TargetTerritoryInstructionLabel = UI.CreateLabel(vert).SetText("");

        playerListHeading = UI.CreateVerticalLayoutGroup(vert).SetFlexibleWidth(1);

        PlayCardBtn = UI.CreateButton(buttonsHGroup)
            .SetText("Play " .. cardAction)
            .SetInteractable(false)
            .SetColor(BUTTON_COLOURS.DarkGreen)
            .SetFlexibleWidth(allowsPlayerSelection and 0.4 or 0.7)
            .SetOnClick(function()
                if (TargetTerritoryID == nil and TargetPlayerID == nil) then
                    TargetTerritoryInstructionLabel.SetText("You must select a territory" .. (allowsPlayerSelection and " or a player" or "") .. " first").SetColor(ERROR_COLOUR);
                    TargetTerritoryBtn.SetInteractable(true);
                    if (allowsPlayerSelection) then SelectPlayerBtn.SetInteractable(true); end

                    return;
                end

                local message;
                local modData;
                local jumpTerritoryID = TargetTerritoryID;

                if (TargetTerritoryID ~= nil) then
                    message = cardAction .. " " .. TargetTerritoryName;
                    modData = modDataPrefix .. TargetTerritoryID;
                else
                    message = cardAction .. " a territory belonging to " .. TargetPlayerName;
                    modData = "CreateBugForPlayer_" .. TargetPlayerID;
                    --no specific territory chosen yet (the mod picks one when the order resolves), so just jump
                    --the camera to any territory of theirs we can currently see
                    jumpTerritoryID = first(GetPlayerTerritoryIDs(Game.LatestStanding.Territories, TargetPlayerID));
                    if (jumpTerritoryID == nil) then
                        -- everything they own is fogged to us right now; jump to one of our own territories instead
                        jumpTerritoryID = first(GetPlayerTerritoryIDs(Game.LatestStanding.Territories, Game.Us.ID));
                    end
                end

                local td = game.Map.Territories[jumpTerritoryID];
                local jumpToSpot = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);

                if (playCard(message, modData, WL.TurnPhase.SpyingCards, {}, jumpToSpot)) then
                    close();
                end
            end);
    end);
end

function TargetTerritoryClicked()
	UI.InterceptNextTerritoryClick(TerritoryClicked);
	TargetTerritoryInstructionLabel.SetText("Please click on the territory you wish to " .. cardAction .. ".").SetColor(TEXT_DEFAULT_COLOUR);
	TargetTerritoryBtn.SetInteractable(false);
    if (allowsPlayerSelection) then SelectPlayerBtn.SetInteractable(false); end
    PlayCardBtn.SetInteractable(false);

    --picking a territory instead invalidates whatever player was selected
    TargetPlayerID = nil;
    TargetPlayerName = nil;
    Destroy_PlayerList_UI();
end

function TerritoryClicked(terrDetails)
	if UI.IsDestroyed(TargetTerritoryBtn) then
		-- Dialog was destroyed, so we don't need to intercept the click anymore
		return WL.CancelClickIntercept;
	end
	TargetTerritoryBtn.SetInteractable(true);
    if (allowsPlayerSelection) then SelectPlayerBtn.SetInteractable(true); end


	if (terrDetails == nil) then
		--The click request was cancelled.   Return to our default state.
		TargetTerritoryInstructionLabel.SetText("");
        TargetTerritoryID = nil;
        TargetTerritoryName = nil;
        PlayCardBtn.SetInteractable(false);
        Game.HighlightTerritories({});
        return;
    end

    local terr = Game.LatestStanding.Territories[terrDetails.ID];
    local isValidSelection = requiresEnemyTerritory
        and (terr.OwnerPlayerID ~= Game.Us.ID and terr.OwnerPlayerID ~= WL.PlayerID.Neutral)
        or (not requiresEnemyTerritory and terr.OwnerPlayerID == Game.Us.ID);

    if (not isValidSelection) then
        local invalidMessage = requiresEnemyTerritory and "You may only select a territory controlled by an enemy" or "You may only select territories you control";
        TargetTerritoryInstructionLabel.SetText(invalidMessage).SetColor(ERROR_COLOUR);

        TargetTerritoryID = nil;
        TargetTerritoryName = nil;
        PlayCardBtn.SetInteractable(false);
        Game.HighlightTerritories({});
    else
		--Territory was clicked, remember its ID
		TargetTerritoryInstructionLabel.SetText("Selected territory: " .. terrDetails.Name).SetColor(TEXT_DEFAULT_COLOUR);
		TargetTerritoryID = terrDetails.ID;
        TargetTerritoryName = terrDetails.Name;
        PlayCardBtn.SetInteractable(true);

        --if we're placing a bug on a specific territory with Custom Vision enabled, show the player exactly
        --which territories the bug will end up giving them vision of
        if (cardAction == "Bug" and Mod.Settings.VisibilityGainedCustomVision) then
            local visibleTerritories = GetTerritoriesWithinDistance(Game, TargetTerritoryID, Mod.Settings.CustomVisionRadius);
            Game.HighlightTerritories(visibleTerritories);
        else
            Game.HighlightTerritories({});
        end
	end
end

function SelectPlayerClicked()
    TargetTerritoryInstructionLabel.SetText("Please select a player below.").SetColor(TEXT_DEFAULT_COLOUR);
    TargetTerritoryBtn.SetInteractable(false);
    SelectPlayerBtn.SetInteractable(false);
    PlayCardBtn.SetInteractable(false);

    --picking a player instead invalidates whatever territory was selected; nothing to highlight since we don't
    --know which territory the bug will end up on yet
    TargetTerritoryID = nil;
    TargetTerritoryName = nil;
    Game.HighlightTerritories({});

    Create_PlayerList_UI(playerListHeading);
end

function Create_PlayerList_UI(rootParent)
    Destroy_PlayerList_UI();
    playerListContent = UI.CreateVerticalLayoutGroup(rootParent);

    for playerID, player in pairs(Game.Game.PlayingPlayers) do
        if (playerID ~= Game.Us.ID) then
            local playerName = player.DisplayName(nil, false);
            UI.CreateButton(playerListContent)
                .SetText(playerName)
                .SetColor(player.Color.HtmlColor)
                .SetOnClick(function() PlayerListItemClicked(playerID, playerName); end);
        end
    end
end

function Destroy_PlayerList_UI()
    if (playerListContent ~= nil and not UI.IsDestroyed(playerListContent)) then
        UI.Destroy(playerListContent);
    end
    playerListContent = nil;
end

function PlayerListItemClicked(playerID, playerName)
    TargetPlayerID = playerID;
    TargetPlayerName = playerName;
    TargetTerritoryInstructionLabel.SetText("Selected player: " .. playerName).SetColor(TEXT_DEFAULT_COLOUR);
    TargetTerritoryBtn.SetInteractable(true);
    SelectPlayerBtn.SetInteractable(true);
    PlayCardBtn.SetInteractable(true);
    Destroy_PlayerList_UI();
end
