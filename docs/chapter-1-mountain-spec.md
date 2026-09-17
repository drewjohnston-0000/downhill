# Chapter 1 — The Mountain (spec v1)

**Beautiful. Forgiving. Always joyful.** That triad outranks every reference image.

Prove the third prototype pillar from `concept.md`: **seeing the world far below makes
the player want to go there.** Pillars one and two (carving, speed) are playtest-proven
and frozen. This chapter evolves the *world*, not the feel.

The reel is a reference for **composition, light, place and the rider's ease**. It is
not a reference for gameplay: it coasts, it never brakes, nothing is at stake. The game
iterates past it. Joy comes from the descent having rhythm (tuck the straights, brake
into the switchbacks, skate to recover), from speed reading as delight rather than
threat (hair and hem streaming harder, never a shake or a crash), and from the rule that
nothing the world does can end a run. Forgiving is a constraint on every slice: soft
shoulders, no cliff death, no hard stops.

**Tempo: the soundtrack is 108 bpm, not 128.** Mid-tempo, head-nod, not a drop. Use it
as the pacing rule for everything, not just audio: the course changes character every
few bars rather than every beat; corners arrive with time to read them; the camera
settles rather than snaps; speed builds and breathes rather than spikes; secondary
motion sways rather than thrashes. If a slice makes the run feel like 128, it is off
brief even if it is exciting.

North star for this chapter: **`docs/concept-board-files/girl-montpelier.mp4`**, judged
against the frames in `docs/moodboard/img/frame-girl-montpelier-{1,3,5}.jpg`. What those
frames have that we do not: the horizon sits in the top quarter, the camera pitches
down, the hillside falls away steeply, a town and a bay are visible *below* the rider,
the sky is big with white cumulus, the near ground is grass with flowers, and the rider
is large and expressive in frame. Environment vocabulary is Montpelier's: a narrow pale
path on a grass hillside, no kerbs, no rock cutting. The splash's sealed road and
golden-hour palette are chapter 2 material.

## What the clip actually shows (frame study, 2026-09-17)

Read from ffmpeg frame sheets, saved (gitignored) as `docs/reference/montpelier-*.jpg`.
The file is a portrait phone screen-recording of an Instagram reel with UI chrome, so
crop it before judging. It is four cut shots, not one take (cuts at 1.2 s, 6.2 s,
11.3 s): a wide establishing shot with the rider small; a close shot on a cracked
concrete-slab path bending left; a dirt path across the hillside with flowers on the
drop side and a rock cutting on the rise side; a ridge path with fence posts. One frame
shows a lower tier of the path at a switchback.

- **Camera.** Behind and above, pitched down roughly 30 to 40 degrees. The horizon sits
  at 20 to 25 percent of frame height. The rider's head is near frame centre and the
  rider spans about half the frame height. The path fills about a third of the frame
  width where the rider stands. Portrait, like our 720x1280 base.
- **Rider pose is static.** Both feet planted, knees soft, arms out at shoulder height
  as if balancing. No pushing. No lean into the bend: the body stays upright and the
  world turns underneath, which is exactly our aim-along-velocity camera decision.
  All of the life is **secondary motion**: hair whipping back, skirt hem billowing,
  bag swinging, hands drifting. Plus one big saturated navy cast shadow on the path
  ahead and to the right.
- **Scale.** The path is three to four board lengths wide. Ours is about six and a
  half (300 units against a 46-unit box). Fix this by making the rider read larger,
  not by narrowing the sim road.
- **Light.** High midday sun, saturated. Shadows are deep blue, not grey. Grass is
  yellow-green in sun. Sea is cobalt with white surf. Town is pale. Our current
  golden-hour palette is the opposite of this.
- **It is coasting, not speed.** The clip's subject is the place and the rider's
  ease, not velocity. Speed cues can stay subtle.

Superseded: `docs/lateral-terrain-spec.md`. Its cross-section idea survives inside the
height field below; its "sim never sees the slope" guardrail does not (see Decisions).

## Decisions (confirmed 2026-09-17)

- **The gravity model may change.** The concern was never "sim is sacred", it was
  "one variable at a time". So the sim change is done as a *faithful transform* with an
  equivalence proof before the course evolves (Slice 1), and the current course stays
  buildable as the telemetry baseline throughout.
- **Feel stays locked.** No value in `RiderConfig` changes in this chapter. Handling
  and corner traction remain deferred. Camber becomes *available* to the course
  designer; it is not used to tune feel.
- **Montpelier wins.** Composition, camera, palette, near-field dressing and world
  vocabulary come from the clip. The splash is not the target this chapter.

## Why the world model must change (the supporting reasons)

1. **The fall line is a fixed world direction.** `RiderConfig.fall_line_dir` is
   always -Y and `RoadPath.build_course` slopes cap around 40 degrees off it. The road
   cannot turn past 90 degrees: no hairpins, no switchbacks, no "next tier of road
   visible below you". Montpelier's descent and the splash's switchback are unbuildable.
2. **Elevation is one-dimensional.** `ElevationProfile.height(y)` means there is no
   terrain, only a profile. A vista can only be a painted ring because there is no
   ground for it to be made of.
3. **Corner camber today is an accident.** On a bend the old model's gravity pulls
   *across* the road (the road runs across a tilted plane). That is what makes corners
   cost speed, but nobody chose it. Making camber a per-segment number turns an
   accident into a design knob, and the deferred "camber affects handling" feature
   stops being a rebuild.

## The model

### Road (`sim/road_path.gd`, extended)

- Stays a 2-D polyline in the sim plane, with `half_width`. Gains:
  - per-point **height** along the path (monotone non-increasing: the road only
    descends; a test guards this);
  - per-point **camber** (height change per unit of lateral offset; 0 = a level shelf);
  - `project(pos) -> {s, n, height, camber, tangent}`: arc length `s` and signed lateral
    offset `n` of the nearest point. `distance_to_center` / `off_road_amount` become
    thin wrappers over this.
- Course builder emits arbitrary turns (`heading` per segment, not `slope` per
  segment), so switchbacks are legal. The existing `COURSE` in `main/main.gd` is kept
  buildable through the new builder with identical geometry (the baseline).

### Height field (`sim/height_field.gd`, new, pure)

`height(pos)` and `gradient(pos)`, built from the road:

```
(s, n) = road.project(pos)
if |n| <= half_width:            h = road.height(s) + road.camber(s) * n        # the shelf
else:                            h = shelf edge + cross(side, |n| - half_width, s)  # hillside
far from the road:               blend into a background mountain function
```

- `cross()` is Opus's cross-section: rise side climbs, drop side falls. Fixed per
  course first, per-segment later. It is *inside the sim* now, because the sim reads
  the gradient, but on the shelf it contributes nothing, so on-road feel is untouched.
- `gradient()` by central differences (step ~1 world unit). Deterministic, trivially
  testable, no analytic derivative to keep in sync.
- Replaces `ElevationProfile` as the single source of truth. `Terrain3D.elevation()`
  reads the same object the sim reads, as today.

### Gravity (`sim/rider_simulation.gd`, one line changes)

Today: `velocity += fall_line_dir * gravity * pull_factor(y) * dt`.
New:   `velocity += -gradient(pos) / reference_grade * gravity * dt`.

Direction is downhill, strength is local grade over a reference grade. On the old
course, with camber set to the tilted-plane value `grade * normal_y`, this is exactly
the old model (the old height was a function of y only). That equality is the
equivalence test in Slice 1. `fall_line_dir` is deleted once the test passes.

### Presentation

- **Near strip**: road + shoulders built in `(s, n)` coordinates from the height
  field, replacing the world-X grass band. Exact on curves, cheap.
- **Far grid**: a coarse height-field grid for the hillside down to the water, built
  from the background mountain function only (no road search per vertex).
- **Sea**: one flat quad at water level. **Vista ring** stays for distant headlands.
- **Camera**: gaze target is a smoothed road point ahead along `s`, with a pitch bias
  so the horizon rises toward the top quarter of the frame when the ground falls away.
  Keep the anti-bob smoothing; it was hard-won.

## Guardrails (every slice)

- **Feel frozen.** `RiderConfig` values unchanged. Any slice that needs to touch them
  stops and re-specs.
- **Baseline preserved.** The current course remains buildable; a scripted-input
  telemetry run on it must match `logs/` baselines within tolerance after Slice 1.
- **Readability is sacred.** The path must read against grass and the next corner
  must be readable before the tarmac is. Posts stay until something else does that job
  (Slice 4 may retire them if flowers and edge contrast prove sufficient).
- **Capture-driven, stop-conditioned.** Every visual slice: at most three
  tune-and-capture iterations against the Montpelier frame, then it is clearly better
  or it reverts. Every sim slice: tests green before capture.
- **Whitelist**: built-in materials, `MultiMesh`, `SurfaceTool`, `WorldEnvironment`,
  the existing 2-D cloud layer, and alpha-coverage textured *cards* for grass/flowers
  (the reason we are on 4.8). Still no custom 3-D, sky or post shaders.

## Slices (in order; shippable after any one)

### Slice 0 — Ugly spike: does "the world below me" land? (S, one session)

No sim change. A hand-placed 3-D path with two switchbacks down a procedural grass
hillside to a flat sea plane. Rider moves *on rails* at constant speed. Camera pitched
down, horizon in the top quarter, rider larger in frame. Grey geometry, current
palette. One capture at the first switchback, A/B against
`frame-girl-montpelier-1.jpg`.

Acceptance: (1) the horizon is in the top third; (2) a lower tier of the path is
visible below the rider; (3) the sea reads as far below; (4) a naive viewer says "I
want to go down there". If three iterations fail this, stop and rethink before Slice 1.

**Slice 0 landed 2026-09-17** as `main/spike.tscn` (`spike.gd`), three iterations, kept
until Slice 2 replaces it. Captures: `logs/spike_summit.png` (whole descent, town and
sea below), `logs/spike_switchback.png` (reel composition past the first hairpin).
Criteria 1 to 3 met on capture; criterion 4 is the user's call on playing it. Findings
that feed Slices 1 to 3:
- The road-first shelf (flatten the mountain onto the path within ~45 units, ease
  back over ~260) is what makes the path sit in the slope. Do it in the height field.
- A coarse far grid cannot resolve the shelf between vertices. The exact near strip
  in `(s, n)` with the grid pushed down beneath it works; keep that split.
- At a hairpin the two tiers are within the blend distance and the nearest-point
  rule picks one tier, terracing the other. The height field must blend against
  *all* nearby path segments (take the lowest shelf, or blend by inverse distance).
- The camera needs a ground floor (never below terrain plus clearance) at the summit.
- A steep upper mountain (about 34 degrees at the top, easing to the coast) is what
  makes the world fall away. Gentle slopes read as a lawn.
- With the camera 105 back and 80 up looking 21 degrees down, the horizon lands at 20
  to 30 percent and the rider at about a third of frame height. Slice 3 goes closer.

### Slice 1 — Height field gravity + equivalence proof (M, no visible change)

`HeightField`, `RoadPath.project`, per-point height/camber, gradient-driven gravity.
Old course rebuilt through the new builder with tilted-plane camber.

Tests: gradient of a plane is exact; shelf gradient equals road grade; scripted 60 s
run on the old course reproduces the old trajectory within epsilon; road height
monotone; `project` round-trips known `(s, n)` points. Telemetry baseline run matches.
Then delete `ElevationProfile`, `fall_line_dir`, `pull_factor`.

### Slice 2 — The chapter 1 descent (L)

A designed path: ridge start, long open traverse with the bay in view, two switchbacks,
a fast straight, a final sweep toward the town. Level shelf (camber 0) everywhere first;
cross-section drops to the sea on one side and rises on the other. Near strip, far
grid, sea quad. Old course kept as a second scene for telemetry comparison.

Acceptance: full run finishes; all four verbs have a home (tuck on straights, brake
into the switchbacks, skate to recover); no off-road wipeouts; the speed trace
"breathes" at least as much as the baseline course.

### Slice 3 — Composition (S)

Match the clip's numbers, not a vibe: horizon at 20 to 25 percent of frame height,
camera pitched down 30 to 40 degrees, rider spanning about half the frame height with
the head near centre, path about a third of frame width at the rider. Achieve rider
size by moving the camera closer and scaling the rider *visual* up (about 1.6x), never
by narrowing the sim road. Sun high, shadows deep blue: adjust sun angle, shadow and
ambient colour. Palette re-anchored from golden hour to midday: cobalt sea, saturated
yellow-green grass, white cumulus, clear blue sky. `WorldEnvironment`, camera exports
and colour constants only.

### Slice 4 — Near-field dressing (M)

Grass tufts and flower cards (alpha-coverage mipmaps) scattered by a deterministic
seed along both shoulders, denser near the path. Pale path colour and a soft edge
band. Wind is out. Retire the posts only if the readability guard still holds.

### Slice 5 — Rider card: static pose, secondary motion (M, optional)

**5a landed 2026-09-17 (uncommitted):** `presentation/rider_card_3d.gd` stacks six SVG
layers from `assets/rider/` (legs, torso, skirt, head, hair, bag; shared 64x128 canvas,
imported at 512x1024 with alpha-coverage mipmaps) on Sprite3Ds that face the camera
around Y; `RiderBody3D` now carries a deck with wheels that yaws with heading, the box
kept behind `card_rider = false`. Captures: `logs/rider_card_straight.png`,
`logs/rider_card_carve.png`. Found: the 2-D cloud layer draws over the rider's head
when she stands against the sky. **Fixed:** `CloudCards3D` replaces the canvas layer
with depth-tested cards beyond the vista ring. 5b (springs) still open.

Promoted from chapter 2 because the clip shows it is cheaper than "character
animation". The rider is a back-view **layered card stack** (deck, legs, torso with
arms out, bag, hair), each a flat painted card facing the camera. No rig, no clips.
Three elements are driven by simple springs: hair and skirt hem stream back with
speed, bag and hair swing with lateral acceleration, the whole stack tilts a few
degrees with lean. Cast shadow from the existing sun. This is the "2-D skin over 3-D
space" thesis applied to the character. Acceptance: at speed on a straight the rider
reads alive with zero body animation; in a carve the world turns under an upright
body.

### Slice 6 — Optional life in the valley (M, cut first if over budget)

Blocky town on the shore, a few sail cards on the bay, fence posts on ridge sections.

## Explicitly out (chapter 2 candidates)

- **Surfaces and materials**, both meanings: painted road/grass textures, and grip by
  surface (`surface-dependent-grip`). Hook left for later: the height field can
  return a surface id per `(s, n)`. Do not build the hook yet.
- Camber used for handling. It exists as a knob; leave it at 0 on the shelf.
- Corner traction limit, slide, obstacles, splash-style kerb blocks and rock cutting.
- Rigged rider animation (the card stack in Slice 5 is the chapter 1 answer). Foliage
  *system*, wind, water shading, town detail.

## Risks

- **Height-field build cost.** Nearest-point search per vertex in GDScript. Mitigated
  by building the near strip in `(s, n)` (no search) and the far grid from the
  background function only. If a blend seam shows, widen the strip before optimising.
- **Camera pitch vs nausea.** Pitching down over rolling ground reintroduces the bob
  we removed. Smooth along `s`, never sample raw height under the camera.
- **Equivalence is not identical.** Central differences and a polyline projection will
  differ from the analytic profile at the 1e-3 level. Set the tolerance from a first
  run, then freeze it; do not chase zero.
- **Verb balance moves with the course.** Expected and wanted. Judge Slice 2 by
  "every verb has a home", not by matching the baseline numbers.

## Definition of done

One capture at the first switchback that a viewer places next to the Montpelier frame
without embarrassment, a full playtested run where the player reports wanting to reach
the town, tests green, telemetry showing all four verbs in use, and the old course
still runnable as a baseline.
