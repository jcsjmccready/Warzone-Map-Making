---Client_CreateGame hook. Used to check the game settings before actually creating the game
---@param settings GameSettings # Read-only GameSettings object
---@param alert fun(message: string) # When invoked, it will show a pop-up for the client with the message. It will also abort the game creation
function Client_CreateGame(settings, alert)
    if (Mod.Settings.isAcquiringTypeCard ~= nil and not Mod.Settings.isAcquiringTypeCard and not settings.CommerceGame) then
        alert("Dead Man's Switch is set to be acquired via Commerce, but this game is not a Commerce game.");
    end

    if (Mod.Settings.isDamageTypeBomb and (settings.Cards == nil or settings.Cards[WL.CardID.Bomb] == nil)) then
        alert("Bombs must be enabled for this mod to work.");
    end

    if (Mod.Settings.isDamageTypeSanction and (settings.Cards == nil or settings.Cards[WL.CardID.Sanctions] == nil)) then
        alert("Sanction cards must be enabled for this mod to work.");
    end

    if (Mod.Settings.isDamageTypeBlockade and (settings.Cards == nil or settings.Cards[WL.CardID.Blockade] == nil)) then
        alert("Blockade cards must be enabled for this mod to work.");
    end

    if (Mod.Settings.isDamageTypeEmergencyBlockade and (settings.Cards == nil or settings.Cards[WL.CardID.EmergencyBlockade] == nil)) then
        alert("Emergency Blockade cards must be enabled for this mod to work.");
    end

    if (Mod.Settings.isDamageTypeGift and (settings.Cards == nil or settings.Cards[WL.CardID.Gift] == nil)) then
        alert("Gift cards must be enabled for this mod to work.");
    end

    if (Mod.Settings.isDamageTypeDiplomacy and (settings.Cards == nil or settings.Cards[WL.CardID.Diplomacy] == nil)) then
        alert("Diplomacy cards must be enabled for this mod to work.");
    end

    if (Mod.Settings.isDamageTypeSpy and (settings.Cards == nil or settings.Cards[WL.CardID.Spy] == nil)) then
        alert("Spy cards must be enabled for this mod to work.");
    end
end