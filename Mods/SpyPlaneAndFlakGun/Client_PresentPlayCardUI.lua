require('Utilities')

---Client_PresentPlayCardUI hook
---TODO: Spy Plane play card UI not yet implemented
---@param game GameClientHook
---@param cardInstance CardInstance # Read-only data about the card that the player is attempting to play
---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM) # Function that when invoked, will make the player play the card
---@param closeCardsDialog fun() # Function that when invoked will close this cards dialog
function Client_PresentPlayCardUI(game, cardInstance, playCard, closeCardsDialog)
    Game = game;

    if (cardInstance.CardID == Mod.Settings.FlakGunCardID) then
        Present_FlakGunPlayCardUI(game, playCard, closeCardsDialog);
    end
end

---Presents the Flak Gun's target-territory selection dialog, highlighting the territories that will be covered
---by its area of effect (if any) as soon as a candidate territory is picked.
---@param game GameClientHook
---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM)
---@param closeCardsDialog fun()
function Present_FlakGunPlayCardUI(game, playCard, closeCardsDialog)
    --If this dialog is already open, close the previous one. This prevents two copies of it from being open at once which can cause errors due to only saving one instance of TargetTerritoryBtn
    if (Close ~= nil) then
        Close();
    end

    closeCardsDialog();

    game.CreateDialog(function(rootParent, setMaxSize, setScrollable, game, close)
        Close = close;
        setMaxSize(400, 200);
        local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1); --set flexible width so things don't jump around while we change InstructionLabel
        local buttonsHGroup = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
        TargetTerritoryBtn = UI.CreateButton(buttonsHGroup)
            .SetText("Select Territory")
            .SetOnClick(FlakGunTargetTerritoryClicked)
            .SetFlexibleWidth(0.3);

        TargetTerritoryInstructionLabel = UI.CreateLabel(vert).SetText("");

        PlayCardBtn = UI.CreateButton(buttonsHGroup)
            .SetText("Fire Flak Gun")
            .SetInteractable(false)
            .SetColor(BUTTON_COLOURS.DarkGreen)
            .SetFlexibleWidth(0.7)
            .SetOnClick(function()
                if (TargetTerritoryID == nil) then
                    TargetTerritoryInstructionLabel.SetText("You must select a territory first").SetColor(ERROR_COLOUR);
                    TargetTerritoryBtn.SetInteractable(true);

                    return;
                end
                local td = game.Map.Territories[TargetTerritoryID];

                local jumpToSpot = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);

                if (playCard("Fire a Flak Gun at " .. TargetTerritoryName, "ShootFlakGun_" .. TargetTerritoryID, WL.TurnPhase.Deploys, {}, jumpToSpot)) then
                    close();
                end
            end);
    end);
end

function FlakGunTargetTerritoryClicked()
    UI.InterceptNextTerritoryClick(FlakGunTerritoryClicked);
    TargetTerritoryInstructionLabel.SetText("Please click on the territory you wish to fire the Flak Gun at.").SetColor(TEXT_DEFAULT_COLOUR);
    TargetTerritoryBtn.SetInteractable(false);
    PlayCardBtn.SetInteractable(false);
end

function FlakGunTerritoryClicked(terrDetails)
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
        PlayCardBtn.SetInteractable(false);
        Game.HighlightTerritories({});
        return;
    end

    --Territory was clicked, remember its ID
    TargetTerritoryInstructionLabel.SetText("Selected territory: " .. terrDetails.Name).SetColor(TEXT_DEFAULT_COLOUR);
    TargetTerritoryID = terrDetails.ID;
    TargetTerritoryName = terrDetails.Name;
    PlayCardBtn.SetInteractable(true);

    local areaOfEffect = Mod.Settings.FlakGunAreaOfEffect or 0;
    if (areaOfEffect > 0) then
        local affectedTerritories = GetTerritoriesWithinDistance(Game, terrDetails.ID, areaOfEffect); --get resultant set of territories that this will effect
        Game.HighlightTerritories(affectedTerritories); --highlight the impacted terrs
    else
        Game.HighlightTerritories({});
    end
end
