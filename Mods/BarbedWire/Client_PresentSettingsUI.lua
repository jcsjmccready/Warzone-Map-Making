---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)

    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateLabel(descriptionVGroup).SetText("If a territory containing a Barbed Wire is taken, the next turn, they can not move out. It resets one turn later.");

    if(Mod.Settings.TanksDestroy) then
        UI.CreateLabel(descriptionVGroup).SetText("Tanks destroy Barbed Wire on entry");
    end
    if(Mod.Settings.TanksIgnore) then
        UI.CreateLabel(descriptionVGroup).SetText("Armies with tanks can ignore triggered Barbed Wire");
    end

    if(Mod.Settings.AllyTriggers) then
        UI.CreateLabel(descriptionVGroup).SetText("Any allies can trigger the Barbed Wire");
        else
        UI.CreateLabel(descriptionVGroup).SetText("Any allies can not trigger the Barbed Wire");
    end

    UI.CreateVerticalLayoutGroup(rootParent);

    if(Mod.Settings.isAcquiringTypeCard) then
        local cardVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

        UI.CreateLabel(cardVGroup).SetText("Barbed Wire Card:");
        UI.CreateLabel(cardVGroup).SetText("Number of Pieces: " .. Mod.Settings.NumPieces);
        UI.CreateLabel(cardVGroup).SetText("Card Weight: " .. Mod.Settings.CardWeight);
        UI.CreateLabel(cardVGroup).SetText("Minimum Pieces: " .. Mod.Settings.MinPieces);
        UI.CreateLabel(cardVGroup).SetText("Initial Pieces: " .. Mod.Settings.InitialPieces);
    end
end