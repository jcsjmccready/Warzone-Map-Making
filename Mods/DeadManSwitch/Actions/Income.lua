require("Actions.Actions");

Actions.Income = {};
Actions.Income.GrantToDefender = {};

---@param game GameServerHook
---@param standing GameStanding
---@param playerID PlayerID
---@return integer
local function GetPlayerIncome(game, standing, playerID)
	local player = game.ServerGame.Game.PlayingPlayers[playerID];
	return (player ~= nil) and player.Income(0, standing, false, false).Total or 0;
end

---@param territoryModification TerritoryModification
---@param game GameServerHook
---@param context DeadManSwitchTriggerContext
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param numberOfDMS integer
function Actions.Income.GrantToDefender.Trigger(territoryModification, game, context, addNewOrder, numberOfDMS)
	if (context.DefendingPlayerID == WL.PlayerID.Neutral) then return; end;

	local standing = game.ServerGame.LatestTurnStanding;
	local defenderIncome = GetPlayerIncome(game, standing, context.DefendingPlayerID);

	local perSwitch = (Mod.Settings.GrantIncomeFlat or 0) + math.max((Mod.Settings.GrantIncomePercent or 0) * defenderIncome, Mod.Settings.GrantIncomeMinimumPercent or 0);
	local amount = math.floor(perSwitch * numberOfDMS + 0.5);
	if (amount <= 0) then return; end;

	local steal = Mod.Settings.GrantIncomeSteal;

	if (steal) then
		local attackerIncome = GetPlayerIncome(game, standing, context.AttackerPlayerID);
		amount = math.min(amount, math.max(attackerIncome, 0));
		if (amount <= 0) then return; end;
	end

	-- gold in Commerce games, otherwise bonus armies
	local isCommerce = game.Settings.CommerceGame;
	local message = "Dead Man's Switch granted its previous owner " .. amount .. (isCommerce and " gold" or " bonus income");
	if (steal) then message = message .. ", stolen from the attacker"; end

	local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, message, { context.DefendingPlayerID, context.AttackerPlayerID }, {});

	if (isCommerce) then
		local resourceChanges = { [context.DefendingPlayerID] = { [WL.ResourceType.Gold] = amount } };
		if (steal) then resourceChanges[context.AttackerPlayerID] = { [WL.ResourceType.Gold] = -amount }; end
		event.AddResourceOpt = resourceChanges;
	else
		local incomeMods = { WL.IncomeMod.Create(context.DefendingPlayerID, amount, "Dead Man's Switch") };
		if (steal) then table.insert(incomeMods, WL.IncomeMod.Create(context.AttackerPlayerID, -amount, "Dead Man's Switch")); end
		event.IncomeMods = incomeMods;
	end

	event.Icon = "Triggered";
	addNewOrder(event, true);
end
