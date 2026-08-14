---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID # Creates a custom card. Can be invoked multiple times to create multiple cards. Every invokation will return the CardID of the just created card, make sure to save this in the settings of your mod
function Client_SaveConfigureUI(alert, addCard)
    Mod.Settings.Version = CURRENT_SETTINGS_VERSION;

    Mod.Settings.IsAcquiringTypeCard = isAcquiringTypeCard.GetIsChecked();

    Mod.Settings.BombShelterDamagePercent = math.floor(bombShelterDamagePercent.GetValue() * 100 + 0.5) / 100;
    if (Mod.Settings.BombShelterDamagePercent < 0 or Mod.Settings.BombShelterDamagePercent > 1) then
        alert("% of Bomb Card damage armies in a Bomb Shelter take must be between 0 and 1");
        return;
    end

    Mod.Settings.BombShelterDestroyedOnBomb = bombShelterDestroyedOnBomb.GetIsChecked();

    Mod.Settings.BombShelterHasDuration = bombShelterHasDuration.GetIsChecked();
    if (Mod.Settings.BombShelterHasDuration) then
        Mod.Settings.BombShelterDurationTurns = bombShelterDurationTurns.GetValue();
        if (Mod.Settings.BombShelterDurationTurns < 1) then
            alert("Number of turns until a Bomb Shelter is removed must be at least 1");
            return;
        end
    end

    if (Mod.Settings.IsAcquiringTypeCard) then
        Mod.Settings.BombShelterNumPieces = bombShelterNumPieces.GetValue();
        Mod.Settings.BombShelterCardWeight = bombShelterCardWeight.GetValue();
        Mod.Settings.BombShelterMinPieces = bombShelterMinPieces.GetValue();
        Mod.Settings.BombShelterInitialPieces = bombShelterInitialPieces.GetValue();

        if (Mod.Settings.BombShelterNumPieces < 1) then
            alert("Number of Bomb Shelter card pieces cannot be less than 1");
            return;
        end
        if (Mod.Settings.BombShelterCardWeight < 0) then
            alert("Bomb Shelter card weight cannot be less than 0");
            return;
        end
        if (Mod.Settings.BombShelterMinPieces < 0) then
            alert("Minimum Bomb Shelter card pieces cannot be less than 0");
            return;
        end
        if (Mod.Settings.BombShelterInitialPieces < 0) then
            alert("Initial Bomb Shelter card pieces cannot be less than 0");
            return;
        end

        local bombShelterCardID = addCard(
            "Bomb Shelter Card",
            "Creates a Bomb Shelter on a target friendly territory at the end of the turn. Armies in a Bomb Shelter take reduced damage from Bomb Cards.",
            "BombShelterCard.png",
            Mod.Settings.BombShelterNumPieces,
            Mod.Settings.BombShelterMinPieces,
            Mod.Settings.BombShelterInitialPieces,
            Mod.Settings.BombShelterCardWeight);

        Mod.Settings.BombShelterCardID = bombShelterCardID;
    else
        Mod.Settings.BombShelterCost = bombShelterCost.GetValue();
        Mod.Settings.BombShelterMaxPerPlayer = bombShelterMaxPerPlayer.GetValue();

        if (Mod.Settings.BombShelterCost < 0) then
            alert("Cost of a Bomb Shelter cannot be less than 0");
            return;
        end
        if (Mod.Settings.BombShelterMaxPerPlayer < 1) then
            alert("Maximum Bomb Shelters a player can own at once must be at least 1");
            return;
        end
    end
end
