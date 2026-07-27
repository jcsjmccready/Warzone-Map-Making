---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
	local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

	UI.CreateLabel(descriptionVGroup).SetText("After " .. Mod.Settings.TurnsBeforeStart .. " turns, the clock starts and the Hot Potato is handed to " ..
		(Mod.Settings.HolderSelectionBiggest and "the biggest player." or "a random player."));
	UI.CreateLabel(descriptionVGroup).SetText("The holder receives a piece of the Hot Potato card for every turn it has survived without being passed on - watch their piece count to see how close it is to going off.");

	local fightsMessage = Mod.Settings.OnlyAttackWins
		and "The first time each turn the holder wins an attack against another player, the Hot Potato passes to the loser."
		or "The first time each turn the holder wins an attack or successfully defends against another player, the Hot Potato passes to the loser.";
	UI.CreateLabel(descriptionVGroup).SetText(fightsMessage);
	UI.CreateLabel(descriptionVGroup).SetText("All of its pieces move with it - the count doesn't reset when it's passed on. It can never be passed straight back to whoever it was just received from.");

	UI.CreateLabel(descriptionVGroup).SetText("While held, the holder's income is reduced by " .. math.floor(Mod.Settings.MinorPenaltyPercent * 100) .. "% each turn.");
	UI.CreateLabel(descriptionVGroup).SetText("Once it reaches " .. Mod.Settings.FuseLength .. " pieces, it has one full turn at that count before it detonates: its pieces are taken away, " ..
		math.floor(Mod.Settings.MajorPenaltyPercent * 100) .. "% of the armies (minimum " .. Mod.Settings.MajorPenaltyMinDamage .. ") on every territory the holder owns are destroyed, and the clock resets. (Passing on an already fully-armed potato does not buy the new holder a fresh turn - it can still go off in their hands right away.)");

	UI.CreateLabel(descriptionVGroup).SetText("Once " .. Mod.Settings.MinPlayersRemaining .. " or fewer players remain, the Hot Potato stops for good.");
end
