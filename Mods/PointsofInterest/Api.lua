require("IO.ModAuth");
require("IO.ApiBase");
require("Application");

----------------------------------------------------------------------------------------------------------------------
-- Points of Interest's public ModAuth API
--
-- To call any action below, send a ModAuth order such as the below:
--   IO.ModAuth.Send(IO.ModAuth.LOCAL_MOD_KEY for targetted mod, playerID, data, addNewOrder);
-- e.g. for PointsOfInterestAddPointOfInterestDto: data = { Action = PointsOfInterestActions.AddPointOfInterest, Letter = "A", TerritoryID = 4 }.
----------------------------------------------------------------------------------------------------------------------

POINTS_OF_INTEREST_API_VERSION = 1;

PointsOfInterestApi = IO.ApiBase.New();

---@param data PointsOfInterestAddPointOfInterestDto
---@param order GameOrderCustom
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
local function HandleAddPointOfInterest(data, order, game, addNewOrder)
    if (not PointsOfInterestApi.ValidateFields(PointsOfInterestActions.AddPointOfInterest, data, order, addNewOrder, {
        { Name = "Letter", Type = "string", Required = true },
        { Name = "TerritoryID", Type = "number", Required = true },
    })) then return; end;

    local name = GetNatoNameForLetter(data.Letter);
    if (name == nil) then
        addNewOrder(WL.GameOrderEvent.Create(WL.PlayerID.Neutral, IO.ModAuth.LOCAL_MOD_KEY .. " rejected " .. PointsOfInterestActions.AddPointOfInterest .. ": Letter must be a single letter A-Z", { order.PlayerID }, {}));
        return;
    end

    if (game.Map.Territories[data.TerritoryID] == nil) then
        addNewOrder(WL.GameOrderEvent.Create(WL.PlayerID.Neutral, IO.ModAuth.LOCAL_MOD_KEY .. " rejected " .. PointsOfInterestActions.AddPointOfInterest .. ": TerritoryID does not exist", { order.PlayerID }, {}));
        return;
    end

    PointsOfInterestApplication.AddPointOfInterest(game, addNewOrder, order.PlayerID, name, data.TerritoryID);
end
PointsOfInterestApi.Register(PointsOfInterestActions.AddPointOfInterest, HandleAddPointOfInterest);

---@param data PointsOfInterestRemovePointOfInterestDto
---@param order GameOrderCustom
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
local function HandleRemovePointOfInterest(data, order, game, addNewOrder)
    if (not PointsOfInterestApi.ValidateFields(PointsOfInterestActions.RemovePointOfInterest, data, order, addNewOrder, {
        { Name = "TerritoryID", Type = "number", Required = true },
        { Name = "Letter", Type = "string", Required = false },
    })) then return; end;

    local name = nil;
    if (data.Letter ~= nil) then
        name = GetNatoNameForLetter(data.Letter);
        if (name == nil) then
            addNewOrder(WL.GameOrderEvent.Create(WL.PlayerID.Neutral, IO.ModAuth.LOCAL_MOD_KEY .. " rejected " .. PointsOfInterestActions.RemovePointOfInterest .. ": Letter must be a single letter A-Z", { order.PlayerID }, {}));
            return;
        end
    end

    PointsOfInterestApplication.RemovePointOfInterest(game, addNewOrder, data.TerritoryID, name);
end
PointsOfInterestApi.Register(PointsOfInterestActions.RemovePointOfInterest, HandleRemovePointOfInterest);
