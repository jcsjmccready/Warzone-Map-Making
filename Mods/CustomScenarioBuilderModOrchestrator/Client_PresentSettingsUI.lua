require("Utilities");

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(descriptionVGroup).SetText("This mod places Placeholder special units on configured territories at the start of the game, as stand-ins for a structure or special unit from another mod.");

    local modVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(modVGroup).SetText("Placeholder Placement:");

    local placements = Mod.Settings.PlaceholderPlacements or {};
    if (#placements == 0) then
        UI.CreateLabel(modVGroup).SetText("No placements configured").SetColor(BUTTON_COLOURS.DarkGray);
    end

    for _, placement in ipairs(placements) do
        local placementType = placement.Type or DEFAULT_PLACEMENT_TYPE;
        local text = "[" .. GetOptionText(PLACEMENT_TYPE_OPTIONS, placementType) .. "] " .. placement.TerritoryName;
        if (placement.PlacementName ~= nil) then
            text = text .. "  (" .. placement.PlacementName .. ")";
        end
        UI.CreateLabel(modVGroup).SetText(text);
    end
end
