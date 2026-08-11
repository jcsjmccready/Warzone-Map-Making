require('Utilities')

---Client_PresentCommercePurchaseUI hook
---@param rootParent RootParent
---@param game GameClientHook
---@param close fun() # Zero parameter function that closes the dialog
function Client_PresentCommercePurchaseUI(rootParent, game, close)
    MigrateModSettings();

    if (Mod.Settings.IsAcquiringTypeCard) then
        return; -- Foxholes are acquired via card in this game, not commerce
    end

    Game = game;
    Close = close;
    TargetTerritoryID = nil;
    TargetTerritoryName = nil;

    local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(vert).SetText("Build a Foxhole").SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(vert).SetText("Cost: " .. (Mod.Settings.FoxholeCost or 0) .. " gold");

    local ownedCount = CountPlayerFoxholes(game.LatestStanding, game.Us.ID);
    local maxAllowed = Mod.Settings.FoxholeMaxPerPlayer or 0;
    UI.CreateLabel(vert).SetText("You own " .. ownedCount .. " / " .. maxAllowed .. " Foxholes");

    if (ownedCount >= maxAllowed) then
        UI.CreateLabel(vert).SetText("You have reached the maximum number of Foxholes").SetColor(ERROR_COLOUR);
        return;
    end

    local buttonsHGroup = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
    TargetTerritoryBtn = UI.CreateButton(buttonsHGroup)
        .SetText("Select Territory")
        .SetOnClick(TargetTerritoryClicked)
        .SetFlexibleWidth(0.3);

    TargetTerritoryInstructionLabel = UI.CreateLabel(vert).SetText("");

    BuyFoxholeBtn = UI.CreateButton(buttonsHGroup)
        .SetText("Buy Foxhole")
        .SetInteractable(false)
        .SetColor(BUTTON_COLOURS.DarkGreen)
        .SetFlexibleWidth(0.7)
        .SetOnClick(function()
            if (TargetTerritoryID == nil) then
                TargetTerritoryInstructionLabel.SetText("You must select a territory first").SetColor(ERROR_COLOUR);
                TargetTerritoryBtn.SetInteractable(true);
                return;
            end

            local order = WL.GameOrderCustom.Create(
                game.Us.ID,
                "Build a Foxhole on " .. TargetTerritoryName,
                "Foxhole_" .. TargetTerritoryID,
                { [WL.ResourceType.Gold] = Mod.Settings.FoxholeCost or 0 },
                WL.TurnPhase.Purchase);
            table.insert(game.Orders, order);

            Game.HighlightTerritories({});
            close();
        end);
end

function TargetTerritoryClicked()
    Game.HighlightTerritories({}); --clear any territories highlighted from a previous failed territory selection
    UI.InterceptNextTerritoryClick(TerritoryClicked);
    TargetTerritoryInstructionLabel.SetText("Please click on the territory you wish to build the Foxhole on.").SetColor(TEXT_DEFAULT_COLOUR);
    TargetTerritoryBtn.SetInteractable(false);
    BuyFoxholeBtn.SetInteractable(false);
end

function TerritoryClicked(terrDetails)
    if UI.IsDestroyed(TargetTerritoryBtn) then
        -- Dialog was destroyed, so we don't need to intercept the click anymore
        return WL.CancelClickIntercept;
    end
    TargetTerritoryBtn.SetInteractable(true);

    if (terrDetails == nil) then
        --The click request was cancelled. Return to our default state.
        TargetTerritoryInstructionLabel.SetText("");
        TargetTerritoryID = nil;
        TargetTerritoryName = nil;
        BuyFoxholeBtn.SetInteractable(false);
        Game.HighlightTerritories({});
        return;
    end

    local terr = Game.LatestStanding.Territories[terrDetails.ID];
    if (terr.OwnerPlayerID ~= Game.Us.ID) then
        TargetTerritoryInstructionLabel.SetText("You may only select territories you control").SetColor(ERROR_COLOUR);

        TargetTerritoryID = nil;
        TargetTerritoryName = nil;
        BuyFoxholeBtn.SetInteractable(false);
        Game.HighlightTerritories({});
    else
        TargetTerritoryInstructionLabel.SetText("Selected territory: " .. terrDetails.Name).SetColor(TEXT_DEFAULT_COLOUR);
        TargetTerritoryID = terrDetails.ID;
        TargetTerritoryName = terrDetails.Name;
        BuyFoxholeBtn.SetInteractable(true);
        Game.HighlightTerritories({TargetTerritoryID});
    end
end
