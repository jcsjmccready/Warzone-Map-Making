require("Utilities");

local APPLIED_MARKER_MESSAGE = "Slot Starting Income";

---@param game GameServerHook
---@param standing GameStanding
function Server_StartGame(game, standing)
    local incomeMods = standing.IncomeMods or {};
    local resources = standing.Resources or {};

    for _, row in ipairs(Mod.Settings.Rows or {}) do
        local playerID = FindPlayerIDForSlot(game, standing, row.Slot);
        if (playerID ~= nil) then
            local alreadyApplied = false;
            for _, mod in ipairs(incomeMods) do
                if (mod.PlayerID == playerID and mod.Message == APPLIED_MARKER_MESSAGE) then
                    alreadyApplied = true;
                    break;
                end
            end

            if (not alreadyApplied) then
                if (game.Settings.CommerceGame) then
                    local playerResources = resources[playerID] or {};
                    local currentGold = playerResources[WL.ResourceType.Gold] or 0;
                    playerResources[WL.ResourceType.Gold] = math.max(0, currentGold + row.Income);
                    resources[playerID] = playerResources;
                    table.insert(incomeMods, WL.IncomeMod.Create(playerID, 0, APPLIED_MARKER_MESSAGE, nil));
                else
                    table.insert(incomeMods, WL.IncomeMod.Create(playerID, row.Income, APPLIED_MARKER_MESSAGE, nil));
                end
            end
        end
    end

    standing.IncomeMods = incomeMods;
    standing.Resources = resources;
end
