# Changelog

## 1.0.7

- Rebranded **OctoThreat** as **MS Threat** under the MoobStack publisher.
- Renamed the addon folder, TOC, source files, addon table, frames, UI branding, diagnostics, documentation, and primary saved-variable table to MS-prefixed names.
- Added `/msthreat`, `/mst`, and `/msthreatmeter` as primary aliases.
- Retained `/othreat` and `/octothreat` as legacy aliases.
- Added settings-preserving migration from `OctoThreatDB` to `MSThreatDB` without deleting the legacy data.
- Added a temporary legacy migration bridge for update installations.
- Preserved all realm-and-character profiles, positions, provider choices, appearance settings, behavior settings, recovery settings, and fight reports.
- Replaced server-specific product language with World of Warcraft 1.12.1 and Interface 11200 compatibility wording.
- Preserved the early command bootstrap, exact native/server providers, solo estimator, recovery controls, and compact meter behavior from version 1.0.6.

## Legacy history

Versions **1.0.0 through 1.0.6** were published under the **OctoThreat** name.

### 1.0.6

- Replaced Lua 5.1-style vararg forwarding with fixed-arity protected calls compatible with the WoW 1.12 Lua runtime.
- Added an early slash-command bootstrap and load-stage diagnostics.
- Retried guarded initialization during addon load, login, world entry, and the first slash command.

### 1.0.5

- Added realm-and-character keyed profiles.
- Separated settings, positions, provider preferences, and last-fight history between characters.
- Restarted all transient providers after character changes.

### 1.0.4

- Added the header refresh button.
- Improved combat latching, stealth-heavy class behavior, visibility, provider retention, and server-packet diagnostics.

### 1.0.3

- Added settings-safe refresh and automatic stale-data recovery after group changes.

### 1.0.2

- Added the clearly marked local solo threat estimator and solo fight recording.

### 1.0.1

- Fixed sparse old-client roster arrays and hardened row rendering.

### 1.0.0

- Initial release with native and server threat providers, compact sorted rows, aggro warnings, TPS, fight reports, and configuration UI.
