require("Utilities");

---Joins a list of strings into a natural-language list, e.g. {"a"} -> "a", {"a", "b"} -> "a and b",
---{"a", "b", "c"} -> "a, b, and c"
---@param items string[]
local function JoinWithAnd(items)
    local n = #items;
    if (n == 0) then return ""; end
    if (n == 1) then return items[1]; end
    if (n == 2) then return items[1] .. " and " .. items[2]; end
    return table.concat(items, ", ", 1, n - 1) .. ", and " .. items[n];
end

---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID # Creates a custom card. Can be invoked multiple times to create multiple cards. Every invokation will return the CardID of the just created card, make sure to save this in the settings of your mod
function Client_SaveConfigureUI(alert, addCard)
    Mod.Settings.Version = LATEST_SETTINGS_VERSION;

    Mod.Settings.FlakGunNumPieces = flakGunNumPieces.GetValue();
    Mod.Settings.FlakGunCardWeight = flakGunCardWeight.GetValue();
    Mod.Settings.FlakGunMinPieces = flakGunMinPieces.GetValue();
    Mod.Settings.FlakGunInitialPieces = flakGunInitialPieces.GetValue();
    Mod.Settings.FlakGunAreaOfEffect = flakGunAreaOfEffect.GetValue();
    Mod.Settings.FlakGunRounds = flakGunRounds.GetValue();

    if (Mod.Settings.FlakGunNumPieces < 1) then
        alert("Number of Flak Gun card pieces cannot be less than 1");
        return;
    end
    if (Mod.Settings.FlakGunCardWeight < 0) then
        alert("Flak Gun card weight cannot be less than 0");
        return;
    end
    if (Mod.Settings.FlakGunMinPieces < 0) then
        alert("Minimum Flak Gun card pieces cannot be less than 0");
        return;
    end
    if (Mod.Settings.FlakGunInitialPieces < 0) then
        alert("Initial Flak Gun card pieces cannot be less than 0");
        return;
    end
    if (Mod.Settings.FlakGunAreaOfEffect < 0) then
        alert("Flak Gun area of effect cannot be less than 0");
        return;
    end
    if (Mod.Settings.FlakGunRounds < 1) then
        alert("Flak Gun rounds cannot be less than 1");
        return;
    end

    Mod.Settings.FlakGunFriendlyFire = flakGunFriendlyFire.GetIsChecked();

    Mod.Settings.FlakGunAirliftInteractionEnabled = flakGunAirliftInteractionEnabled.GetIsChecked();

    if (Mod.Settings.FlakGunAirliftInteractionEnabled) then
        Mod.Settings.FlakGunSourceCancelsAirlift = flakGunSourceCancelsAirlift.GetIsChecked();
        Mod.Settings.FlakGunSourceDamagesArmies = flakGunSourceDamagesArmies.GetIsChecked();
        Mod.Settings.FlakGunDestinationCancelsAirlift = flakGunDestinationCancelsAirlift.GetIsChecked();
        Mod.Settings.FlakGunDestinationDamagesArmies = flakGunDestinationDamagesArmies.GetIsChecked();
    else
        Mod.Settings.FlakGunSourceCancelsAirlift = nil;
        Mod.Settings.FlakGunSourceDamagesArmies = nil;
        Mod.Settings.FlakGunDestinationCancelsAirlift = nil;
        Mod.Settings.FlakGunDestinationDamagesArmies = nil;
    end

    if (Mod.Settings.FlakGunSourceDamagesArmies) then
        Mod.Settings.FlakGunSourceDamagePercent = flakGunSourceDamagePercent.GetValue();
        Mod.Settings.FlakGunSourceMinDamage = flakGunSourceMinDamage.GetValue();

        if (Mod.Settings.FlakGunSourceDamagePercent < 0) then
            alert("Flak Gun source damage percent cannot be less than 0");
            return;
        end
        if (Mod.Settings.FlakGunSourceMinDamage < 0) then
            alert("Flak Gun source minimum damage cannot be less than 0");
            return;
        end
    else
        Mod.Settings.FlakGunSourceDamagePercent = nil;
        Mod.Settings.FlakGunSourceMinDamage = nil;
    end

    if (Mod.Settings.FlakGunDestinationDamagesArmies) then
        Mod.Settings.FlakGunDestinationDamagePercent = flakGunDestinationDamagePercent.GetValue();
        Mod.Settings.FlakGunDestinationMinDamage = flakGunDestinationMinDamage.GetValue();

        if (Mod.Settings.FlakGunDestinationDamagePercent < 0) then
            alert("Flak Gun destination damage percent cannot be less than 0");
            return;
        end
        if (Mod.Settings.FlakGunDestinationMinDamage < 0) then
            alert("Flak Gun destination minimum damage cannot be less than 0");
            return;
        end
    else
        Mod.Settings.FlakGunDestinationDamagePercent = nil;
        Mod.Settings.FlakGunDestinationMinDamage = nil;
    end

    local flakGunEffects = {
        Mod.Settings.FlakGunDestinationDamagesArmies and "deal damage to armies in arriving airlifts" or "cancel arriving airlifts",
        Mod.Settings.FlakGunSourceDamagesArmies and "deal damage to armies in departing airlifts" or "cancel departing airlifts",
    };

    local flakGunBaseDescription = "Shoot a flak gun at a chosen territory.";
    if (#flakGunEffects > 0) then
        flakGunBaseDescription = flakGunBaseDescription .. " It will " .. JoinWithAnd(flakGunEffects) .. ".";
    end

    local flakGunDescription = flakGunBaseDescription;
    if (Mod.Settings.FlakGunRounds > 1) then
        flakGunDescription = flakGunDescription .. " Playing this card will also give you a temporary copy of it for the next " .. (Mod.Settings.FlakGunRounds - 1) .. " turn(s)";
    end

    local flakGunCardId = addCard(
        "Flak Gun",
        flakGunDescription,
        "FlakGunCard.png",
        Mod.Settings.FlakGunNumPieces,
        Mod.Settings.FlakGunMinPieces,
        Mod.Settings.FlakGunInitialPieces,
        Mod.Settings.FlakGunCardWeight);

    Mod.Settings.FlakGunCardID = flakGunCardId;

    if (Mod.Settings.FlakGunRounds > 1) then
        local temporaryFlakGunDescription = flakGunBaseDescription .. " Discards at the end of the turn if unused.";

        local temporaryFlakGunCardId = addCard(
            "Temp. Flak Gun",
            temporaryFlakGunDescription,
            "TempFlakGunCard.png",
            1,
            0,
            0,
            0);

        Mod.Settings.FlakGunTemporaryCardID = temporaryFlakGunCardId;
    end
end
