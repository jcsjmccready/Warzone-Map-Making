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

    setMaxSize(400, 300);

    local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    local topButtonsHGroup = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
    InspectBonusBtn = UI.CreateButton(topButtonsHGroup)
        .SetText("Inspect Bonus")
        .SetOnClick(InspectBonusClicked)
        .SetColor(BUTTON_COLOURS.RoyalBlue)
        .SetFlexibleWidth(0.5);

    InspectTerritoryBtn = UI.CreateButton(topButtonsHGroup)
        .SetText("Inspect Territory")
        .SetOnClick(InspectTerritoryClicked)
        .SetColor(BUTTON_COLOURS.Tan)
        .SetFlexibleWidth(0.5);

    ContentParent = UI.CreateVerticalLayoutGroup(vert).SetFlexibleWidth(1);
end

function InspectBonusClicked()
    if (UI.IsDestroyed(InspectBonusBtn)) then
        -- This dialog was already closed/replaced before this click was processed
        return;
    end

    InspectBonusBtn.SetInteractable(false);
    InspectTerritoryBtn.SetInteractable(true);

    Destroy_Content_UI();
    Create_InspectBonus_UI(ContentParent);
end

function InspectTerritoryClicked()
    if (UI.IsDestroyed(InspectTerritoryBtn)) then
        -- This dialog was already closed/replaced before this click was processed
        return;
    end

    InspectTerritoryBtn.SetInteractable(false);
    InspectBonusBtn.SetInteractable(true);

    Destroy_Content_UI();
    Create_InspectTerritory_UI(ContentParent);
end

---Destroys the currently active sub-panel (whichever one it is), taking every one of its suboptions down with
---it (UI.Destroy is recursive), before the caller builds the other panel in its place.
function Destroy_Content_UI()
    if (ContentVGroup ~= nil) then
        UI.Destroy(ContentVGroup);
    end
end

------------------------------
-- Inspect Bonus
------------------------------

function Create_InspectBonus_UI(rootParent)
    ContentVGroup = UI.CreateVerticalLayoutGroup(rootParent);

    local buttonsHGroup = UI.CreateHorizontalLayoutGroup(ContentVGroup).SetFlexibleWidth(1);
    SelectBonusFromMapBtn = UI.CreateButton(buttonsHGroup)
        .SetText("Select From Map")
        .SetOnClick(SelectBonusFromMapClicked)
        .SetFlexibleWidth(0.5);

    SelectBonusFromListBtn = UI.CreateButton(buttonsHGroup)
        .SetText("Select From List")
        .SetOnClick(SelectBonusFromListClicked)
        .SetFlexibleWidth(0.5);

    BonusInstructionLabel = UI.CreateLabel(ContentVGroup).SetText("");
    BonusValueLabel = UI.CreateLabel(ContentVGroup).SetText("");
end

function SelectBonusFromMapClicked()
    if (UI.IsDestroyed(SelectBonusFromMapBtn)) then
        -- This dialog was already closed/replaced before this click was processed
        return;
    end

    UI.InterceptNextBonusLinkClick(BonusClickedFromMap);
    Game.HighlightTerritories({});
    BonusValueLabel.SetText("");
    SelectBonusFromMapBtn.SetInteractable(false);
    SelectBonusFromListBtn.SetInteractable(false);
end

function BonusClickedFromMap(bonusDetails)
    if UI.IsDestroyed(SelectBonusFromMapBtn) then
        -- Dialog was destroyed, so we don't need to intercept the click anymore
        return WL.CancelClickIntercept;
    end

    SelectBonusFromMapBtn.SetInteractable(true);
    SelectBonusFromListBtn.SetInteractable(true);

    if (bonusDetails == nil) then
        --The click request was cancelled. Return to our default state.
        BonusInstructionLabel.SetText("");
        BonusValueLabel.SetText("");
        Game.HighlightTerritories({});
        return;
    end

    if (not PlayerCanSeeAnyTerritoryInBonus(Game.LatestStanding, Game.Map, bonusDetails.ID)) then
        BonusInstructionLabel.SetText("You must have visibility of the bonus").SetColor(ERROR_COLOUR);
        BonusValueLabel.SetText("");
        Game.HighlightTerritories({});
        return;
    end

    ShowBonusValue(bonusDetails.ID, bonusDetails.Name);
end

function SelectBonusFromListClicked()
    if (UI.IsDestroyed(SelectBonusFromListBtn)) then
        -- This dialog was already closed/replaced before this click was processed
        return;
    end

    local options = {};
    for bonusID, bonus in pairs(Game.Map.Bonuses) do
        if (bonus.Amount >= 0 and PlayerCanSeeAnyTerritoryInBonus(Game.LatestStanding, Game.Map, bonusID)) then
            table.insert(options, { text = bonus.Name, selected = function() ShowBonusValue(bonusID, bonus.Name); end });
        end
    end

    if (#options == 0) then
        BonusInstructionLabel.SetText("You don't have visibility of any non-negative bonuses").SetColor(ERROR_COLOUR);
        return;
    end

    UI.PromptFromList("Choose a bonus", options);
end

function ShowBonusValue(bonusID, bonusName)
    if (UI.IsDestroyed(BonusInstructionLabel)) then
        -- This dialog was already closed/replaced before this selection was processed
        return;
    end

    local bonus = Game.Map.Bonuses[bonusID];
    if (bonus == nil) then return; end;

    BonusInstructionLabel.SetText("Selected bonus: " .. bonusName).SetColor(TEXT_DEFAULT_COLOUR);
    Game.HighlightTerritories(bonus.Territories);

    local effectiveValue = GetEffectiveBonusValue(Game.Map, bonusID);
    if (effectiveValue < bonus.Amount) then
        BonusValueLabel.SetText("Current value: " .. effectiveValue .. "/" .. bonus.Amount .. " (conscripted)").SetColor(BUTTON_COLOURS.Orange);
    else
        BonusValueLabel.SetText("Current value: " .. effectiveValue .. " (not conscripted)").SetColor(BUTTON_COLOURS.DarkGreen);
    end
end

------------------------------
-- Inspect Territory
------------------------------

function Create_InspectTerritory_UI(rootParent)
    ContentVGroup = UI.CreateVerticalLayoutGroup(rootParent);

    local buttonHGroup = UI.CreateHorizontalLayoutGroup(ContentVGroup).SetFlexibleWidth(1);
    SelectTerritoryBtn = UI.CreateButton(buttonHGroup)
        .SetText("Select Territory")
        .SetFlexibleWidth(1)
        .SetOnClick(SelectTerritoryClicked);

    TerritoryInstructionLabel = UI.CreateLabel(ContentVGroup).SetText("");
    TerritoryBonusesParent = UI.CreateVerticalLayoutGroup(ContentVGroup);
    TerritoryBonusesVGroup = nil;
end

function SelectTerritoryClicked()
    if (UI.IsDestroyed(SelectTerritoryBtn)) then
        -- This dialog was already closed/replaced before this click was processed
        return;
    end

    UI.InterceptNextTerritoryClick(TerritoryClickedFromMap);
    TerritoryInstructionLabel.SetText("Please click on the territory you wish to inspect.").SetColor(TEXT_DEFAULT_COLOUR);
    if (TerritoryBonusesVGroup ~= nil) then
        UI.Destroy(TerritoryBonusesVGroup);
        TerritoryBonusesVGroup = nil;
    end
    SelectTerritoryBtn.SetInteractable(false);
end

function TerritoryClickedFromMap(terrDetails)
    if UI.IsDestroyed(SelectTerritoryBtn) then
        -- Dialog was destroyed, so we don't need to intercept the click anymore
        return WL.CancelClickIntercept;
    end

    SelectTerritoryBtn.SetInteractable(true);

    if (terrDetails == nil) then
        --The click request was cancelled. Return to our default state.
        TerritoryInstructionLabel.SetText("");
        return;
    end

    ShowTerritoryBonuses(terrDetails.ID, terrDetails.Name);
end

function ShowTerritoryBonuses(territoryID, territoryName)
    if (UI.IsDestroyed(TerritoryInstructionLabel)) then
        -- This dialog was already closed/replaced before this selection was processed
        return;
    end

    if (not PlayerCanSeeTerritory(Game.LatestStanding, territoryID)) then
        TerritoryInstructionLabel.SetText("You must have visibility of the territory").SetColor(ERROR_COLOUR);
        if (TerritoryBonusesVGroup ~= nil) then
            UI.Destroy(TerritoryBonusesVGroup);
            TerritoryBonusesVGroup = nil;
        end
        return;
    end

    TerritoryInstructionLabel.SetText("Selected territory: " .. territoryName).SetColor(TEXT_DEFAULT_COLOUR);

    if (TerritoryBonusesVGroup ~= nil) then
        UI.Destroy(TerritoryBonusesVGroup);
    end
    TerritoryBonusesVGroup = UI.CreateVerticalLayoutGroup(TerritoryBonusesParent);

    local bonusIDs = Game.Map.Territories[territoryID].PartOfBonuses or {};
    if (#bonusIDs == 0) then
        UI.CreateLabel(TerritoryBonusesVGroup).SetText("This territory isn't part of any bonus.").SetColor(TEXT_DEFAULT_COLOUR);
        return;
    end

    for _, bonusID in ipairs(bonusIDs) do
        local bonus = Game.Map.Bonuses[bonusID];
        if (bonus ~= nil) then
            local effectiveValue = GetEffectiveBonusValue(Game.Map, bonusID);
            if (effectiveValue < bonus.Amount) then
                UI.CreateLabel(TerritoryBonusesVGroup).SetText(bonus.Name .. ": " .. effectiveValue .. "/" .. bonus.Amount .. " (conscripted)").SetColor(BUTTON_COLOURS.Orange);
            else
                UI.CreateLabel(TerritoryBonusesVGroup).SetText(bonus.Name .. ": " .. effectiveValue .. " (not conscripted)").SetColor(BUTTON_COLOURS.DarkGreen);
            end
        end
    end
end
