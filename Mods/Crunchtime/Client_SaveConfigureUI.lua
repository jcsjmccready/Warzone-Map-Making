require("Utilities");

---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID # Creates a custom card. Can be invoked multiple times to create multiple cards. Every invokation will return the CardID of the just created card, make sure to save this in the settings of your mod
function Client_SaveConfigureUI(alert, addCard)
    Mod.Settings.Version = CURRENT_SETTINGS_VERSION;

    Mod.Settings.TriggerTypeCard = triggerTypeCard.GetIsChecked();
    Mod.Settings.TriggerTypeMenu = triggerTypeMenu.GetIsChecked();

    Mod.Settings.AllowIncreaseFirst = allowIncreaseFirst.GetIsChecked();
    Mod.Settings.AllowDecreaseFirst = allowDecreaseFirst.GetIsChecked();

    if (not Mod.Settings.AllowIncreaseFirst and not Mod.Settings.AllowDecreaseFirst) then
        alert("At least one starting order must be allowed");
        return;
    end

    Mod.Settings.UserSpecifiedDuration = userSpecifiedDuration.GetIsChecked();

    Mod.Settings.IncreasePercent = increasePercent.GetValue();
    Mod.Settings.IncreaseFlatAmount = increaseFlatAmount.GetValue();

    Mod.Settings.DecreasePercent = decreasePercent.GetValue();
    Mod.Settings.DecreaseFlatAmount = decreaseFlatAmount.GetValue();

    if (Mod.Settings.IncreasePercent < 0) then
        alert("Percentage income increase cannot be less than 0");
        return;
    end
    if (Mod.Settings.IncreaseFlatAmount < 0) then
        alert("Flat income increase cannot be less than 0");
        return;
    end
    if (Mod.Settings.DecreasePercent < 0) then
        alert("Percentage income decrease cannot be less than 0");
        return;
    end
    if (Mod.Settings.DecreaseFlatAmount < 0) then
        alert("Flat income decrease cannot be less than 0");
        return;
    end

    if (Mod.Settings.UserSpecifiedDuration) then
        Mod.Settings.MaxUserSpecifiedDuration = maxUserSpecifiedDuration.GetValue();
        Mod.Settings.IncreaseDuration = nil;
        Mod.Settings.DecreaseDuration = nil;

        if (Mod.Settings.MaxUserSpecifiedDuration < 1) then
            alert("Maximum duration must be at least 1 turn");
            return;
        end
    else
        Mod.Settings.IncreaseDuration = increaseDuration.GetValue();
        Mod.Settings.DecreaseDuration = decreaseDuration.GetValue();
        Mod.Settings.MaxUserSpecifiedDuration = nil;

        if (Mod.Settings.IncreaseDuration < 1) then
            alert("Increase phase duration must be at least 1 turn");
            return;
        end
        if (Mod.Settings.DecreaseDuration < 1) then
            alert("Decrease phase duration must be at least 1 turn");
            return;
        end
    end

    if (Mod.Settings.TriggerTypeCard) then
        Mod.Settings.NumPieces = numPieces.GetValue();
        Mod.Settings.CardWeight = cardWeight.GetValue();
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

        local crunchtimeCardID = addCard(
            "Crunch Time Card",
            "Play this card to enter Crunch Time. Choose whether to start with Crunch Time (income increase) or Rest Time (income decrease) - the other follows automatically afterwards. Once started, it cannot be exited early.",
            "CrunchtimeCard.png",
            Mod.Settings.NumPieces,
            Mod.Settings.MinPieces,
            Mod.Settings.InitialPieces,
            Mod.Settings.CardWeight);
        Mod.Settings.CrunchtimeCardID = crunchtimeCardID;
    end
end
