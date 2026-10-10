require("IO.ModAuth");
require("IO.Api");
require("Application");

----------------------------------------------------------------------------------------------------------------------
-- BombShelter's public ModAuth API
--
-- To call any action below, send a ModAuth order such as the below:
--   IO.ModAuth.Send(IO.ModAuth.LOCAL_MOD_KEY for targetted mod, playerID, data, addNewOrder);
-- e.g. for BombShelterTriggerBombShelterDto: data = { Action = BombShelterActions.TriggerBombShelter, TerritoryID = 4, ArmiesBefore = 10 }.
----------------------------------------------------------------------------------------------------------------------

BOMB_SHELTER_API_VERSION = 1;

---@enum BombShelterAction
BombShelterActions = {
    AddBombShelter = "AddBombShelter",
    TriggerBombShelter = "TriggerBombShelter",
    DestroyBombShelter = "DestroyBombShelter",
};

BombShelterApi = IO.Api.New();

---Builds a Bomb Shelter on a territory. By default, it's queued and only resolved at the end of the turn, alongside the mod's own card/commerce builds, and
---is subject to the same rules as a normal build (the sending player must still own TerritoryID when the turn ends,
---and the BombShelterMaxPerPlayer cap applies if the mod is configured for Commerce acquisition)
---@class BombShelterAddBombShelterDto
---@field Action "AddBombShelter"
---@field TerritoryID TerritoryID # Required. The territory to build on.
---@field IsImmediate boolean | nil # Optional. Defaults to false (queued for end of turn, the standard behaviour).

---@param data BombShelterAddBombShelterDto
---@param order GameOrderCustom
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
local function HandleAddBombShelter(data, order, game, addNewOrder)
    if (not BombShelterApi.ValidateFields(BombShelterActions.AddBombShelter, data, order, addNewOrder, {
        { Name = "TerritoryID", Type = "number", Required = true },
        { Name = "IsImmediate", Type = "boolean", Required = false },
    })) then return; end;

    if (data.IsImmediate) then
        BombShelterApplication.AddBombShelterImmediately(game, addNewOrder, order.PlayerID, data.TerritoryID);
    else
        BombShelterApplication.QueueBombShelterBuild(order.PlayerID, data.TerritoryID);
    end
end
BombShelterApi.Register(BombShelterActions.AddBombShelter, HandleAddBombShelter);

---Simulates a bomb (or bomb-like effect) hitting a shelter-protected territory, applying the same damage-clamping and
---optional shelter-destruction behaviour as a real Bomb Card. Does nothing if the territory has no Bomb Shelter.
---@class BombShelterTriggerBombShelterDto
---@field Action "TriggerBombShelter"
---@field TerritoryID TerritoryID # Required. The territory being "bombed".
---@field ArmiesBefore integer # Required. Army count on the territory before this bomb's damage, used to work out how much the shelter should claw back or add.
---@field DestroyBombShelter boolean | nil # Optional. Defaults to Mod.Settings.BombShelterDestroyedOnBomb when omitted.
---@field OverriddenPercentage number | nil # Optional. Defaults to Mod.Settings.BombShelterDamagePercent when omitted.

---@param data BombShelterTriggerBombShelterDto
---@param order GameOrderCustom
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
local function HandleTriggerBombShelter(data, order, game, addNewOrder)
    if (not BombShelterApi.ValidateFields(BombShelterActions.TriggerBombShelter, data, order, addNewOrder, {
        { Name = "TerritoryID", Type = "number", Required = true },
        { Name = "ArmiesBefore", Type = "number", Required = true },
        { Name = "DestroyBombShelter", Type = "boolean", Required = false },
        { Name = "OverriddenPercentage", Type = "number", Required = false },
    })) then return; end;

    BombShelterApplication.TriggerBombShelter(game, addNewOrder, data, data.DestroyBombShelter, data.OverriddenPercentage);
end
BombShelterApi.Register(BombShelterActions.TriggerBombShelter, HandleTriggerBombShelter);

---Destroys one Bomb Shelter instance on a territory outright, independent of any bomb damage (e.g. for a mod with its
---own kind of explosive or demolition effect). Does nothing if the territory has no Bomb Shelter.
---@class BombShelterDestroyBombShelterDto
---@field Action "DestroyBombShelter"
---@field TerritoryID TerritoryID # Required. The territory to destroy a shelter on.

---@param data BombShelterDestroyBombShelterDto
---@param order GameOrderCustom
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
local function HandleDestroyBombShelter(data, order, game, addNewOrder)
    if (not BombShelterApi.ValidateFields(BombShelterActions.DestroyBombShelter, data, order, addNewOrder, {
        { Name = "TerritoryID", Type = "number", Required = true },
    })) then return; end;

    BombShelterApplication.DestroyBombShelter(game, addNewOrder, data);
end
BombShelterApi.Register(BombShelterActions.DestroyBombShelter, HandleDestroyBombShelter);
