require('Utilities')

---Client_PresentMenuUI hook
---@param rootParent RootParent
---@param setMaxSize fun(width: number, height: number)
---@param setScrollable fun(horizontallyScrollable: boolean, verticallyScrollable: boolean)
---@param game GameClientHook
---@param close fun()
function Client_PresentMenuUI(rootParent, setMaxSize, setScrollable, game, close)
    Game = game;
    Close = close;

    setMaxSize(400, 300);

    local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(vert).SetText("Crunch Time").SetColor(SUBHEADING_COLOUR);

    ---@type CrunchTimePhase[] | nil
    local myPhases = Mod.PlayerGameData.CrunchtimePhases;

    if (myPhases ~= nil) then
        local currentPhase = myPhases[1];
        UI.CreateLabel(vert).SetText("You are currently in " .. PhaseEffectName(currentPhase.Percent) .. " - income is " .. (currentPhase.Percent >= 0 and "increasing" or "decreasing") .. ".");
        UI.CreateLabel(vert).SetText("Turns remaining in this phase: " .. (currentPhase.FinalTurn - Game.Game.TurnNumber));

        if (#myPhases > 1) then
            local nextPhase = myPhases[2];
            UI.CreateLabel(vert).SetText("After that, " .. PhaseEffectName(nextPhase.Percent) .. " begins - income will " .. (nextPhase.Percent >= 0 and "increase" or "decrease") .. " for " .. (nextPhase.FinalTurn - currentPhase.FinalTurn) .. " turn(s).");
        else
            UI.CreateLabel(vert).SetText("This is the final phase - it will end afterwards.");
        end

        UI.CreateLabel(vert).SetText("Cannot be exited early.").SetColor(ERROR_COLOUR);
        return;
    end

    if (not Mod.Settings.TriggerTypeMenu) then
        UI.CreateLabel(vert).SetText("Crunch Time is entered by playing the Crunch Time card, not from this menu.");
        return;
    end

    ---@type PhaseRowSetting[]
    local configuredPhases = Mod.Settings.Phases or {};
    ChosenStartIndex = 1;

    if (Mod.Settings.PhaseOrderPlayerSelected and #configuredPhases > 1) then
        UI.CreateLabel(vert).SetText("Choose which phase to start on. Once started, it cannot be exited early.");

        local phaseGroup = UI.CreateRadioButtonGroup(vert);
        for i, row in ipairs(configuredPhases) do
            local rowBtn = UI.CreateRadioButton(vert).SetGroup(phaseGroup).SetText(DescribePhaseRow(row)).SetIsChecked(i == 1);
            rowBtn.SetOnValueChanged(function()
                if (rowBtn.GetIsChecked()) then ChosenStartIndex = i; end
            end);
        end
    else
        UI.CreateLabel(vert).SetText("This will begin with " .. DescribePhaseRow(configuredPhases[1]) .. ". Once started, it cannot be exited early.");
    end

    if (Mod.Settings.UserSpecifiedDuration) then
        local durationHorz = UI.CreateHorizontalLayoutGroup(vert);
        UI.CreateLabel(durationHorz).SetText("Duration in turns (applies to every phase)").SetPreferredWidth(290);
        DurationField = UI.CreateNumberInputField(durationHorz)
            .SetWholeNumbers(true)
            .SetSliderMinValue(1)
            .SetSliderMaxValue(Mod.Settings.MaxUserSpecifiedDuration or 20)
            .SetValue(1);
    end

    InstructionLabel = UI.CreateLabel(vert).SetText("");

    BeginBtn = UI.CreateButton(vert)
        .SetText("Begin")
        .SetColor(BUTTON_COLOURS.DarkGreen)
        .SetOnClick(function()
            local duration = 0;
            if (Mod.Settings.UserSpecifiedDuration) then
                duration = math.floor(DurationField.GetValue());
                if (duration < 1) then
                    InstructionLabel.SetText("Duration must be at least 1 turn").SetColor(ERROR_COLOUR);
                    return;
                end
            end

            local payload = CRUNCHTIME_MOD_DATA_PREFIX .. ChosenStartIndex .. "_" .. duration;
            local message = "Enter " .. PhaseEffectName(configuredPhases[ChosenStartIndex].Percent);

            table.insert(game.Orders, WL.GameOrderCustom.Create(Game.Us.ID, message, payload, nil, WL.TurnPhase.Deploys));
            close();
        end);
end
