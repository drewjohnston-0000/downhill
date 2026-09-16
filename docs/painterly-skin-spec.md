# Painterly Skin — Spec (v1)

The purpose of this doc is to keep an inherently unbounded, subjective task bounded.
It is the tight spec: acceptance criteria, non-goals, a technique whitelist, a
stop-condition, and a slice breakdown. If achieving the look seems to need a
technique **not** on a slice's whitelist, we STOP and re-size — we do not silently
expand. The win is fewer/smaller: aim for the least that is clearly better than the
flat boxes, not for the reference pixel-for-pixel.

## Target vs baseline (the A/B)

- **Target frame:** `docs/concept-board-files/girl-coogee-1.png` — warm low sun on a
  light road with cool cast shadows, a deep saturated sky, lush roadside greens, and
  the far town/headland fading into atmospheric haze. Soft painterly (not photoreal),
  strong forward-into-the-vista depth — which is already our chase-cam framing.
- **Baseline frame:** current flat-unlit look (capture to `logs/baseline.png`). Its
  specific faults to fix: no sun/shadow (flat fill), a muddy brown horizon band, flat
  lifeless surfaces, no depth/haze separating near from far.

We judge every slice by comparing one of our capture viewpoints against the target
frame — two specific stills, not a vibe.

## Guardrails (apply to every slice)

- **Sim untouched.** All work is in presentation: materials, lights, environment,
  shaders. The unit tests still guard everything that matters; art cannot break the
  game.
- **Readability is sacred.** The road must stay clearly distinct from grass, and the
  posts must stay legible against it. We fought for this (fairness). Any slice that
  hurts it is reverted, no debate.
- **Flat-unlit stays recoverable.** Keep the current look revertible (a style flag or
  a clean git checkpoint before each slice) so we always have a known-good baseline.
- **Capture-driven.** Iterate on rendered frames via the screenshot harness, never
  blind commits. Checkpoint after each slice.
- **Native Metal / Forward+** (Godot 4.8-dev6; dev5's Metal crash is fixed). No
  rendering feature that needs a driver or pipeline we can't run on it.

## Stop-condition (because there is no CI-green here)

Each slice gets **at most 3 tune-and-capture iterations.** If after 3 it is not
*clearly* better than the frame before it, we revert that slice and either re-spec or
stop. "It's fine" is not "clearly better" — if we're squinting, we revert.

## Slice breakdown — do in order, stop after any one

Each slice is an S, independently shippable and reversible. "L" = at most Slice A + B.
Slice C is optional polish. We can ship a coherent game after any slice.

### Slice A — Light & atmosphere (DONE; lowest risk, high payoff)

Turn "flat boxes" into "a lit scene with depth" using only built-in nodes.
Landed: warm `DirectionalLight3D` with shadows, `WorldEnvironment` ambient fill +
depth fog, sky ground-colour fix, materials switched to lit. All 5 criteria met,
capture-verified on Metal. Playtest-confirmed.

- **Whitelist:** one `DirectionalLight3D` (warm sun, casting shadows) · `WorldEnvironment`
  tuning (sky top/horizon colours, ambient light, **distance fog / height fog** for the
  hazy far hills) · switch materials `SHADING_MODE_UNSHADED` → a lit mode so the sun
  reads. Nothing else.
- **Acceptance (all must be yes, judged from one capture):**
  1. Surfaces show a sun direction — a visible light-to-shadow gradient, not flat fill.
  2. The far ground/hills read hazier/lighter than the near ground (atmospheric depth).
  3. The muddy brown horizon band is gone; sky reads as a clean, saturated daytime sky.
  4. Road stays clearly distinct from grass; posts stay legible. (readability guard)
  5. The frame reads warmer / more "lit scene", less "raw 3D render", vs the baseline.

### Slice B — Toon / material character (only if A lands and we want more)

The "drawn" surface quality.

- **Whitelist (to be confirmed when we get here):** a cel/toon shading ramp on the
  surface materials; a warm/cool split (warm sun, cool shadow); grass/road colour pass
  toward the reference palette. Still no post-process pipeline.
- **Acceptance:** surfaces read cel-shaded (banded light, not smooth); warm-sun /
  cool-shadow contrast is visible; readability guard still holds.

### Slice C — Polish (optional; each sub-item is its own tiny S, pick à la carte)

Soft clouds · a yellow road centreline · roadside foliage clumps · subtle colour grade.

## Non-goals — explicitly OUT this round (deferred XL)

Custom painterly post-process pipeline · outline/edge shader (inverted-hull or
screen-space) · foliage/tree *system* (a few static clumps in Slice C is fine; a system
is not) · character art / animating the rider · water rendering · hand-painted textures
· any per-object bespoke shader. If we want one of these, it is a new, separately-sized
piece of work — not a bolt-on to this L.

## Definition of "L" for this work

Lit + atmospheric + (optionally) cel-ish + still readable, presentation-only, whitelist
techniques, capture-verified — roughly one focused session, Slice A (+ maybe B). Any of
the Non-goals would make it an XL; those are deferred by this spec.
