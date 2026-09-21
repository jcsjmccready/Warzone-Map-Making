require("Actions.Actions");

Actions.ManualDamage = {};
Actions.ManualDamage.Flat = {};
Actions.ManualDamage.Percent = {};

---Kills a flat number of armies on the captured territory for each DMS
---@param territoryModification TerritoryModification
---@param game GameServerHook
---@param order GameOrderAttackTransfer
---@param result GameOrderAttackTransferResult
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param numberOfDMS integer
function Actions.ManualDamage.Flat.Trigger(territoryModification, game, order, result, addNewOrder, numberOfDMS)
	local damageAmount = Mod.Settings.FlatDamage * numberOfDMS;
	local damageArmies = WL.Armies.Create(damageAmount + result.AttackingArmiesKilled.NumArmies);
	territoryModification.SetArmiesTo = result.ActualArmies.Subtract(damageArmies).NumArmies;

	AddTriggeredEvent(order, territoryModification, addNewOrder);
end

---Kills a percentage of the armies (with a minimum) on the captured territory for each DMS
---@param territoryModification TerritoryModification
---@param game GameServerHook
---@param order GameOrderAttackTransfer
---@param result GameOrderAttackTransferResult
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param numberOfDMS integer
function Actions.ManualDamage.Percent.Trigger(territoryModification, game, order, result, addNewOrder, numberOfDMS)
	local armiesAfterAttack = result.ActualArmies.NumArmies - result.AttackingArmiesKilled.NumArmies;
	local remainingArmies = armiesAfterAttack;

	for _ = 1, numberOfDMS do
		remainingArmies = math.floor(remainingArmies * (1 - Mod.Settings.PercentageDamage) + 0.5);
	end

	local minimumRemainingArmies = math.max(0, armiesAfterAttack - (Mod.Settings.PercentageMinDamage * numberOfDMS));
	territoryModification.SetArmiesTo = math.min(remainingArmies, minimumRemainingArmies);

	AddTriggeredEvent(order, territoryModification, addNewOrder);
end
