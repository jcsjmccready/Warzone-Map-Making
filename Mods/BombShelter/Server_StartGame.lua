
---@param game GameServerHook
---@param standing GameStanding
function Server_StartGame(game, standing)
    local pub = Mod.PublicGameData or {};
    pub.BombShelterStructureID = WL.StructureType.Custom("Bomb Shelter");
    Mod.PublicGameData = pub;
end
