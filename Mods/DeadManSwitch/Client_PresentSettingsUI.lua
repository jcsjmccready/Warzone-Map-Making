require("Utilities");

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    local damageTypeMessage = "ERROR";

    if(Mod.Settings.isDamageTypeBomb) then
        damageTypeMessage = "a bomb is automatically played on it.";
    end

    if(Mod.Settings.isDamageTypeFlat) then
        damageTypeMessage = Mod.Settings.FlatDamage .. " armies are killed.";
    end

    if(Mod.Settings.isDamageTypePercent) then
        damageTypeMessage = math.floor(Mod.Settings.PercentageDamage * 100) .. "% of the armies (with a minimum of " .. Mod.Settings.PercentageMinDamage .. " armies) are killed.";
    end

    if(Mod.Settings.isDamageTypeBlockade) then
        damageTypeMessage = "a blockade card is automatically played on it.";
    end

    if(Mod.Settings.isDamageTypeEmergencyBlockade) then
        damageTypeMessage = "an emergency blockade card is automatically played on it.";
    end

    if(Mod.Settings.isDamageTypeGift) then
        if(Mod.Settings.GiftRecipientType == "Defender") then
            damageTypeMessage = "a gift card is automatically played, gifting it back to its previous owner.";
        else
            damageTypeMessage = "a gift card is automatically played, gifting it to a random other player.";
        end
    end

    local additionalActions = {};
    if(Mod.Settings.isDamageTypeSanction) then
        table.insert(additionalActions, "a sanction card is automatically played on its owner");
    end
    if(Mod.Settings.isDamageTypeDiplomacy) then
        table.insert(additionalActions, "a diplomacy card is automatically played between the attacker and defender");
    end
    if(Mod.Settings.isDamageTypeSpy) then
        table.insert(additionalActions, "a spy card is automatically played on the attacker");
    end
    if(Mod.Settings.isDamageTypeGrantIncome) then
        local incomeMessage = "its previous owner is granted " .. (Mod.Settings.GrantIncomeFlat or 0) .. " + " .. math.floor((Mod.Settings.GrantIncomePercent or 0) * 100) .. "% of their own income (minimum " .. (Mod.Settings.GrantIncomeMinimumPercent or 0) .. ")";
        if(Mod.Settings.GrantIncomeSteal) then
            incomeMessage = incomeMessage .. ", stolen from the attacker";
        end
        table.insert(additionalActions, incomeMessage);
    end

    if(#additionalActions > 0) then
        damageTypeMessage = damageTypeMessage .. " Additionally, " .. JoinWithAnd(additionalActions) .. ".";
    end

    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateLabel(descriptionVGroup).SetText("If a territory containing a Dead Man's Switch is successfully captured, afterwards, it is destroyed and " .. damageTypeMessage);

    if(Mod.Settings.AllyTriggers) then
        UI.CreateLabel(descriptionVGroup).SetText("Any allies can trigger then Dead Man's Switch");
        else
        UI.CreateLabel(descriptionVGroup).SetText("Any allies can not trigger then Dead Man's Switch");
    end

    UI.CreateVerticalLayoutGroup(rootParent);

    if(Mod.Settings.isAcquiringTypeCard) then
        local cardVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

        UI.CreateLabel(cardVGroup).SetText("Dead Man's Switches are acquired via the Dead Man's Switch Card:");
        UI.CreateLabel(cardVGroup).SetText("Number of Pieces: " .. Mod.Settings.NumPieces);
        UI.CreateLabel(cardVGroup).SetText("Card Weight: " .. Mod.Settings.CardWeight);
        UI.CreateLabel(cardVGroup).SetText("Minimum Pieces: " .. Mod.Settings.MinPieces);
        UI.CreateLabel(cardVGroup).SetText("Initial Pieces: " .. Mod.Settings.InitialPieces);
    else
        local commerceVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

        UI.CreateLabel(commerceVGroup).SetText("Dead Man's Switches are acquired via Commerce:");
        UI.CreateLabel(commerceVGroup).SetText("Cost: " .. (Mod.Settings.Cost or 0) .. " gold");
        UI.CreateLabel(commerceVGroup).SetText("Maximum Dead Man's Switches per player: " .. (Mod.Settings.MaxPerPlayer or 0));
    end
end