require("Utilities");

---Server_AdvanceTurn_Order hook. Builds a Point of Interest when a purchase order is processed
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl)
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
    if (order.proxyType ~= 'GameOrderCustom') then
        return;
    end

    local name, territoryID = ParseBuildPayload(order.Payload);
    if (name == nil) then
        return;
    end

    local territoryDetails = game.Map.Territories[territoryID];
    if (not IsNatoName(name) or territoryDetails == nil) then
        -- malformed order; skipping it means the player isn't charged for it
        skipThisOrder(WL.ModOrderControl.Skip);
        return;
    end

    BuildPointOfInterest(order.PlayerID, name, territoryID, territoryDetails, addNewOrder);
end

---Adds the structure to the territory, records it in private game data, and grants its configured visibility.
---Structures can't be removed, and FogMods persist until removed, so the FogMod only ever needs adding here.
---@param playerID PlayerID # Player who paid for it. Only used to attribute the order, ownership is irrelevant
---@param name string
---@param territoryID TerritoryID
---@param territoryDetails TerritoryDetails
---@param addNewOrder fun(order: GameOrder)
function BuildPointOfInterest(playerID, name, territoryID, territoryDetails, addNewOrder)
    local visibility = GetConfiguredVisibility(name);

    local territoryModification = WL.TerritoryModification.Create(territoryID);
    territoryModification.AddStructuresOpt = { [WL.StructureType.Custom(name)] = 1 };

    local event = WL.GameOrderEvent.Create(playerID, "Built " .. name .. " on " .. territoryDetails.Name, {}, { territoryModification });
    event.JumpToActionSpotOpt = WL.RectangleVM.Create(territoryDetails.MiddlePointX, territoryDetails.MiddlePointY, territoryDetails.MiddlePointX, territoryDetails.MiddlePointY);
    event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create(name, 8, GetColourIntegerFromHex(BUTTON_COLOURS.DarkGreen)) };
    event.Icon = "Build";

    -- Visible to every player, since Points of Interest belong to the lobby rather than to a player
    local fogModID = nil;
    local fogLevel = GetStandingFogLevel(visibility);
    if (fogLevel ~= nil) then
        local fogMod = WL.FogMod.Create(name .. " Point of Interest", fogLevel, FOG_MOD_PRIORITY, { territoryID }, nil);
        event.FogModsOpt = { fogMod };
        fogModID = fogMod.ID;
    end

    addNewOrder(event);

    local priv = Mod.PrivateGameData or {};
    local pointsOfInterest = priv.PointsOfInterest or {};
    table.insert(pointsOfInterest, {
        StructureName = name,
        Visibility = visibility,
        TerritoryID = territoryID,
        FogModID = fogModID,
    });
    priv.PointsOfInterest = pointsOfInterest;
    Mod.PrivateGameData = priv;
end
