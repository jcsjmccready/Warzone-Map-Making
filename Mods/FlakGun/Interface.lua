---@enum FlakGunAction
FlakGunActions = {
	FireFlakGun = "FireFlakGun",
};

---Fires a Flak Gun at a territory for the remainder of the turn, intercepting airlifts through its area of
---effect per the mod's configured damage options. Never starts a card-rounds streak (only playing the actual
---card does that).
---@class FlakGunFireFlakGunDto
---@field Action "FireFlakGun"
---@field TerritoryID TerritoryID # Required. The territory to fire the Flak Gun at.
