require('Utilities')
require('Flight.Flight')
require('Flight.Path')
require('Flight.Progress')
require('Flight.Territory')

---Client_PresentPlayCardUI hook
---@param game GameClientHook
---@param cardInstance CardInstance # Read-only data about the card that the player is attempting to play
---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM) # Function that when invoked, will make the player play the card
---@param closeCardsDialog fun() # Function that when invoked will close this cards dialog
function Client_PresentPlayCardUI(game, cardInstance, playCard, closeCardsDialog)
    Game = game;

    if (cardInstance.CardID == Mod.Settings.SpyPlaneCardID) then
        Present_SpyPlanePlayCardUI(game, playCard, closeCardsDialog);
    end
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
        setMaxSize(400, 330);
        local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1); --set flexible width so things don't jump around while we change InstructionLabel

        local territoryButtonsHGroup = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
        SpyPlaneStartTerritoryBtn = UI.CreateButton(territoryButtonsHGroup)
            .SetText("Select Source")
            .SetColor(BUTTON_COLOURS.LightBlue)
            .SetOnClick(SpyPlaneStartTerritoryClicked)
            .SetFlexibleWidth(0.5);

        SpyPlaneEndTerritoryBtn = UI.CreateButton(territoryButtonsHGroup)
            .SetText("Select Target")
            .SetColor(BUTTON_COLOURS.LightBlue)
            .SetOnClick(SpyPlaneEndTerritoryClicked)
            .SetFlexibleWidth(0.5);

        SpyPlaneStartTerritoryInstructionLabel = UI.CreateLabel(vert).SetText("");
        SpyPlaneEndTerritoryInstructionLabel = UI.CreateLabel(vert).SetText("");

        --Territory snapshots (the actual shape of the selected territory) don't exist in app versions below
        --SNAPSHOT_AND_ICON_MIN_VERSION, so only the name labels still work there
        local displayRow = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
        local startColumn = UI.CreateVerticalLayoutGroup(displayRow).SetPreferredWidth(120).SetFlexibleWidth(1).SetCenter(true);
        SpyPlaneStartTerritorySnapshot = nil;
        SpyPlaneStartTerritorySnapshotVert = nil;
        if (WL.IsVersionOrHigher(SNAPSHOT_AND_ICON_MIN_VERSION)) then
            SpyPlaneStartTerritorySnapshotVert = UI.CreateVerticalLayoutGroup(startColumn).SetCenter(true).SetPreferredHeight(60); --fixed height so the row doesn't resize when the snapshot appears
        end
        SpyPlaneStartTerritoryNameLabel = UI.CreateLabel(startColumn).SetText(" ").SetAlignment(WL.TextAlignmentOptions.Center);

        local endColumn = UI.CreateVerticalLayoutGroup(displayRow).SetPreferredWidth(120).SetFlexibleWidth(1).SetCenter(true);
        SpyPlaneEndTerritorySnapshot = nil;
        SpyPlaneEndTerritorySnapshotVert = nil;
        if (WL.IsVersionOrHigher(SNAPSHOT_AND_ICON_MIN_VERSION)) then
            SpyPlaneEndTerritorySnapshotVert = UI.CreateVerticalLayoutGroup(endColumn).SetCenter(true).SetPreferredHeight(60); --fixed height so the row doesn't resize when the snapshot appears
        end
        SpyPlaneEndTerritoryNameLabel = UI.CreateLabel(endColumn).SetText(" ").SetAlignment(WL.TextAlignmentOptions.Center);

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

        local stepsPreviewRow = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
        SpyPlaneStepsPreviousBtn = UI.CreateButton(stepsPreviewRow)
            .SetText("<-")
            .SetInteractable(false)
            .SetOnClick(SpyPlaneStepsPreviousClicked)
            .SetPreferredWidth(50)
            .SetFlexibleWidth(0);

        SpyPlaneShowStepsBtn = UI.CreateButton(stepsPreviewRow)
            .SetText("Show Steps")
            .SetInteractable(false)
            .SetOnClick(SpyPlaneShowStepsClicked)
            .SetFlexibleWidth(1);

        SpyPlaneStepsNextBtn = UI.CreateButton(stepsPreviewRow)
            .SetText("->")
            .SetInteractable(false)
            .SetOnClick(SpyPlaneStepsNextClicked)
            .SetPreferredWidth(50)
            .SetFlexibleWidth(0);

        SpyPlaneStartTerritoryClicked();
    end);
end

--SetTerritoryIDs rejects an empty list, so the snapshot is destroyed to clear it and recreated on the next selection
function ClearSpyPlaneStartSnapshot()
    SpyPlaneStartTerritoryNameLabel.SetText(" ");
    if (SpyPlaneStartTerritorySnapshot == nil) then return; end
    UI.Destroy(SpyPlaneStartTerritorySnapshot);
    SpyPlaneStartTerritorySnapshot = nil;
end

function ShowSpyPlaneStartSnapshot(terrID, name)
    SpyPlaneStartTerritoryNameLabel.SetText(name);
    if (SpyPlaneStartTerritorySnapshotVert == nil) then return; end
    if (SpyPlaneStartTerritorySnapshot == nil) then
        SpyPlaneStartTerritorySnapshot = UI.CreateSnapshot(SpyPlaneStartTerritorySnapshotVert).SetPreferredWidth(60).SetPreferredHeight(60);
    end
    SpyPlaneStartTerritorySnapshot.SetTerritoryIDs({ terrID });
end

--SetTerritoryIDs rejects an empty list, so the snapshot is destroyed to clear it and recreated on the next selection
function ClearSpyPlaneEndSnapshot()
    SpyPlaneEndTerritoryNameLabel.SetText(" ");
    if (SpyPlaneEndTerritorySnapshot == nil) then return; end
    UI.Destroy(SpyPlaneEndTerritorySnapshot);
    SpyPlaneEndTerritorySnapshot = nil;
end

function ShowSpyPlaneEndSnapshot(terrID, name)
    SpyPlaneEndTerritoryNameLabel.SetText(name);
    if (SpyPlaneEndTerritorySnapshotVert == nil) then return; end
    if (SpyPlaneEndTerritorySnapshot == nil) then
        SpyPlaneEndTerritorySnapshot = UI.CreateSnapshot(SpyPlaneEndTerritorySnapshotVert).SetPreferredWidth(60).SetPreferredHeight(60);
    end
    SpyPlaneEndTerritorySnapshot.SetTerritoryIDs({ terrID });
end

function SpyPlaneStartTerritoryClicked()
    UI.InterceptNextTerritoryClick(SpyPlaneStartTerritoryHandleClick);
    SpyPlaneStartTerritoryInstructionLabel.SetText("");
    SpyPlaneStartTerritoryBtn.SetColor(BUTTON_COLOURS.DarkGreen).SetInteractable(false);
    SpyPlaneEndTerritoryBtn.SetInteractable(false);
    SpyPlanePlayCardBtn.SetInteractable(false);

    --picking a new start invalidates whatever start/end territory (and its distance checks) was already selected,
    --so clear the old highlight immediately rather than leaving the previous selection's highlight showing while
    --we wait for the new start territory to be clicked
    SpyPlaneStartTerritoryID = nil;
    SpyPlaneStartTerritoryName = nil;
    SpyPlaneEndTerritoryID = nil;
    SpyPlaneEndTerritoryName = nil;
    SpyPlaneEndTerritoryInstructionLabel.SetText("");
    ClearSpyPlaneStartSnapshot();
    ClearSpyPlaneEndSnapshot();
    UpdateSpyPlaneHighlight();
    UpdateSpyPlanePlayCardButtonText();
    UpdateSpyPlaneStepsPreviewAvailability();
end

function SpyPlaneStartTerritoryHandleClick(terrDetails)
    if UI.IsDestroyed(SpyPlaneStartTerritoryBtn) then
        -- Dialog was destroyed, so we don't need to intercept the click anymore
        return WL.CancelClickIntercept;
    end
    SpyPlaneStartTerritoryBtn.SetColor(BUTTON_COLOURS.LightBlue).SetInteractable(true);
    SpyPlaneEndTerritoryBtn.SetInteractable(true);

    if (terrDetails == nil) then
        --The click request was cancelled. Return to our default state.
        SpyPlaneStartTerritoryInstructionLabel.SetText("");
        SpyPlaneStartTerritoryID = nil;
        SpyPlaneStartTerritoryName = nil;
        ClearSpyPlaneStartSnapshot();
    elseif (terrDetails.ID == SpyPlaneEndTerritoryID) then
        SpyPlaneStartTerritoryInstructionLabel.SetText("Start territory can't be the same as the end territory").SetColor(ERROR_COLOUR);
        SpyPlaneStartTerritoryID = nil;
        SpyPlaneStartTerritoryName = nil;
        ClearSpyPlaneStartSnapshot();
    else
        SpyPlaneStartTerritoryInstructionLabel.SetText("");
        SpyPlaneStartTerritoryID = terrDetails.ID;
        SpyPlaneStartTerritoryName = terrDetails.Name;
        ShowSpyPlaneStartSnapshot(terrDetails.ID, terrDetails.Name);
    end

    SpyPlanePlayCardBtn.SetInteractable(IsSpyPlaneSelectionValid());
    UpdateSpyPlaneFlightDistanceLabel();
    UpdateSpyPlaneHighlight();
    UpdateSpyPlanePlayCardButtonText();
    UpdateSpyPlaneStepsPreviewAvailability();

    --a successful source pick should flow straight into target selection, so the player doesn't need to press the
    --"Select Target" button themselves
    if (SpyPlaneStartTerritoryID ~= nil) then
        SpyPlaneEndTerritoryClicked();
    end
end

function SpyPlaneEndTerritoryClicked()
    UI.InterceptNextTerritoryClick(SpyPlaneEndTerritoryHandleClick);
    SpyPlaneEndTerritoryInstructionLabel.SetText("");
    SpyPlaneStartTerritoryBtn.SetInteractable(false);
    SpyPlaneEndTerritoryBtn.SetColor(BUTTON_COLOURS.DarkGreen).SetInteractable(false);
    SpyPlanePlayCardBtn.SetInteractable(false);
end

function SpyPlaneEndTerritoryHandleClick(terrDetails)
    if UI.IsDestroyed(SpyPlaneEndTerritoryBtn) then
        -- Dialog was destroyed, so we don't need to intercept the click anymore
        return WL.CancelClickIntercept;
    end
    SpyPlaneStartTerritoryBtn.SetInteractable(true);
    SpyPlaneEndTerritoryBtn.SetColor(BUTTON_COLOURS.LightBlue).SetInteractable(true);

    if (terrDetails == nil) then
        --The click request was cancelled. Return to our default state.
        SpyPlaneEndTerritoryInstructionLabel.SetText("");
        SpyPlaneEndTerritoryID = nil;
        SpyPlaneEndTerritoryName = nil;
        ClearSpyPlaneEndSnapshot();
    elseif (terrDetails.ID == SpyPlaneStartTerritoryID) then
        SpyPlaneEndTerritoryInstructionLabel.SetText("End territory can't be the same as the start territory").SetColor(ERROR_COLOUR);
        SpyPlaneEndTerritoryID = nil;
        SpyPlaneEndTerritoryName = nil;
        ClearSpyPlaneEndSnapshot();
    else
        SpyPlaneEndTerritoryID = terrDetails.ID;
        SpyPlaneEndTerritoryName = terrDetails.Name;
        ShowSpyPlaneEndSnapshot(terrDetails.ID, terrDetails.Name);
    end

    SpyPlanePlayCardBtn.SetInteractable(IsSpyPlaneSelectionValid());
    UpdateSpyPlaneFlightDistanceLabel();
    UpdateSpyPlaneHighlight();
    UpdateSpyPlanePlayCardButtonText();
    UpdateSpyPlaneStepsPreviewAvailability();
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
        SpyPlaneEndTerritoryInstructionLabel.SetText(percentOverMaxFlightDistance .. "% > max distance").SetColor(ERROR_COLOUR);
    else
        SpyPlaneEndTerritoryInstructionLabel.SetText("");
    end
end

---Builds the (already max-distance-clamped) FlightPath between two territories' centerpoints.
---@param startTerritoryID TerritoryID
---@param endTerritoryID TerritoryID
---@param maxFlightDistance number
---@return FlightPath
function BuildSpyPlanePath(startTerritoryID, endTerritoryID, maxFlightDistance)
    local startTd = Game.Map.Territories[startTerritoryID];
    local endTd = Game.Map.Territories[endTerritoryID];
    local path = Flight.NewPolylinePath({
        { X = startTd.MiddlePointX, Y = startTd.MiddlePointY },
        { X = endTd.MiddlePointX, Y = endTd.MiddlePointY },
    });
    return Flight.Clamp(path, maxFlightDistance);
end

---Returns " (N steps)" describing how many turns a Distance-based Steps flight between the given territories will
---take, or "" if Steps/Distance mode isn't the configured flight style (Instant and Segment-based Steps don't have
---a meaningful "number of steps" to report here). Always at least 2, matching SpyPlaneApplication.FlySpyPlane's
---server-side step count so the start and end territories are never collapsed into a single step.
---@param startTerritoryID TerritoryID
---@param endTerritoryID TerritoryID
function GetSpyPlaneStepCountSuffix(startTerritoryID, endTerritoryID)
    if (not (Mod.Settings.SpyPlaneFlightStyleSteps and Mod.Settings.SpyPlaneStepModeDistance)) then
        return "";
    end

    local maxFlightDistance = Mod.Settings.SpyPlaneMaxFlightDistance or 300;
    local maxDistancePerStep = Mod.Settings.SpyPlaneMaxDistancePerStep or 200;
    local path = BuildSpyPlanePath(startTerritoryID, endTerritoryID, maxFlightDistance);
    local stepCount = math.max(2, math.ceil(path.TotalLength / maxDistancePerStep));

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

---Whether a source and target are both selected and the flight between them is within the maximum flight distance.
function IsSpyPlaneSelectionValid()
    return SpyPlaneStartTerritoryID ~= nil
        and SpyPlaneEndTerritoryID ~= nil
        and GetSpyPlanePercentOverMaxFlightDistance(SpyPlaneStartTerritoryID, SpyPlaneEndTerritoryID) == nil;
end

---Highlights the territories within the Spy Plane's reach: once both a start and end territory have been picked,
---the territories that fall within its line of flight (its Inclusion Generosity used as the "thickness" of the
---line, and its Maximum Flight Distance capping how far along the line is covered); once only a start territory
---has been picked, every territory within Maximum Flight Distance of it (the valid range for an end territory).
---Clears highlighting if neither is picked yet.
function UpdateSpyPlaneHighlight()
    local maxFlightDistance = Mod.Settings.SpyPlaneMaxFlightDistance or 300;

    if (SpyPlaneStartTerritoryID == nil) then
        Game.HighlightTerritories({});
        return;
    end

    if (SpyPlaneEndTerritoryID == nil) then
        local startTd = Game.Map.Territories[SpyPlaneStartTerritoryID];
        local startPoint = { X = startTd.MiddlePointX, Y = startTd.MiddlePointY };
        local territoriesWithinRange = Flight.GetTerritoriesNearPoints(Game, { startPoint, startPoint }, maxFlightDistance);
        Game.HighlightTerritories(territoriesWithinRange);
        return;
    end

    local inclusionGenerosity = Mod.Settings.SpyPlaneInclusionGenerosity or 50;
    local path = BuildSpyPlanePath(SpyPlaneStartTerritoryID, SpyPlaneEndTerritoryID, maxFlightDistance);
    local coveredTerritories = Flight.GetTerritoriesAlongPath(Game, path, inclusionGenerosity);
    Game.HighlightTerritories(coveredTerritories);
end

---Computes, for the current source/target selection, the covered territories of every step a Steps flight (either
---Distance-based or Segment-based) will take - a client-side replay of the same Flight.NewProgress/Flight.Advance
---stepping SpyPlaneApplication.FlySpyPlane/AdvanceActiveSpyPlaneFlights use server-side, against a throwaway
---FlightProgress so nothing here touches Mod.PrivateGameData.
---@return TerritoryID[][]
function ComputeSpyPlaneStepsPreview()
    if (SpyPlaneStartTerritoryID == nil or SpyPlaneEndTerritoryID == nil) then
        return {};
    end

    local maxFlightDistance = Mod.Settings.SpyPlaneMaxFlightDistance or 300;
    local inclusionGenerosity = Mod.Settings.SpyPlaneInclusionGenerosity or 50;
    local path = BuildSpyPlanePath(SpyPlaneStartTerritoryID, SpyPlaneEndTerritoryID, maxFlightDistance);

    local stepDistance;
    if (Mod.Settings.SpyPlaneStepModeSegment) then
        local flightSteps = Mod.Settings.SpyPlaneFlightSteps or 5;
        stepDistance = path.TotalLength / flightSteps;
    else
        local maxDistancePerStep = Mod.Settings.SpyPlaneMaxDistancePerStep or 200;
        stepDistance = Flight.ComputeStepDistance(path.TotalLength, maxDistancePerStep);
    end

    local progress = Flight.NewProgress(path, stepDistance);
    local steps = {};
    while (progress.DistanceCovered < progress.Path.TotalLength) do
        local result = Flight.Advance(progress);
        table.insert(steps, Flight.GetTerritoriesNearPoints(Game, result.Points, inclusionGenerosity));
    end

    return steps;
end

---Resets any step preview in progress (it's now stale) whenever the source/target selection changes, and enables
---"Show Steps" only when a Steps flight (Distance-based or Segment-based) is configured and the current selection
---is valid.
function UpdateSpyPlaneStepsPreviewAvailability()
    SpyPlaneStepsPreview = nil;
    SpyPlaneStepsPreviewIndex = nil;
    SpyPlaneShowStepsBtn.SetText("Show Steps");
    SpyPlaneStepsPreviousBtn.SetInteractable(false);
    SpyPlaneStepsNextBtn.SetInteractable(false);
    SpyPlaneShowStepsBtn.SetInteractable(IsSpyPlaneSelectionValid() and Mod.Settings.SpyPlaneFlightStyleSteps == true);
end

---Highlights the currently-selected preview step and updates the "Show Steps"/arrow buttons to match.
function UpdateSpyPlaneStepsPreviewDisplay()
    Game.HighlightTerritories(SpyPlaneStepsPreview[SpyPlaneStepsPreviewIndex]);
    SpyPlaneShowStepsBtn.SetText("Step " .. SpyPlaneStepsPreviewIndex .. " / " .. #SpyPlaneStepsPreview);
    SpyPlaneStepsPreviousBtn.SetInteractable(SpyPlaneStepsPreviewIndex > 1);
    SpyPlaneStepsNextBtn.SetInteractable(SpyPlaneStepsPreviewIndex < #SpyPlaneStepsPreview);
end

function SpyPlaneShowStepsClicked()
    if (SpyPlaneStepsPreview ~= nil) then
        --already showing a preview - clicking again reverts back to the default "Show Steps" state
        UpdateSpyPlaneStepsPreviewAvailability();
        UpdateSpyPlaneHighlight();
        return;
    end

    SpyPlaneStepsPreview = ComputeSpyPlaneStepsPreview();
    SpyPlaneStepsPreviewIndex = 1;
    UpdateSpyPlaneStepsPreviewDisplay();
end

function SpyPlaneStepsPreviousClicked()
    if (SpyPlaneStepsPreview == nil or SpyPlaneStepsPreviewIndex <= 1) then return; end
    SpyPlaneStepsPreviewIndex = SpyPlaneStepsPreviewIndex - 1;
    UpdateSpyPlaneStepsPreviewDisplay();
end

function SpyPlaneStepsNextClicked()
    if (SpyPlaneStepsPreview == nil or SpyPlaneStepsPreviewIndex >= #SpyPlaneStepsPreview) then return; end
    SpyPlaneStepsPreviewIndex = SpyPlaneStepsPreviewIndex + 1;
    UpdateSpyPlaneStepsPreviewDisplay();
end
