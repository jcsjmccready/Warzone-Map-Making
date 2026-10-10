require("Utilities");
require("ModConstants");
require("IO.Writer");
require("Templates"); -- ROW_TEMPLATES lives there, kept separate so it's easy to find and update

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

    local territoryIDLabel; -- forward declared, TerritoryPicked below needs to close over it before it's created
    local pickTerritoryBtn; -- forward declared, TerritoryPicked below needs to close over it before it's created

    ---Shows the ID of whatever territory the player clicks on next, or clears the label if the click was cancelled
    ---@param terrDetails TerritoryDetails | nil
    local function TerritoryPicked(terrDetails)
        if (UI.IsDestroyed(pickTerritoryBtn)) then
            -- this dialog was closed before the click arrived, nothing left to update
            return WL.CancelClickIntercept;
        end

        pickTerritoryBtn.SetInteractable(true);

        if (terrDetails == nil) then
            territoryIDLabel.SetText("");
            return;
        end

        territoryIDLabel.SetText(terrDetails.Name .. " = TerritoryID " .. terrDetails.ID).SetColor(TEXT_DEFAULT_COLOUR);
    end

    local pickTerritoryHorz = UI.CreateHorizontalLayoutGroup(vert);
    pickTerritoryBtn = UI.CreateButton(pickTerritoryHorz)
        .SetText("Find territory ID...")
        .SetOnClick(function()
            UI.InterceptNextTerritoryClick(TerritoryPicked);
            territoryIDLabel.SetText("Click a territory on the map...").SetColor(TEXT_DEFAULT_COLOUR);
            pickTerritoryBtn.SetInteractable(false);
        end);
    territoryIDLabel = UI.CreateLabel(pickTerritoryHorz).SetText("");

    UI.CreateEmpty(vert).SetPreferredHeight(10);

    local targetHorz = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
    UI.CreateLabel(targetHorz).SetText("Target mod key").SetPreferredWidth(150);
    local targetModKeyField = UI.CreateTextInputField(targetHorz)
        .SetPreferredWidth(0)
        .SetMinWidth(0)
        .SetFlexibleWidth(1);

    local selectedPlayerID; -- forward declared, defaulted to game.Us.ID below
    local playerIDLabel; -- forward declared, PlayerPicked below needs to close over it before it's created

    ---Sets which player the next simulated order will be sent as
    ---@param playerID PlayerID
    ---@param playerName string
    local function PlayerPicked(playerID, playerName)
        selectedPlayerID = playerID;
        playerIDLabel.SetText(playerName .. " (ID " .. playerID .. ")").SetColor(TEXT_DEFAULT_COLOUR);
    end

    local playerHorz = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
    UI.CreateButton(playerHorz)
        .SetText("Order Player Id")
        .SetColor(BUTTON_COLOURS.RoyalBlue)
        .SetPreferredWidth(150)
        .SetOnClick(function()
            local options = {};
            for playerID, player in pairs(game.Game.PlayingPlayers) do
                local playerName = player.DisplayName(nil, false);
                table.insert(options, { text = playerName, selected = function() PlayerPicked(playerID, playerName); end });
            end
            UI.PromptFromList("Choose the player to act as", options);
        end);
    playerIDLabel = UI.CreateLabel(playerHorz).SetText("").SetFlexibleWidth(1);

    PlayerPicked(game.Us.ID, game.Game.PlayingPlayers[game.Us.ID].DisplayName(nil, false));

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

    ---Adds a new key/value row to the table
    ---@param defaultKey string | nil
    ---@param defaultValue string | nil
    ---@param isOptional boolean | nil # Shows a grayed "*" marker and an "Optional" placeholder hint on the row - TextInputField has no SetColor, so the marker is the only way to show this visually
    local function AddRow(defaultKey, defaultValue, isOptional)
        local rowHorz = UI.CreateHorizontalLayoutGroup(rowsContainer).SetFlexibleWidth(1);

        -- Fixed pixel widths for the key, optional-marker and delete columns so every row lines up regardless of how
        -- long its text is; the value field just fills whatever space is left, which is the same for every row.
        local keyField = UI.CreateTextInputField(rowHorz)
            .SetPlaceholderText("Key")
            .SetText(defaultKey or "")
            .SetPreferredWidth(165) -- fixed; a key longer than this will still make the box overflow, that's a known limitation
            .SetMinWidth(0)
            .SetFlexibleWidth(0);

        local valueField = UI.CreateTextInputField(rowHorz)
            .SetPlaceholderText(isOptional and "Optional" or "Value")
            .SetText(defaultValue or "")
            .SetPreferredWidth(0)
            .SetMinWidth(0)
            .SetFlexibleWidth(1);

        UI.CreateLabel(rowHorz)
            .SetText(isOptional and "*" or "")
            .SetColor(BUTTON_COLOURS.Yellow)
            .SetPreferredWidth(20)
            .SetFlexibleWidth(0);

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
            AddRow(templateRow.Key, templateRow.Value, templateRow.Optional);
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
            AddMenuOrder(game, selectedPlayerID, SEND_ORDER_PREFIX .. IO.Writer.Write(payload), "Ask " .. THIS_MOD_KEY .. " to send a simulated authenticated order to " .. targetModKey);
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
---@param playerID PlayerID # The player to submit the order as (not necessarily game.Us.ID - see "Acting as player")
---@param payload string # The server-side payload to act on
---@param message string # The message shown for the order in the order list
function AddMenuOrder(game, playerID, payload, message)
    local order = WL.GameOrderCustom.Create(
        playerID,
        message,
        payload,
        nil,
        WL.TurnPhase.Attacks);

    -- Orders is a snapshot, so it has to be reassigned for the new order to be kept
    local orders = game.Orders;
    table.insert(orders, order);
    game.Orders = orders;
end
