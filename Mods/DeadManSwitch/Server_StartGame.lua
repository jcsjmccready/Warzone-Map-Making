
---@param game GameServerHook
---@param standing GameStanding
function Server_StartGame(game, standing)
    local pub = Mod.PublicGameData or {};
    pub.DmsStructureID = WL.StructureType.Custom("Dead Man's Switch");
    Mod.PublicGameData = pub;
end
