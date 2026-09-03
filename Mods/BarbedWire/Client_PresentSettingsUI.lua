require("Utilities");

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    MigrateModSettings();

    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateLabel(descriptionVGroup).SetText("Mod Settings Version: " .. GetSettingsVersionForDisplay()).SetColor(BUTTON_COLOURS.DarkGray);

    UI.CreateLabel(descriptionVGroup).SetText("If a territory containing a Barbed Wire is successfully captured, on the following turn, attack/transfer orders out of that territory will be blocked.");

    UI.CreateLabel(descriptionVGroup).SetText("Trigger Duration: " .. (Mod.Settings.BarbedWireTriggerDuration or 1));

    if(Mod.Settings.BarbedWireSingleUse) then
        UI.CreateLabel(descriptionVGroup).SetText("Barbed wire is destroyed instead of resetting");
    end

    if(Mod.Settings.BarbedWireHasLimitedLifespan) then
        UI.CreateLabel(descriptionVGroup).SetText("Turns before expires: " .. Mod.Settings.BarbedWireLifespan);
    end

    if(Mod.Settings.BarbedWireTanksDestroy) then
        UI.CreateLabel(descriptionVGroup).SetText("Tanks destroy Barbed Wire on entry/exit");
    end
    if(Mod.Settings.BarbedWireTanksIgnore) then
        UI.CreateLabel(descriptionVGroup).SetText("Armies with tanks can ignore triggered Barbed Wire");
    end

    if(Mod.Settings.BarbedWireAllyTriggers) then
        UI.CreateLabel(descriptionVGroup).SetText("Any allies can trigger the Barbed Wire");
        else
        UI.CreateLabel(descriptionVGroup).SetText("Any allies can not trigger the Barbed Wire");
    end

    UI.CreateVerticalLayoutGroup(rootParent);

    if(Mod.Settings.isAcquiringTypeCard) then
        local cardVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

        UI.CreateLabel(cardVGroup).SetText("Barbed Wire Card:");
        UI.CreateLabel(cardVGroup).SetText("Number of Pieces: " .. Mod.Settings.BarbedWireNumPieces);
        UI.CreateLabel(cardVGroup).SetText("Card Weight: " .. Mod.Settings.BarbedWireCardWeight);
        UI.CreateLabel(cardVGroup).SetText("Minimum Pieces: " .. Mod.Settings.BarbedWireMinPieces);
        UI.CreateLabel(cardVGroup).SetText("Initial Pieces: " .. Mod.Settings.BarbedWireInitialPieces);
    else
        local commerceVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

        UI.CreateLabel(commerceVGroup).SetText("Barbed Wire Commerce:");
        UI.CreateLabel(commerceVGroup).SetText("Cost: " .. Mod.Settings.BarbedWireCost .. " gold");
        UI.CreateLabel(commerceVGroup).SetText("Limit: " .. Mod.Settings.BarbedWireMaxPerPlayer .. " per player");
    end
end