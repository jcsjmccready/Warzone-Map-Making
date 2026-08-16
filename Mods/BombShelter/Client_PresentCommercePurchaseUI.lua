require('Utilities')

---@param rootParent RootParent
---@param game GameClientHook
---@param close fun() # Zero parameter function that closes the dialog
function Client_PresentCommercePurchaseUI(rootParent, game, close)
    CommerceGame = game;
    CommerceClose = close;

    local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    local message = "Protects armies from " .. (Mod.Settings.BombShelterDamagePercent or 0)*100 .. "% of damage from bombs";

    if(Mod.Settings.BombShelterHasDuration) then
        message = message .. ". Lasts for " .. (Mod.Settings.BombShelterDurationTurns or 0) .. " turns";
    end

    if(Mod.Settings.BombShelterDestroyedOnBomb) then
        message = message .. ". Destroyed when bombed";
    end

    local horz = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
    UI.CreateLabel(horz).SetText("Bomb Shelter").SetColor(BUTTON_COLOURS.Yellow).SetMinWidth(40);
    UI.CreateLabel(horz).SetText(message);

    local horz = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
    UI.CreateLabel(horz).SetText("Cost: " .. (Mod.Settings.BombShelterCost or 0) .. " gold")
    .SetFlexibleWidth(0.5)
    .SetColor(BUTTON_COLOURS.Bronze);

    local currentCount = CommerceCountOwnedAndQueuedBombShelters(game);

    CommerceLimitLabel = UI.CreateLabel(horz).SetText(CommerceLimitLabelText(currentCount))
    .SetFlexibleWidth(0.5)
    .SetColor(BUTTON_COLOURS.Bronze);

    CommerceTargetTerritoryBtn = UI.CreateButton(vert)
        .SetText("Build on Territory")
        .SetOnClick(CommerceTargetTerritoryClicked)
        .SetFlexibleWidth(1)
        .SetColor(BUTTON_COLOURS.DarkGreen);
end

---@param currentCount integer
function CommerceLimitLabelText(currentCount)
    return "Limit: " .. currentCount .. "/" .. (Mod.Settings.BombShelterMaxPerPlayer or 0) .. " per player";
end

---@param game GameClientHook
function CommerceCountOwnedAndQueuedBombShelters(game)
    local structureID = Mod.PublicGameData.BombShelterStructureID;
    local count = CountPlayerBombShelters(game.LatestStanding, game.Us.ID, structureID);

    for _, order in pairs(game.Orders) do
        if (order.proxyType == 'GameOrderCustom' and startsWith(order.Payload, "BombShelter_")) then
            count = count + 1;
        end
    end

    return count;
end

--- Initiate territory selection for the Bomb Shelter purchase
function CommerceTargetTerritoryClicked()
    local currentCount = CommerceCountOwnedAndQueuedBombShelters(CommerceGame);
    CommerceLimitLabel.SetText(CommerceLimitLabelText(currentCount));

    local maxAllowed = Mod.Settings.BombShelterMaxPerPlayer or 0;
    if (currentCount >= maxAllowed) then
        UI.Alert("You already own or have queued " .. currentCount .. " Bomb Shelter(s). You can only have " .. maxAllowed .. ".");
        return;
    end

    CommerceGame.HighlightTerritories({}); --clear any territories highlighted from a previous failed territory selection
    CommerceTargetTerritoryBtn.SetInteractable(false);
    UI.InterceptNextTerritoryClick(CommerceTerritoryClicked);
end

-- Territory on click callback
---@param terrDetails TerritoryDetailsVM | nil
function CommerceTerritoryClicked(terrDetails)
    if UI.IsDestroyed(CommerceTargetTerritoryBtn) then
        -- Dialog was destroyed, so we don't need to intercept the click anymore
        return WL.CancelClickIntercept;
    end

    if (terrDetails == nil) then
        --The click request was cancelled. Let the player try again.
        CommerceTargetTerritoryBtn.SetInteractable(true);
        return;
    end

    local terr = CommerceGame.LatestStanding.Territories[terrDetails.ID];
    if (terr == nil or terr.OwnerPlayerID ~= CommerceGame.Us.ID) then
        --Not a territory the player controls - reset and let them press the button again to retry.
        CommerceTargetTerritoryBtn.SetInteractable(true);
        CommerceGame.HighlightTerritories({});
        return;
    end

    local cost = Mod.Settings.BombShelterCost or 0;
    local order = WL.GameOrderCustom.Create(
        CommerceGame.Us.ID,
        "Build a Bomb Shelter on " .. terrDetails.Name,
        "BombShelter_" .. terrDetails.ID,
        { [WL.ResourceType.Gold] = cost },
        WL.TurnPhase.Attacks);

    -- Re-assign rather than mutate in place: Orders is a snapshot, so table.insert on the value returned by
    -- CommerceGame.Orders alone wouldn't persist the new order back to the game.
    local orders = CommerceGame.Orders;
    table.insert(orders, order);
    CommerceGame.Orders = orders;

    CommerceLimitLabel.SetText(CommerceLimitLabelText(CommerceCountOwnedAndQueuedBombShelters(CommerceGame)));

    -- Reset state
    CommerceGame.HighlightTerritories({});
    CommerceTargetTerritoryBtn.SetInteractable(true);
end
