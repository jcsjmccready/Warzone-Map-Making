---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID
function Client_SaveConfigureUI(alert, addCard)

	Mod.Settings.TurnsBeforeStart = turnsBeforeStart.GetValue();
	if (Mod.Settings.TurnsBeforeStart < 1) then
		alert("Turns before the clock starts cannot be less than 1");
		return;
	end

	Mod.Settings.FuseLength = fuseLength.GetValue();
	if (Mod.Settings.FuseLength < 1) then
		alert("Fuse length cannot be less than 1");
		return;
	end

	Mod.Settings.MinPlayersRemaining = minPlayersRemaining.GetValue();
	if (Mod.Settings.MinPlayersRemaining < 0) then
		alert("Minimum players remaining cannot be less than 0");
		return;
	end

	Mod.Settings.HolderSelectionBiggest = holderSelectionBiggest.GetIsChecked();
	Mod.Settings.OnlyAttackWins = onlyAttackWins.GetIsChecked();

	Mod.Settings.MinorPenaltyPercent = minorPenaltyPercent.GetValue();
	if (Mod.Settings.MinorPenaltyPercent < 0 or Mod.Settings.MinorPenaltyPercent > 1) then
		alert("Minor penalty percentage must be between 0 and 1");
		return;
	end

	Mod.Settings.MajorPenaltyPercent = majorPenaltyPercent.GetValue();
	if (Mod.Settings.MajorPenaltyPercent < 0 or Mod.Settings.MajorPenaltyPercent > 1) then
		alert("Major penalty percentage must be between 0 and 1");
		return;
	end

	Mod.Settings.MajorPenaltyMinDamage = majorPenaltyMinDamage.GetValue();
	if (Mod.Settings.MajorPenaltyMinDamage < 0) then
		alert("Major penalty minimum damage cannot be less than 0");
		return;
	end

	Mod.Settings.CardID = addCard("Hot Potato", "You're going to want to get rid of this... \n[Can't be Played]", "HotPotato.png", Mod.Settings.FuseLength + 1, 0, 0, 0);
end
