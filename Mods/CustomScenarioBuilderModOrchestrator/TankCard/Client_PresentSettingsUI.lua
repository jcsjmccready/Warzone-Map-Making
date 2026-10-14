require("Utilities");

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    local modVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(modVGroup).SetText("This mod adds a Tank Card. Play it on a territory you control to build a Tank there at the end of the turn.");
    UI.CreateLabel(modVGroup).SetText("Number of Pieces: " .. tostring(Mod.Settings.NumPieces));
    UI.CreateLabel(modVGroup).SetText("Card Weight: " .. tostring(Mod.Settings.CardWeight));
    UI.CreateLabel(modVGroup).SetText("Minimum Pieces: " .. tostring(Mod.Settings.MinPieces));
    UI.CreateLabel(modVGroup).SetText("Initial Pieces: " .. tostring(Mod.Settings.InitialPieces));
end
