---@class RowTemplateRow
---@field Key string
---@field Value string

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
        },
    },
    {
        Name = "Queue Bomb Shelter Build",
        TargetModKey = "BombShelter_Mgreedy",
        Rows = {
            { Key = "Action", Value = "QueueBuild" },
            { Key = "TerritoryID", Value = "1" },
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
