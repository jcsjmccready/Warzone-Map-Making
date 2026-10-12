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

DeadManSwitchApi = IO.ApiBase.New();

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
