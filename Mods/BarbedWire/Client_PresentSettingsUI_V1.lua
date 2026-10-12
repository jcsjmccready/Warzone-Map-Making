--Settings version 1 display - frozen. This is the settings page exactly as it was before settings versioning
--was introduced; games saved under version 1 must keep showing this, so don't change it.

PresentSettingsV1 = {}

---@param rootParent RootParent
function PresentSettingsV1.Render(rootParent)
    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateLabel(descriptionVGroup).SetText("If a territory containing a Barbed Wire is successfully captured, on the following turn, attack/transfer orders out of that territory will be blocked.");

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
    end
end
