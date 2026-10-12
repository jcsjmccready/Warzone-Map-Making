require("Utilities");

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    UI.CreateVerticalLayoutGroup(rootParent);

    local spyPlaneCardVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(spyPlaneCardVGroup).SetText("Spy Plane Card:").SetColor(BUTTON_COLOURS.LightBlue);

    UI.CreateLabel(spyPlaneCardVGroup).SetText("Number of Pieces: " .. Mod.Settings.SpyPlaneNumPieces);
    UI.CreateLabel(spyPlaneCardVGroup).SetText("Card Weight: " .. Mod.Settings.SpyPlaneCardWeight);
    UI.CreateLabel(spyPlaneCardVGroup).SetText("Minimum Pieces: " .. Mod.Settings.SpyPlaneMinPieces);
    UI.CreateLabel(spyPlaneCardVGroup).SetText("Initial Pieces: " .. Mod.Settings.SpyPlaneInitialPieces);
    UI.CreateLabel(spyPlaneCardVGroup).SetText("Inclusion Generosity: " .. Mod.Settings.SpyPlaneInclusionGenerosity);
    UI.CreateLabel(spyPlaneCardVGroup).SetText("Maximum Flight Distance: " .. Mod.Settings.SpyPlaneMaxFlightDistance);

    if(Mod.Settings.SpyPlaneFlightStyleSteps) then
        if(Mod.Settings.SpyPlaneStepModeDistance) then
            UI.CreateLabel(spyPlaneCardVGroup).SetText("Flight Style: Steps (Distance-based, max " .. Mod.Settings.SpyPlaneMaxDistancePerStep .. " per step)");
        else
            UI.CreateLabel(spyPlaneCardVGroup).SetText("Flight Style: Steps (Segment-based, " .. Mod.Settings.SpyPlaneFlightSteps .. " segments)");
        end
    else
        UI.CreateLabel(spyPlaneCardVGroup).SetText("Flight Style: Instant");
    end
end
