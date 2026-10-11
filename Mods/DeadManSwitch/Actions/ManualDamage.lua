require("Actions.Actions");

Actions.ManualDamage = {};
Actions.ManualDamage.Flat = {};
Actions.ManualDamage.Percent = {};

---Kills a flat number of armies on the captured territory for each DMS
---@param territoryModification TerritoryModification
---@param game GameServerHook
---@param context DeadManSwitchTriggerContext
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param numberOfDMS integer
function Actions.ManualDamage.Flat.Trigger(territoryModification, game, context, addNewOrder, numberOfDMS)
	local damageAmount = Mod.Settings.FlatDamage * numberOfDMS;
	territoryModification.SetArmiesTo = math.max(0, context.ArmiesOnArrival - damageAmount);

	AddTriggeredEvent(context, territoryModification, addNewOrder);
end

---Kills a percentage of the armies (with a minimum) on the captured territory for each DMS
---@param territoryModification TerritoryModification
---@param game GameServerHook
---@param context DeadManSwitchTriggerContext
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param numberOfDMS integer
function Actions.ManualDamage.Percent.Trigger(territoryModification, game, context, addNewOrder, numberOfDMS)
	local remainingArmies = context.ArmiesOnArrival;

	for _ = 1, numberOfDMS do
		remainingArmies = math.max(0, math.floor(remainingArmies * (1 - Mod.Settings.PercentageDamage) + 0.5));
	end

	local minimumRemainingArmies = math.max(0, context.ArmiesOnArrival - (Mod.Settings.PercentageMinDamage * numberOfDMS));
	territoryModification.SetArmiesTo = math.max(0, math.min(remainingArmies, minimumRemainingArmies));

	AddTriggeredEvent(context, territoryModification, addNewOrder);
end
