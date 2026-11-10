require("Flight.Flight");

----------------------------------------------------------------------------------------------------------------------
-- Generic, mod-agnostic path-shape machinery. This file should never need project-specific changes - copy it
-- as-is into any mod's Flight/ folder that wants multi-step flight/path behaviour, alongside Progress.lua and
-- Territory.lua. A path is always finite (a Loop is one full circle, so it has a finite circumference) and only
-- describes shape - what a mod does with the territories a path passes over is entirely up to that mod.
----------------------------------------------------------------------------------------------------------------------

---@enum FlightPathType
Flight.PathType = {
	Polyline = "Polyline",
	Loop = "Loop",
};

---@class FlightPoint
---@field X number
---@field Y number

---@class FlightPath
---@field Type FlightPathType
---@field TotalLength number # Total arc length of the path, in map units
---@field Waypoints FlightPoint[] | nil # Polyline only - at least 2 points, in travel order
---@field CumulativeLengths number[] | nil # Polyline only - CumulativeLengths[i] is the distance from Waypoints[1] to Waypoints[i]
---@field CenterX number | nil # Loop only
---@field CenterY number | nil # Loop only
---@field Radius number | nil # Loop only
---@field StartAngleRadians number | nil # Loop only - the angle (from CenterX/CenterY) the loop starts and ends at

---Max angular step used when a Loop path is approximated as a sequence of straight points (for territory distance
---checks, which treat consecutive points as a straight sub-segment). Small enough to keep that approximation close
---to the true arc.
local MAX_LOOP_SAMPLE_ANGLE_RADIANS = math.pi / 12; -- 15 degrees

---@param path FlightPath
---@param distance number
---@return number # distance clamped to [0, path.TotalLength]
local function ClampDistance(path, distance)
	return math.max(0, math.min(path.TotalLength, distance));
end

---@param path FlightPath # Type == Polyline
---@param distance number
---@return FlightPoint
local function PolylinePointAt(path, distance)
	distance = ClampDistance(path, distance);
	local waypoints = path.Waypoints --[[@as FlightPoint[] ]];
	local cumulativeLengths = path.CumulativeLengths --[[@as number[] ]];

	for i = 2, #waypoints do
		if (distance <= cumulativeLengths[i]) then
			local legLength = cumulativeLengths[i] - cumulativeLengths[i - 1];
			local t = (legLength > 0) and ((distance - cumulativeLengths[i - 1]) / legLength) or 0;
			local a = waypoints[i - 1];
			local b = waypoints[i];
			return { X = a.X + t * (b.X - a.X), Y = a.Y + t * (b.Y - a.Y) };
		end
	end

	return waypoints[#waypoints];
end

---@param path FlightPath # Type == Loop
---@param distance number
---@return FlightPoint
local function LoopPointAt(path, distance)
	distance = ClampDistance(path, distance);
	local angle = (path.StartAngleRadians or 0) + (distance / (path.Radius --[[@as number]]));
	return {
		X = (path.CenterX --[[@as number]]) + (path.Radius --[[@as number]]) * math.cos(angle),
		Y = (path.CenterY --[[@as number]]) + (path.Radius --[[@as number]]) * math.sin(angle),
	};
end

---@param path FlightPath # Type == Polyline
---@param distanceA number # Already clamped to [0, path.TotalLength]
---@param distanceB number # Already clamped to [0, path.TotalLength], >= distanceA
---@return FlightPoint[]
local function PolylinePointsBetween(path, distanceA, distanceB)
	local cumulativeLengths = path.CumulativeLengths --[[@as number[] ]];
	local waypoints = path.Waypoints --[[@as FlightPoint[] ]];

	local points = { PolylinePointAt(path, distanceA) };

	for i = 2, #waypoints - 1 do
		local cumulativeLength = cumulativeLengths[i];
		if (cumulativeLength > distanceA and cumulativeLength < distanceB) then
			table.insert(points, waypoints[i]);
		end
	end

	table.insert(points, PolylinePointAt(path, distanceB));
	return points;
end

---@param path FlightPath # Type == Loop
---@param distanceA number # Already clamped to [0, path.TotalLength]
---@param distanceB number # Already clamped to [0, path.TotalLength], >= distanceA
---@return FlightPoint[]
local function LoopPointsBetween(path, distanceA, distanceB)
	local span = distanceB - distanceA;
	local angleSpan = span / (path.Radius --[[@as number]]);
	local sampleCount = math.max(1, math.ceil(math.abs(angleSpan) / MAX_LOOP_SAMPLE_ANGLE_RADIANS));

	local points = {};
	for i = 0, sampleCount do
		table.insert(points, LoopPointAt(path, distanceA + span * (i / sampleCount)));
	end
	return points;
end

---Builds a straight multi-waypoint path (A->B->C->D, or just A->B).
---@param waypoints FlightPoint[] # At least 2 points, in travel order
---@return FlightPath
function Flight.NewPolylinePath(waypoints)
	local cumulativeLengths = { [1] = 0 };
	for i = 2, #waypoints do
		local a = waypoints[i - 1];
		local b = waypoints[i];
		local legLength = math.sqrt((b.X - a.X) ^ 2 + (b.Y - a.Y) ^ 2);
		cumulativeLengths[i] = cumulativeLengths[i - 1] + legLength;
	end

	---@type FlightPath
	return {
		Type = Flight.PathType.Polyline,
		TotalLength = cumulativeLengths[#cumulativeLengths],
		Waypoints = waypoints,
		CumulativeLengths = cumulativeLengths,
	};
end

---Builds a path describing a single full loop (one circle) around (centerX, centerY).
---@param centerX number
---@param centerY number
---@param radius number
---@param startAngleRadiansOpt number | nil # Defaults to 0
---@return FlightPath
function Flight.NewLoopPath(centerX, centerY, radius, startAngleRadiansOpt)
	---@type FlightPath
	return {
		Type = Flight.PathType.Loop,
		TotalLength = 2 * math.pi * radius,
		CenterX = centerX,
		CenterY = centerY,
		Radius = radius,
		StartAngleRadians = startAngleRadiansOpt or 0,
	};
end

---Returns a new path truncated to at most maxLength (cutting the final leg/arc short), or path unchanged if it's
---already within maxLength.
---@param path FlightPath
---@param maxLength number
---@return FlightPath
function Flight.Clamp(path, maxLength)
	if (path.TotalLength <= maxLength) then
		return path;
	end

	if (path.Type == Flight.PathType.Loop) then
		---@type FlightPath
		return {
			Type = Flight.PathType.Loop,
			TotalLength = maxLength,
			CenterX = path.CenterX,
			CenterY = path.CenterY,
			Radius = path.Radius,
			StartAngleRadians = path.StartAngleRadians,
		};
	end

	local clampedWaypoint = PolylinePointAt(path, maxLength);
	local waypoints = {};
	local cumulativeLengths = {};
	for i, cumulativeLength in ipairs(path.CumulativeLengths --[[@as number[] ]]) do
		if (cumulativeLength >= maxLength) then
			table.insert(waypoints, clampedWaypoint);
			table.insert(cumulativeLengths, maxLength);
			break;
		end
		table.insert(waypoints, (path.Waypoints --[[@as FlightPoint[] ]])[i]);
		table.insert(cumulativeLengths, cumulativeLength);
	end

	---@type FlightPath
	return {
		Type = Flight.PathType.Polyline,
		TotalLength = maxLength,
		Waypoints = waypoints,
		CumulativeLengths = cumulativeLengths,
	};
end

---Returns the single point at the given distance along path.
---@param path FlightPath
---@param distance number
---@return FlightPoint
function Flight.PointAt(path, distance)
	if (path.Type == Flight.PathType.Loop) then
		return LoopPointAt(path, distance);
	end
	return PolylinePointAt(path, distance);
end

---Returns the ordered points describing path's shape between distanceA and distanceB. A Polyline leg returns just
---its two endpoints (plus any waypoint(s) strictly between them); a Loop returns enough intermediate points to
---approximate its curvature. Feed the result into Flight.GetTerritoriesNearPoints.
---@param path FlightPath
---@param distanceA number
---@param distanceB number # >= distanceA
---@return FlightPoint[]
function Flight.PointsBetween(path, distanceA, distanceB)
	distanceA = ClampDistance(path, distanceA);
	distanceB = ClampDistance(path, distanceB);

	if (path.Type == Flight.PathType.Loop) then
		return LoopPointsBetween(path, distanceA, distanceB);
	end

	return PolylinePointsBetween(path, distanceA, distanceB);
end
