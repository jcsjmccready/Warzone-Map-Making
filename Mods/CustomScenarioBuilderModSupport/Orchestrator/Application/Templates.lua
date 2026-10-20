require("Application.Utilities");

-- Known-case templates for the Placeholder Placement rows
---@type { Text: string, Type: string, PlacementName: string }[]
PLACEMENT_TEMPLATES = {};
for _, entry in ipairs(VANILLA_STRUCTURE_TYPES) do
    table.insert(PLACEMENT_TEMPLATES, { Text = entry.Name, Type = "Structure", PlacementName = entry.Name });
end