require('Utilities')

INSTRUCTION_TEXT = "Please click on the territory you wish to fire the Flak Gun at.";

---Client_PresentPlayCardUI hook
---@param game GameClientHook
---@param cardInstance CardInstance # Read-only data about the card that the player is attempting to play
---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM) # Function that when invoked, will make the player play the card
---@param closeCardsDialog fun() # Function that when invoked will close this cards dialog
function Client_PresentPlayCardUI(game, cardInstance, playCard, closeCardsDialog)
    if (cardInstance.CardID ~= Mod.Settings.FlakGunCardID and cardInstance.CardID ~= Mod.Settings.FlakGunTemporaryCardID) then
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
        setMaxSize(400, 285);
        local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1); --set flexible width so things don't jump around while we change InstructionLabel

        TargetTerritoryInstructionLabel = UI.CreateLabel(vert).SetText(INSTRUCTION_TEXT).SetAlignment(WL.TextAlignmentOptions.Center);

        local buttonsRow = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
        TargetTerritoryBtn = UI.CreateButton(buttonsRow)
            .SetText("Select Territory")
            .SetColor(BUTTON_COLOURS.RoyalBlue)
            .SetPreferredWidth(150)
            .SetFlexibleWidth(1)
            .SetOnClick(TargetTerritoryClicked);
        PlayCardBtn = UI.CreateButton(buttonsRow)
            .SetText("Fire Flak Gun")
            .SetInteractable(false)
            .SetColor(BUTTON_COLOURS.DarkGreen)
            .SetPreferredWidth(150)
            .SetFlexibleWidth(1)
            .SetOnClick(function()
                if (TargetTerritoryID == nil) then
                    TargetTerritoryInstructionLabel.SetText("You must select a territory first").SetColor(ERROR_COLOUR);
                    TargetTerritoryBtn.SetInteractable(true);
                    return;
                end

                local td = game.Map.Territories[TargetTerritoryID];
                local jumpToSpot = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);

                if (playCard("Fire a Flak Gun at " .. TargetTerritoryName, "ShootFlakGun_" .. TargetTerritoryID, WL.TurnPhase.Deploys, {}, jumpToSpot)) then
                    Game.HighlightTerritories({});
                    close();
                end
            end);

        local displayRow = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
        local selectorColumn = UI.CreateVerticalLayoutGroup(displayRow).SetPreferredWidth(120).SetFlexibleWidth(1).SetCenter(true);

        --Territory snapshots and custom art don't exist in app versions below SNAPSHOT_AND_ICON_MIN_VERSION, so only the name label still works there
        TargetTerritorySnapshot = nil;
        TargetTerritorySnapshotVert = nil;
        if (WL.IsVersionOrHigher(SNAPSHOT_AND_ICON_MIN_VERSION)) then
            TargetTerritorySnapshotVert = UI.CreateVerticalLayoutGroup(selectorColumn).SetCenter(true).SetPreferredHeight(60); --fixed height so the row doesn't resize when the snapshot appears
        end
        TargetTerritoryNameLabel = UI.CreateLabel(selectorColumn).SetText(" ").SetAlignment(WL.TextAlignmentOptions.Center);

        if (WL.IsVersionOrHigher(SNAPSHOT_AND_ICON_MIN_VERSION)) then
            local iconColumn = UI.CreateVerticalLayoutGroup(displayRow).SetPreferredWidth(120).SetFlexibleWidth(1).SetCenter(true);
            UI.CreateImage(iconColumn).SetSprite("FlakGun.png").SetPreferredWidth(60).SetPreferredHeight(60);
            UI.CreateLabel(iconColumn).SetText("Bang!").SetAlignment(WL.TextAlignmentOptions.Center).SetColor(BUTTON_COLOURS.DarkGray);
        end

        TargetTerritoryClicked(); --start in selection mode so the player doesn't need to press the button first
    end);
end

--SetTerritoryIDs rejects an empty list, so the snapshot is destroyed to clear it and recreated on the next selection
function ClearTargetSnapshot()
    TargetTerritoryNameLabel.SetText(" ");
    if (TargetTerritorySnapshot == nil) then return; end
    UI.Destroy(TargetTerritorySnapshot);
    TargetTerritorySnapshot = nil;
end

function ShowTargetSnapshot(terrID, name)
    TargetTerritoryNameLabel.SetText(name);
    if (TargetTerritorySnapshotVert == nil) then return; end
    if (TargetTerritorySnapshot == nil) then
        TargetTerritorySnapshot = UI.CreateSnapshot(TargetTerritorySnapshotVert).SetPreferredWidth(60).SetPreferredHeight(60);
    end
    TargetTerritorySnapshot.SetTerritoryIDs({ terrID });
end

function TargetTerritoryClicked()
    Game.HighlightTerritories({}); --clear any territories highlighted from a previous failed/cleared selection
    UI.InterceptNextTerritoryClick(TerritoryClicked);
    TargetTerritoryInstructionLabel.SetText(INSTRUCTION_TEXT).SetColor(TEXT_DEFAULT_COLOUR);
    TargetTerritoryBtn.SetInteractable(false);
    PlayCardBtn.SetInteractable(false);
end

---Updates selection state and highlights the Flak Gun's area of effect (always includes the selected territory
---itself) around whichever territory was clicked.
---@param terrDetails TerritoryDetails | nil
function TerritoryClicked(terrDetails)
    if UI.IsDestroyed(TargetTerritoryBtn) then
        -- Dialog was destroyed, so we don't need to intercept the click anymore
        return WL.CancelClickIntercept;
    end
    TargetTerritoryBtn.SetInteractable(true);

    if (terrDetails == nil) then
        --The click request was cancelled. Return to our default state.
        TargetTerritoryInstructionLabel.SetText(INSTRUCTION_TEXT).SetColor(TEXT_DEFAULT_COLOUR);
        TargetTerritoryID = nil;
        TargetTerritoryName = nil;
        PlayCardBtn.SetInteractable(false);
        ClearTargetSnapshot();
        Game.HighlightTerritories({});
        return;
    end

    --Territory was clicked, remember its ID
    TargetTerritoryInstructionLabel.SetText(INSTRUCTION_TEXT).SetColor(TEXT_DEFAULT_COLOUR);
    TargetTerritoryID = terrDetails.ID;
    TargetTerritoryName = terrDetails.Name;
    ShowTargetSnapshot(terrDetails.ID, terrDetails.Name);
    PlayCardBtn.SetInteractable(true);

    local areaOfEffect = Mod.Settings.FlakGunAreaOfEffect or 0;
    local affectedTerritories = GetTerritoriesWithinDistance(Game, terrDetails.ID, areaOfEffect); --get resultant set of territories that this will effect, always includes the selected territory itself
    Game.HighlightTerritories(affectedTerritories); --highlight the impacted terrs
end
