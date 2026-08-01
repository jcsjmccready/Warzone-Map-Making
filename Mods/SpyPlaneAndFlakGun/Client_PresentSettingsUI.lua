require("Utilities");

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    UI.CreateVerticalLayoutGroup(rootParent);

    if(Mod.Settings.IncludeSpyPlaneCard) then
        local spyPlaneCardVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
        UI.CreateLabel(spyPlaneCardVGroup).SetText("Spy Plane Card:").SetColor(BUTTON_COLOURS.LightBlue);

        UI.CreateLabel(spyPlaneCardVGroup).SetText("Number of Pieces: " .. Mod.Settings.SpyPlaneNumPieces);
        UI.CreateLabel(spyPlaneCardVGroup).SetText("Card Weight: " .. Mod.Settings.SpyPlaneCardWeight);
        UI.CreateLabel(spyPlaneCardVGroup).SetText("Minimum Pieces: " .. Mod.Settings.SpyPlaneMinPieces);
        UI.CreateLabel(spyPlaneCardVGroup).SetText("Initial Pieces: " .. Mod.Settings.SpyPlaneInitialPieces);
        UI.CreateLabel(spyPlaneCardVGroup).SetText("Inclusion Generosity: " .. Mod.Settings.SpyPlaneInclusionGenerosity);
        UI.CreateLabel(spyPlaneCardVGroup).SetText("Maximum Flight Distance: " .. Mod.Settings.SpyPlaneMaxFlightDistance);

        if(Mod.Settings.SpyPlaneFlightStyleSteps) then
            UI.CreateLabel(spyPlaneCardVGroup).SetText("Flight Style: Steps (" .. Mod.Settings.SpyPlaneFlightSteps .. " steps)");
        else
            UI.CreateLabel(spyPlaneCardVGroup).SetText("Flight Style: Instant");
        end
    end

    if(Mod.Settings.IncludeFlakGunCard) then
        local flakGunCardVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
        UI.CreateLabel(flakGunCardVGroup).SetText("Flak Gun Card:").SetColor(BUTTON_COLOURS.LightBlue);

        UI.CreateLabel(flakGunCardVGroup).SetText("Number of Pieces: " .. Mod.Settings.FlakGunNumPieces);
        UI.CreateLabel(flakGunCardVGroup).SetText("Card Weight: " .. Mod.Settings.FlakGunCardWeight);
        UI.CreateLabel(flakGunCardVGroup).SetText("Minimum Pieces: " .. Mod.Settings.FlakGunMinPieces);
        UI.CreateLabel(flakGunCardVGroup).SetText("Initial Pieces: " .. Mod.Settings.FlakGunInitialPieces);
        UI.CreateLabel(flakGunCardVGroup).SetText("Area Of Effect: " .. Mod.Settings.FlakGunAreaOfEffect);
        UI.CreateLabel(flakGunCardVGroup).SetText("Flak Gun Rounds: " .. Mod.Settings.FlakGunRounds);
        UI.CreateLabel(flakGunCardVGroup).SetText("Friendly Fire: " .. tostring(Mod.Settings.FlakGunFriendlyFire));
        UI.CreateLabel(flakGunCardVGroup).SetText("Targeting Spy Plane Destroys It: " .. tostring(Mod.Settings.FlakGunTargetingSpyPlaneDestroys));
        UI.CreateLabel(flakGunCardVGroup).SetText("Targeting Airlift Source Cancels Airlift: " .. tostring(Mod.Settings.FlakGunTargetingAirliftSourceCancels));
        UI.CreateLabel(flakGunCardVGroup).SetText("Targeting Airlift Destination Hurts Transported Armies: " .. tostring(Mod.Settings.FlakGunTargetingAirliftDestinationHurts));

        if(Mod.Settings.FlakGunTargetingAirliftDestinationHurts) then
            UI.CreateLabel(flakGunCardVGroup).SetText("Airlift Damage Percent: " .. Mod.Settings.FlakGunAirliftDamagePercent);
            UI.CreateLabel(flakGunCardVGroup).SetText("Airlift Minimum Damage: " .. Mod.Settings.FlakGunAirliftMinDamage);
        end
    end
end
