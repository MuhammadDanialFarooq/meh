# Kaboom Kablow reference inspection

The uploaded place was inspected as data; none of its scripts were run. Modern
binary chunk compression was decoded, then readable properties and source text
were inspected. Some newer metadata properties were unsupported by the decoder;
the work uses ordinary readable lighting values and the relevant UI source.
The reference place and its full scripts are not bundled in Paintland.

Observed reference properties:

- Lighting brightness 1.5, afternoon time 14:06, ambient 197/197/197, outdoor ambient 190/190/190, diffuse 0.75, specular 0.1, purple bottom/pink top color shifts.
- Enabled color correction: brightness -0.075, contrast 0.4, saturation 0.6. Bloom saved disabled; blur objects saved at zero and driven by UI scripts.
- Most readable reference text uses Gotham bold/heavy faces, consistent with Paintland's existing typography.
- `ReplicatedStorage/Module/Ui/SpringUI`: spring-driven position/size/scale transitions.
- `ReplicatedStorage/Cooked/UIEffects/SpringButton`: hover enlargement, press compression, release spring and connection cleanup.
- `ReplicatedStorage/Module/Ui/BlurController` and `FrameHandler`: animated menu blur (one request uses size 18).
- `PickupEffect`: curved reward movement, back/quad/cubic easing and bounded particle emission.

Adaptation:

Paintland uses independently written damped-spring interactions, panel entrances,
subtle menu/wardrobe blur and capture/kill character bounce. Its existing capture,
trail-join and kill bursts are retained. Particle scaling now preserves each
particle's initial size while easing out instead of snapping to a fixed size.
Lighting copies the readable base afternoon settings but uses gentler color
correction (contrast 0.3, saturation 0.35, brightness -0.04) and lower menu blur
(4; wardrobe 8) to retain territory/trail readability and the live menu backdrop.
No skybox images, scripts, purchase systems or external plugin code were copied.

This is a source-guided adaptation. No in-engine run, screenshot comparison or
mobile GPU/frame-rate validation was possible here; check those in Roblox Studio.
