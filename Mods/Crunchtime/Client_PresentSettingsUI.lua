require("Utilities");

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    local triggerMethod = "a Crunch Time Card";
    if (Mod.Settings.TriggerTypeMenu) then triggerMethod = "the Mod Menu"; end
    UI.CreateLabel(descriptionVGroup)
    .SetText("Players may choose to enter Crunch Time via " .. triggerMethod .. ", triggering a temporary period of Crunch Time (increased income) and Rest Time (decreased income), in either order.");

    UI.CreateLabel(descriptionVGroup)
    .SetText("Once started, it can not be exited early.");

    UI.CreateVerticalLayoutGroup(rootParent);

    local increaseVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(increaseVGroup).SetText("Crunch Time (income increase):").SetColor(BUTTON_COLOURS.DarkGreen);
    UI.CreateLabel(increaseVGroup).SetText("Effect: +" .. math.floor(Mod.Settings.IncreasePercent * 100 + 0.5) .. "% then +" .. Mod.Settings.IncreaseFlatAmount .. " income");
    if (Mod.Settings.UserSpecifiedDuration) then
        UI.CreateLabel(increaseVGroup).SetText("Duration: chosen by the player (up to " .. Mod.Settings.MaxUserSpecifiedDuration .. " turns)");
    else
        UI.CreateLabel(increaseVGroup).SetText("Duration: " .. Mod.Settings.IncreaseDuration .. " turn(s)");
    end

    local decreaseVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(decreaseVGroup).SetText("Rest Time (income decrease):").SetColor(BUTTON_COLOURS.OrangeRed);
    UI.CreateLabel(decreaseVGroup).SetText("Effect: -" .. math.floor(Mod.Settings.DecreasePercent * 100 + 0.5) .. "% then -" .. Mod.Settings.DecreaseFlatAmount .. " income");
    if (Mod.Settings.UserSpecifiedDuration) then
        UI.CreateLabel(decreaseVGroup).SetText("Duration: chosen by the player (same duration as Crunch Time)");
    else
        UI.CreateLabel(decreaseVGroup).SetText("Duration: " .. Mod.Settings.DecreaseDuration .. " turn(s)");
    end
end
