require("Utilities");
require("Application");

---Server_AdvanceTurn_Order hook. Builds a vanilla structure directly onto standing when a Planning Mode build
---order (queued via the in-game mod menu) is processed.
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl)
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
    if (order.proxyType ~= 'GameOrderCustom') then return; end
    ---@cast order GameOrderCustom

    local structureName, buildTerritoryID = ParsePlanningPayload(order.Payload);
    if (structureName ~= nil) then
        CustomScenarioBuilderModOrchestratorApplication.AddVanillaStructure(game, addNewOrder, order.PlayerID, structureName, buildTerritoryID);
        return;
    end

    local kind, deleteTerritoryID, identifier = ParseDeletePayload(order.Payload);
    if (kind == "Structure") then
        CustomScenarioBuilderModOrchestratorApplication.RemoveStructure(game, addNewOrder, order.PlayerID, deleteTerritoryID, identifier);
    elseif (kind == "SpecialUnit") then
        CustomScenarioBuilderModOrchestratorApplication.RemoveSpecialUnit(game, addNewOrder, order.PlayerID, deleteTerritoryID, identifier);
    end
end
