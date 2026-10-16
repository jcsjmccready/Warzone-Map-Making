require("Utilities");
require("Application");

---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl)
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
    if (Mod.Settings.DisableAIMovements and order.proxyType == 'GameOrderAttackTransfer') then
        local player = game.Game.Players[order.PlayerID];
        if (player ~= nil and player.IsAIOrHumanTurnedIntoAI) then
            skipThisOrder(WL.ModOrderControl.Skip);
            return;
        end
    end

    if (order.proxyType ~= 'GameOrderCustom') then return; end
    ---@cast order GameOrderCustom

    local structureName, buildTerritoryID = ParsePlanningPayload(order.Payload);
    if (structureName ~= nil) then
        CustomScenarioBuilderModOrchestratorApplication.AddVanillaStructure(game, addNewOrder, order.PlayerID, structureName, buildTerritoryID);
        return;
    end

    local deleteType, deleteTerritoryID, deleteIdentifier = ParseDeletePayload(order.Payload);
    if (deleteType == "Structure") then
        CustomScenarioBuilderModOrchestratorApplication.RemoveStructure(game, addNewOrder, order.PlayerID, deleteTerritoryID, deleteIdentifier);
        return;
    elseif (deleteType == "SpecialUnit") then
        CustomScenarioBuilderModOrchestratorApplication.RemoveSpecialUnit(game, addNewOrder, order.PlayerID, deleteTerritoryID, deleteIdentifier);
        return;
    end

    local moveType, fromTerritoryID, toTerritoryID, moveIdentifier = ParseMovePayload(order.Payload);
    if (moveType == "Structure") then
        CustomScenarioBuilderModOrchestratorApplication.MoveStructure(game, addNewOrder, order.PlayerID, fromTerritoryID, toTerritoryID, moveIdentifier);
        return;
    elseif (moveType == "SpecialUnit") then
        CustomScenarioBuilderModOrchestratorApplication.MoveSpecialUnit(game, addNewOrder, order.PlayerID, fromTerritoryID, toTerritoryID, moveIdentifier);
        return;
    end

    local cloneType, cloneTerritoryID, cloneIdentifier = ParseClonePayload(order.Payload);
    if (cloneType == "Structure") then
        CustomScenarioBuilderModOrchestratorApplication.CloneStructure(game, addNewOrder, order.PlayerID, cloneTerritoryID, cloneIdentifier);
    elseif (cloneType == "SpecialUnit") then
        CustomScenarioBuilderModOrchestratorApplication.CloneSpecialUnit(game, addNewOrder, order.PlayerID, cloneTerritoryID, cloneIdentifier);
    end
end
