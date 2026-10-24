require("Utilities");

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    local mainVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateLabel(mainVGroup).SetText("Gives designated slots a one-time starting income change. Adjusting gold or turn 0 income if a commerce game or not.");

    local rows = {};
    for _, row in ipairs(Mod.Settings.Rows or {}) do
        if (row.Income ~= 0) then
            table.insert(rows, row);
        end
    end
    if (#rows == 0) then
        UI.CreateLabel(mainVGroup).SetText("No slots configured.");
        return;
    end

    UI.CreateLabel(mainVGroup).SetText("Slot Income:").SetColor(SUBHEADING_COLOUR);

    local columnsHorz = UI.CreateHorizontalLayoutGroup(mainVGroup).SetFlexibleWidth(1);
    local columns = {
        UI.CreateVerticalLayoutGroup(columnsHorz).SetFlexibleWidth(1),
        UI.CreateVerticalLayoutGroup(columnsHorz).SetFlexibleWidth(1),
        UI.CreateVerticalLayoutGroup(columnsHorz).SetFlexibleWidth(1),
    };
    for i, row in ipairs(rows) do
        local column = columns[((i - 1) % #columns) + 1];
        local sign = (row.Income >= 0) and "+" or "";
        UI.CreateLabel(column).SetText("Slot " .. SlotToLetter(row.Slot) .. ": " .. sign .. row.Income);
    end

    -- pad every shorter column with blank rows so all columns end at the same height
    local maxRowsPerColumn = math.ceil(#rows / #columns);
    for i, column in ipairs(columns) do
        local itemCount = math.floor(#rows / #columns) + ((i <= (#rows % #columns)) and 1 or 0);
        for _ = itemCount + 1, maxRowsPerColumn do
            UI.CreateLabel(column).SetText(".");
        end
    end
end
