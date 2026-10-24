# Validation

## Vanilla card dependencies get checked twice

If a mod relies on a vanilla card (Airlift, Spy, Blockade, ...) being enabled - whether a player
plays it normally or the mod plays it programmatically - check for it in two places, not one:

1. **Client-side, in `Client_CreateGame`**: `alert(...)` if `settings.Cards[WL.CardID.X] == nil`, so
   the game creator is warned up front.
2. **Server-side, at the moment the mod actually plays that card**: re-check
   `game.Settings.Cards[WL.CardID.X] ~= nil` immediately before constructing the card's order, even
   though `Client_CreateGame` already warned about it - settings aren't guaranteed to still match at
   runtime (e.g. a cross-mod call, or the setting changing between creation and play). If it's
   missing, cancel the action and emit an event with the message
   `"<Card> card not available - <Mod> action cancelled"` instead of silently doing nothing or
   erroring.
