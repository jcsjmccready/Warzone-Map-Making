---@enum BarbedWireAction
BarbedWireActions = {
	AddTrap = "AddTrap",
	TriggerTrap = "TriggerTrap",
	ResetTrap = "ResetTrap",
	DestroyTrap = "DestroyTrap",
};

---Queues a trap (Barbed Wire or Caltrop) to be built on a territory at the end of the turn.
---@class BarbedWireAddTrapDto
---@field Action "AddTrap"
---@field TrapKey string # Required. "BarbedWire" | "Caltrop".
---@field TerritoryID TerritoryID # Required. The territory to build on.
---@field IsImmediate boolean | nil # Optional. Defaults to false (queued for end of turn, the standard behaviour). When true, bypasses <Prefix>MaxPerPlayer, which only caps Commerce purchases.

---Triggers a trap on a territory, converting any primed pieces of the given type there into triggered ones.
---@class BarbedWireTriggerTrapDto
---@field Action "TriggerTrap"
---@field TrapKey string # Required. "BarbedWire" | "Caltrop".
---@field TerritoryID TerritoryID # Required. The territory to trigger a trap on.

---Resets any triggered trap of the given type on a territory back to primed (or destroys it if that trap type is
---configured as single-use), independent of its normal trigger-duration expiry.
---@class BarbedWireResetTrapDto
---@field Action "ResetTrap"
---@field TrapKey string # Required. "BarbedWire" | "Caltrop".
---@field TerritoryID TerritoryID # Required. The territory to reset a trap on.

---Destroys any Primed/Triggered trap of the given type on a territory outright.
---@class BarbedWireDestroyTrapDto
---@field Action "DestroyTrap"
---@field TrapKey string # Required. "BarbedWire" | "Caltrop".
---@field TerritoryID TerritoryID # Required. The territory to destroy a trap on.
