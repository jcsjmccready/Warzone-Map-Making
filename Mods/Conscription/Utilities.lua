function startsWith(str, sub)
	return string.sub(str, 1, string.len(sub)) == sub;
end

function first(array, func)
	for _,v in pairs(array) do
		if (func == nil or func(v)) then
			return v;
		end
	end
	return nil;
end

--given 0-255 RGB integers, return a single 24-bit integer, useful for annotations
function GetColourInteger (red, green, blue)
	return red*256^2 + green*256 + blue;
end

--given a hex colour string like "#RRGGBB", return a single 24-bit integer
function GetColourIntegerFromHex(hexColour)
    local normalized = string.gsub(hexColour, "#", "");
    return tonumber(normalized, 16);
end

function GetButtonColors()
    return {
        Blue = "#0000FF";
        Purple = "#59009D";
        Orange = "#FF7D00";
        DarkGray = "#606060";
        HotPink = "#FF697A";
        SeaGreen = "#00FF8C";
        Teal = "#009B9D";
        DarkMagenta = "#AC0059";
        Yellow = "#FFFF00";
        Ivory = "#FEFF9B";
        ElectricPurple = "#B70AFF";
        DeepPink = "#FF00B1";
        Aqua = "#4EFFFF";
        DarkGreen = "#008000";
        Red = "#FF0000";
        Green = "#00FF05";
        SaddleBrown = "#94652E";
        OrangeRed = "#FF4700";
        LightBlue = "#23A0FF";
        Orchid = "#FF87FF";
        Brown = "#943E3E";
        CopperRose = "#AD7E7E";
        Tan = "#FFAF56";
        Lime = "#8EBE57";
        TyrianPurple = "#990024";
        MardiGras = "#880085";
        RoyalBlue = "#4169E1";
        WildStrawberry = "#FF43A4";
        SmokyBlack = "#100C08";
        Goldenrod = "#DAA520";
        Cyan = "#00FFFF";
        Artichoke = "#8F9779";
        RainForest = "#00755E";
        Peach = "#FFE5B4";
        AppleGreen = "#8DB600";
        Viridian = "#40826D";
        Mahogany = "#C04000";
        PinkLace = "#FFDDF4";
        Bronze = "#CD7F32";
        WoodBrown = "#C19A6B";
        Tuscany = "#C09999";
        AcidGreen = "#B0BF1A";
        Amazon = "#3B7A57";
        ArmyGreen = "#4B5320";
        DonkeyBrown = "#664C28";
        Cordovan = "#893F45";
        Cinnamon = "#D2691E";
        Charcoal = "#36454F";
        Fuchsia = "#FF00FF";
        ScreaminGreen = "#76FF7A";
    };
end

TEXT_DEFAULT_COLOUR = "#CCCCCC";
BUTTON_COLOURS = GetButtonColors();
ERROR_COLOUR = BUTTON_COLOURS.Red;
SUBHEADING_COLOUR = BUTTON_COLOURS.Yellow;

--Returns true only if every territory belonging to bonusID is owned by playerID (per the given standing)
---@param standing GameStanding
---@param map MapDetails
---@param bonusID BonusID
---@param playerID PlayerID
function PlayerFullyOwnsBonus(standing, map, bonusID, playerID)
	local bonus = map.Bonuses[bonusID];
	if (bonus == nil or playerID == nil or playerID == WL.PlayerID.Neutral) then
		return false;
	end

	for _, terrID in ipairs(bonus.Territories) do
		local territoryStanding = standing.Territories[terrID];
		if (territoryStanding == nil or territoryStanding.OwnerPlayerID ~= playerID) then
			return false;
		end
	end
	return true;
end

--Returns the PlayerID that currently fully owns bonusID (every territory in it, same owner, non-neutral), or nil
--if the bonus is split between multiple owners/neutral.
---@param standing GameStanding
---@param map MapDetails
---@param bonusID BonusID
function GetBonusSoleOwner(standing, map, bonusID)
	local bonus = map.Bonuses[bonusID];
	if (bonus == nil or #bonus.Territories == 0) then
		return nil;
	end

	local firstTerritoryStanding = standing.Territories[bonus.Territories[1]];
	if (firstTerritoryStanding == nil) then return nil; end;

	local ownerID = firstTerritoryStanding.OwnerPlayerID;
	if (ownerID == nil or ownerID == WL.PlayerID.Neutral) then
		return nil;
	end

	if (PlayerFullyOwnsBonus(standing, map, bonusID, ownerID)) then
		return ownerID;
	end
	return nil;
end

function shuffle(tbl)
	for i = #tbl, 2, -1 do
		local j = math.random(i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
end

--Effective (post-conscription) value of a bonus: its map-defined Amount, minus however much Conscription has
--already permanently taken off it. Never goes below 0.
---@param map MapDetails
---@param bonusID BonusID
function GetEffectiveBonusValue(map, bonusID)
	local bonus = map.Bonuses[bonusID];
	if (bonus == nil) then return 0; end;

	local reductions = (Mod.PublicGameData or {}).BonusReductions or {};
	local reduction = reductions[bonusID] or 0;
	return math.max(bonus.Amount - reduction, 0);
end

--Ordered from least to most conscripted. StructureName must match a file in StructureImages/ (minus ".png").
--Threshold doubles as the tier's ordering/comparison key, since it's already monotonically increasing.
CONSCRIPTION_TIERS = {
	{ Threshold = 0.01, StructureName = "MinimalConscripted" };
	{ Threshold = 0.25, StructureName = "QuarterConscripted" };
	{ Threshold = 0.50, StructureName = "HalfConscripted" };
	{ Threshold = 0.75, StructureName = "ThreeQuarterConscripted" };
	{ Threshold = 1.00, StructureName = "FullyConscripted" };
};

--Returns the highest conscription tier whose Threshold has been reached by percent (0-1), or nil if percent is
--below the lowest tier's threshold.
function GetConscriptionTierForPercent(percent)
	local highest = nil;
	for _, tier in ipairs(CONSCRIPTION_TIERS) do
		if (percent >= tier.Threshold) then
			highest = tier;
		end
	end
	return highest;
end

--Returns the highest conscription tier Threshold currently present (with a count > 0) on a territory's
--structures table, or 0 if none of the 4 conscription structures are present.
function GetAppliedConscriptionThreshold(structures)
	local highestThreshold = 0;
	for _, tier in ipairs(CONSCRIPTION_TIERS) do
		local structureID = WL.StructureType.Custom(tier.StructureName);
		if (structures[structureID] ~= nil and structures[structureID] > 0 and tier.Threshold > highestThreshold) then
			highestThreshold = tier.Threshold;
		end
	end
	return highestThreshold;
end

--Returns the (mutable, cached) structures table for a territory, seeded from LatestTurnStanding the first
--time it's requested for a given structuresByTerritory cache. Callers mutate the returned table in place.
---@param game GameServerHook
---@param structuresByTerritory table<TerritoryID, table<EnumStructureType, integer>>
---@param territoryId TerritoryID
function GetTerritoryStructures(game, structuresByTerritory, territoryId)
	local structures = structuresByTerritory[territoryId];
	if (structures == nil) then
		structures = {};
		for key, value in pairs(game.ServerGame.LatestTurnStanding.Territories[territoryId].Structures or {}) do
			structures[key] = value;
		end
		structuresByTerritory[territoryId] = structures;
	end
	return structures;
end

--Returns a shallow copy of a structures table.
---@param structures table<EnumStructureType, integer>
function CopyStructures(structures)
	local copy = {};
	for key, value in pairs(structures) do
		copy[key] = value;
	end
	return copy;
end
