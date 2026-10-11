Actions = {};

---Plain, resolved inputs every triggered action needs.
---@class DeadManSwitchTriggerContext
---@field TerritoryID TerritoryID # The territory the triggered Dead Man's Switch(es) were on
---@field AttackerPlayerID PlayerID # The player who captured the territory, is shown every event, and is the fallback recipient of any card that would otherwise go to a neutral DefendingPlayerID
---@field DefendingPlayerID PlayerID # The territory's owner at the moment of triggering. Usually equal to AttackerPlayerID (a successful capture already transferred ownership), but can be WL.PlayerID.Neutral - some cards have no real recipient/target in that case
---@field ArmiesOnArrival integer # Armies left on the territory immediately after the capture, before any Dead Man's Switch damage

---Adds the event that shows a DMS was triggered, applying the DMS territory modification
---@param context DeadManSwitchTriggerContext
---@param territoryModification TerritoryModification # The DMS territory modification to attach to the event
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean) # Adds a game order, the second argument skips it if the triggering order is skipped
function AddTriggeredEvent(context, territoryModification, addNewOrder)
	local event = WL.GameOrderEvent.Create(context.AttackerPlayerID, "Triggered a Dead Man's Switch", {}, {territoryModification});
	event.TerritoryAnnotationsOpt = { [context.TerritoryID] = WL.TerritoryAnnotation.Create("Triggered DMS", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
	event.Icon = "Triggered";
	addNewOrder(event, true);
end
