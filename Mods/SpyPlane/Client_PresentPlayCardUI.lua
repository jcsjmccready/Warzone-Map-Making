require('Utilities')
require('Flight.Flight')
require('Flight.Path')
require('Flight.Progress')
require('Flight.Territory')

---Which flight shape the player has selected in the play-card dialog. Distinct from Flight.PathType (Polyline/
---Loop) - Line and Path both produce a Polyline FlightPath, but are different UI/modes with different minimum
---territory counts.
---@enum SpyPlaneFlightMode
SpyPlaneFlightMode = {
    Line = "Line",
    Circle = "Circle",
    Path = "Path",
};

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

---Presents the Spy Plane's flight-shape (Line/Circle) and territory selection dialog.
---@param game GameClientHook
---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM)
---@param closeCardsDialog fun()
function Present_SpyPlanePlayCardUI(game, playCard, closeCardsDialog)
    --If this dialog is already open, close the previous one. This prevents two copies of it from being open at once which can cause errors due to only saving one instance of the territory buttons
    if (Close ~= nil) then
        Close();
    end

    closeCardsDialog();

    local lineEnabled = IsSpyPlaneLineFlightEnabled();
    local circleEnabled = IsSpyPlaneCircleFlightEnabled();
    local pathEnabled = IsSpyPlanePathFlightEnabled();

    --reset selection state each time the dialog is (re)opened - default to Line, else Circle, else Path, whichever
    --is enabled first (Client_CreateGame.lua guarantees at least one of the three is enabled)
    if (lineEnabled) then
        SpyPlaneSelectedFlightMode = SpyPlaneFlightMode.Line;
    elseif (circleEnabled) then
        SpyPlaneSelectedFlightMode = SpyPlaneFlightMode.Circle;
    else
        SpyPlaneSelectedFlightMode = SpyPlaneFlightMode.Path;
    end
    SpyPlaneStartTerritoryID = nil;
    SpyPlaneStartTerritoryName = nil;
    SpyPlaneEndTerritoryID = nil;
    SpyPlaneEndTerritoryName = nil;
    SpyPlaneCircleTerritoryID = nil;
    SpyPlaneCircleTerritoryName = nil;
    SpyPlanePathWaypoints = {};
    SpyPlaneAddingPathTerritories = false;
    SpyPlaneStepsRowShown = false;
    SpyPlaneStepsPreviewRow = nil;

    game.CreateDialog(function(rootParent, setMaxSize, setScrollable, game, close)
        Close = close;
        SpyPlanePlayCard = playCard;
        setMaxSize(400, 360);
        local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1); --set flexible width so things don't jump around while we change InstructionLabel
        local mainRow = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
        SpyPlaneDialogVert = mainRow;

        --only offer a flight-shape choice when more than one is enabled - with only one enabled, skip straight to
        --it. the column itself is still needed for the Steps button alone, so it's shown whenever either applies.
        local enabledModeCount = (lineEnabled and 1 or 0) + (circleEnabled and 1 or 0) + (pathEnabled and 1 or 0);
        local showModeButtons = enabledModeCount > 1;
        local stepsEnabled = Mod.Settings.SpyPlaneFlightStyleSteps == true;
        SpyPlaneLineModeBtn = nil;
        SpyPlaneCircleModeBtn = nil;
        SpyPlanePathModeBtn = nil;
        SpyPlaneStepsModeBtn = nil;
        if (showModeButtons or stepsEnabled) then
            local modeColumn = UI.CreateVerticalLayoutGroup(mainRow).SetFlexibleWidth(0).SetFlexibleHeight(1);

            if (showModeButtons) then
                if (lineEnabled) then
                    SpyPlaneLineModeBtn = UI.CreateButton(modeColumn)
                        .SetIcon("Line.png")
                        .SetText("")
                        .SetInteractable(SpyPlaneSelectedFlightMode ~= SpyPlaneFlightMode.Line)
                        .SetOnClick(function() SpyPlaneModeClicked(SpyPlaneFlightMode.Line); end)
                        .SetPreferredWidth(40)
                        .SetPreferredHeight(40)
                        .SetFlexibleWidth(0);
                end

                if (circleEnabled) then
                    SpyPlaneCircleModeBtn = UI.CreateButton(modeColumn)
                        .SetIcon("Circle.png")
                        .SetText("")
                        .SetInteractable(SpyPlaneSelectedFlightMode ~= SpyPlaneFlightMode.Circle)
                        .SetOnClick(function() SpyPlaneModeClicked(SpyPlaneFlightMode.Circle); end)
                        .SetPreferredWidth(40)
                        .SetPreferredHeight(40)
                        .SetFlexibleWidth(0);
                end

                if (pathEnabled) then
                    SpyPlanePathModeBtn = UI.CreateButton(modeColumn)
                        .SetIcon("Path.png")
                        .SetText("")
                        .SetInteractable(SpyPlaneSelectedFlightMode ~= SpyPlaneFlightMode.Path)
                        .SetOnClick(function() SpyPlaneModeClicked(SpyPlaneFlightMode.Path); end)
                        .SetPreferredWidth(40)
                        .SetPreferredHeight(40)
                        .SetFlexibleWidth(0);
                end
            end

            --absorbs the remaining column height so the buttons above stay pinned to the top instead of centering
            UI.CreateEmpty(modeColumn).SetFlexibleHeight(1);

            if (stepsEnabled) then
                SpyPlaneStepsModeBtn = UI.CreateButton(modeColumn)
                    .SetIcon("Steps.png")
                    .SetText("")
                    .SetOnClick(SpyPlaneStepsModeClicked)
                    .SetPreferredWidth(40)
                    .SetPreferredHeight(40)
                    .SetFlexibleWidth(0);
            end
        end

        SpyPlaneModeContentHeading = UI.CreateVerticalLayoutGroup(mainRow).SetFlexibleWidth(1);
        CreateSpyPlaneModeUI(SpyPlaneModeContentHeading, playCard);
    end);
end

---Whether Line flight is enabled per the mod's settings. Defaults to true if unset.
function IsSpyPlaneLineFlightEnabled()
    return Mod.Settings.SpyPlaneEnableLineFlight ~= false;
end

---Whether Circle flight is enabled per the mod's settings. Defaults to false if unset.
function IsSpyPlaneCircleFlightEnabled()
    return Mod.Settings.SpyPlaneEnableCircleFlight == true;
end

---Whether Path flight is enabled per the mod's settings. Defaults to false if unset.
function IsSpyPlanePathFlightEnabled()
    return Mod.Settings.SpyPlaneEnablePathFlight == true;
end

---Builds whichever mode's content is currently selected into parent - the single place that dispatches on
---SpyPlaneSelectedFlightMode, used both for the dialog's initial build and RebuildSpyPlaneModeContent.
---@param parent UIObject
---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM)
function CreateSpyPlaneModeUI(parent, playCard)
    if (SpyPlaneSelectedFlightMode == SpyPlaneFlightMode.Circle) then
        Create_SpyPlaneCircleMode_UI(parent, playCard);
    elseif (SpyPlaneSelectedFlightMode == SpyPlaneFlightMode.Path) then
        Create_SpyPlanePathMode_UI(parent, playCard);
    else
        Create_SpyPlaneLineMode_UI(parent, playCard);
    end
end

---Destroys whichever mode's content is currently built and rebuilds the newly-selected one in its place - the
---same destroy-and-recreate-in-a-stable-parent pattern Client_PresentConfigureUI.lua uses for its own
---radio-driven sub-options.
function RebuildSpyPlaneModeContent()
    Game.HighlightTerritories({});
    UI.Destroy(SpyPlaneModeContentHeading);
    SpyPlaneModeContentHeading = UI.CreateVerticalLayoutGroup(SpyPlaneDialogVert).SetFlexibleWidth(1);

    --reset all selection state back to the same defaults as when the play card dialog was first opened, rather
    --than carrying anything over between modes (the steps row, if shown, was just destroyed along with the rest
    --of the old mode's content anyway)
    SpyPlaneStartTerritoryID = nil;
    SpyPlaneStartTerritoryName = nil;
    SpyPlaneEndTerritoryID = nil;
    SpyPlaneEndTerritoryName = nil;
    SpyPlaneCircleTerritoryID = nil;
    SpyPlaneCircleTerritoryName = nil;
    SpyPlanePathWaypoints = {};
    SpyPlaneAddingPathTerritories = false;
    SpyPlaneStepsRowShown = false;
    SpyPlaneStepsPreviewRow = nil;

    CreateSpyPlaneModeUI(SpyPlaneModeContentHeading, SpyPlanePlayCard);
end

---Switches the active flight mode and rebuilds the dialog's content for it. No-ops if mode is already selected.
---@param mode SpyPlaneFlightMode
function SpyPlaneModeClicked(mode)
    if (SpyPlaneSelectedFlightMode == mode) then return; end
    SpyPlaneSelectedFlightMode = mode;

    if (SpyPlaneLineModeBtn ~= nil) then
        SpyPlaneLineModeBtn.SetInteractable(mode ~= SpyPlaneFlightMode.Line);
    end
    if (SpyPlaneCircleModeBtn ~= nil) then
        SpyPlaneCircleModeBtn.SetInteractable(mode ~= SpyPlaneFlightMode.Circle);
    end
    if (SpyPlanePathModeBtn ~= nil) then
        SpyPlanePathModeBtn.SetInteractable(mode ~= SpyPlaneFlightMode.Path);
    end

    RebuildSpyPlaneModeContent();
end

----------------------------------------------------------------------------------------------------------------------
-- Line mode: pick a source and target territory, flies in a straight (clamped) line between them. Supports
-- whichever flight style (Instant, Distance-based Steps, Segment-based Steps) is configured in the mod's settings.
----------------------------------------------------------------------------------------------------------------------

---@param parent UIObject
---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM)
function Create_SpyPlaneLineMode_UI(parent, playCard)
    local territoryButtonsHGroup = UI.CreateHorizontalLayoutGroup(parent).SetFlexibleWidth(1);
    SpyPlaneStartTerritoryBtn = UI.CreateButton(territoryButtonsHGroup)
        .SetText("Select Source")
        .SetOnClick(SpyPlaneStartTerritoryClicked)
        .SetFlexibleWidth(0.5);

    SpyPlaneEndTerritoryBtn = UI.CreateButton(territoryButtonsHGroup)
        .SetText("Select Target")
        .SetOnClick(SpyPlaneEndTerritoryClicked)
        .SetFlexibleWidth(0.5);

    SpyPlaneStartTerritoryInstructionLabel = UI.CreateLabel(parent).SetText("");
    SpyPlaneEndTerritoryInstructionLabel = UI.CreateLabel(parent).SetText("");

    --Territory snapshots (the actual shape of the selected territory) don't exist in app versions below
    --SNAPSHOT_AND_ICON_MIN_VERSION, so only the name labels still work there
    local displayRow = UI.CreateHorizontalLayoutGroup(parent).SetFlexibleWidth(1);
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

    SpyPlanePlayCardBtn = UI.CreateButton(parent)
        .SetText("Send Spy Plane")
        .SetInteractable(false)
        .SetColor(BUTTON_COLOURS.DarkGreen)
        .SetFlexibleWidth(1)
        .SetOnClick(function() SpyPlaneSendLineModeClicked(playCard); end);

    SpyPlaneStepsRowParent = parent;
    RebuildSpyPlaneStepsRow();

    SpyPlaneStartTerritoryClicked();
end

---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM)
function SpyPlaneSendLineModeClicked(playCard)
    if (SpyPlaneStartTerritoryID == nil) then
        SpyPlaneStartTerritoryInstructionLabel.SetText("You must select a start territory first").SetColor(ERROR_COLOUR);
        return;
    end

    if (SpyPlaneEndTerritoryID == nil) then
        SpyPlaneEndTerritoryInstructionLabel.SetText("You must select an end territory first").SetColor(ERROR_COLOUR);
        return;
    end

    local startTd = Game.Map.Territories[SpyPlaneStartTerritoryID];
    local endTd = Game.Map.Territories[SpyPlaneEndTerritoryID];
    local percentOverMaxFlightDistance = GetSpyPlanePercentOverMaxFlightDistance(SpyPlaneStartTerritoryID, SpyPlaneEndTerritoryID);

    if (percentOverMaxFlightDistance ~= nil) then
        SpyPlaneEndTerritoryInstructionLabel.SetText("That flight is " .. percentOverMaxFlightDistance .. "% past the maximum flight distance - select an end territory closer to " .. SpyPlaneStartTerritoryName).SetColor(ERROR_COLOUR);
        return;
    end

    local jumpToSpot = WL.RectangleVM.Create(startTd.MiddlePointX, startTd.MiddlePointY, endTd.MiddlePointX, endTd.MiddlePointY);
    local modData = "FlySpyPlane_" .. SpyPlaneStartTerritoryID .. "_" .. SpyPlaneEndTerritoryID;
    local message = "Flies a Spy Plane from " .. SpyPlaneStartTerritoryName .. " to " .. SpyPlaneEndTerritoryName;

    if (playCard(message, modData, WL.TurnPhase.Deploys, {}, jumpToSpot)) then
        Close();
    end
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

---Starts waiting for the player to click a source territory. Like Circle mode's territory picker, a previous
---source selection (if any) is left untouched - its name/snapshot/highlight keep showing - until the player
---actually picks a new one; it's only replaced at that point, not cleared up-front.
function SpyPlaneStartTerritoryClicked()
    UI.InterceptNextTerritoryClick(SpyPlaneStartTerritoryHandleClick);
    SpyPlaneStartTerritoryInstructionLabel.SetText("");
    SpyPlaneEndTerritoryBtn.SetInteractable(false);
    SpyPlanePlayCardBtn.SetInteractable(false);
    if (SpyPlaneStepsModeBtn ~= nil) then
        SpyPlaneStepsModeBtn.SetInteractable(false);
    end

    if (SpyPlaneStartTerritoryID ~= nil) then
        --a source already exists, so leave the button clickable - pressing it again cancels the pending pick
        --and keeps that existing source, rather than leaving the player stuck waiting for a map click
        SpyPlaneStartTerritoryBtn.SetText("Keep Selection").SetOnClick(SpyPlaneKeepStartSelectionClicked);
    else
        SpyPlaneStartTerritoryBtn.SetInteractable(false);
        SpyPlaneStartTerritoryNameLabel.SetText("Selecting...");
    end
end

---Cancels the pending source pick (swallowing whatever territory gets clicked next) and keeps whatever source
---already existed before "Select Source" was pressed.
function SpyPlaneKeepStartSelectionClicked()
    UI.InterceptNextTerritoryClick(function() end);
    SpyPlaneStartTerritoryBtn.SetText("Select Source").SetOnClick(SpyPlaneStartTerritoryClicked);
    SpyPlaneEndTerritoryBtn.SetInteractable(true);
    SpyPlanePlayCardBtn.SetInteractable(IsSpyPlaneSelectionValid());
    UpdateSpyPlaneStepsPreviewAvailability();
end

function SpyPlaneStartTerritoryHandleClick(terrDetails)
    if UI.IsDestroyed(SpyPlaneStartTerritoryBtn) then
        -- Dialog was destroyed, so we don't need to intercept the click anymore
        return WL.CancelClickIntercept;
    end
    SpyPlaneStartTerritoryBtn.SetText("Select Source").SetOnClick(SpyPlaneStartTerritoryClicked).SetInteractable(true);
    SpyPlaneEndTerritoryBtn.SetInteractable(true);

    local pickedNewSource = false;
    if (terrDetails == nil) then
        --The click request was cancelled - keep whatever source already existed (there's nothing to replace it with)
        SpyPlaneStartTerritoryInstructionLabel.SetText("");
        if (SpyPlaneStartTerritoryID == nil) then
            ClearSpyPlaneStartSnapshot();
        end
    elseif (terrDetails.ID == SpyPlaneEndTerritoryID) then
        SpyPlaneStartTerritoryInstructionLabel.SetText("Start territory can't be the same as the end territory").SetColor(ERROR_COLOUR);
    else
        SpyPlaneStartTerritoryInstructionLabel.SetText("");
        SpyPlaneStartTerritoryID = terrDetails.ID;
        SpyPlaneStartTerritoryName = terrDetails.Name;
        ShowSpyPlaneStartSnapshot(terrDetails.ID, terrDetails.Name);
        pickedNewSource = true;
    end

    SpyPlanePlayCardBtn.SetInteractable(IsSpyPlaneSelectionValid());
    UpdateSpyPlaneFlightDistanceLabel();
    UpdateSpyPlaneHighlight();
    UpdateSpyPlanePlayCardButtonText();
    UpdateSpyPlaneStepsPreviewAvailability();

    --a successful source pick should flow straight into target selection, so the player doesn't need to press the
    --"Select Target" button themselves
    if (pickedNewSource) then
        SpyPlaneEndTerritoryClicked();
    end
end

---Starts waiting for the player to click a target territory. Like Circle mode's territory picker, a previous
---target selection (if any) is left untouched - its name/snapshot/highlight keep showing - until the player
---actually picks a new one; it's only replaced at that point, not cleared up-front.
function SpyPlaneEndTerritoryClicked()
    UI.InterceptNextTerritoryClick(SpyPlaneEndTerritoryHandleClick);
    SpyPlaneEndTerritoryInstructionLabel.SetText("");
    SpyPlaneStartTerritoryBtn.SetInteractable(false);
    SpyPlanePlayCardBtn.SetInteractable(false);
    if (SpyPlaneStepsModeBtn ~= nil) then
        SpyPlaneStepsModeBtn.SetInteractable(false);
    end

    if (SpyPlaneEndTerritoryID ~= nil) then
        --a target already exists, so leave the button clickable - pressing it again cancels the pending pick
        --and keeps that existing target, rather than leaving the player stuck waiting for a map click
        SpyPlaneEndTerritoryBtn.SetText("Keep Selection").SetOnClick(SpyPlaneKeepEndSelectionClicked);
    else
        SpyPlaneEndTerritoryBtn.SetInteractable(false);
        SpyPlaneEndTerritoryNameLabel.SetText("Selecting...");
    end
end

---Cancels the pending target pick (swallowing whatever territory gets clicked next) and keeps whatever target
---already existed before "Select Target" was pressed.
function SpyPlaneKeepEndSelectionClicked()
    UI.InterceptNextTerritoryClick(function() end);
    SpyPlaneEndTerritoryBtn.SetText("Select Target").SetOnClick(SpyPlaneEndTerritoryClicked);
    SpyPlaneStartTerritoryBtn.SetInteractable(true);
    SpyPlanePlayCardBtn.SetInteractable(IsSpyPlaneSelectionValid());
    UpdateSpyPlaneStepsPreviewAvailability();
end

function SpyPlaneEndTerritoryHandleClick(terrDetails)
    if UI.IsDestroyed(SpyPlaneEndTerritoryBtn) then
        -- Dialog was destroyed, so we don't need to intercept the click anymore
        return WL.CancelClickIntercept;
    end
    SpyPlaneEndTerritoryBtn.SetText("Select Target").SetOnClick(SpyPlaneEndTerritoryClicked).SetInteractable(true);
    SpyPlaneStartTerritoryBtn.SetInteractable(true);

    if (terrDetails == nil) then
        --The click request was cancelled - keep whatever target already existed (there's nothing to replace it with)
        SpyPlaneEndTerritoryInstructionLabel.SetText("");
        if (SpyPlaneEndTerritoryID == nil) then
            ClearSpyPlaneEndSnapshot();
        end
    elseif (terrDetails.ID == SpyPlaneStartTerritoryID) then
        SpyPlaneEndTerritoryInstructionLabel.SetText("End territory can't be the same as the start territory").SetColor(ERROR_COLOUR);
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

    return math.max(1, math.floor(((flightDistance / maxFlightDistance) - 1) * 100 + 0.5));
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

---Highlights whichever mode (Line, Circle or Path) is currently active, delegating to that mode's own highlight
---logic. Used to restore the normal highlight once a step preview is dismissed.
function UpdateSpyPlaneSelectedModeHighlight()
    if (SpyPlaneSelectedFlightMode == SpyPlaneFlightMode.Circle) then
        UpdateSpyPlaneCircleHighlight();
    elseif (SpyPlaneSelectedFlightMode == SpyPlaneFlightMode.Path) then
        UpdateSpyPlanePathHighlight();
    else
        UpdateSpyPlaneHighlight();
    end
end

---@class SpyPlaneStepPreview
---@field Territories TerritoryID[] # territories covered by the flight during this step
---@field PlaneLocationTerritoryID TerritoryID # territory nearest the leading edge of this step - matches the "Spy Plane" position annotation

---Computes, for whichever mode (Line, Circle or Path) is currently active, every step a Steps flight (either
---Distance-based or Segment-based) will take - a client-side replay of the same Flight.NewProgress/Flight.Advance
---stepping SpyPlaneApplication.FlySpyPlane/FlySpyPlaneCircle/FlySpyPlanePath use server-side, against a throwaway
---FlightProgress so nothing here touches Mod.PrivateGameData.
---@return SpyPlaneStepPreview[]
function ComputeSpyPlaneStepsPreview()
    local path;
    if (SpyPlaneSelectedFlightMode == SpyPlaneFlightMode.Circle) then
        if (SpyPlaneCircleTerritoryID == nil) then return {}; end
        path = BuildSpyPlaneCirclePath(SpyPlaneCircleTerritoryID, SpyPlaneCircleRadiusInput.GetValue(), SpyPlaneCircleDirection);
    elseif (SpyPlaneSelectedFlightMode == SpyPlaneFlightMode.Path) then
        if (not IsSpyPlanePathSelectionValid()) then return {}; end
        local maxFlightDistance = Mod.Settings.SpyPlaneMaxFlightDistance or 300;
        path = BuildSpyPlanePathPath(maxFlightDistance);
    else
        if (SpyPlaneStartTerritoryID == nil or SpyPlaneEndTerritoryID == nil) then return {}; end
        local maxFlightDistance = Mod.Settings.SpyPlaneMaxFlightDistance or 300;
        path = BuildSpyPlanePath(SpyPlaneStartTerritoryID, SpyPlaneEndTerritoryID, maxFlightDistance);
    end

    local inclusionGenerosity = Mod.Settings.SpyPlaneInclusionGenerosity or 50;
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
        local lastPoint = result.Points[#result.Points];
        table.insert(steps, {
            Territories = Flight.GetTerritoriesNearPoints(Game, result.Points, inclusionGenerosity),
            PlaneLocationTerritoryID = Flight.FindNearestTerritory(Game, lastPoint.X, lastPoint.Y),
        });
    end

    return steps;
end

---(Re)builds the <-/Show Plane/-> row in SpyPlaneStepsRowParent, or destroys it if SpyPlaneStepsRowShown
---is false. There's no show/hide primitive in the mod UI library, so toggling this row's visibility means
---destroying and recreating it.
function RebuildSpyPlaneStepsRow()
    if (SpyPlaneStepsPreviewRow ~= nil) then
        UI.Destroy(SpyPlaneStepsPreviewRow);
        SpyPlaneStepsPreviewRow = nil;
    end

    if (not SpyPlaneStepsRowShown) then return; end

    SpyPlaneStepsPreviewRow = UI.CreateHorizontalLayoutGroup(SpyPlaneStepsRowParent).SetFlexibleWidth(1);
    SpyPlaneStepsPreviousBtn = UI.CreateButton(SpyPlaneStepsPreviewRow)
        .SetText("<-")
        .SetInteractable(false)
        .SetOnClick(SpyPlaneStepsPreviousClicked)
        .SetPreferredWidth(50)
        .SetFlexibleWidth(0);

    SpyPlaneShowPlaneLocationBtn = UI.CreateButton(SpyPlaneStepsPreviewRow)
        .SetText("Show Plane")
        .SetOnClick(SpyPlaneShowPlaneLocationClicked)
        .SetFlexibleWidth(1);

    SpyPlaneStepsNextBtn = UI.CreateButton(SpyPlaneStepsPreviewRow)
        .SetText("->")
        .SetInteractable(false)
        .SetOnClick(SpyPlaneStepsNextClicked)
        .SetPreferredWidth(50)
        .SetFlexibleWidth(0);
end

---Recomputes the step preview (if the steps row is currently shown) or clears it (if not), and refreshes the
---highlight to match. Called whenever the current mode's selection changes, so a stale preview is never left
---showing after something that would change it.
function RefreshSpyPlaneStepsPreview()
    SpyPlaneStepsPreview = nil;
    SpyPlaneStepsPreviewIndex = nil;
    SpyPlaneShowPlaneLocation = false;

    if (not SpyPlaneStepsRowShown) then return; end

    local preview = ComputeSpyPlaneStepsPreview();
    if (#preview == 0) then
        --nothing to preview (e.g. a degenerate 0-length path) - close the row rather than show an empty one
        SpyPlaneStepsRowShown = false;
        RebuildSpyPlaneStepsRow();
        UpdateSpyPlaneSelectedModeHighlight();
        return;
    end

    SpyPlaneStepsPreview = preview;
    SpyPlaneStepsPreviewIndex = 1;
    UpdateSpyPlaneStepsPreviewDisplay();
end

---Enables the Steps icon button only when the current mode has a valid selection (both a source and target for
---Line, a center territory for Circle, or 2+ territories within max distance for Path), and closes the steps row
---if the selection just became invalid.
function UpdateSpyPlaneStepsPreviewAvailability()
    local selectionValid;
    if (SpyPlaneSelectedFlightMode == SpyPlaneFlightMode.Circle) then
        selectionValid = SpyPlaneCircleTerritoryID ~= nil;
    elseif (SpyPlaneSelectedFlightMode == SpyPlaneFlightMode.Path) then
        selectionValid = IsSpyPlanePathSelectionValid();
    else
        selectionValid = IsSpyPlaneSelectionValid();
    end

    if (SpyPlaneStepsModeBtn ~= nil) then
        SpyPlaneStepsModeBtn.SetInteractable(selectionValid);
    end

    if (not selectionValid and SpyPlaneStepsRowShown) then
        SpyPlaneStepsRowShown = false;
        RebuildSpyPlaneStepsRow();
    end

    RefreshSpyPlaneStepsPreview();
end

---Toggles the steps row (and the step-preview mode it drives) on/off.
function SpyPlaneStepsModeClicked()
    SpyPlaneStepsRowShown = not SpyPlaneStepsRowShown;
    RebuildSpyPlaneStepsRow();
    RefreshSpyPlaneStepsPreview();

    if (not SpyPlaneStepsRowShown) then
        UpdateSpyPlaneSelectedModeHighlight();
    end
end

---Highlights the currently-selected preview step - either the full corridor of territories it covers, or just the
---single territory the "Spy Plane" position annotation would land on, depending on SpyPlaneShowPlaneLocation.
function UpdateSpyPlaneStepsPreviewDisplay()
    local step = SpyPlaneStepsPreview[SpyPlaneStepsPreviewIndex];
    if (SpyPlaneShowPlaneLocation) then
        Game.HighlightTerritories({ step.PlaneLocationTerritoryID });
    else
        Game.HighlightTerritories(step.Territories);
    end

    SpyPlaneShowPlaneLocationBtn.SetText(SpyPlaneShowPlaneLocation and "Show Flight Path" or "Show Plane");
    SpyPlaneStepsPreviousBtn.SetInteractable(SpyPlaneStepsPreviewIndex > 1);
    SpyPlaneStepsNextBtn.SetInteractable(SpyPlaneStepsPreviewIndex < #SpyPlaneStepsPreview);
end

function SpyPlaneShowPlaneLocationClicked()
    SpyPlaneShowPlaneLocation = not SpyPlaneShowPlaneLocation;
    UpdateSpyPlaneStepsPreviewDisplay();
end

function SpyPlaneStepsPreviousClicked()
    if (SpyPlaneStepsPreviewIndex <= 1) then return; end
    SpyPlaneStepsPreviewIndex = SpyPlaneStepsPreviewIndex - 1;
    UpdateSpyPlaneStepsPreviewDisplay();
end

function SpyPlaneStepsNextClicked()
    if (SpyPlaneStepsPreviewIndex >= #SpyPlaneStepsPreview) then return; end
    SpyPlaneStepsPreviewIndex = SpyPlaneStepsPreviewIndex + 1;
    UpdateSpyPlaneStepsPreviewDisplay();
end

----------------------------------------------------------------------------------------------------------------------
-- Circle mode: pick a single center territory, flies a full loop around it - always starting at the top of the
-- loop. Supports whichever flight style (Instant, Distance-based Steps, Segment-based Steps) is configured in the
-- mod's settings, same as Line mode.
----------------------------------------------------------------------------------------------------------------------

---@param parent UIObject
---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM)
function Create_SpyPlaneCircleMode_UI(parent, playCard)
    --reset to the default direction every time Circle mode's content is (re)built
    SpyPlaneCircleDirection = 1;

    local topRow = UI.CreateHorizontalLayoutGroup(parent).SetFlexibleWidth(1);

    --direction only affects a Steps flight (which territory gets revealed on which turn) - an Instant flight
    --highlights the full loop regardless of direction, so there's nothing for this button to control there
    SpyPlaneCircleDirectionBtn = nil;
    if (Mod.Settings.SpyPlaneFlightStyleInstant ~= true) then
        SpyPlaneCircleDirectionBtn = UI.CreateButton(topRow)
            .SetText("Clockwise")
            .SetColor(BUTTON_COLOURS.LightBlue)
            .SetOnClick(SpyPlaneCircleDirectionClicked)
            .SetFlexibleWidth(0.5);
    end

    SpyPlaneCircleTerritoryBtn = UI.CreateButton(topRow)
        .SetText("Select Territory")
        .SetOnClick(SpyPlaneCircleTerritoryClicked)
        .SetFlexibleWidth(SpyPlaneCircleDirectionBtn ~= nil and 0.5 or 1);

    SpyPlaneCircleInstructionLabel = UI.CreateLabel(parent).SetText("");

    --Territory snapshots (the actual shape of the selected territory) don't exist in app versions below
    --SNAPSHOT_AND_ICON_MIN_VERSION, so only the name label still works there
    local displayRow = UI.CreateHorizontalLayoutGroup(parent).SetFlexibleWidth(1);
    local circleColumn = UI.CreateVerticalLayoutGroup(displayRow).SetPreferredWidth(120).SetFlexibleWidth(1).SetCenter(true);
    SpyPlaneCircleTerritorySnapshot = nil;
    SpyPlaneCircleTerritorySnapshotVert = nil;
    if (WL.IsVersionOrHigher(SNAPSHOT_AND_ICON_MIN_VERSION)) then
        SpyPlaneCircleTerritorySnapshotVert = UI.CreateVerticalLayoutGroup(circleColumn).SetCenter(true).SetPreferredHeight(60); --fixed height so the row doesn't resize when the snapshot appears
    end
    SpyPlaneCircleTerritoryNameLabel = UI.CreateLabel(circleColumn).SetText(" ").SetAlignment(WL.TextAlignmentOptions.Center);

    local radiusRow = UI.CreateHorizontalLayoutGroup(parent).SetFlexibleWidth(1);
    UI.CreateLabel(radiusRow).SetText("Radius").SetPreferredWidth(80);
    local maxRadius = math.floor(GetSpyPlaneMaxCircleRadius());
    SpyPlaneCircleRadiusInput = UI.CreateNumberInputField(radiusRow)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(maxRadius)
        .SetValue(maxRadius)
        .SetFlexibleWidth(1);

    SpyPlaneCircleRefreshBtn = UI.CreateButton(radiusRow)
        .SetIcon("Refresh.png")
        .SetText("")
        .SetIconPreferredWidth(30)
        .SetIconPreferredHeight(30)
        .SetOnClick(SpyPlaneCircleRefreshClicked)
        .SetPreferredWidth(40)
        .SetFlexibleWidth(0);

    SpyPlaneCirclePlayCardBtn = UI.CreateButton(parent)
        .SetText("Send Spy Plane")
        .SetInteractable(false)
        .SetColor(BUTTON_COLOURS.DarkGreen)
        .SetFlexibleWidth(1)
        .SetOnClick(function() SpyPlaneSendCircleModeClicked(playCard); end);

    SpyPlaneStepsRowParent = parent;
    RebuildSpyPlaneStepsRow();

    SpyPlaneCircleTerritoryClicked();
end

---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM)
function SpyPlaneSendCircleModeClicked(playCard)
    if (SpyPlaneCircleTerritoryID == nil) then
        SpyPlaneCircleInstructionLabel.SetText("You must select a territory first").SetColor(ERROR_COLOUR);
        return;
    end

    local centerTd = Game.Map.Territories[SpyPlaneCircleTerritoryID];
    local radius = SpyPlaneCircleRadiusInput.GetValue();
    local jumpToSpot = WL.RectangleVM.Create(centerTd.MiddlePointX - radius, centerTd.MiddlePointY - radius, centerTd.MiddlePointX + radius, centerTd.MiddlePointY + radius);
    local modData = "FlySpyPlaneCircle_" .. SpyPlaneCircleTerritoryID .. "_" .. radius .. "_" .. SpyPlaneCircleDirection;
    local message = "Flies a Spy Plane in a circle around " .. SpyPlaneCircleTerritoryName;

    if (playCard(message, modData, WL.TurnPhase.Deploys, {}, jumpToSpot)) then
        Close();
    end
end

--SetTerritoryIDs rejects an empty list, so the snapshot is destroyed to clear it and recreated on the next selection
function ClearSpyPlaneCircleSnapshot()
    SpyPlaneCircleTerritoryNameLabel.SetText(" ");
    if (SpyPlaneCircleTerritorySnapshot == nil) then return; end
    UI.Destroy(SpyPlaneCircleTerritorySnapshot);
    SpyPlaneCircleTerritorySnapshot = nil;
end

function ShowSpyPlaneCircleSnapshot(terrID, name)
    SpyPlaneCircleTerritoryNameLabel.SetText(name);
    if (SpyPlaneCircleTerritorySnapshotVert == nil) then return; end
    if (SpyPlaneCircleTerritorySnapshot == nil) then
        SpyPlaneCircleTerritorySnapshot = UI.CreateSnapshot(SpyPlaneCircleTerritorySnapshotVert).SetPreferredWidth(60).SetPreferredHeight(60);
    end
    SpyPlaneCircleTerritorySnapshot.SetTerritoryIDs({ terrID });
end

---Starts waiting for the player to click a territory. Unlike the start/end territory pickers in Line mode, the
---previous selection (if any) is left untouched - its name/snapshot/highlight keep showing - until the player
---actually picks a new one; it's only replaced at that point, not cleared up-front.
function SpyPlaneCircleTerritoryClicked()
    UI.InterceptNextTerritoryClick(SpyPlaneCircleTerritoryHandleClick);
    SpyPlaneCircleInstructionLabel.SetText("");
    SpyPlaneCirclePlayCardBtn.SetInteractable(false);
    SpyPlaneCircleRadiusInput.SetInteractable(false);
    SpyPlaneCircleRefreshBtn.SetInteractable(false);
    if (SpyPlaneStepsModeBtn ~= nil) then
        SpyPlaneStepsModeBtn.SetInteractable(false);
    end
    if (SpyPlaneCircleDirectionBtn ~= nil) then
        SpyPlaneCircleDirectionBtn.SetInteractable(false);
    end

    if (SpyPlaneCircleTerritoryID ~= nil) then
        --a selection already exists, so leave the button clickable - pressing it again cancels the pending pick
        --and keeps that existing selection, rather than leaving the player stuck waiting for a map click
        SpyPlaneCircleTerritoryBtn.SetText("Keep Selection").SetOnClick(SpyPlaneCircleKeepSelectionClicked);
    else
        SpyPlaneCircleTerritoryBtn.SetInteractable(false);
        SpyPlaneCircleTerritoryNameLabel.SetText("Selecting...");
    end
end

---Cancels the pending territory pick (swallowing whatever territory gets clicked next) and keeps whatever
---selection already existed before "Select Territory" was pressed.
function SpyPlaneCircleKeepSelectionClicked()
    UI.InterceptNextTerritoryClick(function() end);
    SpyPlaneCircleTerritoryBtn.SetText("Select Territory").SetOnClick(SpyPlaneCircleTerritoryClicked);
    SpyPlaneCirclePlayCardBtn.SetInteractable(SpyPlaneCircleTerritoryID ~= nil);
    SpyPlaneCircleRadiusInput.SetInteractable(true);
    SpyPlaneCircleRefreshBtn.SetInteractable(true);
    if (SpyPlaneCircleDirectionBtn ~= nil) then
        SpyPlaneCircleDirectionBtn.SetInteractable(true);
    end
    UpdateSpyPlaneStepsPreviewAvailability();
end

function SpyPlaneCircleTerritoryHandleClick(terrDetails)
    if UI.IsDestroyed(SpyPlaneCircleTerritoryBtn) then
        -- Dialog was destroyed, so we don't need to intercept the click anymore
        return WL.CancelClickIntercept;
    end
    SpyPlaneCircleTerritoryBtn.SetText("Select Territory").SetOnClick(SpyPlaneCircleTerritoryClicked).SetInteractable(true);
    SpyPlaneCircleRadiusInput.SetInteractable(true);
    SpyPlaneCircleRefreshBtn.SetInteractable(true);
    if (SpyPlaneCircleDirectionBtn ~= nil) then
        SpyPlaneCircleDirectionBtn.SetInteractable(true);
    end

    if (terrDetails == nil) then
        --The click request was cancelled - keep whatever selection already existed (there's nothing to replace it with)
        SpyPlaneCircleInstructionLabel.SetText("");
        if (SpyPlaneCircleTerritoryID == nil) then
            ClearSpyPlaneCircleSnapshot();
        end
    else
        SpyPlaneCircleInstructionLabel.SetText("");
        SpyPlaneCircleTerritoryID = terrDetails.ID;
        SpyPlaneCircleTerritoryName = terrDetails.Name;
        ShowSpyPlaneCircleSnapshot(terrDetails.ID, terrDetails.Name);
    end

    SpyPlaneCirclePlayCardBtn.SetInteractable(SpyPlaneCircleTerritoryID ~= nil);
    UpdateSpyPlaneCircleHighlight();
    UpdateSpyPlaneStepsPreviewAvailability();
end

---Refreshes the Circle highlight and invalidates any step preview in progress (it's now stale, since Refresh
---implies the radius changed).
function SpyPlaneCircleRefreshClicked()
    UpdateSpyPlaneStepsPreviewAvailability();
    UpdateSpyPlaneCircleHighlight();
end

---Toggles between Clockwise and Anticlockwise - the button's own text always names the direction it's currently
---set to.
function SpyPlaneCircleDirectionClicked()
    if (SpyPlaneCircleDirection == 1) then
        SpyPlaneCircleDirection = -1;
        SpyPlaneCircleDirectionBtn.SetText("Anticlockwise");
    else
        SpyPlaneCircleDirection = 1;
        SpyPlaneCircleDirectionBtn.SetText("Clockwise");
    end

    --flipping direction invalidates any step preview in progress (it's now stale)
    UpdateSpyPlaneStepsPreviewAvailability();
end

---The largest radius the loop can be: Maximum Flight Distance is treated as the loop's total circumference, so
---this is the radius at which the loop's circumference exactly equals it.
---@return number
function GetSpyPlaneMaxCircleRadius()
    local maxFlightDistance = Mod.Settings.SpyPlaneMaxFlightDistance or 300;
    return maxFlightDistance / (2 * math.pi);
end

---Builds the loop FlightPath for Circle mode - always starts at the top of the loop (angle -pi/2, since map Y
---increases downward), in whichever direction the player picked.
---@param centerTerritoryID TerritoryID
---@param radius number
---@param direction number # +1 (Clockwise) or -1 (Anticlockwise)
---@return FlightPath
function BuildSpyPlaneCirclePath(centerTerritoryID, radius, direction)
    local centerTd = Game.Map.Territories[centerTerritoryID];
    return Flight.NewLoopPath(centerTd.MiddlePointX, centerTd.MiddlePointY, radius, -math.pi / 2, direction);
end

---Highlights the territories within Inclusion Generosity of the full loop (at the player's chosen radius and
---direction) around the selected center territory. Clears highlighting if no center territory is picked yet.
function UpdateSpyPlaneCircleHighlight()
    if (SpyPlaneCircleTerritoryID == nil) then
        Game.HighlightTerritories({});
        return;
    end

    local inclusionGenerosity = Mod.Settings.SpyPlaneInclusionGenerosity or 50;
    local path = BuildSpyPlaneCirclePath(SpyPlaneCircleTerritoryID, SpyPlaneCircleRadiusInput.GetValue(), SpyPlaneCircleDirection);
    local coveredTerritories = Flight.GetTerritoriesAlongPath(Game, path, inclusionGenerosity);
    Game.HighlightTerritories(coveredTerritories);
end

----------------------------------------------------------------------------------------------------------------------
-- Path mode: pick any number (2+) of territories, flies the straight-leg route through them in order. Supports
-- whichever flight style (Instant, Distance-based Steps, Segment-based Steps) is configured in the mod's settings,
-- same as Line mode. Deliberately simple UI for now - a plain text list of waypoints, add-to-end/remove-last/clear
-- only (no reordering, no per-waypoint snapshots).
----------------------------------------------------------------------------------------------------------------------

---@param parent UIObject
---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM)
function Create_SpyPlanePathMode_UI(parent, playCard)
    SpyPlanePathAddBtn = UI.CreateButton(parent)
        .SetText("Add Territories")
        .SetOnClick(SpyPlanePathAddTerritoryClicked)
        .SetFlexibleWidth(1);

    SpyPlanePathInstructionLabel = UI.CreateLabel(parent).SetText("");
    SpyPlanePathWaypointsLabel = UI.CreateLabel(parent).SetText("No territories selected yet");

    local actionsRow = UI.CreateHorizontalLayoutGroup(parent).SetFlexibleWidth(1);
    SpyPlanePathRemoveLastBtn = UI.CreateButton(actionsRow)
        .SetText("Remove Last")
        .SetInteractable(false)
        .SetOnClick(SpyPlanePathRemoveLastClicked)
        .SetFlexibleWidth(0.5);

    SpyPlanePathClearBtn = UI.CreateButton(actionsRow)
        .SetText("Clear")
        .SetInteractable(false)
        .SetOnClick(SpyPlanePathClearClicked)
        .SetFlexibleWidth(0.5);

    SpyPlanePathPlayCardBtn = UI.CreateButton(parent)
        .SetText("Send Spy Plane")
        .SetInteractable(false)
        .SetColor(BUTTON_COLOURS.DarkGreen)
        .SetFlexibleWidth(1)
        .SetOnClick(function() SpyPlaneSendPathModeClicked(playCard); end);

    SpyPlaneStepsRowParent = parent;
    RebuildSpyPlaneStepsRow();

    UpdateSpyPlanePathHighlight();
end

---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM)
function SpyPlaneSendPathModeClicked(playCard)
    if (#SpyPlanePathWaypoints < 2) then
        SpyPlanePathInstructionLabel.SetText("You must select at least two territories").SetColor(ERROR_COLOUR);
        return;
    end

    local percentOverMaxFlightDistance = GetSpyPlanePathPercentOverMaxFlightDistance();
    if (percentOverMaxFlightDistance ~= nil) then
        SpyPlanePathInstructionLabel.SetText("That flight is " .. percentOverMaxFlightDistance .. "% past the maximum flight distance - remove a territory or choose a shorter route").SetColor(ERROR_COLOUR);
        return;
    end

    local firstTd = Game.Map.Territories[SpyPlanePathWaypoints[1].ID];
    local lastTd = Game.Map.Territories[SpyPlanePathWaypoints[#SpyPlanePathWaypoints].ID];
    local jumpToSpot = WL.RectangleVM.Create(firstTd.MiddlePointX, firstTd.MiddlePointY, lastTd.MiddlePointX, lastTd.MiddlePointY);

    local ids = {};
    for _, waypoint in ipairs(SpyPlanePathWaypoints) do
        table.insert(ids, waypoint.ID);
    end
    local modData = "FlySpyPlanePath_" .. table.concat(ids, "_");
    local message = "Flies a Spy Plane along a path through " .. #SpyPlanePathWaypoints .. " territories";

    if (playCard(message, modData, WL.TurnPhase.Deploys, {}, jumpToSpot)) then
        Close();
    end
end

---Toggles "adding territories" mode on/off. While on, each territory the player clicks is appended to the route
---and the picker immediately re-arms itself for the next one, so the player can keep clicking territory after
---territory until they're happy, then press the button again (now reading "Adding Territories") to stop.
function SpyPlanePathAddTerritoryClicked()
    if (SpyPlaneAddingPathTerritories) then
        SpyPlanePathStopAddingTerritories();
        return;
    end

    SpyPlaneAddingPathTerritories = true;
    SpyPlanePathAddBtn.SetText("Adding Territories");
    UI.InterceptNextTerritoryClick(SpyPlanePathAddTerritoryHandleClick);
    SpyPlanePathRemoveLastBtn.SetInteractable(false);
    SpyPlanePathClearBtn.SetInteractable(false);
    SpyPlanePathPlayCardBtn.SetInteractable(false);
    if (SpyPlaneStepsModeBtn ~= nil) then
        SpyPlaneStepsModeBtn.SetInteractable(false);
    end

    UpdateSpyPlanePathNextTerritoryRangeHighlight();
end

---Exits "adding territories" mode: swallows whatever territory the player clicks next (there's no way to
---un-register a pending UI.InterceptNextTerritoryClick, only overwrite it), restores the Add button, and
---refreshes everything that was frozen while adding.
function SpyPlanePathStopAddingTerritories()
    SpyPlaneAddingPathTerritories = false;
    UI.InterceptNextTerritoryClick(function() end);
    SpyPlanePathAddBtn.SetText("Add Territories");
    UpdateSpyPlanePathDisplay();
    UpdateSpyPlanePathHighlight();
    UpdateSpyPlaneStepsPreviewAvailability();
end

function SpyPlanePathAddTerritoryHandleClick(terrDetails)
    if UI.IsDestroyed(SpyPlanePathAddBtn) then
        -- Dialog was destroyed, so we don't need to intercept the click anymore
        return WL.CancelClickIntercept;
    end

    if (terrDetails == nil) then
        --The click request was cancelled - stop adding rather than leaving the picker silently armed
        SpyPlanePathStopAddingTerritories();
        return;
    end

    table.insert(SpyPlanePathWaypoints, { ID = terrDetails.ID, Name = terrDetails.Name });
    UpdateSpyPlanePathDisplay();
    UpdateSpyPlanePathNextTerritoryRangeHighlight();

    --still adding - re-arm the intercept for the next territory instead of stopping
    UI.InterceptNextTerritoryClick(SpyPlanePathAddTerritoryHandleClick);
end

function SpyPlanePathRemoveLastClicked()
    table.remove(SpyPlanePathWaypoints);
    UpdateSpyPlanePathDisplay();
    UpdateSpyPlanePathHighlight();
    UpdateSpyPlaneStepsPreviewAvailability();
end

function SpyPlanePathClearClicked()
    SpyPlanePathWaypoints = {};
    UpdateSpyPlanePathDisplay();
    UpdateSpyPlanePathHighlight();
    UpdateSpyPlaneStepsPreviewAvailability();
end

---Refreshes the waypoints list label, the Remove Last/Clear/Send button interactability, and the instruction
---label. Called whenever the waypoint list changes.
function UpdateSpyPlanePathDisplay()
    if (#SpyPlanePathWaypoints == 0) then
        SpyPlanePathWaypointsLabel.SetText("No territories selected yet");
    else
        local names = {};
        for _, waypoint in ipairs(SpyPlanePathWaypoints) do
            table.insert(names, waypoint.Name);
        end
        SpyPlanePathWaypointsLabel.SetText(table.concat(names, " -> "));
    end

    SpyPlanePathRemoveLastBtn.SetInteractable(#SpyPlanePathWaypoints > 0);
    SpyPlanePathClearBtn.SetInteractable(#SpyPlanePathWaypoints > 0);
    SpyPlanePathPlayCardBtn.SetInteractable(IsSpyPlanePathSelectionValid());
    UpdateSpyPlanePathInstructionLabel();
end

---Refreshes the instruction label with the flight distance check (or a prompt for one more territory), provided
---at least one territory is selected. Recalculated whenever the waypoint list changes.
function UpdateSpyPlanePathInstructionLabel()
    local percentOverMaxFlightDistance = GetSpyPlanePathPercentOverMaxFlightDistance();
    if (percentOverMaxFlightDistance ~= nil) then
        SpyPlanePathInstructionLabel.SetText(percentOverMaxFlightDistance .. "% > max distance").SetColor(ERROR_COLOUR);
    elseif (#SpyPlanePathWaypoints == 1) then
        SpyPlanePathInstructionLabel.SetText("Add at least one more territory");
    else
        SpyPlanePathInstructionLabel.SetText("");
    end
end

---Builds the (already max-distance-clamped) FlightPath through every waypoint's centerpoint, in order.
---@param maxFlightDistance number
---@return FlightPath
function BuildSpyPlanePathPath(maxFlightDistance)
    local waypoints = {};
    for _, waypoint in ipairs(SpyPlanePathWaypoints) do
        local td = Game.Map.Territories[waypoint.ID];
        table.insert(waypoints, { X = td.MiddlePointX, Y = td.MiddlePointY });
    end
    return Flight.Clamp(Flight.NewPolylinePath(waypoints), maxFlightDistance);
end

---Returns how far (in whole percent, minimum 1) the route through every waypoint exceeds
---Mod.Settings.SpyPlaneMaxFlightDistance, or nil if it's within range or fewer than 2 waypoints are selected.
---Sums the straight-line distance between each consecutive pair of waypoints.
---@return number
function GetSpyPlanePathTotalDistance()
    local totalDistance = 0;
    for i = 2, #SpyPlanePathWaypoints do
        local a = Game.Map.Territories[SpyPlanePathWaypoints[i - 1].ID];
        local b = Game.Map.Territories[SpyPlanePathWaypoints[i].ID];
        totalDistance = totalDistance + math.sqrt((b.MiddlePointX - a.MiddlePointX) ^ 2 + (b.MiddlePointY - a.MiddlePointY) ^ 2);
    end
    return totalDistance;
end

function GetSpyPlanePathPercentOverMaxFlightDistance()
    if (#SpyPlanePathWaypoints < 2) then return nil; end

    local totalDistance = GetSpyPlanePathTotalDistance();
    local maxFlightDistance = Mod.Settings.SpyPlaneMaxFlightDistance or 300;
    if (totalDistance <= maxFlightDistance) then return nil; end

    return math.max(1, math.floor(((totalDistance / maxFlightDistance) - 1) * 100 + 0.5));
end

---Whether at least two territories are selected and the route through them is within the maximum flight distance.
function IsSpyPlanePathSelectionValid()
    return #SpyPlanePathWaypoints >= 2 and GetSpyPlanePathPercentOverMaxFlightDistance() == nil;
end

---Highlights the territories within the Spy Plane's reach: with 2+ waypoints, the territories along the route
---(clamped to Maximum Flight Distance); with exactly 1, every territory within Maximum Flight Distance of it (the
---valid range for the next waypoint). Clears highlighting if no waypoints are selected yet.
function UpdateSpyPlanePathHighlight()
    local maxFlightDistance = Mod.Settings.SpyPlaneMaxFlightDistance or 300;

    if (#SpyPlanePathWaypoints == 0) then
        Game.HighlightTerritories({});
        return;
    end

    if (#SpyPlanePathWaypoints == 1) then
        local td = Game.Map.Territories[SpyPlanePathWaypoints[1].ID];
        local point = { X = td.MiddlePointX, Y = td.MiddlePointY };
        Game.HighlightTerritories(Flight.GetTerritoriesNearPoints(Game, { point, point }, maxFlightDistance));
        return;
    end

    local inclusionGenerosity = Mod.Settings.SpyPlaneInclusionGenerosity or 50;
    local path = BuildSpyPlanePathPath(maxFlightDistance);
    local coveredTerritories = Flight.GetTerritoriesAlongPath(Game, path, inclusionGenerosity);
    Game.HighlightTerritories(coveredTerritories);
end

---Highlights every territory within reach of the next waypoint pick: the remaining flight distance (Maximum
---Flight Distance minus whatever's already been used by the route so far) around the last selected waypoint.
---Used while "Add Territory" is awaiting a click, so the player can see how far they're still allowed to go.
function UpdateSpyPlanePathNextTerritoryRangeHighlight()
    if (#SpyPlanePathWaypoints == 0) then
        Game.HighlightTerritories({});
        return;
    end

    local maxFlightDistance = Mod.Settings.SpyPlaneMaxFlightDistance or 300;
    local remainingDistance = math.max(0, maxFlightDistance - GetSpyPlanePathTotalDistance());
    local lastTd = Game.Map.Territories[SpyPlanePathWaypoints[#SpyPlanePathWaypoints].ID];
    local point = { X = lastTd.MiddlePointX, Y = lastTd.MiddlePointY };
    Game.HighlightTerritories(Flight.GetTerritoriesNearPoints(Game, { point, point }, remainingDistance));
end
