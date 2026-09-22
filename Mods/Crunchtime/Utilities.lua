CURRENT_SETTINGS_VERSION = 1;

CRUNCHTIME_MOD_DATA_PREFIX = "Crunchtime_";

--returns the number of turns the named phase should last for a player who chose chosenUserSpecifiedDuration
--(chosenUserSpecifiedDuration is ignored unless Mod.Settings.UserSpecifiedDuration is true)
function GetPhaseDuration(phase, chosenUserSpecifiedDuration)
    if (Mod.Settings.UserSpecifiedDuration) then
        return chosenUserSpecifiedDuration;
    end

    if (phase == "Increase") then
        return Mod.Settings.IncreaseDuration;
    end

    return Mod.Settings.DecreaseDuration;
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

function startsWith(str, sub)
	return string.sub(str, 1, string.len(sub)) == sub;
end

--the user-facing name for a phase: an income increase is presented as "Crunch Time", an income decrease as "Rest Time"
function PhaseDisplayName(phase)
    if (phase == "Increase") then
        return "Crunch Time";
    end
    return "Rest Time";
end

--finds a player's CrunchtimeState in the Mod.PrivateGameData.Crunchtime array, or nil if they aren't in Crunch Time.
--server-side only, since PrivateGameData isn't readable from client hooks
function FindCrunchtimeState(crunchtime, playerID)
    for _, state in ipairs(crunchtime) do
        if (state.PlayerID == playerID) then
            return state;
        end
    end
    return nil;
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
ERROR_COLOUR = "#FF0000";
SUBHEADING_COLOUR = "#FFFF00";
BUTTON_COLOURS = GetButtonColors();
