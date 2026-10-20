require("Application.Utilities");
require("Application.BuiltInSupport.BuiltInSupport");

-- Known-case templates for the Placeholder Placement rows - vanilla structures and Built-in Support special
-- units, sorted alphabetically by name ("Struct"/"SU" in Text disambiguates the two when mixed together).
---@type { Text: string, Type: string, PlacementName: string, SpecialUnitFields: table<string, string> | nil }[]
PLACEMENT_TEMPLATES = {};
for _, entry in ipairs(VANILLA_STRUCTURE_TYPES) do
    table.insert(PLACEMENT_TEMPLATES, { Text = entry.Name .. " [Struct]", Type = "Structure", PlacementName = entry.Name });
end
for _, unit in ipairs(BuiltInSupport.ListUnits()) do
    table.insert(PLACEMENT_TEMPLATES, {
        Text = unit.Name .. " [SU]",
        Type = "SpecialUnit",
        PlacementName = unit.Name,
        SpecialUnitFields = BuiltInSupport.Find(unit.Name).Fields,
    });
end
table.sort(PLACEMENT_TEMPLATES, function(a, b) return string.lower(a.PlacementName) < string.lower(b.PlacementName); end);