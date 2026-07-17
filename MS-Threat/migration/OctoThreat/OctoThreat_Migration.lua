-- Temporary saved-variable bridge for MS Threat 1.0.8.
-- The former threat-meter implementation is intentionally not loaded.

MSThreatLegacyMigration = MSThreatLegacyMigration or {}
MSThreatLegacyMigration.loaded = 1
MSThreatLegacyMigration.sourceAddon = "OctoThreat"
MSThreatLegacyMigration.sourceVersion = "1.0.6"
MSThreatLegacyMigration.account = OctoThreatDB
