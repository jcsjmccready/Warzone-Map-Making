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

function startsWith(str, sub)
	return string.sub(str, 1, string.len(sub)) == sub;
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
