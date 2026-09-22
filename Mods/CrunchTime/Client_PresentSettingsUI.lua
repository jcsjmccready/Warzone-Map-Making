require("Utilities");

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    local triggerMethod = "a Crunch Time Card";
    if (Mod.Settings.TriggerTypeMenu) then triggerMethod = "the Mod Menu"; end
    UI.CreateLabel(descriptionVGroup)
    .SetText("Players may choose to enter Crunch Time via " .. triggerMethod .. ", triggering a sequence of temporary income changes.");

    if (Mod.Settings.PhaseOrderPlayerSelected) then
        UI.CreateLabel(descriptionVGroup).SetText("The player chooses which phase to start on.");
    else
        UI.CreateLabel(descriptionVGroup).SetText("It always starts on phase 1.");
    end

    if (Mod.Settings.UserSpecifiedDuration) then
        UI.CreateLabel(descriptionVGroup).SetText("The player chooses a duration (up to " .. Mod.Settings.MaxUserSpecifiedDuration .. " turns) used for every phase.");
    end

    UI.CreateLabel(descriptionVGroup)
    .SetText("Once started, it can not be exited early.");

    UI.CreateVerticalLayoutGroup(rootParent);

    local phasesVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(phasesVGroup).SetText("Phases:").SetColor(SUBHEADING_COLOUR);

    ---@type PhaseRowSetting[]
    local configuredPhases = Mod.Settings.Phases or {};
    for i, row in ipairs(configuredPhases) do
        local color = (row.Percent >= 0) and BUTTON_COLOURS.DarkGreen or BUTTON_COLOURS.OrangeRed;
        UI.CreateLabel(phasesVGroup).SetText(i .. ". " .. DescribePhaseRow(row)).SetColor(color);
    end
end
