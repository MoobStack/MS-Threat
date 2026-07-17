# MS Threat

**MS Threat** is a lightweight, standalone current-target threat meter. It sorts available party, raid, player, and optional pet threat data into one compact header with dynamically inserted rows, while keeping separate settings and fight history for every realm-and-character profile.

- **Version:** 1.0.8
- **Publisher:** MoobStack
- **Internal addon name:** `MSThreat`
- **Client:** World of Warcraft 1.12.1
- **Interface:** 11200
- **Repository:** `MoobStack/MS-Threat`

> Designed for the World of Warcraft 1.12.1 client using Interface 11200. Compatibility may vary across community-maintained client modifications.

---

## Changelog

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

---

## Documentation

### Overview

MS Threat displays threat for the currently selected hostile NPC. The meter intentionally draws only one header bar and the active participant rows beneath it; there is no enclosing window background.

Rows are sorted from highest to lowest threat. Depending on the active provider, each row can show:

- Threat rank.
- Player or pet name.
- Current tank marker.
- Percentage of the threat leader.
- Percentage toward the aggro-pull threshold.
- Absolute threat, when available.
- Rolling threat per second, when absolute values are available.
- An estimate marker when values are reconstructed from local combat messages.

The local player receives a gold row marker. A detected tank receives a red marker and `[T]` indicator. **Keep your row visible** can retain the local player on-screen while preserving the player's real rank.

MS Threat does not require pfUI, another threat addon, or other group members to install MS Threat.

### Features

- Compact single-header current-target threat meter.
- Descending player and optional pet sorting.
- Exact native threat support when exposed by the client.
- Compatible exact server-protocol support for eligible grouped encounters.
- Native percentage-only ordering when absolute values are unavailable.
- Clearly marked solo and group local estimates when no exact table is available.
- Separate realm-and-character profiles.
- Automatic profile activation and transient-provider reset after changing characters.
- Player, party, raid, and optional pet rows in the local-estimation fallback.
- Damage and healing-message attribution for visible group members.
- Absolute threat, percentage, and rolling TPS columns.
- Class-colored, threat-gradient, or neutral row styles.
- Configurable width, row height, row count, scale, and opacity.
- Hide-while-out-of-combat and hide-without-target controls.
- Aggro-threshold header flash and optional warning sound.
- Automatic stale-data recovery.
- Header **R** refresh button and settings **Refresh** button.
- Per-character last-fight peak-threat and TPS reports.
- Early slash-command bootstrap and load diagnostics.
- Settings-preserving migration from OctoThreat.

---

### Threat providers

MS Threat never requires calculated threat to be exchanged between players' addon installations. Auto mode chooses the best source visible to the local client.

| Provider | Meaning | Typical use |
|---|---|---|
| `NATIVE` | Exact absolute threat from client-exposed threat APIs | Preferred whenever available |
| `SERVER` | Exact grouped threat returned through the compatible TWT v4 server protocol | Eligible grouped elite and boss encounters |
| `NATIVE %` | Precise ordering and percentages without absolute threat or TPS | When the client exposes percentages only |
| `GROUP EST` | Estimated group threat reconstructed from combat messages visible to this client | Ordinary grouped targets without exact data |
| `LOCAL EST` | Estimated player and optional pet threat reconstructed locally | Ordinary solo combat without exact data |

#### Auto-mode priority

Auto mode uses the following practical order:

1. Native absolute threat.
2. Fresh exact compatible-server threat.
3. Native percentage data during grouped combat.
4. Group or solo local estimate, depending on the current group state.
5. Native percentage data during solo combat when no numeric local table is available.

Local estimates never replace a fresh exact table and are never labeled exact.

#### Exact server-provider limits

The compatible server path is normally available only when all of the following are true:

- The player is in a party or raid.
- A hostile elite creature or world boss is selected.
- The local player or selected target is in the current fight.
- The connected environment supports the compatible threat protocol.

Server mode is intentionally strict. **Auto** is recommended because it can fall back to native percentage or local estimation where an exact server table is unavailable.

#### Local group estimation

Version 1.0.8 adds local group estimation for ordinary grouped fights. It creates rows for the visible roster and attributes supported party or raid damage and healing messages to the corresponding participant when they apply to the selected target.

Group-estimated values are marked with `GROUP EST` and a `~` prefix. They are useful for maintaining a populated, sorted meter without requiring another player's addon, but they remain estimates because the original 1.12.1 combat log does not expose every hidden threat component.

---

### Combat and character-switch recovery

Threat tracking is scoped to the **local player and selected target**. A different party member fighting somewhere else no longer keeps the current-target meter in combat or leaves it stuck in `WAIT`.

When the active character changes, MS Threat:

- Activates the correct realm-and-character profile.
- Clears previous native and server rows.
- Clears prior server-query target state.
- Clears local-estimator entries.
- Clears TPS samples and warning state.
- Rebuilds the current roster.
- Redetects available providers.
- Restores the new character's position and settings.
- Begins a fresh tracking segment only when the new character or selected target is actually in combat.

A short combat latch covers old-client event ordering, but the latch now expires automatically when live player and target combat evidence disappears.

---

### Installation

#### Clean installation

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
5. Log in and verify:

   ```text
   /msthreat status
   ```

Avoid a double-nested installation:

```text
Incorrect:
World of Warcraft\Interface\AddOns\MSThreat\MSThreat\MSThreat.toc
```

The configuration window and preview open automatically only for a newly created character profile.

#### Updating from MS Threat 1.0.7

1. Completely exit World of Warcraft.
2. Replace the existing folder:

   ```text
   World of Warcraft\Interface\AddOns\MSThreat
   ```

3. Install the version 1.0.8 `MSThreat` folder.
4. Do not delete `WTF` saved-variable files.
5. Log in and enter:

   ```text
   /msthreat status
   ```

Existing profiles receive the new `groupFallback` setting automatically. It defaults to enabled without replacing any other profile setting.

#### Updating directly from OctoThreat

Use the settings-preserving Update archive. It contains two sibling folders:

```text
World of Warcraft\Interface\AddOns\MSThreat\
World of Warcraft\Interface\AddOns\OctoThreat\
```

The temporary `OctoThreat` folder is a saved-variable bridge only. It loads `OctoThreatDB` before MS Threat starts and does not run the former threat-meter implementation.

1. Completely exit World of Warcraft.
2. Delete or move the old full `OctoThreat` code folder. Saved data under `WTF` is unaffected.
3. Extract the Update archive into `Interface\AddOns`.
4. Enable **MS Threat** and **MS Threat Legacy Migration**.
5. Log into the affected characters.
6. Verify migration:

   ```text
   /msthreat status
   /msthreat profiles
   ```

7. Log out normally so `MSThreatDB` is written.
8. After migration remains correct on a later login, disable or remove the temporary `OctoThreat` bridge.

The legacy table is copied as follows:

```text
OctoThreatDB
    → MSThreatDB
```

Legacy data is not erased.

---

### Basic use

Open settings:

```text
/msthreat
```

Unlock and move the meter:

```text
/msthreat unlock
```

Drag the header with the left mouse button, then lock it:

```text
/msthreat lock
```

Right-click the header to open settings. Click the small **R** button to restart transient threat data without changing the active character profile.

Show demonstration rows:

```text
/msthreat test
```

Print detailed diagnostics:

```text
/msthreat status
```

---

### User interface

#### Header interactions

| Interaction | Action |
|---|---|
| Left-drag while unlocked | Move the meter |
| Right-click | Open settings |
| Click `R` | Restart roster and provider data without changing settings |

#### Display settings

- Meter width: `180–520` pixels.
- Row height: `14–30` pixels.
- Maximum visible rows: `3–40`.
- Scale: `0.50–2.00`.
- Opacity: `20–100%`.
- Row style: class colors, threat gradient, or neutral blue.
- Threat-value column.
- Leader-percentage column.
- TPS column.
- Large-number abbreviation.

#### Behavior settings

- Hide while out of combat.
- Hide without a hostile NPC target.
- Include pets and guardians.
- Save last-fight summary.
- Lock meter position.
- Keep the local player's row visible.
- Estimate threat while solo.
- Estimate group threat locally when exact data is unavailable.
- Provider mode: Auto, Native, Server, or Local.
- Automatic stale-data recovery.
- Aggro warning and warning sound.
- Warning threshold: `50–100%`.
- Update interval: `0.10–1.00` seconds.
- TPS averaging window: `2–15` seconds.

#### Settings action buttons

| Button | Action |
|---|---|
| **Preview** | Show demonstration rows |
| **Refresh** | Restart transient threat data |
| **Center** | Center and unlock the meter |
| **Last fight** | Print the latest fight report |
| **Defaults** | Reset the active character profile |
| **Done** | Close settings |

---

### Provider and state badges

| Badge | Meaning |
|---|---|
| `NATIVE` | Exact absolute native threat |
| `SERVER` | Exact compatible-server threat |
| `NATIVE %` | Precise ordering and percentages only |
| `GROUP EST` | Group combat-log estimate; values are prefixed with `~` |
| `LOCAL EST` | Solo combat-log estimate; values are prefixed with `~` |
| `PREVIEW` | Demonstration data |
| `REFRESH` | Roster and providers are restarting |
| `WAIT` | Waiting for combat or data within the explicitly selected provider mode |
| `OFF` | The required local fallback is disabled |
| `NO API` | Native-only mode requested but unavailable |
| `NO GROUP` | Server-only mode requires a party or raid |
| `NO DATA` | The requested provider cannot supply data for this situation |
| `NO TARGET` | No valid hostile NPC target is selected |
| `IDLE` | The local player and selected target are out of combat |

---

### Per-character profiles

Profiles are stored under realm-and-character keys:

```text
MSThreatDB.profiles["Realm::Character"]
```

Each profile keeps independent:

- Meter position and dimensions.
- Scale, opacity, and row layout.
- Visibility options.
- Provider mode.
- Solo-estimation setting.
- Group-estimation setting.
- Pet-display setting.
- Aggro-warning configuration.
- Automatic recovery configuration.
- Last-fight report.

Show the active profile:

```text
/msthreat profile
```

List all profiles:

```text
/msthreat profiles
```

`/msthreat reset` affects only the active character profile.

---

### Recovery

Manual recovery restarts only transient state:

```text
/msthreat refresh
```

Aliases:

```text
/msthreat recover
/msthreat resetdata
```

Refresh clears and reacquires roster entries, native rows, compatible-server state, local-estimator rows, TPS history, provider selection, and warning state. It preserves the active profile's settings and meter position.

Automatic recovery performs one settings-safe refresh after a valid current-target fight remains empty for the configured recovery delay.

---

### Aggro warning

The aggro warning uses percentage toward the provider's pull threshold when that value is available. When the local player crosses the configured threshold:

- The header flashes.
- An optional warning sound plays.
- The warning resets after threat falls sufficiently below the threshold.

Warnings are suppressed for the current tank and for locally estimated rows.

---

### Last-fight report

When absolute threat is available—exact or estimated—MS Threat can record:

- Peak threat per visible participant.
- Maximum rolling TPS.
- Fight duration.
- Provider used.
- Whether the report was estimated.

Print the latest report:

```text
/msthreat report
```

Percentage-only data is not stored as absolute threat.

---

### Commands

#### Primary aliases

```text
/msthreat
/mst
/msthreatmeter
```

#### Legacy aliases

```text
/othreat
/octothreat
```

All aliases use the same command dispatcher.

#### Configuration and visibility

| Command | Description |
|---|---|
| `/msthreat` | Open or close settings. |
| `/msthreat config` | Open or close settings. |
| `/msthreat options` | Open or close settings. |
| `/msthreat show` | Enable and show the meter when visibility conditions permit. |
| `/msthreat hide` | Disable and hide the meter. |
| `/msthreat toggle` | Toggle the meter's enabled state. |

#### Positioning and preview

| Command | Description |
|---|---|
| `/msthreat lock` | Lock the meter position. |
| `/msthreat unlock` | Unlock the meter and show preview rows for movement. |
| `/msthreat center` | Center and unlock the meter. |
| `/msthreat test` | Show demonstration rows for 15 seconds. |

#### Providers and local estimation

| Command | Description |
|---|---|
| `/msthreat provider auto` | Prefer exact native/server data, then the appropriate local estimate or percentage table. |
| `/msthreat provider native` | Use only client-exposed native threat data. |
| `/msthreat provider server` | Use only the compatible exact server protocol. |
| `/msthreat provider local` | Use only local estimation for the current solo/group state. |
| `/msthreat soloest on` | Enable solo local estimation. |
| `/msthreat soloest off` | Disable solo local estimation. |
| `/msthreat soloestimate on\|off` | Alias for `soloest`. |
| `/msthreat groupest on` | Enable grouped local estimation. |
| `/msthreat groupest off` | Disable grouped local estimation. |
| `/msthreat groupestimate on\|off` | Alias for `groupest`. |

#### Recovery

| Command | Description |
|---|---|
| `/msthreat refresh` | Restart transient threat data without changing settings. |
| `/msthreat recover` | Alias for Refresh. |
| `/msthreat resetdata` | Alias for Refresh. |

#### Profiles and reports

| Command | Description |
|---|---|
| `/msthreat profile` | Show the active profile and saved-profile count. |
| `/msthreat profile status` | Alias for the active-profile summary. |
| `/msthreat profiles` | List all saved realm-and-character profiles. |
| `/msthreat profile list` | Alias for listing profiles. |
| `/msthreat report` | Print the most recently recorded fight. |

#### Diagnostics and reset

| Command | Description |
|---|---|
| `/msthreat status` | Print profile, combat-scope, provider, server, fallback, local-parser, and recovery diagnostics. |
| `/msthreat bootstrap` | Print early command-bootstrap and initialization diagnostics. |
| `/msthreat loadstatus` | Alias for Bootstrap. |
| `/msthreat reset` | Restore defaults only for the active character profile. |
| `/msthreat help` | Print command help. |

---

### Troubleshooting

#### The meter remains in WAIT after changing characters

Version 1.0.8 repairs the provider and combat-state causes of this issue. Verify:

```text
/msthreat status
```

The output should show:

```text
Version 1.0.8
Provider mode: AUTO
Fallbacks: solo on | group on
```

For ordinary grouped targets without exact data, the meter should switch to `GROUP EST` after the player or selected target enters combat.

#### The meter says IDLE while another party member is fighting

This is intentional when neither the local player nor selected target is in that fight. Threat is scoped to the selected target rather than unrelated group activity.

#### Group-estimated rows do not increase

Confirm:

- **Estimate group threat locally** is enabled.
- Provider mode is `AUTO` or `LOCAL`.
- A living hostile NPC is selected.
- The local client receives party or raid combat messages for that target.

Use:

```text
/msthreat status
```

The local diagnostics report matched group events, rejected sources, and unmatched messages.

#### Server mode shows NO DATA or WAIT

Server-only mode normally requires a grouped elite or world-boss encounter supported by the connected environment. Use Auto mode for broader coverage:

```text
/msthreat provider auto
```

#### Commands are unrecognized

Confirm:

```text
World of Warcraft\Interface\AddOns\MSThreat\MSThreat.toc
```

Enable script errors and reload:

```text
/console scriptErrors 1
/reload
```

Then use:

```text
/msthreat bootstrap
```

#### Settings did not migrate from OctoThreat

Confirm both `MSThreat` and the temporary `OctoThreat` migration bridge are installed and enabled. Then run:

```text
/msthreat status
```

Log out normally after migration so the new account-wide database is written.

---

### Known limitations

- MS Threat tracks only the currently selected hostile NPC.
- Native threat availability depends on the client build.
- Compatible exact-server availability depends on the connected environment and encounter eligibility.
- Group and solo local estimates cannot reconstruct hidden flat threat, all stance/talent/buff modifiers, taunts, resets, partial wipes, overheal rules, or encounter-specific mechanics.
- Other players' hidden stance, talents, and threat modifiers cannot be determined reliably from combat messages.
- Combat-message matching is name-based; simultaneous enemies with identical names can be ambiguous.
- Local group estimates include only messages visible to the local client.
- Percentage-only providers cannot supply absolute threat or TPS.
- A manual or automatic refresh begins a new tracking segment; a useful completed segment may become the latest fight report.

---

### Saved variables and temporary legacy identifiers

Current account-wide database:

```text
MSThreatDB
```

Temporary legacy identifiers retained for migration or integration compatibility:

```text
OctoThreat
OctoThreat_CommandDispatch
OctoThreatDB
/othreat
/octothreat
```

`OctoThreatDB` is read only when the migration bridge loads it and is not erased automatically.

---

### Compatibility

```text
World of Warcraft 1.12.1
Interface 11200
```

MS Threat uses frame-based Lua compatible with the original 1.12.1 addon environment and does not require modern Retail or current Classic APIs.

---

### License

MS Threat is distributed under the MIT License. See `LICENSE` for the complete terms.

---

### Publisher disclaimer

> MoobStack is an independent community addon publisher. These addons are not affiliated with, authorized by, or endorsed by Blizzard Entertainment or any community server project. World of Warcraft and related marks are the property of their respective owners.
