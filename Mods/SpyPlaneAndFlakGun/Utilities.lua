function Determine_Falloff_Examples(falloffField, distanceField)
    local falloff = falloffField or 0;
    local maxDistance = math.max(1, distanceField or 1);
    local examples = {};

    for distance = 0, maxDistance do
        local percentAffected = math.floor(((1 - falloff) ^ distance) * 100 + 0.5) / 100;
        table.insert(examples, string.format('D%s=%s%%', distance, percentAffected * 100));
    end

    return 'Falloff examples: ' .. table.concat(examples, ', ');
end

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

function split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
         table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
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

function removeWhere(array, func)
	for k,v in pairs(array) do
		if (func(v)) then
			array[k] = nil;
		end
	end
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
	local i = math.random(len);
	return array[i];
end

function startsWith(str, sub)
	return string.sub(str, 1, string.len(sub)) == sub;
end

function shuffle(tbl)
	for i = #tbl, 2, -1 do
		local j = math.random(i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
end

function groupBy(tbl, funcToGetKey)
	local ret = {};
	for k,v in pairs(tbl) do
		local key = funcToGetKey(v);
		local group = ret[key];
		if (group == nil) then
			group = {};
			ret[key] = group;
		end
		table.insert(group, v);
	end

	return ret;
end

function TrimWhitespace(s)
    return s:match "^%s*(.-)%s*$"
end

function ParseCommaDelimitedString(str)
	local result = {}
    local start = 1
    while true do
        local commaPos = string.find(str, ',', start)
        if commaPos then
            local value = TrimWhitespace(string.sub(str, start, commaPos - 1));
			if (#value > 0) then table.insert(result, value); end;
            start = commaPos + 1
        else
            -- If there's no more commas, take the remaining part of the string
            local value = TrimWhitespace(string.sub(str, start));
            if (#value > 0) then table.insert(result, value); end;
            break
        end
    end
    return result
end

--true if playerAID and playerBID are the same player, or are on the same (non-neutral) team
function ArePlayersFriendly(game, playerAID, playerBID)
	if (playerAID == playerBID) then return true; end

	local playerA = game.Game.Players[playerAID];
	local playerB = game.Game.Players[playerBID];
	if (playerA == nil or playerB == nil) then return false; end

	return playerA.Team ~= -1 and playerA.Team == playerB.Team;
end

--Returns the TerritoryIDs of every territory on the map whose centerpoint falls within maxDistanceFromLine of the
--line segment drawn between (ax, ay) and (bx, by) (a "thick line" from a birds eye view - adjacency is not
--considered at all, only literal on-map distance to the segment)
function GetTerritoriesNearLineSegment(game, ax, ay, bx, by, maxDistanceFromLine)
	local abx, aby = bx - ax, by - ay;
	local abLengthSquared = abx * abx + aby * aby;

	local result = {};
	for territoryID, territoryDetails in pairs(game.Map.Territories) do
		local px, py = territoryDetails.MiddlePointX, territoryDetails.MiddlePointY;
		local apx, apy = px - ax, py - ay;

		--project the territory's centerpoint onto the segment, clamped to the segment itself (not the infinite
		--line) since the plane only flies from start to end, not beyond either end
		local t = 0;
		if (abLengthSquared > 0) then
			t = math.max(0, math.min(1, (apx * abx + apy * aby) / abLengthSquared));
		end

		local closestX = ax + t * abx;
		local closestY = ay + t * aby;
		local dx, dy = px - closestX, py - closestY;
		local distanceFromLine = math.sqrt(dx * dx + dy * dy);

		if (distanceFromLine <= maxDistanceFromLine) then
			table.insert(result, territoryID);
		end
	end

	return result;
end

--Returns the TerritoryID of whichever territory on the map has its centerpoint closest to (x, y)
function FindNearestTerritory(game, x, y)
	local nearestTerritoryID = nil;
	local nearestDistanceSquared = nil;

	for territoryID, territoryDetails in pairs(game.Map.Territories) do
		local dx, dy = territoryDetails.MiddlePointX - x, territoryDetails.MiddlePointY - y;
		local distanceSquared = dx * dx + dy * dy;

		if (nearestDistanceSquared == nil or distanceSquared < nearestDistanceSquared) then
			nearestTerritoryID = territoryID;
			nearestDistanceSquared = distanceSquared;
		end
	end

	return nearestTerritoryID;
end

--Returns the TerritoryIDs of every territory on the map whose centerpoint falls within maxDistanceFromLine of the
--line segment drawn between startTerritoryID and endTerritoryID's centerpoints. If maxSegmentLengthOpt is given and
--the start/end territories are further apart than that, the segment's end is pulled in along the same direction to
--maxSegmentLengthOpt, so territories past that point along the line are never included
function GetTerritoriesNearLine(game, startTerritoryID, endTerritoryID, maxDistanceFromLine, maxSegmentLengthOpt)
	local ax, ay, bx, by = GetClampedLineSegment(game, startTerritoryID, endTerritoryID, maxSegmentLengthOpt);
	return GetTerritoriesNearLineSegment(game, ax, ay, bx, by, maxDistanceFromLine);
end

--Returns the (ax, ay, bx, by) coordinates of the line segment between startTerritoryID and endTerritoryID's
--centerpoints, and its length. If maxLengthOpt is given and the territories are further apart than that, the
--segment's end (bx, by) is pulled in along the same direction to maxLengthOpt, and the returned length is
--maxLengthOpt instead of the actual distance between the territories
function GetClampedLineSegment(game, startTerritoryID, endTerritoryID, maxLengthOpt)
	local startTd = game.Map.Territories[startTerritoryID];
	local endTd = game.Map.Territories[endTerritoryID];

	local ax, ay = startTd.MiddlePointX, startTd.MiddlePointY;
	local bx, by = endTd.MiddlePointX, endTd.MiddlePointY;
	local abx, aby = bx - ax, by - ay;

	local actualLength = math.sqrt(abx * abx + aby * aby);
	local length = actualLength;

	if (maxLengthOpt ~= nil and actualLength > maxLengthOpt) then
		local scale = maxLengthOpt / actualLength;
		abx, aby = abx * scale, aby * scale;
		length = maxLengthOpt;
	end

	return ax, ay, ax + abx, ay + aby, length;
end

function GetTerritoriesWithinDistance (game, targetTerritoryID, intMaxDistance)
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

function GetGrayColors()
    return {
        TextLighter = "#EEEEEE";
        TextLight = "#DDDDDD";
        TextDefault = "#CCCCCC";
        TextDark = "#BBBBBB";
        TextDarker = "#AAAAAA";
        TextColor = "#DDDDDD";
    };
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

GRAY_COLOURS = GetGrayColors();
TEXT_DEFAULT_COLOUR = GRAY_COLOURS.TextDefault;
ERROR_COLOUR = "#FF0000";
SUBHEADING_COLOUR = "#FFFF00";
BUTTON_COLOURS = GetButtonColors();