require("Utilities");

---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID
function Client_SaveConfigureUI(alert, addCard)
    Mod.Settings.Version = CURRENT_SETTINGS_VERSION;

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

    local tankCardID = addCard(
        "Tank Card",
        "Play this card to build a Tank on any territory you control (at the end of the turn).",
        "TankCard.png",
        Mod.Settings.NumPieces,
        Mod.Settings.MinPieces,
        Mod.Settings.InitialPieces,
        Mod.Settings.CardWeight);

    Mod.Settings.TankCardID = tankCardID;
end
