# MS Threat v1.0.8

MS Threat 1.0.8 fixes the persistent `WAIT` state seen after changing characters and expands independent threat coverage for ordinary grouped combat.

## Changes

- Fixed combat detection that could treat an unrelated party member's fight as the selected target's encounter.
- Fixed stale combat latches that could survive a missed or delayed combat-end event.
- Added `GROUP EST`, an independent local group-estimation fallback for ordinary grouped targets without exact data.
- Added visible party and raid damage/healing attribution for the selected target.
- Added a per-character **Estimate group threat locally** setting.
- Added `/msthreat groupest on|off` and `/msthreat soloest on|off`.
- Kept native absolute, exact compatible-server, and native percentage data ahead of local estimates.
- Reinitialized transient roster/provider state when the active character profile changes.
- Expanded `/msthreat status` diagnostics.

## Installation

### Updating MS Threat 1.0.7

1. Completely exit World of Warcraft.
2. Replace `Interface\AddOns\MSThreat` with the folder from the Clean archive.
3. Do not delete the `WTF` saved-variable files.
4. Log in and run `/msthreat status`.

Existing profiles automatically receive the new group-estimation option, enabled by default.

### Clean installation

Extract the Clean archive into `Interface\AddOns` and confirm:

```text
Interface\AddOns\MSThreat\MSThreat.toc
```

### Updating directly from OctoThreat

Use the Update archive. It contains:

```text
MSThreat\
OctoThreat\
```

Enable **MS Threat** and **MS Threat Legacy Migration**, log into the affected characters, verify `/msthreat status`, and log out normally. The temporary legacy bridge can be removed after migration is confirmed.

## Recommended provider setting

```text
/msthreat provider auto
/msthreat soloest on
/msthreat groupest on
```

Auto mode prefers exact data and uses a clearly marked local estimate only when needed.

## Compatibility

World of Warcraft 1.12.1 — Interface 11200.

## Downloads

- `MoobStack-MSThreat-v1.0.8-Clean.zip` — clean installation and direct update from MS Threat 1.0.7.
- `MoobStack-MSThreat-v1.0.8-Update.zip` — includes the temporary OctoThreat saved-variable migration bridge.
- `MoobStack-MSThreat-v1.0.8-Source.zip` — repository-ready source and documentation.

The release has been syntax-checked and tested in a mocked World of Warcraft 1.12.1 runtime. It has not yet been executed inside the live game client.
