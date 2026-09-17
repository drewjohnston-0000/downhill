> **SUPERSEDED 2026-09-17** by `docs/chapter-1-mountain-spec.md`. The cross-section idea
> lives on inside its height field; the "sim never sees the slope" guardrail was dropped.

# Lateral Terrain — Scope (v1)

Turn the flat plane into a **mountainside**: the road cut into a slope, land rising
close on one side and falling away to the vista on the other. The splash composition,
honestly — perched on a slope, looking down and out. This is the feature that makes the
world feel like a *descent through a place* rather than a road on a table.

## Confirmed decisions (the guardrails)

- **PRESENTATION-ONLY. The sim stays flat-2D.** The cross-slope is *visual*. The sim
  still decides lateral road position + heading + speed on a flat road shelf; gravity
  still pulls straight down the fall line. **No camber physics** — no sliding to the low
  edge, no banking, no weight transfer. Handling is untouched (we deferred that), the
  sim stays Node-free and unit-tested, and this bounds the work to an **L**. It is also
  exactly what the visual-target note already commits to ("keep the 2D sim; presentation
  adds pitch/vista"). Sim-affecting camber is a separate, larger, gameplay feature —
  explicitly OUT (see Non-goals).
- **NON-FEARFUL by construction.** You can never plunge off a cliff. The drop side is
  guarded by a line of **rounded concrete blocks** (like the splash) — they *look* soft
  (rounded corners) and they *are* soft: hitting them at speed is a forgiving deflect
  (reuse the planned soft-collision model), never a stop, never a fall. The rise side is
  brushable grass hillside (drag, as now). The drama of the drop-off is purely visual.

## The model (presentation only)

- Keep the existing 1-D fall-line profile `height(y)` (the descent) **unchanged**.
- Add a lateral **cross-section** profile: `cross(n, y)` → a height delta, where `n` is
  the signed perpendicular distance from the road centreline (along the road normal):
  - `|n| ≤ half_width`: delta = 0 — the flat road shelf, road unchanged.
  - rise side beyond the edge: delta climbs (hillside / rock cutting).
  - drop side beyond the edge: delta falls (embankment down to the vista).
- Compose in presentation only: `world_height = height(y) + cross(n, y)`. The road
  (`n = 0`) is unchanged, so the rider and the road ribbon stay exactly where they are.
  **The sim never sees `cross()`** — it lives in Terrain3D / the mesh builders.
- Which side drops, and how steep, is a per-course property: start with a fixed
  cross-section along the whole course; vary it per-segment later.

## Architecture

- `cross()` as a small **pure presentation profile** class (mirrors `ElevationProfile`,
  but lateral). Presentation-only — NOT in `sim/`.
- `RoadMesh3D` grass follows `cross()` along the road normal. (Today the grass widens
  along world-X for stability — that reconciliation is the main technical risk, below.)
- New `BarrierBlocks3D` — rounded concrete blocks along the drop edge (MultiMesh, like
  the posts). Rounded box mesh; forgiving deflect handled by the off-road/obstacle model.
- The vista becomes **asymmetric**: near hillside geometry on the rise side blocks the
  vista there; the drop side opens to the 3D backdrop ridges. (Slice C.)

## Slices (in order; shippable after any one)

- **A — Cross-slope ground + drop-side barrier (core).** A fixed cross-section (rise one
  side, drop + concrete blocks the other) along the whole course. The road reads as cut
  into a slope; the rounded blocks guard the drop; drifting into them soft-deflects. Sim
  stays flat. (~L)
- **B — Per-segment variation.** Which side drops, and steepness, vary along the course
  via the segment builder — designed drop-offs, visually cambered sweepers. (~M)
- **C — Asymmetric vista + slope dressing.** Near hillside geometry on the rise side,
  open vista on the drop side; rock/foliage clumps on the slopes. (~L, optional — a
  foliage *system* stays deferred; a few static clumps is fine.)

## Hard parts / risks

- **Ground mesh geometry.** Cross-slope along the road *normal* vs the current
  "grass widens along world-X" (which fixed earlier elevation-sampling clipping on
  curves). Reconciling the two without reintroducing clipping is the main risk — expect
  capture-driven iteration here.
- **Readability.** Keep the road legible when the ground drops steeply beside it. The
  white gutter lines + the kerb blocks should help mark the edge.
- **Forgiving edge collision.** Today off-road = grass drag + deflect. The blocks want a
  firmer nudge at the road edge without a hard stop — reuse the planned soft-collision
  model, tuned so hitting a block at speed pushes you back onto the road, never stops
  you dead.

## Non-goals (deferred)

- **Camber affecting handling/gravity** (sliding to the low edge, banking, weighting) —
  the big gameplay version. Explicitly OUT this round.
- Falling off / cliff death — never (not fearful).
- Procedural terrain, height-field editing, terrain textures.
- A foliage *system* (a few static clumps in Slice C is fine).

## Sizing

Presentation-only + Slice A = **L**. A + B ≤ L. Slice C is optional and drifts toward XL
if foliage creeps past "a few static clumps".
