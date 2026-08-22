require("Utilities");

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(descriptionVGroup).SetText("This mod adds the Corrupt Hand card which provides the ability to block players from playing their cards if they are inattentive.");

    local modVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    if (Mod.Settings.TurnsUntilCorruption == 0) then
        UI.CreateLabel(modVGroup).SetText("Playing a Corrupt Hand card gives the target player a Corruption card immediately.");
    else
        UI.CreateLabel(modVGroup).SetText("Playing a Corrupt Hand card gives the target player a Budding Corruption, that matures into an active Corruption after " .. Mod.Settings.TurnsUntilCorruption .. " turns.");
    end
    UI.CreateLabel(modVGroup).SetText("At the end of a turn, if a Corruption Card is in a players hand (including the turn it enters their hand), it corrupts " .. Mod.Settings.CardsCorruptedPerTurnPerSource .. " cards.");

    UI.CreateLabel(modVGroup).SetText("Playing a corrupted card:").SetColor(SUBHEADING_COLOUR);
    if (Mod.Settings.RecoveryAllowRandom) then
        UI.CreateLabel(modVGroup).SetText("Allows the option to recover " .. ((Mod.Settings.RecoveryRandomPercent or 0) * 100) .. "% of pieces towards a random card from your corrupted pool");
    end
    if (Mod.Settings.RecoveryAllowPlayerSelected) then
        UI.CreateLabel(modVGroup).SetText("Allows the option to recover " .. ((Mod.Settings.RecoveryPlayerSelectedPercent or 0) * 100) .. "% of pieces towards a card of your choice from your corrupted pool");
    end
    UI.CreateLabel(modVGroup).SetText("Discarding a Corrupted card instead of playing it forfeits the recovery" .. (Mod.Settings.RecoveryAllowRandom and " (unless Random recovery is enabled, in which case the random option is chosen)" or "") .. ".");

    UI.CreateLabel(modVGroup).SetText("");

    UI.CreateLabel(modVGroup).SetText("Corrupt Hand Card:").SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(modVGroup).SetText("Number of Pieces: " .. Mod.Settings.NumPieces);
    UI.CreateLabel(modVGroup).SetText("Card Weight: " .. Mod.Settings.CardWeight);
    UI.CreateLabel(modVGroup).SetText("Minimum Pieces: " .. Mod.Settings.MinPieces);
    UI.CreateLabel(modVGroup).SetText("Initial Pieces: " .. Mod.Settings.InitialPieces);
end
