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

    setMaxSize(400, 260);

    local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(vert).SetText("Crunch Time").SetColor(SUBHEADING_COLOUR);

    ---@type CrunchTimePhase[] | nil
    local myPhases = Mod.PlayerGameData.CrunchtimePhases;

    if (myPhases ~= nil) then
        local currentPhase = myPhases[1];
        UI.CreateLabel(vert).SetText("You are currently in " .. PhaseDisplayName(currentPhase.Phase) .. " - income is " .. (currentPhase.Phase == "Increase" and "increasing" or "decreasing") .. ".");
        UI.CreateLabel(vert).SetText("Turns remaining in this phase: " .. (currentPhase.FinalTurn - Game.Game.TurnNumber));

        if (#myPhases > 1) then
            local nextPhase = myPhases[2];
            UI.CreateLabel(vert).SetText("After that, " .. PhaseDisplayName(nextPhase.Phase) .. " begins - income will " .. (nextPhase.Phase == "Increase" and "increase" or "decrease") .. " for " .. (nextPhase.FinalTurn - currentPhase.FinalTurn) .. " turn(s).");
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

    local allowIncrease = Mod.Settings.AllowIncreaseFirst ~= false;
    local allowDecrease = Mod.Settings.AllowDecreaseFirst ~= false;
    ChosenPhase = allowIncrease and "Increase" or "Decrease";

    if (allowIncrease and allowDecrease) then
        UI.CreateLabel(vert).SetText("Choose whether to start with Crunch Time or Rest Time. Once started, it cannot be exited early.");

        local phaseGroup = UI.CreateRadioButtonGroup(vert);
        local increaseBtn = UI.CreateRadioButton(vert).SetGroup(phaseGroup).SetText("Start with Crunch Time (income increase)").SetIsChecked(true);
        local decreaseBtn = UI.CreateRadioButton(vert).SetGroup(phaseGroup).SetText("Start with Rest Time (income decrease)").SetIsChecked(false);

        increaseBtn.SetOnValueChanged(function()
            if (increaseBtn.GetIsChecked()) then ChosenPhase = "Increase"; end
        end);
        decreaseBtn.SetOnValueChanged(function()
            if (decreaseBtn.GetIsChecked()) then ChosenPhase = "Decrease"; end
        end);
    else
        UI.CreateLabel(vert).SetText("This will begin with " .. PhaseDisplayName(ChosenPhase) .. ". Once started, it cannot be exited early.");
    end

    if (Mod.Settings.UserSpecifiedDuration) then
        local durationHorz = UI.CreateHorizontalLayoutGroup(vert);
        UI.CreateLabel(durationHorz).SetText("Duration in turns (applies to both phases)").SetPreferredWidth(290);
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

            local payload = CRUNCHTIME_MOD_DATA_PREFIX .. ChosenPhase .. "_" .. duration;
            local message = "Enter " .. PhaseDisplayName(ChosenPhase);

            table.insert(game.Orders, WL.GameOrderCustom.Create(Game.Us.ID, message, payload, nil, WL.TurnPhase.Deploys));
            close();
        end);
end
