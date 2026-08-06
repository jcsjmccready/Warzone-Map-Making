require('Utilities')

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(descriptionVGroup).SetText("Play the Conscription Card and pick a bonus you fully control. If you still fully control it at the end of the turn, its value is permanently reduced and you receive a one-turn boost to your income.");

    local modVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(modVGroup).SetText("Conscription Card:").SetColor(SUBHEADING_COLOUR);

    UI.CreateLabel(modVGroup).SetText("Income Gained This Turn:").SetColor(BUTTON_COLOURS.DarkGray);
    UI.CreateLabel(modVGroup).SetText("Flat: " .. (Mod.Settings.FlatIncomeGained or 0));
    UI.CreateLabel(modVGroup).SetText("% of bonus value: " .. ((Mod.Settings.PercentIncomeGained or 0) * 100) .. "%");
    UI.CreateLabel(modVGroup).SetText("Minimum: " .. (Mod.Settings.MinimumIncomeGained or 0));

    UI.CreateLabel(modVGroup).SetText("Permanent Bonus Value Decrease:").SetColor(BUTTON_COLOURS.DarkGray);
    UI.CreateLabel(modVGroup).SetText("Flat: " .. (Mod.Settings.FlatValueDecrease or 0));
    UI.CreateLabel(modVGroup).SetText("%: " .. ((Mod.Settings.PercentValueDecrease or 0) * 100) .. "%");
    UI.CreateLabel(modVGroup).SetText("Minimum: " .. (Mod.Settings.MinimumValueDecrease or 0));

    UI.CreateLabel(modVGroup).SetText("Fully conscripted bonuses slowly neutralise if unoccupied: " .. tostring(Mod.Settings.NeutraliseFullyConscripted or false));
    if (Mod.Settings.NeutraliseFullyConscripted) then
        UI.CreateLabel(modVGroup).SetText("% of applicable territories neutralised per turn: " .. ((Mod.Settings.NeutralisePercentPerTurn or 0) * 100) .. "%");
    end

    UI.CreateLabel(modVGroup).SetText("");

    UI.CreateLabel(modVGroup).SetText("Number of Pieces: " .. (Mod.Settings.ConscriptionNumPieces or 0));
    UI.CreateLabel(modVGroup).SetText("Card Weight: " .. (Mod.Settings.ConscriptionCardWeight or 0));
    UI.CreateLabel(modVGroup).SetText("Minimum Pieces: " .. (Mod.Settings.ConscriptionMinPieces or 0));
    UI.CreateLabel(modVGroup).SetText("Initial Pieces: " .. (Mod.Settings.ConscriptionInitialPieces or 0));
end
