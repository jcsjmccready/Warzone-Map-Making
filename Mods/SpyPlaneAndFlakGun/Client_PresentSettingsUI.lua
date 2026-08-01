require("Utilities");

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    UI.CreateVerticalLayoutGroup(rootParent);

    if(Mod.Settings.IncludeSpyPlaneCard) then
        local spyPlaneCardVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
        UI.CreateLabel(spyPlaneCardVGroup).SetText("Spy Plane Card:").SetColor(BUTTON_COLOURS.LightBlue);

        UI.CreateLabel(spyPlaneCardVGroup).SetText("Number of Pieces: " .. Mod.Settings.SpyPlaneNumPieces);
        UI.CreateLabel(spyPlaneCardVGroup).SetText("Card Weight: " .. Mod.Settings.SpyPlaneCardWeight);
        UI.CreateLabel(spyPlaneCardVGroup).SetText("Minimum Pieces: " .. Mod.Settings.SpyPlaneMinPieces);
        UI.CreateLabel(spyPlaneCardVGroup).SetText("Initial Pieces: " .. Mod.Settings.SpyPlaneInitialPieces);
    end

    if(Mod.Settings.IncludeFlakGunCard) then
        local flakGunCardVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
        UI.CreateLabel(flakGunCardVGroup).SetText("Flak Gun Card:").SetColor(BUTTON_COLOURS.L);

        UI.CreateLabel(flakGunCardVGroup).SetText("Number of Pieces: " .. Mod.Settings.FlakGunNumPieces);
        UI.CreateLabel(flakGunCardVGroup).SetText("Card Weight: " .. Mod.Settings.FlakGunCardWeight);
        UI.CreateLabel(flakGunCardVGroup).SetText("Minimum Pieces: " .. Mod.Settings.FlakGunMinPieces);
        UI.CreateLabel(flakGunCardVGroup).SetText("Initial Pieces: " .. Mod.Settings.FlakGunInitialPieces);
    end
end
