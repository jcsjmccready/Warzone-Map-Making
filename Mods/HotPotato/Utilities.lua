function NewIdentity()
	local data = Mod.PublicGameData;
	local ret = data.Identity or 1;
	data.Identity = ret + 1;
	Mod.PublicGameData = data;
	return ret;
end

function Dump(obj)
	if obj.proxyType ~= nil then
		DumpProxy(obj);
	elseif type(obj) == 'table' then
		DumpTable(obj);
	else
		print('Dump ' .. type(obj));
	end
end
function DumpTable(tbl)
    for k,v in pairs(tbl) do
        print('k = ' .. tostring(k) .. ' (' .. type(k) .. ') ' .. ' v = ' .. tostring(v) .. ' (' .. type(v) .. ')');
    end
end
function DumpProxy(obj)
    print('type=' .. obj.proxyType .. ' readOnly=' .. tostring(obj.readonly) .. ' readableKeys=' .. table.concat(obj.readableKeys, ',') .. ' writableKeys=' .. table.concat(obj.writableKeys, ','));
end

function map(array, func)
	local new_array = {}
	local i = 1;
	for _,v in pairs(array) do
		new_array[i] = func(v);
		i = i + 1;
	end
	return new_array
end

function filter(array, func)
	local new_array = {}
	local i = 1;
	for _,v in pairs(array) do
		if (func(v)) then
			new_array[i] = v;
			i = i + 1;
		end
	end
	return new_array
end

function first(array, func)
	for _,v in pairs(array) do
		if (func == nil or func(v)) then
			return v;
		end
	end
	return nil;
end

function randomFromArray(array)
	local len = #array;
	if (len == 0) then return nil; end;
	local i = math.random(len);
	return array[i];
end

function startsWith(str, sub)
	return string.sub(str, 1, string.len(sub)) == sub;
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

--given a hex colour string like "#RRGGBB", return a single 24-bit integer
function GetColourIntegerFromHex(hexColour)
    local normalized = string.gsub(hexColour, "#", "");
    return tonumber(normalized, 16);
end

TEXT_DEFAULT_COLOUR = "#CCCCCC";
BUTTON_COLOURS = GetButtonColors();
ERROR_COLOUR = BUTTON_COLOURS.Red;
SUBHEADING_COLOUR = BUTTON_COLOURS.Yellow;

--Returns an array of the PlayerIDs of every player currently still playing (not eliminated/booted/surrendered)
function GetPlayingPlayerIDs(game)
	local ids = {};
	for playerID, _ in pairs(game.Game.PlayingPlayers) do
		table.insert(ids, playerID);
	end
	return ids;
end

--Returns the total number of armies a player currently owns across all their territories
function GetPlayerArmyCount(game, playerID)
	local total = 0;
	for _, territory in pairs(game.ServerGame.LatestTurnStanding.Territories) do
		if (territory.OwnerPlayerID == playerID) then
			total = total + territory.NumArmies.NumArmies;
		end
	end
	return total;
end

--Returns the PlayerID from playerIDs with the highest total army count (ties broken randomly)
function GetBiggestPlayerID(game, playerIDs)
	local best = {};
	local bestCount = -1;
	for _, playerID in pairs(playerIDs) do
		local count = GetPlayerArmyCount(game, playerID);
		if (count > bestCount) then
			bestCount = count;
			best = { playerID };
		elseif (count == bestCount) then
			table.insert(best, playerID);
		end
	end
	return randomFromArray(best);
end

--Returns the subset of playerIDs that are not AI-controlled (ie. real human players)
function GetNonAIPlayerIDs(game, playerIDs)
	return filter(playerIDs, function(id)
		local player = game.Game.Players[id];
		return player ~= nil and not player.IsAIOrHumanTurnedIntoAI;
	end);
end

--Returns every TerritoryID currently owned by playerID
function GetTerritoriesOwnedBy(game, playerID)
	local territories = {};
	for territoryID, territory in pairs(game.ServerGame.LatestTurnStanding.Territories) do
		if (territory.OwnerPlayerID == playerID) then
			table.insert(territories, territoryID);
		end
	end
	return territories;
end
