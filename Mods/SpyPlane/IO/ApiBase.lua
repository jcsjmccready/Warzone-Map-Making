require("IO.ModAuth");

----------------------------------------------------------------------------------------------------------------------
-- Generic, mod-agnostic machinery for exposing a ModAuth API. This file should never need project-specific changes -
-- copy it as-is into any mod's IO/ folder that wants to expose authenticated actions to other mods, then build that
-- mod's own Api.lua on top of it: create one instance with IO.ApiBase.New(), then for each action, define a handler
-- function and Register() it. See Mods/BombShelter/Api.lua for a worked example.
----------------------------------------------------------------------------------------------------------------------

IO.ApiBase = {};

---@class ModAuthFieldSpec # One field's presence/type requirement, checked against an endpoint's data table
---@field Name string # The field's key in the data table
---@field Type string # Expected result of Lua's type(), e.g. "number", "string", "boolean"
---@field Required boolean # If false, the field is only checked when present (nil is allowed)

---@class ModAuthApi
---@field ModKey ModKey # This mod's own IO.ModAuth.LOCAL_MOD_KEY, shown in rejection/unrecognized-action messages
---@field Endpoints table<string, fun(data: table, order: GameOrderCustom, game: GameServerHook, addNewOrder: fun(order: GameOrder))>
---@field Register fun(action: string, handler: fun(data: table, order: GameOrderCustom, game: GameServerHook, addNewOrder: fun(order: GameOrder))) # Registers a handler for one action
---@field ValidateFields fun(action: string, data: table, order: GameOrderCustom, addNewOrder: fun(order: GameOrder), fieldSpecs: ModAuthFieldSpec[]): boolean # See IO.ApiBase.New
---@field HandleOrder fun(order: GameOrder, game: GameServerHook, addNewOrder: fun(order: GameOrder), skipThisOrder: fun(modOrderControl: EnumModOrderControl)): boolean # See IO.ApiBase.New

---Creates a new API instance for this mod, keyed by its own IO.ModAuth.LOCAL_MOD_KEY. Call Register() once per action
---the mod exposes (right after defining its handler), then route every order from Server_AdvanceTurn_Order through the
---result's HandleOrder first.
---@return ModAuthApi
function IO.ApiBase.New()
    local modKey = IO.ModAuth.LOCAL_MOD_KEY;

    ---@type ModAuthApi
    local api = { ModKey = modKey, Endpoints = {} };

    function api.Register(action, handler)
        api.Endpoints[action] = handler;
    end

    -- Checks data against fieldSpecs and, if anything's missing or the wrong type, emits an event telling the sender
    -- (visible to the order's player) exactly what was wrong instead of silently doing nothing.
    function api.ValidateFields(action, data, order, addNewOrder, fieldSpecs)
        local errors = {};
        for _, fieldSpec in ipairs(fieldSpecs) do
            local value = data[fieldSpec.Name];
            if (value == nil) then
                if (fieldSpec.Required) then
                    table.insert(errors, fieldSpec.Name .. " is required");
                end
            elseif (type(value) ~= fieldSpec.Type) then
                table.insert(errors, fieldSpec.Name .. " must be a " .. fieldSpec.Type .. ", got " .. type(value));
            end
        end

        if (#errors > 0) then
            local message = modKey .. " rejected " .. action .. ": " .. table.concat(errors, "; ");
            addNewOrder(WL.GameOrderEvent.Create(WL.PlayerID.Neutral, message, { order.PlayerID }, {}));
            return false;
        end

        return true;
    end

    function api.HandleOrder(order, game, addNewOrder, skipThisOrder)
        return IO.ModAuth.ProcessOrder(
            order,
            addNewOrder,
            skipThisOrder,
            function(senderModKey, data, authenticatedOrder)
                local endpoint = api.Endpoints[data.Action];
                if (endpoint ~= nil) then
                    endpoint(data, authenticatedOrder, game, addNewOrder);
                else --404
                    local message = modKey .. " received an unrecognized action '" .. tostring(data.Action) .. "' from " .. tostring(senderModKey);
                    addNewOrder(WL.GameOrderEvent.Create(WL.PlayerID.Neutral, message, { authenticatedOrder.PlayerID }, {}));
                end
            end
        );
    end

    return api;
end
