-- CustomScenarioBuilderModOrchestrator
--
-- TEST: prove that a mod can place a custom special unit into the game's
-- custom scenario from Server_Created, so it is on the map when the game starts.
--
-- For this first test we hard-code a single Tank (stats copied from
-- FizzerWL/ExampleMods TanksMod) onto territory ID 1.

local TEST_TERRITORY_ID = 1;
local TANK_POWER = 5;

---Builds a Tank custom special unit, matching TanksMod's definition.
---@param ownerID PlayerID
---@return CustomSpecialUnit
local function BuildTank(ownerID)
	local builder = WL.CustomSpecialUnitBuilder.Create(ownerID);
	builder.Name = 'Tank';
	builder.IncludeABeforeName = true;
	builder.ImageFilename = 'Tank.png';
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

---True if the player could be the game creator. The API has no creator field, but at
---Server_Created invitees are still Invited, so the creator is the human who is already
---Playing. AIs added by the creator are excluded.
---@param player GamePlayer
---@return boolean
local function IsCreatorCandidate(player)
	return player.State == WL.GamePlayerState.Playing and not player.IsAI;
end

---Returns the PlayerID of the game creator, or nil if none can be found.
---Players is keyed by PlayerID, so pairs() order is undefined; if more than one player
---qualifies, the lowest GamePlayerID (the earliest added) is taken.
---@param game GameServerHook
---@return PlayerID | nil
local function GetGameCreatorID(game)
	local firstPlayer = nil;
	for _, player in pairs(game.Game.Players) do
		if (IsCreatorCandidate(player) and (firstPlayer == nil or player.GamePlayerID < firstPlayer.GamePlayerID)) then
			firstPlayer = player;
		end
	end
	if (firstPlayer == nil) then
		return nil;
	end
	return firstPlayer.ID;
end

---Server_Created hook
---@param game GameServerHook
---@param settings GameSettings
function Server_Created(game, settings)
	-- Proxy objects may hand back copies, so every level is read into a local,
	-- mutated, then reassigned back up the chain (see .agents/game-data.md).
	local scenario = settings.CustomScenario;
	if (scenario == nil) then
		print('[CSBMO] settings.CustomScenario is nil - is the game using the Custom Scenario distribution?');
		return;
	end

	local territories = scenario.Territories;
	local scenarioTerritory = territories[TEST_TERRITORY_ID];
	if (scenarioTerritory == nil) then
		print('[CSBMO] Territory ' .. TEST_TERRITORY_ID .. ' is not in the custom scenario.');
		return;
	end

	-- Special units can't be neutral-owned, so give the tank to the game creator.
	local ownerID = GetGameCreatorID(game);
	if (ownerID == nil) then
		print('[CSBMO] Could not find the game creator to own the Tank.');
		return;
	end

	local specialUnits = scenarioTerritory.SpecialUnits or {};
	table.insert(specialUnits, BuildTank(ownerID));

	scenarioTerritory.SpecialUnits = specialUnits;
	territories[TEST_TERRITORY_ID] = scenarioTerritory;
	scenario.Territories = territories;
	settings.CustomScenario = scenario;

	print('[CSBMO] Added a Tank owned by player ' .. ownerID .. ' to territory ' .. TEST_TERRITORY_ID .. '.');
end
