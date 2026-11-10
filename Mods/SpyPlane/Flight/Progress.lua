require("Flight.Flight");
require("Flight.Path");

----------------------------------------------------------------------------------------------------------------------
-- Generic, mod-agnostic step-progression machinery. This file should never need project-specific changes - copy
-- it as-is into any mod's Flight/ folder, alongside Path.lua and Territory.lua. A FlightProgress is the one
-- self-contained record a mod persists per active flight (e.g. in its own Mod.PrivateGameData) across turns -
-- plain data only, safe to round-trip through PrivateGameData like anything else stored there.
----------------------------------------------------------------------------------------------------------------------

---@class FlightProgress # One flight's progress along its path - store this per active flight, pass it to Flight.Advance
---@field Path FlightPath
---@field StepDistance number # Fixed at creation, baked into the record so later Advance calls can't drift from a different setting
---@field DistanceCovered number # Starts at 0

---@class FlightStepResult
---@field Points FlightPoint[] # Points covering the step just taken (feed into Flight.GetTerritoriesNearPoints)
---@field IsComplete boolean # True once DistanceCovered has reached Path.TotalLength

---@param path FlightPath
---@param stepDistance number
---@return FlightProgress
function Flight.NewProgress(path, stepDistance)
	return {
		Path = path,
		StepDistance = stepDistance,
		DistanceCovered = 0,
	};
end

---Advances progress by its StepDistance (clamped to the path's remaining length), mutating progress.DistanceCovered
---in place, and returns the points covering the step just taken.
---@param progress FlightProgress
---@return FlightStepResult
function Flight.Advance(progress)
	local stepStart = progress.DistanceCovered;
	local stepEnd = math.min(progress.Path.TotalLength, stepStart + progress.StepDistance);

	local points = Flight.PointsBetween(progress.Path, stepStart, stepEnd);
	progress.DistanceCovered = stepEnd;

	return {
		Points = points,
		IsComplete = progress.DistanceCovered >= progress.Path.TotalLength,
	};
end

---Returns the step distance so the path completes in at least minSteps steps of at most maxDistancePerStep each -
---e.g. so a path's start and end are never collapsed into a single step (minSteps defaults to 2).
---@param totalLength number
---@param maxDistancePerStep number
---@param minStepsOpt integer | nil # Defaults to 2
---@return number stepDistance
function Flight.ComputeStepDistance(totalLength, maxDistancePerStep, minStepsOpt)
	local minSteps = minStepsOpt or 2;
	if (maxDistancePerStep <= 0) then
		return totalLength / minSteps;
	end

	local stepCount = math.max(minSteps, math.ceil(totalLength / maxDistancePerStep));
	return totalLength / stepCount;
end
