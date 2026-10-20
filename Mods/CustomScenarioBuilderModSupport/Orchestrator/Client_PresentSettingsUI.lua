require("Application.Utilities");

---@param placement PlaceholderPlacementSetting
---@return string
local function FormatPlacementText(placement)
    return placement.TerritoryName .. ": " .. (placement.PlacementName or "(no Placement Name)");
end

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(descriptionVGroup).SetText("This mod orchestrates the placement of modded special units, custom structures and vanilla structures at the start of a custom scenario game.");

    local modVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateLabel(modVGroup).SetText('Icon Glossary').SetColor(BUTTON_COLOURS.Artichoke);

    local typeRow = UI.CreateHorizontalLayoutGroup(modVGroup).SetFlexibleWidth(1);
    UI.CreateImage(typeRow)
        .SetSprite(ICON_STRUCTURE)
        .SetPreferredWidth(ICON_SIZE)
        .SetMinWidth(0)
        .SetFlexibleWidth(0)
        .SetPreferredHeight(ICON_SIZE)
        .SetMinHeight(0);
    UI.CreateImage(typeRow)
        .SetSprite(ICON_SPECIAL_UNIT)
        .SetPreferredWidth(ICON_SIZE)
        .SetMinWidth(0)
        .SetFlexibleWidth(0)
        .SetPreferredHeight(ICON_SIZE)
        .SetMinHeight(0);
    UI.CreateLabel(typeRow).SetText("The row represents a Structure or a Special Unit").SetFlexibleWidth(1);

    local originRow = UI.CreateHorizontalLayoutGroup(modVGroup).SetFlexibleWidth(1);
    UI.CreateImage(originRow)
        .SetSprite(ICON_VANILLA)
        .SetPreferredWidth(ICON_SIZE)
        .SetMinWidth(0)
        .SetFlexibleWidth(0)
        .SetPreferredHeight(ICON_SIZE)
        .SetMinHeight(0);
    UI.CreateImage(originRow)
        .SetSprite(ICON_MODDED)
        .SetPreferredWidth(ICON_SIZE)
        .SetMinWidth(0)
        .SetFlexibleWidth(0)
        .SetPreferredHeight(ICON_SIZE)
        .SetMinHeight(0);
    UI.CreateLabel(originRow).SetText("A built-in vanilla structure, or a modded structure/special unit").SetFlexibleWidth(1);

    UI.CreateEmpty(modVGroup).SetPreferredHeight(10);

    UI.CreateLabel(modVGroup).SetText("Territory Placement:").SetColor(BUTTON_COLOURS.Artichoke);

    local placements = Mod.Settings.PlaceholderPlacements or {};
    if (#placements == 0) then
        UI.CreateLabel(modVGroup).SetText("No placements configured").SetColor(BUTTON_COLOURS.DarkGray);
    end

    local sortedPlacements = SortPlacementsByTerritoryName(placements);
    local columnsHorz = UI.CreateHorizontalLayoutGroup(modVGroup).SetFlexibleWidth(1);
    local leftColumn = UI.CreateVerticalLayoutGroup(columnsHorz).SetFlexibleWidth(1);
    local rightColumn = UI.CreateVerticalLayoutGroup(columnsHorz).SetFlexibleWidth(1);
    local leftColumnCount = math.ceil(#sortedPlacements / 2);

    for index, placement in ipairs(sortedPlacements) do
        local column = (index <= leftColumnCount) and leftColumn or rightColumn;
        local row = UI.CreateHorizontalLayoutGroup(column).SetFlexibleWidth(1);

        UI.CreateImage(row)
            .SetSprite((placement.Type == "Structure") and ICON_STRUCTURE or ICON_SPECIAL_UNIT)
            .SetPreferredWidth(LIST_VIEW_ICON_SIZE)
            .SetMinWidth(0)
            .SetFlexibleWidth(0)
            .SetPreferredHeight(LIST_VIEW_ICON_SIZE)
            .SetMinHeight(0);

        local originIcon = ICON_VANILLA;
        if (placement.Type == "SpecialUnit" or IsModdedStructure(placement)) then
            originIcon = ICON_MODDED;
        end
        UI.CreateImage(row).SetSprite(originIcon)
            .SetPreferredWidth(LIST_VIEW_ICON_SIZE)
            .SetMinWidth(0)
            .SetFlexibleWidth(0)
            .SetPreferredHeight(LIST_VIEW_ICON_SIZE)
            .SetMinHeight(0);

        UI.CreateLabel(row).SetText(FormatPlacementText(placement)).SetFlexibleWidth(1);
    end
end
