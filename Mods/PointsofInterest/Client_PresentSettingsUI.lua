require("Utilities");

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(descriptionVGroup).SetText("This mod adds Points of Interest structures (Alpha to Zulu), built on any territory through the commerce menu. They belong to the whole lobby and cannot be removed.");

    local modVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(modVGroup).SetText("Cost of a Point of Interest: " .. (Mod.Settings.PoICost or 0) .. " gold");
    UI.CreateLabel(modVGroup).SetText("");
    UI.CreateLabel(modVGroup).SetText("Visibility of the territory a Point of Interest is on:").SetColor(SUBHEADING_COLOUR);
    for _, name in ipairs(NATO_NAMES) do
        UI.CreateLabel(modVGroup).SetText(name .. ": " .. GetVisibilityText(GetConfiguredVisibility(name)));
    end
end
