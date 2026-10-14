function startsWith(str, sub)
	return string.sub(str, 1, string.len(sub)) == sub;
end

-- Stats match FizzerWL/ExampleMods TanksMod.
function BuildTank(ownerID)
	local builder = WL.CustomSpecialUnitBuilder.Create(ownerID);
	builder.Name = 'Tank';
	builder.IncludeABeforeName = true;
	builder.ImageFilename = 'Tank.png';
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
	return builder.Build();
end
