CURRENT_SETTINGS_VERSION = 2;

function MigrateModSettings()
    local version = Mod.Settings.Version or 1;

    if (version < 2) then
        -- version 1: the mod only supported Reconnaissance, and had no Enabled flag for it - if the mod was
        -- configured at all, Reconnaissance was implicitly always enabled.
        if (Mod.Settings.ReconnaissanceEnabled == nil) then
            Mod.Settings.ReconnaissanceEnabled = true;
        end

        if (Mod.Settings.SurveillanceEnabled == nil) then
            Mod.Settings.SurveillanceEnabled = false;
        end
    end
end

--returns territoryID plus all of its directly connected neighbours, used to mimic the area a recon card reveals
function GetTerritoryAndAdjacentIDs(game, territoryID)
    local territories = { territoryID };
    for neighbourID, _ in pairs(game.Map.Territories[territoryID].ConnectedTo or {}) do
        table.insert(territories, neighbourID);
    end
    return territories;
end

--splits str on literal separator pat (not a Lua pattern); uses plain-text find rather than the lazy "(.-)" pattern
--match, since that recurses once per unmatched character and hits Lua's "pattern too complex" limit on long strings
function split(str, pat)
   local t = {}
   local last_end = 1
   local first = true
   local s, e = str:find(pat, 1, true)
   while s do
      local cap = str:sub(last_end, s - 1);
      if not (first and cap == "") then
         table.insert(t, cap);
      end
      first = false;
      last_end = e + 1
      s, e = str:find(pat, last_end, true)
   end
   if last_end <= #str then
      table.insert(t, str:sub(last_end));
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

function first(array, func)
	for _,v in pairs(array) do
		if (func == nil or func(v)) then
			return v;
		end
	end
	return nil;
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

--given 0-255 RGB integers, return a single 24-bit integer, useful for annotations
function GetColourInteger (red, green, blue)
	return red*256^2 + green*256 + blue;
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
SUBHEADING_COLOUR2 = BUTTON_COLOURS.LightBlue;
