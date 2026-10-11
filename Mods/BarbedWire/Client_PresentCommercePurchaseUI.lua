require('Utilities')

---@param rootParent RootParent
---@param game GameClientHook
---@param close fun() # Zero parameter function that closes the dialog
function Client_PresentCommercePurchaseUI(rootParent, game, close)
    local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    if (Mod.Settings.IncludeBarbedWire == nil or Mod.Settings.IncludeBarbedWire) then
        if (Mod.Settings.isAcquiringTypeCard == nil or Mod.Settings.isAcquiringTypeCard) then
            Create_TrapCommerce_NotEnabled_UI(vert, "Barbed Wire");
        else
            Create_TrapCommerce_Section_UI(vert, game, "BarbedWire", "Barbed Wire", BuildTrapCommerceDescription("BarbedWire", "Barbed Wire"));
        end
    end

    if (Mod.Settings.IncludeCaltrop) then
        if (Mod.Settings.IncludeBarbedWire == nil or Mod.Settings.IncludeBarbedWire) then
            UI.CreateEmpty(vert).SetPreferredHeight(10);
        end

        if (Mod.Settings.CaltropIsAcquiringTypeCard == nil or Mod.Settings.CaltropIsAcquiringTypeCard) then
            Create_TrapCommerce_NotEnabled_UI(vert, "Caltrop");
        else
            Create_TrapCommerce_Section_UI(vert, game, "Caltrop", "Caltrop", BuildTrapCommerceDescription("Caltrop", "Caltrop"));
        end
    end
end

---Shown in place of a trap's Commerce section when that trap is enabled but configured for Card acquisition, even though this is a Commerce game.
---@param rootParent RootParent
---@param displayName string
function Create_TrapCommerce_NotEnabled_UI(rootParent, displayName)
    local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(vert).SetText(displayName .. ": Not enabled for commerce").SetColor(BUTTON_COLOURS.DarkGray);
end

---One trap's "Cost / Limit / Build on Territory" section of the Commerce purchase dialog.
---@param rootParent RootParent
---@param game GameClientHook
---@param prefix string # the trap's settings prefix, i.e. its V2_TrapType.Key ("BarbedWire" | "Caltrop")
---@param displayName string
---@param description string
function Create_TrapCommerce_Section_UI(rootParent, game, prefix, displayName, description)
    local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateLabel(vert).SetText(displayName).SetColor(BUTTON_COLOURS.Yellow).SetFlexibleWidth(1).SetAlignment(WL.TextAlignmentOptions.Center);

    local headerHorz = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
    local iconColumn = UI.CreateVerticalLayoutGroup(headerHorz).SetPreferredWidth(100).SetCenter(true);
    --UI.CreateImage doesn't exist in app versions below SNAPSHOT_AND_ICON_MIN_VERSION, so the icon is skipped there
    if (WL.IsVersionOrHigher(SNAPSHOT_AND_ICON_MIN_VERSION)) then
        UI.CreateImage(iconColumn).SetSprite(prefix .. ".png").SetPreferredWidth(60).SetPreferredHeight(60);
    end
    UI.CreateEmpty(headerHorz).SetPreferredWidth(10);
    UI.CreateLabel(headerHorz).SetText(description);

    local payloadPrefix = "Create" .. prefix .. "Commerce_";
    local primedStructureID = Mod.PublicGameData[prefix .. "PrimedStructureID"];
    local triggeredStructureID = Mod.PublicGameData[prefix .. "TriggeredStructureID"];

    ---@return integer
    local function countOwnedAndQueued()
        local count = CountPlayerTrapPieces(game.LatestStanding, game.Us.ID, primedStructureID, triggeredStructureID);

        for _, order in pairs(game.Orders) do
            if (order.proxyType == 'GameOrderCustom' and startsWith(order.Payload, payloadPrefix)) then
                count = count + 1;
            end
        end

        return count;
    end

    ---@param currentCount integer
    ---@return string
    local function limitLabelText(currentCount)
        return "Limit: " .. currentCount .. "/" .. (Mod.Settings[prefix .. "MaxPerPlayer"] or 0) .. " per player";
    end

    local costLimitHorz = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
    UI.CreateLabel(costLimitHorz).SetText("Cost: " .. (Mod.Settings[prefix .. "Cost"] or 0) .. " gold")
        .SetFlexibleWidth(0.5)
        .SetColor(BUTTON_COLOURS.Bronze);

    local limitLabel = UI.CreateLabel(costLimitHorz).SetText(limitLabelText(countOwnedAndQueued()))
        .SetFlexibleWidth(0.5)
        .SetColor(BUTTON_COLOURS.Bronze);

    local targetTerritoryBtn;

    -- Territory on click callback
    ---@param terrDetails TerritoryDetailsVM | nil
    local function territoryClicked(terrDetails)
        if UI.IsDestroyed(targetTerritoryBtn) then
            -- Dialog was destroyed, so we don't need to intercept the click anymore
            return WL.CancelClickIntercept;
        end

        if (terrDetails == nil) then
            --The click request was cancelled. Let the player try again.
            targetTerritoryBtn.SetInteractable(true);
            return;
        end

        local terr = game.LatestStanding.Territories[terrDetails.ID];
        if (terr == nil or terr.OwnerPlayerID ~= game.Us.ID) then
            --Not a territory the player controls - reset and let them press the button again to retry.
            targetTerritoryBtn.SetInteractable(true);
            game.HighlightTerritories({});
            return;
        end

        local cost = Mod.Settings[prefix .. "Cost"] or 0;
        local order = WL.GameOrderCustom.Create(
            game.Us.ID,
            "Build a " .. displayName .. " on " .. terrDetails.Name,
            payloadPrefix .. terrDetails.ID,
            { [WL.ResourceType.Gold] = cost },
            WL.TurnPhase.Attacks);
        order.Icon = prefix;

        -- Re-assign rather than mutate in place: Orders is a snapshot, so table.insert on the value returned by
        -- game.Orders alone wouldn't persist the new order back to the game.
        local orders = game.Orders;
        table.insert(orders, order);
        game.Orders = orders;

        limitLabel.SetText(limitLabelText(countOwnedAndQueued()));

        -- Reset state
        game.HighlightTerritories({});
        targetTerritoryBtn.SetInteractable(true);
    end

    targetTerritoryBtn = UI.CreateButton(vert)
        .SetText("Build on Territory")
        .SetOnClick(function()
            local currentCount = countOwnedAndQueued();
            limitLabel.SetText(limitLabelText(currentCount));

            local maxAllowed = Mod.Settings[prefix .. "MaxPerPlayer"] or 0;
            if (currentCount >= maxAllowed) then
                UI.Alert("You already own or have queued " .. currentCount .. " " .. displayName .. "(s). You can only have " .. maxAllowed .. ".");
                return;
            end

            game.HighlightTerritories({}); --clear any territories highlighted from a previous failed territory selection
            targetTerritoryBtn.SetInteractable(false);
            UI.InterceptNextTerritoryClick(territoryClicked);
        end)
        .SetFlexibleWidth(1)
        .SetColor(BUTTON_COLOURS.DarkGreen);
end
