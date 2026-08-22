require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
	Create_UI_Controls(rootParent);
end;

function Create_UI_Controls(rootParent)
	local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
	
	UI.CreateLabel(mainModUI).SetText('Mod Settings:').SetColor(SUBHEADING_COLOUR);

	---- Timing
	local timingHeading = UI.CreateVerticalLayoutGroup(mainModUI);
	UI.CreateLabel(timingHeading).SetText('Timing:');

	local horz = UI.CreateHorizontalLayoutGroup(timingHeading);
	UI.CreateLabel(horz).SetText('Turns before the clock starts').SetPreferredWidth(290);
	turnsBeforeStart = UI.CreateNumberInputField(horz)
		.SetSliderMinValue(1)
		.SetSliderMaxValue(30)
		.SetValue(Mod.Settings.TurnsBeforeStart or 6);

	local horz = UI.CreateHorizontalLayoutGroup(timingHeading);
	UI.CreateLabel(horz).SetText('Turns before it restarts after exploding').SetPreferredWidth(290);
	turnsBeforeRestart = UI.CreateNumberInputField(horz)
		.SetSliderMinValue(1)
		.SetSliderMaxValue(30)
		.SetValue(Mod.Settings.TurnsBeforeRestart or 6);

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
	UI.CreateLabel(holderHeading).SetText('Who gets handed the Hot Potato when the clock starts:');

	local holderSelectionGroup = UI.CreateRadioButtonGroup(holderHeading);
	UI.CreateLabel(holderSelectionGroup).SetText('Also used for transfering hot potato on owners death*').SetColor(BUTTON_COLOURS.DarkGray);

	holderSelectionRandom = UI.CreateRadioButton(holderHeading).SetGroup(holderSelectionGroup).SetText('A random player').SetIsChecked(not Mod.Settings.HolderSelectionBiggest);
	holderSelectionBiggest = UI.CreateRadioButton(holderHeading).SetGroup(holderSelectionGroup).SetText('The biggest player (most armies)').SetIsChecked(Mod.Settings.HolderSelectionBiggest or false);


	---- Ownership announcement
	local announcementHeading = UI.CreateVerticalLayoutGroup(mainModUI);
	UI.CreateLabel(announcementHeading).SetText('Ownership announcement:');

	announceHotPotatoTransfer = UI.CreateCheckBox(announcementHeading).SetText("Announce hot potato transfer").SetIsChecked(Mod.Settings.AnnounceHotPotatoTransfer or false);
	announceHotPotatoTransfer.SetOnValueChanged(function()
		if (not announceHotPotatoTransfer.GetIsChecked()) then
			stateNewOwner.SetIsChecked(false);
		end
	end);

	stateNewOwner = UI.CreateCheckBox(announcementHeading).SetText("State new owner").SetIsChecked(Mod.Settings.StateNewOwner or false);
	stateNewOwner.SetOnValueChanged(function()
		if (stateNewOwner.GetIsChecked()) then
			announceHotPotatoTransfer.SetIsChecked(true);
		end
	end);

	---- Fights
	local fightsHeading = UI.CreateVerticalLayoutGroup(mainModUI);
	UI.CreateLabel(fightsHeading).SetText('Fights that pass the Hot Potato on:');
	UI.CreateLabel(fightsHeading).SetText('One transfer per turn*').SetColor(BUTTON_COLOURS.DarkGray);
	UI.CreateLabel(fightsHeading).SetText('Win a fight to transfer ownership of the potato').SetColor(BUTTON_COLOURS.DarkGray);
	onlyAttackWins = UI.CreateCheckBox(fightsHeading).SetText("Only count the holder attacking and winning (not defending)").SetIsChecked(Mod.Settings.OnlyAttackWins or false);

	UI.CreateLabel(mainModUI).SetText('Penalty Settings:').SetColor(SUBHEADING_COLOUR);

	---- Minor penalty
	local minorPenaltyHeading = UI.CreateVerticalLayoutGroup(mainModUI);
	UI.CreateLabel(minorPenaltyHeading).SetText('Penalty for holding Potato:').SetColor(BUTTON_COLOURS.Orange);

	local horz = UI.CreateHorizontalLayoutGroup(minorPenaltyHeading);
	UI.CreateLabel(horz).SetText('Income loss %').SetPreferredWidth(290);
	minorPenaltyPercent = UI.CreateNumberInputField(horz)
		.SetSliderMinValue(0)
		.SetSliderMaxValue(1.0)
		.SetWholeNumbers(false)
		.SetValue(Mod.Settings.MinorPenaltyPercent or 0.15);

	local horz = UI.CreateHorizontalLayoutGroup(minorPenaltyHeading);
	UI.CreateLabel(horz).SetText('Income loss minimum').SetPreferredWidth(290);
	minorPenaltyMinDamage = UI.CreateNumberInputField(horz)
		.SetSliderMinValue(0)
		.SetSliderMaxValue(30)
		.SetValue(Mod.Settings.MinorPenaltyMinDamage or 1);

	---- Major penalty
	local majorPenaltyHeading = UI.CreateVerticalLayoutGroup(mainModUI);
	UI.CreateLabel(majorPenaltyHeading).SetText('Penalty for Potato exploding in your hands:').SetColor(BUTTON_COLOURS.OrangeRed);

	local horz = UI.CreateHorizontalLayoutGroup(majorPenaltyHeading);
	UI.CreateLabel(horz).SetText('% of armies lost per friendly territory').SetPreferredWidth(290);
	majorPenaltyPercent = UI.CreateNumberInputField(horz)
		.SetSliderMinValue(0)
		.SetSliderMaxValue(1.0)
		.SetWholeNumbers(false)
		.SetValue(Mod.Settings.MajorPenaltyPercent or 0.5);

	local horz = UI.CreateHorizontalLayoutGroup(majorPenaltyHeading);
	UI.CreateLabel(horz).SetText('Minimum armies lost per friendly territory').SetPreferredWidth(290);
	majorPenaltyMinDamage = UI.CreateNumberInputField(horz)
		.SetSliderMinValue(0)
		.SetSliderMaxValue(30)
		.SetValue(Mod.Settings.MajorPenaltyMinDamage or 3);

	local horz = UI.CreateHorizontalLayoutGroup(majorPenaltyHeading);
	UI.CreateLabel(horz).SetText('Income loss %').SetPreferredWidth(290);
	majorPenaltyIncomeLossPercent = UI.CreateNumberInputField(horz)
		.SetSliderMinValue(0)
		.SetSliderMaxValue(1.0)
		.SetWholeNumbers(false)
		.SetValue(Mod.Settings.MajorPenaltyIncomeLossPercent or 0.25);

	local horz = UI.CreateHorizontalLayoutGroup(majorPenaltyHeading);
	UI.CreateLabel(horz).SetText('Income loss minimum').SetPreferredWidth(290);
	majorPenaltyIncomeLossMinDamage = UI.CreateNumberInputField(horz)
		.SetSliderMinValue(0)
		.SetSliderMaxValue(30)
		.SetValue(Mod.Settings.MajorPenaltyIncomeLossMinDamage or 3);

	local horz = UI.CreateHorizontalLayoutGroup(majorPenaltyHeading);
	UI.CreateLabel(horz).SetText('% of non-friendly territories with complete fog').SetPreferredWidth(290);
	majorPenaltyFogPercent = UI.CreateNumberInputField(horz)
		.SetSliderMinValue(0)
		.SetSliderMaxValue(1.0)
		.SetWholeNumbers(false)
		.SetValue(Mod.Settings.MajorPenaltyFogPercent or 0.25);

	local horz = UI.CreateHorizontalLayoutGroup(majorPenaltyHeading);
	UI.CreateLabel(horz).SetText('Duration of fog').SetPreferredWidth(290);
	majorPenaltyFogDuration = UI.CreateNumberInputField(horz)
		.SetSliderMinValue(1)
		.SetSliderMaxValue(30)
		.SetValue(Mod.Settings.MajorPenaltyFogDuration or 3);
end;
