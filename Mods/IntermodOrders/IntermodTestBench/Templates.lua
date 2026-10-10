---@class RowTemplateRow
---@field Key string
---@field Value string
---@field Optional boolean | nil # Marked visually in the menu as optional for the action, rather than required

---@class RowTemplate
---@field Name string # Shown in the "Load template..." picker
---@field TargetModKey string | nil # Pre-fills the target mod key field, if set
---@field Rows RowTemplateRow[] # Replaces whatever rows are currently in the table

---@type RowTemplate[]
ROW_TEMPLATES = {
    {
        Name = "Trigger Bomb Shelter",
        TargetModKey = "BombShelter_Mgreedy",
        Rows = {
            { Key = "Action", Value = "TriggerBombShelter" },
            { Key = "TerritoryID", Value = "1" },
            { Key = "ArmiesBefore", Value = "10" },
            { Key = "DestroyBombShelter", Value = "false", Optional = true },
            { Key = "OverriddenPercentage", Value = "0.5", Optional = true },
        },
    },
    {
        Name = "Add Bomb Shelter",
        TargetModKey = "BombShelter_Mgreedy",
        Rows = {
            { Key = "Action", Value = "AddBombShelter" },
            { Key = "TerritoryID", Value = "1" },
            { Key = "IsImmediate", Value = "false", Optional = true },
        },
    },
    {
        Name = "Destroy Bomb Shelter",
        TargetModKey = "BombShelter_Mgreedy",
        Rows = {
            { Key = "Action", Value = "DestroyBombShelter" },
            { Key = "TerritoryID", Value = "1" },
        },
    },
};
