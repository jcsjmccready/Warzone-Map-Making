require("Utilities");

---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID
function Client_SaveConfigureUI(alert, addCard)
    Mod.Settings.Version = CURRENT_SETTINGS_VERSION;

    local rows = {};
    local outOfRangeSlotLetters = {};
    for _, row in ipairs(SlotStartingIncomeConfigureState.Rows) do
        local slot = row.SlotDropdown.GetKey();
        local income = row.IncomeField.GetValue();
        if (income > MAX_VALUE_MODIFIER or income < -MAX_VALUE_MODIFIER) then
            table.insert(outOfRangeSlotLetters, SlotToLetter(slot));
        end
        table.insert(rows, { Slot = slot, Income = income });
    end

    if (#outOfRangeSlotLetters > 0) then
        alert("Income must be between -" .. MAX_VALUE_MODIFIER .. " and " .. MAX_VALUE_MODIFIER .. "\nSlots: " .. table.concat(outOfRangeSlotLetters, ", "));
        return;
    end

    Mod.Settings.Rows = rows;
end
