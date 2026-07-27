require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
	Create_UI_Controls(rootParent);
end;

function Create_UI_Controls(rootParent)
	local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

	---- Timing
	local timingHeading = UI.CreateVerticalLayoutGroup(mainModUI);
	UI.CreateLabel(timingHeading).SetText('Timing:').SetColor(SUBHEADING_COLOUR);

	local horz = UI.CreateHorizontalLayoutGroup(timingHeading);
	UI.CreateLabel(horz).SetText('Turns before the clock starts').SetPreferredWidth(290);
	turnsBeforeStart = UI.CreateNumberInputField(horz)
		.SetSliderMinValue(1)
		.SetSliderMaxValue(30)
		.SetValue(Mod.Settings.TurnsBeforeStart or 6);

	local horz = UI.CreateHorizontalLayoutGroup(timingHeading);
	UI.CreateLabel(horz).SetText('Turns held before it explodes (fuse length)').SetPreferredWidth(290);
	fuseLength = UI.CreateNumberInputField(horz)
		.SetSliderMinValue(1)
		.SetSliderMaxValue(30)
		.SetValue(Mod.Settings.FuseLength or 4);

	local horz = UI.CreateHorizontalLayoutGroup(timingHeading);
	UI.CreateLabel(horz).SetText('Stop once this many players (or fewer) remain').SetPreferredWidth(290);
	minPlayersRemaining = UI.CreateNumberInputField(horz)
		.SetSliderMinValue(0)
		.SetSliderMaxValue(8)
		.SetValue(Mod.Settings.MinPlayersRemaining or 2);

	---- Who gets it
	local holderHeading = UI.CreateVerticalLayoutGroup(mainModUI);
	UI.CreateLabel(holderHeading).SetText('Who gets handed the Hot Potato when the clock starts:').SetColor(SUBHEADING_COLOUR);

	local holderSelectionGroup = UI.CreateRadioButtonGroup(holderHeading);
	holderSelectionRandom = UI.CreateRadioButton(holderHeading).SetGroup(holderSelectionGroup).SetText('A random player').SetIsChecked(not Mod.Settings.HolderSelectionBiggest);
	holderSelectionBiggest = UI.CreateRadioButton(holderHeading).SetGroup(holderSelectionGroup).SetText('The biggest player (most armies)').SetIsChecked(Mod.Settings.HolderSelectionBiggest or false);

	---- Fights
	local fightsHeading = UI.CreateVerticalLayoutGroup(mainModUI);
	UI.CreateLabel(fightsHeading).SetText('Fights that pass the Hot Potato on:').SetColor(SUBHEADING_COLOUR);
	onlyAttackWins = UI.CreateCheckBox(fightsHeading).SetText("Only count the holder attacking and winning (not defending)").SetIsChecked(Mod.Settings.OnlyAttackWins or false);

	---- Penalties
	local penaltiesHeading = UI.CreateVerticalLayoutGroup(mainModUI);
	UI.CreateLabel(penaltiesHeading).SetText('Penalties:').SetColor(SUBHEADING_COLOUR);

	local horz = UI.CreateHorizontalLayoutGroup(penaltiesHeading);
	UI.CreateLabel(horz).SetText('Holding the potato pieces: income lost each turn while held').SetPreferredWidth(290);
	minorPenaltyPercent = UI.CreateNumberInputField(horz)
		.SetSliderMinValue(0)
		.SetSliderMaxValue(1.0)
		.SetWholeNumbers(false)
		.SetValue(Mod.Settings.MinorPenaltyPercent or 0.15);

	local horz = UI.CreateHorizontalLayoutGroup(penaltiesHeading);
	UI.CreateLabel(horz).SetText('Holding the Hot Potato: percentage of armies destroyed on explosion').SetPreferredWidth(290);
	majorPenaltyPercent = UI.CreateNumberInputField(horz)
		.SetSliderMinValue(0)
		.SetSliderMaxValue(1.0)
		.SetWholeNumbers(false)
		.SetValue(Mod.Settings.MajorPenaltyPercent or 0.5);

	local horz = UI.CreateHorizontalLayoutGroup(penaltiesHeading);
	UI.CreateLabel(horz).SetText('Major penalty: minimum armies destroyed per territory').SetPreferredWidth(290);
	majorPenaltyMinDamage = UI.CreateNumberInputField(horz)
		.SetSliderMinValue(0)
		.SetSliderMaxValue(30)
		.SetValue(Mod.Settings.MajorPenaltyMinDamage or 3);
end;
