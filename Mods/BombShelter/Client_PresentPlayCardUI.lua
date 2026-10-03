require('Utilities')

---Client_PresentPlayCardUI
---@param game GameClientHook
---@param cardInstance CardInstance # Read-only data about the card that the player is attempting to play
---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM) # Function that when invoked, will make the player play the card
---@param closeCardsDialog fun() # Function that when invoked will close this cards dialog
function Client_PresentPlayCardUI(game, cardInstance, playCard, closeCardsDialog)
    if (cardInstance.CardID ~= Mod.Settings.BombShelterCardID) then
        return;
    end

    Game = game;

    --If this dialog is already open, close the previous one. This prevents two copies of it from being open at once which can cause errors due to only saving one instance of TargetTerritoryBtn
    if (Close ~= nil) then
        Close();
    end

    closeCardsDialog();

    TargetTerritoryID = nil;
    TargetTerritoryName = nil;

    game.CreateDialog(function(rootParent, setMaxSize, setScrollable, game, close)
        Close = close;
        setMaxSize(400, 320);
        local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1); --set flexible width so things don't jump around while we change InstructionLabel
        local buttonsHGroup = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
        TargetTerritoryBtn = UI.CreateButton(buttonsHGroup)
            .SetText("Select Territory")
            .SetOnClick(TargetTerritoryClicked)
            .SetFlexibleWidth(0.3);

        TargetTerritoryInstructionLabel = UI.CreateLabel(vert).SetText("");

        --UI.CreateSnapshot doesn't exist in older app versions, so the snapshot is skipped there
        TargetTerritorySnapshot = nil;
        TargetTerritorySnapshotVert = nil;
        if (UI.CreateSnapshot ~= nil) then
            --holder keeps the snapshot above the name label when it is recreated
            TargetTerritorySnapshotVert = UI.CreateVerticalLayoutGroup(vert).SetFlexibleWidth(1).SetCenter(true);
            TargetTerritoryNameLabel = UI.CreateLabel(vert).SetText(" ").SetAlignment(WL.TextAlignmentOptions.Center);
        end

        PlayCardBtn = UI.CreateButton(buttonsHGroup)
            .SetText("Build Bomb Shelter")
            .SetInteractable(false)
            .SetColor(BUTTON_COLOURS.DarkGreen)
            .SetFlexibleWidth(0.7)
            .SetOnClick(function()
                if (TargetTerritoryID == nil) then
                    TargetTerritoryInstructionLabel.SetText("You must select a territory first").SetColor(ERROR_COLOUR);
                    TargetTerritoryBtn.SetInteractable(true);
                    return;
                end

                local td = game.Map.Territories[TargetTerritoryID];
                local jumpToSpot = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);

                if (playCard("Build a Bomb Shelter on " .. TargetTerritoryName, "BombShelter_" .. TargetTerritoryID, WL.TurnPhase.Attacks, {}, jumpToSpot)) then
                    Game.HighlightTerritories({});
                    close();
                end
            end);
    end);
end

--SetTerritoryIDs rejects an empty list, so the snapshot is destroyed to clear it and recreated on the next selection
function ClearTargetSnapshot()
    if (TargetTerritorySnapshot == nil) then return; end
    UI.Destroy(TargetTerritorySnapshot);
    TargetTerritorySnapshot = nil;
    TargetTerritoryNameLabel.SetText(" ");
end

function ShowTargetSnapshot(terrID, name)
    if (TargetTerritorySnapshotVert == nil) then return; end
    if (TargetTerritorySnapshot == nil) then
        TargetTerritorySnapshot = UI.CreateSnapshot(TargetTerritorySnapshotVert).SetPreferredWidth(100).SetPreferredHeight(100);
    end
    TargetTerritorySnapshot.SetTerritoryIDs({ terrID });
    TargetTerritoryNameLabel.SetText(name);
end

function TargetTerritoryClicked()
    Game.HighlightTerritories({}); --clear any territories highlighted from a previous failed territory selection
    UI.InterceptNextTerritoryClick(TerritoryClicked);
    TargetTerritoryInstructionLabel.SetText("Please click on the territory you wish to build the Bomb Shelter on.").SetColor(TEXT_DEFAULT_COLOUR);
    TargetTerritoryBtn.SetInteractable(false);
    PlayCardBtn.SetInteractable(false);
end

function TerritoryClicked(terrDetails)
    if UI.IsDestroyed(TargetTerritoryBtn) then
        -- Dialog was destroyed, so we don't need to intercept the click anymore
        return WL.CancelClickIntercept;
    end
    TargetTerritoryBtn.SetInteractable(true);

    if (terrDetails == nil) then
        --The click request was cancelled. Return to our default state.
        TargetTerritoryInstructionLabel.SetText("");
        TargetTerritoryID = nil;
        TargetTerritoryName = nil;
        PlayCardBtn.SetInteractable(false);
        ClearTargetSnapshot();
        Game.HighlightTerritories({});
        return;
    end

    local terr = Game.LatestStanding.Territories[terrDetails.ID];
    if (terr.OwnerPlayerID ~= Game.Us.ID) then
        TargetTerritoryInstructionLabel.SetText("You may only select territories you control").SetColor(ERROR_COLOUR);

        TargetTerritoryID = nil;
        TargetTerritoryName = nil;
        PlayCardBtn.SetInteractable(false);
        ClearTargetSnapshot();
        Game.HighlightTerritories({});
    else
        --Territory was clicked, remember its ID
        --The snapshot shows the selection, so the text is only needed when the app is too old to have snapshots
        local selectedText = TargetTerritorySnapshotVert ~= nil and "" or ("Selected territory: " .. terrDetails.Name);
        TargetTerritoryInstructionLabel.SetText(selectedText).SetColor(TEXT_DEFAULT_COLOUR);
        TargetTerritoryID = terrDetails.ID;
        TargetTerritoryName = terrDetails.Name;
        ShowTargetSnapshot(terrDetails.ID, terrDetails.Name);
        PlayCardBtn.SetInteractable(true);
        Game.HighlightTerritories({TargetTerritoryID});
    end
end
