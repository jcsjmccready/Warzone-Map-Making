-- Matches the Diplomat mod's own CustomSpecialUnitBuilder exactly, so a Diplomat placed through CSBMS behaves
-- identically to one actually played from that mod's own card. truce.png lives in this mod's own
-- SpecialUnitImages folder, a copy of the Diplomat mod's own image.
--
-- No require("Application.BuiltInSupport.BuiltInSupport") here - this file is only ever loaded via that file's own require
-- (at the bottom, after Register is defined), never required directly by anything else.
BuiltInSupport.Register("Diplomat", function(ownerID)
    local builder = WL.CustomSpecialUnitBuilder.Create(ownerID);
    builder.Name = 'Diplomat';
    builder.IncludeABeforeName = true;
    builder.ImageFilename = 'truce.png';
    builder.AttackPower = 1;
    builder.DefensePower = 1;
    builder.CombatOrder = 3415; --defends commanders
    builder.DamageToKill = 1;
    builder.DamageAbsorbedWhenAttacked = 1;
    builder.CanBeGiftedWithGiftCard = true;
    builder.CanBeTransferredToTeammate = true;
    builder.CanBeAirliftedToSelf = true;
    builder.CanBeAirliftedToTeammate = true;
    builder.IsVisibleToAllPlayers = false;
    return builder.Build();
end);
