require("IO.ModAuth");
require("IO.ApiBase");
require("Application");

----------------------------------------------------------------------------------------------------------------------
-- Dead Man's Switch's public ModAuth API
--
-- To call any action below, send a ModAuth order such as the below:
--   IO.ModAuth.Send(IO.ModAuth.LOCAL_MOD_KEY for targetted mod, playerID, data, addNewOrder);
-- e.g. for DeadManSwitchTriggerDeadManSwitchDto: data = { Action = DeadManSwitchActions.TriggerDeadManSwitch, TerritoryID = 4, AttackerPlayerID = 2, ArmiesOnArrival = 6 }.
----------------------------------------------------------------------------------------------------------------------

DEAD_MAN_SWITCH_API_VERSION = 1;

---@enum DeadManSwitchAction
DeadManSwitchActions = {
    AddDeadManSwitch = "AddDeadManSwitch",
    TriggerDeadManSwitch = "TriggerDeadManSwitch",
    DestroyDeadManSwitch = "DestroyDeadManSwitch",
};

DeadManSwitchApi = IO.ApiBase.New();

---Builds a Dead Man's Switch on a territory. End of turn by default
---@class DeadManSwitchAddDeadManSwitchDto
---@field Action "AddDeadManSwitch"
---@field TerritoryID TerritoryID # Required. The territory to build on.
---@field IsImmediate boolean | nil # Optional. Defaults to false (queued for end of turn, the standard behaviour).

---@param data DeadManSwitchAddDeadManSwitchDto
---@param order GameOrderCustom
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
local function HandleAddDeadManSwitch(data, order, game, addNewOrder)
    if (not DeadManSwitchApi.ValidateFields(DeadManSwitchActions.AddDeadManSwitch, data, order, addNewOrder, {
        { Name = "TerritoryID", Type = "number", Required = true },
        { Name = "IsImmediate", Type = "boolean", Required = false },
    })) then return; end;

    if (data.IsImmediate) then
        DeadManSwitchApplication.AddDeadManSwitchImmediately(game, addNewOrder, order.PlayerID, data.TerritoryID);
    else
        DeadManSwitchApplication.QueueDeadManSwitchBuild(order.PlayerID, data.TerritoryID, "Built a Dead Man's Switch via another mod");
    end
end
DeadManSwitchApi.Register(DeadManSwitchActions.AddDeadManSwitch, HandleAddDeadManSwitch);

---@class DeadManSwitchTriggerDeadManSwitchDto
---@field Action "TriggerDeadManSwitch"
---@field TerritoryID TerritoryID # Required. The territory being captured/triggered.
---@field AttackerPlayerID PlayerID # Required. The player who captured the territory and is on the receiving end of the retaliation effects.
---@field ArmiesOnArrival integer # Required. Armies left on the territory immediately after the capture, before any Dead Man's Switch damage. Used by the flat/percent damage types.
---@field NumSwitches integer | nil # Optional. Defaults to however many Dead Man's Switch instances are on the territory.

--- Triggers a DMS as if a player had captured the territory
---@param data DeadManSwitchTriggerDeadManSwitchDto
---@param order GameOrderCustom
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
local function HandleTriggerDeadManSwitch(data, order, game, addNewOrder)
    if (not DeadManSwitchApi.ValidateFields(DeadManSwitchActions.TriggerDeadManSwitch, data, order, addNewOrder, {
        { Name = "TerritoryID", Type = "number", Required = true },
        { Name = "AttackerPlayerID", Type = "number", Required = true },
        { Name = "ArmiesOnArrival", Type = "number", Required = true },
        { Name = "NumSwitches", Type = "number", Required = false },
    })) then return; end;

    DeadManSwitchApplication.TriggerDeadManSwitch(game, addNewOrder, data);
end
DeadManSwitchApi.Register(DeadManSwitchActions.TriggerDeadManSwitch, HandleTriggerDeadManSwitch);

---Removes one Dead Man's Switch instance on a territory outright
---@class DeadManSwitchDestroyDeadManSwitchDto
---@field Action "DestroyDeadManSwitch"
---@field TerritoryID TerritoryID # Required. The territory to destroy a switch on.

---@param data DeadManSwitchDestroyDeadManSwitchDto
---@param order GameOrderCustom
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
local function HandleDestroyDeadManSwitch(data, order, game, addNewOrder)
    if (not DeadManSwitchApi.ValidateFields(DeadManSwitchActions.DestroyDeadManSwitch, data, order, addNewOrder, {
        { Name = "TerritoryID", Type = "number", Required = true },
    })) then return; end;

    DeadManSwitchApplication.DestroyDeadManSwitch(game, addNewOrder, data);
end
DeadManSwitchApi.Register(DeadManSwitchActions.DestroyDeadManSwitch, HandleDestroyDeadManSwitch);
