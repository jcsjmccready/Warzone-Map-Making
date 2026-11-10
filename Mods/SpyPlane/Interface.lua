---@enum SpyPlaneAction
SpyPlaneActions = {
	FlySpyPlane = "FlySpyPlane",
};

---Flies a Spy Plane along the line between two territories, granting vision of the territories it passes near
---per the mod's configured flight style (Instant or Distance-based Steps).
---@class SpyPlaneFlySpyPlaneDto
---@field Action "FlySpyPlane"
---@field StartTerritoryID TerritoryID # Required. The territory the flight starts from.
---@field EndTerritoryID TerritoryID # Required. The territory the flight ends at.
