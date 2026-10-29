# In-client smoke test

**Status: not run.** No WoW Forever client was available during the adaptation. Tick items only after doing
them in the live client, and note the client build. Turn on Lua errors first: `/console scriptErrors 1`.

Use `tools/build.ps1 package-test` to build a test zip. It contains `TEST-BUILD-NOT-A-RELEASE.txt` and must not be published.

## First load

- [ ] The add-on appears in the AddOns list as **ForeverGuide**. Note whether it is flagged out of date: that shows whether `## Interface: 16001` matches the release client.
- [ ] Log in. No Lua errors, and `/fguide debug errors` is empty.
- [ ] If the client's interface is not 16001, chat says "built for interface 16001; this client reports …". Record the reported value.
- [ ] `/fguide debug` shows version, interface, quest db 0, guides 2 loaded and 0 rejected, open placeholders, and saved-data schema 1.
- [ ] `/fguide debug api`: record every line that says `no`.

## Window and settings

- [ ] The guide window opens at the right of the screen and looks like TBCGuide's: same layout, colours, progress bar and step rows. Drag, resize, minimise, lock and scale all work.
- [ ] The minimap button works: left-click opens settings, right-click toggles the guide window, and it can be dragged.
- [ ] `/fguide options` opens the settings window. Every tab opens. Change a setting, `/reload`, and confirm it persisted (PH-PLATFORM-SAVEDVARS).
- [ ] The options panel appears in the game's AddOns settings.

## Guide selection

- [ ] A new character of each original race gets "Alliance starting zones" or "Horde starting zones" automatically.
- [ ] `/fguide guide` opens the browser. The filters work, the guides show `?-?` levels and "(Pending WoW Forever data)", and the details show "Content status: placeholder".

## Step advancement and missing-data display

- [ ] The current step reads "Pending WoW Forever data: …" with a question-mark icon and the "Missing: … (PH-…)" detail line.
- [ ] No arrow, map pin or TomTom waypoint appears for a pending step.
- [ ] Left-click moves past the step. The bar text shows "N pending data" and the done count does not increase.
- [ ] After the last step, the window says "End of the available steps (… Pending WoW Forever data)", not "Guide finished!". Chat does not say "Guide complete".
- [ ] `/fguide prev` reopens the last deferred step. `/fguide reset` and `/fguide reset all` clear progress and keep settings.
- [ ] Accept and turn in any real quest: nothing in the guide advances (no false match), and quest automation does not accept it.

## Reload / relog persistence

- [ ] Defer two steps, `/reload`: both stay deferred. Log out and back in: still deferred, same guide active.
- [ ] Inspect the character file `WTF\Account\<account>\<realm>\<character>\SavedVariables\ForeverGuide.lua`: progress keys are step ids (`a.start.route`), not numbers.

## Other features

- [ ] `/fguide talents` shows "Talents: Pending WoW Forever data" with no TBC trees.
- [ ] `/fguide class` prints tips tagged "(TBC-era tips, not yet checked for WoW Forever)".
- [ ] Gear scoring is off by default. With `/fguide set gearEnabled on`, item tooltips show scores tagged "[TBC weights, unverified for WoW Forever]".
- [ ] Junk selling: off by default. When on, grey items sell at a vendor and protected items stay.
- [ ] `/fguide mark skull` on a target: record whether it marks or the client blocks it (PH-API-RAIDTARGET). The marker bar (`/fguide markbar`) works either way.
- [ ] `/fguide orphans` opens the orphan window. Record whether the quest-log "Orphaned" button appears.
- [ ] With TomTom installed (if a Forever build exists), nothing errors.

## Error handling

- [ ] Delete `ForeverGuide.lua` from SavedVariables and log in: defaults are rebuilt and nothing errors.
- [ ] Corrupt a progress entry by hand (for example `progress = "x"`): it is repaired on login.

## Coexistence with TBCGuide

- [ ] If TBCGuide loads on this client at all, enable both. There are no slash-command warnings, `/tbcg` and `/fguide` each open their own window, and each add-on's SavedVariables file contains only its own data.
