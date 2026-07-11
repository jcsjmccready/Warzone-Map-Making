
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



TEXT_DEFAULT_COLOUR = "#CCCCCC";
ERROR_COLOUR = "#FF0000";
SUBHEADING_COLOUR = "#FFFF00";
BUTTON_COLOURS = GetButtonColors();