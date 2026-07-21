require('Utilities')

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)

    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateLabel(descriptionVGroup).SetText("Grants the ability to issue a attack/transfer order by playing a card.");

    UI.CreateVerticalLayoutGroup(rootParent);

    local modVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(modVGroup).SetText("Mod Behaviour:").SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(modVGroup).SetText("Number of turns you can issue a neutral order for: " .. Mod.Settings.CardDuration);

    if (Mod.Settings.NeutralArmyGivesVision) then
        if (Mod.Settings.VisionMethodManual) then
            UI.CreateLabel(modVGroup).SetText("Neutral army gives vision: Mod gives vision manually");
        elseif (Mod.Settings.VisionMethodFreeReconCard)  then
            UI.CreateLabel(modVGroup).SetText("Neutral army gives vision: Play free recon card");
        end
    end

    if (Mod.Settings.ArmyAmountInputTroops) then
        UI.CreateLabel(modVGroup).SetText("You can specify the number of troops sent in the attack/transfer");
    end
    if (Mod.Settings.ArmyAmountEntireArmy) then
        UI.CreateLabel(modVGroup).SetText("The entire army is sent on attack/transfers");
    end

    local cardVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateLabel(cardVGroup).SetText("Card Settings:").SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(cardVGroup).SetText("Number of Pieces: " .. Mod.Settings.NumPieces);
    UI.CreateLabel(cardVGroup).SetText("Card Weight: " .. Mod.Settings.CardWeight);
    UI.CreateLabel(cardVGroup).SetText("Minimum Pieces: " .. Mod.Settings.MinPieces);
    UI.CreateLabel(cardVGroup).SetText("Initial Pieces: " .. Mod.Settings.InitialPieces);
end