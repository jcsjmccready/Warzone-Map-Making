require('Utilities')

---Client_PresentPlayCardUI
---@param game GameClientHook
---@param cardInstance CardInstance # Read-only data about the card that the player is attempting to play
---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM) # Function that when invoked, will make the player play the card
---@param closeCardsDialog fun() # Function that when invoked will close this cards dialog
function Client_PresentPlayCardUI(game, cardInstance, playCard, closeCardsDialog)
    if (cardInstance.CardID ~= Mod.Settings.CrunchtimeCardID) then
        return;
    end

    Game = game;

    --If this dialog is already open, close the previous one.
    if (Close ~= nil) then
        Close();
    end

    closeCardsDialog();

    local existingPhases = Mod.PlayerGameData.CrunchtimePhases;
    if (existingPhases ~= nil) then
        UI.Alert("You are already in " .. PhaseEffectName(existingPhases[1].Percent) .. " and cannot restart or exit early.");
        return;
    end

    ---@type PhaseRowSetting[]
    local configuredPhases = Mod.Settings.Phases or {};
    ChosenStartIndex = 1;

    game.CreateDialog(function(rootParent, setMaxSize, setScrollable, game, close)
        Close = close;
        setMaxSize(400, 300);
        local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

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
                .SetSliderMaxValue(Mod.Settings.MaxUserSpecifiedDuration or 10)
                .SetValue(3);
        end

        InstructionLabel = UI.CreateLabel(vert).SetText("");

        UI.CreateButton(vert)
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

                local modData = CRUNCHTIME_MOD_DATA_PREFIX .. ChosenStartIndex .. "_" .. duration;
                local message = "Enter " .. PhaseEffectName(configuredPhases[ChosenStartIndex].Percent);

                if (playCard(message, modData, WL.TurnPhase.Deploys, {}, nil)) then
                    close();
                end
            end);
    end);
end
