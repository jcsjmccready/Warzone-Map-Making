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

function filter(array, func)
	local new_array = {};
	local i = 1;
	for _,v in pairs(array) do
		if (func(v)) then
			new_array[i] = v;
			i = i + 1;
		end
	end
	return new_array;
end

function shuffleInPlace(tbl)
	for i = #tbl, 2, -1 do
		local j = math.random(i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
end

function randomFromArray(array)
	local len = #array;
	if (len == 0) then return nil; end;
	local i = math.random(len);
	return array[i];
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

BUILTIN_CARD_DISPLAY_NAMES = {
    CardGameAbandon = "Emergency Blockade Card",
    CardGameAirlift = "Airlift Card",
    CardGameBlockade = "Blockade Card",
    CardGameBomb = "Bomb Card",
    CardGameDiplomacy = "Diplomacy Card",
    CardGameGift = "Gift Card",
    CardGameOrderDelay = "Order Delay Card",
    CardGameOrderPriority = "Order Priority Card",
    CardGameReconnaissance = "Reconnaissance Card",
    CardGameReinforcement = "Reinforcement Card",
    CardGameSanctions = "Sanctions Card",
    CardGameSpy = "Spy Card",
    CardGameSurveillance = "Surveillance Card",
};

function GetCardDisplayName(game, cardID)
    local cardSettings = game.Settings.Cards[cardID];
    if (cardSettings == nil) then
        return "Card #" .. cardID;
    end

    if (cardSettings.proxyType == 'CardGameCustom') then
        return cardSettings.Name;
    end

    return BUILTIN_CARD_DISPLAY_NAMES[cardSettings.proxyType] or ("Card #" .. cardID);
end

function GetPiecesForRecoveryPercent(game, cardID, percent)
    local cardSettings = game.Settings.Cards[cardID];
    local numPieces = (cardSettings ~= nil and cardSettings.NumPieces) or 1;
    local piecesAwarded = math.max(math.floor(percent * numPieces + 0.5), 1);
    return piecesAwarded, numPieces;
end

function IsCardImmuneToCorruption(cardID)
	return cardID == Mod.Settings.BuddingCorruptionCardID
		or cardID == Mod.Settings.CorruptionCardID
		or cardID == Mod.Settings.CorruptedCardID;
end

function GetCorruptibleCards(playerCards)
	local eligible = {};
	for cardInstanceID, cardInstance in pairs(playerCards.WholeCards) do
		if (not IsCardImmuneToCorruption(cardInstance.CardID)) then
			table.insert(eligible, { InstanceID = cardInstanceID, Instance = cardInstance });
		end
	end
	return eligible;
end
