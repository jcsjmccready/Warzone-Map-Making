require("Flight.Flight");
require("Flight.Path");

----------------------------------------------------------------------------------------------------------------------
-- Generic, mod-agnostic territory-sampling machinery. This file should never need project-specific changes - copy
-- it as-is into any mod's Flight/ folder, alongside Path.lua and Progress.lua.
----------------------------------------------------------------------------------------------------------------------

---Returns the TerritoryIDs of every territory on the map whose centerpoint falls within maxDistanceFromLine of the
---connected point-chain points[1]->points[2]->...->points[n] (a "thick line" from a birds eye view - adjacency is
---not considered at all, only literal on-map distance to the nearest sub-segment).
---@param game GameServerHook | GameClientHook
---@param points FlightPoint[] # At least 2 points
---@param maxDistanceFromLine number
---@return TerritoryID[]
function Flight.GetTerritoriesNearPoints(game, points, maxDistanceFromLine)
	local covered = {};

	for territoryID, territoryDetails in pairs(game.Map.Territories) do
		local px, py = territoryDetails.MiddlePointX, territoryDetails.MiddlePointY;

		local isCovered = false;
		for i = 2, #points do
			local a = points[i - 1];
			local b = points[i];
			local abx, aby = b.X - a.X, b.Y - a.Y;
			local abLengthSquared = abx * abx + aby * aby;

			--project the territory's centerpoint onto the sub-segment, clamped to the sub-segment itself (not the
			--infinite line)
			local t = 0;
			if (abLengthSquared > 0) then
				local apx, apy = px - a.X, py - a.Y;
				t = math.max(0, math.min(1, (apx * abx + apy * aby) / abLengthSquared));
			end

			local closestX = a.X + t * abx;
			local closestY = a.Y + t * aby;
			local dx, dy = px - closestX, py - closestY;
			local distanceFromLine = math.sqrt(dx * dx + dy * dy);

			if (distanceFromLine <= maxDistanceFromLine) then
				isCovered = true;
				break;
			end
		end

		if (isCovered) then
			table.insert(covered, territoryID);
		end
	end

	return covered;
end

---Returns the TerritoryID of whichever territory on the map has its centerpoint closest to (x, y).
---@param game GameServerHook | GameClientHook
---@param x number
---@param y number
---@return TerritoryID
function Flight.FindNearestTerritory(game, x, y)
	local nearestTerritoryID = nil;
	local nearestDistanceSquared = nil;

	for territoryID, territoryDetails in pairs(game.Map.Territories) do
		local dx, dy = territoryDetails.MiddlePointX - x, territoryDetails.MiddlePointY - y;
		local distanceSquared = dx * dx + dy * dy;

		if (nearestDistanceSquared == nil or distanceSquared < nearestDistanceSquared) then
			nearestTerritoryID = territoryID;
			nearestDistanceSquared = distanceSquared;
		end
	end

	return nearestTerritoryID;
end

---Samples the entire path in one call - the client-preview entry point (e.g. highlighting the whole flight while
---the player is still picking territories), as opposed to Flight.Advance's turn-by-turn stepping.
---@param game GameServerHook | GameClientHook
---@param path FlightPath
---@param maxDistanceFromLine number
---@return TerritoryID[]
function Flight.GetTerritoriesAlongPath(game, path, maxDistanceFromLine)
	local points = Flight.PointsBetween(path, 0, path.TotalLength);
	return Flight.GetTerritoriesNearPoints(game, points, maxDistanceFromLine);
end
