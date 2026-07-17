# Updating from OctoThreat 1.0.6 to MS Threat 1.0.7

1. Completely exit World of Warcraft.
2. Delete or move the existing full `Interface\AddOns\OctoThreat` addon-code folder. Saved variables under `WTF` are unaffected.
3. Extract `MoobStack-MSThreat-v1.0.7-Update.zip` directly into `Interface\AddOns`.
4. Confirm these sibling paths exist:

   ```text
   Interface\AddOns\MSThreat\MSThreat.toc
   Interface\AddOns\OctoThreat\OctoThreat.toc
   ```

5. Enable **MS Threat** and **MS Threat Legacy Migration**.
6. Log in and run `/msthreat status`.
7. Confirm the saved-data line says `legacy OctoThreatDB imported this session` or `legacy migration complete`.
8. Log out normally to save `MSThreatDB`.
9. Verify profiles and settings on the relevant characters.
10. Remove the temporary `OctoThreat` bridge after migration is confirmed.

The legacy `OctoThreatDB` data is not erased automatically.
