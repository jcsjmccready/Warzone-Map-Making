require("Utilities");

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)

    UI.CreateVerticalLayoutGroup(rootParent);

    if(Mod.Settings.IncludeFearCard) then
        local fearCardVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

        UI.CreateLabel(fearCardVGroup).SetText("Fear Card:").SetColor(BUTTON_COLOURS.ElectricPurple);
        UI.CreateLabel(fearCardVGroup).SetText("Creates a structure that 'fears' armies, forcing them to move away from it.");

        UI.CreateLabel(fearCardVGroup).SetText("");
        UI.CreateLabel(fearCardVGroup).SetText("");
        UI.CreateLabel(fearCardVGroup).SetText("");

        UI.CreateLabel(fearCardVGroup).SetText("Can only create on own territories: " .. tostring(Mod.Settings.FearCreateOnlyOwnTerritories));
        UI.CreateLabel(fearCardVGroup).SetText("Fear Distance: " .. Mod.Settings.FearDistance);
        UI.CreateLabel(fearCardVGroup).SetText("Fear Duration: " .. Mod.Settings.FearDuration);
        UI.CreateLabel(fearCardVGroup).SetText("Fear % Falloff Per Step: " .. Mod.Settings.FearFalloff * 100 .. "%");
        UI.CreateLabel(fearCardVGroup).SetText("Maximum Fear % where Special Units are Immune: " .. Mod.Settings.FearSpecialUnitThreshold * 100 .. "%");
        UI.CreateLabel(fearCardVGroup).SetText("Falloff examples: " .. Determine_Falloff_Examples(Mod.Settings.FearFalloff, Mod.Settings.FearDistance)).SetColor(BUTTON_COLOURS.DarkGray);

        UI.CreateLabel(fearCardVGroup).SetText("");
        UI.CreateLabel(fearCardVGroup).SetText("");
        UI.CreateLabel(fearCardVGroup).SetText("");

        UI.CreateLabel(fearCardVGroup).SetText("Number of Pieces: " .. Mod.Settings.FearNumPieces);
        UI.CreateLabel(fearCardVGroup).SetText("Card Weight: " .. Mod.Settings.FearCardWeight);
        UI.CreateLabel(fearCardVGroup).SetText("Minimum Pieces: " .. Mod.Settings.FearMinPieces);
        UI.CreateLabel(fearCardVGroup).SetText("Initial Pieces: " .. Mod.Settings.FearInitialPieces);
    end

    if(Mod.Settings.IncludeCharmCard) then
        local charmCardVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
        UI.CreateLabel(charmCardVGroup).SetText("Charm Card:").SetColor(BUTTON_COLOURS.Orchid);
        UI.CreateLabel(charmCardVGroup).SetText("Creates a structure that 'charms' armies, forcing them to move towards it.");

        UI.CreateLabel(charmCardVGroup).SetText("");
        UI.CreateLabel(charmCardVGroup).SetText("");
        UI.CreateLabel(charmCardVGroup).SetText("");

        UI.CreateLabel(charmCardVGroup).SetText("Can only create on own territories: " .. tostring(Mod.Settings.CharmCreateOnlyOwnTerritories));
        UI.CreateLabel(charmCardVGroup).SetText("Charm Distance: " .. Mod.Settings.CharmDistance);
        UI.CreateLabel(charmCardVGroup).SetText("Charm Duration: " .. Mod.Settings.CharmDuration);
        UI.CreateLabel(charmCardVGroup).SetText("Charm % Falloff Per Step: " .. Mod.Settings.CharmFalloff * 100 .. "%");
        UI.CreateLabel(charmCardVGroup).SetText("Maximum Charm % where Special Units are Immune: " .. Mod.Settings.CharmSpecialUnitThreshold * 100 .. "%");
        UI.CreateLabel(charmCardVGroup).SetText("Falloff examples: " .. Determine_Falloff_Examples(Mod.Settings.CharmFalloff, Mod.Settings.CharmDistance)).SetColor(BUTTON_COLOURS.DarkGray);

        UI.CreateLabel(charmCardVGroup).SetText("");
        UI.CreateLabel(charmCardVGroup).SetText("");
        UI.CreateLabel(charmCardVGroup).SetText("");

        UI.CreateLabel(charmCardVGroup).SetText("Number of Pieces: " .. Mod.Settings.CharmNumPieces);
        UI.CreateLabel(charmCardVGroup).SetText("Card Weight: " .. Mod.Settings.CharmCardWeight);
        UI.CreateLabel(charmCardVGroup).SetText("Minimum Pieces: " .. Mod.Settings.CharmMinPieces);
        UI.CreateLabel(charmCardVGroup).SetText("Initial Pieces: " .. Mod.Settings.CharmInitialPieces);
    end
end