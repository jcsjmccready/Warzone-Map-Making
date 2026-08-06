require('Utilities')

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateLabel(descriptionVGroup).SetText("Play the Bribed Spy card on a target player, granting them additional income but all other players play a free spy card against them while the card is in effect.");
    if (Mod.Settings.AllowTargetingSelf) then
        UI.CreateLabel(descriptionVGroup).SetText("Players are allowed to bribe themselves.");
    end

    UI.CreateVerticalLayoutGroup(rootParent);

    local cardVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(cardVGroup).SetText("Bribed Spy Card:").SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(cardVGroup).SetText("Number of Pieces: " .. Mod.Settings.NumPieces);
    UI.CreateLabel(cardVGroup).SetText("Card Weight: " .. Mod.Settings.CardWeight);
    UI.CreateLabel(cardVGroup).SetText("Minimum Pieces: " .. Mod.Settings.MinPieces);
    UI.CreateLabel(cardVGroup).SetText("Initial Pieces: " .. Mod.Settings.InitialPieces);
    UI.CreateLabel(cardVGroup).SetText("Bribe Duration: " .. Mod.Settings.BribeDuration .. " turn(s)");

    UI.CreateVerticalLayoutGroup(rootParent);

    local incomeVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(incomeVGroup).SetText("Bribed Player Income:").SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(incomeVGroup).SetText("Minimum income gained per turn: " .. Mod.Settings.MinimumIncomeGain);
    UI.CreateLabel(incomeVGroup).SetText("Increased income: " .. Mod.Settings.IncreasedIncomePercentage .. "%");
end
