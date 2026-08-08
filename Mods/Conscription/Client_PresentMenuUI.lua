require('Utilities')

---Client_PresentMenuUI hook
---@param rootParent RootParent
---@param setMaxSize fun(width: number, height: number)
---@param setScrollable fun(horizontallyScrollable: boolean, verticallyScrollable: boolean)
---@param game GameClientHook
---@param close fun()
function Client_PresentMenuUI(rootParent, setMaxSize, setScrollable, game, close)
    Game = game;
    Close = close;

    setMaxSize(400, 200);

    local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    local buttonsHGroup = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
    SelectFromMapBtn = UI.CreateButton(buttonsHGroup)
        .SetText("Select From Map")
        .SetOnClick(SelectFromMapClicked)
        .SetFlexibleWidth(0.5);

    SelectFromListBtn = UI.CreateButton(buttonsHGroup)
        .SetText("Select From List")
        .SetOnClick(SelectFromListClicked)
        .SetFlexibleWidth(0.5);

    BonusInstructionLabel = UI.CreateLabel(vert).SetText("");
    BonusValueLabel = UI.CreateLabel(vert).SetText("");
end

function SelectFromMapClicked()
    UI.InterceptNextBonusLinkClick(BonusClickedFromMap);
    BonusValueLabel.SetText("");
    SelectFromMapBtn.SetInteractable(false);
    SelectFromListBtn.SetInteractable(false);
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
        BonusInstructionLabel.SetText("");
        BonusValueLabel.SetText("");
        return;
    end

    ShowBonusValue(bonusDetails.ID, bonusDetails.Name);
end

function SelectFromListClicked()
    local options = {};
    for bonusID, bonus in pairs(Game.Map.Bonuses) do
        table.insert(options, { text = bonus.Name, selected = function() ShowBonusValue(bonusID, bonus.Name); end });
    end
    UI.PromptFromList("Choose a bonus", options);
end

function ShowBonusValue(bonusID, bonusName)
    local bonus = Game.Map.Bonuses[bonusID];
    if (bonus == nil) then return; end;

    BonusInstructionLabel.SetText("Selected bonus: " .. bonusName).SetColor(TEXT_DEFAULT_COLOUR);

    local effectiveValue = GetEffectiveBonusValue(Game.Map, bonusID);
    if (effectiveValue < bonus.Amount) then
        BonusValueLabel.SetText("Current value: " .. effectiveValue .. "/" .. bonus.Amount .. " (conscripted)").SetColor(BUTTON_COLOURS.Orange);
    else
        BonusValueLabel.SetText("Current value: " .. effectiveValue .. " (not conscripted)").SetColor(BUTTON_COLOURS.DarkGreen);
    end
end
