I want you to help me build a small playable prototype of a downhill longboarding game in Godot.

This is an exploratory project. I want to be actively involved in the design and implementation, rather than having you independently build a large solution and present it to me afterwards.

## Development approach

Work iteratively.

Before making a substantial architectural decision, explain the options briefly and recommend one.

Implement the game in small vertical slices that I can run and evaluate.

At the end of each meaningful increment:

1. Tell me what changed.
2. Tell me which files were added or modified.
3. Explain any important design decisions.
4. Tell me how to run and test it.
5. Ask me to play it and give feedback before making significant gameplay changes.

Do not build several speculative systems ahead of what we currently need.

Prefer simple implementations that can later evolve cleanly.

## Technology

Use Godot 4.8.

Use GDScript unless there is a compelling reason not to.

For this first prototype, use a deliberately lo-fi 2D visual style.

Do not introduce 3D yet.

The prototype should use simple shapes, sprites, lines and placeholder graphics that can easily be replaced later.

Gameplay code must not depend unnecessarily on presentation code.

## Code quality

Treat this as the beginning of a real codebase, not disposable prototype code.

I care strongly about:

- clear architecture
- small focused classes/scripts
- explicit responsibilities
- meaningful names
- low coupling
- composition rather than deep inheritance
- avoiding large God objects
- avoiding gameplay logic buried inside UI or rendering code
- deterministic logic where practical
- code that can be tested without running an entire game scene

Separate simulation/gameplay logic from Godot presentation where reasonable.

Avoid abstractions that do not yet solve a real problem.

Do not over-engineer.

When you see a trade-off between prototype speed and maintainability, explain it briefly.

## Testing

Unit tests are required.

Choose an appropriate Godot/GDScript testing framework and explain your choice before introducing it.

Gameplay calculations should be written in ways that make them easy to unit test.

At minimum, tests should eventually cover things such as:

- acceleration from gradient
- speed limits/clamping where applicable
- steering/carving calculations
- braking
- grip or traction calculations
- transitions into and out of slides
- any scoring/flow calculations once those exist

Tests should focus on meaningful behaviour rather than implementation details.

Keep scene/integration tests separate from pure unit tests.

All tests should be runnable easily from the project/repository.

## Game concept

The game is about downhill longboarding.

The inspiration is the feeling of watching skilled downhill mountain biking at places such as Whistler:

- speed
- commitment
- reading the terrain
- choosing a line
- smooth sequences of corners
- flow
- occasional danger
- spectacular scenery

It is NOT primarily a Tony Hawk-style trick game.

The player's skill should come from riding a line beautifully.

A good sequence should eventually feel something like:

carve → apex → tuck → accelerate → crest → compression → slide → recover → accelerate

The final game may eventually use large real-world-inspired descents such as:

- Taipei mountain roads
- Rio de Janeiro
- Doi Suthep / Chiang Mai
- Mt Hotham to Harrietville

Real elevation/GPS data may eventually form the basis of terrain, but routes will be creatively compressed and modified for gameplay.

None of that geographical tooling is required for the first prototype.

## First playable prototype

Start extremely small.

I want one short downhill course, perhaps 60–90 seconds long.

Use a top-down or slightly pseudo-isometric 2D presentation.

The rider remains approximately within the lower-middle portion of the screen while the environment moves around them.

The road should have curves rather than simply scrolling vertically.

Initially the player needs only:

- gravity/slope-driven acceleration
- steering / carving
- braking
- a tuck for reduced drag / increased speed
- collision with road boundaries
- a simple sense of momentum

Do NOT add tricks, progression, cosmetics, multiplayer, procedural generation, traffic, collectibles or elaborate scenery yet.

## Important control philosophy

The board should not feel like a car.

Turning should represent the rider leaning into a carve.

Speed should influence turning behaviour.

At low speed the board can change direction relatively easily.

At high speed the player should need to anticipate corners.

Eventually we may distinguish between:

- carving
- grip
- controlled sliding
- braking
- rider weight transfer

For the first iteration, implement only enough physics to explore whether carving feels satisfying.

I strongly prefer a controllable approximation over physically accurate skateboard simulation.

## Visual prototype

Keep the visuals deliberately charming and minimal.

For example:

- a simple road ribbon
- grass/background terrain
- a small stylised rider and board
- basic shadows
- perhaps simple trees or roadside objects

Do not spend meaningful development time creating art.

The visual goal is readability and personality rather than realism.

The eventual game should have epic backgrounds, but this prototype is testing movement first.

## Camera

The camera is important even in 2D.

It should help communicate speed.

Experiment conservatively with things such as:

- looking further ahead as speed increases
- slight lateral camera lag
- subtle zoom changes
- subtle screen shake only where appropriate

Keep camera effects isolated so they can easily be tuned or disabled.

Do not use excessive effects to disguise weak movement mechanics.

## Flow

Do not implement a complete flow/scoring system yet.

Architect the prototype so one could later observe things such as:

- sustained speed
- smooth steering
- successful corner sequences
- unnecessary braking
- collisions
- slides
- near misses

Eventually these could contribute to a hidden or lightly presented "flow" state.

## Surprises

An important future design principle is that the world may contain rare undocumented joyful interactions.

Examples:

- reaching down to grab a daisy
- briefly touching a squirrel running alongside
- high-fiving somebody beside the road

These are not collectibles and should not generate "7/20 secrets found" UI.

They should feel like unexpected Easter eggs.

Do not implement these yet, but avoid architectural decisions that would make contextual world interactions difficult later.

## First task

Do not start by building the entire prototype.

First:

1. Propose a small project structure.
2. Explain how you suggest separating the rider simulation from its Godot node/presentation.
3. Propose the minimum state required for the first movement model.
4. Explain your proposed unit-testing approach.
5. Describe the smallest first implementation milestone.

The first milestone should ideally produce something I can run within minutes:

A simple rider on a simple road where gravity causes forward movement and I can carve left and right.

Wait for my feedback after that milestone before substantially expanding the gameplay.