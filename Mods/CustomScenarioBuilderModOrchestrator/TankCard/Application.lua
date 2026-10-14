require("Utilities");
require("CustomScenarioBuilder");

TankCardApplication = {};

---@class TankCardPendingBuild # One queued build, not yet resolved into an actual Tank
---@field PlayerID PlayerID # The player who queued it, re-checked for ownership at build time
---@field TerritoryID TerritoryID
---@field Message string # Shown in the order list for the build order itself

---@class TankCardPrivateGameData
---@field PendingTanks TankCardPendingBuild[] | nil # Cleared at the end of every turn once BuildQueuedTanks resolves them

---Builds a Tank custom special unit.
---@param ownerID PlayerID
---@return CustomSpecialUnit
function TankCardApplication.BuildTank(ownerID)
    local builder = WL.CustomSpecialUnitBuilder.Create(ownerID);
    builder.Name = TANK_NAME;
    builder.IncludeABeforeName = true;
    builder.ImageFilename = TANK_IMAGE_FILENAME;
    builder.AttackPower = TANK_POWER;
    builder.DefensePower = TANK_POWER;
    builder.CombatOrder = 3415; -- defends commanders
    builder.DamageToKill = TANK_POWER;
    builder.DamageAbsorbedWhenAttacked = TANK_POWER;
    builder.CanBeGiftedWithGiftCard = true;
    builder.CanBeTransferredToTeammate = true;
    builder.CanBeAirliftedToSelf = true;
    builder.CanBeAirliftedToTeammate = true;
    builder.IsVisibleToAllPlayers = false;
    return builder.Build();
end

---Queues a Tank to be built on the target territory at the end of the turn.
---@param playerID PlayerID
---@param targetTerritoryID TerritoryID
---@param message string # Shown in the order list for the eventual build order
function TankCardApplication.QueueTankBuild(playerID, targetTerritoryID, message)
    local priv = Mod.PrivateGameData --[[@as TankCardPrivateGameData]];
    local pending = priv.PendingTanks or {};

    table.insert(pending, {
        PlayerID = playerID,
        TerritoryID = targetTerritoryID,
        Message = message,
    });

    priv.PendingTanks = pending;
    Mod.PrivateGameData = priv;
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function TankCardApplication.BuildQueuedTanks(game, addNewOrder)
    local priv = Mod.PrivateGameData --[[@as TankCardPrivateGameData]];
    local pending = priv.PendingTanks;
    if (pending == nil) then return; end;

    -- Split pending builds into ones we can still build and ones we removed because ownership changed.
    local removedPending = {};
    local remainingPending = {};
    for _, build in pairs(pending) do
        local territory = game.ServerGame.LatestTurnStanding.Territories[build.TerritoryID];
        if (territory == nil or territory.OwnerPlayerID ~= build.PlayerID) then
            table.insert(removedPending, build);
        else
            table.insert(remainingPending, build);
        end
    end

    for _, build in pairs(remainingPending) do
        local tank = TankCardApplication.BuildTank(build.PlayerID);

        local territoryModification = WL.TerritoryModification.Create(build.TerritoryID);
        territoryModification.AddSpecialUnits = { tank };

        local td = game.Map.Territories[build.TerritoryID];
        local event = WL.GameOrderEvent.Create(build.PlayerID, build.Message, {}, { territoryModification });
        event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
        event.TerritoryAnnotationsOpt = { [build.TerritoryID] = WL.TerritoryAnnotation.Create("Tank built", 8, GetColourIntegerFromHex(BUTTON_COLOURS.DarkGreen)) };
        event.Icon = "Build";
        addNewOrder(event);
    end

    for _, build in pairs(removedPending) do
        local td = game.Map.Territories[build.TerritoryID];
        local event = WL.GameOrderEvent.Create(build.PlayerID, "Unable to build Tank on " .. td.Name, {}, {});
        event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
        event.TerritoryAnnotationsOpt = { [build.TerritoryID] = WL.TerritoryAnnotation.Create("Unable to build Tank", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Red)) };
        event.Icon = "BuildFailed";
        addNewOrder(event);
    end

    priv.PendingTanks = nil;
    Mod.PrivateGameData = priv;
end

---Resolves a Placeholder from the Custom Scenario Builder Mod Orchestrator mod (see CustomScenarioBuilder.lua)
---into a real Tank. Owned by Neutral, matching CSBMO's own Placeholder unit's ownership - untested whether a
---special unit added this way (via TerritoryStanding.NumArmies reassignment, not CustomScenario) tolerates
---Neutral ownership the same way; worth confirming in an actual test game.
---@param placeholder CustomScenarioBuilderPlaceholder
---@param territoryStanding TerritoryStanding
function TankCardApplication.ResolveCustomScenarioBuilderPlaceholder(placeholder, territoryStanding)
    local tank = TankCardApplication.BuildTank(WL.PlayerID.Neutral);
    CustomScenarioBuilder.ReplacePlaceholder(placeholder, territoryStanding, { AddSpecialUnits = { tank } });
end
