--Settings version 2 display

PresentSettingsV2 = {}

---@param rootParent RootParent
function PresentSettingsV2.Render(rootParent)
    if (Mod.Settings.IncludeBarbedWire) then
        PresentSettingsV2.ShowTrap(rootParent, "BarbedWire", "Barbed Wire", Mod.Settings.isAcquiringTypeCard);
    end

    if (Mod.Settings.IncludeCaltrop) then
        PresentSettingsV2.ShowTrap(rootParent, "Caltrop", "Caltrop", Mod.Settings.CaltropIsAcquiringTypeCard);
    end
end

---@param rootParent RootParent
---@param prefix string # the trap's settings prefix, i.e. its V2_TrapType.Key
---@param displayName string
---@param isAcquiringTypeCard boolean | nil
function PresentSettingsV2.ShowTrap(rootParent, prefix, displayName, isAcquiringTypeCard)
    local vGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    ---@param text string
    local function line(text)
        UI.CreateLabel(vGroup).SetText(text);
    end

    UI.CreateLabel(vGroup).SetText(displayName .. ":").SetColor(prefix == "BarbedWire" and SUBHEADING_COLOUR or BUTTON_COLOURS.LightBlue);

    line("If a territory containing a " .. displayName .. " is successfully captured, orders out of that territory are blocked on the following turn.");
    line("Trigger Duration: " .. (Mod.Settings[prefix .. "TriggerDuration"] or 1));

    if (Mod.Settings[prefix .. "TrapsArmies"]) then
        line("Traps armies");
    end
    if (Mod.Settings[prefix .. "TrapsSpecialUnits"]) then
        line("Traps special units");
    end
    if (Mod.Settings[prefix .. "CancelsAirlifts"]) then
        line("Cancels airlifts out of a territory with a primed or triggered " .. displayName);
    end
    if (Mod.Settings[prefix .. "OnlyTriggersOnTrappableUnits"]) then
        line("Only triggers if trappable units attacked");
    end
    if (Mod.Settings[prefix .. "BombDestroys"]) then
        line("A bomb destroys the " .. displayName);
    end

    if (Mod.Settings[prefix .. "SingleUse"]) then
        line(displayName .. " is destroyed instead of resetting");
    end
    if (Mod.Settings[prefix .. "HasLimitedLifespan"]) then
        line("Turns before expires: " .. Mod.Settings[prefix .. "Lifespan"]);
    end

    if (Mod.Settings[prefix .. "IsImmuneUnitEnabled"]) then
        local unitName = Mod.Settings[prefix .. "ImmuneUnitName"] or "Tank";
        if (Mod.Settings[prefix .. "ImmuneUnitDestroys"]) then
            line("Immune unit (" .. unitName .. ") destroys " .. displayName .. " on entry/exit");
        end
        if (Mod.Settings[prefix .. "ImmuneUnitIgnores"]) then
            line("Armies with the immune unit (" .. unitName .. ") ignore triggered " .. displayName);
        end
    end

    if (Mod.Settings[prefix .. "AllyTriggers"]) then
        line("Any allies can trigger the " .. displayName);
    else
        line("Any allies can not trigger the " .. displayName);
    end

    if (isAcquiringTypeCard == nil or isAcquiringTypeCard) then
        local cardVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
        UI.CreateLabel(cardVGroup).SetText(displayName .. " Card:");
        UI.CreateLabel(cardVGroup).SetText("Number of Pieces: " .. Mod.Settings[prefix .. "NumPieces"]);
        UI.CreateLabel(cardVGroup).SetText("Card Weight: " .. Mod.Settings[prefix .. "CardWeight"]);
        UI.CreateLabel(cardVGroup).SetText("Minimum Pieces: " .. Mod.Settings[prefix .. "MinPieces"]);
        UI.CreateLabel(cardVGroup).SetText("Initial Pieces: " .. Mod.Settings[prefix .. "InitialPieces"]);
    elseif (prefix == "BarbedWire") then
        local commerceVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
        UI.CreateLabel(commerceVGroup).SetText(displayName .. " Commerce:");
        UI.CreateLabel(commerceVGroup).SetText("Cost: " .. Mod.Settings[prefix .. "Cost"] .. " gold");
        UI.CreateLabel(commerceVGroup).SetText("Limit: " .. Mod.Settings[prefix .. "MaxPerPlayer"] .. " per player");
    else
        UI.CreateLabel(rootParent).SetText(displayName .. " is acquired via Commerce");
    end

    UI.CreateVerticalLayoutGroup(rootParent);
end
