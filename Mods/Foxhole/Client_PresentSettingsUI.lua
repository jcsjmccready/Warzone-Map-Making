require('Utilities')

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    MigrateModSettings();

    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(descriptionVGroup).SetText("This mod adds Foxhole structures. Armies in a territory with a Foxhole take reduced damage from Bomb Cards.");

    local modVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(modVGroup).SetText("Mod Behaviour:").SetColor(SUBHEADING_COLOUR);

    if (Mod.Settings.IsAcquiringTypeCard) then
        UI.CreateLabel(modVGroup).SetText("Foxholes are acquired via the Foxhole Card");
    else
        UI.CreateLabel(modVGroup).SetText("Foxholes are acquired via Commerce");
        UI.CreateLabel(modVGroup).SetText("Cost: " .. (Mod.Settings.FoxholeCost or 0) .. " gold");
        UI.CreateLabel(modVGroup).SetText("Maximum Foxholes per player: " .. (Mod.Settings.FoxholeMaxPerPlayer or 0));
    end

    UI.CreateLabel(modVGroup).SetText("");
    UI.CreateLabel(modVGroup).SetText("% of Bomb Card damage armies in a Foxhole take: " .. ((Mod.Settings.FoxholeDamagePercent or 0) * 100) .. "%");
    UI.CreateLabel(modVGroup).SetText("Foxhole destroyed when bombed: " .. tostring(Mod.Settings.FoxholeDestroyedOnBomb or false));
    UI.CreateLabel(modVGroup).SetText("Foxhole has a limited duration: " .. tostring(Mod.Settings.FoxholeHasDuration or false));
    if (Mod.Settings.FoxholeHasDuration) then
        UI.CreateLabel(modVGroup).SetText("Turns until a Foxhole is removed: " .. (Mod.Settings.FoxholeDurationTurns or 0));
    end

    if (Mod.Settings.IsAcquiringTypeCard) then
        UI.CreateLabel(modVGroup).SetText("");
        UI.CreateLabel(modVGroup).SetText("Card Settings:").SetColor(SUBHEADING_COLOUR);
        UI.CreateLabel(modVGroup).SetText("Number of Pieces: " .. (Mod.Settings.FoxholeNumPieces or 0));
        UI.CreateLabel(modVGroup).SetText("Card Weight: " .. (Mod.Settings.FoxholeCardWeight or 0));
        UI.CreateLabel(modVGroup).SetText("Minimum Pieces: " .. (Mod.Settings.FoxholeMinPieces or 0));
        UI.CreateLabel(modVGroup).SetText("Initial Pieces: " .. (Mod.Settings.FoxholeInitialPieces or 0));
    end
end
