require("Utilities");

-- PrivateGameData layout used by this mod:
--   TurnsUntilStart        integer      turns remaining before the clock starts and a holder is picked
--   CurrentHolder          PlayerID|nil the player currently holding the Hot Potato, nil if it isn't active
--   PriorHolder            PlayerID|nil the player who held it immediately before CurrentHolder, can't receive it back
--   TurnsHeld              integer      cumulative turns the potato has been held (survives being passed around)
--   TerritoryOwners        table        this turn's running TerritoryID -> OwnerPlayerID map, seeded at turn start
--   TransferCheckedThisTurn boolean     true once this turn's one-and-only transfer attempt has been resolved
--   Dormant                boolean      true this turn if too few players remain for the mod to do anything

--Picks who the Hot Potato goes to out of candidateIDs. Prefers human (non-AI) players over AI ones - only
--falls back to including AI players if no human candidates are available - then applies the configured
--random-vs-biggest selection strategy within whichever pool was used.
function ChooseNewHolder(game, candidateIDs)
	local humanIDs = GetNonAIPlayerIDs(game, candidateIDs);
	local pool = (#humanIDs > 0) and humanIDs or candidateIDs;
	return Mod.Settings.HolderSelectionBiggest and GetBiggestPlayerID(game, pool) or randomFromArray(pool);
end

---Server_AdvanceTurn_Start hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Start(game, addNewOrder)
	local priv = Mod.PrivateGameData;

	-- seed this turn's ownership snapshot; Server_AdvanceTurn_Order updates it as attacks succeed so it can
	-- always tell who owned a territory immediately before the order that just captured it
	local owners = {};
	for territoryID, territory in pairs(game.ServerGame.LatestTurnStanding.Territories) do
		owners[territoryID] = territory.OwnerPlayerID;
	end
	priv.TerritoryOwners = owners;
	priv.TransferCheckedThisTurn = false;

	local playingIDs = GetPlayingPlayerIDs(game);
	priv.Dormant = (#playingIDs <= Mod.Settings.MinPlayersRemaining);

	if (priv.Dormant) then
		if (priv.CurrentHolder ~= nil) then
			local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, "Too few players remain - the Hot Potato fizzles out", {}, {});
			if (game.Game.PlayingPlayers[priv.CurrentHolder] ~= nil) then
				event.AddCardPiecesOpt = { [priv.CurrentHolder] = { [Mod.Settings.CardID] = -priv.TurnsHeld } };
			end
			addNewOrder(event);
		end
		priv.CurrentHolder = nil;
		priv.PriorHolder = nil;
		priv.TurnsHeld = 0;
		Mod.PrivateGameData = priv;
		return;
	end

	-- if the holder is gone (eliminated/booted/surrendered) the potato immediately falls to someone else -
	-- the fuse keeps burning, it just isn't reset, since disappearing shouldn't be a way to stall it out
	if (priv.CurrentHolder ~= nil and game.Game.PlayingPlayers[priv.CurrentHolder] == nil) then
		local eligible = filter(playingIDs, function(id) return id ~= priv.PriorHolder; end);
		if (#eligible == 0) then eligible = playingIDs; end
		local newHolder = ChooseNewHolder(game, eligible);

		if (newHolder ~= nil) then
			priv.PriorHolder = priv.CurrentHolder;
			priv.CurrentHolder = newHolder;

			-- the old holder's cards (and pieces) are gone along with them on elimination, so only the new
			-- holder needs to be given the pieces representing the fuse progress so far
			local event = WL.GameOrderEvent.Create(newHolder, "The previous Hot Potato holder is gone, and it has fallen into your hands", {}, {});
			event.AddCardPiecesOpt = { [newHolder] = { [Mod.Settings.CardID] = priv.TurnsHeld } };
			addNewOrder(event);
		end
	end

	Mod.PrivateGameData = priv;
end

---Server_AdvanceTurn_Order hook
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl)
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
	if (order.proxyType ~= 'GameOrderAttackTransfer' or not result.IsAttack or result.IsNullified) then return; end
	if (result.ActualArmies ~= nil and result.ActualArmies.IsEmpty) then return; end -- ignore skipped/empty attacks

	local priv = Mod.PrivateGameData;
	local owners = priv.TerritoryOwners or {};
	local previousOwner = owners[order.To];

	-- keep the running ownership snapshot accurate for the rest of this turn's orders, regardless of whether
	-- the Hot Potato is even active right now
	if (result.IsSuccessful) then
		owners[order.To] = order.PlayerID;
		priv.TerritoryOwners = owners;
		Mod.PrivateGameData = priv;
	end

	if (priv.CurrentHolder == nil or priv.TransferCheckedThisTurn) then return; end

	local holder = priv.CurrentHolder;
	local loser = nil;

	if (result.IsSuccessful and order.PlayerID == holder and previousOwner ~= nil
		and previousOwner ~= WL.PlayerID.Neutral and previousOwner ~= holder) then
		loser = previousOwner; -- the holder attacked and captured another player's territory
	elseif (not Mod.Settings.OnlyAttackWins and not result.IsSuccessful
		and previousOwner == holder and order.PlayerID ~= holder) then
		loser = order.PlayerID; -- the holder successfully defended against an attacker
	end

	if (loser == nil) then return; end

	-- this is the first (and only) fight this turn that decides the Hot Potato's fate, win or block
	priv.TransferCheckedThisTurn = true;

	if (loser == priv.PriorHolder) then
		addNewOrder(WL.GameOrderEvent.Create(holder, "Won a fight, but the Hot Potato can't be passed back to who you got it from - it stays put", {}, {}));
	else
		priv.PriorHolder = holder;
		priv.CurrentHolder = loser;

		-- the pieces (ie. the fuse progress) move with the potato - take them all from the old holder and
		-- give the same amount to the new one, rather than resetting the count
		local event = WL.GameOrderEvent.Create(loser, "Lost a fight against the Hot Potato holder, and now holds it yourself!", {}, {});
		event.AddCardPiecesOpt = {
			[holder] = { [Mod.Settings.CardID] = -priv.TurnsHeld },
			[loser] = { [Mod.Settings.CardID] = priv.TurnsHeld },
		};
		addNewOrder(event);
	end

	Mod.PrivateGameData = priv;
end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_End(game, addNewOrder)
	local priv = Mod.PrivateGameData;
	if (priv.Dormant) then return; end;

	if (priv.CurrentHolder == nil) then
		priv.TurnsUntilStart = (priv.TurnsUntilStart or Mod.Settings.TurnsBeforeStart) - 1;

		if (priv.TurnsUntilStart <= 0) then
			local playingIDs = GetPlayingPlayerIDs(game);
			local newHolder = ChooseNewHolder(game, playingIDs);

			if (newHolder ~= nil) then
				priv.CurrentHolder = newHolder;
				priv.PriorHolder = nil;
				priv.TurnsHeld = 1;

				local event = WL.GameOrderEvent.Create(newHolder, "The clock starts - the Hot Potato has been handed to you!", {}, {});
				event.AddCardPiecesOpt = { [newHolder] = { [Mod.Settings.CardID] = 1 } };
				addNewOrder(event);
			end
		end

		Mod.PrivateGameData = priv;
		return;
	end

	-- if the fuse was already fully burned down as of the start of this turn, it goes off now - this is
	-- checked *before* this turn's piece is added so the holder always gets to see the piece count actually
	-- sitting at FuseLength/FuseLength for one full turn before it detonates, rather than jumping straight
	-- from FuseLength-1 to exploding in the same turn the last piece would have been added. If the potato was
	-- passed to a new holder already fully armed (ie. it was already due to explode when they received it),
	-- it still goes off on them right away - passing on an already-primed potato doesn't buy a fresh turn
	if (priv.TurnsHeld >= Mod.Settings.FuseLength) then
		Explode(game, addNewOrder, priv.CurrentHolder, priv.TurnsHeld);
		priv.CurrentHolder = nil;
		priv.PriorHolder = nil;
		priv.TurnsHeld = 0;
		priv.TurnsUntilStart = Mod.Settings.TurnsBeforeStart;
		Mod.PrivateGameData = priv;
		return;
	end

	priv.TurnsHeld = priv.TurnsHeld + 1;

	-- another turn survived without being passed on - hand the holder one more piece of the Hot Potato card
	local pieceEvent = WL.GameOrderEvent.Create(priv.CurrentHolder, "The Hot Potato ticks over another turn", {}, {});
	pieceEvent.AddCardPiecesOpt = { [priv.CurrentHolder] = { [Mod.Settings.CardID] = 1 } };
	addNewOrder(pieceEvent);

	ApplyMinorPenalty(game, addNewOrder, priv.CurrentHolder);

	Mod.PrivateGameData = priv;
end

--applies the per-turn income penalty for holding the Hot Potato; added as an IncomeMod so, like other mods'
--sanction-style effects, it takes effect on the holder's income from next turn onward
function ApplyMinorPenalty(game, addNewOrder, holderID)
	local percent = Mod.Settings.MinorPenaltyPercent or 0;
	if (percent <= 0) then return; end;

	local player = game.Game.Players[holderID];
	if (player == nil) then return; end;

	local income = player.Income(0, game.ServerGame.LatestTurnStanding, false, false).Total;
	local penalty = math.max(1, math.floor(income * percent + 0.5));

	local event = WL.GameOrderEvent.Create(holderID, "The Hot Potato weighs on your economy (-" .. penalty .. " income next turn)", {}, {});
	event.IncomeMods = { WL.IncomeMod.Create(holderID, -penalty, "Holding the Hot Potato") };
	addNewOrder(event);
end

--the fuse ran out: strips the accumulated Hot Potato card pieces (the potato is spent) and destroys a
--percentage of the armies (with a minimum per territory) on every territory the holder owns, then the caller
--resets the Hot Potato state and restarts the countdown
function Explode(game, addNewOrder, holderID, piecesHeld)
	local territoryIDs = GetTerritoriesOwnedBy(game, holderID);
	local mods = {};
	local annotations = {};

	for _, territoryID in ipairs(territoryIDs) do
		local territory = game.ServerGame.LatestTurnStanding.Territories[territoryID];
		local currentArmies = territory.NumArmies.NumArmies;
		local damage = math.max(Mod.Settings.MajorPenaltyMinDamage or 0, math.floor(currentArmies * (Mod.Settings.MajorPenaltyPercent or 0) + 0.5));
		local newArmies = math.max(0, currentArmies - damage);

		if (newArmies < currentArmies) then
			local territoryModification = WL.TerritoryModification.Create(territoryID);
			territoryModification.SetArmiesTo = newArmies;
			table.insert(mods, territoryModification);
			annotations[territoryID] = WL.TerritoryAnnotation.Create("Boom!", 10, GetColourIntegerFromHex(BUTTON_COLOURS.Red));
		end
	end

	local event = WL.GameOrderEvent.Create(holderID, "The Hot Potato explodes in your hands!", {}, mods);
	event.TerritoryAnnotationsOpt = annotations;
	event.AddCardPiecesOpt = { [holderID] = { [Mod.Settings.CardID] = -piecesHeld } };
	addNewOrder(event);
end
