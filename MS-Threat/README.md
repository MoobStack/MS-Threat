# MS Threat

**MS Threat** is a lightweight, standalone current-target threat meter published by **MoobStack**. It sorts available party, raid, player, and optional pet threat data into one compact header with dynamically inserted rows, while keeping separate settings and fight history for every character.

- **Version:** 1.0.7
- **Publisher:** MoobStack
- **Internal addon name:** `MSThreat`
- **Client:** World of Warcraft 1.12.1
- **Interface:** 11200
- **Repository:** `MoobStack/MS-Threat`

> Designed for the World of Warcraft 1.12.1 client using Interface 11200. Compatibility may vary across community-maintained client modifications.

---

## Changelog

### 1.0.7

- Rebranded **OctoThreat** as **MS Threat** under the MoobStack publisher.
- Renamed the addon folder, TOC, source files, addon table, frames, UI branding, diagnostics, documentation, and primary saved-variable table to MS-prefixed names.
- Added `/msthreat`, `/mst`, and `/msthreatmeter` as the primary command aliases.
- Retained `/othreat` and `/octothreat` as legacy aliases for existing macros and user habits.
- Added migration from `OctoThreatDB` to `MSThreatDB` without deleting or modifying the legacy saved data.
- Added a temporary `OctoThreat` migration bridge for settings-preserving update installations.
- Preserved every existing realm-and-character profile, including meter position, appearance, provider mode, visibility options, warning settings, recovery settings, and last-fight history.
- Updated compatibility and documentation language to target the World of Warcraft 1.12.1 client and Interface 11200 without tying the addon to one community server project.
- Preserved the early command bootstrap, provider recovery, native and server threat paths, local solo estimator, compact row UI, and per-character profile behavior from version 1.0.6.

### Legacy history

Versions **1.0.0 through 1.0.6** were published under the **OctoThreat** name.

---

## Documentation

### Overview

MS Threat displays the threat table for the currently selected hostile NPC. It is intentionally minimal: the meter draws one header bar and only the active threat rows beneath it, without an enclosing background panel.

Rows are sorted from highest to lowest current threat. Depending on the active provider, each row can show:

- True threat rank.
- Player or pet name.
- Current tank marker.
- Percentage of the threat leader.
- Percentage toward the aggro-pull threshold.
- Absolute threat, when available.
- Rolling threat per second, when absolute threat is available.
- An estimated marker when using local solo calculations.

The local player receives a gold row marker. The detected tank receives a red marker and `[T]` indicator. The optional **Keep your row visible** setting keeps the local player on-screen when their true rank falls below the configured row limit.

MS Threat does **not** require pfUI, another threat addon, or other group members to install the same addon.

### Main features

- Compact single-header threat meter with dynamic rows.
- Descending threat sorting for the current hostile NPC target.
- Exact native threat support when exposed by the client.
- Compatible server-protocol support for eligible group encounters.
- Clearly marked local solo estimates when exact numeric data is unavailable.
- Optional player and pet tracking during solo combat.
- Absolute threat, percentage, and rolling TPS columns.
- Class-colored, threat-gradient, or neutral row styles.
- Configurable width, row height, row count, scale, and opacity.
- Hide while out of combat and hide without a hostile target options.
- Aggro-threshold header flash and optional warning sound.
- Automatic stale-data recovery after group, target, and provider transitions.
- Header **R** button and settings **Refresh** button for settings-safe recovery.
- Per-character profiles stored by realm and character name.
- Last-fight peak threat and maximum TPS report.
- Preview mode for positioning and appearance configuration.
- Early slash-command bootstrap with load diagnostics.
- Settings-preserving migration from OctoThreat 1.0.6.

---

## Threat providers and independence

MS Threat does not exchange calculated threat with other players' addon installations. In **Auto** mode, it selects the best locally available provider.

| Provider | Data | Typical use |
|---|---|---|
| `NATIVE` | Exact absolute threat, tank state, and pull percentage from client-exposed threat APIs | Preferred whenever available |
| `SERVER` | Exact group threat returned through the compatible TWT v4 server protocol | Eligible grouped elite and boss encounters |
| `LOCAL EST` | Estimated solo threat calculated from this client's combat messages | Ordinary solo combat when exact numeric data is unavailable |
| `NATIVE %` | Precise percentage ordering without absolute threat values | Clients exposing percentages but not absolute values |

### Auto provider priority

The practical priority is:

1. Native absolute threat.
2. Fresh exact server threat.
3. Local solo estimate when solo fallback is enabled.
4. Native percentage-only ordering when no absolute numeric table is available.

MS Threat never labels local combat-log calculations as exact. Estimated values use the `LOCAL EST` badge and a `~` prefix.

### Compatible server protocol

The server path sends the established `TWT_UDTSv4` query and reads `TWTv4=` responses. Availability is controlled by the client and server environment. It is normally restricted to party or raid combat against elite creatures or world bosses.

This is a server query, not peer-addon synchronization. Other players do not need MS Threat installed.

### Solo local estimator

When solo and exact numeric data is unavailable, MS Threat can estimate threat from locally visible combat messages. It tracks supported player damage, reflected damage, effective healing, visible form modifiers, and optional pet damage against the selected target.

The estimator cannot reconstruct every hidden threat rule. It is useful for solo questing, relative TPS review, and fight history, but it is deliberately marked as estimated.

---

## Installation

### Clean installation

1. Completely exit World of Warcraft.
2. Extract the `MSThreat` folder into:

   ```text
   World of Warcraft\Interface\AddOns\
   ```

3. Confirm the final path is:

   ```text
   World of Warcraft\Interface\AddOns\MSThreat\MSThreat.toc
   ```

4. Enable **MS Threat** on the character-selection AddOns screen.
5. Log in and verify the installation:

   ```text
   /msthreat status
   ```

Avoid a double-nested folder:

```text
Incorrect:
World of Warcraft\Interface\AddOns\MSThreat\MSThreat\MSThreat.toc
```

The configuration window and preview meter open automatically only for a newly created character profile.

---

## Updating from OctoThreat 1.0.6

Use the settings-preserving migration update. It contains two sibling addon folders:

```text
World of Warcraft\Interface\AddOns\MSThreat\
World of Warcraft\Interface\AddOns\OctoThreat\
```

The temporary `OctoThreat` folder is a saved-variable bridge. It loads `OctoThreatDB` before MS Threat starts, but it does not execute the former threat-meter implementation.

### Migration steps

1. Completely exit World of Warcraft.
2. Delete or move the existing full `OctoThreat` addon-code folder. This does not delete saved variables under `WTF`.
3. Extract the migration update directly into:

   ```text
   World of Warcraft\Interface\AddOns\
   ```

4. Confirm both files exist:

   ```text
   World of Warcraft\Interface\AddOns\MSThreat\MSThreat.toc
   World of Warcraft\Interface\AddOns\OctoThreat\OctoThreat.toc
   ```

5. Enable both AddOns-screen entries:

   ```text
   MS Threat
   MS Threat Legacy Migration
   ```

6. Log into a character that previously used OctoThreat.
7. Enter:

   ```text
   /msthreat status
   ```

8. Confirm the saved-data line reports one of the following:

   ```text
   legacy OctoThreatDB imported this session
   legacy migration complete
   ```

9. Log out normally or exit the client so `MSThreatDB` is written.
10. Verify the settings on the other characters whose profiles were stored in the former database.

OctoThreat 1.0.6 already stores all realm-and-character profiles in one account-wide table, so the complete profile container is copied during migration. The original `OctoThreatDB` is not erased or modified.

After migration has been verified, the temporary bridge may be disabled or deleted:

```text
World of Warcraft\Interface\AddOns\OctoThreat
```

After making a backup, the old saved-variable file may also be removed manually:

```text
WTF\Account\<Account>\SavedVariables\OctoThreat.lua
```

---

## Basic use

Open or close settings:

```text
/msthreat
```

Unlock the meter for movement:

```text
/msthreat unlock
```

Drag the header with the left mouse button, then lock it:

```text
/msthreat lock
```

Right-click the header to open settings. Click the small **R** button at the right edge of the header to restart transient roster and provider data without changing saved settings.

Show demonstration rows:

```text
/msthreat test
```

Print current provider and recovery diagnostics:

```text
/msthreat status
```

---

## User interface

### Meter header

The header displays:

- Addon name and current target.
- Active provider badge.
- A compact **R** refresh button.

Header interactions:

| Interaction | Action |
|---|---|
| Left-drag while unlocked | Move the meter |
| Right-click | Open settings |
| Click `R` | Restart transient roster/provider data without changing settings |

### Display settings

- Meter width: `180–520` pixels.
- Row height: `14–30` pixels.
- Maximum rows: `3–40`.
- Scale: `0.50–2.00`.
- Opacity: `20–100%`.
- Row style: class colors, threat gradient, or neutral blue.
- Show or hide threat values.
- Show or hide leader percentage.
- Show or hide threat per second.
- Abbreviate large numeric values.

### Behavior settings

- Hide while out of combat.
- Hide without a hostile NPC target.
- Include pets and guardians.
- Save the last-fight summary.
- Lock the meter position.
- Keep the local player's row visible.
- Estimate local threat while solo.
- Select Auto, Native, Server, or Local provider mode.
- Automatically recover stale threat data.
- Warn near the aggro-pull threshold.
- Play a warning sound.
- Warning threshold: `50–100%`.
- Update interval: `0.10–1.00` seconds.
- TPS averaging window: `2–15` seconds.

### Settings action buttons

| Button | Action |
|---|---|
| **Preview** | Show demonstration rows |
| **Refresh** | Restart transient threat data without changing settings |
| **Center** | Center and unlock the meter |
| **Last fight** | Print the latest fight report |
| **Defaults** | Reset the active character profile |
| **Done** | Close settings |

---

## Provider badges

| Badge | Meaning |
|---|---|
| `NATIVE` | Exact absolute threat from a client-exposed native API |
| `SERVER` | Exact absolute threat from the compatible server protocol |
| `NATIVE %` | Precise percentage ordering without absolute threat or TPS |
| `LOCAL EST` | Solo combat-log estimate; numeric values are prefixed with `~` |
| `PREVIEW` | Demonstration rows generated by the test command or UI |
| `REFRESH` | Roster and providers are being restarted |
| `WAIT` | Waiting for eligible combat or fresh provider data |
| `NO API` | Requested native provider is unavailable |
| `NO GROUP` | Server provider requires a party or raid |
| `NO DATA` | No usable provider returned data for the current situation |
| `NO TARGET` | A valid hostile NPC target is not selected |
| `IDLE` | Out of combat |

---

## Per-character profiles

MS Threat stores settings under realm-and-character keys inside:

```text
MSThreatDB.profiles["Realm::Character"]
```

Each character keeps independent:

- Meter position.
- Width, scale, opacity, and row layout.
- Visibility settings.
- Provider mode.
- Solo-estimation setting.
- Pet display setting.
- Aggro warning configuration.
- Automatic recovery configuration.
- Last-fight report.

List the active profile:

```text
/msthreat profile
```

List every saved profile:

```text
/msthreat profiles
```

Resetting settings affects only the active character profile.

---

## Recovery and group changes

Group and character transitions can briefly expose an incomplete roster on old clients. MS Threat includes several recovery mechanisms:

- Debounced party and raid roster refreshes.
- Group fingerprint checks for missed roster events.
- Delayed provider synchronization after entering the world.
- Short retention of the last valid native or server table through brief data gaps.
- Enabled-by-default automatic stale-data recovery.
- Manual settings-safe refresh through the header, settings UI, or command.

Manual recovery:

```text
/msthreat refresh
```

Aliases:

```text
/msthreat recover
/msthreat resetdata
```

Refresh restarts transient roster, provider, server-query, local-estimator, TPS, and warning state. It does not change the active profile's saved configuration or meter position.

---

## Aggro warning

The warning is based on percentage toward the provider's aggro-pull threshold rather than only percentage of the current threat leader.

When the local player crosses the configured threshold:

- The header flashes.
- An optional raid-warning sound plays.
- The warning resets after threat falls sufficiently below the threshold.

The warning is suppressed for the current tank and for locally estimated rows.

---

## Last-fight report

When absolute threat is available—either exact or locally estimated—MS Threat records each visible participant's:

- Peak threat.
- Maximum rolling TPS.
- Fight duration.
- Provider used.
- Whether the report is estimated.

Print the latest report:

```text
/msthreat report
```

Percentage-only data is not stored as if it were absolute threat.

---

## Commands

### Primary aliases

```text
/msthreat
/mst
/msthreatmeter
```

### Legacy aliases

```text
/othreat
/octothreat
```

All primary and legacy aliases use the same command dispatcher.

### Configuration and visibility

| Command | Description |
|---|---|
| `/msthreat` | Open or close settings. |
| `/msthreat config` | Open or close settings. |
| `/msthreat options` | Open or close settings. |
| `/msthreat show` | Enable and show the meter when visibility conditions permit. |
| `/msthreat hide` | Disable and hide the meter. |
| `/msthreat toggle` | Toggle the meter's enabled state. |

### Positioning and preview

| Command | Description |
|---|---|
| `/msthreat lock` | Lock the meter position. |
| `/msthreat unlock` | Unlock the meter and show preview rows for movement. |
| `/msthreat center` | Center and unlock the meter. |
| `/msthreat test` | Show demonstration rows for 15 seconds. |

### Providers and recovery

| Command | Description |
|---|---|
| `/msthreat provider auto` | Prefer the best available exact source, with solo estimate fallback. |
| `/msthreat provider native` | Use only client-exposed native threat data. |
| `/msthreat provider server` | Use only the compatible server threat protocol. |
| `/msthreat provider local` | Use only the local solo estimator. |
| `/msthreat refresh` | Restart transient roster and provider state without changing settings. |
| `/msthreat recover` | Alias for Refresh. |
| `/msthreat resetdata` | Alias for Refresh. |

### Profiles and reports

| Command | Description |
|---|---|
| `/msthreat profile` | Show the active realm-and-character profile and profile count. |
| `/msthreat profile status` | Alias for the active-profile summary. |
| `/msthreat profiles` | List all saved character profiles. |
| `/msthreat profile list` | Alias for listing profiles. |
| `/msthreat report` | Print the most recently recorded fight. |

### Diagnostics and reset

| Command | Description |
|---|---|
| `/msthreat status` | Print target, profile, migration, group, combat, provider, server-packet, local-estimator, and recovery diagnostics. |
| `/msthreat bootstrap` | Print early bootstrap and load-stage diagnostics. |
| `/msthreat loadstatus` | Alias for bootstrap diagnostics. |
| `/msthreat reset` | Restore defaults only for the active character profile. |
| `/msthreat help` | Print command help. |

---

## Saved variables and migration

### Current saved variable

```text
MSThreatDB
```

This account-wide table contains separate realm-and-character profiles.

### Legacy saved variable

```text
OctoThreatDB
```

During the migration update, the legacy table is deep-copied into `MSThreatDB`. Existing native MS Threat data takes precedence. The legacy table remains intact as a backup.

### Temporary compatibility identifiers

The following legacy identifiers intentionally remain during the transition:

```text
OctoThreat
OctoThreat_CommandDispatch
OctoThreatDB
/othreat
/octothreat
```

- `OctoThreat` is a runtime alias to the new `MSThreat` addon table.
- `OctoThreat_CommandDispatch` points to the new command dispatcher.
- `OctoThreatDB` is read only when the migration bridge loads it.
- Legacy slash commands remain supported for macros and existing habits.

---

## Troubleshooting

### The addon is enabled but commands are unrecognized

Confirm this path exists:

```text
World of Warcraft\Interface\AddOns\MSThreat\MSThreat.toc
```

Then enable script errors and reload:

```text
/console scriptErrors 1
/reload
```

The early command bootstrap is designed to keep `/msthreat` available even when a later file fails. Try:

```text
/msthreat bootstrap
```

### Settings did not migrate

Confirm both sibling folders are installed and enabled:

```text
MSThreat
OctoThreat
```

The second entry should be titled **MS Threat Legacy Migration**. Then run:

```text
/msthreat status
```

Log out normally after migration so `MSThreatDB` is written.

### The meter remains in WAIT after changing characters or groups

Use the settings-safe refresh:

```text
/msthreat refresh
```

Also confirm:

- Provider mode is `AUTO`.
- **Estimate my threat while solo** is enabled for solo play.
- **Auto-recover stale threat data** is enabled.
- A living hostile NPC is selected.

Print full diagnostics:

```text
/msthreat status
```

### The server provider reports NO GROUP or NO DATA

The compatible server protocol normally requires:

- A party or raid.
- An elite creature or world boss.
- Active group combat.
- Server support for the protocol.

Use Auto mode so native and local sources remain available where applicable:

```text
/msthreat provider auto
```

### The meter does not show out of combat

Disable **Hide while out of combat** in the Behavior tab. This is the master out-of-combat visibility setting.

### The meter does not record a solo fight

Use:

```text
/msthreat provider auto
```

Enable **Estimate my threat while solo**, select a hostile NPC, and begin combat. Local values should display with `LOCAL EST` and `~`.

---

## Known limitations

- MS Threat tracks only the currently selected hostile NPC.
- Native threat availability depends on the client build.
- Compatible server-protocol availability and encounter eligibility depend on the connected server environment.
- The local solo estimator cannot reconstruct every hidden flat-threat value, talent modifier, buff modifier, taunt, reset, partial wipe, overheal rule, or encounter-specific mechanic.
- Combat-log matching uses target names; simultaneous enemies with identical names cannot always be distinguished perfectly.
- Local estimation is solo-only and does not attempt to infer unseen party or raid members' threat.
- Percentage-only providers cannot supply absolute threat or TPS.
- A manual or automatic soft refresh begins a new tracking segment; any useful completed segment may become the latest fight report.

---

## Compatibility

MS Threat targets:

```text
World of Warcraft 1.12.1
Interface 11200
```

It uses frame-based Lua compatible with the original 1.12.1 addon environment and does not require modern Retail or current Classic APIs.

---

## License

MS Threat is distributed under the MIT License. See `LICENSE` for the complete terms.

---

## Publisher disclaimer

> MoobStack is an independent community addon publisher. These addons are not affiliated with, authorized by, or endorsed by Blizzard Entertainment or any community server project. World of Warcraft and related marks are the property of their respective owners.
