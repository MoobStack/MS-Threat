# Validation summary — MS Threat 1.0.7

## Completed source and compatibility checks

- Confirmed the attached source release was OctoThreat 1.0.6.
- Renamed the addon folder, TOC, Lua files, namespace, frames, visible branding, messages, and saved-variable declaration.
- Confirmed `## Interface: 11200`, author `MoobStack`, and version `1.0.7`.
- Confirmed TOC order: bootstrap, core, local provider, UI.
- Parsed every addon and migration-bridge Lua file successfully with `texluac -p` as a structural syntax check.
- Scanned for WoW 1.12.1-incompatible additions, including active `string.gmatch`, Lua length-operator usage, and Lua 5.1-style vararg forwarding; none were introduced.
- Confirmed the addon uses no required companion folder for clean installations.

## Branding and command checks

- Confirmed `/msthreat`, `/mst`, and `/msthreatmeter` register as primary aliases.
- Confirmed `/othreat` and `/octothreat` remain registered as legacy aliases.
- Confirmed all five aliases route through one early bootstrap dispatcher.
- Confirmed `MSThreat`, `MSThreat_CommandDispatch`, and MS-prefixed frame names are active.
- Confirmed `OctoThreat` and `OctoThreat_CommandDispatch` remain documented runtime compatibility aliases.
- Confirmed visible UI titles, chat prefixes, tooltips, status output, and help text use **MS Threat**.
- Confirmed no server-specific promotional compatibility wording remains in current source or public documentation.

## Saved-data and profile migration checks

A mocked WoW-style runtime exercised the packaged Lua source and verified:

- Full initialization and configuration-window creation.
- Deep-copy migration from `OctoThreatDB` into `MSThreatDB`.
- Preservation of multiple existing realm-and-character profiles.
- Preservation of independent character position, width, provider mode, and last-fight data.
- Mage-to-rogue profile switching without profile leakage.
- Existing MS-prefixed profile values take precedence over legacy values.
- Missing profiles and keys are copied from the legacy database.
- Changes to `MSThreatDB` do not mutate `OctoThreatDB`.
- The one-time `_moobStackMigration.octoThreat106` marker is written.
- Clean initialization without a legacy database creates a native MoobStack profile.
- The minimal legacy bridge loads only `OctoThreatDB` and successfully supplies it to MS Threat.
- `/msthreat status`, `/msthreat profile`, and the settings toggle execute through the new dispatcher.

## Provider regression checks

The runtime test also verified that Auto mode retains the existing provider priority:

1. Native absolute threat.
2. Fresh server absolute threat.
3. Local solo numeric estimate.
4. Native percentage-only ordering.

No provider calculation or display behavior was redesigned during the rebrand.

## Documentation checks

- Confirmed the repository `README.md` places **Changelog** before **Documentation**.
- Confirmed every new and legacy slash alias is documented.
- Confirmed action, visibility, positioning, provider, recovery, profile, report, reset, and bootstrap commands are documented.
- Confirmed installation and migration paths match the release archives.
- Confirmed README, standalone changelog, release notes, TOC, core, and bootstrap all report version 1.0.7.
- Confirmed the publisher disclaimer and World of Warcraft 1.12.1 / Interface 11200 wording are present.

## Archive checks

- Performed 168 static consistency and packaging assertions.
- Verified clean, update, and source ZIP CRC integrity.
- Verified the clean archive contains only the `MSThreat` top-level addon folder.
- Verified the clean archive contains no legacy migration bridge.
- Verified the update archive contains `MSThreat` plus the minimal `OctoThreat` migration bridge.
- Verified the update bridge does not contain the former full core, local provider, or UI implementation.
- Verified the source archive contains GitHub Markdown, release metadata, addon source, and migration-bridge source.
- Verified there is no accidental double nesting.

## Test scope

Validation included static source review, Lua syntax compilation, mocked runtime initialization, UI construction, command dispatch, profile migration, profile switching, provider-selection regression checks, documentation consistency, and ZIP validation.

The release was **not** executed inside a live World of Warcraft client in this environment.
