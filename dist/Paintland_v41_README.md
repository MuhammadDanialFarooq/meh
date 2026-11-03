# Paintland V41 — shared multiplayer arena and animated results

Paintland keeps its territory game loop: leave your land, close a loop to claim
cells, and cut an exposed rival trail. This build moves shared modules into
**ReplicatedStorage**, adds a server-authoritative multiplayer path, and updates
the menu, revive, results, character and capture-audio presentation.

The original supplied V26 model remains unchanged in `models/`. Editable code is
in `model-source/`. Generated builds are:

- `dist/Paintland_v41.rbxlx` — a complete place to open directly in Roblox Studio.
- `dist/Paintland_v41.rbxmx` — a service-organized installation folder for an existing place.
- `dist/Paintland_v41_beta.zip` — both builds, source, tools, tests and this README.

## Install in Roblox Studio

### Open the complete place

Open `Paintland_v41.rbxlx` with **File > Open from File**. The client bootstrap,
server bootstrap and shared modules are already placed in their services. Use
Studio's **Test > Start Server** with at least two players to exercise multiplayer.
An ordinary solo Play session cannot establish two-client synchronization.

### Add to an existing place

1. Save a backup and stop the play session.
2. Remove the previous Paintland client bootstrap/folder from
   **StarterPlayer > StarterPlayerScripts**. Remove an older `PaintlandModules`
   or `PaintlandServer` installation if present. Do not leave duplicate bootstraps.
3. Insert `Paintland_v41.rbxmx` into Workspace using **Insert from File**.
4. Move `PaintlandV41 > ReplicatedStorage > PaintlandModules` into the real
   **ReplicatedStorage** service.
5. Move `PaintlandV41 > StarterPlayerScripts > PaintlandClient` into
   **StarterPlayer > StarterPlayerScripts**. This is a LocalScript.
6. Move `PaintlandV41 > ServerScriptService > PaintlandServer` into the real
   **ServerScriptService**. This is a server Script.
7. Delete the now-empty `PaintlandV41` installation folder. Start a server test
   and inspect **View > Output** on both server and clients.

The outer folders in the import model are installation labels, not Roblox
services. Leaving them in Workspace will not install the game. A client-only
V40 installation is insufficient for V41 multiplayer. The server bootstrap
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

V41 is a multiplayer integration build requiring those Studio/published tests.
A successful compile or headless run does not establish a lag-free live release.
