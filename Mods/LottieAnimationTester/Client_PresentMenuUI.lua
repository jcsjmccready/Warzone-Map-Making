require("Utilities");

---Client_PresentMenuUI hook
---@param rootParent RootParent
---@param setMaxSize fun(width: number, height: number) # Sets the max size of the dialog
---@param setScrollable fun(horizontallyScrollable: boolean, verticallyScrollable: boolean) # Set whether the dialog is scrollable both horizontal and vertically
---@param game GameClientHook
---@param close fun() # Zero parameter function that closes the dialog
function Client_PresentMenuUI(rootParent, setMaxSize, setScrollable, game, close)
    setMaxSize(600, 520);
    setScrollable(false, true);

    local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(vert).SetText("Lottie Animation Tester").SetColor(SUBHEADING_COLOUR);

    if (game.Us == nil) then
        UI.CreateLabel(vert).SetText("Spectators can't create orders.").SetColor(ERROR_COLOUR);
        return;
    end

    UI.CreateLabel(vert).SetText(
        "1. Paste the JSON output of lottie_to_warzone.py below and click Submit Animation. " ..
        "2. Once the upload completes, click Add Testing Order to trigger it in-game.");

    local lastSubmittedLabel = UI.CreateLabel(vert).SetText("");
    LastSubmittedLabel = lastSubmittedLabel; -- lets Submit/Clear (and the uploader, on completion) keep this updated
    RefreshLastSubmittedLabel();

    local statusLabel = UI.CreateLabel(vert).SetText("");
    UploadStatusLabel = statusLabel; -- lets the background chunk uploader (Client_GameRefresh) keep this updated

    -- Forward declared so the buttons above can read it; their closures only run once
    -- clicked, by which point animationField is assigned.
    local animationField;

    UI.CreateButton(vert)
        .SetText("Submit Animation")
        .SetColor(BUTTON_COLOURS.RoyalBlue)
        .SetOnClick(function()
            local jsonText = animationField.GetText();
            if (jsonText == nil or jsonText == "") then
                SetUploadStatus("Paste the lottie_to_warzone.py JSON output above first.");
                return;
            end
            QueueChunkUpload(jsonText);
            SetUploadStatus("Uploading... (0/" .. UploadTotalChunks .. ")");
            TrySendNextChunk(game); -- kick off the first chunk now rather than waiting on Client_GameRefresh
        end);

    UI.CreateButton(vert)
        .SetText("Add Testing Order")
        .SetColor(BUTTON_COLOURS.DarkGreen)
        .SetOnClick(function()
            local order = WL.GameOrderCustom.Create(
                game.Us.ID,
                "Test Lottie animation",
                PAYLOAD_PREFIX, -- just a trigger marker; the real data lives in Mod.PublicGameData
                nil);

            -- Orders is a snapshot, so it has to be reassigned for the new order to be kept
            local orders = game.Orders;
            table.insert(orders, order);
            game.Orders = orders;

            SetUploadStatus("Order added - it will animate once the turn advances.");
        end);

    UI.CreateButton(vert)
        .SetText("Clear Stored Animation")
        .SetColor(BUTTON_COLOURS.Red)
        .SetOnClick(function()
            UploadQueue = {}; -- cancel any upload still in flight before clearing server-side state
            game.SendGameCustomMessage("Clearing stored animation...", { Mod = PAYLOAD_PREFIX, Action = "Clear" }, function(response)
                SetUploadStatus("Cleared stored animation.");
                ShowLastSubmitted(response.HasAnimation, nil);
            end);
        end);

    animationField = UI.CreateTextInputField(vert)
        .SetMultiLine(true)
        .SetPlaceholderText("Paste lottie_to_warzone.py's JSON output here")
        .SetFlexibleWidth(1)
        .SetFlexibleHeight(1)
        .SetPreferredHeight(260);
end
