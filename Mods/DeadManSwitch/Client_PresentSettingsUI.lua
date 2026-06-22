---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    local damageTypeMessage = "ERROR";

    if(Mod.Settings.isDamageTypeBomb) then
        damageTypeMessage = "a bomb is played on it.";
    end

    if(Mod.Settings.isDamageTypeFlat) then
        damageTypeMessage = Mod.Settings.FlatDamage .. " armies are killed.";
    end

    if(Mod.Settings.isDamageTypePercent) then
        damageTypeMessage = "it takes " .. math.floor(Mod.Settings.PercentageDamage * 100) .. "% damage, with a minimum of " .. Mod.Settings.PercentageMinDamage .. " armies killed.";
    end

    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateLabel(descriptionVGroup).SetText("If a territory containing a Dead Man's Switch is taken, afterwards, " .. damageTypeMessage);

    if(Mod.Settings.AllyTriggers) then
        UI.CreateLabel(descriptionVGroup).SetText("Any allies can trigger then Dead Man's Switch");
        else
        UI.CreateLabel(descriptionVGroup).SetText("Any allies can not trigger then Dead Man's Switch");
    end

    UI.CreateVerticalLayoutGroup(rootParent);

    if(Mod.Settings.isAcquiringTypeCard) then
        local cardVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

        UI.CreateLabel(cardVGroup).SetText("Dead Man's Switch Card:");
        UI.CreateLabel(cardVGroup).SetText("Number of Pieces: " .. Mod.Settings.NumPieces);
        UI.CreateLabel(cardVGroup).SetText("Card Weight: " .. Mod.Settings.CardWeight);
        UI.CreateLabel(cardVGroup).SetText("Minimum Pieces: " .. Mod.Settings.MinPieces);
        UI.CreateLabel(cardVGroup).SetText("Initial Pieces: " .. Mod.Settings.InitialPieces);
    end

    if(Mod.Settings.isAcquiringTypeCommerce) then
        local cardVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

        UI.CreateLabel(cardVGroup).SetText("Building Dead Man's Switch:");
        UI.CreateLabel(cardVGroup).SetText("Cost: " .. Mod.Settings.CommerceCost);
        UI.CreateLabel(cardVGroup).SetText("Concurrent DMS Limit: " .. Mod.Settings.ConcurrentDMSLimit);
    end
end