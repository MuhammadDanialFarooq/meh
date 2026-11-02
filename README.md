# Paintland V39 beta — reference-inspired polish and cosmetics

A targeted repair of the supplied PaintlandClient V26 Roblox model. The original
upload is retained unchanged in `models/`; editable Luau sources are in
`model-source/`. The importable result is `dist/PaintlandClient_v39.rbxmx`.

## Install in Roblox Studio

1. Save a backup of your place. Stop the play session.
2. Remove the previous **PaintlandClient** folder from **StarterPlayer > StarterPlayerScripts** to prevent duplicate bootstraps.
3. Insert `dist/PaintlandClient_v39.rbxmx` there using Explorer's **Insert from File**. Keep its `Paintland` LocalScript and `PaintlandModules` folder together under `PaintlandClient`.
4. Press Play and check **View > Output**. Studio regression tests are enabled by `Config.RunVictoryRegressionTests`. They run isolated test worlds before the game starts. Two warnings containing `intentional VFX failure` are expected from the error-isolation test; other failures need investigation.
5. Check a normal loop, a large enclosure, a loop along the wall, simultaneous bot captures, a self-trail death, revive/replay, and reaching 100%. Use Device Emulator to check portrait/landscape layouts and touch steering. Check the minimap during captures and after resizing.

## V39 style, motion and cosmetics

The supplied **Kaboom Kablow** place was decoded and its saved lighting and UI
source inspected. See `docs/reference-style.md` for concrete findings and how
they were adapted. Its scripts were not executed or copied into this game.

- Bright afternoon lighting, soft purple/pink light accents, saturated color correction and animated menu blur. Blur clears in gameplay and on the death screen so trails and the frozen death backdrop stay readable. `LightingController` restores previous base settings on teardown.
- Damped-spring hover/press/release feedback on menu, wardrobe, audio, revive, victory and death buttons, plus spring panel entrances. Updates use the existing render loop, not a separate connection for every frame/button.
- Capture/kill character bounces and smoother, size-preserving confetti shrink/fade. The existing capture flashes, kill bursts and trail joins remain.
- **HATS & FACES** on the main menu opens a wardrobe with a live 3D preview. Cycle hats/faces and select **LOOKING GOOD** to return. Choices carry into play, death/revive and replay in the current session.
- Hats: None, Cap, Crown, Top Hat, Halo and Wizard. Faces: Happy, Wink, Fierce and Shades. All default geometry is generated in code, so no external hat/face asset is required. Bots get randomized choices too.

Settings in `PaintlandModules > Config`:

| Setting | Purpose |
| --- | --- |
| `StylizedLighting` | Enable the new local lighting style |
| `LightingContrast`, `LightingSaturation`, `MenuBlurSize` | Tune the grade and menu blur |
| `ReducedMotion` | Disable button/character bounce and moving preview rotation |
| `RandomBotCosmetics` | Give bots varied hats/faces |
| `CosmeticHats` | Optional list of supported procedural hat names |
| `CosmeticFaces` | Optional `{Name, Style, ImageId}` face presets; ImageId overrides the procedural face |

These are free session choices, not a paid shop or persistent unlock system.
Existing `PlayerCosmetics` defaults and the cosmetic API remain available. Custom
face images still need permission for the experience. The new defaults require
no uploads and the eight-song playlist remains configured.

Headless tests exercise wardrobe selection/callbacks, spring settling, reduced
motion, lighting restoration, all 24 default hat/face combinations, custom face
images, preview setup and gameplay pulses. Those use Roblox value/instance
doubles, so Studio checks remain essential: inspect face/hat positioning, hover
and press feedback, menu blur, live preview, selected appearance after revive,
lighting contrast on trails and mobile performance. The reference-inspired look
is not claimed to be an exact visual replica.

## V38 background playlist

The eight songs supplied in `songs.rbxmx` are configured in Music1–Music8 order.
The source model is retained as `models/songs.rbxmx`; you do not need to insert it
separately because the game creates its own Sound and music group at runtime.
The original relative track levels (0.3, except Music5 at 0.4) and group play
volume (0.6) are retained. Playback starts in the menu and loops the playlist.

While playing, the normal mix uses neutral EQ. The main menu, revive and defeat
screens use a quieter mix (group volume 0.18), with high frequencies reduced
by 25 dB and mids by 10 dB. Volume and EQ transition over 0.65 seconds. The same
song keeps its position across menu/play/replay/death transitions; its pitch is
not changed. Muting music silences the music group without rewinding the track.

The bottom-right **MUSIC** and **SFX** buttons are independent. Effects retain
their muted default; music starts enabled. Both controls are hidden during the
revive/defeat prompt to keep the result layout clean. A song that fails to load
within 12 seconds is skipped for the session with an Output warning; an
all-unplayable playlist stops instead of retrying endlessly.

In **PaintlandModules > Config**, edit:

| Setting | Purpose |
| --- | --- |
| `MusicTrackIds` | The eight song IDs; add/remove/reorder entries here |
| `MusicTrackVolumes` | Per-track relative levels, matching playlist order |
| `MusicPlayVolume`, `MusicMenuVolume` | Normal and quieter group volumes |
| `MusicMenuHighGain`, `MusicMenuMidGain` | Menu muffling in decibels; 0 removes EQ reduction |
| `MusicFadeSeconds` | Mix transition length |
| `MusicEnabled`, `MusicMutedByDefault` | Enable/disable and initial mute state |

Automated tests verify imported IDs/order/relative levels, playlist wrapping,
mode/mute continuity, EQ targets, failed-track skipping and cleanup. These use
Sound doubles and do not verify Roblox asset access or audible quality. In
Studio, allow each audio asset for your experience if required, listen to menu →
Play → defeat → replay, verify no song restart, and check both mute buttons.

## V37 preserve the mainland after cuts

Connectivity cleanup no longer chooses the territory closest to the head. That
rule could retain a tiny sliver and erase the much larger mainland after a cut.
Cleanup now keeps the **largest four-connected owned component**. Head position
only breaks equal-size ties. A second owned bridge keeps both sides in the same
component, so neither side is removed just because the first bridge was cut.

Only genuinely disconnected smaller pieces become neutral. Actual enemy-captured
cells are not restored, and a path painted by another owner is not treated as
your connection. This rule applies through the shared capture/join loser cleanup;
the winner is still never pruned during its own capture or join.

The new tests reproduce the V36 loss, check a head on a tiny fragment and a head
outside land, verify a second owned bridge, check equal-size ties and run the
actual World loser-cleanup path. Existing crossing joins, captures, victory,
revive/defeat UI, menu demo and effect checks pass. Verify the reported cut in
Studio; the tests establish ownership behavior, not engine rendering.

## V36 crossing joins

Trail joins now claim the recorded bridge even where it passes through another
owner's territory. The previous version explicitly blocked those cells, leaving
inherited land detached and vulnerable to later connectivity pruning. Only the
actual trail/contact route can cross rival land; no unrelated shortcut is carved.

Both sides of the join use this rule: the winner's active trail and the defeated
trail back to its territory. Third-party heads covered by the bridge, or rivals
left with no land, are eliminated consistently with normal closed-loop captures.
Surviving crossed owners retain their largest connected fragment (the V37 rule). The winner is not pruned as part of its own join.

Regression tests reproduce the V35 failure, verify four-connected joins through
rival territory on either trail, run later connectivity cleanup to ensure the
inherited area stays connected, and check covered-head/last-tile eliminations,
loser fragment cleanup and counts. The full existing gameplay, menu and effect
tests also pass. Verify the same crossing in Studio; a later genuine enemy cut
through the bridge can still split territory under the normal game rules.

## V35 live main-menu backdrop

Opening the game or returning to Main Menu starts an independent, silent
bot-only match behind the translucent menu. Eight bots move, draw trails, capture
land, eliminate each other and respawn using the actual game simulation. The
camera gently follows a bot and periodically changes targets; a dead target is
replaced. The background resets after 55 seconds or completion so the menu does
not settle into an empty/end-state arena.

Pressing Play stops the demo and creates a fresh human match. Demo ownership,
stats, trails and effects do not carry over. It has no player input, audio reward,
purchase/revive or gameplay HUD callbacks. The death screen still freezes the
player's game until Play Again or Main Menu is selected. Returning to Main Menu
then starts a new demo rather than resuming the dead player's round.

Adjust `MenuDemoBots`, `MenuDemoRoundSeconds` and `MenuDemoFollowSeconds` in
Config. No extra service, animation asset or background task is required. The
existing render-step loop advances the demo and stops doing so on Play.

Headless tests run demo movement/captures/respawns, dead-camera-target replacement,
completion/timed resets and the stopped-demo-to-fresh-game handoff. They cannot
verify the actual camera composition or device frame rates; check the main menu
in Studio and on a phone, then Play, die, return to menu, and Play again.

## V34 clarified map size

The requested size increase applies to the **minimap**. It is now 190 pixels wide
on desktop and 144 on phones (previously 142 and 108); short landscape displays
use 96 instead of 76 to keep it clear of the rest of the HUD. Change
`MinimapDesktopSize` and `MinimapPhoneSize` in Config to tune it.

The V33 arena/camera changes have been reverted: `Grid=112`,
`WorldViewHeightStuds=124`, `MobileWorldViewHeight=144`. The reference-style death
screen, image icons and Play Again/Main Menu actions remain. The renderer's
phone-aware effect scaling correction is retained.

## V33 death screen and arena scale

The death screen now follows the supplied layout: a red **OOF**, white
**You conquered X% land** text, a green **PLAY AGAIN** button and a yellow
**MAIN MENU** button. The frozen game remains visible through a translucent black
overlay. There is no solid menu card or gradient on the death screen. Tile count
and eliminations appear as smaller secondary text. Play Again starts a clean run
with the selected color; Main Menu returns to color selection without starting.
Buttons use ImageLabel icons from the common Material icon atlas. Optional
`DefeatPlayIconId` and `DefeatMenuIconId` in Config replace them with full custom
image assets (numbers or `rbxassetid://...` strings); cropping is removed for custom
images. Those images must be accessible to the experience. Check them in Studio.

The playable grid increases from 112 to 144 cells per side while retaining tile
size and movement speed. This gives more arena space without inflating individual
tiles. The camera is also closer: `WorldViewHeightStuds=112` on desktop and
`MobileWorldViewHeight=124` on phones. A smaller view-height value zooms closer;
`Grid` changes actual map size. Renderer effect scaling now uses the matching
phone/desktop view height. The minimap panel size is unchanged.

The larger arena increases the amount of grid work and should be checked on
phones. Headless capture, minimap, join, victory and UI checks run with the new
size; this does not establish device frame rates. Death-screen layout tests cover
portrait/landscape bounds, separated actions, touch target size, preserved death
stats, replay/menu routing, black tint and image-icon objects. A Studio visual
playtest against the reference remains necessary.

## V32 reference-inspired effects

The uploaded 144p gameplay video was inspected using sampled frames and closer
sequences around 39–45 seconds and 190–201 seconds. The reference shows short
pale flashes over fresh paint, floating percentage gains and compact multikill
announcements. This update adapts those cues to the existing Roblox presentation:

- Captured territory gets a quicker pale-to-owner sweep and a floating `+x.xx%` reward.
- Trail-cut eliminations burst at the collision contact, rather than the defeated character's distant head.
- Absorbed land visibly transitions from victim color through pale white to winner color, spreading from the contact area. The overlay is now above the land surface; the old overlay was inside the land and could be hidden.
- Kill announcements use `ELIMINATED`, `DOUBLE KILL`, `TRIPLE KILL`, `QUADRA KILL`, `ACE!`, then `UNSTOPPABLE!`. Multikills require kills within a configurable 3-second gap. Lifetime kill streaks, including the five audio tiers, remain separate.
- Capture sparks, impact rings and motion dust now use the real tilted camera's projection, rather than the older flat 2D camera approximation.
- Reduced-motion mode suppresses impact bursts and kill bounce, and uses a simple takeover color fade.

The large expanding circular paint mechanic in the clip has not been added as an
ability. The changes above are presentation only: ownership, kill rules, joining,
revives and defeat flow remain governed by the existing simulation. No sounds or
artwork were extracted from the video; custom sound settings and muted defaults
remain unchanged.

Effects settings are in **PaintlandModules > Config**: `KillComboWindowSeconds`,
`KillPopupDuration`, `CaptureFlashDuration`, `CaptureWorldPopupDuration`,
`TerritoryMergeDuration`, `TerritoryMergeWaveDelay`, and `ReducedMotion`.

In Studio, cut a trail far from the victim's head, check the burst stays at the
cut as the camera moves, inspect a takeover color sweep, then make two quick
kills and two widely spaced kills. Check reward text and effects on a phone.
Automated controller tests cover origin selection, timed combos, projection calls,
overlay height, recycling, object limits and reduced motion. They cannot prove
pixel-level appearance or performance in Roblox. The low-resolution reference
also limits small-detail comparisons; this is an adaptation, not an exact replica.

## V31 trail joins — game loop before abilities

Cutting an exposed bot trail now preserves the hit cell and the trail route before
the victim's trail is cleared. The connection follows your active trail to the
cut, then the defeated trail back to its starting territory. The defeated trail's
loose tail beyond the hit is not painted. Successful joins convert the recorded
route into land, transfer the victim's territory, and clear the consumed trail
collision buckets. Grid counters, minimap chunks and land rendering all receive
the same ownership updates. Small adjacent-cell gaps from collision tolerance are
bridged locally; no arbitrary map-wide shortcut is searched.

As of V36, a recorded route crossing third-party territory claims those crossing
cells so the join remains connected. Captured or previously split islands can
still exist for other reasons. Enclosure kills without a trail-contact point
retain direct inheritance. The human's land remains reserved while their revive
choice is pending, as in earlier versions.

Automated tests exercise real collision-to-elimination flow on a bent trail,
verify 4-connected ownership, exclude the dangling tail, test adjacent-cell
radius hits, exact counters, renderer/minimap invalidation, cleared trail buckets,
and connected third-party crossings. Studio playtesting is still required: cut a
bot midway along an L-shaped path and follow the new colored connection home.
Abilities are intentionally deferred until the core game loop is settled.

## V30 defeat results

When the revive countdown expires, or the player chooses **END RUN**, the match
stops and a **DEFEAT** card shows the territory percentage, tile count and
eliminations recorded at death. The **BACK TO MAIN MENU** action returns to the
color-selection menu. A new match starts only when Play is selected; the old
automatic restart on timeout has been removed.

When revive capability discovery has finished and no revive button is usable,
the game goes directly to defeat on the next UI update. While ad availability is
still being checked, the regular countdown remains. Ending the run is disabled
during ad/purchase/credit verification so those operations are not abandoned.
Late server messages cannot revive a closed prompt. In Studio, the existing test
revive button remains available for testing.

Test a countdown expiry, End Run, a fully unavailable revive, successful revive
followed by another death, and returning to menu then starting a fresh run. Verify
that results keep the death snapshot and no bots move while on defeat/menu.
Actual Roblox ad/purchase integration is still outside this client-only model.

## V29 interface

The start menu and gameplay HUD now use a consistent dark navy, mint and soft
white palette. The menu has a clear primary action, selected-color checkmarks
and brief play instructions. The territory meter separates its caption and value
from the fill; elimination counts, leaderboard rows and the minimap share the
same panel styling. Landscape phones use a smaller minimap and show two ranking
rows to keep controls apart. The existing dedicated revive and victory screens
remain in place.

A **SOUND: OFF / ON** button sits at the bottom right in menus and gameplay.
V29 starts **muted by default** to silence the placeholder pings. Toggling sound
persists across replay/revive in the current session, but not across rejoining.
It is hidden during the revive prompt. `SoundEnabled = false` is a hard disable;
the button cannot override that setting.

### Replace the sounds in Studio

Open **StarterPlayer > StarterPlayerScripts > PaintlandClient > PaintlandModules > Config**.
Edit the sound settings near the bottom:

- `KillSoundIds`: a table of five audio asset IDs (numbers or `rbxassetid://...` strings), in kill order. The fifth repeats for subsequent kills. An empty table uses the placeholder pitched pings.
- `CaptureSoundId`: your territory-capture sound. Leave the tier settings to retain the 5-point pitch changes.
- `SpawnSoundId`, `DeathSoundId`, `VictorySoundId`: replace the other event cues separately. Set a cue to `""` to silence that event.
- `SoundMutedByDefault`: set `false` after replacing the placeholder sounds if you want audio on when joining.
- `SoundMasterVolume`, `KillSoundVolume`, `CaptureSoundVolume`: overall and reward volumes. Set a reward volume to `0` to silence just that category.
- `SoundEnabled = false`: disable every cue immediately.

Use audio you own or that your experience has permission to use. Copy the audio
asset ID, not a model/decal ID. Check Studio Output for permission/loading errors.
Change these settings in the **Config ModuleScript**, not in generated live
Sound instances. If editing repository sources, change `model-source/Config.luau`
and rebuild the `.rbxmx` model.

## Audio cue behavior

Kill cues rise through **five tones** using the existing life kill streak. Kills
six and above repeat the exact fifth cue, with no further pitch increase. Death
resets the streak in the simulation; revive and replay start again at tone one.
Bot kills do not play player reward sounds.

Capture sounds use the **net percentage points gained by one completed capture**,
not your total ownership or a relative percent change. For example, moving from
20% to 27% gains 7 points and uses tier 1; gaining 12 points uses tier 2.
A positive gain below 5 uses tier 0; each extra 5 points raises pitch. Capture
tiers continue above five. A single cue plays per capture, rather than one per
cell. Inheritance during that capture is included in its net gain; separate
trail-kill inheritance uses the kill cue so rewards don't double-play.
Spawn, death and victory have distinct pitches too. Overlapping voices are
bounded to five kill cues, three capture cues and one each for other events.

When unmuted, the fallback is Roblox's bundled `electronicpingshort.wav` at different pitches,
so no uploaded sound ID is needed to try it. This creates an ascending arcade
sequence; it does **not** include Valorant's recordings. To use five separate
custom kill recordings, set `Config.KillSoundIds` to five audio IDs that your
experience has permission to play. Custom recordings play at their original
pitch, and the fifth is reused thereafter. Sound asset availability and actual
loudness must be checked in Studio and on devices.

Audio settings in `model-source/Config.luau`:

| Setting | Default / behavior |
| --- | --- |
| `SoundEnabled` | `true`; set false to disable cues |
| `SoundMutedByDefault` | `true`; placeholder pings start silent |
| `SoundMasterVolume` | `0.65` |
| `KillSoundPitches` | Five ascending default playback speeds |
| `KillSoundIds` | Optional table of five custom asset IDs |
| `CaptureSoundMetric` | `"Percentage"`; change to `"Tiles"` for raw tile gain |
| `CaptureSoundStep` | `5` percentage points, or tiles in Tiles mode |
| `CaptureSoundSemitonesPerStep` | `0.6`; larger values give bigger pitch jumps |
| `CaptureSoundId` | Replace with permitted audio for the capture cue |

The sound toggle calls `AudioController:SetMuted(true/false)`. Sound
instances are reused and stopped on new runs/death; the controller also exposes
`Destroy()` for teardown. No background music is included.

In Studio, listen to kills 1, 2, 3, 4, 5, 6 and confirm 5/6 match; die/revive
and verify the next kill returns to tone one. Compare gains immediately below
and at 5/10/15 points, check a multi-kill capture for volume balance, and inspect
Output for sound loading/permission errors. Listen on a phone as well.

## Changes

- Fully enclosed regions are captured even when larger than the exterior. The last interior pocket can complete the arena. When a loop divides the circular wall, the largest boundary-connected component remains exterior; smaller sides are captured. This explicit rule preserves the beta's wall-capture convention.
- Defeated bots transfer their actual territory; trail kills now join it via the recorded route including crossings through third-party land along the trail. No unrelated connecting strips are drawn across neutral ground; off-route rival land follows normal capture cleanup. Inherited islands may appear as separate colored patches; that reflects ownership.
- Capture checks repeat after inheritance so another head covered by transferred land is eliminated in the same operation.
- Elimination presentation callbacks cannot interrupt simulation completion if an effect throws.
- Minimap rectangles use shared integer pixel edges, eliminating fractional overlaps/gaps. The inaccurate camera rectangle is hidden. A rounded square frame and separate percentage footer improve readability without covering the map.
- Capturer ownership preservation, opponent fragment pruning, bot respawns, and the actual 100% victory requirement remain in place. Eliminating every currently alive bot does not itself win; bots can respawn in safe neutral space until the board is filled.

## Validation

All 49 scripts compiled with the official Luau compiler. Headless tests execute the
actual gameplay modules using small Roblox value/UI doubles, not Roblox's engine.
UI tests run the actual constructors/callbacks with minimal UI doubles, checking
menu/defeat state, death stat snapshots, revive expiry/decline/unavailability,
pending-operation guards, color selection, mute state and non-overlapping HUD panel bounds at
eight viewport sizes. This does not verify actual rendering, text glyphs or device
input. Audio tests cover kills 1–20, custom cue IDs, exact 5-point thresholds, tile mode,
voice limits, mute, reset, death and teardown. Gameplay tests cover five capture/inheritance scenarios, the existing 74%-ownership/victory
regression, minimap pixel coverage at 108/142 pixels, and dirty-queue updates.
The new enclosure test fails against original V26 gameplay code, confirming it
reproduces a repaired defect. Model verification checks all embedded script
sources, preserves the original hierarchy/properties, and confirms twenty-two original scripts changed and ten modules were added.

```sh
python3 tools/build_model.py
python3 tools/verify_model.py
LUAU_BIN=/path/to/luau python3 tools/run_tests.py
/path/to/luau-compile --null model-source/*.luau
```

Use the official `luau-lang/luau` CLI build for those commands. In this workspace,
the binaries are at `/tmp/paintland-luau/luau` and `luau-compile`. The build tool
uses only Python's standard library and can regenerate the model after edits.

## Beta scope

This is a client-side solo game against bots, not a shared multiplayer game.
Each client maintains its own world; live players cannot compete in this model.
A multiplayer release needs a server-authoritative simulation and replication.
The upload contains no server-side revive purchase/ad implementation; monetized
revives require separately verified server handlers and receipt validation.
No purchases or advertisements were tested here.

Roblox Studio rendering, touch input, phone performance, actual Roblox services,
and a complete manual match remain untested in this cloud environment. The
minimap's visual appearance should be checked in Studio; pixel arithmetic tests
cannot establish GPU/UI rendering behavior. This is a tested beta repair, not a
guarantee that every possible issue is eliminated.
