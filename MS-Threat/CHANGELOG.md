# Changelog

### 1.0.8

- Fixed a cross-character and grouped-combat failure that could leave the meter permanently showing `WAIT` after changing characters.
- Added a per-profile **group local-estimation fallback** for ordinary grouped targets when exact native or compatible server data is unavailable.
- Added the `GROUP EST` provider badge and clearly marked estimated group rows.
- Added `/msthreat groupest on|off` and `/msthreat soloest on|off` commands.
- Added a Behavior-page option named **Estimate group threat locally**.
- Changed combat-state detection to use the local player and selected target rather than any group member fighting elsewhere.
- Added automatic expiry of a stale combat latch when an old client misses or delays the expected combat-end event.
- Restricted exact server queries to combat involving the selected target, preventing unrelated group activity from keeping the provider in `WAIT`.
- Added local parsing for visible party and raid damage and healing messages against the current target.
- Kept native absolute threat, compatible server threat, and native percentage tables ahead of local estimates in Auto mode.
- Re-baselined roster, native, server, local-estimator, TPS, warning, and recovery state when the active character profile changes.
- Updated `/msthreat status` with combat-scope and separate solo/group fallback diagnostics.
- Preserved existing profiles, positions, appearance settings, provider choices, fight reports, primary commands, and legacy command aliases.
- Updated GitHub documentation, release notes, upgrade instructions, and validation materials for version 1.0.8.

### 1.0.7

- Rebranded **OctoThreat** as **MS Threat** under the MoobStack publisher.
- Added migration from `OctoThreatDB` to `MSThreatDB` without deleting legacy data.
- Added primary `/msthreat`, `/mst`, and `/msthreatmeter` aliases while retaining `/othreat` and `/octothreat`.
- Preserved separate realm-and-character profiles and the existing native, server, percentage, and solo-local providers.

### Legacy history

Versions **1.0.0 through 1.0.6** were published under the **OctoThreat** name.
