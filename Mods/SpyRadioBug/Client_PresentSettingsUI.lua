require("Utilities");

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    local visibilityMessage = "ERROR";

    if(Mod.Settings.VisibilityGainedAutoplaySpyCard) then
        visibilityMessage = "a Spy card is automatically played on the owner of the territory";
    end

    if(Mod.Settings.VisibilityGainedCustomVision) then
        visibilityMessage = "you are given vision of it and the targets territories within " .. Mod.Settings.CustomVisionRadius .. " territories of it.";
    end

    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateLabel(descriptionVGroup).SetText("Create a Spy Radio Bug on an enemy territory. While undiscovered, " .. visibilityMessage);
    UI.CreateLabel(descriptionVGroup).SetText("Your enemy is given Temporary Sweeper cards to search for your bug. If they find it, it is removed.");

    UI.CreateVerticalLayoutGroup(rootParent);

    local modVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(modVGroup).SetText("Mod Behaviour:").SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(modVGroup).SetText("Sweeper Radius: " .. Mod.Settings.SweeperRadius);
    if(Mod.Settings.VisibilityGainedCustomVision) then
        UI.CreateLabel(modVGroup).SetText("Radio Detection Radius: " .. Mod.Settings.RadioDetectionRadius);
    end
    UI.CreateLabel(modVGroup).SetText("Card pieces awarded on recapture: " .. Mod.Settings.RecaptureCardPieces);

    UI.CreateVerticalLayoutGroup(rootParent);

    if(Mod.Settings.isAcquiringTypeCard) then
        local cardVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

        UI.CreateLabel(cardVGroup).SetText("Spy Radio Bug Card:");
        UI.CreateLabel(cardVGroup).SetText("Number of Pieces: " .. Mod.Settings.NumPieces);
        UI.CreateLabel(cardVGroup).SetText("Card Weight: " .. Mod.Settings.CardWeight);
        UI.CreateLabel(cardVGroup).SetText("Minimum Pieces: " .. Mod.Settings.MinPieces);
        UI.CreateLabel(cardVGroup).SetText("Initial Pieces: " .. Mod.Settings.InitialPieces);
    end
end
