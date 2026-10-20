require("Application.Utilities");
require("Application.PlanningOrders");
require("Application.PlacementSerialization");
require("Application.BuiltInSupport.BuiltInSupport");

---Client_PresentMenuUI hook
---@param rootParent RootParent
---@param setMaxSize fun(width: number, height: number) # Sets the max size of the dialog
---@param setScrollable fun(horizontallyScrollable: boolean, verticallyScrollable: boolean) # Set whether the dialog is scrollable both horizontal and vertically
---@param game GameClientHook
---@param close fun() # Zero parameter function that closes the dialog
function Client_PresentMenuUI(rootParent, setMaxSize, setScrollable, game, close)
    setMaxSize(500, 470);
    setScrollable(false, true);

    MenuGame = game;

    local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(vert).SetText("Add Vanilla Structure/Built-in Special Unit").SetColor(SUBHEADING_COLOUR);

    if (not Mod.Settings.IsPlanningMode) then
        UI.CreateLabel(vert).SetText("Used for planning mode. Nothing here to see...").SetColor(BUTTON_COLOURS.DarkGray);
        return;
    end

    if (game.Us == nil) then
        UI.CreateLabel(vert).SetText("Spectators can't create orders.").SetColor(ERROR_COLOUR);
        return;
    end

    local options = {};
    for _, entry in ipairs(VANILLA_STRUCTURE_TYPES) do
        table.insert(options, { Key = entry.Name, Text = entry.Name .. " [Struct]", Type = "Structure" });
    end
    for _, unit in ipairs(BuiltInSupport.ListUnits()) do
        table.insert(options, { Key = unit.Name, Text = unit.Name .. " [SU]", Type = "SpecialUnit" });
    end
    table.sort(options, function(a, b) return string.lower(a.Key) < string.lower(b.Key); end);
    MenuStructureOptions = options;

    local horz = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
    MenuStructureDropDown = CreateDropDown(horz, options, options[1].Key, nil);
    MenuTargetTerritoryBtn = UI.CreateButton(horz)
        .SetText("Create Build Order")
        .SetOnClick(MenuTargetTerritoryClicked)
        .SetFlexibleWidth(1)
        .SetColor(BUTTON_COLOURS.DarkGreen);

    UI.CreateLabel(vert).SetText('Modify Structure/SU on Map').SetColor(SUBHEADING_COLOUR);

    local modifyHorz = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
    MenuMoveTerritoryBtn = UI.CreateButton(modifyHorz)
        .SetText("Move")
        .SetIcon(ICON_MOVE)
        .SetIconMinWidth(20).SetIconPreferredWidth(20)
        .SetIconMinHeight(20).SetIconPreferredHeight(20)
        .SetOnClick(MenuMoveTerritoryClicked)
        .SetFlexibleWidth(1)
        .SetColor(BUTTON_COLOURS.RoyalBlue);
    MenuCloneTerritoryBtn = UI.CreateButton(modifyHorz)
        .SetText("Clone")
        .SetIcon(ICON_COPY)
        .SetIconMinWidth(20).SetIconPreferredWidth(20)
        .SetIconMinHeight(20).SetIconPreferredHeight(20)
        .SetOnClick(MenuCloneTerritoryClicked)
        .SetFlexibleWidth(1)
        .SetColor(BUTTON_COLOURS.DarkGreen);
    MenuDeleteTerritoryBtn = UI.CreateButton(modifyHorz)
        .SetText("X Delete")
        .SetOnClick(MenuDeleteTerritoryClicked)
        .SetFlexibleWidth(1)
        .SetColor(BUTTON_COLOURS.Red);

    UI.CreateEmpty(vert).SetPreferredHeight(10);

    ---- Extract Placement Configuration
    UI.CreateLabel(vert).SetText('Export Placement Configuration').SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(vert).SetText("Exports the positional information of the structures and custom orders on the map.");
    UI.CreateLabel(vert).SetText("Copy the exported data and paste it into the mod config's import section.");

    UI.CreateButton(vert)
        .SetText("Export Structures/Special Units on Map")
        .SetColor(BUTTON_COLOURS.RoyalBlue)
        .SetFlexibleWidth(1)
        .SetOnClick(function()
            MenuExtractedConfigField.SetText(SerializePlacementData(GetPlacementsFromMap(game)));
        end);

    MenuExtractedConfigField = UI.CreateTextInputField(vert)
        .SetPlaceholderText("Copy exported placement data...")
        .SetMultiLine(true)
        .SetPreferredHeight(100)
        .SetFlexibleWidth(1);
end

-- Exports one placement per structure/special unit found
---@param game GameClientHook
---@return PlaceholderPlacementSetting[]
function GetPlacementsFromMap(game)
    local vanillaStructureNames = GetVanillaStructureNames();
    local placements = {};

    for territoryID, territoryStanding in pairs(game.LatestStanding.Territories) do
        local territoryName = game.Map.Territories[territoryID].Name;

        for structureID, count in pairs(territoryStanding.Structures or {}) do
            local structureName = vanillaStructureNames[structureID] or tostring(structureID);
            if (structureName ~= nil) then
                for _ = 1, count do
                    table.insert(placements, { Type = "Structure", PlacementName = structureName, TerritoryName = territoryName });
                end
            end
        end

        for _, specialUnit in ipairs(territoryStanding.NumArmies.SpecialUnits or {}) do
            if (specialUnit.proxyType == "CustomSpecialUnit") then
                ---@cast specialUnit CustomSpecialUnit
                table.insert(placements, {
                    Type = "SpecialUnit",
                    PlacementName = specialUnit.Name,
                    TerritoryName = territoryName,
                    SpecialUnitFields = {
                        AttackPower = tostring(specialUnit.AttackPower),
                        AttackPowerPercentage = tostring(specialUnit.AttackPowerPercentage),
                        CanBeAirliftedToSelf = tostring(specialUnit.CanBeAirliftedToSelf),
                        CanBeAirliftedToTeammate = tostring(specialUnit.CanBeAirliftedToTeammate),
                        CanBeGiftedWithGiftCard = tostring(specialUnit.CanBeGiftedWithGiftCard),
                        CanBeTransferredToTeammate = tostring(specialUnit.CanBeTransferredToTeammate),
                        CombatOrder = tostring(specialUnit.CombatOrder),
                        DamageAbsorbedWhenAttacked = tostring(specialUnit.DamageAbsorbedWhenAttacked),
                        DamageToKill = tostring(specialUnit.DamageToKill),
                        DefensePower = tostring(specialUnit.DefensePower),
                        DefensePowerPercentage = tostring(specialUnit.DefensePowerPercentage),
                        Health = tostring(specialUnit.Health),
                        IncludeABeforeName = tostring(specialUnit.IncludeABeforeName),
                        IsVisibleToAllPlayers = tostring(specialUnit.IsVisibleToAllPlayers),
                        ModData = specialUnit.ModData or "",
                        ModID = tostring(specialUnit.ModID),
                        TextOverHeadOpt = specialUnit.TextOverHeadOpt or "",
                    },
                });
            end
        end
    end

    return placements;
end

--- Initiate territory selection for building the selected vanilla structure
function MenuTargetTerritoryClicked()
    MenuTargetTerritoryBtn.SetInteractable(false);
    UI.InterceptNextTerritoryClick(MenuTerritoryClicked);
end

-- Territory on click callback. Any territory is valid: ownership and visibility don't matter for planning markers
---@param terrDetails TerritoryDetailsVM | nil
function MenuTerritoryClicked(terrDetails)
    if UI.IsDestroyed(MenuTargetTerritoryBtn) then
        -- Dialog was destroyed, so we don't need to intercept the click anymore
        return WL.CancelClickIntercept;
    end

    MenuTargetTerritoryBtn.SetInteractable(true);

    if (terrDetails == nil) then
        --The click request was cancelled. Let the player try again.
        return;
    end

    local selectedKey = MenuStructureDropDown.GetKey();
    local selectedType = "Structure";
    for _, option in ipairs(MenuStructureOptions) do
        if (option.Key == selectedKey) then
            selectedType = option.Type;
            break;
        end
    end

    local order = WL.GameOrderCustom.Create(
        MenuGame.Us.ID,
        "Place " .. selectedKey .. " on " .. terrDetails.Name,
        BuildPlanningPayload(selectedType, selectedKey, terrDetails.ID),
        nil,
        WL.TurnPhase.Attacks);

    -- Re-assign rather than mutate in place: Orders is a snapshot, so table.insert on the value returned by
    -- MenuGame.Orders alone wouldn't persist the new order back to the game.
    local orders = MenuGame.Orders;
    table.insert(orders, order);
    MenuGame.Orders = orders;

    MenuGame.HighlightTerritories({ terrDetails.ID });
end

---Queues a GameOrderCustom carrying payload, to be processed into the actual effect by Server_AdvanceTurn_Order
---@param message string
---@param payload string
---@param territoryID TerritoryID
local function SubmitCustomOrder(message, payload, territoryID)
    local order = WL.GameOrderCustom.Create(MenuGame.Us.ID, message, payload, nil, WL.TurnPhase.Attacks);

    -- Re-assign rather than mutate in place: Orders is a snapshot, so table.insert on the value returned by
    -- MenuGame.Orders alone wouldn't persist the new order back to the game.
    local orders = MenuGame.Orders;
    table.insert(orders, order);
    MenuGame.Orders = orders;

    MenuGame.HighlightTerritories({ territoryID });
end

---Removes one item (structure/special unit)
---@param territoryID TerritoryID
---@param territoryName string
---@param item ModifyPickerItem
local function DeleteModifyItem(territoryID, territoryName, item)
    if (item.type == "Structure") then
        SubmitCustomOrder(
            "Remove a " .. item.label .. " from " .. territoryName,
            BuildDeleteStructurePayload(territoryID, item.identifier),
            territoryID);
    else
        SubmitCustomOrder(
            "Remove a " .. item.label .. " from " .. territoryName,
            BuildDeleteSpecialUnitPayload(territoryID, item.identifier),
            territoryID);
    end
end

---Duplicates one item (structure/special unit) onto the territory it's already on
---Cloning a vanilla special unit (Commander/Boss1-4) is a no-op server-side.
---@param territoryID TerritoryID
---@param territoryName string
---@param item ModifyPickerItem
local function CloneModifyItem(territoryID, territoryName, item)
    if (item.type == "Structure") then
        SubmitCustomOrder(
            "Clone a " .. item.label .. " on " .. territoryName,
            BuildCloneStructurePayload(territoryID, item.identifier),
            territoryID);
    else
        SubmitCustomOrder(
            "Clone a " .. item.label .. " on " .. territoryName,
            BuildCloneSpecialUnitPayload(territoryID, item.identifier),
            territoryID);
    end
end

---@class ModifyPickerItem
---@field label string
---@field icon string
---@field originIcon string
---@field type "Structure" | "SpecialUnit"
---@field identifier string # structureName (raw ID/vanilla name) for Structure, specialUnitID (GUID) for SpecialUnit

---Shows a custom popup dialog listing every modifiable item on a territory, each with just its icon/name and a
---single action button - used instead of UI.PromptFromList so rows can carry an icon (Structure/SpecialUnit),
---@param territoryName string
---@param items ModifyPickerItem[]
---@param actionIcon string # icon shown on each row's action button; "" for a text button instead
---@param actionText string # text shown on each row's action button when actionIcon is ""
---@param actionColor string
---@param onSelect fun(item: ModifyPickerItem)
local function ShowSelectPicker(territoryName, items, actionIcon, actionText, actionColor, onSelect)
    -- CreateDialog doesn't auto-close a previously opened dialog - close the last one ourselves
    if (MenuModifyDialogClose ~= nil) then
        MenuModifyDialogClose();
        MenuModifyDialogClose = nil;
    end

    MenuGame.CreateDialog(function(rootParent, setMaxSize, setScrollable, dialogGame, close)
        MenuModifyDialogClose = close;
        setMaxSize(400, 400);
        setScrollable(false, true);

        local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
        UI.CreateLabel(vert).SetText("Select a target on " .. territoryName).SetColor(SUBHEADING_COLOUR);

        for _, item in ipairs(items) do
            local row = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
            UI.CreateImage(row)
                .SetSprite(item.icon)
                .SetPreferredWidth(ICON_SIZE)
                .SetMinWidth(0)
                .SetFlexibleWidth(0)
                .SetPreferredHeight(ICON_SIZE)
                .SetMinHeight(0);
            UI.CreateImage(row)
                .SetSprite(item.originIcon)
                .SetPreferredWidth(ICON_SIZE)
                .SetMinWidth(0)
                .SetFlexibleWidth(0)
                .SetPreferredHeight(ICON_SIZE)
                .SetMinHeight(0);
            UI.CreateLabel(row).SetText(item.label).SetFlexibleWidth(1);

            local actionBtn = UI.CreateButton(row)
                .SetColor(actionColor)
                .SetPreferredWidth(40)
                .SetMinWidth(0)
                .SetFlexibleWidth(0)
                .SetPreferredHeight(30)
                .SetMinHeight(0);
            if (actionIcon ~= "") then
                actionBtn
                    .SetText("")
                    .SetIcon(actionIcon)
                    .SetIconMinWidth(20)
                    .SetIconPreferredWidth(20)
                    .SetIconMinHeight(20)
                    .SetIconPreferredHeight(20);
            else
                actionBtn.SetText(actionText);
            end
            actionBtn.SetOnClick(function()
                close();
                onSelect(item);
            end);
        end
    end);
end

---Shows the Move picker. Unlike ShowSelectPicker, selecting a row doesn't close the dialog straight away -
---instead that row's button turns green and disables, the heading switches to asking for a destination
---territory, and only once a territory is actually clicked does the dialog close and the order get queued.
---Clicking a different row's button first cancels the pending pick and starts over on the new row.
---@param fromTerritoryID TerritoryID
---@param fromTerritoryName string
---@param items ModifyPickerItem[]
local function ShowMovePicker(fromTerritoryID, fromTerritoryName, items)
    -- CreateDialog doesn't auto-close a previously opened dialog - close the last one ourselves
    if (MenuModifyDialogClose ~= nil) then
        MenuModifyDialogClose();
        MenuModifyDialogClose = nil;
    end

    MenuGame.CreateDialog(function(rootParent, setMaxSize, setScrollable, dialogGame, close)
        MenuModifyDialogClose = close;
        setMaxSize(400, 400);
        setScrollable(false, true);

        local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
        local headingLabel = UI.CreateLabel(vert).SetText("Select a target on " .. fromTerritoryName).SetColor(SUBHEADING_COLOUR);

        -- Only one row can be "pending a territory pick" at a time - selecting another row cancels this one
        local cancelPending = function() end;

        for _, item in ipairs(items) do
            local row = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
            UI.CreateImage(row)
                .SetSprite(item.icon)
                .SetPreferredWidth(ICON_SIZE)
                .SetMinWidth(0)
                .SetFlexibleWidth(0)
                .SetPreferredHeight(ICON_SIZE)
                .SetMinHeight(0);
            UI.CreateImage(row)
                .SetSprite(item.originIcon)
                .SetPreferredWidth(ICON_SIZE)
                .SetMinWidth(0)
                .SetFlexibleWidth(0)
                .SetPreferredHeight(ICON_SIZE)
                .SetMinHeight(0);
            UI.CreateLabel(row).SetText(item.label).SetFlexibleWidth(1);

            local actionBtn = UI.CreateButton(row)
                .SetText("")
                .SetIcon(ICON_MOVE)
                .SetIconMinWidth(20)
                .SetIconPreferredWidth(20)
                .SetIconMinHeight(20)
                .SetIconPreferredHeight(20)
                .SetColor(BUTTON_COLOURS.RoyalBlue)
                .SetPreferredWidth(40)
                .SetMinWidth(0)
                .SetFlexibleWidth(0)
                .SetPreferredHeight(30)
                .SetMinHeight(0);

            actionBtn.SetOnClick(function()
                cancelPending(); -- in case a different row was already pending

                actionBtn.SetColor(BUTTON_COLOURS.DarkGreen).SetInteractable(false);
                headingLabel.SetText("Select a territory to move " .. item.label .. " to");

                local isCancelled = false;
                cancelPending = function()
                    isCancelled = true;
                    actionBtn.SetColor(BUTTON_COLOURS.RoyalBlue).SetInteractable(true);
                    headingLabel.SetText("Select a target on " .. fromTerritoryName);
                end;

                UI.InterceptNextTerritoryClick(function(toTerrDetails)
                    if (isCancelled or UI.IsDestroyed(actionBtn)) then
                        -- A different row was picked instead, or the dialog was destroyed - don't act on this click
                        return WL.CancelClickIntercept;
                    end

                    if (toTerrDetails == nil) then
                        --The click request was cancelled. Let the player try again.
                        cancelPending();
                        return;
                    end

                    if (toTerrDetails.ID == fromTerritoryID) then
                        UI.Alert("Can't move " .. item.label .. " to the same territory it's already on.");
                        cancelPending();
                        return;
                    end

                    close();

                    if (item.type == "Structure") then
                        SubmitCustomOrder(
                            "Move a " .. item.label .. " from " .. fromTerritoryName .. " to " .. toTerrDetails.Name,
                            BuildMoveStructurePayload(fromTerritoryID, toTerrDetails.ID, item.identifier),
                            toTerrDetails.ID);
                    else
                        SubmitCustomOrder(
                            "Move a " .. item.label .. " from " .. fromTerritoryName .. " to " .. toTerrDetails.Name,
                            BuildMoveSpecialUnitPayload(fromTerritoryID, toTerrDetails.ID, item.identifier),
                            toTerrDetails.ID);
                    end
                end);
            end);
        end
    end);
end

---Scans the player's already-queued orders for delete/move orders on this terrtitory
---@param territoryID TerritoryID
---@return table<string, integer> structureCounts # structureName (raw ID/vanilla name) -> how many are already queued to leave
---@return table<GUID, boolean> specialUnitIDs # already-queued-to-leave special unit IDs
local function GetPendingRemovals(territoryID)
    local structureCounts = {};
    local specialUnitIDs = {};

    for _, order in ipairs(MenuGame.Orders) do
        if (order.proxyType == 'GameOrderCustom') then
            ---@cast order GameOrderCustom

            local deleteType, deleteTerritoryID, deleteIdentifier = ParseDeletePayload(order.Payload);
            if (deleteIdentifier ~= nil and deleteTerritoryID == territoryID) then
                if (deleteType == "Structure") then
                    structureCounts[deleteIdentifier] = (structureCounts[deleteIdentifier] or 0) + 1;
                elseif (deleteType == "SpecialUnit") then
                    specialUnitIDs[deleteIdentifier] = true;
                end
            end

            local moveType, fromTerritoryID, _, moveIdentifier = ParseMovePayload(order.Payload);
            if (moveIdentifier ~= nil and fromTerritoryID == territoryID) then
                if (moveType == "Structure") then
                    structureCounts[moveIdentifier] = (structureCounts[moveIdentifier] or 0) + 1;
                elseif (moveType == "SpecialUnit") then
                    specialUnitIDs[moveIdentifier] = true;
                end
            end
        end
    end

    return structureCounts, specialUnitIDs;
end

---Builds the list of every structure/special unit standing on a territory that's still available to modify
---@param terrDetails TerritoryDetailsVM
---@return ModifyPickerItem[] | nil
local function BuildModifyItems(terrDetails)
    local vanillaStructureNames = GetVanillaStructureNames();
    local territoryStanding = MenuGame.LatestStanding.Territories[terrDetails.ID];
    local pendingStructureCounts, pendingSpecialUnitIDs = GetPendingRemovals(terrDetails.ID);

    ---@type ModifyPickerItem[]
    local items = {};
    for structureID, count in pairs((territoryStanding or {}).Structures or {}) do
        local structureName = vanillaStructureNames[structureID] or tostring(structureID);
        local displayName = CustomStructureToDisplayName(structureName) or structureName;
        local originIcon = (vanillaStructureNames[structureID] ~= nil) and ICON_VANILLA or ICON_MODDED;
        local remainingCount = math.max(0, count - (pendingStructureCounts[structureName] or 0));
        for _ = 1, remainingCount do
            table.insert(items, {
                label = displayName,
                icon = ICON_STRUCTURE,
                originIcon = originIcon,
                type = "Structure",
                identifier = structureName,
            });
        end
    end

    for _, specialUnit in ipairs(((territoryStanding or {}).NumArmies or {}).SpecialUnits or {}) do
        if (not pendingSpecialUnitIDs[specialUnit.ID]) then
            table.insert(items, {
                label = specialUnit.Name,
                icon = ICON_SPECIAL_UNIT,
                originIcon = (specialUnit.proxyType == "CustomSpecialUnit") and ICON_MODDED or ICON_VANILLA,
                type = "SpecialUnit",
                identifier = specialUnit.ID,
            });
        end
    end

    if (#items == 0) then
        UI.Alert("Nothing to modify on " .. terrDetails.Name);
        return nil;
    end

    return items;
end

--- Initiate territory selection for moving a structure/special unit already standing on the map
function MenuMoveTerritoryClicked()
    MenuMoveTerritoryBtn.SetInteractable(false);
    UI.InterceptNextTerritoryClick(function(terrDetails)
        if UI.IsDestroyed(MenuMoveTerritoryBtn) then
            return WL.CancelClickIntercept;
        end
        MenuMoveTerritoryBtn.SetInteractable(true);
        if (terrDetails == nil) then return; end

        local items = BuildModifyItems(terrDetails);
        if (items == nil) then return; end

        ShowMovePicker(terrDetails.ID, terrDetails.Name, items);
    end);
end

--- Initiate territory selection for cloning a structure/special unit already standing on the map
function MenuCloneTerritoryClicked()
    MenuCloneTerritoryBtn.SetInteractable(false);
    UI.InterceptNextTerritoryClick(function(terrDetails)
        if UI.IsDestroyed(MenuCloneTerritoryBtn) then
            return WL.CancelClickIntercept;
        end
        MenuCloneTerritoryBtn.SetInteractable(true);
        if (terrDetails == nil) then return; end

        local items = BuildModifyItems(terrDetails);
        if (items == nil) then return; end

        ShowSelectPicker(terrDetails.Name, items, ICON_COPY, "", BUTTON_COLOURS.DarkGreen, function(item)
            CloneModifyItem(terrDetails.ID, terrDetails.Name, item);
        end);
    end);
end

--- Initiate territory selection for deleting a structure/special unit already standing on the map
function MenuDeleteTerritoryClicked()
    MenuDeleteTerritoryBtn.SetInteractable(false);
    UI.InterceptNextTerritoryClick(function(terrDetails)
        if UI.IsDestroyed(MenuDeleteTerritoryBtn) then
            return WL.CancelClickIntercept;
        end
        MenuDeleteTerritoryBtn.SetInteractable(true);
        if (terrDetails == nil) then return; end

        local items = BuildModifyItems(terrDetails);
        if (items == nil) then return; end

        ShowSelectPicker(terrDetails.Name, items, "", "X", BUTTON_COLOURS.Red, function(item)
            DeleteModifyItem(terrDetails.ID, terrDetails.Name, item);
        end);
    end);
end
