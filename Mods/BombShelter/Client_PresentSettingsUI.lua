require('Utilities')

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(descriptionVGroup).SetText("This mod adds Bomb Shelter structures. Armies in a territory with a Bomb Shelter take modified damage from Bomb Cards.");

    local modVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(modVGroup).SetText("Mod Behaviour:").SetColor(SUBHEADING_COLOUR);

    if (Mod.Settings.IsAcquiringTypeCard) then
        UI.CreateLabel(modVGroup).SetText("Bomb Shelters are acquired via the Bomb Shelter Card");
    else
        UI.CreateLabel(modVGroup).SetText("Bomb Shelters are acquired via Commerce");
        UI.CreateLabel(modVGroup).SetText("Cost: " .. (Mod.Settings.BombShelterCost or 0) .. " gold");
        UI.CreateLabel(modVGroup).SetText("Maximum Bomb Shelters per player: " .. (Mod.Settings.BombShelterMaxPerPlayer or 0));
    end

    UI.CreateLabel(modVGroup).SetText("");
    UI.CreateLabel(modVGroup).SetText("% damage Bomb Card deals to armies in a Bomb Shelter: " .. ((Mod.Settings.BombShelterDamagePercent or 0) * 100) .. "%");
    UI.CreateLabel(modVGroup).SetText("Bomb Shelter destroyed when bombed: " .. tostring(Mod.Settings.BombShelterDestroyedOnBomb or false));
    UI.CreateLabel(modVGroup).SetText("Bomb Shelter has a limited duration: " .. tostring(Mod.Settings.BombShelterHasDuration or false));
    if (Mod.Settings.BombShelterHasDuration) then
        UI.CreateLabel(modVGroup).SetText("Turns until a Bomb Shelter is removed: " .. (Mod.Settings.BombShelterDurationTurns or 0));
    end

    if (Mod.Settings.IsAcquiringTypeCard) then
        UI.CreateLabel(modVGroup).SetText("");
        UI.CreateLabel(modVGroup).SetText("Card Settings:").SetColor(SUBHEADING_COLOUR);
        UI.CreateLabel(modVGroup).SetText("Number of Pieces: " .. (Mod.Settings.BombShelterNumPieces or 0));
        UI.CreateLabel(modVGroup).SetText("Card Weight: " .. (Mod.Settings.BombShelterCardWeight or 0));
        UI.CreateLabel(modVGroup).SetText("Minimum Pieces: " .. (Mod.Settings.BombShelterMinPieces or 0));
        UI.CreateLabel(modVGroup).SetText("Initial Pieces: " .. (Mod.Settings.BombShelterInitialPieces or 0));
    end
end
