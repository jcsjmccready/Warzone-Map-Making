require("Utilities");

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(descriptionVGroup).SetText("This mod orchestrates the placement of modded special units, custom structures and vanilla structures at the start of a custom scenario game.");

    local modVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(modVGroup).SetText("Territory Placement:").SetColor(BUTTON_COLOURS.Artichoke);

    local placements = Mod.Settings.PlaceholderPlacements or {};
    if (#placements == 0) then
        UI.CreateLabel(modVGroup).SetText("No placements configured").SetColor(BUTTON_COLOURS.DarkGray);
    end

    for _, placement in ipairs(SortPlacementsByTerritoryName(placements)) do
        local row = UI.CreateHorizontalLayoutGroup(modVGroup).SetFlexibleWidth(1);

        UI.CreateImage(row)
            .SetSprite((placement.Type == "Structure") and ICON_STRUCTURE or ICON_SPECIAL_UNIT)
            .SetPreferredWidth(LIST_VIEW_ICON_SIZE).SetMinWidth(0).SetFlexibleWidth(0).SetPreferredHeight(LIST_VIEW_ICON_SIZE).SetMinHeight(0);

        local originIcon = ICON_VANILLA;
        if (placement.Type == "SpecialUnit" or IsModdedStructure(placement)) then
            originIcon = ICON_MODDED;
        end
        UI.CreateImage(row).SetSprite(originIcon).SetPreferredWidth(LIST_VIEW_ICON_SIZE).SetMinWidth(0).SetFlexibleWidth(0).SetPreferredHeight(LIST_VIEW_ICON_SIZE).SetMinHeight(0);

        UI.CreateLabel(row).SetText(FormatPlacementText(placement)).SetFlexibleWidth(1);
    end
end
