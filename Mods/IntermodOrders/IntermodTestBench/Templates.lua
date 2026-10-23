---@class RowTemplateRow
---@field Key string
---@field Value string
---@field Optional boolean | nil # Marked visually in the menu as optional for the action, rather than required

---@class RowTemplate
---@field Name string # Shown in the template picker, once a group has been chosen
---@field TargetModKey string | nil # Pre-fills the target mod key field, if set
---@field Rows RowTemplateRow[] # Replaces whatever rows are currently in the table

---@class RowTemplateGroup
---@field Name string # Shown in the "Load template..." group picker
---@field Templates RowTemplate[]

---@type RowTemplateGroup[]
TEMPLATE_GROUPS = {
    {
        Name = "Bomb Shelter",
        Templates = {
            {
                Name = "Trigger",
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
                Name = "Add",
                TargetModKey = "BombShelter_Mgreedy",
                Rows = {
                    { Key = "Action", Value = "AddBombShelter" },
                    { Key = "TerritoryID", Value = "1" },
                    { Key = "IsImmediate", Value = "false", Optional = true },
                },
            },
            {
                Name = "Destroy",
                TargetModKey = "BombShelter_Mgreedy",
                Rows = {
                    { Key = "Action", Value = "DestroyBombShelter" },
                    { Key = "TerritoryID", Value = "1" },
                },
            },
        },
    },
    {
        Name = "Dead Man's Switch",
        Templates = {
            {
                Name = "Trigger",
                TargetModKey = "DeadManSwitch_Mgreedy",
                Rows = {
                    { Key = "Action", Value = "TriggerDeadManSwitch" },
                    { Key = "TerritoryID", Value = "1" },
                    { Key = "AttackerPlayerID", Value = "1" },
                    { Key = "ArmiesOnArrival", Value = "5" },
                    { Key = "NumSwitches", Value = "1", Optional = true },
                },
            },
            {
                Name = "Add",
                TargetModKey = "DeadManSwitch_Mgreedy",
                Rows = {
                    { Key = "Action", Value = "AddDeadManSwitch" },
                    { Key = "TerritoryID", Value = "1" },
                    { Key = "IsImmediate", Value = "false", Optional = true },
                },
            },
            {
                Name = "Destroy",
                TargetModKey = "DeadManSwitch_Mgreedy",
                Rows = {
                    { Key = "Action", Value = "DestroyDeadManSwitch" },
                    { Key = "TerritoryID", Value = "1" },
                },
            },
        },
    },
    {
        Name = "Barbed Wire / Caltrop",
        Templates = {
            {
                Name = "Add",
                TargetModKey = "BarbedWire_Mgreedy",
                Rows = {
                    { Key = "Action", Value = "AddTrap" },
                    { Key = "TrapKey", Value = "BarbedWire" },
                    { Key = "TerritoryID", Value = "1" },
                    { Key = "IsImmediate", Value = "false", Optional = true },
                },
            },
            {
                Name = "Trigger",
                TargetModKey = "BarbedWire_Mgreedy",
                Rows = {
                    { Key = "Action", Value = "TriggerTrap" },
                    { Key = "TrapKey", Value = "BarbedWire" },
                    { Key = "TerritoryID", Value = "1" },
                },
            },
            {
                Name = "Reset",
                TargetModKey = "BarbedWire_Mgreedy",
                Rows = {
                    { Key = "Action", Value = "ResetTrap" },
                    { Key = "TrapKey", Value = "BarbedWire" },
                    { Key = "TerritoryID", Value = "1" },
                },
            },
            {
                Name = "Destroy",
                TargetModKey = "BarbedWire_Mgreedy",
                Rows = {
                    { Key = "Action", Value = "DestroyTrap" },
                    { Key = "TrapKey", Value = "BarbedWire" },
                    { Key = "TerritoryID", Value = "1" },
                },
            },
        },
    },
    {
        Name = "Points of Interest",
        Templates = {
            {
                Name = "Add",
                TargetModKey = "PointsOfInterest_Mgreedy",
                Rows = {
                    { Key = "Action", Value = "AddPointOfInterest" },
                    { Key = "Letter", Value = "A" },
                    { Key = "TerritoryID", Value = "1" },
                },
            },
            {
                Name = "Remove",
                TargetModKey = "PointsOfInterest_Mgreedy",
                Rows = {
                    { Key = "Action", Value = "RemovePointOfInterest" },
                    { Key = "TerritoryID", Value = "1" },
                    { Key = "Letter", Value = "A", Optional = true },
                },
            },
        },
    },
};
