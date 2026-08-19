require("Utilities");

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(descriptionVGroup).SetText("Play the Corrupt Hand card and secretly select an enemy player to start corrupting their hand.");

    local modVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(modVGroup).SetText("Incubation:").SetColor(SUBHEADING_COLOUR);
    if (Mod.Settings.TurnsUntilCorruption == 0) then
        UI.CreateLabel(modVGroup).SetText("Target receives Corruption immediately");
    else
        UI.CreateLabel(modVGroup).SetText("Turns until Budding Corruption matures into Corruption: " .. Mod.Settings.TurnsUntilCorruption);
    end

    UI.CreateLabel(modVGroup).SetText("Corruption:").SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(modVGroup).SetText("Cards corrupted per turn, per active Corruption card: " .. Mod.Settings.CardsCorruptedPerTurnPerSource);

    UI.CreateLabel(modVGroup).SetText("Recovery:").SetColor(SUBHEADING_COLOUR);
    if (Mod.Settings.RecoveryAllowRandom) then
        UI.CreateLabel(modVGroup).SetText("Random: " .. ((Mod.Settings.RecoveryRandomPercent or 0) * 100) .. "% of pieces towards a random card from your corrupted pool");
    end
    if (Mod.Settings.RecoveryAllowPlayerSelected) then
        UI.CreateLabel(modVGroup).SetText("Player Selected: " .. ((Mod.Settings.RecoveryPlayerSelectedPercent or 0) * 100) .. "% of pieces towards a card of your choice from your corrupted pool");
    end
    UI.CreateLabel(modVGroup).SetText("Discarding a Corrupted card instead of playing it forfeits the recovery" .. (Mod.Settings.RecoveryAllowRandom and " (unless Random recovery is enabled, in which case a reduced amount is still recovered)" or "") .. ".");

    UI.CreateLabel(modVGroup).SetText("");

    UI.CreateLabel(modVGroup).SetText("Corrupt Hand Card:").SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(modVGroup).SetText("Number of Pieces: " .. Mod.Settings.NumPieces);
    UI.CreateLabel(modVGroup).SetText("Card Weight: " .. Mod.Settings.CardWeight);
    UI.CreateLabel(modVGroup).SetText("Minimum Pieces: " .. Mod.Settings.MinPieces);
    UI.CreateLabel(modVGroup).SetText("Initial Pieces: " .. Mod.Settings.InitialPieces);
end
