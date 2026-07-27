require("Utilities");

---Server_StartGame hook
---@param game GameServerHook
---@param standing GameStanding
function Server_StartGame(game, standing)
	local priv = Mod.PrivateGameData;
	priv.TurnsUntilStart = Mod.Settings.TurnsBeforeStart;
	priv.CurrentHolder = nil;
	priv.PriorHolder = nil;
	priv.TurnsHeld = 0;
	Mod.PrivateGameData = priv;
end
