require("Utilities");
require("Interface");

SpyPlaneApplication = {};

---@class ActiveSpyPlaneFlight # A Distance-based Steps Spy Plane flight still in progress, carried over between turns
---@field PlayerID PlayerID # The player who played the Spy Plane card
---@field StartX number # The X coordinate the flight started from
---@field StartY number # The Y coordinate the flight started from
---@field EndX number # The X coordinate the flight ends at (already pulled in to Mod.Settings.SpyPlaneMaxFlightDistance if needed)
---@field EndY number # The Y coordinate the flight ends at (already pulled in to Mod.Settings.SpyPlaneMaxFlightDistance if needed)
---@field EndTerritoryID TerritoryID # The territory the player originally selected as the flight's destination, annotated on every step
---@field TotalDistance number # The total length of the flight, in map units (already capped to Mod.Settings.SpyPlaneMaxFlightDistance)
---@field StepDistance number # How far each step advances (TotalDistance divided evenly across however many steps the flight needs, always at least 2 so the start and end territories are never collapsed into a single step)
---@field DistanceCovered number # How much of the flight has already been covered by steps granted on previous turns

---@class SpyPlanePrivateGameData
---@field ActiveSpyPlaneFlights ActiveSpyPlaneFlight[] | nil # Distance-based Steps flights still in progress, cleared per-flight once each one reaches its end
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
---it left off, up to flight.StepDistance further along), and advances flight.DistanceCovered to match. Used both
---for a flight's first step (played as part of its own order) and every subsequent step (advanced automatically by
---SpyPlaneApplication.AdvanceActiveSpyPlaneFlights at the start of each of the flight's following turns).
---@param game GameServerHook
---@param flight ActiveSpyPlaneFlight
---@param inclusionGenerosity number
---@param addNewOrder fun(order: GameOrder)
---@param isFirstStep boolean|nil # If true, also annotates the flight's actual starting territory (distinct from this step's current-location annotation, which is based on the step's midpoint and may not match the true start)
local function AdvanceSpyPlaneFlightStep(game, flight, inclusionGenerosity, addNewOrder, isFirstStep)
	local stepStartDistance = flight.DistanceCovered;
	local stepEndDistance = math.min(flight.TotalDistance, flight.DistanceCovered + flight.StepDistance);

	local t0 = (flight.TotalDistance > 0) and (stepStartDistance / flight.TotalDistance) or 0;
	local t1 = (flight.TotalDistance > 0) and (stepEndDistance / flight.TotalDistance) or 1;

	local x0 = flight.StartX + t0 * (flight.EndX - flight.StartX);
	local y0 = flight.StartY + t0 * (flight.EndY - flight.StartY);
	local x1 = flight.StartX + t1 * (flight.EndX - flight.StartX);
	local y1 = flight.StartY + t1 * (flight.EndY - flight.StartY);

	local coveredTerritories = GetTerritoriesNearLineSegment(game, x0, y0, x1, y1, inclusionGenerosity);
	local fogMod = GrantSpyPlaneVisionForTurn(coveredTerritories, flight.PlayerID);

	--label whichever territory is closest to this step's segment as the plane's current position, and re-label
	--the flight's overall destination each step too since annotations don't persist from the turn the card was
	--played (Instant's annotations are a one-time thing, but a Steps flight spans many turns of separate events)
	local midX, midY = (x0 + x1) / 2, (y0 + y1) / 2;
	local nearestTerritoryID = FindNearestTerritory(game, midX, midY);

	local event = WL.GameOrderEvent.Create(flight.PlayerID, "Spy Plane continues its flight", {}, {});
	event.FogModsOpt = { fogMod };
	event.JumpToActionSpotOpt = WL.RectangleVM.Create(x0, y0, x1, y1);

	local annotations = {
		[nearestTerritoryID] = WL.TerritoryAnnotation.Create("Spy Plane", 8, GetColourIntegerFromHex(BUTTON_COLOURS.DarkGray)),
		[flight.EndTerritoryID] = WL.TerritoryAnnotation.Create("Spy Plane End", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Charcoal)),
	};
	if (isFirstStep) then
		local startTerritoryID = FindNearestTerritory(game, flight.StartX, flight.StartY);
		--don't overwrite the current-location annotation if the first step's midpoint already lands on the start territory
		if (startTerritoryID ~= nearestTerritoryID) then
			annotations[startTerritoryID] = WL.TerritoryAnnotation.Create("Spy Plane Start", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Charcoal));
		end
	end
	event.TerritoryAnnotationsOpt = annotations;

	addNewOrder(event);

	flight.DistanceCovered = stepEndDistance;
end

---Flies a Spy Plane along the line between startTerritoryID and endTerritoryID - depending on the configured
---flight style, either grants the player vision of the whole flight line for this turn (Instant), or kicks off a
---Distance-based Steps flight by granting vision of its first step and (if more than one step is needed) queuing
---the rest to be advanced automatically on the player's following turns via
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

	--in Distance-based Steps, the first step's own event (via AdvanceSpyPlaneFlightStep) already labels the
	--plane's starting position via its isFirstStep annotation, so a separate "Spy Plane Start" annotation here
	--would be redundant
	local isDistanceSteps = Mod.Settings.SpyPlaneFlightStyleSteps and Mod.Settings.SpyPlaneStepModeDistance;
	local annotations = {
		[endTerritoryID] = WL.TerritoryAnnotation.Create("Spy Plane End", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Charcoal)),
	};
	if (not isDistanceSteps) then
		annotations[startTerritoryID] = WL.TerritoryAnnotation.Create("Spy Plane Start", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Charcoal));
	end
	event.TerritoryAnnotationsOpt = annotations;

	if (Mod.Settings.SpyPlaneFlightStyleInstant) then
		local coveredTerritories = GetTerritoriesNearLine(game, startTerritoryID, endTerritoryID, inclusionGenerosity, maxFlightDistance);
		event.FogModsOpt = { GrantSpyPlaneVisionForTurn(coveredTerritories, playerID) };
	elseif (Mod.Settings.SpyPlaneFlightStyleSteps and Mod.Settings.SpyPlaneStepModeDistance) then
		local ax, ay, bx, by, totalDistance = GetClampedLineSegment(game, startTerritoryID, endTerritoryID, maxFlightDistance);

		local maxDistancePerStep = Mod.Settings.SpyPlaneMaxDistancePerStep or 200;
		--always at least 2 steps, so the flight's start and end territories are never both revealed in a single step
		local stepCount = math.max(2, math.ceil(totalDistance / maxDistancePerStep));

		---@type ActiveSpyPlaneFlight
		local flight = {
			PlayerID = playerID,
			StartX = ax, StartY = ay,
			EndX = bx, EndY = by,
			EndTerritoryID = endTerritoryID,
			TotalDistance = totalDistance,
			StepDistance = totalDistance / stepCount,
			DistanceCovered = 0,
		};

		--grant this turn's step immediately, same as Instant does for the whole flight, then queue whatever's left
		AdvanceSpyPlaneFlightStep(game, flight, inclusionGenerosity, addNewOrder, true);

		if (flight.DistanceCovered < flight.TotalDistance) then
			local priv = Mod.PrivateGameData --[[@as SpyPlanePrivateGameData]];
			local activeFlights = priv.ActiveSpyPlaneFlights or {};
			table.insert(activeFlights, flight);
			priv.ActiveSpyPlaneFlights = activeFlights;
			Mod.PrivateGameData = priv;
		end
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

		if (flight.DistanceCovered < flight.TotalDistance) then
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
