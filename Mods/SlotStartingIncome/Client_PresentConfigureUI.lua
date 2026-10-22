require("Utilities");

-- Read by Client_SaveConfigureUI once the player saves
SlotStartingIncomeConfigureState = { Rows = {} };

local rowsContainer; -- set by Client_PresentConfigureUI, every helper below closes over it
local addRowBtn; -- set by Client_PresentConfigureUI, updated as rows are added/removed

local INCOME_SLIDER_RANGE = 50;

---Every slot currently selected by a row other than excludeRow
---@param excludeRow table | nil
---@return table<integer, boolean>
local function GetUsedSlots(excludeRow)
    local used = {};
    for _, row in ipairs(SlotStartingIncomeConfigureState.Rows) do
        if (row ~= excludeRow) then
            used[row.SlotDropdown.GetKey()] = true;
        end
    end
    return used;
end

---Slot options still selectable by row, i.e. every slot not already taken by a different row
---@param row table | nil
---@return { Key: integer, Text: string }[]
local function GetAvailableSlotOptionsFor(row)
    local used = GetUsedSlots(row);
    local options = {};
    for _, option in ipairs(GetAllSlotOptions()) do
        if (not used[option.Key]) then
            table.insert(options, option);
        end
    end
    return options;
end

---First slot not currently used by any row, or nil if every slot (A-OJ) is taken
---@return integer | nil
local function GetFirstUnusedSlot()
    local options = GetAvailableSlotOptionsFor(nil);
    if (#options == 0) then return nil; end
    return options[1].Key;
end

---@param row table
local function RemoveConfigRow(row)
    for i, candidate in ipairs(SlotStartingIncomeConfigureState.Rows) do
        if (candidate == row) then
            table.remove(SlotStartingIncomeConfigureState.Rows, i);
            break;
        end
    end
    UI.Destroy(row.Container);

    -- re-enables if any slots aren't taken
    addRowBtn.SetInteractable(GetFirstUnusedSlot() ~= nil);
end

---@param defaultSlot integer
---@param defaultIncome integer
local function AddConfigRow(defaultSlot, defaultIncome)
    local rowHorz = UI.CreateHorizontalLayoutGroup(rowsContainer).SetFlexibleWidth(1);

    local row; -- forward declared, the dropdown/delete button below need to close over it before it's created

    local dropdown = CreateDropDown(rowHorz, function() return GetAvailableSlotOptionsFor(row); end, defaultSlot, nil);
    dropdown.Button
        .SetPreferredWidth(60)
        .SetMinWidth(0)
        .SetFlexibleWidth(0);

    local incomeField = UI.CreateNumberInputField(rowHorz)
        .SetWholeNumbers(true)
        .SetSliderMinValue(-INCOME_SLIDER_RANGE)
        .SetSliderMaxValue(INCOME_SLIDER_RANGE)
        .SetValue(defaultIncome or 0)
        .SetSliderPreferredWidth(300)
        .SetBoxPreferredWidth(80)
        .SetPreferredWidth(0)
        .SetMinWidth(0)
        .SetFlexibleWidth(1);

    row = { Container = rowHorz, SlotDropdown = dropdown, IncomeField = incomeField };

    UI.CreateButton(rowHorz)
        .SetText("X")
        .SetColor(BUTTON_COLOURS.Red)
        .SetPreferredWidth(40)
        .SetMinWidth(0)
        .SetFlexibleWidth(0)
        .SetOnClick(function() RemoveConfigRow(row); end);

    table.insert(SlotStartingIncomeConfigureState.Rows, row);

    -- disables if all slots are taken
    addRowBtn.SetInteractable(GetFirstUnusedSlot() ~= nil);
end

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
    SlotStartingIncomeConfigureState.Rows = {};

    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateEmpty(mainModUI).SetPreferredHeight(10);

    -- The header row is added as the first child of rowsContainer, below, rather than as a sibling of it - that
    -- way it shares the exact same layout context as the rows and its columns line up with theirs
    rowsContainer = UI.CreateVerticalLayoutGroup(mainModUI).SetFlexibleWidth(1);

    local headerHorz = UI.CreateHorizontalLayoutGroup(rowsContainer).SetFlexibleWidth(1);
    UI.CreateLabel(headerHorz).SetText("Slot").SetColor(SUBHEADING_COLOUR)
        .SetAlignment(WL.TextAlignmentOptions.Center)
        .SetPreferredWidth(60)
        .SetMinWidth(0)
        .SetFlexibleWidth(0);

    UI.CreateLabel(headerHorz).SetText("Income +-").SetColor(SUBHEADING_COLOUR)
        .SetAlignment(WL.TextAlignmentOptions.Left)
        .SetPreferredWidth(0)
        .SetMinWidth(0)
        .SetFlexibleWidth(1);

    addRowBtn = UI.CreateButton(headerHorz)
        .SetText("+")
        .SetColor(BUTTON_COLOURS.DarkGreen)
        .SetPreferredWidth(40)
        .SetMinWidth(0)
        .SetFlexibleWidth(0)
        .SetOnClick(function()
            local slot = GetFirstUnusedSlot();
            if (slot ~= nil) then
                AddConfigRow(slot, 0);
            end
        end);

    for _, savedRow in ipairs(Mod.Settings.Rows or {}) do
        AddConfigRow(savedRow.Slot, savedRow.Income);
    end

    addRowBtn.SetInteractable(GetFirstUnusedSlot() ~= nil);
end
