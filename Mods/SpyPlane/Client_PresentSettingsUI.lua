require("Utilities");

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    UI.CreateVerticalLayoutGroup(rootParent);

    local spyPlaneCardVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(spyPlaneCardVGroup).SetText("Spy Plane Card:").SetColor(SUBHEADING_COLOUR);

    local enabledFlightTypes = {};
    if (Mod.Settings.SpyPlaneEnableLineFlight ~= false) then table.insert(enabledFlightTypes, "Line"); end
    if (Mod.Settings.SpyPlaneEnableCircleFlight == true) then table.insert(enabledFlightTypes, "Circle"); end
    if (Mod.Settings.SpyPlaneEnablePathFlight == true) then table.insert(enabledFlightTypes, "Path"); end
    UI.CreateLabel(spyPlaneCardVGroup)
        .SetText("Spy Plane sends a plane out that reveals every territory it flies over for one turn. Enabled flight types: " .. table.concat(enabledFlightTypes, ", "));

    UI.CreateLabel(spyPlaneCardVGroup).SetText("Card Pieces:").SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(spyPlaneCardVGroup).SetText("Number of Pieces: " .. Mod.Settings.SpyPlaneNumPieces);
    UI.CreateLabel(spyPlaneCardVGroup).SetText("Card Weight: " .. Mod.Settings.SpyPlaneCardWeight);
    UI.CreateLabel(spyPlaneCardVGroup).SetText("Minimum Pieces: " .. Mod.Settings.SpyPlaneMinPieces);
    UI.CreateLabel(spyPlaneCardVGroup).SetText("Initial Pieces: " .. Mod.Settings.SpyPlaneInitialPieces);

    UI.CreateLabel(spyPlaneCardVGroup).SetText("Mod Behaviour:").SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(spyPlaneCardVGroup).SetText("Inclusion Generosity: " .. Mod.Settings.SpyPlaneInclusionGenerosity);
    UI.CreateLabel(spyPlaneCardVGroup).SetText("Maximum Flight Distance: " .. Mod.Settings.SpyPlaneMaxFlightDistance);

    if (Mod.Settings.SpyPlaneFlightStyleSteps) then
        if (Mod.Settings.SpyPlaneStepModeDistance) then
            UI.CreateLabel(spyPlaneCardVGroup).SetText("Flight Style: Multiple Turns (Distance-based, " .. Mod.Settings.SpyPlaneMinDistancePerStep .. "-" .. Mod.Settings.SpyPlaneMaxDistancePerStep .. " per step)");
        else
            UI.CreateLabel(spyPlaneCardVGroup).SetText("Flight Style: Multiple Turns (Fixed-turns, " .. Mod.Settings.SpyPlaneFlightSteps .. " segments)");
        end
    else
        UI.CreateLabel(spyPlaneCardVGroup).SetText("Flight Style: Instant");
    end
end
