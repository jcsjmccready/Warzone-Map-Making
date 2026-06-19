function Client_SaveConfigureUI(alert, addCard)

    Mod.Settings.isAcquiringTypeCard = isAcquiringTypeCard.GetIsChecked();
    if(Mod.Settings.isAcquiringTypeCard) then
        Mod.Settings.NumPieces = numPieces.GetValue();
        Mod.Settings.CardWeight = cardWeight.GetValue();
        Mod.Settings.MinPieces = minPieces.GetValue();
        Mod.Settings.InitialPieces = initialPieces.GetValue();

        if (Mod.Settings.NumPieces < 1) then
            alert("Number of pieces cannot be less than 1");
            return;
        end
        if (Mod.Settings.CardWeight < 0) then
            alert("Card weight cannot be less than 0");
            return;
        end
        if (Mod.Settings.MinPieces < 0) then
            alert("Minimum pieces cannot be less than 0");
            return;
        end
        if (Mod.Settings.InitialPieces < 0) then
            alert("Initial pieces cannot be less than 0");
            return;
        end

    addCard("Dead Man's Switch Card", "Play this card to create a Dead Man's Switch on any territory you control (at the end of the turn). If this territory is taken, a bomb is played on it.", "DmsCard.png", Mod.Settings.NumPieces, Mod.Settings.MinPieces, Mod.Settings.InitialPieces, Mod.Settings.CardWeight);
    end

    Mod.Settings.isAcquiringTypeCommerce = isAcquiringTypeCommerce.GetIsChecked();

    Mod.Settings.isDamageTypeBomb = isDamageTypeBomb.GetIsChecked();

    Mod.Settings.isDamageTypeFlat = isDamageTypeFlat.GetIsChecked();
    if(Mod.Settings.isDamageTypeFlat) then
        Mod.Settings.FlatDamage = flatDamage.GetValue();
    end

    Mod.Settings.isDamageTypePercent = isDamageTypePercent.GetIsChecked();
    if(Mod.Settings.isDamageTypePercent) then
        Mod.Settings.PercentageDamage = percentageDamage.GetValue();
        Mod.Settings.PercentageMinDamage = percentageMinDamage.GetValue();
    end

    -- Mod.Settings.AllyTriggers = allyTriggers.GetIsChecked();
end

