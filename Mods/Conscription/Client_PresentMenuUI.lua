require('Utilities')

MAX_RESULT_LINES = 8;

---Client_PresentMenuUI hook
---@param rootParent RootParent
---@param setMaxSize fun(width: number, height: number)
---@param setScrollable fun(horizontallyScrollable: boolean, verticallyScrollable: boolean)
---@param game GameClientHook
---@param close fun()
function Client_PresentMenuUI(rootParent, setMaxSize, setScrollable, game, close)
    Game = game;
    Close = close;

    setMaxSize(420, 300);

    local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    local titleHGroup = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
    UI.CreateButton(titleHGroup)
        .SetText("Identify Conscription Level")
        .SetInteractable(false)
        .SetFlexibleWidth(1);

    local buttonsHGroup = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
    BonusFromMapBtn = UI.CreateButton(buttonsHGroup)
        .SetText("Bonus from Map")
        .SetOnClick(BonusFromMapClicked)
        .SetColor(BUTTON_COLOURS.RoyalBlue)
        .SetFlexibleWidth(1);

    BonusFromListBtn = UI.CreateButton(buttonsHGroup)
        .SetText("Bonus from List")
        .SetOnClick(BonusFromListClicked)
        .SetColor(BUTTON_COLOURS.Tan)
        .SetFlexibleWidth(1);

    BonusFromTerritoryBtn = UI.CreateButton(buttonsHGroup)
        .SetText("Bonus from Territory")
        .SetOnClick(BonusFromTerritoryClicked)
        .SetColor(BUTTON_COLOURS.Amazon)
        .SetFlexibleWidth(1);

    InstructionLabel = UI.CreateLabel(vert).SetText("");

    -- fixed pool of reusable result-line labels, so each bonus's line can be individually coloured (orange
    -- if conscripted, green if not) without ever destroying/recreating UI objects
    ResultsParent = UI.CreateVerticalLayoutGroup(vert);
    ResultsLabels = {};
    for i = 1, MAX_RESULT_LINES do
        ResultsLabels[i] = UI.CreateLabel(ResultsParent).SetText("");
    end
end

function ClearResultLines()
    for i = 1, MAX_RESULT_LINES do
        ResultsLabels[i].SetText("");
    end
end

---Sets result line `index` (1-based) to `text` in `color`. Silently does nothing past MAX_RESULT_LINES.
function SetResultLine(index, text, color)
    if (index > MAX_RESULT_LINES) then return; end;
    ResultsLabels[index].SetText(text).SetColor(color);
end

---Returns bonus's formatted result line and its status colour: "Name: current/base (status)".
function FormatBonusLine(bonus, effectiveValue)
    local status, color = GetConscriptionStatus(bonus, effectiveValue);
    if (effectiveValue < bonus.Amount) then
        return bonus.Name .. ": " .. effectiveValue .. "/" .. bonus.Amount .. " (" .. status .. ")", color;
    end
    return bonus.Name .. ": " .. effectiveValue .. " (" .. status .. ")", color;
end

---Re-enables whichever button a map/territory click is currently being awaited for (if any) and clears the
---pending state, so a stale click that arrives afterwards (see the PendingSelectionType checks in
---BonusClickedFromMap/TerritoryClickedFromMap) is just let through instead of being treated as our selection.
---There's no engine API to cancel an InterceptNextBonusLinkClick/InterceptNextTerritoryClick ahead of time, so
---this only cleans up our own UI/state - the intercept itself is cancelled from inside the callback instead.
function AbortPendingSelection()
    if (PendingSelectionType == "map") then
        BonusFromMapBtn.SetInteractable(true);
    elseif (PendingSelectionType == "territory") then
        BonusFromTerritoryBtn.SetInteractable(true);
    end
    PendingSelectionType = nil;
end

---Every territory belonging to a currently-conscripted bonus that the player has at least partial visibility
---into (i.e. PlayerCanSeeAnyTerritoryInBonus), as a HighlightTerritories-ready array.
function GetConscriptedBonusTerritoriesToHighlight()
    local highlightSet = {};
    for bonusID, bonus in pairs(Game.Map.Bonuses) do
        local effectiveValue = GetEffectiveBonusValue(Game.Map, bonusID);
        if (effectiveValue < bonus.Amount and PlayerCanSeeAnyTerritoryInBonus(Game.LatestStanding, Game.Map, bonusID)) then
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

---Every territory the player can individually see that belongs to at least one currently-conscripted bonus, as
---a HighlightTerritories-ready array.
function GetVisibleTerritoriesInConscriptedBonuses()
    local highlightList = {};
    for terrID, territory in pairs(Game.Map.Territories) do
        if (PlayerCanSeeTerritory(Game.LatestStanding, terrID)) then
            for _, bonusID in ipairs(territory.PartOfBonuses or {}) do
                local bonus = Game.Map.Bonuses[bonusID];
                if (bonus ~= nil and GetEffectiveBonusValue(Game.Map, bonusID) < bonus.Amount) then
                    table.insert(highlightList, terrID);
                    break;
                end
            end
        end
    end
    return highlightList;
end

------------------------------
-- Bonus from Map / Bonus from List
------------------------------

function BonusFromMapClicked()
    if (UI.IsDestroyed(BonusFromMapBtn)) then
        -- This dialog was already closed/replaced before this click was processed
        return;
    end

    AbortPendingSelection();

    UI.InterceptNextBonusLinkClick(BonusClickedFromMap);
    Game.HighlightTerritories(GetConscriptedBonusTerritoriesToHighlight());
    ClearResultLines();
    InstructionLabel.SetText("Please click on the bonus you wish to inspect.").SetColor(TEXT_DEFAULT_COLOUR);
    BonusFromMapBtn.SetInteractable(false);
    PendingSelectionType = "map";
end

function BonusClickedFromMap(bonusDetails)
    if UI.IsDestroyed(BonusFromMapBtn) then
        -- Dialog was destroyed, so we don't need to intercept the click anymore
        return WL.CancelClickIntercept;
    end

    if (PendingSelectionType ~= "map") then
        -- a different button was clicked before this bonus was, so let the click through normally instead of
        -- treating it as our selection
        return WL.CancelClickIntercept;
    end

    BonusFromMapBtn.SetInteractable(true);
    PendingSelectionType = nil;

    if (bonusDetails == nil) then
        --The click request was cancelled. Return to our default state.
        InstructionLabel.SetText("");
        Game.HighlightTerritories({});
        return;
    end

    if (not PlayerCanSeeAnyTerritoryInBonus(Game.LatestStanding, Game.Map, bonusDetails.ID)) then
        InstructionLabel.SetText("You must have visibility of the bonus").SetColor(ERROR_COLOUR);
        Game.HighlightTerritories({});
        return;
    end

    ShowBonusValue(bonusDetails.ID, bonusDetails.Name);
end

function BonusFromListClicked()
    if (UI.IsDestroyed(BonusFromListBtn)) then
        -- This dialog was already closed/replaced before this click was processed
        return;
    end

    AbortPendingSelection();

    local options = {};
    for bonusID, bonus in pairs(Game.Map.Bonuses) do
        if (GetEffectiveBonusValue(Game.Map, bonusID) < bonus.Amount and PlayerCanSeeAnyTerritoryInBonus(Game.LatestStanding, Game.Map, bonusID)) then
            table.insert(options, { text = bonus.Name, selected = function() ShowBonusValue(bonusID, bonus.Name); end });
        end
    end

    if (#options == 0) then
        InstructionLabel.SetText("You don't have visibility of any conscripted bonuses").SetColor(ERROR_COLOUR);
        return;
    end

    UI.PromptFromList("Choose a bonus", options);
end

function ShowBonusValue(bonusID, bonusName)
    if (UI.IsDestroyed(InstructionLabel)) then
        -- This dialog was already closed/replaced before this selection was processed
        return;
    end

    local bonus = Game.Map.Bonuses[bonusID];
    if (bonus == nil) then return; end;

    InstructionLabel.SetText("Selected bonus: " .. bonusName).SetColor(TEXT_DEFAULT_COLOUR);

    local effectiveValue = GetEffectiveBonusValue(Game.Map, bonusID);
    local status, color = GetConscriptionStatus(bonus, effectiveValue);

    if (effectiveValue < bonus.Amount) then
        Game.HighlightTerritories(bonus.Territories);
        SetResultLine(1, "Current value: " .. effectiveValue .. "/" .. bonus.Amount .. " (" .. status .. ")", color);
    else
        Game.HighlightTerritories({});
        SetResultLine(1, "Current value: " .. effectiveValue .. " (" .. status .. ")", color);
    end
end

------------------------------
-- Bonus from Territory
------------------------------

function BonusFromTerritoryClicked()
    if (UI.IsDestroyed(BonusFromTerritoryBtn)) then
        -- This dialog was already closed/replaced before this click was processed
        return;
    end

    AbortPendingSelection();

    UI.InterceptNextTerritoryClick(TerritoryClickedFromMap);
    Game.HighlightTerritories(GetVisibleTerritoriesInConscriptedBonuses());
    ClearResultLines();
    InstructionLabel.SetText("Please click on the territory you wish to inspect.").SetColor(TEXT_DEFAULT_COLOUR);
    BonusFromTerritoryBtn.SetInteractable(false);
    PendingSelectionType = "territory";
end

function TerritoryClickedFromMap(terrDetails)
    if UI.IsDestroyed(BonusFromTerritoryBtn) then
        -- Dialog was destroyed, so we don't need to intercept the click anymore
        return WL.CancelClickIntercept;
    end

    if (PendingSelectionType ~= "territory") then
        -- a different button was clicked before this territory was, so let the click through normally instead
        -- of treating it as our selection
        return WL.CancelClickIntercept;
    end

    BonusFromTerritoryBtn.SetInteractable(true);
    PendingSelectionType = nil;

    if (terrDetails == nil) then
        --The click request was cancelled. Return to our default state.
        InstructionLabel.SetText("");
        Game.HighlightTerritories({});
        return;
    end

    ShowTerritoryBonuses(terrDetails.ID, terrDetails.Name);
end

function ShowTerritoryBonuses(territoryID, territoryName)
    if (UI.IsDestroyed(InstructionLabel)) then
        -- This dialog was already closed/replaced before this selection was processed
        return;
    end

    if (not PlayerCanSeeTerritory(Game.LatestStanding, territoryID)) then
        InstructionLabel.SetText("You must have visibility of the territory").SetColor(ERROR_COLOUR);
        Game.HighlightTerritories({});
        return;
    end

    InstructionLabel.SetText("Selected territory: " .. territoryName).SetColor(TEXT_DEFAULT_COLOUR);

    local bonusIDs = Game.Map.Territories[territoryID].PartOfBonuses or {};
    if (#bonusIDs == 0) then
        SetResultLine(1, "This territory isn't part of any bonus.", TEXT_DEFAULT_COLOUR);
        Game.HighlightTerritories({});
        return;
    end

    -- only highlight territories belonging to bonuses that are actually conscripted, deduplicated since a
    -- territory can belong to more than one bonus
    local highlightSet = {};
    local lineIndex = 1;
    for _, bonusID in ipairs(bonusIDs) do
        local bonus = Game.Map.Bonuses[bonusID];
        if (bonus ~= nil) then
            local effectiveValue = GetEffectiveBonusValue(Game.Map, bonusID);
            local text, color = FormatBonusLine(bonus, effectiveValue);
            SetResultLine(lineIndex, text, color);
            lineIndex = lineIndex + 1;

            if (effectiveValue < bonus.Amount) then
                for _, terrID in ipairs(bonus.Territories) do
                    highlightSet[terrID] = true;
                end
            end
        end
    end

    local highlightList = {};
    for terrID, _ in pairs(highlightSet) do
        table.insert(highlightList, terrID);
    end
    Game.HighlightTerritories(highlightList);
end
