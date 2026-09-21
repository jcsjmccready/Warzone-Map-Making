require("Utilities.CommonUtils");
require("ModConstants");

---Client_PresentMenuUI hook
---@param rootParent RootParent
---@param setMaxSize fun(width: number, height: number) # Sets the max size of the dialog
---@param setScrollable fun(horizontallyScrollable: boolean, verticallyScrollable: boolean) # Set whether the dialog is scrollable both horizontal and vertically
---@param game GameClientHook
---@param close fun() # Zero parameter function that closes the dialog
function Client_PresentMenuUI(rootParent, setMaxSize, setScrollable, game, close)
    setMaxSize(400, 200);

    local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(vert).SetText(THIS_MOD_KEY .. " test menu").SetColor(SUBHEADING_COLOUR);
    local statusLabel = UI.CreateLabel(vert).SetText("");

    if (game.Us == nil) then
        statusLabel.SetText("Spectators can't create orders.").SetColor(ERROR_COLOUR);
        return;
    end

    UI.CreateButton(vert)
        .SetText("Send test order to " .. OTHER_MOD_KEY)
        .SetColor(BUTTON_COLOURS.DarkGreen)
        .SetOnClick(function()
            AddSendTestOrder(game);
            statusLabel.SetText("Order added, " .. OTHER_MOD_KEY .. " gets it when the turn advances.").SetColor(TEXT_DEFAULT_COLOUR);
        end);
end

---Adds the order that asks this mod's server code to send a test order to the other mod
---@param game GameClientHook
function AddSendTestOrder(game)
    local order = WL.GameOrderCustom.Create(
        game.Us.ID,
        "Ask " .. THIS_MOD_KEY .. " to send a test order to " .. OTHER_MOD_KEY,
        SEND_ORDER_PAYLOAD,
        nil,
        WL.TurnPhase.Attacks);

    -- Orders is a snapshot, so it has to be reassigned for the new order to be kept
    local orders = game.Orders;
    table.insert(orders, order);
    game.Orders = orders;
end
