# Upgrading to MS Threat 1.0.8

## From MS Threat 1.0.7

1. Completely exit World of Warcraft.
2. Replace `Interface\AddOns\MSThreat` with the new `MSThreat` folder.
3. Preserve the `WTF` directory.
4. Log in and run:

   ```text
   /msthreat status
   ```

5. Confirm:

   ```text
   Version 1.0.8
   Provider mode: AUTO
   Fallbacks: solo on | group on
   ```

All existing profiles, positions, settings, and fight reports are preserved. Existing profiles receive the new `groupFallback` value through normal default filling.

## Directly from OctoThreat

Use the Update archive, which contains `MSThreat` and a small `OctoThreat` migration bridge. Enable both AddOns-screen entries, log into the affected characters, verify `/msthreat status`, and log out normally.

The bridge copies `OctoThreatDB` into `MSThreatDB` without erasing the former data. After migration survives another login, the temporary `OctoThreat` bridge can be removed.
