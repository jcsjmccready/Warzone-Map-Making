---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID # Creates a custom card. Can be invoked multiple times to create multiple cards. Every invokation will return the CardID of the just created card, make sure to save this in the settings of your mod
function Client_SaveConfigureUI(alert, addCard)
    Mod.Settings.TurnsUntilCorruption = turnsUntilCorruption.GetValue();
    if (Mod.Settings.TurnsUntilCorruption < 0) then
        alert("Turns until Budding Corruption matures cannot be less than 0");
        return;
    end

    Mod.Settings.CardsCorruptedPerTurnPerSource = cardsCorruptedPerTurn.GetValue();
    if (Mod.Settings.CardsCorruptedPerTurnPerSource < 1) then
        alert("Cards corrupted per turn cannot be less than 1");
        return;
    end

    Mod.Settings.RecoveryModeFullRandomCard = recoveryModeFullRandomCard.GetIsChecked();
    if (not Mod.Settings.RecoveryModeFullRandomCard) then
        Mod.Settings.PartialPiecesPercent = math.floor(partialPiecesPercent.GetValue() * 100 + 0.5) / 100;
        if (Mod.Settings.PartialPiecesPercent <= 0 or Mod.Settings.PartialPiecesPercent > 1) then
            alert("% of pieces returned must be greater than 0 and no more than 100");
            return;
        end
    end

    Mod.Settings.NumPieces = numPieces.GetValue();
    Mod.Settings.CardWeight = math.floor(cardWeight.GetValue() * 100 + 0.5) / 100;
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

    local corruptHandCardID = addCard(
        "Corrupt Hand",
        "Secretly select an enemy player. They will begin to have their hand corrupted, one card at a time, until you are discovered.",
        "CorruptHand.png",
        Mod.Settings.NumPieces,
        Mod.Settings.MinPieces,
        Mod.Settings.InitialPieces,
        Mod.Settings.CardWeight);
    Mod.Settings.CorruptHandCardID = corruptHandCardID;

    -- the three cards below are never earned normally (0 weight, 0 pieces per turn, 0 initial pieces); they are
    -- always handed out directly by the mod as a corruption progresses
    local buddingCorruptionCardID = addCard(
        "Budding Corruption",
        "Someone is secretly corrupting your hand. In " .. Mod.Settings.TurnsUntilCorruption .. " turn(s) this will mature into Corruption. Discard it to stop the corruption from spreading further, though any cards already corrupted must still be played to recover them.",
        "BuddingCorruption.png",
        1, 0, 0, 0);
    Mod.Settings.BuddingCorruptionCardID = buddingCorruptionCardID;

    local corruptionCardID = addCard(
        "Corruption",
        "One of your other cards is corrupted at the end of every turn while you hold this card. Discard it to stop the corruption from spreading further, though any cards already corrupted must still be played to recover them.",
        "Corruption.png",
        1, 0, 0, 0);
    Mod.Settings.CorruptionCardID = corruptionCardID;

    local corruptedCardID = addCard(
        "Corrupted",
        "One of your cards, corrupted. Play it to recover what was lost.",
        "Corrupted.png",
        1, 0, 0, 0);
    Mod.Settings.CorruptedCardID = corruptedCardID;
end
