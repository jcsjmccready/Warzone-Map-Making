---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID # Creates a custom card. Can be invoked multiple times to create multiple cards. Every invokation will return the CardID of the just created card, make sure to save this in the settings of your mod
function Client_SaveConfigureUI(alert, addCard)

    Mod.Settings.NumPieces = numPieces.GetValue();
    Mod.Settings.CardWeight = cardWeight.GetValue();
    Mod.Settings.MinPieces = minPieces.GetValue();
    Mod.Settings.InitialPieces = initialPieces.GetValue();
    Mod.Settings.CardDuration = cardDuration.GetValue();
    Mod.Settings.NeutralArmyGivesVision = neutralArmyGivesVision.GetIsChecked();
    if (Mod.Settings.NeutralArmyGivesVision) then
        Mod.Settings.VisionMethodFreeReconCard = visionMethodFreeReconCard.GetIsChecked();
        Mod.Settings.VisionMethodManual = visionMethodManual.GetIsChecked();
    end
    Mod.Settings.ArmyAmountEntireArmy = armyAmountEntireArmy.GetIsChecked();
    Mod.Settings.ArmyAmountInputTroops = armyAmountInputTroops.GetIsChecked();

    if (Mod.Settings.CardDuration < 1) then
        alert("Number of turns you can issue neutral orders for cannot be less than 1");
        return;
    end
    if (Mod.Settings.NumPieces < 1) then
        alert("Number of card pieces cannot be less than 1");
        return;
    end
    if (Mod.Settings.CardWeight < 0) then
        alert("Card weight cannot be less than 0");
        return;
    end
    if (Mod.Settings.MinPieces < 0) then
        alert("Minimum card pieces cannot be less than 0");
        return;
    end
    if (Mod.Settings.InitialPieces < 0) then
        alert("Initial card pieces cannot be less than 0");
        return;
    end

    local commandNeutralCardID = addCard(
        "Order Neutral Card",
        "Play this card to create an attack/transfer order for a neutral territory",
        "OrderNeutral.png",
        Mod.Settings.NumPieces, 
        Mod.Settings.MinPieces,
        Mod.Settings.InitialPieces,
        Mod.Settings.CardWeight);

    local temporaryCommandNeutralCardID = addCard(
        "Temp. Order Neutral Card",
        "Play this card to create an attack/transfer order for a neutral territory. Discards at the end of the turn if unused.",
        "TemporaryOrderNeutral.png",
        1, 
        0,
        0,
        0);

    Mod.Settings.CardID = commandNeutralCardID;
    Mod.Settings.TemporaryCardID = temporaryCommandNeutralCardID;
end