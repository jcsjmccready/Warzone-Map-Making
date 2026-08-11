---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID # Creates a custom card. Can be invoked multiple times to create multiple cards. Every invokation will return the CardID of the just created card, make sure to save this in the settings of your mod
function Client_SaveConfigureUI(alert, addCard)
    Mod.Settings.Version = CURRENT_SETTINGS_VERSION;

    Mod.Settings.IsAcquiringTypeCard = isAcquiringTypeCard.GetIsChecked();

    Mod.Settings.FoxholeDamagePercent = math.floor(foxholeDamagePercent.GetValue() * 100 + 0.5) / 100;
    if (Mod.Settings.FoxholeDamagePercent < 0 or Mod.Settings.FoxholeDamagePercent > 1) then
        alert("% of Bomb Card damage armies in a Foxhole take must be between 0 and 1");
        return;
    end

    Mod.Settings.FoxholeDestroyedOnBomb = foxholeDestroyedOnBomb.GetIsChecked();

    Mod.Settings.FoxholeHasDuration = foxholeHasDuration.GetIsChecked();
    if (Mod.Settings.FoxholeHasDuration) then
        Mod.Settings.FoxholeDurationTurns = foxholeDurationTurns.GetValue();
        if (Mod.Settings.FoxholeDurationTurns < 1) then
            alert("Number of turns until a Foxhole is removed must be at least 1");
            return;
        end
    end

    if (Mod.Settings.IsAcquiringTypeCard) then
        Mod.Settings.FoxholeNumPieces = foxholeNumPieces.GetValue();
        Mod.Settings.FoxholeCardWeight = foxholeCardWeight.GetValue();
        Mod.Settings.FoxholeMinPieces = foxholeMinPieces.GetValue();
        Mod.Settings.FoxholeInitialPieces = foxholeInitialPieces.GetValue();

        if (Mod.Settings.FoxholeNumPieces < 1) then
            alert("Number of Foxhole card pieces cannot be less than 1");
            return;
        end
        if (Mod.Settings.FoxholeCardWeight < 0) then
            alert("Foxhole card weight cannot be less than 0");
            return;
        end
        if (Mod.Settings.FoxholeMinPieces < 0) then
            alert("Minimum Foxhole card pieces cannot be less than 0");
            return;
        end
        if (Mod.Settings.FoxholeInitialPieces < 0) then
            alert("Initial Foxhole card pieces cannot be less than 0");
            return;
        end

        local foxholeCardID = addCard(
            "Foxhole Card",
            "Play this card and select a territory you control to build a Foxhole there. Armies in a Foxhole take reduced damage from Bomb Cards.",
            "FoxholeCard.png",
            Mod.Settings.FoxholeNumPieces,
            Mod.Settings.FoxholeMinPieces,
            Mod.Settings.FoxholeInitialPieces,
            Mod.Settings.FoxholeCardWeight);

        Mod.Settings.FoxholeCardID = foxholeCardID;
    else
        Mod.Settings.FoxholeCost = foxholeCost.GetValue();
        Mod.Settings.FoxholeMaxPerPlayer = foxholeMaxPerPlayer.GetValue();

        if (Mod.Settings.FoxholeCost < 0) then
            alert("Cost of a Foxhole cannot be less than 0");
            return;
        end
        if (Mod.Settings.FoxholeMaxPerPlayer < 1) then
            alert("Maximum Foxholes a player can own at once must be at least 1");
            return;
        end
    end
end
