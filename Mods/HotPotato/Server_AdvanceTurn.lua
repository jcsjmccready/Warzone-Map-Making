require("Utilities");

-- PrivateGameData layout used by this mod:
--   TurnsUntilStart        	integer      turns remaining before the clock starts and a holder is picked
--   CurrentHolder          	PlayerID|nil the player currently holding the Hot Potato, nil if it isn't active
--   PriorHolder            	PlayerID|nil the player who held it immediately before CurrentHolder, can't receive it back
--   TurnsHeld              	integer      cumulative turns the potato has been held (survives being passed around)
--   PotatoTransferredThisTurn  boolean      true once this turn's one-and-only transfer has been resolved
--   Dormant                	boolean      true this turn if too few players remain for the mod to do anything

-- TODO: REMOVE THE HUMAN PREFERENCE CODE - TESTING ONLY
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

	local playingIDs = GetPlayingPlayerIDs(game);
	priv.Dormant = (#playingIDs <= Mod.Settings.MinPlayersRemaining);

	if (priv.Dormant) then
		if (priv.CurrentHolder ~= nil) then
			local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, "Too few players remain - the Hot Potato fizzles out", { priv.CurrentHolder }, {});
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
	
	priv.PotatoTransferredThisTurn = false;

	-- if the holder is gone (eliminated/booted/surrendered) the potato immediately falls to someone else -
	-- the fuse keeps burning, it just isn't reset, since disappearing shouldn't be a way to stall it out
	if (priv.CurrentHolder ~= nil and game.Game.PlayingPlayers[priv.CurrentHolder] == nil) then
		local eligible = filter(playingIDs, function(id) return id ~= priv.PriorHolder; end);
		if (#eligible == 0) then eligible = playingIDs; end
		local newHolder = ChooseNewHolder(game, eligible);

		if (newHolder ~= nil) then
			priv.PriorHolder = priv.CurrentHolder;
			priv.CurrentHolder = newHolder;

			-- this counts as this turn's one hand-change, so a fight later this same turn can't pass it again - noone gets to skip owning the potato >:(
			priv.PotatoTransferredThisTurn = true;

			-- the old holder's cards (and pieces) are gone along with them on elimination, so only the new
			-- holder needs to be given the pieces representing the fuse progress so far
			local event = WL.GameOrderEvent.Create(newHolder, "The previous Hot Potato holder is gone, and it has fallen into your hands", { newHolder }, {});
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
	if (priv.CurrentHolder == nil or priv.PotatoTransferredThisTurn) then return; end

	local potatoHolder = priv.CurrentHolder;
	local targetPlayerID = game.ServerGame.LatestTurnStanding.Territories[order.To].OwnerPlayerID;
	local loserPlayerID = nil;

	-- if successful attack by potato holder
	if (result.IsSuccessful and order.PlayerID == potatoHolder
		and targetPlayerID ~= nil and targetPlayerID ~= WL.PlayerID.Neutral and targetPlayerID ~= potatoHolder) then
		loserPlayerID = targetPlayerID; -- the holder attacked and captured another player's territory
	elseif (not Mod.Settings.OnlyAttackWins and not result.IsSuccessful
		and targetPlayerID == potatoHolder and order.PlayerID ~= potatoHolder) then
		loserPlayerID = order.PlayerID; -- the holder successfully defended against an attacker
	end

	-- safety check for good measure, exit early
	if (loserPlayerID == nil) then return; end


	if (loserPlayerID == priv.PriorHolder) then
		addNewOrder(WL.GameOrderEvent.Create(potatoHolder, "Won a fight, but no potato pass-backs!", { potatoHolder }, {}));
	else
		priv.PotatoTransferredThisTurn = true;
		priv.PriorHolder = potatoHolder;
		priv.CurrentHolder = loserPlayerID;

		-- the pieces (ie. the fuse progress) move with the potato - take them all from the old holder and
		-- give the same amount to the new one, rather than resetting the count
		local holderName = game.Game.Players[potatoHolder].DisplayName(nil, false);
		local loserName = game.Game.Players[loserPlayerID].DisplayName(nil, false);
		local event = WL.GameOrderEvent.Create(loserPlayerID, holderName .. " passed the potato to " .. loserName, { potatoHolder, loserPlayerID }, {});
		event.AddCardPiecesOpt = {
			[potatoHolder] = { [Mod.Settings.CardID] = -priv.TurnsHeld },
			[loserPlayerID] = { [Mod.Settings.CardID] = priv.TurnsHeld },
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
		priv.TurnsUntilStart = Mod.Settings.TurnsBeforeRestart;
		Mod.PrivateGameData = priv;
		return;
	end

	priv.TurnsHeld = priv.TurnsHeld + 1;

	-- this is the one-turn "primed and about to go off" state described above - worth a lobby-wide heads up
	-- since it's the last chance for anyone else to try and pass it off before it detonates
	if (priv.TurnsHeld >= Mod.Settings.FuseLength) then
		local holderName = game.Game.Players[priv.CurrentHolder].DisplayName(nil, false);
		addNewOrder(WL.GameOrderEvent.Create(priv.CurrentHolder, "The Hot Potato is primed in " .. holderName .. "'s hands - it will explode next turn.", {}, {}));
	end

	-- hand the holder one more piece of the Hot Potato card
	local pieceEvent = WL.GameOrderEvent.Create(priv.CurrentHolder, "The Hot Potato ticks over another turn", { priv.CurrentHolder }, {});
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
	local penalty = math.max(Mod.Settings.MinorPenaltyMinDamage or 0, math.floor(income * percent + 0.5));

	local event = WL.GameOrderEvent.Create(holderID, "The Hot Potato weighs on your economy (-" .. penalty .. " income next turn)", { holderID }, {});
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
			annotations[territoryID] = WL.TerritoryAnnotation.Create("Hot Potato Explodes", 10, GetColourIntegerFromHex(BUTTON_COLOURS.Red));
		end
	end

	local event = WL.GameOrderEvent.Create(holderID, "The Hot Potato explodes in your hands!", {}, mods);
	event.TerritoryAnnotationsOpt = annotations;
	event.AddCardPiecesOpt = { [holderID] = { [Mod.Settings.CardID] = -piecesHeld } };

	local player = game.Game.Players[holderID];
	local incomeLossPercent = Mod.Settings.MajorPenaltyIncomeLossPercent or 0;
	if (player ~= nil and incomeLossPercent > 0) then
		local income = player.Income(0, game.ServerGame.LatestTurnStanding, false, false).Total;
		local incomePenalty = math.max(Mod.Settings.MajorPenaltyIncomeLossMinDamage or 0, math.floor(income * incomeLossPercent + 0.5));
		if (incomePenalty > 0) then
			event.IncomeMods = { WL.IncomeMod.Create(holderID, -incomePenalty, "The Hot Potato exploded") };
		end
	end

	addNewOrder(event);
end