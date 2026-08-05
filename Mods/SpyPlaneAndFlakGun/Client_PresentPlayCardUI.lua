require('Utilities')

---Client_PresentPlayCardUI hook
---@param game GameClientHook
---@param cardInstance CardInstance # Read-only data about the card that the player is attempting to play
---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM) # Function that when invoked, will make the player play the card
---@param closeCardsDialog fun() # Function that when invoked will close this cards dialog
function Client_PresentPlayCardUI(game, cardInstance, playCard, closeCardsDialog)
    Game = game;

    if (cardInstance.CardID == Mod.Settings.FlakGunCardID or cardInstance.CardID == Mod.Settings.FlakGunTemporaryCardID) then
        Present_FlakGunPlayCardUI(game, playCard, closeCardsDialog);
    end

    if (cardInstance.CardID == Mod.Settings.SpyPlaneCardID) then
        Present_SpyPlanePlayCardUI(game, playCard, closeCardsDialog);
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
    local affectedTerritories = GetTerritoriesWithinDistance(Game, terrDetails.ID, areaOfEffect); --get resultant set of territories that this will effect, always includes the selected territory itself
    Game.HighlightTerritories(affectedTerritories); --highlight the impacted terrs
end

---Presents the Spy Plane's start/end territory selection dialog.
---@param game GameClientHook
---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM)
---@param closeCardsDialog fun()
function Present_SpyPlanePlayCardUI(game, playCard, closeCardsDialog)
    --If this dialog is already open, close the previous one. This prevents two copies of it from being open at once which can cause errors due to only saving one instance of the territory buttons
    if (Close ~= nil) then
        Close();
    end

    closeCardsDialog();

    --reset selection state each time the dialog is (re)opened
    SpyPlaneStartTerritoryID = nil;
    SpyPlaneStartTerritoryName = nil;
    SpyPlaneEndTerritoryID = nil;
    SpyPlaneEndTerritoryName = nil;

    game.CreateDialog(function(rootParent, setMaxSize, setScrollable, game, close)
        Close = close;
        setMaxSize(400, 240);
        local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1); --set flexible width so things don't jump around while we change InstructionLabel

        local territoryButtonsHGroup = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
        SpyPlaneStartTerritoryBtn = UI.CreateButton(territoryButtonsHGroup)
            .SetText("Select Start Territory")
            .SetOnClick(SpyPlaneStartTerritoryClicked)
            .SetFlexibleWidth(0.5);

        SpyPlaneEndTerritoryBtn = UI.CreateButton(territoryButtonsHGroup)
            .SetText("Select End Territory")
            .SetOnClick(SpyPlaneEndTerritoryClicked)
            .SetFlexibleWidth(0.5);

        SpyPlaneStartTerritoryInstructionLabel = UI.CreateLabel(vert).SetText("");
        SpyPlaneEndTerritoryInstructionLabel = UI.CreateLabel(vert).SetText("");

        SpyPlanePlayCardBtn = UI.CreateButton(vert)
            .SetText("Send Spy Plane")
            .SetInteractable(false)
            .SetColor(BUTTON_COLOURS.DarkGreen)
            .SetFlexibleWidth(1)
            .SetOnClick(function()
                if (SpyPlaneStartTerritoryID == nil) then
                    SpyPlaneStartTerritoryInstructionLabel.SetText("You must select a start territory first").SetColor(ERROR_COLOUR);
                    return;
                end

                if (SpyPlaneEndTerritoryID == nil) then
                    SpyPlaneEndTerritoryInstructionLabel.SetText("You must select an end territory first").SetColor(ERROR_COLOUR);
                    return;
                end

                local startTd = game.Map.Territories[SpyPlaneStartTerritoryID];
                local endTd = game.Map.Territories[SpyPlaneEndTerritoryID];
                local percentOverMaxFlightDistance = GetSpyPlanePercentOverMaxFlightDistance(SpyPlaneStartTerritoryID, SpyPlaneEndTerritoryID);

                if (percentOverMaxFlightDistance ~= nil) then
                    SpyPlaneEndTerritoryInstructionLabel.SetText("That flight is " .. percentOverMaxFlightDistance .. "% past the maximum flight distance - select an end territory closer to " .. SpyPlaneStartTerritoryName).SetColor(ERROR_COLOUR);
                    return;
                end

                local jumpToSpot = WL.RectangleVM.Create(startTd.MiddlePointX, startTd.MiddlePointY, endTd.MiddlePointX, endTd.MiddlePointY);
                local modData = "FlySpyPlane_" .. SpyPlaneStartTerritoryID .. "_" .. SpyPlaneEndTerritoryID;
                local message = "Flies a Spy Plane from " .. SpyPlaneStartTerritoryName .. " to " .. SpyPlaneEndTerritoryName;

                if (playCard(message, modData, WL.TurnPhase.Deploys, {}, jumpToSpot)) then
                    close();
                end
            end);
    end);
end

function SpyPlaneStartTerritoryClicked()
    UI.InterceptNextTerritoryClick(SpyPlaneStartTerritoryHandleClick);
    SpyPlaneStartTerritoryInstructionLabel.SetText("Please click on the territory you wish the Spy Plane to start at.").SetColor(TEXT_DEFAULT_COLOUR);
    SpyPlaneStartTerritoryBtn.SetInteractable(false);
    SpyPlaneEndTerritoryBtn.SetInteractable(false);
    SpyPlanePlayCardBtn.SetInteractable(false);
end

function SpyPlaneStartTerritoryHandleClick(terrDetails)
    if UI.IsDestroyed(SpyPlaneStartTerritoryBtn) then
        -- Dialog was destroyed, so we don't need to intercept the click anymore
        return WL.CancelClickIntercept;
    end
    SpyPlaneStartTerritoryBtn.SetInteractable(true);
    SpyPlaneEndTerritoryBtn.SetInteractable(true);

    if (terrDetails == nil) then
        --The click request was cancelled. Return to our default state.
        SpyPlaneStartTerritoryInstructionLabel.SetText("");
        SpyPlaneStartTerritoryID = nil;
        SpyPlaneStartTerritoryName = nil;
    elseif (terrDetails.ID == SpyPlaneEndTerritoryID) then
        SpyPlaneStartTerritoryInstructionLabel.SetText("Start territory can't be the same as the end territory").SetColor(ERROR_COLOUR);
        SpyPlaneStartTerritoryID = nil;
        SpyPlaneStartTerritoryName = nil;
    else
        SpyPlaneStartTerritoryInstructionLabel.SetText("Selected start: " .. terrDetails.Name).SetColor(TEXT_DEFAULT_COLOUR);
        SpyPlaneStartTerritoryID = terrDetails.ID;
        SpyPlaneStartTerritoryName = terrDetails.Name;
    end

    SpyPlanePlayCardBtn.SetInteractable(SpyPlaneStartTerritoryID ~= nil and SpyPlaneEndTerritoryID ~= nil);
    UpdateSpyPlaneFlightDistanceLabel();
    UpdateSpyPlaneHighlight();
    UpdateSpyPlanePlayCardButtonText();
end

function SpyPlaneEndTerritoryClicked()
    UI.InterceptNextTerritoryClick(SpyPlaneEndTerritoryHandleClick);
    SpyPlaneEndTerritoryInstructionLabel.SetText("Please click on the territory you wish the Spy Plane to end at.").SetColor(TEXT_DEFAULT_COLOUR);
    SpyPlaneStartTerritoryBtn.SetInteractable(false);
    SpyPlaneEndTerritoryBtn.SetInteractable(false);
    SpyPlanePlayCardBtn.SetInteractable(false);
end

function SpyPlaneEndTerritoryHandleClick(terrDetails)
    if UI.IsDestroyed(SpyPlaneEndTerritoryBtn) then
        -- Dialog was destroyed, so we don't need to intercept the click anymore
        return WL.CancelClickIntercept;
    end
    SpyPlaneStartTerritoryBtn.SetInteractable(true);
    SpyPlaneEndTerritoryBtn.SetInteractable(true);

    if (terrDetails == nil) then
        --The click request was cancelled. Return to our default state.
        SpyPlaneEndTerritoryInstructionLabel.SetText("");
        SpyPlaneEndTerritoryID = nil;
        SpyPlaneEndTerritoryName = nil;
    elseif (terrDetails.ID == SpyPlaneStartTerritoryID) then
        SpyPlaneEndTerritoryInstructionLabel.SetText("End territory can't be the same as the start territory").SetColor(ERROR_COLOUR);
        SpyPlaneEndTerritoryID = nil;
        SpyPlaneEndTerritoryName = nil;
    else
        SpyPlaneEndTerritoryID = terrDetails.ID;
        SpyPlaneEndTerritoryName = terrDetails.Name;
    end

    SpyPlanePlayCardBtn.SetInteractable(SpyPlaneStartTerritoryID ~= nil and SpyPlaneEndTerritoryID ~= nil);
    UpdateSpyPlaneFlightDistanceLabel();
    UpdateSpyPlaneHighlight();
    UpdateSpyPlanePlayCardButtonText();
end

---Refreshes the "Send Spy Plane" button's text with how many steps the flight will take, provided both a start
---and end territory are currently selected and the flight is within the maximum distance. Recalculated whenever
---either selection changes, same as UpdateSpyPlaneFlightDistanceLabel.
function UpdateSpyPlanePlayCardButtonText()
    local stepCountSuffix = "";
    if (SpyPlaneStartTerritoryID ~= nil and SpyPlaneEndTerritoryID ~= nil and GetSpyPlanePercentOverMaxFlightDistance(SpyPlaneStartTerritoryID, SpyPlaneEndTerritoryID) == nil) then
        stepCountSuffix = GetSpyPlaneStepCountSuffix(SpyPlaneStartTerritoryID, SpyPlaneEndTerritoryID);
    end

    SpyPlanePlayCardBtn.SetText("Send Spy Plane" .. stepCountSuffix);
end

---Refreshes the end-territory label with the flight distance check, provided both a start and end territory are
---currently selected. Recalculated whenever either selection changes, so switching the start after already
---picking an end (or vice versa) doesn't leave a stale message showing.
function UpdateSpyPlaneFlightDistanceLabel()
    if (SpyPlaneStartTerritoryID == nil or SpyPlaneEndTerritoryID == nil) then
        return;
    end

    local percentOverMaxFlightDistance = GetSpyPlanePercentOverMaxFlightDistance(SpyPlaneStartTerritoryID, SpyPlaneEndTerritoryID);
    if (percentOverMaxFlightDistance ~= nil) then
        SpyPlaneEndTerritoryInstructionLabel.SetText("Selected end: " .. SpyPlaneEndTerritoryName .. " (" .. percentOverMaxFlightDistance .. "% > max distance)").SetColor(ERROR_COLOUR);
    else
        SpyPlaneEndTerritoryInstructionLabel.SetText("Selected end: " .. SpyPlaneEndTerritoryName).SetColor(TEXT_DEFAULT_COLOUR);
    end
end

---Returns " (N steps)" describing how many turns a Distance-based Steps flight between the given territories will
---take, or "" if Steps/Distance mode isn't the configured flight style (Instant and Segment-based Steps don't have
---a meaningful "number of steps" to report here). Always at least 2, matching HandleFlySpyPlane's server-side step
---count so the start and end territories are never collapsed into a single step.
---@param startTerritoryID TerritoryID
---@param endTerritoryID TerritoryID
function GetSpyPlaneStepCountSuffix(startTerritoryID, endTerritoryID)
    if (not (Mod.Settings.SpyPlaneFlightStyleSteps and Mod.Settings.SpyPlaneStepModeDistance)) then
        return "";
    end

    local maxFlightDistance = Mod.Settings.SpyPlaneMaxFlightDistance or 300;
    local maxDistancePerStep = Mod.Settings.SpyPlaneMaxDistancePerStep or 200;
    local _, _, _, _, totalDistance = GetClampedLineSegment(Game, startTerritoryID, endTerritoryID, maxFlightDistance);
    local stepCount = math.max(2, math.ceil(totalDistance / maxDistancePerStep));

    return " (" .. stepCount .. " steps)";
end

---Returns how far (in whole percent) the flight from startTerritoryID to endTerritoryID exceeds
---Mod.Settings.SpyPlaneMaxFlightDistance, or nil if it's within range.
---@param startTerritoryID TerritoryID
---@param endTerritoryID TerritoryID
function GetSpyPlanePercentOverMaxFlightDistance(startTerritoryID, endTerritoryID)
    local startTd = Game.Map.Territories[startTerritoryID];
    local endTd = Game.Map.Territories[endTerritoryID];
    local flightDistance = math.sqrt((endTd.MiddlePointX - startTd.MiddlePointX) ^ 2 + (endTd.MiddlePointY - startTd.MiddlePointY) ^ 2);
    local maxFlightDistance = Mod.Settings.SpyPlaneMaxFlightDistance or 300;

    if (flightDistance <= maxFlightDistance) then
        return nil;
    end

    return math.floor(((flightDistance / maxFlightDistance) - 1) * 100 + 0.5);
end

---Highlights the territories that fall within the Spy Plane's line of flight (its Inclusion Generosity used as the
---"thickness" of the line, and its Maximum Flight Distance capping how far along the line is covered), once both
---a start and end territory have been picked. Clears highlighting otherwise.
function UpdateSpyPlaneHighlight()
    if (SpyPlaneStartTerritoryID == nil or SpyPlaneEndTerritoryID == nil) then
        Game.HighlightTerritories({});
        return;
    end

    local inclusionGenerosity = Mod.Settings.SpyPlaneInclusionGenerosity or 50;
    local maxFlightDistance = Mod.Settings.SpyPlaneMaxFlightDistance or 300;
    local coveredTerritories = GetTerritoriesNearLine(Game, SpyPlaneStartTerritoryID, SpyPlaneEndTerritoryID, inclusionGenerosity, maxFlightDistance);
    Game.HighlightTerritories(coveredTerritories);
end
