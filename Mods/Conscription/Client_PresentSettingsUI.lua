require('Utilities')

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(descriptionVGroup).SetText("This mod adds the Conscription Card. Play it and select a bonus you fully control. At the end of the turn, if you still own it, receive a one-time boost to your income and permanently reduce the value of the bonus.");
    UI.CreateLabel(descriptionVGroup).SetText("A bonus can eventually be fully conscripted down to nothing.");
    UI.CreateLabel(descriptionVGroup).SetText("Territories of a conscripted bonus will have structures added to them indicating to what extent they are conscripted.");
    UI.CreateLabel(descriptionVGroup).SetText("If a territory belongs to multiple conscripted bonuses, the most severe conscription indicator will be used.");

    local modVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(modVGroup).SetText("Mod Behaviour:").SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(modVGroup).SetText("Income Gained This Turn:");
    UI.CreateLabel(modVGroup).SetText("Flat: " .. (Mod.Settings.FlatIncomeGained or 0));
    UI.CreateLabel(modVGroup).SetText("% of bonus value: " .. ((Mod.Settings.PercentIncomeGained or 0) * 100) .. "%");
    UI.CreateLabel(modVGroup).SetText("Minimum from %: " .. (Mod.Settings.MinimumIncomeGained or 0));

    UI.CreateLabel(modVGroup).SetText("");
    UI.CreateLabel(modVGroup).SetText("Permanent Bonus Value Decrease:");
    UI.CreateLabel(modVGroup).SetText("Flat: " .. (Mod.Settings.FlatValueDecrease or 0));
    UI.CreateLabel(modVGroup).SetText("%: " .. ((Mod.Settings.PercentValueDecrease or 0) * 100) .. "%");
    UI.CreateLabel(modVGroup).SetText("Minimum from %: " .. (Mod.Settings.MinimumValueDecrease or 0));

    UI.CreateLabel(modVGroup).SetText("");
    UI.CreateLabel(modVGroup).SetText("Full Conscription Penalty:");
    UI.CreateLabel(modVGroup).SetText("Fully conscripted bonuses slowly neutralise if unoccupied: " .. tostring(Mod.Settings.NeutraliseFullyConscripted or false));
    if (Mod.Settings.NeutraliseFullyConscripted) then
        UI.CreateLabel(modVGroup).SetText("% of applicable territories neutralised per turn: " .. ((Mod.Settings.NeutralisePercentPerTurn or 0) * 100) .. "%");
    end

    UI.CreateLabel(modVGroup).SetText("");

    UI.CreateLabel(modVGroup).SetText("Card Settings:").SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(modVGroup).SetText("Number of Pieces: " .. (Mod.Settings.ConscriptionNumPieces or 0));
    UI.CreateLabel(modVGroup).SetText("Card Weight: " .. (Mod.Settings.ConscriptionCardWeight or 0));
    UI.CreateLabel(modVGroup).SetText("Minimum Pieces: " .. (Mod.Settings.ConscriptionMinPieces or 0));
    UI.CreateLabel(modVGroup).SetText("Initial Pieces: " .. (Mod.Settings.ConscriptionInitialPieces or 0));
end
