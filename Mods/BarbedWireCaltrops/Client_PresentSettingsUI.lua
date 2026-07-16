require("Utilities");

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)

    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);


    if(Mod.Settings.IncludeTankCaltrop) then
        local tankCaltropVGroup = UI.CreateVerticalLayoutGroup(descriptionVGroup).SetFlexibleWidth(1);
        UI.CreateLabel(tankCaltropVGroup).SetText("Barbed Wire:").SetColor(SUBHEADING_COLOUR);
        UI.CreateLabel(tankCaltropVGroup).SetText("If a territory containing a Tank Caltrop is successfully captured with a Tank, on the following turn, attack/transfer orders out of that territory will exclude any Tanks.");
        
        if(Mod.Settings.TankCaltropAllyTriggers) then
            UI.CreateLabel(tankCaltropVGroup).SetText("Any allies can trigger the Tank Caltrop");
            else
            UI.CreateLabel(tankCaltropVGroup).SetText("Any allies can not trigger the Tank Caltrop");
        end
        
        if(Mod.Settings.isAcquiringTypeCard) then
            local cardVGroup = UI.CreateVerticalLayoutGroup(tankCaltropVGroup).SetFlexibleWidth(1);

            UI.CreateLabel(cardVGroup).SetText("Card Settings:").SetColor(BUTTON_COLOURS.LightBlue);
            UI.CreateLabel(cardVGroup).SetText("Number of Pieces: " .. Mod.Settings.TankCaltropNumPieces);
            UI.CreateLabel(cardVGroup).SetText("Card Weight: " .. Mod.Settings.TankCaltropCardWeight);
            UI.CreateLabel(cardVGroup).SetText("Minimum Pieces: " .. Mod.Settings.TankCaltropMinPieces);
            UI.CreateLabel(cardVGroup).SetText("Initial Pieces: " .. Mod.Settings.TankCaltropInitialPieces);
        end
    end

    if(Mod.Settings.IncludeBarbedWire) then
        local barbedWireVGroup = UI.CreateVerticalLayoutGroup(descriptionVGroup).SetFlexibleWidth(1);

        UI.CreateLabel(barbedWireVGroup).SetText("Tank Caltrop:").SetColor(SUBHEADING_COLOUR);
        UI.CreateLabel(barbedWireVGroup).SetText("If a territory containing a Barbed Wire is successfully captured, on the following turn, attack/transfer orders out of that territory will be blocked.");

        if(Mod.Settings.BarbedWireTanksDestroy) then
            UI.CreateLabel(barbedWireVGroup).SetText("Tanks destroy Barbed Wire on entry/exit");
        end
        if(Mod.Settings.BarbedWireTanksIgnore) then
            UI.CreateLabel(barbedWireVGroup).SetText("Armies with tanks can ignore triggered Barbed Wire");
        end

        if(Mod.Settings.BarbedWireAllyTriggers) then
            UI.CreateLabel(barbedWireVGroup).SetText("Any allies can trigger the Barbed Wire");
            else
            UI.CreateLabel(barbedWireVGroup).SetText("Any allies can not trigger the Barbed Wire");
        end

        if(Mod.Settings.isAcquiringTypeCard) then
            local cardVGroup = UI.CreateVerticalLayoutGroup(barbedWireVGroup).SetFlexibleWidth(1);

            UI.CreateLabel(cardVGroup).SetText("Card Settings:").SetColor(BUTTON_COLOURS.LightBlue);
            UI.CreateLabel(cardVGroup).SetText("Number of Pieces: " .. Mod.Settings.BarbedWireNumPieces);
            UI.CreateLabel(cardVGroup).SetText("Card Weight: " .. Mod.Settings.BarbedWireCardWeight);
            UI.CreateLabel(cardVGroup).SetText("Minimum Pieces: " .. Mod.Settings.BarbedWireMinPieces);
            UI.CreateLabel(cardVGroup).SetText("Initial Pieces: " .. Mod.Settings.BarbedWireInitialPieces);
        end
    end
end