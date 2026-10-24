---@enum DeadManSwitchAction
DeadManSwitchActions = {
    AddDeadManSwitch = "AddDeadManSwitch",
    TriggerDeadManSwitch = "TriggerDeadManSwitch",
    DestroyDeadManSwitch = "DestroyDeadManSwitch",
};

---Builds a Dead Man's Switch on a territory. End of turn by default
---@class DeadManSwitchAddDeadManSwitchDto
---@field Action "AddDeadManSwitch"
---@field TerritoryID TerritoryID # Required. The territory to build on.
---@field IsImmediate boolean | nil # Optional. Defaults to false (queued for end of turn, the standard behaviour).

---@class DeadManSwitchTriggerDeadManSwitchDto
---@field Action "TriggerDeadManSwitch"
---@field TerritoryID TerritoryID # Required. The territory being captured/triggered.
---@field AttackerPlayerID PlayerID # Required. The player who captured the territory and is on the receiving end of the retaliation effects.
---@field ArmiesOnArrival integer # Required. Armies left on the territory immediately after the capture, before any Dead Man's Switch damage. Used by the flat/percent damage types.
---@field NumSwitches integer | nil # Optional. Defaults to however many Dead Man's Switch instances are on the territory.

---Removes one Dead Man's Switch instance on a territory outright
---@class DeadManSwitchDestroyDeadManSwitchDto
---@field Action "DestroyDeadManSwitch"
---@field TerritoryID TerritoryID # Required. The territory to destroy a switch on.
