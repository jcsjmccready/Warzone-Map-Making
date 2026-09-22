require("Utilities");

---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID # Creates a custom card. Can be invoked multiple times to create multiple cards. Every invokation will return the CardID of the just created card, make sure to save this in the settings of your mod
function Client_SaveConfigureUI(alert, addCard)
    Mod.Settings.Version = CURRENT_SETTINGS_VERSION;

    Mod.Settings.TriggerTypeCard = triggerTypeCard.GetIsChecked();
    Mod.Settings.TriggerTypeMenu = triggerTypeMenu.GetIsChecked();

    -- both modes write into the same Mod.Settings.Phases / PhaseOrderPlayerSelected / UserSpecifiedDuration shape
    -- that Server_AdvanceTurn.lua reads - Basic mode is just a simpler UI over that same data
    Mod.Settings.ConfigMode = basicModeBtn.GetIsChecked() and "Basic" or "Advanced";

    local ok;
    if (basicModeBtn.GetIsChecked()) then
        ok = Save_Basic_Mode(alert);
    else
        ok = Save_Advanced_Mode(alert);
    end
    if (not ok) then return; end

    if (Mod.Settings.TriggerTypeCard) then
        Mod.Settings.NumPieces = numPieces.GetValue();
        Mod.Settings.CardWeight = cardWeight.GetValue();
        Mod.Settings.MinPieces = minPieces.GetValue();
        Mod.Settings.InitialPieces = initialPieces.GetValue();

        if (Mod.Settings.NumPieces < 1) then
            alert("Number of pieces cannot be less than 1");
            return;
        end
        if (Mod.Settings.CardWeight < 0) then
            alert("Card weight cannot be less than 0");
            return;
        end
        if (Mod.Settings.MinPieces < 0) then
            alert("Minimum pieces cannot be less than 0");
            return;
        end
        if (Mod.Settings.InitialPieces < 0) then
            alert("Initial pieces cannot be less than 0");
            return;
        end

        local crunchtimeCardID = addCard(
            "Crunch Time Card",
            "Play this card to enter Crunch Time, a sequence of temporary income changes. Once started, it cannot be exited early.",
            "CrunchTime.png",
            Mod.Settings.NumPieces,
            Mod.Settings.MinPieces,
            Mod.Settings.InitialPieces,
            Mod.Settings.CardWeight);
        Mod.Settings.CrunchtimeCardID = crunchtimeCardID;
    end
end

--Advanced mode: reads the arbitrary list of phase rows the map maker built up directly
---@param alert fun(message: string)
---@return boolean
function Save_Advanced_Mode(alert)
    Mod.Settings.PhaseOrderPlayerSelected = phaseOrderPlayerSelected.GetIsChecked();

    if (Mod.Settings.PhaseOrderPlayerSelected and userSpecifiedDuration ~= nil) then
        Mod.Settings.UserSpecifiedDuration = userSpecifiedDuration.GetIsChecked();
    else
        -- dynamic duration only exists when the player is already choosing a starting phase - without that
        -- entry dialog there's nowhere to put a duration field
        Mod.Settings.UserSpecifiedDuration = false;
    end

    if (Mod.Settings.UserSpecifiedDuration) then
        Mod.Settings.MaxUserSpecifiedDuration = maxUserSpecifiedDuration.GetValue();

        if (Mod.Settings.MaxUserSpecifiedDuration < 1) then
            alert("Maximum duration must be at least 1 turn");
            return false;
        end
    else
        Mod.Settings.MaxUserSpecifiedDuration = nil;
    end

    if (#PhaseRows < 2) then
        alert("At least 2 phases are required");
        return false;
    end

    local phases = {};
    for _, row in ipairs(PhaseRows) do
        local duration = row.DurationField.GetValue();
        if (duration < 1) then
            alert("Each phase's duration must be at least 1 turn");
            return false;
        end

        table.insert(phases, {
            Duration = duration,
            Percent = row.PercentField.GetValue(),
            FlatAmount = row.FlatField.GetValue(),
        });
    end
    Mod.Settings.Phases = phases;

    return true;
end

--Basic mode: reads the fixed Crunch Time (increase) / Rest Time (decrease) UI and translates it into the same
--Phases / PhaseOrderPlayerSelected shape Advanced mode produces:
-- - both orders allowed -> Phases = {increase, decrease}, PhaseOrderPlayerSelected = true (player picks either)
-- - only increase allowed -> Phases = {increase, decrease}, PhaseOrderPlayerSelected = false (fixed at increase)
-- - only decrease allowed -> Phases = {decrease, increase}, PhaseOrderPlayerSelected = false (fixed at decrease)
---@param alert fun(message: string)
---@return boolean
function Save_Basic_Mode(alert)
    local incPercent = increasePercent.GetValue();
    local incFlat = increaseFlatAmount.GetValue();
    local decPercent = decreasePercent.GetValue();
    local decFlat = decreaseFlatAmount.GetValue();

    if (incPercent < 0) then
        alert("Percentage income increase cannot be less than 0");
        return false;
    end
    if (incFlat < 0) then
        alert("Flat income increase cannot be less than 0");
        return false;
    end
    if (decPercent < 0) then
        alert("Percentage income decrease cannot be less than 0");
        return false;
    end
    if (decFlat < 0) then
        alert("Flat income decrease cannot be less than 0");
        return false;
    end

    local allowIncrease = allowIncreaseFirst.GetIsChecked();
    local allowDecrease = allowDecreaseFirst.GetIsChecked();
    if (not allowIncrease and not allowDecrease) then
        alert("At least one starting order must be allowed");
        return false;
    end

    Mod.Settings.UserSpecifiedDuration = userSpecifiedDuration.GetIsChecked();

    local incDuration, decDuration;
    if (Mod.Settings.UserSpecifiedDuration) then
        Mod.Settings.MaxUserSpecifiedDuration = maxUserSpecifiedDuration.GetValue();
        if (Mod.Settings.MaxUserSpecifiedDuration < 1) then
            alert("Maximum duration must be at least 1 turn");
            return false;
        end
        -- ignored at runtime (UserSpecifiedDuration overrides every phase's Duration), but still saved so the
        -- fields have something sensible to show if the map maker switches this checkbox back off later
        incDuration = 1;
        decDuration = 1;
    else
        Mod.Settings.MaxUserSpecifiedDuration = nil;
        incDuration = increaseDuration.GetValue();
        decDuration = decreaseDuration.GetValue();

        if (incDuration < 1) then
            alert("Crunch Time duration must be at least 1 turn");
            return false;
        end
        if (decDuration < 1) then
            alert("Rest Time duration must be at least 1 turn");
            return false;
        end
    end

    local increaseRow = { Duration = incDuration, Percent = incPercent, FlatAmount = incFlat };
    local decreaseRow = { Duration = decDuration, Percent = -decPercent, FlatAmount = -decFlat };

    if (allowIncrease and allowDecrease) then
        Mod.Settings.Phases = { increaseRow, decreaseRow };
        Mod.Settings.PhaseOrderPlayerSelected = true;
    elseif (allowIncrease) then
        Mod.Settings.Phases = { increaseRow, decreaseRow };
        Mod.Settings.PhaseOrderPlayerSelected = false;
    else
        Mod.Settings.Phases = { decreaseRow, increaseRow };
        Mod.Settings.PhaseOrderPlayerSelected = false;
    end

    return true;
end
