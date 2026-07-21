function GetTerritoriesWithinDistance (game, targetTerritoryID, intMaxDistance)
    local arrTerrProcessed = {}; --list of terrs already processed
    local arrTerrResults = {}; --resultant list of terrs within specified distance
    local arrTerrListToProcess = {}; --terrs remaining to be processed

	local intDepth = 0;
    arrTerrProcessed [targetTerritoryID] = true;
    table.insert (arrTerrResults, targetTerritoryID);
    table.insert (arrTerrListToProcess, targetTerritoryID);

    while (intDepth < intMaxDistance and #arrTerrListToProcess > 0) do
        local intNextTerrID = {};
        for _, terrID in ipairs(arrTerrListToProcess) do
            for neighbourTerrID, _ in pairs (game.Map.Territories [terrID].ConnectedTo) do
                if not arrTerrProcessed [neighbourTerrID] then
                    arrTerrProcessed [neighbourTerrID] = true;
                    table.insert(arrTerrResults, neighbourTerrID);
                    table.insert(intNextTerrID, neighbourTerrID);
                end
            end
        end
        arrTerrListToProcess = intNextTerrID;
        intDepth = intDepth + 1;
    end
    return (arrTerrResults);
end

--process a manual attack sequence from AttackOrder [type NumArmies] on DefendingTerritory [type Territory] with respect to Specials & armies
--process Specials with combat orders below armies first, then process the armies, then process the remaining Specials
--also treat Specials properly with respect to their specs, notably damage required to kill, health, attack/damage power & modifier properties, damage absorption, etc
--boolWZattackTransferOrder
--     - [Limited Multimove] true indicates whether this is a standard WZ attack order and we're manipulating 'result' to let WZ handle the result of the battle
--     - [Airstrike]         false indicates that this isn't being done with an attack order, usually b/c the FROM and TO territories are not adjacent and the standard WZ engine can't process these attacks; in this case the result is handled by this code, either FROM/TO directly modified + optional airlift to visibly move units when attack is successful
--return value is the result with updated AttackingArmiesKilled, DefendingArmiesKilled values & a true/false AttackIsSuccessful indicator
function process_manual_attack (game, AttackingArmies, DefendingTerritory, result, addNewOrder, boolWZattackTransferOrder)
	--note armies have combat order of 0, Commanders 10,000, need to get the combat order of Specials from their properties
	local DefendingArmies = DefendingTerritory.NumArmies;

	local sortedAttackerSpecialUnits = {};
	local sortedDefenderSpecialUnits = {};
	local totalDefenderDefensePowerPercentage = 1.0;    --this is covered in defense power for an SU so don't actually need this
	--local totalAttackerDefensePowerPercentage = 1.0;  --this is covered in defense power for an SU so don't need this
	local totalAttackerAttackPowerPercentage = 1.0;     --this is covered in defense power for an SU so don't actually need this
	--local totalDefenderAttackPowerPercentage = 1.0;   --this is covered in attack power for an SU so don't actually need this

	--this doesn't work; the AttackingArmies.SpecialUnits table is likely not totally compliant; it needs to be a sequential array table, not a key-value table
	--table.sort(sortedAttackingArmies.SpecialUnits, function(a, b) printDebug ("COMPARE "..a.CombatOrder..", ".. b.CombatOrder..", "..tostring(a.CombatOrder < b.CombatOrder)); return (a.CombatOrder < b.CombatOrder); end);

	--instead, rebuild AttackingArmies.SpecialUnits into a new sequential array & sort this new table by ascending CombatOrder and process that instead
	for _, unit in pairs(AttackingArmies.SpecialUnits) do
		table.insert(sortedAttackerSpecialUnits, unit);
		-- if (unit.proxyType == "CustomSpecialUnit") then
			--if (unit.AttackPowerPercentage ~= nil) then totalAttackerAttackPowerPercentage = totalAttackerAttackPowerPercentage * unit.AttackPowerPercentage; end
			--if (unit.DefensePowerPercentage ~= nil) then totalAttackerDefensePowerPercentage = totalAttackerDefensePowerPercentage * unit.DefensePowerPercentage; end
			--do some math here; remember <0.0 is not possible, 0.0-1.0 is actually -100%-0%, 1.0-2.0 is 0%-100%, etc
				--printDebug ("SPECIAL ATTACKER "..unit.Name..", APower% "..unit.AttackPowerPercentage..", DPower% "..unit.DefensePowerPercentage..", DmgAbsorb "..unit.DamageAbsorbedWhenAttacked..", DmgToKill "..unit.DamageToKill..", Health "..unit.Health);
		-- end
	end
	table.sort(sortedAttackerSpecialUnits, function(a, b) return a.CombatOrder < b.CombatOrder; end)

	--instead, rebuild DefendingArmies.SpecialUnits into a new sequential array & sort this new table by ascending CombatOrder and process that instead
	for _, unit in pairs(DefendingArmies.SpecialUnits) do
		table.insert(sortedDefenderSpecialUnits, unit);
		-- if (unit.proxyType == "CustomSpecialUnit") then
			--if (unit.AttackPowerPercentage ~= nil) then printDebug ("APP "..unit.Name,totalDefenderAttackPowerPercentage,unit.AttackPowerPercentage); totalDefenderAttackPowerPercentage = totalDefenderAttackPowerPercentage * unit.AttackPowerPercentage; end
			--if (unit.DefensePowerPercentage ~= nil) then printDebug ("DPP "..unit.Name,totalDefenderDefensePowerPercentage,unit.DefensePowerPercentage); totalDefenderDefensePowerPercentage = totalDefenderDefensePowerPercentage * unit.DefensePowerPercentage; end
			--do some math here; remember <0.0 is not possible, 0.0-1.0 is actually -100%-0%, 1.0-2.0 is 0%-100%, etc
			--printDebug ("SPECIAL DEFENDER "..unit.Name..", APower% "..unit.AttackPowerPercentage..", DPower% "..unit.DefensePowerPercentage..", DmgAbsorb "..unit.DamageAbsorbedWhenAttacked..", DmgToKill "..unit.DamageToKill..", Health "..unit.Health);
		-- end
	end
	table.sort(sortedDefenderSpecialUnits, function(a, b) return a.CombatOrder < b.CombatOrder; end)

	local AttackPower = AttackingArmies.AttackPower;
	local DefensePower = DefendingTerritory.NumArmies.DefensePower;
	local AttackDamage = math.floor (AttackPower * game.Settings.OffenseKillRate * totalAttackerAttackPowerPercentage + 0.5);
	local DefenseDamage = math.floor (DefensePower * game.Settings.DefenseKillRate * totalDefenderDefensePowerPercentage + 0.5);

	--assume order is an attack (otherwise don't call process_manual_attack)
	--if the target territory has an active shield, nullify all damage by zeroing out AttackDamage & DefenseDamage; this is required b/c WZ engine applies the damage nullifying property of the Shield SU only to accompanying allied armies involved in attack but not other SUs
	--thus, other SUs in the territory with the shield will still give out defense damage to attack units, which shouldn't be the case for a Shield; so nullify that damage here
	local boolTOterritoryHasActiveShield = territoryHasActiveShield (DefendingTerritory);
	if (boolTOterritoryHasActiveShield == true) then
		AttackDamage = 0;
		DefenseDamage = 0;
		print ("[ATTACK/TRANSFER] [SHIELD on TARGET TERRITORY] nullify all damage");
	end

	--process Defender damage 1st; if both players are eliminated by this order & they are the last 2 active players in the game, then Defender is eliminated 1st, Attacker wins
	-- print ("[DEFENDER TAKES DAMAGE] "..AttackDamage..", AttackPower "..AttackPower..", AttackerAttackPower% ".. totalAttackerAttackPowerPercentage..", Off kill rate "..game.Settings.OffenseKillRate.." _________________");
	local defenderResult = apply_damage_to_specials_and_armies (sortedDefenderSpecialUnits, DefendingArmies.NumArmies, AttackDamage, game, addNewOrder, boolWZattackTransferOrder, nil);
	-- print ("[ATTACKER TAKES DAMAGE] "..DefenseDamage..", DefensePower "..DefensePower..", DefenderDefensePower% ".. totalDefenderDefensePowerPercentage..", Def kill rate "..game.Settings.DefenseKillRate.." _________________");
	local attackerResult = apply_damage_to_specials_and_armies (sortedAttackerSpecialUnits, AttackingArmies.NumArmies, DefenseDamage, game, addNewOrder, boolWZattackTransferOrder, {["Flag"]=384, ["Captured Flag"]=384}); --Flag/Captured Flag SUs from Mod#384 (Capture the Flag mod) are invulnerable SUs
	local boolAttackSuccessful = false; --indicates whether attacker is successful and should move units to target territory and take ownership of it
	-- print ("[DEFENDER RESULT] #armies "..defenderResult.RemainingArmies .." ["..defenderResult.KilledArmies.. " died], #specials "..#defenderResult.SurvivingSpecials.." ["..#defenderResult.KilledSpecials.. " died, ".. #defenderResult.ClonedSpecials .." cloned]");
	-- print ("[ATTACKER RESULT] #armies "..attackerResult.RemainingArmies .." ["..attackerResult.KilledArmies.. " died], #specials "..#attackerResult.SurvivingSpecials.." ["..#attackerResult.KilledSpecials.. " died, ".. #attackerResult.ClonedSpecials .." cloned]");
	local damageToAllSpecialUnits = concatenateArrays (attackerResult.DamageToSpecialUnits, defenderResult.DamageToSpecialUnits); --combine elements from each array for attacker/defender to get a single array
	for k,v in pairs (defenderResult.DamageToSpecialUnits) do print ("[SU Def damage] SU "..k..", damage "..v); end
	for k,v in pairs (attackerResult.DamageToSpecialUnits) do print ("[SU Att damage] SU "..k..", damage "..v); end
	for k,v in pairs (damageToAllSpecialUnits) do print ("[SU Both damage] SU "..k..", damage "..v); end

	--if all of defender's armies & SUs are killed & attacker still has at least 1 army or SU surviving, attack is successful, transfer the armies
	--note that both sides reduced to 0 means attack is unsuccessful, territory not captured
	if (defenderResult.RemainingArmies == 0 and #defenderResult.SurvivingSpecials == 0 and (attackerResult.RemainingArmies >0 or #attackerResult.SurvivingSpecials >0)) then
		--defender is eliminated, attacker wins
		boolAttackSuccessful = true;
	else
		--defender survives, attacker may have lost some units
	end

	--if this battle is being processed as a WZ attackTransfer order, then update the result here to reflect the true results of the attack
	--if it is not an actual WZ attack/transfer order, then just pass the results back and let the calling function handle the details in a manner appropriately for whatever the use case is
	--result.IsSuccessful cannot be directly updated, but by updating the actual.AttackingArmies, actual.DefendingArmies, result.AttackingArmiesKilled & result.DefendingArmiesKilled, the result will be processed correctly by the WZ engine
	if (boolWZattackTransferOrder == true) then
		local newResult = result;
		newResult.AttackingArmiesKilled = WL.Armies.Create (attackerResult.KilledArmies, attackerResult.KilledSpecialsObjects);
		newResult.DefendingArmiesKilled = WL.Armies.Create (defenderResult.KilledArmies, defenderResult.KilledSpecialsObjects);
		newResult.DamageToSpecialUnits = damageToAllSpecialUnits; --assign damage done to SUs for both attacker & defender
		result = newResult;
	end
	-- ^^ this doesn't work; the 'result' object isn't updating properly, so must leave it to the calling function to update itself
	-- the 'result' object received here is likely a Lua copy of the original object, so changes don't propagate back to the original object when _Order function ends
	-- ^^^ but it should work now b/c instead of modifying result.X properties directly, it copies it to newResult, modifies those properties and saves it back to result=newResult -- this should work now

	return ({AttackerResult=attackerResult, DefenderResult=defenderResult, IsSuccessful=boolAttackSuccessful, DamageToSpecialUnits=damageToAllSpecialUnits, Result=result, AttackingArmiesKilled=WL.Armies.Create (attackerResult.KilledArmies, attackerResult.KilledSpecialsObjects), DefendingArmiesKilled=WL.Armies.Create (defenderResult.KilledArmies, defenderResult.KilledSpecialsObjects)});
end

--gives the player a free Reconnaissance card already played on targetTerritoryID, used to grant vision of the outcome of a neutral order
function GiveFreeReconOfTerritory(playerID, targetTerritoryID, addNewOrder)
    local instance = WL.NoParameterCardInstance.Create(WL.CardID.Reconnaissance);
    addNewOrder(WL.GameOrderReceiveCard.Create(playerID, { instance }));
    addNewOrder(WL.GameOrderPlayCardReconnaissance.Create(instance.ID, playerID, targetTerritoryID));
end

--returns territoryID plus all of its directly connected neighbours, used to mimic the area a recon card reveals
function GetTerritoryAndAdjacentIDs(game, territoryID)
    local territories = { territoryID };
    for neighbourID, _ in pairs(game.Map.Territories[territoryID].ConnectedTo) do
        table.insert(territories, neighbourID);
    end
    return territories;
end

--manually grants playerID vision of targetTerritoryID and its neighbours for one turn by adding a high priority FogMod
--to 'event', restricted to that player only; the FogMod is tracked in PrivateGameData so Server_AdvanceTurn_Start can
--remove it again after that one turn of vision has been shown
function GrantManualVisionOfTerritory(game, event, playerID, targetTerritoryID)
    local territories = GetTerritoryAndAdjacentIDs(game, targetTerritoryID);
    local fogMod = WL.FogMod.Create("Order Neutral - manual vision", WL.StandingFogLevel.Visible, 9000, territories, { playerID });
    event.FogModsOpt = { fogMod };

    local privateGameData = Mod.PrivateGameData;
    if (privateGameData.PendingVisionFogModIDs == nil) then privateGameData.PendingVisionFogModIDs = {}; end;
    table.insert(privateGameData.PendingVisionFogModIDs, fogMod.ID);
    Mod.PrivateGameData = privateGameData;
end

--removes any manually granted vision FogMods added last turn, so the vision they grant lasts exactly one turn
function RemoveExpiredVisionFogMods(addNewOrder)
    local privateGameData = Mod.PrivateGameData;
    local pendingIDs = privateGameData.PendingVisionFogModIDs;
    if (pendingIDs == nil or #pendingIDs == 0) then return; end;

    local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, "Order Neutral vision expired", {}, {});
    event.RemoveFogModsOpt = pendingIDs;
    addNewOrder(event);

    privateGameData.PendingVisionFogModIDs = nil;
    Mod.PrivateGameData = privateGameData;
end

--builds a "X armies, Special Unit Name, Special Unit Name" style description of a moving force
function DescribeArmyMovement (numArmies, specialUnits)
	local parts = { numArmies .. " armies" };
	for _, unit in pairs (specialUnits) do
		table.insert (parts, GetSpecialUnitName(unit));
	end
	return table.concat (parts, ", ");
end

function GetSpecialUnitName (unit)
	if (unit.proxyType == "CustomSpecialUnit") then
		return unit.Name;
	end
	return unit.proxyType; --eg "Commander"
end

--WZ rejects a single TerritoryModification.AddSpecialUnits with more than 4 entries ("Cannot add more than 4 special
--units"), so large attacking/transferring forces (eg. 6 tanks) need to be split up. Sets targetMod.AddSpecialUnits to
--the first chunk (<=4 units) and returns an array of any leftover chunks (each itself an array of <=4 units) that
--didn't fit; pass those to QueueExtraSpecialUnitEvents once the primary event has been added, so they arrive as
--their own follow-up events rather than as extra TerritoryModifications on the same event (which don't reliably
--apply beyond the first one)
function AssignAddSpecialUnits(targetMod, specialUnits)
	local MAX_SPECIAL_UNITS_PER_MOD = 4;

	local chunks = {};
	local chunk = {};
	for _, unit in pairs(specialUnits) do
		table.insert(chunk, unit);
		if (#chunk >= MAX_SPECIAL_UNITS_PER_MOD) then
			table.insert(chunks, chunk);
			chunk = {};
		end
	end
	if (#chunk > 0) then
		table.insert(chunks, chunk);
	end

	if (#chunks > 0) then
		targetMod.AddSpecialUnits = chunks[1];
	end

	local extraChunks = {};
	for i = 2, #chunks do
		table.insert(extraChunks, chunks[i]);
	end
	return extraChunks;
end

--queues a follow-up GameOrderEvent per leftover chunk returned by AssignAddSpecialUnits, each just adding that
--chunk of special units to territoryID; call this after the primary event for the order has already been queued
function QueueExtraSpecialUnitEvents(territoryID, extraChunks, playerID, addNewOrder)
	for _, chunk in ipairs(extraChunks) do
		local extraMod = WL.TerritoryModification.Create(territoryID);
		extraMod.AddSpecialUnits = chunk;
		addNewOrder(WL.GameOrderEvent.Create(WL.PlayerID.Neutral, "Managing special units", { playerID }, { extraMod }));
	end
end

function territoryHasActiveShield (territory)
	if not territory then return false; end

	for _, specialUnit in pairs (territory.NumArmies.SpecialUnits) do
		if (specialUnit.proxyType == 'CustomSpecialUnit' and specialUnit.Name == 'Shield') then
			return (true);
		end
	end

	return (false);
end

--process damage quantity 'totalDamage' to the Specials in table 'sortedSpecialUnits' and the armies in 'armyCount'
--Specials are already stored in table in order of their CombatOrder
--the combo of (sortedSpecialUnits+armyCount) is either the Attacker and totalDamage is damage from defender units, or the combo is the Defender and totalDamage is damage from attacker units
--this function will be called once for each case, once for the Attacker and once for the Defender
--boolWZattackTransferOrder of true - ...document me...
--arrInvulnerableSpecials -- string non-sequential array with keys of SUs and value of the ModID the SU comes from, indicating SUs which  should be treated as invulnerable and not take damage (but not prevent other units from taking damage, they just can't take damage 
--		or die themselves; essentially ignored as part of the attack); currently this is used only in the case of the Flag and Captured Flag SUs from the Capture the Flag mod (mod #384); currently just comparing the SU names, not comparing the SU IDs or originating Mod ID
function apply_damage_to_specials_and_armies (sortedSpecialUnits, armyCount, totalDamage, game, addNewOrder, boolWZattackTransferOrder, arrInvulnerableSpecials)
	local remainingDamage = totalDamage;
	local boolArmiesProcessed = false;
	local remainingArmies = armyCount;
	local survivingSpecials = {};
	local killedSpecialsGUIDs = {};
	local killedSpecialsObjects = {};
	local clonedSpecials = {};
    local damageToSpecialUnits = {};
	local strDummyPlaceHolder = "|dummyPlaceholder|applyDamageToArmies";

	table.insert (sortedSpecialUnits, {CombatOrder=1, proxyType=strDummyPlaceHolder}); --add a dummy element to the end of the table to ensure armies are processed if they haven't been processed so far (if all specials have CombatOrder<0)

	--process Specials with combat orders below armies first, then process the armies, then process the remaining Specials
	for k,v in ipairs (sortedSpecialUnits) do
		local newSpecialUnit_clone = nil;
        local boolCurrentSUdamaged = false;
		--Properties Exist for Commander: ID, guid, proxyType, CombatOrder <--- and that's it!
		--Properties DNE for Commander: AttackPower, AttackPowerPercentage, DamageAbsorbedWhenAttacked, DamageToKill, DefensePower, DefensePowerPercentage, Health
		local boolCurrentSpecialSurvives = true;

		if (v.proxyType == strDummyPlaceHolder) then
			boolCurrentSpecialSurvives = false; --don't add this to the survivingSpecials table
			--don't do anything other than let the loop continue 1 last iteration to apply damage to the armies
			--this item has CombatOrder==0 but it is placed last into the table just to ensure that at least 1 element has >0 CombatOrder so that the loop will process damage on the armies if there is remainingDamage left
		end

		--if there's no more damage to apply, skip the code to apply any further damage; could also use 'break' to exit the loop		
		--first check if CombatOrder indicates that it's time to apply damage to armies, then apply damage to Specials thereafter if damage is remaining
		--1 iteration through loop can apply damage to both armies and then 1 Special (the current Special being iterated on in the loop representing the current element of the table being looped through)
		if (remainingDamage >0) then
			if (boolArmiesProcessed==false and v.CombatOrder >0) then --if armies haven't had damage applied yet and this Special has combat order of >0 then apply damage to armies
				--apply damage to armies
				if (remainingArmies == 0) then
				elseif (remainingDamage >= remainingArmies) then
					remainingDamage = math.max (0, remainingDamage - remainingArmies);
					remainingArmies = 0;
				else
					--apply damage to armies of amount remainingDamage
					remainingArmies = math.max (0, remainingArmies - remainingDamage);
					remainingDamage = 0;
				end
				boolArmiesProcessed = true;
			end

			--damage to armies may have occurred already depending on CombatOrder value of current special, and this may have depleted all remaining damage
			--if there's still damage to apply, apply it to this Special
			if (remainingDamage > 0) then
				if (v.proxyType=="Commander") then
					if (remainingDamage >=7) then
						remainingDamage = math.max (0, remainingDamage - 7);
						boolCurrentSpecialSurvives = false; --remove commander (don't stop processing; it might not be this player's commander, game needs to continue to cover all cases)
						local publicGameData = Mod.PublicGameData;
						local commanderOwner = v.OwnerID;
						if (publicGameData.CardData == nil) then publicGameData.CardData = {}; end
						publicGameData.CardData.ResurrectionCardID = tostring(getCardID ("Resurrection", game));
						local CommanderOwner_ResurrectionCard = playerHasCard (commanderOwner, publicGameData.CardData.ResurrectionCardID, game); --get card instance ID of player's Resurrection card
						print ("[RESURRECTION CHECK] Res cardID " ..tostring (publicGameData.CardData.ResurrectionCardID)..", Res card instance ID ".. tostring (CommanderOwner_ResurrectionCard));

						if (CommanderOwner_ResurrectionCard~=nil) then
							--addNewOrder(WL.GameOrderEvent.Create(commanderOwner, "[Resurrection|Invoke]", {}, {}, {}, {}), true); --add event, use 'true' so this order is skipped if the order that kills the Commander is skipped
							-- addNewOrder(WL.GameOrderCustom.Create(commanderOwner, "a", "b"), false); --add order, use 'true' so this new order is skipped if the order that kills the Commander is skipped
							--reference: WL.GameOrderCustom.Create(playerID PlayerID, message string, payload string, costOpt Table<ResourceType (enum),integer>) (static) returns GameOrderCustom:
							local strResurrectionInvoke = "Resurrection|Invoke|"..commanderOwner.."|"..tostring(CommanderOwner_ResurrectionCard);
							addNewOrder(WL.GameOrderCustom.Create (commanderOwner, "Resurrection|Invoke", strResurrectionInvoke), true); --add order, use 'true' so this new order is skipped if the order that kills the Commander is skipped
							-- addNewOrder(WL.GameOrderCustom.Create(commanderOwner, "a", "b"), false); --add order, use 'true' so this new order is skipped if the order that kills the Commander is skipped
							--local airstrikeEvent = WL.GameOrderEvent.Create(gameOrder.PlayerID, strAirStrikeResultText, {}, {sourceTerritory, targetTerritory});

							--local event = WL.GameOrderEvent.Create(castingPlayerID, gameOrder.Description, {}, {impactedTerritory}); -- create Event object to send back to addOrder function parameter
						else
							--local event = WL.GameOrderEvent.Create(castingPlayerID, gameOrder.Description, {}, {impactedTerritory}); -- create Event object to send back to addOrder function parameter
							--ELIM player!

							--elim player NEXT TURN to get updated LastTurnStanding
							addNewOrder (WL.GameOrderEvent.Create (commanderOwner, "Limited Multimove|Commander killed"), true);

							-- local modifiedTerritories = eliminatePlayer (commanderOwner, game.ServerGame.LatestTurnStanding.Territories, true, game.Settings.SinglePlayer);
							-- addNewOrder(WL.GameOrderEvent.Create (commanderOwner, getPlayerName (game, commanderOwner).."'s Commander was killed", {}, modifiedTerritories, {}, {}), true); --add event, use 'true' so this order is skipped if the order that kills the Commander is skipped
							--reference: WL.GameOrderEvent.Create(playerID PlayerID, message string, visibleToOpt HashSet<PlayerID>, terrModsOpt Array<TerritoryModification>, setResourcesOpt Table<PlayerID,Table<ResourceType (enum),integer>>, incomeModsOpt Array<IncomeMod>) (static) returns GameOrderEvent:

							--reference: function eliminatePlayer (playerIds, territories, removeSpecialUnits, isSinglePlayer)
							--eliminatePlayer (commanderOwner, territories, removeSpecialUnits, isSinglePlayer);
							--addNewOrder(WL.GameOrderEvent.Create(winnerId, 'Decided random winner', {}, eliminate(votes.players, game.ServerGame.LatestTurnStanding.Territories, true, game.Settings.SinglePlayer)));
						end
					else
						remainingDamage = 0; --commander survives, no more attacks to occur
						boolCurrentSpecialSurvives = true; --add commander to survivingSpecials table
					end
				elseif (v.proxyType=="CustomSpecialUnit") then

					--check if this SU is invulnerable and if so, skip it and process the next SU in the list; currently this is only use for the Flag & Captured Flag SUs in the Capture the Flag mod (Mod #384)
					if (arrInvulnerableSpecials ~= nil and arrInvulnerableSpecials [v.Name] ~= nil) then
						--this is invulnerable unit -- don't process it, ensure it's marked as surviving (so it's not removed) & taking no damage (so it's not cloned with new health)
						boolCurrentSpecialSurvives = true; --this is default, don't need to set it, but doing it here for clarity
						boolCurrentSUdamaged = false; --this is default, don't need to set it, but doing it here for clarity
					else
						--not an invulnerable SU, so process it according to v.DamageAbsorbedWhenAttacked / v.Health / v.DamageToKill

						--absorb damage only applies to SUs that don't use Health; if they use Health, DamageAbsorbedWhenAttacked is ignored during regular WZ attacks; mimic that functionality here (even if both DamageAbsorbedWhenAttacked & Health are specified on an SU)
						--SUs use either (A) Health or (B) DamageToKill + DamageAbsorbedWhenAttacked; if Health is specified, the other 2 properties are ignored
						if (v.DamageAbsorbedWhenAttacked ~= nil and v.Health == nil) then 
                            remainingDamage = math.max (0, remainingDamage - v.DamageAbsorbedWhenAttacked);end
						if (v.Health ~= nil) then --SU uses Health (not DamageToKill + DamageAbsorbedWhenAttacked)
							if (v.Health == 0) then
								boolCurrentSpecialSurvives = false; --remove special from survivingSpecials table & add to killedSpecialsGUIDs table
							elseif (remainingDamage >= v.Health) then
								remainingDamage = remainingDamage - v.Health;
								boolCurrentSpecialSurvives = false; --remove special from survivingSpecials table & add to killedSpecialsGUIDs table
							else
								--apply damage to special of amount remainingDamage
								--2 cases need to be handled here, as follows; provide information to handle both, and let the calling function handle the resulting actions appropriately
								--     (case 1) [Limited Multimove] using standard WZ attack order - track damage to SUs and return in a table to be applied via the attack order
								--     (case 2) [Airstrike] using totally manual attack order - must clone damaged SUs with the new remaining health and store the SUs in a table

								--(applies to both case 1 & case 2)
								boolCurrentSpecialSurvives = true; --add cloned special to survivingSpecials table
								boolCurrentSUdamaged = true; --indicates that this SU has been damaged, so it needs to be cloned and added to the survivingSpecials table
								--(case 1) track damage done to SU
								local intNewSUhealthAfterDamage = v.Health-remainingDamage;
								damageToSpecialUnits [v.ID] = remainingDamage; --assign damage done to damageToSpecialUnits table so it can be applied to the SU via the WZ engine as part of the attackTransfer order
								remainingDamage = 0; --no more damage left to process
								--reference: ---@field DamageToSpecialUnits table<GUID, integer> # The damage done to special units, only when they are not killed

								--(case 2) clone/recreate the SU with new health level; only do this if not using WZ attackTransfer order which would apply damage to the SU w/o need for cloning with new health level
								if (boolWZattackTransferOrder == false) then
									local newSpecialUnitBuilder = WL.CustomSpecialUnitBuilder.CreateCopy(v);
									newSpecialUnitBuilder.Health = intNewSUhealthAfterDamage;
									--newSpecialUnitBuilder.Name = newSpecialUnitBuilder.Name.."(C)"; --FOR TESITNG PURPOSES: append (C) to name so it's visible in-game that it's a cloned unit
									newSpecialUnit_clone = newSpecialUnitBuilder.Build();
								end
							end
						else   --SU uses DamageToKill + DamageAbsorbedWhenAttacked (not Health)
							if (remainingDamage > v.DamageToKill) then
								remainingDamage = math.max (0, remainingDamage - v.DamageToKill);
								boolCurrentSpecialSurvives = false; --remove special from survivingSpecials table
								--printDebug ("boolCurrentSpecialSurvives "..tostring(boolCurrentSpecialSurvives));
							else
								--apply damage to special of amount remainingDamage
								boolCurrentSpecialSurvives = true; --add special to survivingSpecials table
								remainingDamage = 0;
							end
						end
					end
				end
			end
		end

		--cases to account for
		-- SAME ACTION:
			-- CASE: attackorder + survive + no damage = add to survivingSpecials
			-- CASE: non-attackorder + survive + no damage = add to survivingSpecials
		-- CASE: attackorder + survive + damage = add to survivingSpecials + damageToSpecialUnits
		-- CASE: non-attackorder + survive + damage = add clone to clonedSpecials + survivingSpecials + damageToSpecialUnits + add orig to killedSpecialsGUIDs & killedSpecialsObjects
		-- SAME ACTION:
			-- CASE: non-attackorder + dies = add to killedSpecialsGUIDs & killedSpecialsObjects
			-- CASE: attackorder + dies = add to killedSpecialsGUIDs & killedSpecialsObjects

		--the Special being analyzed this iteration through loop has already DIED or SURVIVED by this opint, add to survivingSpecials table if it survived
		--printDebug ("boolCurrentSpecialSurvives "..tostring(boolCurrentSpecialSurvives));
		if (boolCurrentSpecialSurvives == true) then --the Special survived; but it may have (A) taken no damage, in which case just add it to the survivingSpecials table, or (B) taken damage (if so it has been cloned and need to replace it with the new cloned Special and add that to the table)
			if (boolCurrentSUdamaged == false) then
				-- SAME ACTION for both cases:
					-- CASE: attackorder + survive + no damage = add to survivingSpecials
					-- CASE: non-attackorder + survive + no damage = add to survivingSpecials
				table.insert (survivingSpecials, v);
			elseif (boolWZattackTransferOrder == true and boolCurrentSUdamaged == true) then
				--CASE: attackorder + survive + damage = add to survivingSpecials + damageToSpecialUnits
				table.insert (survivingSpecials, v);
				--damageToSpecialUnits modified earlier in code
			elseif (boolWZattackTransferOrder == false) then
				--CASE: non-attackorder + survive + damage = add clone to clonedSpecials + survivingSpecials + damageToSpecialUnits + add orig to killedSpecialsGUIDs & killedSpecialsObjects
				if (newSpecialUnit_clone == nil) then --the Special Unit survived & didn't need to be cloned, just add the original to the survivingSpecials table
					table.insert (survivingSpecials, v);
				else   --the Special Unit survived but needed to be cloned, add the new cloned Special to the survivingSpecials table & add the original to the killedSpecialsGUIDs table (this isn't totally accurate since it wasn't killed per se, 
					--but this mechanism is used to remove it from the source territory & not add it to the target territory if the attack if successful)
						-- CASE: non-attackorder + survive + damage = add clone to clonedSpecials + survivingSpecials + damageToSpecialUnits + add orig to killedSpecialsGUIDs & killedSpecialsObjects
						table.insert (survivingSpecials, newSpecialUnit_clone); --add the new cloned Special to the survivingSpecials table; SUs in this table will be added to the target territory if attack is successful
						table.insert (killedSpecialsGUIDs, v.ID); --add the GUID of the original Special to the killedSpecialsGUIDs table
						table.insert (killedSpecialsObjects, v);  --add the original Special object to the killedSpecialsGUIDs table
						table.insert (clonedSpecials, newSpecialUnit_clone); --add the new cloned Special to the clonedSpecials table; if attack is unsuccessful, attacking SUs in this table need to be added to the source territory & defending SUs in this table need to be added to the target territory
						--newSpecialUnit_clone = nil; --reset the clone to nil for next iteration through the loop --> actually don't need to b/c moved the declaration inside the loop
				end
			end
		else
			-- SAME ACTION:
				-- CASE: non-attackorder + dies = add to killedSpecialsGUIDs & killedSpecialsObjects
				-- CASE: attackorder + dies = add to killedSpecialsGUIDs & killedSpecialsObjects
			if (v.proxyType ~= strDummyPlaceHolder) then table.insert (killedSpecialsGUIDs, v.ID); table.insert (killedSpecialsObjects, v); end --only add the Special to the killedSpecialsGUIDs & killedSpecialsObjects table if it dies, ignore the dummy placeholder
		end
	end

	local damageResult = {RemainingArmies=remainingArmies, KilledArmies=math.max (0, armyCount-remainingArmies), SurvivingSpecials=survivingSpecials, KilledSpecials=killedSpecialsGUIDs, KilledSpecialsObjects=killedSpecialsObjects, ClonedSpecials=clonedSpecials, DamageToSpecialUnits=damageToSpecialUnits};
	return damageResult;

	--reference
	--[[local impactedTerritory = WL.TerritoryModification.Create(terrID);
	local modifiedTerritories = {};
	impactedTerritory.RemoveSpecialUnitsOpt = {shieldDataRecord.specialUnitID};
	table.insert(modifiedTerritories, impactedTerritory);]]

end

function applyDamageToSpecials (intDamage, Specials, result)
	local remainingDamage = intDamage;
	for k,v in pairs (Specials) do
		if (remainingDamage > 0) then
			--if the Special is still alive, apply damage to it
			local SpecialHealth = v.Health;
			if (SpecialHealth > 0) then
				local SpecialDamage = math.min (SpecialHealth, remainingDamage);
				remainingDamage = remainingDamage - SpecialDamage;
				result = WL.Armies.Create (result.NumArmies + SpecialDamage, result.SpecialUnits);
			end
		end
	end
	return result;

end

--concatenate elements of 2 arrays, return resulting array; elements do not need to be consecutive or numeric; if both arrays use the same keys, array2 will overwrite the values of array1 where the keys overlap
function concatenateArrays (array1, array2)
	local result = array1; --start with the first array, then add the elements of the 2nd array to it
	for k,v in pairs (array2) do
		result[k] = array2[k];
	end
	return result
end

function NewIdentity()
	local data = Mod.PublicGameData;
	local ret = data.Identity or 1;
	data.Identity = ret + 1;
	Mod.PublicGameData = data;
	return ret;
end

function Dump(obj)
	if obj.proxyType ~= nil then
		DumpProxy(obj);
	elseif type(obj) == 'table' then
		DumpTable(obj);
	else
		print('Dump ' .. type(obj));
	end
end
function DumpTable(tbl)
    for k,v in pairs(tbl) do
        print('k = ' .. tostring(k) .. ' (' .. type(k) .. ') ' .. ' v = ' .. tostring(v) .. ' (' .. type(v) .. ')');
    end
end
function DumpProxy(obj)

    print('type=' .. obj.proxyType .. ' readOnly=' .. tostring(obj.readonly) .. ' readableKeys=' .. table.concat(obj.readableKeys, ',') .. ' writableKeys=' .. table.concat(obj.writableKeys, ','));
end

--splits str on literal separator pat (not a Lua pattern); uses plain-text find rather than the lazy "(.-)" pattern
--match, since that recurses once per unmatched character and hits Lua's "pattern too complex" limit on long strings
--(eg. a comma-separated list of several special unit GUIDs)
function split(str, pat)
   local t = {}
   local last_end = 1
   local first = true
   local s, e = str:find(pat, 1, true)
   while s do
      local cap = str:sub(last_end, s - 1);
      if not (first and cap == "") then
         table.insert(t, cap);
      end
      first = false;
      last_end = e + 1
      s, e = str:find(pat, last_end, true)
   end
   if last_end <= #str then
      table.insert(t, str:sub(last_end));
   end
   return t
end


function map(array, func)
	local new_array = {}
	local i = 1;
	for _,v in pairs(array) do
		new_array[i] = func(v);
		i = i + 1;
	end
	return new_array
end


function filter(array, func)
	local new_array = {}
	local i = 1;
	for _,v in pairs(array) do
		if (func(v)) then
			new_array[i] = v;
			i = i + 1;
		end
	end
	return new_array
end

function removeWhere(array, func)
	for k,v in pairs(array) do
		if (func(v)) then
			array[k] = nil;
		end
	end
end

function first(array, func)
	for _,v in pairs(array) do
		if (func == nil or func(v)) then
			return v;
		end
	end
	return nil;
end

function randomFromArray(array)
	local len = #array;
	local i = math.random(len);
	return array[i];
end

function startsWith(str, sub)
	return string.sub(str, 1, string.len(sub)) == sub;
end

function shuffle(tbl)
	for i = #tbl, 2, -1 do
		local j = math.random(i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
end

function groupBy(tbl, funcToGetKey)
	local ret = {};
	for k,v in pairs(tbl) do
		local key = funcToGetKey(v);
		local group = ret[key];
		if (group == nil) then
			group = {};
			ret[key] = group;
		end
		table.insert(group, v);
	end

	return ret;
end

function TrimWhitespace(s)
    return s:match "^%s*(.-)%s*$"
end

function ParseCommaDelimitedString(str)
	local result = {}
    local start = 1
    while true do
        local commaPos = string.find(str, ',', start)
        if commaPos then
            local value = TrimWhitespace(string.sub(str, start, commaPos - 1));
			if (#value > 0) then table.insert(result, value); end;
            start = commaPos + 1
        else
            -- If there's no more commas, take the remaining part of the string
            local value = TrimWhitespace(string.sub(str, start));
            if (#value > 0) then table.insert(result, value); end;
            break
        end
    end
    return result
end

function GetButtonColors()
    return {
        Blue = "#0000FF"; 
        Purple = "#59009D"; 
        Orange = "#FF7D00"; 
        DarkGray = "#606060"; 
        HotPink = "#FF697A"; 
        SeaGreen = "#00FF8C"; 
        Teal = "#009B9D"; 
        DarkMagenta = "#AC0059"; 
        Yellow = "#FFFF00"; 
        Ivory = "#FEFF9B"; 
        ElectricPurple = "#B70AFF"; 
        DeepPink = "#FF00B1"; 
        Aqua = "#4EFFFF"; 
        DarkGreen = "#008000"; 
        Red = "#FF0000"; 
        Green = "#00FF05"; 
        SaddleBrown = "#94652E"; 
        OrangeRed = "#FF4700"; 
        LightBlue = "#23A0FF"; 
        Orchid = "#FF87FF"; 
        Brown = "#943E3E"; 
        CopperRose = "#AD7E7E"; 
        Tan = "#FFAF56"; 
        Lime = "#8EBE57"; 
        TyrianPurple = "#990024"; 
        MardiGras = "#880085"; 
        RoyalBlue = "#4169E1"; 
        WildStrawberry = "#FF43A4"; 
        SmokyBlack = "#100C08"; 
        Goldenrod = "#DAA520"; 
        Cyan = "#00FFFF"; 
        Artichoke = "#8F9779"; 
        RainForest = "#00755E"; 
        Peach = "#FFE5B4"; 
        AppleGreen = "#8DB600"; 
        Viridian = "#40826D"; 
        Mahogany = "#C04000";
        PinkLace = "#FFDDF4";
        Bronze = "#CD7F32";
        WoodBrown = "#C19A6B";
        Tuscany = "#C09999";
        AcidGreen = "#B0BF1A";
        Amazon = "#3B7A57";
        ArmyGreen = "#4B5320";
        DonkeyBrown = "#664C28";
        Cordovan = "#893F45";
        Cinnamon = "#D2691E";
        Charcoal = "#36454F";
        Fuchsia = "#FF00FF";
        ScreaminGreen = "#76FF7A";
    };
end

--given 0-255 RGB integers, return a single 24-bit integer, useful for annotations
function GetColourInteger (red, green, blue)
	return red*256^2 + green*256 + blue;
end

--given a hex colour string like "#RRGGBB", return a single 24-bit integer
function GetColourIntegerFromHex(hexColour)
    local normalized = string.gsub(hexColour, "#", "");
    return tonumber(normalized, 16);
end

TEXT_DEFAULT_COLOUR = "#CCCCCC";
BUTTON_COLOURS = GetButtonColors();
ERROR_COLOUR = BUTTON_COLOURS.Red;
SUBHEADING_COLOUR = BUTTON_COLOURS.Yellow;
SUBHEADING_COLOUR2 = BUTTON_COLOURS.LightBlue;
