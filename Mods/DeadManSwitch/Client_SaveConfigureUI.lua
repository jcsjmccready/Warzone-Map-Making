require("Utilities");

---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID # Creates a custom card. Can be invoked multiple times to create multiple cards. Every invokation will return the CardID of the just created card, make sure to save this in the settings of your mod
function Client_SaveConfigureUI(alert, addCard)

    local damageTypeMessage = "ERROR";

    Mod.Settings.isDamageTypeBomb = isDamageTypeBomb.GetIsChecked();
    if(Mod.Settings.isDamageTypeBomb) then
        damageTypeMessage = "a bomb is automatically played on it.";
    end

    Mod.Settings.isDamageTypeFlat = isDamageTypeFlat.GetIsChecked();
    if(Mod.Settings.isDamageTypeFlat) then
        Mod.Settings.FlatDamage = flatDamage.GetValue();
        damageTypeMessage = Mod.Settings.FlatDamage .. " armies are killed.";
    end

    Mod.Settings.isDamageTypePercent = isDamageTypePercent.GetIsChecked();
    if(Mod.Settings.isDamageTypePercent) then
        Mod.Settings.PercentageDamage = percentageDamage.GetValue();
        Mod.Settings.PercentageMinDamage = percentageMinDamage.GetValue();
        damageTypeMessage = math.floor(Mod.Settings.PercentageDamage * 100) .. "% of the armies (with a minimum of " .. Mod.Settings.PercentageMinDamage .. " armies) are killed.";
    end

    Mod.Settings.isDamageTypeBlockade = isDamageTypeBlockade.GetIsChecked();
    if(Mod.Settings.isDamageTypeBlockade) then
        damageTypeMessage = "a blockade card is automatically played on it.";
    end

    Mod.Settings.isDamageTypeEmergencyBlockade = isDamageTypeEmergencyBlockade.GetIsChecked();
    if(Mod.Settings.isDamageTypeEmergencyBlockade) then
        damageTypeMessage = "an emergency blockade card is automatically played on it.";
    end

    Mod.Settings.isDamageTypeGift = isDamageTypeGift.GetIsChecked();
    if(Mod.Settings.isDamageTypeGift) then
        Mod.Settings.GiftRecipientType = giftRecipientDefender.GetIsChecked() and "Defender" or "RandomPlayer";
        if(Mod.Settings.GiftRecipientType == "Defender") then
            damageTypeMessage = "a gift card is automatically played, gifting it back to its previous owner.";
        else
            damageTypeMessage = "a gift card is automatically played, gifting it to a random other player.";
        end
    end

    Mod.Settings.isDamageTypeSanction = isDamageTypeSanction.GetIsChecked();
    Mod.Settings.isDamageTypeDiplomacy = isDamageTypeDiplomacy.GetIsChecked();
    Mod.Settings.isDamageTypeSpy = isDamageTypeSpy.GetIsChecked();

    Mod.Settings.isDamageTypeGrantIncome = isDamageTypeGrantIncome.GetIsChecked();
    if(Mod.Settings.isDamageTypeGrantIncome) then
        Mod.Settings.GrantIncomeFlat = grantIncomeFlat.GetValue();
        Mod.Settings.GrantIncomePercent = grantIncomePercent.GetValue();
        Mod.Settings.GrantIncomeMinimumPercent = grantIncomeMinimumPercent.GetValue();
        Mod.Settings.GrantIncomeSteal = grantIncomeSteal.GetIsChecked();

        if (Mod.Settings.GrantIncomeFlat < 0) then
            alert("Flat Income cannot be less than 0");
            return;
        end
        if (Mod.Settings.GrantIncomePercent < 0) then
            alert("% Income cannot be less than 0");
            return;
        end
        if (Mod.Settings.GrantIncomeMinimumPercent < 0) then
            alert("Minimum % Amount cannot be less than 0");
            return;
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
        local incomeMessage = "its previous owner is granted " .. Mod.Settings.GrantIncomeFlat .. " + " .. math.floor(Mod.Settings.GrantIncomePercent * 100) .. "% of their own income (minimum " .. Mod.Settings.GrantIncomeMinimumPercent .. ")";
        if(Mod.Settings.GrantIncomeSteal) then
            incomeMessage = incomeMessage .. ", stolen from the attacker";
        end
        table.insert(additionalActions, incomeMessage);
    end

    if(#additionalActions > 0) then
        damageTypeMessage = damageTypeMessage .. " Additionally, " .. JoinWithAnd(additionalActions) .. ".";
    end

    Mod.Settings.AllyTriggers = allyTriggers.GetIsChecked();

    Mod.Settings.isAcquiringTypeCard = isAcquiringTypeCard.GetIsChecked();
    if(Mod.Settings.isAcquiringTypeCard) then
        Clear_Commerce_Settings();

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

    local dmsCardID = addCard("Dead Man's Switch Card",
        "Play this card to create a Dead Man's Switch on any territory you control (at the end of the turn). If this territory is successfully captured, afterwards, " .. damageTypeMessage,
        "DmsCard.png",
        Mod.Settings.NumPieces,
        Mod.Settings.MinPieces,
        Mod.Settings.InitialPieces,
        Mod.Settings.CardWeight);

    Mod.Settings.DeadManSwitchCardID = dmsCardID;
    else
        Clear_Card_Settings();

        Mod.Settings.Cost = dmsCost.GetValue();
        Mod.Settings.MaxPerPlayer = dmsMaxPerPlayer.GetValue();

        if (Mod.Settings.Cost < 0) then
            alert("Cost of a Dead Man's Switch cannot be less than 0");
            return;
        end
        if (Mod.Settings.MaxPerPlayer < 1) then
            alert("Maximum Dead Man's Switches a player can own at once must be at least 1");
            return;
        end
    end
end

function Clear_Card_Settings()
    Mod.Settings.NumPieces = nil;
    Mod.Settings.CardWeight = nil;
    Mod.Settings.MinPieces = nil;
    Mod.Settings.InitialPieces = nil;
    Mod.Settings.DeadManSwitchCardID = nil;
end

function Clear_Commerce_Settings()
    Mod.Settings.Cost = nil;
    Mod.Settings.MaxPerPlayer = nil;
end

