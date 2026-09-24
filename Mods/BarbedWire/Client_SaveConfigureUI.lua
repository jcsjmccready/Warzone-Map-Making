---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID # Creates a custom card. Can be invoked multiple times to create multiple cards. Every invokation will return the CardID of the just created card, make sure to save this in the settings of your mod
function Client_SaveConfigureUI(alert, addCard)

    Mod.Settings.Version = LATEST_SETTINGS_VERSION;

    Mod.Settings.isAcquiringTypeCard = isAcquiringTypeCard.GetIsChecked();

    -- GetSettingsVersionForDisplay() (Utilities.lua) relies on this being written unconditionally on every
    -- save to detect "never saved" vs "saved pre-Version". If a second include-setting is added alongside
    -- this one, update GetSettingsVersionForDisplay() to check for either rather than just this field.
    Mod.Settings.IncludeBarbedWire = includeBarbedWire.GetIsChecked();

    if(Mod.Settings.IncludeBarbedWire) then
        Mod.Settings.BarbedWireIsTankSpecialBehaviour = barbedWireIsTankSpecialBehaviour.GetIsChecked();
        Mod.Settings.BarbedWireTanksIgnore = barbedWireIsTankSpecialBehaviour.GetIsChecked() and barbedWireTanksIgnore.GetIsChecked();
        Mod.Settings.BarbedWireTanksDestroy = barbedWireIsTankSpecialBehaviour.GetIsChecked() and barbedWireTanksDestroy.GetIsChecked();

        Mod.Settings.BarbedWireTriggerDuration = barbedWireTriggerDuration.GetValue();
        if (Mod.Settings.BarbedWireTriggerDuration < 1) then
            alert("Trigger duration cannot be less than 1");
            return;
        end

        Mod.Settings.BarbedWireAllyTriggers = barbedWireAllyTriggers.GetIsChecked();
        Mod.Settings.BarbedWireTrapsArmies = barbedWireTrapsArmies.GetIsChecked();
        Mod.Settings.BarbedWireCancelsAirlifts = barbedWireCancelsAirlifts.GetIsChecked();
        Mod.Settings.BarbedWireTrapsSpecialUnits = barbedWireTrapsSpecialUnits.GetIsChecked();
        Mod.Settings.BarbedWireOnlyTriggersOnTrappableUnits = barbedWireOnlyTriggersOnTrappableUnits.GetIsChecked();
        Mod.Settings.BarbedWireBombDestroys = barbedWireBombDestroys.GetIsChecked();
        Mod.Settings.BarbedWireSingleUse = barbedWireSingleUse.GetIsChecked();

        Mod.Settings.BarbedWireHasLimitedLifespan = barbedWireHasLimitedLifespan.GetIsChecked();
        if(Mod.Settings.BarbedWireHasLimitedLifespan) then
            Mod.Settings.BarbedWireLifespan = barbedWireLifespan.GetValue();

            if (Mod.Settings.BarbedWireLifespan < 2) then
                alert("Barbed wire lifespan cannot be less than 2");
                return;
            end
        end

        if(Mod.Settings.isAcquiringTypeCard) then
            Mod.Settings.BarbedWireNumPieces = barbedWireNumPieces.GetValue();
            Mod.Settings.BarbedWireCardWeight = math.floor(barbedWireCardWeight.GetValue() * 100 + 0.5) / 100;
            Mod.Settings.BarbedWireMinPieces = barbedWireMinPieces.GetValue();
            Mod.Settings.BarbedWireInitialPieces = barbedWireInitialPieces.GetValue();

            if (Mod.Settings.BarbedWireNumPieces < 1) then
                alert("Number of barbed wire pieces cannot be less than 1");
                return;
            end
            if (Mod.Settings.BarbedWireCardWeight < 0) then
                alert("Barbed wire card weight cannot be less than 0");
                return;
            end
            if (Mod.Settings.BarbedWireMinPieces < 0) then
                alert("Minimum barbed wire pieces cannot be less than 0");
                return;
            end
            if (Mod.Settings.BarbedWireInitialPieces < 0) then
                alert("Initial barbed wire pieces cannot be less than 0");
                return;
            end

            local barbedWireCardID = addCard(
                "Barbed Wire Card",
                "Play this card to create a Barbed Wire on any territory you control (at the end of the turn). If this territory is succesfully captured, on the following turn, attack/transfer orders out of that territory will be blocked.",
                "BarbedWireCard.png",
                Mod.Settings.BarbedWireNumPieces, 
                Mod.Settings.BarbedWireMinPieces,
                Mod.Settings.BarbedWireInitialPieces,
                Mod.Settings.BarbedWireCardWeight);

            Mod.Settings.BarbedWireCardID = barbedWireCardID;
        else
            Mod.Settings.BarbedWireCost = barbedWireCost.GetValue();
            Mod.Settings.BarbedWireMaxPerPlayer = barbedWireMaxPerPlayer.GetValue();

            if (Mod.Settings.BarbedWireCost < 0) then
                alert("Cost of a Barbed Wire cannot be less than 0");
                return;
            end
            if (Mod.Settings.BarbedWireMaxPerPlayer < 1) then
                alert("Maximum Barbed Wire a player can own at once must be at least 1");
                return;
            end
        end
    end

    Mod.Settings.IncludeCaltrop = includeCaltrop.GetIsChecked();

    if(Mod.Settings.IncludeCaltrop) then
        Mod.Settings.CaltropIsTankSpecialBehaviour = caltropIsTankSpecialBehaviour.GetIsChecked();
        Mod.Settings.CaltropTanksIgnore = caltropIsTankSpecialBehaviour.GetIsChecked() and caltropTanksIgnore.GetIsChecked();
        Mod.Settings.CaltropTanksDestroy = caltropIsTankSpecialBehaviour.GetIsChecked() and caltropTanksDestroy.GetIsChecked();

        Mod.Settings.CaltropTriggerDuration = caltropTriggerDuration.GetValue();
        if (Mod.Settings.CaltropTriggerDuration < 1) then
            alert("Trigger duration cannot be less than 1");
            return;
        end

        Mod.Settings.CaltropAllyTriggers = caltropAllyTriggers.GetIsChecked();
        Mod.Settings.CaltropTrapsArmies = caltropTrapsArmies.GetIsChecked();
        Mod.Settings.CaltropCancelsAirlifts = caltropCancelsAirlifts.GetIsChecked();
        Mod.Settings.CaltropTrapsSpecialUnits = caltropTrapsSpecialUnits.GetIsChecked();
        Mod.Settings.CaltropOnlyTriggersOnTrappableUnits = caltropOnlyTriggersOnTrappableUnits.GetIsChecked();
        Mod.Settings.CaltropBombDestroys = caltropBombDestroys.GetIsChecked();
        Mod.Settings.CaltropSingleUse = caltropSingleUse.GetIsChecked();

        Mod.Settings.CaltropHasLimitedLifespan = caltropHasLimitedLifespan.GetIsChecked();
        if(Mod.Settings.CaltropHasLimitedLifespan) then
            Mod.Settings.CaltropLifespan = caltropLifespan.GetValue();

            if (Mod.Settings.CaltropLifespan < 2) then
                alert("Tank Caltrop lifespan cannot be less than 2");
                return;
            end
        end

        Mod.Settings.CaltropIsAcquiringTypeCard = caltropIsAcquiringTypeCard.GetIsChecked();

        if(Mod.Settings.CaltropIsAcquiringTypeCard) then
            Mod.Settings.CaltropNumPieces = caltropNumPieces.GetValue();
            Mod.Settings.CaltropCardWeight = math.floor(caltropCardWeight.GetValue() * 100 + 0.5) / 100;
            Mod.Settings.CaltropMinPieces = caltropMinPieces.GetValue();
            Mod.Settings.CaltropInitialPieces = caltropInitialPieces.GetValue();

            if (Mod.Settings.CaltropNumPieces < 1) then
                alert("Number of Tank Caltrop pieces cannot be less than 1");
                return;
            end
            if (Mod.Settings.CaltropCardWeight < 0) then
                alert("Tank Caltrop card weight cannot be less than 0");
                return;
            end
            if (Mod.Settings.CaltropMinPieces < 0) then
                alert("Minimum Tank Caltrop pieces cannot be less than 0");
                return;
            end
            if (Mod.Settings.CaltropInitialPieces < 0) then
                alert("Initial Tank Caltrop pieces cannot be less than 0");
                return;
            end

            local caltropCardID = addCard(
                "Tank Caltrop Card",
                "Play this card to create Tank Caltrops on any territory you control (at the end of the turn).",
                "TankCaltropCard.png",
                Mod.Settings.CaltropNumPieces,
                Mod.Settings.CaltropMinPieces,
                Mod.Settings.CaltropInitialPieces,
                Mod.Settings.CaltropCardWeight);

            Mod.Settings.CaltropCardID = caltropCardID;
        end
    end

    if(Mod.Settings.IncludeBarbedWire == false and Mod.Settings.IncludeCaltrop == false) then
        alert("You must include at least one of the two: Barbed Wire, Tank Caltrops");
        return;
    end
end
