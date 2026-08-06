---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID # Creates a custom card. Can be invoked multiple times to create multiple cards. Every invokation will return the CardID of the just created card, make sure to save this in the settings of your mod
function Client_SaveConfigureUI(alert, addCard)
    Mod.Settings.FlatIncomeGained = flatIncomeGained.GetValue();
    Mod.Settings.PercentIncomeGained = math.floor(percentIncomeGained.GetValue() * 100 + 0.5) / 100;
    Mod.Settings.MinimumIncomeGained = minimumIncomeGained.GetValue();

    if (Mod.Settings.FlatIncomeGained < 0) then
        alert("Flat income gained cannot be less than 0");
        return;
    end
    if (Mod.Settings.PercentIncomeGained < 0 or Mod.Settings.PercentIncomeGained > 1) then
        alert("% of bonus of income gained must be between 0 and 1");
        return;
    end
    if (Mod.Settings.MinimumIncomeGained < 0) then
        alert("Minimum income gained cannot be less than 0");
        return;
    end

    Mod.Settings.FlatValueDecrease = flatValueDecrease.GetValue();
    Mod.Settings.PercentValueDecrease = math.floor(percentValueDecrease.GetValue() * 100 + 0.5) / 100;
    Mod.Settings.MinimumValueDecrease = minimumValueDecrease.GetValue();

    if (Mod.Settings.FlatValueDecrease < 0) then
        alert("Flat value to decrease bonus by cannot be less than 0");
        return;
    end
    if (Mod.Settings.PercentValueDecrease < 0 or Mod.Settings.PercentValueDecrease > 1) then
        alert("% to decrease bonus by must be between 0 and 1");
        return;
    end
    if (Mod.Settings.MinimumValueDecrease < 0) then
        alert("Minimum bonus value decrease cannot be less than 0");
        return;
    end

    Mod.Settings.NeutraliseFullyConscripted = neutraliseFullyConscripted.GetIsChecked();
    if (Mod.Settings.NeutraliseFullyConscripted) then
        Mod.Settings.NeutralisePercentPerTurn = math.floor(neutralisePercentPerTurn.GetValue() * 100 + 0.5) / 100;

        if (Mod.Settings.NeutralisePercentPerTurn < 0 or Mod.Settings.NeutralisePercentPerTurn > 1) then
            alert("% of applicable territories to neutralise per turn must be between 0 and 1");
            return;
        end
    end

    Mod.Settings.ConscriptionNumPieces = conscriptionNumPieces.GetValue();
    Mod.Settings.ConscriptionCardWeight = conscriptionCardWeight.GetValue();
    Mod.Settings.ConscriptionMinPieces = conscriptionMinPieces.GetValue();
    Mod.Settings.ConscriptionInitialPieces = conscriptionInitialPieces.GetValue();

    if (Mod.Settings.ConscriptionNumPieces < 1) then
        alert("Number of Conscription card pieces cannot be less than 1");
        return;
    end
    if (Mod.Settings.ConscriptionCardWeight < 0) then
        alert("Conscription card weight cannot be less than 0");
        return;
    end
    if (Mod.Settings.ConscriptionMinPieces < 0) then
        alert("Minimum Conscription card pieces cannot be less than 0");
        return;
    end
    if (Mod.Settings.ConscriptionInitialPieces < 0) then
        alert("Initial Conscription card pieces cannot be less than 0");
        return;
    end

    local conscriptionCardId = addCard(
        "Conscription Card",
        "Play this card and select a bonus you fully control. If you still fully control it at the end of the turn, its value is permanently reduced and you receive a one-turn boost to your income.",
        "ConscriptionCard.png",
        Mod.Settings.ConscriptionNumPieces,
        Mod.Settings.ConscriptionMinPieces,
        Mod.Settings.ConscriptionInitialPieces,
        Mod.Settings.ConscriptionCardWeight);

    Mod.Settings.ConscriptionCardID = conscriptionCardId;
end
