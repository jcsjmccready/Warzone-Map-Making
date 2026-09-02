---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID # Creates a custom card. Can be invoked multiple times to create multiple cards. Every invokation will return the CardID of the just created card, make sure to save this in the settings of your mod
function Client_SaveConfigureUI(alert, addCard)

    Mod.Settings.Version = LATEST_SETTINGS_VERSION;

    Mod.Settings.isAcquiringTypeCommerce = isAcquiringTypeCommerce;
    Mod.Settings.isAcquiringTypeCard = isAcquiringTypeCard.GetIsChecked();

    -- GetSettingsVersionForDisplay() (Utilities.lua) relies on this being written unconditionally on every
    -- save to detect "never saved" vs "saved pre-Version". If a second include-setting is added alongside
    -- this one, update GetSettingsVersionForDisplay() to check for either rather than just this field.
    Mod.Settings.IncludeBarbedWire = includeBarbedWire;

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
        end
    end

    if(Mod.Settings.IncludeBarbedWire == false and Mod.Settings.IncludeTankCaltrop == false) then
        alert("You must include at least one of the two: Barbed Wire, Tank Caltrops");
        return;
    end
end
