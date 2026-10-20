-- Matches the Diplomat mod's own CustomSpecialUnitBuilder exactly, so a Diplomat placed through CSBMS behaves
-- identically to one actually played from that mod's own card. truce.png lives in this mod's own
-- SpecialUnitImages folder, a copy of the Diplomat mod's own image.
--
-- No require("Application.BuiltInSupport.BuiltInSupport") here - this file is only ever loaded via that file's own require
-- (at the bottom, after Register is defined), never required directly by anything else.
BuiltInSupport.Register("Diplomat", "Diplomat", "UnFairerOrb76", 546, "truce.png", {
    IncludeABeforeName = "true",
    AttackPower = "1",
    DefensePower = "1",
    CombatOrder = "3415", -- defends commanders
    DamageToKill = "1",
    DamageAbsorbedWhenAttacked = "1",
    CanBeGiftedWithGiftCard = "true",
    CanBeTransferredToTeammate = "true",
    CanBeAirliftedToSelf = "true",
    CanBeAirliftedToTeammate = "true",
    IsVisibleToAllPlayers = "false",
});
