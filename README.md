# Paintland V27 beta

A targeted repair of the supplied PaintlandClient V26 Roblox model. The original
upload is retained unchanged in `models/`; editable Luau sources are in
`model-source/`. The importable result is `dist/PaintlandClient_v27.rbxmx`.

## Install in Roblox Studio

1. Save a backup of your place. Stop the play session.
2. Remove the previous **PaintlandClient** folder from **StarterPlayer > StarterPlayerScripts** to prevent duplicate bootstraps.
3. Insert `dist/PaintlandClient_v27.rbxmx` there using Explorer's **Insert from File**. Keep its `Paintland` LocalScript and `PaintlandModules` folder together under `PaintlandClient`.
4. Press Play and check **View > Output**. Studio regression tests are enabled by `Config.RunVictoryRegressionTests`. They run isolated test worlds before the game starts. Two warnings containing `intentional VFX failure` are expected from the error-isolation test; other failures need investigation.
5. Check a normal loop, a large enclosure, a loop along the wall, simultaneous bot captures, a self-trail death, revive/replay, and reaching 100%. Use Device Emulator to check portrait/landscape layouts and touch steering. Check the minimap during captures and after resizing.

## Changes

- Fully enclosed regions are captured even when larger than the exterior. The last interior pocket can complete the arena. When a loop divides the circular wall, the largest boundary-connected component remains exterior; smaller sides are captured. This explicit rule preserves the beta's wall-capture convention.
- Defeated bots transfer their actual territory directly, including islands separated by other players. No artificial connecting strips are drawn across neutral ground, and third-party land is preserved. Inherited islands may appear as separate colored patches; that reflects ownership.
- Capture checks repeat after inheritance so another head covered by transferred land is eliminated in the same operation.
- Elimination presentation callbacks cannot interrupt simulation completion if an effect throws.
- Minimap rectangles use shared integer pixel edges, eliminating fractional overlaps/gaps. The inaccurate camera rectangle is hidden. A rounded square frame and separate percentage footer improve readability without covering the map.
- Capturer ownership preservation, opponent fragment pruning, bot respawns, and the actual 100% victory requirement remain in place. Eliminating every currently alive bot does not itself win; bots can respawn in safe neutral space until the board is filled.

## Validation

All 39 scripts compiled with the official Luau compiler. Headless tests execute the
actual gameplay modules using small Roblox value/UI doubles, not Roblox's engine.
They cover five capture/inheritance scenarios, the existing 74%-ownership/victory
regression, minimap pixel coverage at 108/142 pixels, and dirty-queue updates.
The new enclosure test fails against original V26 gameplay code, confirming it
reproduces a repaired defect. Model verification checks all embedded script
sources, preserves the original hierarchy/properties, and confirms only six
scripts changed.

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
