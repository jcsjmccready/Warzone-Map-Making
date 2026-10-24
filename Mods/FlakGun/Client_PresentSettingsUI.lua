require("Utilities");

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    UI.CreateVerticalLayoutGroup(rootParent);

    local flakGunCardVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(flakGunCardVGroup).SetText("Shoot a flak gun at a chosen territory to interact with airborne mechanics");

    UI.CreateLabel(flakGunCardVGroup).SetText("Flak Gun Card:").SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(flakGunCardVGroup).SetText("Number of Pieces: " .. Mod.Settings.FlakGunNumPieces);
    UI.CreateLabel(flakGunCardVGroup).SetText("Card Weight: " .. Mod.Settings.FlakGunCardWeight);
    UI.CreateLabel(flakGunCardVGroup).SetText("Minimum Pieces: " .. Mod.Settings.FlakGunMinPieces);
    UI.CreateLabel(flakGunCardVGroup).SetText("Initial Pieces: " .. Mod.Settings.FlakGunInitialPieces);

    UI.CreateLabel(flakGunCardVGroup).SetText("");

    UI.CreateLabel(flakGunCardVGroup).SetText("Flak Gun:").SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(flakGunCardVGroup).SetText("Friendly Fire: " .. tostring(Mod.Settings.FlakGunFriendlyFire));
    UI.CreateLabel(flakGunCardVGroup).SetText("Area Of Effect: " .. Mod.Settings.FlakGunAreaOfEffect);
    UI.CreateLabel(flakGunCardVGroup).SetText("0 = target only, 1 = hits surrounding territories as well*").SetColor(BUTTON_COLOURS.DarkGray);
    UI.CreateLabel(flakGunCardVGroup).SetText("Flak Gun Rounds: " .. Mod.Settings.FlakGunRounds .. " (1 = no temporary copies)");
    UI.CreateLabel(flakGunCardVGroup).SetText("Temporary = discards at the end of the turn*").SetColor(BUTTON_COLOURS.DarkGray);

    UI.CreateLabel(flakGunCardVGroup).SetText("");

    if (Mod.Settings.FlakGunAirliftInteractionEnabled) then
        UI.CreateLabel(flakGunCardVGroup).SetText("Airlift Interaction:").SetColor(SUBHEADING_COLOUR);

        UI.CreateLabel(flakGunCardVGroup).SetText("Targets Airlift Arrival: " .. (Mod.Settings.FlakGunSourceDamagesArmies and "Damages armies" or "Cancels airlift"));
        if (Mod.Settings.FlakGunSourceDamagesArmies) then
            UI.CreateLabel(flakGunCardVGroup).SetText("  Damage: " .. math.floor((Mod.Settings.FlakGunSourceDamagePercent or 0) * 100) .. "% (minimum " .. (Mod.Settings.FlakGunSourceMinDamage or 0) .. " armies)");
        end

        UI.CreateLabel(flakGunCardVGroup).SetText("Targets Airlift Destination: " .. (Mod.Settings.FlakGunDestinationDamagesArmies and "Damages armies" or "Cancels airlift"));
        if (Mod.Settings.FlakGunDestinationDamagesArmies) then
            UI.CreateLabel(flakGunCardVGroup).SetText("  Damage: " .. math.floor((Mod.Settings.FlakGunDestinationDamagePercent or 0) * 100) .. "% (minimum " .. (Mod.Settings.FlakGunDestinationMinDamage or 0) .. " armies)");
        end
    end
end
