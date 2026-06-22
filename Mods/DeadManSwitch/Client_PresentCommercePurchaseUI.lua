require('Utilities')
---Client_PresentCommercePurchaseUI hook
---@param rootParent RootParent
---@param game GameClientHook
---@param close fun() # Zero parameter function that closes the dialog
function Client_PresentCommercePurchaseUI(rootParent, game, close)

	Game = game;

	damageTypeMessage = "ERROR";

	if(Mod.Settings.isDamageTypeBomb) then
        damageTypeMessage = "a bomb is played on it.";
    end

    if(Mod.Settings.isDamageTypeFlat) then
        Mod.Settings.FlatDamage = flatDamage.GetValue();
        damageTypeMessage = Mod.Settings.FlatDamage .. " armies are killed.";
    end

    if(Mod.Settings.isDamageTypePercent) then
        Mod.Settings.PercentageDamage = percentageDamage.GetValue();
        Mod.Settings.PercentageMinDamage = percentageMinDamage.GetValue();
        damageTypeMessage = "it takes " .. math.floor(Mod.Settings.PercentageDamage * 100) .. "% damage, with a minimum of " .. Mod.Settings.PercentageMinDamage .. " armies killed.";
    end

	local horz = UI.CreateHorizontalLayoutGroup(rootParent);
    local vert = UI.CreateVerticalLayoutGroup(horz);

	UI.CreateLabel(vert).SetText("Build a Dead Man's Switch (at the end of the turn) on a territory for " .. Mod.Settings.CommerceCost .. " gold.");
	UI.CreateLabel(vert).SetText("You may have up to " .. Mod.Settings.ConcurrentDMSLimit .. " at a time.");
	UI.CreateLabel(vert).SetText("If this territory is taken, afterwards, " .. damageTypeMessage);

	UI.CreateButton(horz)
		.SetText("Build DMS")            
		.SetColor(BUTTON_COLOURS.DarkGreen)
    	.SetPreferredWidth(150)
		.SetOnClick(BuildClicked);
end

function BuildClicked()
	--Check if they're already at max.  Add in how many they have on the map plus how many purchase orders they've already made
	--We check on the client for player convenience. Another check happens on the server, so even if someone hacks their client and removes this check they still won't be able to go over the max.

	local playerID = Game.Us.ID;
	-- local structureID = WL.StructureType.Custom("Dead Man's Switch"); <- it doesn't like WL. We can't access it here I presume.

	-- local numDeadManSwitchAlreadyHave = 0;
	-- for _,territoryStanding in pairs(Game.LatestStanding.Territories) do
	-- 	if (territoryStanding.OwnerPlayerID == playerID) then
	-- 		if(territoryStanding.Structures ~= nil and territoryStanding.Structures[structureID] ~= nil) then
	-- 			numDeadManSwitchAlreadyHave = numDeadManSwitchAlreadyHave + territoryStanding.Structures[structureID];
	-- 		end
	-- 	end
	-- end

	-- for _,order in pairs(Game.Orders) do
	-- 	if (order.proxyType == 'GameOrderCustom' and startsWith(order.Payload, 'BuyDMS_')) then
	-- 		numDeadManSwitchAlreadyHave = numDeadManSwitchAlreadyHave + 1; -- todo: purchase order + split out advance turn logic to handle different entry points
	-- 	end
	-- end

	-- if (numDeadManSwitchAlreadyHave >= Mod.Settings.ConcurrentDMSLimit) then
	-- 	UI.Alert("You already have " .. numDeadManSwitchAlreadyHave .. " Dead Man's Switches! You can only have " ..  Mod.Settings.ConcurrentDMSLimit);
	-- 	return;
	-- end

	-- Game.CreateDialog(PresentSelectionDialog); 
end


function PresentSelectionDialog(rootParent, setMaxSize, setScrollable, game, close)

end