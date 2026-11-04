# Paintland V43 — equipped abilities, charge rings and kill trails

Paintland keeps its territory game loop: leave your land, close a loop to claim
cells, and cut an exposed rival trail. This build moves shared modules into
**ReplicatedStorage**, adds a server-authoritative multiplayer path, and updates
the menu, revive, results, character and capture-audio presentation. V43 keeps Coins and rare Gems and adds a persistent loadout shop, one equipped
ability, charge earned from captures and kills, character-color charge rings and
READY billboards, Spacebar/double-tap controls, and following kill-block effects.

The original supplied V26 model remains unchanged in `models/`. Editable code is
in `model-source/`. Generated builds are:

- `dist/Paintland_v43.rbxlx` — a complete place to open directly in Roblox Studio.
- `dist/Paintland_v43.rbxmx` — a service-organized installation folder for an existing place.
- `dist/Paintland_v43_beta.zip` — both builds, source, tools, tests and this README.

## Install in Roblox Studio

### Open the complete place

Open `Paintland_v43.rbxlx` with **File > Open from File**. The client bootstrap,
server bootstrap and shared modules are already placed in their services. Use
Studio's **Test > Start Server** with at least two players to exercise multiplayer.
An ordinary solo Play session cannot establish two-client synchronization.

### Add to an existing place

1. Save a backup and stop the play session.
2. Remove the previous Paintland client bootstrap/folder from
   **StarterPlayer > StarterPlayerScripts**. Remove an older `PaintlandModules`
   or `PaintlandServer` installation if present. Do not leave duplicate bootstraps.
3. Insert `Paintland_v43.rbxmx` into Workspace using **Insert from File**.
4. Move `PaintlandV43 > ReplicatedStorage > PaintlandModules` into the real
   **ReplicatedStorage** service.
5. Move `PaintlandV43 > StarterPlayerScripts > PaintlandClient` into
   **StarterPlayer > StarterPlayerScripts**. This is a LocalScript.
6. Move `PaintlandV43 > ServerScriptService > PaintlandServer` into the real
   **ServerScriptService**. This is a server Script.
7. Delete the now-empty `PaintlandV43` installation folder. Start a server test
   and inspect **View > Output** on both server and clients.

The outer folders in the import model are installation labels, not Roblox
services. Leaving them in Workspace will not install the game. A client-only
V40 installation is insufficient for V43 multiplayer. The server bootstrap
sets `Players.CharacterAutoLoads=false`, because Paintland renders its own arena
actors rather than using normal Humanoids; account for that if combining it with
another game's avatar system.

The installed structure is:

```text
ReplicatedStorage
  PaintlandModules
    Config
    GameLoader
    MultiplayerServer
    MultiplayerClient
    MultiplayerWorld
    NetworkProtocol
    Matchmaking
    CurrencyService
    WalletHUD
    Splash
    Dash
    AbilityRegistry
    AbilityService
    AbilityHUD
    AbilityInput
    AbilityIndicator
    LoadoutCatalog
    LoadoutMenu
    KillBlockTrail
    ...other shared modules
StarterPlayer
  StarterPlayerScripts
    PaintlandClient (LocalScript)
ServerScriptService
  PaintlandServer (Script)
```

## Multiplayer and matchmaking

The multiplayer server owns movement, collisions, territory, eliminations,
revive grants and completion. Clients send heading/input sequence and lobby
intent; they do not submit trusted positions, ownership or scores. The client
uses local movement prediction and smooth correction, with interpolation for
remote actors. This reduces visible jitter within a match; it cannot eliminate
network delay or promise identical behavior under every connection condition.

**Quick Play** joins an available public match. **Create Room** makes a private
room with a shareable code; friends use **Join Room** and the host starts the
match. The server maintains room membership, capacity and host ownership.
Private rooms and public matchmaking use MemoryStore directory entries in
published experiences. Joining a room hosted on another Roblox server uses
TeleportService and therefore includes Roblox's normal server-loading transition.
That transition is separate from continuous arena movement.

Studio room tests remain local to the Studio server. Cross-server discovery,
MemoryStore permissions/quotas, TeleportService behavior and reconnect/error
flows must be tested after publishing to an experience. These Roblox services
are not emulated by the headless tests. Server-side validation also remains
necessary even though module source is replicated for organization and reuse.

Multiplayer revive options are server granted. The existing client-side
advertisement/product prompts are not a replacement for developer-product
receipt validation. Any monetized revive flow needs verified server receipt
handlers before it is enabled in a live experience.

## Coins and Gems

The server awards Coins for positive captures and valid eliminations. The wallet
is visible in the menu and during play, with gold Coins, purple Gems and brief
reward captions. It rearranges on narrow screens to avoid the minimap and ability
buttons. Loading shows an ellipsis; failed saves display `SAVE PENDING`.

| Event | Coins | Chance of one Gem |
| --- | --- | --- |
| Positive capture | `5 + floor(percentage points gained * 10)` | 1% when the gain is at least 0.5 points |
| Valid kill | 25 | 5% |

For example, gaining 0.5 percentage points awards 10 Coins; gaining 1.5 awards
20 Coins. Splash gains use the same capture reward. Zero-gain captures, self
eliminations and duplicate death callbacks give no reward. Land inherited after
a kill does not produce a second capture reward. Gem drops share a 60-second
cooldown across captures and kills; the last drop time is saved with the wallet.
The client cannot supply reward amounts, percentages, balances or Gem rolls.

Balances use Roblox DataStore `PaintlandWalletV1`, keyed by user ID. The server
loads on join, saves every 60 seconds, saves before cross-server joins, retries on
departure, and flushes on shutdown. UpdateAsync applies cumulative receipts per
player join, preserving additive rewards across overlapping sessions and retries
after an uncertain write. Failed loads keep rewards pending instead of overwriting
saved balances with zero. Saving still depends on Roblox service availability;
an abrupt server loss can lose rewards earned since the last successful save.

Studio uses **temporary test wallets by default**, marked `TEST`. To test saving,
use a separate published test experience with Studio API access enabled, set
`CurrencyPersistInStudio=true`, and use a separate test DataStore name. Live saving
is enabled by default. Local practice mode (`MultiplayerEnabled=false`) uses a temporary wallet and
loadout for that client session. The shop spends earned Coins or Gems, not Robux.

All economy settings are in `ReplicatedStorage > PaintlandModules > Config`:

```lua
Config.CurrencyPersistenceEnabled = true
Config.CurrencyPersistInStudio = false
Config.CurrencyDataStoreName = "PaintlandWalletV1"
Config.CurrencyAutosaveSeconds = 60
Config.CurrencyCaptureBaseCoins = 5
Config.CurrencyCoinsPerPercent = 10
Config.CurrencyKillCoins = 25
Config.CurrencyGemMinCapturePercent = 0.5
Config.CurrencyCaptureGemChance = 0.01
Config.CurrencyKillGemChance = 0.05
Config.CurrencyGemCooldownSeconds = 60
```

## One equipped ability and the loadout shop

Open **LOADOUT** on the main menu. Players have exactly one ability slot. Abilities
must be purchased separately or included with the currently equipped, owned
character. The classic Slime is free and starts without an ability. Colors remain
independent of character/ability ownership.

| Item | Default price | Entitlement |
| --- | --- | --- |
| Dash ability | 250 Coins | Equip Dash with any character |
| Splash ability | 400 Coins | Equip Splash with any character |
| Runner character | 500 Coins | Cap cosmetic and Dash while Runner is equipped |
| Splashling character | 8 Gems | Crown cosmetic and Splash while Splashling is equipped |

Buying also equips the selected item. Selecting another ability replaces the
slot; the two abilities cannot be activated together. Switching away from a
character removes access to its included ability unless that ability was also
purchased separately. The equipped slot stays fixed during a running round.
**Unequip Ability** clears the slot. Character ownership, purchased abilities,
selected character and selected ability persist with the wallet.

The server checks catalog prices and ownership, then deducts currency and grants
ownership in a single DataStore UpdateAsync. Ownership acts as the purchase
receipt, so a retried buy after an ambiguous response does not charge twice.
Autosaves preserve concurrent purchases and never restore spent currency from a
stale client/session balance. Failed purchases stay unconfirmed until the server
can read a successful result. Existing V42 balances migrate without resetting
Coins or Gems; V42 had no purchased ability inventory to migrate.

## Charge, ring and controls

Abilities have **no passive cooldown recharge**. A new life starts at 0 / 100
charge. Gain **20 charge per percentage point captured** and **35 per valid
kill**, up to 100. For example, a 0.5-point capture adds 10 charge; a kill adds
35. Captures with zero gain, duplicate kills and delayed land inheritance do not
add charge. Using an ability consumes the full charge. A rejected/no-op Splash
retains charge. Claims and kills caused during Splash activation award normal
currency but do not refill the ability that caused them. Death clears charge.

A thin ring follows the character on the arena floor. Its fill tweens between
server-confirmed charge values over 0.28 seconds. The overhead billboard shows,
for example, **DASH · 65 TO GO**, then **READY · DASH** when full. Both use that
character's actual paint color. READY has a restrained pulse; ReducedMotion
shows the correct final fill without tweening or pulsing. Unequipped characters
have no charge indicator. All clients receive other players' equipped ability
and charge, so their indicators also follow the correct state.

- **Keyboard:** Spacebar activates the one equipped, fully charged ability.
- **Phone/tablet:** two short taps in the play area activate it. Steering drags,
  UI touches, slow taps, multitouch gestures and focused text entry are ignored.
- **Gamepad:** right trigger activates the same equipped slot.

The two old ability buttons and Q/E bindings have been removed. A small gameplay
hint explains activation or charge earning; the ring remains attached to the
character. Splash claims a circle within 6 cells when standing on owned land
without an exposed trail. Dash gives 2.25x movement speed for 0.65 seconds while
retaining swept trail collisions and the arena boundary.

```lua
Config.AbilityPrices = {Dash={Coins=250}, Splash={Coins=400}}
Config.CharacterPrices = {Runner={Coins=500}, Splashling={Gems=8}}
Config.AbilityChargeRequired = 100
Config.AbilityChargePerPercent = 20
Config.AbilityChargePerKill = 35
Config.AbilityRingTweenSeconds = 0.28
Config.AbilityDoubleTapSeconds = 0.3
Config.AbilityTapMaxMovement = 18
Config.SplashRadiusCells = 6
Config.DashDurationSeconds = 0.65
Config.DashSpeedMultiplier = 2.25
```

## Kill block trails and module extension

On a valid kill, seven small blocks start at the victim, catch up to the killer,
follow their recent movement as a short chain, and absorb into them. They begin
in the defeated player's color and blend toward the killer's paint. These are
cosmetic anchored parts: they never move players, award extra currency/charge,
or change collision/territory. A reusable pool is capped at 48 parts per client.
The effect clears when the killer dies, respawns, changes identity/slot, or a new
world starts. ReducedMotion suppresses it.

```lua
Config.KillBlockTrailEnabled = true
Config.KillBlockTrailMaxParts = 48
Config.KillBlockTrailDuration = 2.4
```

`Splash` and `Dash` remain separate ModuleScripts in
`ReplicatedStorage > PaintlandModules`. To add an ability, create a module with
`Id`, `Name`, `Color` and `Activate(world, actor, config)`; register it in
`AbilityRegistry.List` and add its price to `Config.AbilityPrices`, or associate
it with an owned character in `LoadoutCatalog`. Activation returns `true,
effectData` or `false, reason`. `AbilityService` owns the single slot and charge;
`AbilityInput` owns gestures; `AbilityIndicator` owns the ring/billboard;
`LoadoutMenu` owns shop presentation; `KillBlockTrail` owns following blocks.
The server remains authoritative even though these modules are replicated.

## Visual direction and references

The requested visual language comes from the uploaded gameplay recording:
cream panels, bold outlines, readable Montserrat typography, bright territory
colors, round characters and elastic movement. The earlier screenshots guide
the blue/cyan revive and results screens: a fixed heart with draining red fill,
outline pulses, and an animated map showing the player's captured area. These
references guide presentation while the existing territory-capture loop remains.
This is an adaptation; exact visual equivalence and device feel require Studio
rendering and playtests.

The character reference is the supplied `Slime-Character-Playground-Demo.rbxl`
and [the linked slime demonstration](https://www.youtube.com/watch?v=JLJtyt1QLk8).
The place was inspected as data without executing its scripts. It uses
SmartBone 0.1.2 and a skinned slime setup. Paintland adapts its elastic movement
using bounded procedural visual deformation: velocity/turn springs, squash and
spread, and independently trailing ground lobes. Faces and accessories follow
that deformation. The simulation collider remains the territory game's collider;
this is cosmetic softbody-style motion, not physical softbody collision or a copy
of the demo's complete skinned rig. Large corrections and long frames reset the
visual springs safely. `SlimeVisualsEnabled=false` disables that deformation.

The earlier `UIEffects.rbxmx` and full `Kaboom Kablow.rbxl` were also inspected as
reference source. Play buttons adapt their diagonal shine and five pulsing
sparkles, using the supplied sparkle image `rbxassetid://96254055681570`.
Reference bootstrap scripts and their tag observers are not installed wholesale.
Check the sparkle image's availability in the target experience. Button
interaction animates the actual Size around fixed `(0.5, 0.5)` anchors, including
scale and offset components, so growth is symmetric around the center.

## Revive heart and final results

The revive countdown starts at **4 seconds**. The main heart silhouette stays
fixed while its red fill drains smoothly; a separate contour expands and fades
for the pulse. A single reused Sound produces the countdown beeps. Pending
server/receipt operations pause the local choice UI rather than granting a
client-side revive. Ending or exhausting the revive opportunity leads to the
results screen instead of silently starting a new match.

The results screen uses a frozen snapshot of the player's captured cells and
stats. A neutral arena map reveals the captured color as the displayed
percentage counts up automatically over `ResultsRevealSeconds`. The result is
retained until the player chooses Play Again or Main Menu. Reduced-motion mode
shows the final result immediately. The map represents the actual arena mask and
owned territory, rather than a decorative percentage unrelated to the grid.

Settings in `ReplicatedStorage > PaintlandModules > Config`:

```lua
Config.ReviveWindowSeconds = 4
Config.ReviveCountdownSoundId = "rbxasset://sounds/electronicpingshort.wav"
-- Replace with your permitted audio, for example "rbxassetid://123456789".
Config.ReviveCountdownVolume = 0.35
Config.ResultsRevealSeconds = 2.0
Config.ReducedMotion = false
```

## Capture sound: five to twenty pitched notes

`CaptureSoundId` uses the requested `rbxassetid://106879573498735`. The repeat
count depends on the **percentage points gained by one capture**, not total
ownership. A positive gain of 0.5 points or less plays five notes; 1.5 points or
more plays twenty. Values between those limits use a linearly interpolated,
rounded count, so a 1.0-point gain plays thirteen notes. Zero gain is silent.

```lua
Config.CaptureSoundId = "rbxassetid://106879573498735"
Config.CaptureRepeatInterval = 0.045
Config.CaptureSequenceStartPitch = 1
Config.CaptureSequenceEndPitch = 1.6
```

Pitch rises through each sequence. Playback uses the existing bounded voice
pool. A new capture replaces the unfinished sequence; mute, death, reset and
teardown cancel it. Sound availability and volume must be checked in Studio
and in the published experience. Roblox audio permission may depend on the
experience owner; use an asset the experience is allowed to play.

The Sound button controls session mute. `SoundEnabled=false` disables effects.
`SoundMutedByDefault` controls the initial state. Beep and capture audio honor the
same mute choice. Button sparkles and slashes can be disabled independently with
`ButtonParticlesEnabled` and `ButtonSlashEnabled`; `ReducedMotion` suppresses
motion effects while retaining essential countdown/result information.

## Build and verification

The build tools use Python's standard library. The original uploaded game and
reference places are not copied into the generated place. All modules under
`model-source/` except the client bootstrap become ModuleScripts inside
ReplicatedStorage. The server bootstrap is generated by the build tool.

```sh
python3 tools/build_model.py
python3 tools/verify_model.py
LUAU_BIN=/path/to/luau python3 tools/run_tests.py
/path/to/luau-compile --null model-source/*.luau
python3 tools/package_beta.py
```

The current workspace's official Luau tools are under `/workspace/work/luau/`.
`verify_model.py` compares every embedded script against current source,
checks service placement and bootstrap type, and checks direct shared-module
requirements. Headless tests execute actual Luau modules with small Roblox
value/UI doubles. They establish logic and layout arithmetic; they do not
emulate Roblox rendering, audio, networking or marketplace services.

Before release, test a normal capture, a large enclosure, wall capture, trail
cut, two simultaneous players, death/revive/results/replay, disconnect/rejoin,
private-room host departure, private-code join on another published server,
and full-arena completion. Check packet delay/loss under Studio network
simulation, touch steering and portrait/landscape layouts on a phone. Inspect
both clients and the server for warnings. Tests that deliberately throw an
`intentional VFX failure` verify effect isolation; those warnings are expected
only during that regression scenario.

V43 passed the official Luau compile, embedded-source checks, and headless
regressions for the existing game plus atomic purchases, purchase retries,
concurrent sessions, character entitlements, one equipped slot, capture/kill
charge, no passive/self recharge, Spacebar and double-tap gesture rejection,
ring tween targets/cleanup, and bounded kill-block following/cleanup. UI layout
arithmetic is checked on desktop, portrait and landscape viewports. These tests
do not emulate Roblox rendering, live DataStore, MemoryStore or TeleportService.

Before release, verify shop purchases/rejoin in a published test experience,
actual touchscreen double taps while steering, character-color ring visibility,
READY billboard readability, block trails, and two-client charge synchronization.
A successful compile or headless run does not establish a lag-free live release.
