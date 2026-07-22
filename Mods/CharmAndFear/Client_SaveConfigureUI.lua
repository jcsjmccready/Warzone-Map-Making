---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID # Creates a custom card. Can be invoked multiple times to create multiple cards. Every invokation will return the CardID of the just created card, make sure to save this in the settings of your mod
function Client_SaveConfigureUI(alert, addCard)
    Mod.Settings.IncludeFearCard = includeFearCard.GetIsChecked();
    if(Mod.Settings.IncludeFearCard) then

        Mod.Settings.FearDistance = fearDistance.GetValue();
        Mod.Settings.FearDuration = fearDuration.GetValue();
        Mod.Settings.FearFalloff = math.floor(fearFalloff.GetValue() * 100 + 0.5) / 100;
        Mod.Settings.FearSpecialUnitThreshold = math.floor(fearSpecialUnitThreshold.GetValue() * 100 + 0.5) / 100;
        Mod.Settings.FearCreateOnlyOwnTerritories = fearCreateOnlyOwnTerritories.GetIsChecked();

        if (Mod.Settings.FearDistance < 0) then
            alert("Fear distance cannot be less than 0");
            return;
        end
        if (Mod.Settings.FearDuration < 1) then
            alert("Fear duration cannot be less than 1");
            return;
        end
        if (Mod.Settings.FearFalloff < 0) then
            alert("Fear falloff cannot be less than 0");
            return;
        end
        if (Mod.Settings.FearFalloff > 1) then
            alert("Fear falloff cannot be greater than 1");
            return;
        end
        if (Mod.Settings.FearSpecialUnitThreshold < 0) then
            alert("Special unit fear threshold cannot be less than 0");
            return;
        end
        if (Mod.Settings.FearSpecialUnitThreshold > 1) then
            alert("Special unit fear threshold cannot be greater than 1");
            return;
        end

        Mod.Settings.FearNumPieces = fearNumPieces.GetValue();
        Mod.Settings.FearCardWeight = fearCardWeight.GetValue();
        Mod.Settings.FearMinPieces = fearMinPieces.GetValue();
        Mod.Settings.FearInitialPieces = fearInitialPieces.GetValue();

        if (Mod.Settings.FearNumPieces < 1) then
            alert("Number of fear card pieces cannot be less than 1");
            return;
        end
        if (Mod.Settings.FearCardWeight < 0) then
            alert("Fear card weight cannot be less than 0");
            return;
        end
        if (Mod.Settings.FearMinPieces < 0) then
            alert("Minimum fear card pieces cannot be less than 0");
            return;
        end
        if (Mod.Settings.FearInitialPieces < 0) then
            alert("Initial fear card pieces cannot be less than 0");
            return;
        end

        local fearCardId = addCard(
            "Fear Card",
            "Play this card to create a Fear structure on a chosen territory. It forces armies to move away from it." ,
            "FearCard.png",
            Mod.Settings.FearNumPieces, 
            Mod.Settings.FearMinPieces,
            Mod.Settings.FearInitialPieces,
            Mod.Settings.FearCardWeight,
            Mod.Settings.FearDuration);

            Mod.Settings.FearCardID = fearCardId;
    end

    Mod.Settings.IncludeCharmCard = includeCharmCard.GetIsChecked();
    if(Mod.Settings.IncludeCharmCard) then
        Mod.Settings.CharmDistance = charmDistance.GetValue();
        Mod.Settings.CharmDuration = charmDuration.GetValue();
        Mod.Settings.CharmFalloff = math.floor(charmFalloff.GetValue() * 100 + 0.5) / 100;
        Mod.Settings.CharmSpecialUnitThreshold = math.floor(charmSpecialUnitThreshold.GetValue() * 100 + 0.5) / 100;
        Mod.Settings.CharmCreateOnlyOwnTerritories = charmCreateOnlyOwnTerritories.GetIsChecked();

        if (Mod.Settings.CharmDistance < 0) then
            alert("Charm distance cannot be less than 0");
            return;
        end
        if (Mod.Settings.CharmDuration < 1) then
            alert("Charm duration cannot be less than 1");
            return;
        end
        if (Mod.Settings.CharmFalloff < 0) then
            alert("Charm falloff cannot be less than 0");
            return;
        end
        if (Mod.Settings.CharmFalloff > 1) then
            alert("Charm falloff cannot be greater than 1");
            return;
        end
        if (Mod.Settings.CharmSpecialUnitThreshold < 0) then
            alert("Special unit charm threshold cannot be less than 0");
            return;
        end
        if (Mod.Settings.CharmSpecialUnitThreshold > 1) then
            alert("Special unit charm threshold cannot be greater than 1");
            return;
        end

        Mod.Settings.CharmNumPieces = charmNumPieces.GetValue();
        Mod.Settings.CharmCardWeight = charmCardWeight.GetValue();
        Mod.Settings.CharmMinPieces = charmMinPieces.GetValue();
        Mod.Settings.CharmInitialPieces = charmInitialPieces.GetValue();

        if (Mod.Settings.CharmNumPieces < 1) then
            alert("Number of charm card pieces cannot be less than 1");
            return;
        end
        if (Mod.Settings.CharmCardWeight < 0) then
            alert("Charm card weight cannot be less than 0");
            return;
        end
        if (Mod.Settings.CharmMinPieces < 0) then
            alert("Minimum charm card pieces cannot be less than 0");
            return;
        end
        if (Mod.Settings.CharmInitialPieces < 0) then
            alert("Initial charm card pieces cannot be less than 0");
            return;
        end

        local charmCardId = addCard(
            "Charm Card",
            "Play this card to create a Charm structure on a chosen territory. It forces armies to move towards it." , 
            "CharmCard.png", 
            Mod.Settings.CharmNumPieces, 
            Mod.Settings.CharmMinPieces,
            Mod.Settings.CharmInitialPieces, 
            Mod.Settings.CharmCardWeight,
            Mod.Settings.CharmDuration);

            Mod.Settings.CharmCardID = charmCardId;
    end

    if(Mod.Settings.IncludeFearCard == false and Mod.Settings.IncludeCharmCard == false) then
        alert("You must include at least one of the two cards (Fear or Charm)");
        return;
    end
end

function getTerritoriesAndPercentage (game, targetTerritoryID, intMaxDistance, stepDecay)
    local arrTerrProcessed = {}; --list of terrs already processed
    local arrTerrResults = {}; --resultant list of terrs within specified distance
    local arrTerrListToProcess = {}; --terrs remaining to be processed

	local intDepth = 0;
    arrTerrProcessed [targetTerritoryID] = true;
    table.insert (arrTerrResults, targetTerritoryID);
    table.insert (arrTerrListToProcess, targetTerritoryID);

    while (intDepth < intMaxDistance and #arrTerrListToProcess > 0) do
        local intNextTerrID = {};
        for _, terrID in ipairs(arrTerrListToProcess) do
            for neighbourTerrID, _ in pairs (game.Map.Territories [terrID].ConnectedTo) do
                if not arrTerrProcessed [neighbourTerrID] then
                    arrTerrProcessed [neighbourTerrID] = true;
                    table.insert(arrTerrResults, neighbourTerrID);
                    table.insert(intNextTerrID, neighbourTerrID);
                end
            end
        end
        arrTerrListToProcess = intNextTerrID;
        intDepth = intDepth + 1;
    end
    return (arrTerrResults);
end