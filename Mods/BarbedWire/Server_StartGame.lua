
---@param game GameServerHook
---@param standing GameStanding
function Server_StartGame(game, standing)
    local pub = Mod.PublicGameData or {};
    pub.BarbedWirePrimedStructureID = WL.StructureType.Custom("PrimedBarbedWire");
    pub.BarbedWireTriggeredStructureID = WL.StructureType.Custom("TriggeredBarbedWire");
    Mod.PublicGameData = pub;
end
