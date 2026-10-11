require("Utilities");

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(descriptionVGroup).SetText("This mod adds Points of Interest structures (Alpha to Zulu), placed on configured territories at the start of the game. They belong to the whole lobby and cannot be removed.");

    local modVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(modVGroup).SetText("POI Config:");
    local anyEnabled = false;
    for _, name in ipairs(NATO_NAMES) do
        if (IsPoIEnabled(name)) then
            anyEnabled = true;
            local visibility = GetConfiguredVisibility(name);
            UI.CreateLabel(modVGroup).SetText(name .. ": " .. GetVisibilityText(visibility)).SetColor(GetPoIStateColor(visibility));
        end
    end
    if (not anyEnabled) then
        UI.CreateLabel(modVGroup).SetText("No POIs enabled").SetColor(BUTTON_COLOURS.DarkGray);
    end

    UI.CreateEmpty(modVGroup).SetPreferredHeight(10);
    UI.CreateLabel(modVGroup).SetText("Territory POI Placement:");
    local placements = Mod.Settings.PoIPlacements or {};
    if (#placements == 0) then
        UI.CreateLabel(modVGroup).SetText("No placements configured").SetColor(BUTTON_COLOURS.DarkGray);
    end

    -- Grouped by POI (NATO alphabetical order) rather than configured order, so every territory sharing a POI is
    -- listed together
    for _, name in ipairs(NATO_NAMES) do
        local territoryNames = {};
        for _, placement in ipairs(placements) do
            if (placement.Name == name) then
                table.insert(territoryNames, placement.TerritoryName);
            end
        end

        if (#territoryNames > 0) then
            UI.CreateLabel(modVGroup).SetText(name .. ":").SetColor(GetPoIStateColor(GetConfiguredVisibility(name)));
            for _, territoryName in ipairs(territoryNames) do
                UI.CreateLabel(modVGroup).SetText("   " .. territoryName);
            end
        end
    end
end
