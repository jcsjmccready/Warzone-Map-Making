---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID # Creates a custom card. Can be invoked multiple times to create multiple cards. Every invokation will return the CardID of the just created card, make sure to save this in the settings of your mod
function Client_SaveConfigureUI(alert, addCard)

    Mod.Settings.isAcquiringTypeCommerce = isAcquiringTypeCommerce;

    Mod.Settings.AllyTriggers = allyTriggers.GetIsChecked();

    Mod.Settings.IsTankSpecialBehaviour = isTankSpecialBehaviour.GetIsChecked();
    Mod.Settings.TanksIgnore = Mod.Settings.IsTankSpecialBehaviour and tanksIgnore.GetIsChecked();
    Mod.Settings.TanksDestroy = Mod.Settings.IsTankSpecialBehaviour and tanksDestroy.GetIsChecked();

    Mod.Settings.isAcquiringTypeCard = isAcquiringTypeCard.GetIsChecked();
    if(Mod.Settings.isAcquiringTypeCard) then
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

    addCard("Barbed Wire Card", "Play this card to create a Barbed Wire on any territory you control (at the end of the turn). If this territory is succesfully captured, on the following turn, attack/transfer orders out of that territory will be blocked." , "BarbedWireCard.png", Mod.Settings.NumPieces, Mod.Settings.MinPieces, Mod.Settings.InitialPieces, Mod.Settings.CardWeight);
    end
end

