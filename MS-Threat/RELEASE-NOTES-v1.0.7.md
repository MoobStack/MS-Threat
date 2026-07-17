# MS Threat v1.0.7

MS Threat v1.0.7 is the MoobStack rebrand of OctoThreat 1.0.6. The release preserves the existing standalone threat meter, provider recovery, local solo estimator, compact UI, and realm-and-character profiles while moving the addon to MS-prefixed identifiers and documentation.

## Changes

- Rebranded OctoThreat as **MS Threat** by MoobStack.
- Renamed the installed addon folder and TOC to `MSThreat`.
- Renamed Lua files, addon globals, frame names, UI titles, messages, diagnostics, and the saved-variable table.
- Added `/msthreat`, `/mst`, and `/msthreatmeter`.
- Retained `/othreat` and `/octothreat` as legacy aliases.
- Added a one-time migration path from `OctoThreatDB` to `MSThreatDB`.
- Preserved all existing character profiles and their settings.
- Updated documentation for the World of Warcraft 1.12.1 client and Interface 11200.
- Preserved all working behavior from OctoThreat 1.0.6.

## Clean installation

1. Completely exit World of Warcraft.
2. Extract `MSThreat` into `World of Warcraft\Interface\AddOns\`.
3. Confirm `World of Warcraft\Interface\AddOns\MSThreat\MSThreat.toc` exists.
4. Enable **MS Threat** at character selection.
5. Log in and run `/msthreat status`.

## Updating from OctoThreat 1.0.6

Use the update archive. It contains:

```text
MSThreat/
OctoThreat/
```

The `OctoThreat` folder is only a saved-variable bridge; it does not run the old meter.

1. Exit World of Warcraft.
2. Remove or move the former full `OctoThreat` addon-code folder.
3. Extract the update archive into `Interface\AddOns`.
4. Enable **MS Threat** and **MS Threat Legacy Migration**.
5. Log in and run `/msthreat status`.
6. Confirm the saved-data line reports that migration was imported or completed.
7. Log out normally so `MSThreatDB` is saved.
8. After verification, remove the temporary `OctoThreat` bridge folder if desired.

The migration does not erase `OctoThreatDB`.

## Compatibility

- World of Warcraft 1.12.1 client.
- Interface 11200.
- No peer addon requirement.
- pfUI is not required.
- Native and server provider availability may vary by client and server environment.

## Downloads

- `MoobStack-MSThreat-v1.0.7.zip` — clean installation containing only `MSThreat`.
- `MoobStack-MSThreat-v1.0.7-Update.zip` — settings-preserving update containing `MSThreat` and the temporary `OctoThreat` migration bridge.
- `MoobStack-MS-Threat-v1.0.7-Repository.zip` — GitHub-ready repository source and documentation bundle.
