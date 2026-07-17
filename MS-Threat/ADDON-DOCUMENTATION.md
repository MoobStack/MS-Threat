# MS Threat 1.0.8 — Addon documentation

## Description

MS Threat is a compact current-target threat meter for the World of Warcraft 1.12.1 client. It prefers exact native or compatible-server data and can independently display clearly marked solo or group estimates from combat messages visible to the local client when exact data is unavailable.

The meter keeps separate realm-and-character profiles and displays only one header with the active player rows beneath it.

## Provider badges

- `NATIVE` — exact native absolute threat.
- `SERVER` — exact compatible-server threat.
- `NATIVE %` — precise percentage ordering without absolute values.
- `GROUP EST` — grouped local estimate.
- `LOCAL EST` — solo local estimate.
- `IDLE` — the local player and selected target are out of combat.
- `WAIT` — the explicitly selected provider is waiting for eligible combat or data.

## Primary commands

```text
/msthreat
/mst
/msthreatmeter
```

Legacy aliases:

```text
/othreat
/octothreat
```

## Commands

```text
/msthreat                         Open or close settings.
/msthreat show|hide|toggle        Control meter visibility.
/msthreat lock|unlock|center      Position the meter.
/msthreat test                    Show preview rows.
/msthreat provider auto|native|server|local
/msthreat soloest on|off          Toggle solo local estimation.
/msthreat groupest on|off         Toggle grouped local estimation.
/msthreat refresh                 Restart transient threat data.
/msthreat recover                 Alias for Refresh.
/msthreat resetdata               Alias for Refresh.
/msthreat profile                 Show the active character profile.
/msthreat profiles                List saved profiles.
/msthreat report                  Print the last-fight report.
/msthreat status                  Print provider and recovery diagnostics.
/msthreat bootstrap               Print early load diagnostics.
/msthreat loadstatus              Alias for Bootstrap.
/msthreat reset                   Reset the active profile.
/msthreat help                    Print command help.
```

## Recommended setup

```text
/msthreat provider auto
/msthreat soloest on
/msthreat groupest on
```

## Compatibility

Designed for the World of Warcraft 1.12.1 client using Interface 11200. Compatibility may vary across community-maintained client modifications.
