# MS Threat 1.0.7

## Description

MS Threat is a lightweight, standalone current-target threat meter by MoobStack. It displays one compact header with dynamically inserted threat rows, sorts available players and optional pets by threat, supports exact native or compatible server data, and provides a clearly marked local estimate during ordinary solo combat. It does not require pfUI, another threat addon, or other group members to install it.

Designed for the World of Warcraft 1.12.1 client using Interface 11200. Compatibility may vary across community-maintained client modifications.

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

| Command | Purpose |
|---|---|
| `/msthreat` | Open or close settings. |
| `/msthreat show` | Enable the meter. |
| `/msthreat hide` | Disable and hide the meter. |
| `/msthreat toggle` | Toggle the enabled state. |
| `/msthreat lock` | Lock the meter position. |
| `/msthreat unlock` | Unlock the meter for dragging. |
| `/msthreat center` | Center and unlock the meter. |
| `/msthreat test` | Show preview rows. |
| `/msthreat status` | Print profile, provider, group, packet, local-estimator, and recovery diagnostics. |
| `/msthreat report` | Print the latest fight summary. |
| `/msthreat profile` | Show the active character profile. |
| `/msthreat profiles` | List all saved character profiles. |
| `/msthreat refresh` | Restart transient threat data without changing settings. |
| `/msthreat recover` | Alias for Refresh. |
| `/msthreat resetdata` | Alias for Refresh. |
| `/msthreat provider auto` | Use the best available provider with solo fallback. |
| `/msthreat provider native` | Use native client threat data only. |
| `/msthreat provider server` | Use compatible server threat data only. |
| `/msthreat provider local` | Use the local solo estimate only. |
| `/msthreat reset` | Reset the active character profile. |
| `/msthreat bootstrap` | Show early load diagnostics. |
| `/msthreat help` | Print command help. |

## Installation

Install the addon at:

```text
World of Warcraft\Interface\AddOns\MSThreat\MSThreat.toc
```

For migration from OctoThreat 1.0.6, install both sibling folders from the update archive, enable **MS Threat** and **MS Threat Legacy Migration**, run `/msthreat status`, and log out normally after migration succeeds.

## Publisher disclaimer

MoobStack is an independent community addon publisher. These addons are not affiliated with, authorized by, or endorsed by Blizzard Entertainment or any community server project. World of Warcraft and related marks are the property of their respective owners.
