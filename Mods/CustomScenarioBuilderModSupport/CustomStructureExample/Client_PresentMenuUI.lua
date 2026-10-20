require('Utilities')

function Client_PresentMenuUI(rootParent, setMaxSize, setScrollable, game, close)

	Game = game;
	Close = close;

	setMaxSize(350, 350);

	vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1); --set flexible width so things don't jump around while we change InstructionLabel

	UI.CreateLabel(vert).SetText("CustomStructureExample placements at game start:");
	local placements = (Mod.PublicGameData or {}).CustomStructureExamplePlacements or {};
	local names = {};
	for territoryName, _ in pairs(placements) do
		table.insert(names, territoryName);
	end
	table.sort(names, function(a, b) return string.lower(a) < string.lower(b); end);
	if (#names == 0) then
		UI.CreateLabel(vert).SetText("None");
	else
		for _, territoryName in ipairs(names) do
			UI.CreateLabel(vert).SetText(territoryName .. ": " .. placements[territoryName]);
		end
	end

	SelectTerritoryBtn = UI.CreateButton(vert).SetText("Select Territory").SetOnClick(SelectTerritoryClicked);
	SelectTerritoryBtn.SetInteractable(game.Game.TurnNumber >= 1);
	TargetTerritoryInstructionLabel = UI.CreateLabel(vert).SetText("");

	BuildCustomStructureExampleBtn = UI.CreateButton(vert).SetText("Build CustomStructureExample").SetOnClick(BuildCustomStructureExampleClicked).SetInteractable(false);

end

function SelectTerritoryClicked()
	UI.InterceptNextTerritoryClick(TerritoryClicked);
	TargetTerritoryInstructionLabel.SetText("Please click on the territory you wish to build the CustomStructureExample on.  If needed, you can move this dialog out of the way.");
	SelectTerritoryBtn.SetInteractable(false);
end

function TerritoryClicked(terrDetails)
	if UI.IsDestroyed(SelectTerritoryBtn) then
		-- Dialog was destroyed, so we don't need to intercept the click anymore
		return WL.CancelClickIntercept;
	end

	SelectTerritoryBtn.SetInteractable(true);

	if (terrDetails == nil) then
		--The click request was cancelled.   Return to our default state.
		TargetTerritoryInstructionLabel.SetText("");
		SelectedTerritory = nil;
		BuildCustomStructureExampleBtn.SetInteractable(false);
	else
		--Territory was clicked, remember it
		TargetTerritoryInstructionLabel.SetText("Selected territory: " .. terrDetails.Name);
		SelectedTerritory = terrDetails;
		BuildCustomStructureExampleBtn.SetInteractable(true);
	end
end

function BuildCustomStructureExampleClicked()
	local msg = 'Build a CustomStructureExample on ' .. SelectedTerritory.Name;
	local payload = 'BuildCustomStructureExample_' .. SelectedTerritory.ID;

	local order = WL.GameOrderCustom.Create(Game.Us.ID, msg, payload);

	order.JumpToActionSpotOpt = WL.RectangleVM.Create(SelectedTerritory.MiddlePointX, SelectedTerritory.MiddlePointY, SelectedTerritory.MiddlePointX, SelectedTerritory.MiddlePointY);
	order.TerritoryAnnotationsOpt = { [SelectedTerritory.ID] = WL.TerritoryAnnotation.Create("Build CustomStructureExample") };

	local orders = Game.Orders;
	table.insert(orders, order);
	Game.Orders = orders;

	Close();
end