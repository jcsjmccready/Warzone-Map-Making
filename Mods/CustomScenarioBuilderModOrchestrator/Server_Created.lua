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

---Server_Created hook
---@param game GameServerHook
---@param settings GameSettings
function Server_Created(game, settings)
	-- CustomScenario.Territories is not writable, so the territory is mutated in place
	-- through the Territories table rather than reassigned back up the chain.
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

	-- Owned by neutral for this test.
	local ownerID = WL.PlayerID.Neutral;

	local specialUnits = scenarioTerritory.SpecialUnits or {};
	table.insert(specialUnits, BuildTank(ownerID));

	scenarioTerritory.SpecialUnits = specialUnits;
	territories[TEST_TERRITORY_ID] = scenarioTerritory;
	settings.CustomScenario = scenario;

	print('[CSBMO] Added a Tank owned by player ' .. tostring(ownerID) .. ' to territory ' .. TEST_TERRITORY_ID .. '.');
end
