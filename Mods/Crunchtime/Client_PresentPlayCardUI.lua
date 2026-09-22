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
        UI.Alert("You are already in " .. PhaseDisplayName(existingPhases[1].Phase) .. " and cannot restart or exit early.");
        return;
    end

    local allowIncrease = Mod.Settings.AllowIncreaseFirst ~= false;
    local allowDecrease = Mod.Settings.AllowDecreaseFirst ~= false;
    ChosenPhase = allowIncrease and "Increase" or "Decrease";

    game.CreateDialog(function(rootParent, setMaxSize, setScrollable, game, close)
        Close = close;
        setMaxSize(400, 250);
        local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

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
            UI.CreateLabel(durationHorz).SetText("Duration for each phase").SetPreferredWidth(290);

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

                local modData = CRUNCHTIME_MOD_DATA_PREFIX .. ChosenPhase .. "_" .. duration;
                local message = "Enter " .. PhaseDisplayName(ChosenPhase);

                if (playCard(message, modData, WL.TurnPhase.Deploys, {}, nil)) then
                    close();
                end
            end);
    end);
end
