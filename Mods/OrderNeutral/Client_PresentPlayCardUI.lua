require('Utilities')

---Client_PresentPlayCardUI
---@param game GameClientHook
---@param cardInstance CardInstance # Read-only data about the card that the player is attempting to play
---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM) # Function that when invoked, will make the player play the card
---@param closeCardsDialog fun() # Function that when invoked will close this cards dialog
function Client_PresentPlayCardUI(game, cardInstance, playCard, closeCardsDialog)
    Game = game;

    --If this dialog is already open, close the previous one. This prevents two copies of it from being open at once which can cause errors due to only saving one instance of the territory buttons
    if (Close ~= nil) then
        Close();
    end

    closeCardsDialog();

    --reset selection state each time the dialog is (re)opened
    FirstTerritoryID = nil;
    FirstTerritoryName = nil;
    SecondTerritoryID = nil;
    SecondTerritoryName = nil;
    ArmyCountInput = nil;
    SpecialUnitCheckboxes = nil;
    ArmyOptionsContent = nil;

    game.CreateDialog(function(rootParent, setMaxSize, setScrollable, game, close)
        Close = close;
        if (Mod.Settings.ArmyAmountInputTroops) then
            setMaxSize(400, 400);
            setScrollable(false, true);
        else
            setMaxSize(400, 260);
        end
        local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1); --set flexible width so things don't jump around while we change InstructionLabel

        local territoryButtonsHGroup = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
        FirstTerritoryBtn = UI.CreateButton(territoryButtonsHGroup)
            .SetText("Select Neutral Territory")
            .SetOnClick(FirstTerritoryClicked)
            .SetFlexibleWidth(0.5);

        SecondTerritoryBtn = UI.CreateButton(territoryButtonsHGroup)
            .SetText("Select Adjacent Territory")
            .SetOnClick(SecondTerritoryClicked)
            .SetFlexibleWidth(0.5)
            .SetInteractable(FirstTerritoryID ~= nil);

        FirstTerritoryInstructionLabel = UI.CreateLabel(vert).SetText("");
        SecondTerritoryInstructionLabel = UI.CreateLabel(vert).SetText("");

        ArmyOptionsHeading = UI.CreateVerticalLayoutGroup(vert).SetFlexibleWidth(1);

        local playButtonsHGroup = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
        PlayCardBtn = UI.CreateButton(playButtonsHGroup)
            .SetText("Play Card")
            .SetColor(BUTTON_COLOURS.DarkGreen)
            .SetFlexibleWidth(1)
            .SetInteractable(FirstTerritoryID ~= nil and SecondTerritoryID ~= nil)
            .SetOnClick(function()
                if (FirstTerritoryID == nil) then
                    FirstTerritoryInstructionLabel.SetText("You must select a neutral territory first").SetColor(ERROR_COLOUR);
                    return;
                end

                if (SecondTerritoryID == nil) then
                    SecondTerritoryInstructionLabel.SetText("You must select a territory adjacent to " .. FirstTerritoryName).SetColor(ERROR_COLOUR);
                    return;
                end

                local armyCountStr = "ALL";
                if (Mod.Settings.ArmyAmountInputTroops) then
                    armyCountStr = tostring(ArmyCountInput.GetValue());
                end

                local chosenSpecialUnitIDs = {};
                for unitID, checkbox in pairs(SpecialUnitCheckboxes) do
                    if (checkbox.GetIsChecked()) then
                        table.insert(chosenSpecialUnitIDs, unitID);
                    end
                end
                local specialUnitsStr = (#chosenSpecialUnitIDs > 0) and table.concat(chosenSpecialUnitIDs, ",") or "NONE";

                if (Mod.Settings.ArmyAmountInputTroops and tonumber(armyCountStr) == 0 and #chosenSpecialUnitIDs == 0) then
                    FirstTerritoryInstructionLabel.SetText("You must send at least 1 army or special unit").SetColor(ERROR_COLOUR);
                    return;
                end

                local td = game.Map.Territories[FirstTerritoryID];

                local jumpToSpot = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);

                local modData = "CreateNeutralAttackTransferOrder_" .. FirstTerritoryID .. "_" .. SecondTerritoryID .. "_" .. armyCountStr .. "_" .. specialUnitsStr;

                if (playCard("Issue neutral attack/transfer order from " .. FirstTerritoryName .. " towards " .. SecondTerritoryName, modData, WL.TurnPhase.Attacks, {}, jumpToSpot)) then
                    close();
                end
            end);
    end);
end

--(re)builds the army count input (if enabled) and one checkbox per special unit present on territoryID, letting the
--player choose exactly what accompanies the order rather than always sending the entire stack
function Create_ArmyOptions_UI(territoryID)
    Destroy_ArmyOptions_UI();

    ArmyOptionsContent = UI.CreateVerticalLayoutGroup(ArmyOptionsHeading).SetFlexibleWidth(1);
    SpecialUnitCheckboxes = {};

    local terr = Game.LatestStanding.Territories[territoryID];

    if (Mod.Settings.ArmyAmountInputTroops) then
        local horz = UI.CreateHorizontalLayoutGroup(ArmyOptionsContent).SetFlexibleWidth(1);
        UI.CreateLabel(horz).SetText("Armies to send").SetPreferredWidth(150);
        ArmyCountInput = UI.CreateNumberInputField(horz)
            .SetSliderMinValue(0)
            .SetSliderMaxValue(terr.NumArmies.NumArmies)
            .SetValue(terr.NumArmies.NumArmies);
    end

    if (#terr.NumArmies.SpecialUnits > 0) then
        UI.CreateLabel(ArmyOptionsContent).SetText("Special units to send:");
        for _, unit in pairs(terr.NumArmies.SpecialUnits) do
            SpecialUnitCheckboxes[unit.ID] = UI.CreateCheckBox(ArmyOptionsContent).SetText(GetSpecialUnitName(unit)).SetIsChecked(true);
        end
    end
end

function Destroy_ArmyOptions_UI()
    if (ArmyOptionsContent ~= nil) then
        UI.Destroy(ArmyOptionsContent);
        ArmyOptionsContent = nil;
    end
    ArmyCountInput = nil;
    SpecialUnitCheckboxes = {};
end

function UpdatePlayCardBtnInteractable()
	PlayCardBtn.SetInteractable(FirstTerritoryID ~= nil and SecondTerritoryID ~= nil);
end

function FirstTerritoryClicked()
	Game.HighlightTerritories({}); --clear any territories highlighted from a previous failed adjacent territory selection
	UI.InterceptNextTerritoryClick(FirstTerritoryHandleClick);
	FirstTerritoryInstructionLabel.SetText("Please click on the neutral territory you wish to create the attack/transfer order for.").SetColor(TEXT_DEFAULT_COLOUR);
	FirstTerritoryBtn.SetInteractable(false);
    SecondTerritoryBtn.SetInteractable(false);

    --picking a new neutral territory invalidates whatever was selected (or errored) for the adjacent territory
    SecondTerritoryID = nil;
    SecondTerritoryName = nil;
    SecondTerritoryInstructionLabel.SetText("");
    Destroy_ArmyOptions_UI();
    UpdatePlayCardBtnInteractable();
end

function FirstTerritoryHandleClick(terrDetails)
	if UI.IsDestroyed(FirstTerritoryBtn) then
		-- Dialog was destroyed, so we don't need to intercept the click anymore
		return WL.CancelClickIntercept;
	end
	FirstTerritoryBtn.SetInteractable(true);

	if (terrDetails == nil) then
		--The click request was cancelled.   Return to our default state.
		FirstTerritoryInstructionLabel.SetText("");
        FirstTerritoryID = nil;
        FirstTerritoryName = nil;
        SecondTerritoryBtn.SetInteractable(false);
        Game.HighlightTerritories({});
        Destroy_ArmyOptions_UI();
        return;
    end

    local terr = Game.LatestStanding.Territories[terrDetails.ID];
    if (terr.OwnerPlayerID ~= WL.PlayerID.Neutral) then
        FirstTerritoryInstructionLabel.SetText("You may only select a neutral territory").SetColor(ERROR_COLOUR);

        FirstTerritoryID = nil;
        FirstTerritoryName = nil;
        Game.HighlightTerritories({});
        Destroy_ArmyOptions_UI();
    else
		--Territory was clicked, remember its ID and name
		FirstTerritoryInstructionLabel.SetText("Selected neutral territory: " .. terrDetails.Name).SetColor(TEXT_DEFAULT_COLOUR);
		FirstTerritoryID = terrDetails.ID;
        FirstTerritoryName = terrDetails.Name;

        --highlight the adjacent territories so the player can see their options while picking the second territory
        local adjacentTerritories = GetTerritoriesWithinDistance(Game, FirstTerritoryID, 1);
        adjacentTerritories = filter(adjacentTerritories, function(terrID) return terrID ~= FirstTerritoryID; end);
        Game.HighlightTerritories(adjacentTerritories);

        Create_ArmyOptions_UI(FirstTerritoryID);
	end

    --if the second territory is no longer adjacent to the (possibly new) first territory, clear it out
    if (SecondTerritoryID ~= nil and (FirstTerritoryID == nil or Game.Map.Territories[FirstTerritoryID].ConnectedTo[SecondTerritoryID] == nil)) then
        SecondTerritoryID = nil;
        SecondTerritoryName = nil;
        SecondTerritoryInstructionLabel.SetText("");
    end

    SecondTerritoryBtn.SetInteractable(FirstTerritoryID ~= nil);
    UpdatePlayCardBtnInteractable();
end

function SecondTerritoryClicked()
    if (FirstTerritoryID == nil) then
        FirstTerritoryInstructionLabel.SetText("You must select a neutral territory first").SetColor(ERROR_COLOUR);
        return;
    end

	UI.InterceptNextTerritoryClick(SecondTerritoryHandleClick);
	SecondTerritoryInstructionLabel.SetText("Please click on a territory adjacent to " .. FirstTerritoryName .. ".").SetColor(TEXT_DEFAULT_COLOUR);
	FirstTerritoryBtn.SetInteractable(false);
    SecondTerritoryBtn.SetInteractable(false);
end

function SecondTerritoryHandleClick(terrDetails)
	if UI.IsDestroyed(SecondTerritoryBtn) then
		-- Dialog was destroyed, so we don't need to intercept the click anymore
		return WL.CancelClickIntercept;
	end
	FirstTerritoryBtn.SetInteractable(true);
    SecondTerritoryBtn.SetInteractable(true);

	if (terrDetails == nil) then
		--The click request was cancelled.   Return to our default state.
		SecondTerritoryInstructionLabel.SetText("");
        SecondTerritoryID = nil;
        SecondTerritoryName = nil;
        UpdatePlayCardBtnInteractable();
        return;
    end

    local isAdjacent = Game.Map.Territories[FirstTerritoryID].ConnectedTo[terrDetails.ID] ~= nil;
    if (not isAdjacent) then
        SecondTerritoryInstructionLabel.SetText("You may only select a territory adjacent to " .. FirstTerritoryName).SetColor(ERROR_COLOUR);

        SecondTerritoryID = nil;
        SecondTerritoryName = nil;

        local adjacentTerritories = GetTerritoriesWithinDistance(Game, FirstTerritoryID, 1);
        adjacentTerritories = filter(adjacentTerritories, function(terrID) return terrID ~= FirstTerritoryID; end);
        Game.HighlightTerritories(adjacentTerritories);
    else
		--Territory was clicked, remember its ID and name
		Game.HighlightTerritories({}); --clear any territories highlighted from a previous failed adjacent territory selection
		SecondTerritoryInstructionLabel.SetText("Selected adjacent territory: " .. terrDetails.Name).SetColor(TEXT_DEFAULT_COLOUR);
		SecondTerritoryID = terrDetails.ID;
        SecondTerritoryName = terrDetails.Name;
	end

    UpdatePlayCardBtnInteractable();
end
