function startsWith(str, sub)
	return string.sub(str, 1, string.len(sub)) == sub;
end

-- Stats match FizzerWL/ExampleMods TanksMod.
---@param ownerID PlayerID
---@param placeholderSpecialUnit CustomSpecialUnit | nil # the live Placeholder being replaced, if there is one - it
---already carries every one of these fields, since CSBMS built it as a 1:1 stand-in for this exact unit
function BuildSpecialUnitExample(ownerID, placeholderSpecialUnit)
	local builder = WL.CustomSpecialUnitBuilder.Create(ownerID);
	builder.Name = 'SpecialUnitExample';
	builder.IncludeABeforeName = true;
	builder.ImageFilename = 'SpecialUnitExample.png';
	builder.AttackPower = 5;
	builder.DefensePower = 5;
	builder.CombatOrder = 3415; -- defends commanders
	builder.DamageToKill = 5;
	builder.DamageAbsorbedWhenAttacked = 5;
	builder.CanBeGiftedWithGiftCard = true;
	builder.CanBeTransferredToTeammate = true;
	builder.CanBeAirliftedToSelf = true;
	builder.CanBeAirliftedToTeammate = true;
	builder.IsVisibleToAllPlayers = false;

	if (placeholderSpecialUnit ~= nil) then
		-- Mapping the Placeholder's own fields across instead of the hardcoded defaults above - this is the
		-- same data a game-maker configured (or an exported live unit carried)
		builder.AttackPower = placeholderSpecialUnit.AttackPower;
		builder.DefensePower = placeholderSpecialUnit.DefensePower;
		builder.CombatOrder = placeholderSpecialUnit.CombatOrder;
		builder.DamageToKill = placeholderSpecialUnit.DamageToKill;
		builder.DamageAbsorbedWhenAttacked = placeholderSpecialUnit.DamageAbsorbedWhenAttacked;
		builder.CanBeGiftedWithGiftCard = placeholderSpecialUnit.CanBeGiftedWithGiftCard;
		builder.CanBeTransferredToTeammate = placeholderSpecialUnit.CanBeTransferredToTeammate;
		builder.CanBeAirliftedToSelf = placeholderSpecialUnit.CanBeAirliftedToSelf;
		builder.CanBeAirliftedToTeammate = placeholderSpecialUnit.CanBeAirliftedToTeammate;
		builder.IsVisibleToAllPlayers = placeholderSpecialUnit.IsVisibleToAllPlayers;
	end

	return builder.Build();
end
