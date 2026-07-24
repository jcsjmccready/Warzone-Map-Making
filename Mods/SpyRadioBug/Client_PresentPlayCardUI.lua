require('Utilities')

---Client_PresentPlayCardUI
---@param game GameClientHook
---@param cardInstance CardInstance # Read-only data about the card that the player is attempting to play
---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM) # Function that when invoked, will make the player play the card
---@param closeCardsDialog fun() # Function that when invoked will close this cards dialog
function Client_PresentPlayCardUI(game, cardInstance, playCard, closeCardsDialog)
    Game = game;

    --the Bug card targets an enemy territory (to hide the bug on), the Temporary Sweeper card targets one of
    --your own territories (to search it for a hidden bug)
    cardAction = "ERROR";
    modDataPrefix = "ERROR";
    requiresEnemyTerritory = false;
    if(cardInstance.CardID == Mod.Settings.BugCardID) then
        cardAction = "Bug";
        modDataPrefix = "CreateBug_";
        requiresEnemyTerritory = true;
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

    game.CreateDialog(function(rootParent, setMaxSize, setScrollable, game, close)
        Close = close;
        setMaxSize(400, 200);
        local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1); --set flexible width so things don't jump around while we change InstructionLabel
        local buttonsHGroup = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
        TargetTerritoryBtn = UI.CreateButton(buttonsHGroup)
            .SetText("Select Territory")
            .SetOnClick(TargetTerritoryClicked)
            .SetFlexibleWidth(0.3);

        TargetTerritoryInstructionLabel = UI.CreateLabel(vert).SetText("");

        PlayCardBtn = UI.CreateButton(buttonsHGroup)
            .SetText("Play " .. cardAction)
            .SetInteractable(false)
            .SetColor(BUTTON_COLOURS.DarkGreen)
            .SetFlexibleWidth(0.7)
            .SetOnClick(function()
                if (TargetTerritoryID == nil) then
                    TargetTerritoryInstructionLabel.SetText("You must select a territory first").SetColor(ERROR_COLOUR);
                    TargetTerritoryBtn.SetInteractable(true);

                    return;
                end
                local td = game.Map.Territories[TargetTerritoryID];

                local jumpToSpot = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);

                if (playCard(cardAction .. " " .. TargetTerritoryName, modDataPrefix .. TargetTerritoryID, WL.TurnPhase.Attacks, {}, jumpToSpot)) then
                    close();
                end
            end);
    end);
end

function TargetTerritoryClicked()
	UI.InterceptNextTerritoryClick(TerritoryClicked);
	TargetTerritoryInstructionLabel.SetText("Please click on the territory you wish to " .. cardAction .. ".").SetColor(TEXT_DEFAULT_COLOUR);
	TargetTerritoryBtn.SetInteractable(false);
    PlayCardBtn.SetInteractable(false);
end

function TerritoryClicked(terrDetails)
	if UI.IsDestroyed(TargetTerritoryBtn) then
		-- Dialog was destroyed, so we don't need to intercept the click anymore
		return WL.CancelClickIntercept;
	end
	TargetTerritoryBtn.SetInteractable(true);


	if (terrDetails == nil) then
		--The click request was cancelled.   Return to our default state.
		TargetTerritoryInstructionLabel.SetText("");
        TargetTerritoryID = nil;
        TargetTerritoryName = nil;
        PlayCardBtn.SetInteractable(false);
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
    else
		--Territory was clicked, remember its ID
		TargetTerritoryInstructionLabel.SetText("Selected territory: " .. terrDetails.Name).SetColor(TEXT_DEFAULT_COLOUR);
		TargetTerritoryID = terrDetails.ID;
        TargetTerritoryName = terrDetails.Name;
        PlayCardBtn.SetInteractable(true);
	end
end
