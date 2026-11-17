require("Utilities");
require("Interface");
require("Flight.Flight");
require("Flight.Path");
require("Flight.Progress");
require("Flight.Territory");

SpyPlaneApplication = {};

---@class SpyPlaneActiveFlight # A Distance-based Steps Spy Plane flight still in progress, carried over between turns
---@field Progress FlightProgress # Mutated turn over turn by Flight.Advance
---@field PlayerID PlayerID # The player who played the Spy Plane card
---@field EndTerritoryID TerritoryID # The territory the player originally selected as the flight's destination, annotated on every step

---@class SpyPlanePrivateGameData
---@field ActiveSpyPlaneFlights SpyPlaneActiveFlight[] | nil # Distance-based Steps flights still in progress, cleared per-flight once each one reaches its end
---@field PendingSpyPlaneVisionFogModIDs GUID[] | nil # FogMod IDs granted last turn, cleared once RemoveExpiredSpyPlaneVisionFogMods removes them

---Grants the given player Visible fog of the given territories for the remainder of this turn only, registering
---the FogMod so RemoveExpiredSpyPlaneVisionFogMods removes it again at the start of the player's next turn. Shared
---by Instant's single whole-flight reveal and each individual step of a Distance-based Steps flight.
---@param coveredTerritories TerritoryID[]
---@param playerID PlayerID
---@return FogMod
local function GrantSpyPlaneVisionForTurn(coveredTerritories, playerID)
	local fogMod = WL.FogMod.Create("Spy Plane vision", WL.StandingFogLevel.Visible, 9000, coveredTerritories, { playerID });

	local priv = Mod.PrivateGameData --[[@as SpyPlanePrivateGameData]];
	if (priv.PendingSpyPlaneVisionFogModIDs == nil) then priv.PendingSpyPlaneVisionFogModIDs = {}; end;
	table.insert(priv.PendingSpyPlaneVisionFogModIDs, fogMod.ID);
	Mod.PrivateGameData = priv;

	return fogMod;
end

---Grants vision of the next strip of territories along an in-progress Distance-based Steps flight (from wherever
---it left off, up to its Flight.ComputeStepDistance-sized step further along). Used both for a flight's first
---step (played as part of its own order) and every subsequent step (advanced automatically by
---SpyPlaneApplication.AdvanceActiveSpyPlaneFlights at the start of each of the flight's following turns).
---@param game GameServerHook
---@param flight SpyPlaneActiveFlight
---@param inclusionGenerosity number
---@param addNewOrder fun(order: GameOrder)
---@param isFirstStep boolean|nil # If true, also annotates the flight's actual starting territory (distinct from this step's current-location annotation, which is based on the step's midpoint and may not match the true start)
local function AdvanceSpyPlaneFlightStep(game, flight, inclusionGenerosity, addNewOrder, isFirstStep)
	local result = Flight.Advance(flight.Progress);

	local coveredTerritories = Flight.GetTerritoriesNearPoints(game, result.Points, inclusionGenerosity);
	local fogMod = GrantSpyPlaneVisionForTurn(coveredTerritories, flight.PlayerID);

	--label whichever territory is closest to this step's leading edge (as far as the plane has gotten this turn)
	--as the plane's current position, and re-label the flight's overall destination each step too since
	--annotations don't persist from the turn the card was played (Instant's annotations are a one-time thing, but
	--a Steps flight spans many turns of separate events)
	local firstPoint = result.Points[1];
	local lastPoint = result.Points[#result.Points];
	local nearestTerritoryID = Flight.FindNearestTerritory(game, lastPoint.X, lastPoint.Y);

	local event = WL.GameOrderEvent.Create(flight.PlayerID, "Spy Plane continues its flight", {}, {});
	event.FogModsOpt = { fogMod };
	event.JumpToActionSpotOpt = WL.RectangleVM.Create(firstPoint.X, firstPoint.Y, lastPoint.X, lastPoint.Y);

	local annotations = {
		[nearestTerritoryID] = WL.TerritoryAnnotation.Create("Spy Plane", 8, GetColourIntegerFromHex(BUTTON_COLOURS.DarkGray)),
		[flight.EndTerritoryID] = WL.TerritoryAnnotation.Create("Spy Plane End", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Charcoal)),
	};
	if (isFirstStep) then
		local startPoint = Flight.PointAt(flight.Progress.Path, 0);
		local startTerritoryID = Flight.FindNearestTerritory(game, startPoint.X, startPoint.Y);
		--don't overwrite the current-location annotation if the first step's leading edge already lands on the start territory
		if (startTerritoryID ~= nearestTerritoryID) then
			annotations[startTerritoryID] = WL.TerritoryAnnotation.Create("Spy Plane Start", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Charcoal));
		end
	end
	event.TerritoryAnnotationsOpt = annotations;

	addNewOrder(event);
end

---Computes the per-step distance for a Steps flight, matching whichever step mode (Distance-based or
---Segment-based) is configured.
---@param path FlightPath
---@return number
local function ComputeSpyPlaneStepDistance(path)
	if (Mod.Settings.SpyPlaneStepModeSegment) then
		local flightSteps = Mod.Settings.SpyPlaneFlightSteps or 5;
		return path.TotalLength / flightSteps;
	end

	local maxDistancePerStep = Mod.Settings.SpyPlaneMaxDistancePerStep or 200;
	--always at least 2 steps, so the flight's start and end territories are never both revealed in a single step
	return Flight.ComputeStepDistance(path.TotalLength, maxDistancePerStep);
end

---Kicks off a Steps flight along path: grants vision of the first step immediately (same as Instant does for the
---whole flight), then (if more than one step is needed) queues the rest to be advanced automatically on the
---player's following turns via SpyPlaneApplication.AdvanceActiveSpyPlaneFlights.
---@param game GameServerHook
---@param path FlightPath
---@param playerID PlayerID
---@param endTerritoryID TerritoryID # Annotated as "Spy Plane End" each step - the flight's destination for a Line, or the loop's center for a Circle
---@param inclusionGenerosity number
---@param addNewOrder fun(order: GameOrder)
local function StartSpyPlaneStepsFlight(game, path, playerID, endTerritoryID, inclusionGenerosity, addNewOrder)
	local stepDistance = ComputeSpyPlaneStepDistance(path);

	---@type SpyPlaneActiveFlight
	local flight = {
		Progress = Flight.NewProgress(path, stepDistance),
		PlayerID = playerID,
		EndTerritoryID = endTerritoryID,
	};

	AdvanceSpyPlaneFlightStep(game, flight, inclusionGenerosity, addNewOrder, true);

	if (flight.Progress.DistanceCovered < flight.Progress.Path.TotalLength) then
		local priv = Mod.PrivateGameData --[[@as SpyPlanePrivateGameData]];
		local activeFlights = priv.ActiveSpyPlaneFlights or {};
		table.insert(activeFlights, flight);
		priv.ActiveSpyPlaneFlights = activeFlights;
		Mod.PrivateGameData = priv;
	end
end

---Flies a Spy Plane along the line between startTerritoryID and endTerritoryID - depending on the configured
---flight style, either grants the player vision of the whole flight line for this turn (Instant), or kicks off a
---Steps flight (step size from either Distance-based or Segment-based mode) by granting vision of its first step
---and (if more than one step is needed) queuing the rest to be advanced automatically on the player's following turns via
---SpyPlaneApplication.AdvanceActiveSpyPlaneFlights.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
---@param playerID PlayerID
---@param startTerritoryID TerritoryID
---@param endTerritoryID TerritoryID
---@param message string # Shown in the order list for the resulting event
function SpyPlaneApplication.FlySpyPlane(game, addNewOrder, playerID, startTerritoryID, endTerritoryID, message)
	local maxFlightDistance = Mod.Settings.SpyPlaneMaxFlightDistance or 300;
	local inclusionGenerosity = Mod.Settings.SpyPlaneInclusionGenerosity or 50;

	local startTd = game.Map.Territories[startTerritoryID];
	local endTd = game.Map.Territories[endTerritoryID];
	local event = WL.GameOrderEvent.Create(playerID, message, {}, {});
	event.JumpToActionSpotOpt = WL.RectangleVM.Create(startTd.MiddlePointX, startTd.MiddlePointY, endTd.MiddlePointX, endTd.MiddlePointY);

	--in Steps (Distance-based or Segment-based), the first step's own event (via AdvanceSpyPlaneFlightStep)
	--already labels the plane's starting position via its isFirstStep annotation, so a separate
	--"Spy Plane Start" annotation here would be redundant
	local isSteps = Mod.Settings.SpyPlaneFlightStyleSteps;
	local annotations = {
		[endTerritoryID] = WL.TerritoryAnnotation.Create("Spy Plane End", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Charcoal)),
	};
	if (not isSteps) then
		annotations[startTerritoryID] = WL.TerritoryAnnotation.Create("Spy Plane Start", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Charcoal));
	end
	event.TerritoryAnnotationsOpt = annotations;

	local path = Flight.Clamp(Flight.NewPolylinePath({
		{ X = startTd.MiddlePointX, Y = startTd.MiddlePointY },
		{ X = endTd.MiddlePointX, Y = endTd.MiddlePointY },
	}), maxFlightDistance);

	if (Mod.Settings.SpyPlaneFlightStyleInstant) then
		local coveredTerritories = Flight.GetTerritoriesAlongPath(game, path, inclusionGenerosity);
		event.FogModsOpt = { GrantSpyPlaneVisionForTurn(coveredTerritories, playerID) };
	elseif (isSteps) then
		--grant this turn's step immediately, same as Instant does for the whole flight, then queue whatever's left
		StartSpyPlaneStepsFlight(game, path, playerID, endTerritoryID, inclusionGenerosity, addNewOrder);
	end

	addNewOrder(event);
end

---Flies a Spy Plane in a full loop of the given radius around centerTerritoryID, starting at the top of the loop -
---depending on the configured flight style, either grants the player vision of the whole loop for this turn
---(Instant), or kicks off a Steps flight the same way SpyPlaneApplication.FlySpyPlane does. radius is clamped to
---[1, Maximum Flight Distance / (2*pi)] - the player picks it client-side, but the server re-clamps rather than
---trusting the card's modData as-is, since Maximum Flight Distance is treated as the loop's largest allowed
---circumference.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
---@param playerID PlayerID
---@param centerTerritoryID TerritoryID
---@param radius number
---@param direction number # +1 (Clockwise) or -1 (Anticlockwise)
---@param message string # Shown in the order list for the resulting event
function SpyPlaneApplication.FlySpyPlaneCircle(game, addNewOrder, playerID, centerTerritoryID, radius, direction, message)
	local maxFlightDistance = Mod.Settings.SpyPlaneMaxFlightDistance or 300;
	local inclusionGenerosity = Mod.Settings.SpyPlaneInclusionGenerosity or 50;
	local maxRadius = maxFlightDistance / (2 * math.pi);
	radius = math.max(1, math.min(radius, maxRadius));

	local centerTd = game.Map.Territories[centerTerritoryID];
	local event = WL.GameOrderEvent.Create(playerID, message, {}, {});
	event.JumpToActionSpotOpt = WL.RectangleVM.Create(centerTd.MiddlePointX - radius, centerTd.MiddlePointY - radius, centerTd.MiddlePointX + radius, centerTd.MiddlePointY + radius);

	--in Steps, the first step's own event (via AdvanceSpyPlaneFlightStep) already labels the plane's starting
	--position via its isFirstStep annotation, so a separate "Spy Plane Circle" annotation here would be redundant
	local isSteps = Mod.Settings.SpyPlaneFlightStyleSteps;
	if (not isSteps) then
		event.TerritoryAnnotationsOpt = {
			[centerTerritoryID] = WL.TerritoryAnnotation.Create("Spy Plane Circle", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Charcoal)),
		};
	end

	--always starts at the top of the loop (angle -pi/2, since map Y increases downward)
	local path = Flight.NewLoopPath(centerTd.MiddlePointX, centerTd.MiddlePointY, radius, -math.pi / 2, direction);

	if (Mod.Settings.SpyPlaneFlightStyleInstant) then
		local coveredTerritories = Flight.GetTerritoriesAlongPath(game, path, inclusionGenerosity);
		event.FogModsOpt = { GrantSpyPlaneVisionForTurn(coveredTerritories, playerID) };
	elseif (isSteps) then
		--the loop has no separate "end" territory to label each step - re-label the center it's circling instead
		StartSpyPlaneStepsFlight(game, path, playerID, centerTerritoryID, inclusionGenerosity, addNewOrder);
	end

	addNewOrder(event);
end

---Flies a Spy Plane along the multi-waypoint route through territoryIDs (in order) - depending on the configured
---flight style, either grants the player vision of the whole route for this turn (Instant), or kicks off a Steps
---flight the same way SpyPlaneApplication.FlySpyPlane does.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
---@param playerID PlayerID
---@param territoryIDs TerritoryID[] # At least 2 territories, in travel order
---@param message string # Shown in the order list for the resulting event
function SpyPlaneApplication.FlySpyPlanePath(game, addNewOrder, playerID, territoryIDs, message)
	local maxFlightDistance = Mod.Settings.SpyPlaneMaxFlightDistance or 300;
	local inclusionGenerosity = Mod.Settings.SpyPlaneInclusionGenerosity or 50;

	local waypoints = {};
	for _, territoryID in ipairs(territoryIDs) do
		local td = game.Map.Territories[territoryID];
		table.insert(waypoints, { X = td.MiddlePointX, Y = td.MiddlePointY });
	end

	local startTerritoryID = territoryIDs[1];
	local endTerritoryID = territoryIDs[#territoryIDs];
	local startTd = game.Map.Territories[startTerritoryID];
	local endTd = game.Map.Territories[endTerritoryID];
	local event = WL.GameOrderEvent.Create(playerID, message, {}, {});
	event.JumpToActionSpotOpt = WL.RectangleVM.Create(startTd.MiddlePointX, startTd.MiddlePointY, endTd.MiddlePointX, endTd.MiddlePointY);

	--in Steps (Distance-based or Segment-based), the first step's own event (via AdvanceSpyPlaneFlightStep)
	--already labels the plane's starting position via its isFirstStep annotation, so a separate
	--"Spy Plane Start" annotation here would be redundant
	local isSteps = Mod.Settings.SpyPlaneFlightStyleSteps;
	local annotations = {
		[endTerritoryID] = WL.TerritoryAnnotation.Create("Spy Plane End", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Charcoal)),
	};
	if (not isSteps) then
		annotations[startTerritoryID] = WL.TerritoryAnnotation.Create("Spy Plane Start", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Charcoal));
	end
	event.TerritoryAnnotationsOpt = annotations;

	local path = Flight.Clamp(Flight.NewPolylinePath(waypoints), maxFlightDistance);

	if (Mod.Settings.SpyPlaneFlightStyleInstant) then
		local coveredTerritories = Flight.GetTerritoriesAlongPath(game, path, inclusionGenerosity);
		event.FogModsOpt = { GrantSpyPlaneVisionForTurn(coveredTerritories, playerID) };
	elseif (isSteps) then
		StartSpyPlaneStepsFlight(game, path, playerID, endTerritoryID, inclusionGenerosity, addNewOrder);
	end

	addNewOrder(event);
end

---Advances every Distance-based Steps Spy Plane flight still in progress by one more step, granting vision of the
---next strip of territories for this turn. Flights that reach their end are dropped from the active list.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function SpyPlaneApplication.AdvanceActiveSpyPlaneFlights(game, addNewOrder)
	local activeFlights = (Mod.PrivateGameData --[[@as SpyPlanePrivateGameData]]).ActiveSpyPlaneFlights;
	if (activeFlights == nil or #activeFlights == 0) then return; end;

	local inclusionGenerosity = Mod.Settings.SpyPlaneInclusionGenerosity or 50;
	local remainingFlights = {};
	for _, flight in ipairs(activeFlights) do
		--AdvanceSpyPlaneFlightStep (via GrantSpyPlaneVisionForTurn) does its own read-modify-write of
		--Mod.PrivateGameData for PendingSpyPlaneVisionFogModIDs, so we must not hold a snapshot of it across this
		--loop - re-read fresh below instead of writing back a copy taken before the loop ran
		AdvanceSpyPlaneFlightStep(game, flight, inclusionGenerosity, addNewOrder);

		if (flight.Progress.DistanceCovered < flight.Progress.Path.TotalLength) then
			table.insert(remainingFlights, flight);
		end
	end

	local priv = Mod.PrivateGameData --[[@as SpyPlanePrivateGameData]];
	priv.ActiveSpyPlaneFlights = (#remainingFlights > 0) and remainingFlights or nil;
	Mod.PrivateGameData = priv;
end

---Removes any Spy Plane vision FogMods granted last turn, so each turn's vision (whether from Instant or a single
---Distance-based Steps step) lasts exactly one turn - mirrors OrderNeutral's RemoveExpiredVisionFogMods.
---@param addNewOrder fun(order: GameOrder)
function SpyPlaneApplication.RemoveExpiredSpyPlaneVisionFogMods(addNewOrder)
	local priv = Mod.PrivateGameData --[[@as SpyPlanePrivateGameData]];
	local pendingIDs = priv.PendingSpyPlaneVisionFogModIDs;
	if (pendingIDs == nil or #pendingIDs == 0) then return; end;

	local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, "Spy Plane vision expired", {}, {});
	event.RemoveFogModsOpt = pendingIDs;
	addNewOrder(event);

	priv.PendingSpyPlaneVisionFogModIDs = nil;
	Mod.PrivateGameData = priv;
end
