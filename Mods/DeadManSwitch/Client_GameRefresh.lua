require("Annotations");

---Client_GameRefresh hook
---@param game GameClientHook
function Client_GameRefresh(game)
    require("Utilities");
    local publicGameData = Mod.PublicGameData
    if(publicGameData ~= nil and publicGameData.logging ~= nil) then
	    DumpTable(publicGameData.logging);
    end;
end