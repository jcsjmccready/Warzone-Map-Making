require('Utilities')

---Client_PresentPlayCardUI hook
---TODO: gameplay effect for Spy Plane / Flak Gun not yet implemented - this mod currently only scaffolds the
---Configure UI (include checkboxes + standard card piece options) and card registration.
---@param game GameClientHook
---@param cardInstance CardInstance # Read-only data about the card that the player is attempting to play
---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM) # Function that when invoked, will make the player play the card
---@param closeCardsDialog fun() # Function that when invoked will close this cards dialog
function Client_PresentPlayCardUI(game, cardInstance, playCard, closeCardsDialog)
end
