require('Utilities')

--Called when the player attempts to play your card.  You can call playCard directly if no UI is needed, or you can call game.CreateDialog to present the player with options.
--If your mod has multiple cards, you can look at game.Settings.Cards[cardInstance.CardID].Name to see which one was played
function Client_PresentPlayCardUI(game, cardInstance, playCard, closeCardsDialog)
    Game = game;

    --If this dialog is already open, close the previous one. This prevents two copies of it from being open at once which can cause errors due to only saving one instance of TargetTerritoryBtn
    if (Close ~= nil) then
        Close();
    end

    closeCardsDialog();

    game.CreateDialog(function(rootParent, setMaxSize, setScrollable, game, close)
        Close = close;
        setMaxSize(400, 200);
        local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1); --set flexible width so things don't jump around while we change InstructionLabel

        if game.Settings.Cards == nil or game.Settings.Cards[WL.CardID.Bomb] == nil then
            WarningLabel = UI.CreateLabel(vert).SetText("Bombs must be enabled for this mod to work.  Please enable bombs in the game settings.");
        else
            TargetTerritoryBtn = UI.CreateButton(vert).SetText("Select Territory").SetOnClick(TargetTerritoryClicked);
            TargetTerritoryInstructionLabel = UI.CreateLabel(vert).SetText("");

            UI.CreateButton(vert).SetText("Play Card").SetOnClick(function() 
                if (TargetTerritoryID == nil) then
                    TargetTerritoryInstructionLabel.SetText("You must select a territory first");
                    return;
                end
                local td = game.Map.Territories[TargetTerritoryID];

                local annotations = { [TargetTerritoryID] = WL.TerritoryAnnotation.Create("Request Dead Man's Switch") };
                local jumpToSpot = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);

                if (playCard("Build a Dead Man's Switch on " .. TargetTerritoryName, "CreateDMS_" .. TargetTerritoryID, WL.TurnPhase.Attacks, annotations, jumpToSpot)) then
                    close();
                end
            end);
        end
    end);
end



function TargetTerritoryClicked()
	UI.InterceptNextTerritoryClick(TerritoryClicked);
	TargetTerritoryInstructionLabel.SetText("Please click on the territory you wish to create the Dead Man's Switch on.  If needed, you can move this dialog out of the way.");
	TargetTerritoryBtn.SetInteractable(false);
end


function TerritoryClicked(terrDetails)
	if UI.IsDestroyed(TargetTerritoryBtn) then
		-- Dialog was destroyed, so we don't need to intercept the click anymore
		return WL.CancelClickIntercept; 
	end
	TargetTerritoryBtn.SetInteractable(true);


	if (terrDetails == nil) then
		--The click request was cancelled.   Return to our default state.
		TargetTerritoryInstructionLabel.SetText("");
        TargetTerritoryID = nil;
        TargetTerritoryName = nil;
        return;
    end
        
    local terr = Game.LatestStanding.Territories[terrDetails.ID];        
    if (terr.OwnerPlayerID ~= Game.Us.ID) then
        TargetTerritoryInstructionLabel.SetText("You may only select territories you control");
        TargetTerritoryID = nil;
        TargetTerritoryName = nil;
    else
		--Territory was clicked, remember its ID
		TargetTerritoryInstructionLabel.SetText("Selected territory: " .. terrDetails.Name);
		TargetTerritoryID = terrDetails.ID;
        TargetTerritoryName = terrDetails.Name;
	end
end

