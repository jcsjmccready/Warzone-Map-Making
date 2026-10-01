require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(mainModUI).SetText('Points of Interest belong to the whole lobby and cannot be removed once built*').SetColor(BUTTON_COLOURS.DarkGray);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Cost of a Point of Interest').SetPreferredWidth(290);
    poiCost = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(50)
        .SetValue(Mod.Settings.PoICost or 5);

    UI.CreateLabel(mainModUI).SetText('Visibility of the territory a Point of Interest is on:').SetColor(SUBHEADING_COLOUR);

    visibilityDropDowns = {};
    for _, name in ipairs(NATO_NAMES) do
        local row = UI.CreateHorizontalLayoutGroup(mainModUI);
        UI.CreateLabel(row).SetText(name).SetPreferredWidth(120);
        visibilityDropDowns[name] = CreateDropDown(row, VISIBILITY_OPTIONS, GetConfiguredVisibility(name));
    end
end
