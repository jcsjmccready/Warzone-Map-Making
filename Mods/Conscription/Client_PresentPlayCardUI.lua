require('Utilities')

---Client_PresentPlayCardUI
---@param game GameClientHook
---@param cardInstance CardInstance # Read-only data about the card that the player is attempting to play
---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM) # Function that when invoked, will make the player play the card
---@param closeCardsDialog fun() # Function that when invoked will close this cards dialog
function Client_PresentPlayCardUI(game, cardInstance, playCard, closeCardsDialog)
    if (cardInstance.CardID ~= Mod.Settings.ConscriptionCardID) then
        return;
    end

    Game = game;
    SelectedBonusID = nil;
    SelectedBonusName = nil;

    --If this dialog is already open, close the previous one. This prevents two copies of it from being open at once which can cause errors due to only saving one instance of the selection buttons/labels
    if (Close ~= nil) then
        Close();
    end

    closeCardsDialog();

    game.CreateDialog(function(rootParent, setMaxSize, setScrollable, game, close)
        Close = close;
        setMaxSize(420, 258);

        local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1); --set flexible width so things don't jump around while we change InstructionLabel

        local buttonsHGroup = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
        SelectFromMapBtn = UI.CreateButton(buttonsHGroup)
            .SetText("Select From Map")
            .SetOnClick(SelectFromMapClicked)
            .SetFlexibleWidth(0.5);

        SelectFromListBtn = UI.CreateButton(buttonsHGroup)
            .SetText("Select From List")
            .SetOnClick(SelectFromListClicked)
            .SetFlexibleWidth(0.5);

        SelectionInstructionLabel = UI.CreateLabel(vert).SetText("");
        PreviewLabel = UI.CreateLabel(vert).SetText("");
        BonusPreviewLabel = UI.CreateLabel(vert).SetText("");

        local playHGroup = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
        PlayCardBtn = UI.CreateButton(playHGroup)
            .SetText("Conscript")
            .SetInteractable(false)
            .SetColor(BUTTON_COLOURS.DarkGreen)
            .SetFlexibleWidth(1)
            .SetOnClick(function()
                if (SelectedBonusID == nil) then
                    SelectionInstructionLabel.SetText("You must select a bonus first").SetColor(ERROR_COLOUR);
                    return;
                end

                local bonus = game.Map.Bonuses[SelectedBonusID];
                local jumpToSpot = nil;
                local firstTerrID = bonus.Territories[1];
                if (firstTerrID ~= nil) then
                    local td = game.Map.Territories[firstTerrID];
                    jumpToSpot = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
                end

                if (playCard("Conscripts " .. SelectedBonusName, "Conscript_" .. SelectedBonusID, WL.TurnPhase.SanctionCards, {}, jumpToSpot)) then
                    Game.HighlightTerritories({});
                    close();
                end
            end);
    end);
end

---Every territory belonging to a bonus the player fully controls and could therefore select (non-negative
---value), as a HighlightTerritories-ready array - shown as an overview when "Select From Map" is clicked, before
---a specific bonus has been picked.
function GetEligibleBonusTerritoriesToHighlight()
    local highlightSet = {};
    for bonusID, bonus in pairs(Game.Map.Bonuses) do
        if (bonus.Amount >= 0 and PlayerFullyOwnsBonus(Game.LatestStanding, Game.Map, bonusID, Game.Us.ID)) then
            for _, terrID in ipairs(bonus.Territories) do
                highlightSet[terrID] = true;
            end
        end
    end

    local highlightList = {};
    for terrID, _ in pairs(highlightSet) do
        table.insert(highlightList, terrID);
    end
    return highlightList;
end

function SelectFromMapClicked()
    if (UI.IsDestroyed(SelectFromMapBtn)) then
        -- This dialog was already closed/replaced before this click was processed
        return;
    end

    Game.HighlightTerritories(GetEligibleBonusTerritoriesToHighlight());
    SelectionInstructionLabel.SetText("Please click on a bonus you fully control.").SetColor(TEXT_DEFAULT_COLOUR);
    PreviewLabel.SetText("");
    BonusPreviewLabel.SetText("");
    SelectFromMapBtn.SetInteractable(false);
    SelectFromListBtn.SetInteractable(false);
    PlayCardBtn.SetInteractable(false);
    UI.InterceptNextBonusLinkClick(BonusClickedFromMap);
end

function BonusClickedFromMap(bonusDetails)
    if UI.IsDestroyed(SelectFromMapBtn) then
        -- Dialog was destroyed, so we don't need to intercept the click anymore
        return WL.CancelClickIntercept;
    end
    SelectFromMapBtn.SetInteractable(true);
    SelectFromListBtn.SetInteractable(true);

    if (bonusDetails == nil) then
        --The click request was cancelled. Return to our default state.
        SelectionInstructionLabel.SetText("");
        PreviewLabel.SetText("");
    BonusPreviewLabel.SetText("");
        return;
    end

    TrySelectBonus(bonusDetails.ID, bonusDetails.Name);
end

function SelectFromListClicked()
    if (UI.IsDestroyed(SelectFromListBtn)) then
        -- This dialog was already closed/replaced before this click was processed
        return;
    end

    local options = {};
    for bonusID, bonus in pairs(Game.Map.Bonuses) do
        if (bonus.Amount >= 0 and PlayerFullyOwnsBonus(Game.LatestStanding, Game.Map, bonusID, Game.Us.ID)) then
            table.insert(options, { text = bonus.Name, selected = function() TrySelectBonus(bonusID, bonus.Name); end });
        end
    end

    if (#options == 0) then
        SelectionInstructionLabel.SetText("You don't fully control any bonuses eligible for conscription").SetColor(ERROR_COLOUR);
        return;
    end

    UI.PromptFromList("Choose a bonus to conscript", options);
end

function TrySelectBonus(bonusID, bonusName)
    if (UI.IsDestroyed(SelectionInstructionLabel)) then
        -- This dialog was already closed/replaced before this selection was processed
        return;
    end

    local bonus = Game.Map.Bonuses[bonusID];
    if (bonus ~= nil and bonus.Amount < 0) then
        SelectionInstructionLabel.SetText(bonusName .. " has a negative value and cannot be conscripted").SetColor(ERROR_COLOUR);
        PreviewLabel.SetText("");
    BonusPreviewLabel.SetText("");
        SelectedBonusID = nil;
        SelectedBonusName = nil;
        PlayCardBtn.SetInteractable(false);
        Game.HighlightTerritories({});
        return;
    end

    if (not PlayerFullyOwnsBonus(Game.LatestStanding, Game.Map, bonusID, Game.Us.ID)) then
        SelectionInstructionLabel.SetText("You must fully control every territory in " .. bonusName .. " to select it").SetColor(ERROR_COLOUR);
        PreviewLabel.SetText("");
    BonusPreviewLabel.SetText("");
        SelectedBonusID = nil;
        SelectedBonusName = nil;
        PlayCardBtn.SetInteractable(false);
        Game.HighlightTerritories({});
        return;
    end

    SelectedBonusID = bonusID;
    SelectedBonusName = bonusName;
    SelectionInstructionLabel.SetText("Selected bonus: " .. bonusName).SetColor(TEXT_DEFAULT_COLOUR);

    -- this is a preview only: if more than one Conscription resolves against the same bonus this turn, later
    -- ones will see a lower effective value, so these figures are only guaranteed as an upper bound
    local effectiveValue = GetEffectiveBonusValue(Game.Map, bonusID);
    local decreaseAmount, incomeGain = CalculateConscriptionEffect(effectiveValue);
    PreviewLabel.SetText("Maximum income gained: " .. incomeGain).SetColor(TEXT_DEFAULT_COLOUR);

    local _, color = GetConscriptionStatus(bonus, effectiveValue);
    BonusPreviewLabel.SetText("Bonus: " .. effectiveValue .. "/" .. bonus.Amount .. " (-" .. decreaseAmount .. ")").SetColor(color);

    PlayCardBtn.SetInteractable(true);
    Game.HighlightTerritories(Game.Map.Bonuses[bonusID].Territories);
end
