require("Utilities");
require("ModConstants");
require("IO.Writer");

---@class RowTemplateRow
---@field Key string
---@field Value string

---@class RowTemplate
---@field Name string # Shown in the "Load template..." picker
---@field TargetModKey string | nil # Pre-fills the target mod key field, if set
---@field Rows RowTemplateRow[] # Replaces whatever rows are currently in the table

---Templated orders for the picker, add more here as new scenarios are worth simulating.
---@type RowTemplate[]
local ROW_TEMPLATES = {
    {
        Name = "Trigger Bomb Shelter",
        TargetModKey = "BombShelter_Mgreedy",
        Rows = {
            { Key = "Action", Value = "TriggerBombShelter" },
            { Key = "TerritoryID", Value = "1" },
            { Key = "ArmiesBefore", Value = "10" },
        },
    },
    {
        Name = "Queue Bomb Shelter Build",
        TargetModKey = "BombShelter_Mgreedy",
        Rows = {
            { Key = "Action", Value = "QueueBuild" },
            { Key = "TerritoryID", Value = "1" },
        },
    },
    {
        Name = "Destroy Bomb Shelter",
        TargetModKey = "BombShelter_Mgreedy",
        Rows = {
            { Key = "Action", Value = "DestroyBombShelter" },
            { Key = "TerritoryID", Value = "1" },
        },
    },
};

---Client_PresentMenuUI hook
---@param rootParent RootParent
---@param setMaxSize fun(width: number, height: number) # Sets the max size of the dialog
---@param setScrollable fun(horizontallyScrollable: boolean, verticallyScrollable: boolean) # Set whether the dialog is scrollable both horizontal and vertically
---@param game GameClientHook
---@param close fun() # Zero parameter function that closes the dialog
function Client_PresentMenuUI(rootParent, setMaxSize, setScrollable, game, close)
    setMaxSize(600, 700);
    setScrollable(false, true);

    local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(vert).SetText(THIS_MOD_KEY .. " test menu").SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(vert).SetText("Simulates another mod calling a target mod's ModAuth API with made-up data, so you can test how that mod handles an authenticated order from a stranger.").SetColor(BUTTON_COLOURS.DarkGray);
    local statusLabel = UI.CreateLabel(vert).SetText("");

    if (game.Us == nil) then
        statusLabel.SetText("Spectators can't create orders.").SetColor(ERROR_COLOUR);
        return;
    end

    local targetHorz = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
    UI.CreateLabel(targetHorz).SetText("Target mod key").SetPreferredWidth(150);
    local targetModKeyField = UI.CreateTextInputField(targetHorz)
        .SetPreferredWidth(0)
        .SetMinWidth(0)
        .SetFlexibleWidth(1);

    UI.CreateLabel(vert).SetText("Simulated data (key/value pairs sent as the authenticated order's data):").SetColor(BUTTON_COLOURS.DarkGray);

    local rows = {}; -- { Container, KeyField, ValueField }
    local rowsContainer; -- forward declared so AddRow can close over it before it's created below

    ---Removes a row from the UI and from the rows list
    ---@param row table
    local function RemoveRow(row)
        for i, candidate in ipairs(rows) do
            if (candidate == row) then
                table.remove(rows, i);
                break;
            end
        end
        UI.Destroy(row.Container);
    end

    ---Adds a new, empty key/value row to the table
    ---@param defaultKey string | nil
    ---@param defaultValue string | nil
    local function AddRow(defaultKey, defaultValue)
        local rowHorz = UI.CreateHorizontalLayoutGroup(rowsContainer).SetFlexibleWidth(1);

        -- Fixed pixel widths for the key and delete columns so every row lines up regardless of how long its text is;
        -- the value field just fills whatever space is left, which is the same for every row.
        local keyField = UI.CreateTextInputField(rowHorz)
            .SetPlaceholderText("Key")
            .SetText(defaultKey or "")
            .SetPreferredWidth(165)
            .SetMinWidth(0)
            .SetFlexibleWidth(0);

        local valueField = UI.CreateTextInputField(rowHorz)
            .SetPlaceholderText("Value")
            .SetText(defaultValue or "")
            .SetPreferredWidth(0)
            .SetMinWidth(0)
            .SetFlexibleWidth(1);

        local row = { Container = rowHorz, KeyField = keyField, ValueField = valueField };

        UI.CreateButton(rowHorz)
            .SetText("X")
            .SetColor(BUTTON_COLOURS.Red)
            .SetPreferredWidth(40)
            .SetMinWidth(0)
            .SetFlexibleWidth(0)
            .SetOnClick(function() RemoveRow(row); end);

        table.insert(rows, row);
    end

    ---Destroys every current row, leaving the table empty
    local function ClearRows()
        for i = #rows, 1, -1 do
            UI.Destroy(rows[i].Container);
            table.remove(rows, i);
        end
    end

    ---Replaces the target mod key and every row with the ones from a template
    ---@param template RowTemplate
    local function LoadTemplate(template)
        ClearRows();
        if (template.TargetModKey ~= nil) then
            targetModKeyField.SetText(template.TargetModKey);
        end
        for _, templateRow in ipairs(template.Rows) do
            AddRow(templateRow.Key, templateRow.Value);
        end
    end

    local addRowHorz = UI.CreateHorizontalLayoutGroup(vert);
    UI.CreateButton(addRowHorz)
        .SetText("+ Add row")
        .SetColor(BUTTON_COLOURS.RoyalBlue)
        .SetOnClick(function() AddRow(); end);

    UI.CreateButton(addRowHorz)
        .SetText("Load template...")
        .SetColor(BUTTON_COLOURS.Purple)
        .SetOnClick(function()
            local options = {};
            for _, template in ipairs(ROW_TEMPLATES) do
                table.insert(options, { text = template.Name, selected = function() LoadTemplate(template); end });
            end
            UI.PromptFromList("Choose a template", options);
        end);

    rowsContainer = UI.CreateVerticalLayoutGroup(vert).SetFlexibleWidth(1);

    UI.CreateButton(vert)
        .SetText("Send simulated authenticated order")
        .SetColor(BUTTON_COLOURS.DarkGreen)
        .SetOnClick(function()
            local targetModKey = targetModKeyField.GetText();
            if (targetModKey == nil or targetModKey == "") then
                statusLabel.SetText("Enter a target mod key first.").SetColor(ERROR_COLOUR);
                return;
            end

            local data = {};
            for _, row in ipairs(rows) do
                local key = row.KeyField.GetText();
                if (key ~= nil and key ~= "") then
                    data[key] = ParseFieldValue(row.ValueField.GetText());
                end
            end

            local payload = { TargetModKey = targetModKey, Data = data };
            AddMenuOrder(game, SEND_ORDER_PREFIX .. IO.Writer.Write(payload), "Ask " .. THIS_MOD_KEY .. " to send a simulated authenticated order to " .. targetModKey);
            statusLabel.SetText("Order added, " .. targetModKey .. " gets it when the turn advances.").SetColor(TEXT_DEFAULT_COLOUR);
        end);
end

---Converts a row's value text into a number or boolean when it looks like one, otherwise leaves it as a string
---@param text string
---@return number | boolean | string
function ParseFieldValue(text)
    if (text == "true") then return true; end
    if (text == "false") then return false; end

    local asNumber = tonumber(text);
    if (asNumber ~= nil) then return asNumber; end

    return text;
end

---Adds an order that asks this mod's server code to send a test order
---@param game GameClientHook
---@param payload string # The server-side payload to act on
---@param message string # The message shown for the order in the order list
function AddMenuOrder(game, payload, message)
    local order = WL.GameOrderCustom.Create(
        game.Us.ID,
        message,
        payload,
        nil,
        WL.TurnPhase.Attacks);

    -- Orders is a snapshot, so it has to be reassigned for the new order to be kept
    local orders = game.Orders;
    table.insert(orders, order);
    game.Orders = orders;
end
