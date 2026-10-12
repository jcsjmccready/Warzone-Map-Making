---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID # Creates a custom card. Can be invoked multiple times to create multiple cards. Every invokation will return the CardID of the just created card, make sure to save this in the settings of your mod
function Client_SaveConfigureUI(alert, addCard)

    Mod.Settings.NumPieces = numPieces.GetValue();
    Mod.Settings.CardWeight = math.floor(cardWeight.GetValue() * 100 + 0.5) / 100;
    Mod.Settings.MinPieces = minPieces.GetValue();
    Mod.Settings.InitialPieces = initialPieces.GetValue();
    Mod.Settings.BribeDuration = bribeDuration.GetValue();
    Mod.Settings.AllowTargetingSelf = allowTargetingSelf.GetIsChecked();
    Mod.Settings.MinimumIncomeGain = minimumIncomeGain.GetValue();
    Mod.Settings.IncreasedIncomePercentage = increasedIncomePercentage.GetValue();

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
    if (Mod.Settings.BribeDuration < 1) then
        alert("Number of turns the bribe lasts cannot be less than 1");
        return;
    end
    if (Mod.Settings.MinimumIncomeGain < 0) then
        alert("Minimum income gained per turn cannot be less than 0");
        return;
    end
    if (Mod.Settings.IncreasedIncomePercentage < 0) then
        alert("Percentage increased income gained cannot be less than 0");
        return;
    end

    local bribedSpyCardID = addCard(
        "Bribed Spy",
        "For " .. Mod.Settings.BribeDuration .. " turn(s), all players get and play a spy card on a target player.\nAdditionally, grant that player increased income.",
        "BribedSpyCard.png",
        Mod.Settings.NumPieces,
        Mod.Settings.MinPieces,
        Mod.Settings.InitialPieces,
        Mod.Settings.CardWeight,
        Mod.Settings.BribeDuration,
        WL.ActiveCardExpireBehaviorOptions.BeginningOfNextTurn);
    Mod.Settings.BribedSpyCardID = bribedSpyCardID;
end
