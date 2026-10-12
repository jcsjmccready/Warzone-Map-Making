---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID # Creates a custom card. Can be invoked multiple times to create multiple cards. Every invokation will return the CardID of the just created card, make sure to save this in the settings of your mod
function Client_SaveConfigureUI(alert, addCard)
    Mod.Settings.SpyPlaneNumPieces = spyPlaneNumPieces.GetValue();
    Mod.Settings.SpyPlaneCardWeight = spyPlaneCardWeight.GetValue();
    Mod.Settings.SpyPlaneMinPieces = spyPlaneMinPieces.GetValue();
    Mod.Settings.SpyPlaneInitialPieces = spyPlaneInitialPieces.GetValue();

    if (Mod.Settings.SpyPlaneNumPieces < 1) then
        alert("Number of Spy Plane card pieces cannot be less than 1");
        return;
    end
    if (Mod.Settings.SpyPlaneCardWeight < 0) then
        alert("Spy Plane card weight cannot be less than 0");
        return;
    end
    if (Mod.Settings.SpyPlaneMinPieces < 0) then
        alert("Minimum Spy Plane card pieces cannot be less than 0");
        return;
    end
    if (Mod.Settings.SpyPlaneInitialPieces < 0) then
        alert("Initial Spy Plane card pieces cannot be less than 0");
        return;
    end

    Mod.Settings.SpyPlaneInclusionGenerosity = spyPlaneInclusionGenerosity.GetValue();
    Mod.Settings.SpyPlaneMaxFlightDistance = spyPlaneMaxFlightDistance.GetValue();
    Mod.Settings.SpyPlaneFlightStyleInstant = spyPlaneFlightStyleInstant.GetIsChecked();
    Mod.Settings.SpyPlaneFlightStyleSteps = spyPlaneFlightStyleSteps.GetIsChecked();

    if (Mod.Settings.SpyPlaneInclusionGenerosity < 25) then
        alert("Spy Plane inclusion generosity cannot be less than 25");
        return;
    end
    if (Mod.Settings.SpyPlaneMaxFlightDistance < 200) then
        alert("Spy Plane maximum flight distance cannot be less than 200");
        return;
    end

    if (Mod.Settings.SpyPlaneFlightStyleSteps) then
        Mod.Settings.SpyPlaneStepModeDistance = spyPlaneStepModeDistance.GetIsChecked();
        Mod.Settings.SpyPlaneStepModeSegment = spyPlaneStepModeSegment.GetIsChecked();

        if (Mod.Settings.SpyPlaneStepModeDistance) then
            Mod.Settings.SpyPlaneMaxDistancePerStep = spyPlaneMaxDistancePerStep.GetValue();

            if (Mod.Settings.SpyPlaneMaxDistancePerStep < 25) then
                alert("Spy Plane maximum distance per step cannot be less than 25");
                return;
            end
        elseif (Mod.Settings.SpyPlaneStepModeSegment) then
            Mod.Settings.SpyPlaneFlightSteps = spyPlaneFlightSteps.GetValue();

            if (Mod.Settings.SpyPlaneFlightSteps < 2) then
                alert("Spy Plane flight segments cannot be less than 2");
                return;
            end
        end
    end

    local spyPlaneDescription = "Send a spy plane between two territories, revealing territories beneath its path.";
    if (Mod.Settings.SpyPlaneFlightStyleSteps) then
        if (Mod.Settings.SpyPlaneStepModeDistance) then
            spyPlaneDescription = "Send a spy plane between two territories over multiple turns, revealing territories beneath its path.";
        elseif (Mod.Settings.SpyPlaneStepModeSegment) then
            spyPlaneDescription = "Send a spy plane between two territories over " .. Mod.Settings.SpyPlaneFlightSteps .. " turns, revealing territories beneath its path.";
        end
    end

    local spyPlaneCardId = addCard(
        "Spy Plane",
        spyPlaneDescription,
        "SpyPlaneCard.png",
        Mod.Settings.SpyPlaneNumPieces,
        Mod.Settings.SpyPlaneMinPieces,
        Mod.Settings.SpyPlaneInitialPieces,
        Mod.Settings.SpyPlaneCardWeight);

    Mod.Settings.SpyPlaneCardID = spyPlaneCardId;
end
