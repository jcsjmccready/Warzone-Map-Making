function Client_PresentPlayCardUI(game, cardInstance, playCard, closeCardsDialog)
	Game = game;

	if (Close ~= nil) then
		Close();
	end
	closeCardsDialog();

	TargetTerritoryID = nil;
	TargetTerritoryName = nil;

	game.CreateDialog(function(rootParent, setMaxSize, setScrollable, game, close)
		Close = close;
		setMaxSize(400, 200);
		local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

		SelectTerritoryBtn = UI.CreateButton(vert).SetText("Select Territory").SetOnClick(SelectTerritoryClicked);
		TargetTerritoryInstructionLabel = UI.CreateLabel(vert).SetText("");
		PlayCardBtn = UI.CreateButton(vert).SetText("Play Tank").SetInteractable(false).SetOnClick(function()
			if (TargetTerritoryID == nil) then
				TargetTerritoryInstructionLabel.SetText("You must select a territory first");
				return;
			end

			local td = game.Map.Territories[TargetTerritoryID];
			local jumpToSpot = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);

			if (playCard("Build a Tank on " .. TargetTerritoryName, "CreateTank_" .. TargetTerritoryID, WL.TurnPhase.Attacks, {}, jumpToSpot)) then
				close();
			end
		end);
	end);
end

function SelectTerritoryClicked()
	UI.InterceptNextTerritoryClick(TerritoryClicked);
	TargetTerritoryInstructionLabel.SetText("Please click on the territory you wish to build a Tank on.");
	SelectTerritoryBtn.SetInteractable(false);
end

function TerritoryClicked(terrDetails)
	if UI.IsDestroyed(SelectTerritoryBtn) then
		-- Dialog was destroyed, so we don't need to intercept the click anymore
		return WL.CancelClickIntercept;
	end
	SelectTerritoryBtn.SetInteractable(true);

	if (terrDetails == nil) then
		--The click request was cancelled. Return to our default state.
		TargetTerritoryInstructionLabel.SetText("");
		TargetTerritoryID = nil;
		TargetTerritoryName = nil;
		PlayCardBtn.SetInteractable(false);
	elseif (Game.LatestStanding.Territories[terrDetails.ID].OwnerPlayerID ~= Game.Us.ID) then
		TargetTerritoryInstructionLabel.SetText("You may only select territories you control");
		TargetTerritoryID = nil;
		TargetTerritoryName = nil;
		PlayCardBtn.SetInteractable(false);
	else
		--Territory was clicked, remember it
		TargetTerritoryInstructionLabel.SetText("Selected territory: " .. terrDetails.Name);
		TargetTerritoryID = terrDetails.ID;
		TargetTerritoryName = terrDetails.Name;
		PlayCardBtn.SetInteractable(true);
	end
end
