require("Application.Utilities");
require("Application.BuiltInSupport.BuiltInSupport");

-- Known-case templates for the Placeholder Placement rows - one list for "Add Vanilla Structure", one for
-- "Add Built-In Special Unit", each sorted alphabetically by name.
---@type { Text: string, Type: string, PlacementName: string, SpecialUnitFields: table<string, string> | nil }[]
VANILLA_STRUCTURE_TEMPLATES = {};
for _, entry in ipairs(VANILLA_STRUCTURE_TYPES) do
    table.insert(VANILLA_STRUCTURE_TEMPLATES, { Text = entry.Name, Type = "Structure", PlacementName = entry.Name });
end
table.sort(VANILLA_STRUCTURE_TEMPLATES, function(a, b) return string.lower(a.PlacementName) < string.lower(b.PlacementName); end);

---@type { Text: string, Type: string, PlacementName: string, SpecialUnitFields: table<string, string> | nil }[]
BUILT_IN_SPECIAL_UNIT_TEMPLATES = {};
for _, unit in ipairs(BuiltInSupport.ListUnits()) do
    table.insert(BUILT_IN_SPECIAL_UNIT_TEMPLATES, {
        Text = unit.Name,
        Type = "SpecialUnit",
        PlacementName = unit.Name,
        SpecialUnitFields = BuiltInSupport.Find(unit.Name).Fields,
    });
end
table.sort(BUILT_IN_SPECIAL_UNIT_TEMPLATES, function(a, b) return string.lower(a.PlacementName) < string.lower(b.PlacementName); end);