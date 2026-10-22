require("Utilities");

---Server_StartGame
---@param game GameServerHook
---@param standing GameStanding
function Server_StartGame(game, standing)
    for _, row in ipairs(Mod.Settings.Rows or {}) do
        local playerID = FindPlayerIDForSlot(game, row.Slot);
        if (playerID ~= nil) then
            if (game.Settings.CommerceGame) then
                local currentGold = standing.NumResources(playerID, WL.ResourceType.Gold);
                local newGold = math.max(0, currentGold + row.Income);
                game.ServerGame.SetPlayerResource(playerID, WL.ResourceType.Gold, newGold);
            else
                local incomeMods = standing.IncomeMods or {};
                table.insert(incomeMods, WL.IncomeMod.Create(playerID, row.Income, "Slot Starting Income", nil));
                standing.IncomeMods = incomeMods;
            end
        end
    end
end
