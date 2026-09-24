require("Utilities");
require("Client_PresentSettingsUI_V1");
require("Client_PresentSettingsUI_V2");

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    UI.CreateLabel(rootParent).SetText("Mod Settings Version: " .. GetSettingsVersionForDisplay()).SetColor(BUTTON_COLOURS.DarkGray);

    local version = Mod.Settings.Version or 1;

    if (version < 2) then
        PresentSettingsV1.Render(rootParent);
    else
        PresentSettingsV2.Render(rootParent);
    end
end
