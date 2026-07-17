# MS Threat 1.0.8 validation report

## Source validation

- Parsed `MSThreat_Bootstrap.lua`, `MSThreat_Core.lua`, `MSThreat_Local.lua`, `MSThreat_UI.lua`, and the migration bridge successfully.
- Confirmed `## Interface: 11200`.
- Confirmed TOC source order: bootstrap, core, local provider, UI.
- Confirmed primary and legacy slash-command registration.
- Confirmed no dependency on modern Retail or current Classic APIs was introduced.
- Confirmed no `string.gmatch`, Lua length-operator table counting, or unsupported vararg-forwarding syntax was introduced.

## Mocked World of Warcraft 1.12.1 runtime validation

A comprehensive harness completed 54 assertions, including:

- New and existing character-profile activation.
- Independent profile widths and settings.
- Automatic defaulting of the new `groupFallback` option on an existing profile.
- Clearing native, server, and local transient rows during character switches.
- Unrelated group-member combat producing `IDLE`, not `WAIT`.
- Automatic expiry of a stale combat latch.
- Immediate grouped roster rows for ordinary current-target combat.
- `GROUP EST` selection and display.
- Party melee and spell-damage attribution.
- Group healing-threat estimation.
- Rejection of combat messages for another target.
- Elite-only exact server-query eligibility.
- Compatible-server packet acceptance and provider priority.
- Native absolute priority over server and local rows.
- Native percentage priority over grouped local estimation.
- Local-only mode during grouped combat.
- Group-fallback disable behavior.
- Solo-estimation regression behavior.
- Configuration checkbox behavior.
- Primary and legacy command aliases.

Separate startup/UI and migration harnesses validated:

- Configuration-window construction.
- Header and options initialization.
- `GROUP EST` header display and color path.
- Behavior-page group-estimation control.
- Deep-copy migration from `OctoThreatDB`.
- Migration of all saved character profiles.
- Existing MS-prefixed value precedence.
- Legacy database preservation.
- Migration marker creation.

## Archive validation

The Clean, Update, and Source archives were checked for:

- ZIP integrity.
- Correct top-level folders.
- No double nesting.
- No legacy bridge in the Clean archive.
- Only migration files in the Update archive's `OctoThreat` folder.
- Matching version and Interface metadata.

## Live-client status

The repaired release has not yet been executed inside the live World of Warcraft client. The validation above consists of source parsing, static compatibility checks, archive inspection, and mocked runtime tests.
