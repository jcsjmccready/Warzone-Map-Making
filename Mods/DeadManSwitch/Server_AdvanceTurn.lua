require("Utilities");
require("IO.ModAuth");
require("Api");
require("Application");

---Server_AdvanceTurn_Start hook.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Start(game, addNewOrder)
    IO.ModAuth.Reset(); -- guarantees auth tokens are reset
end

---Server_AdvanceTurn_Order
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl)
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
    -- authenticated orders, whether self-sent below or sent by another mod via IO.ModAuth.Send - see Api.lua
    if (DeadManSwitchApi.HandleOrder(order, game, addNewOrder, skipThisOrder)) then
        return;
    end

    if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, "CreateDMS_")) then
        local targetTerritoryID = tonumber(string.sub(order.ModData, 11));
        DeadManSwitchApplication.QueueDeadManSwitchBuild(order.PlayerID, targetTerritoryID, order.Description);
        return;
    end

    if (order.proxyType == 'GameOrderCustom' and startsWith(order.Payload, "CreateDMS_")) then
        local targetTerritoryID = tonumber(string.sub(order.Payload, 11));
        DeadManSwitchApplication.QueueDeadManSwitchBuild(order.PlayerID, targetTerritoryID, order.Message);
        return;
    end

    -- a successful attack against a territory protected by a Dead Man's Switch
    if (order.proxyType == 'GameOrderAttackTransfer' and result.IsAttack and result.IsSuccessful) then
        local structureID = WL.StructureType.Custom("Dead Man's Switch");
        local existingStructures = game.ServerGame.LatestTurnStanding.Territories[order.To].Structures;
        if (existingStructures == nil) then return; end;

        local numberOfDMS = existingStructures[structureID] or 0;
        if (numberOfDMS == 0) then return; end; --no DMS here, abort

        if (result.ActualArmies.IsEmpty) then return; end; --an attack of 0, abort, so skipped orders don't destroy the DMS

        -- abort if on same team and ally triggers is disabled
        local territoryOwnerPlayerID = game.ServerGame.LatestTurnStanding.Territories[order.To].OwnerPlayerID;
        local attackerTeam = game.ServerGame.Game.Players[order.PlayerID].Team;
        local ownerTeam = WL.PlayerID.Neutral;
        if (game.ServerGame.Game.Players[territoryOwnerPlayerID] ~= nil) then
            ownerTeam = game.ServerGame.Game.Players[territoryOwnerPlayerID].Team;
        end

        if (attackerTeam ~= nil and ownerTeam ~= nil and attackerTeam ~= -1 and ownerTeam ~= -1 and attackerTeam == ownerTeam and Mod.Settings.AllyTriggers == false) then
            return;
        end;

        ---@type DeadManSwitchTriggerDeadManSwitchDto
        local data = {
            Action = DeadManSwitchActions.TriggerDeadManSwitch,
            TerritoryID = order.To,
            AttackerPlayerID = order.PlayerID,
            ArmiesOnArrival = result.ActualArmies.NumArmies - result.AttackingArmiesKilled.NumArmies,
            NumSwitches = numberOfDMS,
        };
        DeadManSwitchApplication.TriggerDeadManSwitch(game, addNewOrder, data);
        return;
    end
end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_End(game, addNewOrder)
    DeadManSwitchApplication.BuildQueuedDeadManSwitches(game, addNewOrder);
    DeadManSwitchApplication.PlayPendingBlockades(addNewOrder);
    DeadManSwitchApplication.PlayPendingDiplomacy(addNewOrder);
end
