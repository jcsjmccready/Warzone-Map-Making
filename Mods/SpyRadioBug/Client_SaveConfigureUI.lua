---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID # Creates a custom card. Can be invoked multiple times to create multiple cards. Every invokation will return the CardID of the just created card, make sure to save this in the settings of your mod
function Client_SaveConfigureUI(alert, addCard)

    Mod.Settings.isAcquiringTypeCommerce = isAcquiringTypeCommerce;

    Mod.Settings.SweeperRadius = sweeperRadius.GetValue();
    if (Mod.Settings.SweeperRadius < 0) then
        alert("Sweeper Radius cannot be less than 0");
        return;
    end

    Mod.Settings.RadioDetectionRadius = radioDetectionRadius.GetValue();
    if (Mod.Settings.RadioDetectionRadius < 0) then
        alert("Radio Detection Radius cannot be less than 0");
        return;
    end

    Mod.Settings.RecaptureCardPieces = recaptureCardPieces.GetValue();
    if (Mod.Settings.RecaptureCardPieces < 0) then
        alert("Card pieces awarded on recapture cannot be less than 0");
        return;
    end

    local visibilityMessage = "ERROR";
    Mod.Settings.VisibilityGainedAutoplaySpyCard = visibilityGainedAutoplaySpyCard.GetIsChecked();
    if(Mod.Settings.VisibilityGainedAutoplaySpyCard) then
        visibilityMessage = "a Spy card is automatically played on it.";
    end

    Mod.Settings.VisibilityGainedCustomVision = visibilityGainedCustomVision.GetIsChecked();
    if(Mod.Settings.VisibilityGainedCustomVision) then
        Mod.Settings.CustomVisionRadius = customVisionRadius.GetValue();
        if (Mod.Settings.CustomVisionRadius < 0) then
            alert("Radius cannot be less than 0");
            return;
        end
        visibilityMessage = "you are given vision of it and territories within " .. Mod.Settings.CustomVisionRadius .. " territories of it.";
    end

    Mod.Settings.isAcquiringTypeCard = isAcquiringTypeCard.GetIsChecked();
    if(Mod.Settings.isAcquiringTypeCard) then
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

        local bugCardID = addCard(
            "Spy Radio Bug Card",
            "Play this card to place a hidden Spy Radio Bug on a territory controlled by an enemy. While undiscovered, " .. visibilityMessage .. " Your enemy will be given Temporary Sweeper cards to search for it.",
            "Bug.png",
            Mod.Settings.NumPieces,
            Mod.Settings.MinPieces,
            Mod.Settings.InitialPieces,
            Mod.Settings.CardWeight);
        Mod.Settings.BugCardID = bugCardID;

        -- this card is never earned normally (0 weight, 0 pieces per turn, 0 initial pieces); it's handed out
        -- directly by the mod to whoever has an undiscovered Spy Radio Bug on one of their territories
        local tempSweeperCardID = addCard(
            "Temporary Sweeper Card",
            "Play this card on one of your own territories to search it for a hidden Spy Radio Bug. Discards at the end of the turn if unused.",
            "TempSweeper.png",
            1,
            0,
            0,
            0);
        Mod.Settings.TempSweeperCardID = tempSweeperCardID;
    end
end
