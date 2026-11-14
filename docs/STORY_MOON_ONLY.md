# Project Dawn: the shortened story (Earth → Moon → home)

**Status:** this is the story the Godot game plays (branch `feat/moon-only-story`, 15 Nov 2026).
It replaces Acts 4–5 (Mars) and all the optional "Helping Humanity" missions in `docs/STORY.md`
and `GAMEPLAY.md`. Those two files still describe the original, longer design.

## In one line

The crew measures the damage on Earth, makes rocket fuel from Moon ice, launches a shield from the
Moon to the L1 point, flies home, and steps outside into the first real sunrise. Every ending is happy.

## The three acts

| Act | World | What the crew does | Ends with |
|---|---|---|---|
| 1 · First Light | Earth, Bunker 4 | Open the mission board → **launch prep** (each role has a job) → readiness review → sounding rocket measures the UV → **Moon trip prep** → suit up → board the shuttle | Flight to the Moon (3 days) |
| 2 · Water Above Us | Moon, Shackleton Outpost | Check in → Scientist finds the ice → Quartermaster designs the outpost power → Engineer + Scientist mine the ice → Navigator splits it into fuel → **solar storm**: everyone into the shelter | Fuel tanks full |
| 3 · The Shield | Moon | Engineer designs the shield satellites → Engineer + Quartermaster build them at the factory → Navigator aims the shield at **L1** → all four launch it from the Moon Port → **shield report** | **Homecoming**: flight back to Earth (3 days), the capsule lands by Bunker 4, **happy ending** |

### Step by step (what the HUD objective says)

**Act 1 · Earth** (`S.step`)

| step | Objective | Who |
|---|---|---|
| 0 | Open the mission board in Mission Control | anyone |
| 1 | Launch prep: build the rocket · calibrate the UV sensor · pick the launch hour · tune the ground station | ENG · SCI · NAV · QM, at the same time |
| 2 | Readiness review: all 4 on their consoles in Mission Control | all |
| 3 | Start the countdown at the Launch Pad (UV outside: wear the suit or be quick) | NAV |
| 4 | Hear the results in Mission Control | anyone |
| 5 | Moon trip prep: plan the trip · pack the cargo · pre-flight check · pick the landing site, then suit up and board | NAV · QM · ENG · SCI, then all |

**Acts 2–3 · Moon** (`S.ms`)

| ms | Objective | Who |
|---|---|---|
| 0 | Check in at Lunar Control | anyone |
| 1 | Find the ice (neutron scan) at the Science Lab | SCI |
| 2 | Design the outpost power at the Solar Ridge → mission report ★ | QM |
| 3 | Drill the ice in the dark Ice Mine (hold) | ENG + SCI |
| 4 | Split the ice into fuel at the Fuel Plant → **solar storm**: all 4 into the Radiation Shelter | NAV, then all |
| 5 | Design the shield at the Moon Factory, then build it (hold) | ENG, then ENG + QM |
| 6 | Aim the shield at L1 from the Moon Port, then all 4 take the launch seats (hold) | NAV, then all |
| 7 | Shield report ★ → **CONTINUE** starts the flight home | anyone |

After the flight home the game switches to Earth (`S.step = 6`) and the **ending** scene.

## The ending (always happy)

1. The return capsule floats down under its parachute next to Bunker 4.
2. CERES: "Touchdown! … Welcome home." The shield holds at L1 and the ozone meter is climbing.
3. The four crew walk outside without suits into a real sunrise.
4. The ending title depends on the **mission stars** (rocket + outpost power + shield, up to 9):

| Stars | Title |
|---|---|
| 8–9 | Golden Dawn |
| 5–7 | Rising Dawn |
| 0–4 | Quiet Dawn |

Buttons: **WALK BUNKER 4** (free roam on Earth with every door open) and **PLAY AGAIN** (host).

## What was removed

| Removed | Where it was |
|---|---|
| Act 4 "The Red Teacher" (Mars robots, solar panels, MOXIE oxygen, greenhouse + dust storm) | `story.gd`, `designers.gd` (greenhouse power designer), `dawn.gd` (robot battery hazard) |
| Act 5 "Dawn" (seed vault, Mars fuel, launch window, ascent from Mars) | `story.gd`, `minigames.gd` (fuel burn, panel wipe, Mars launch-window orbit) |
| Teleop hold that sent the crew to Mars | `story.gd` |
| Optional missions B (UV Canopy), C (Water for All), D (Storm Watch), G (Planetary Defense), H (Greenhouse for Every Bunker), J (Mars Mystery) | `story.gd`, ending screen, mission panel |
| The 13 Mars rooms and 7 Mars posters | `data/worlds.json`, `data/map.json`, `data/interiors.json`, `data/posters.json`, `assets/map/mars_*`, `assets/rooms/int_mars_*` |
| Mars robot sprites | `assets/art/characters/robot_*.png`, `role_sprites.gd`, `player.gd`, `pixel.gd` |

The rooms that used to be locked for optional missions (UV Canopy, Hydroponics, Water Purifier) are
now ordinary open rooms you can walk into and look around. The Teleop Center on the Moon stays as a room
with flavour text.

## What changed in numbers

- Rooms: 37 → **24** (12 Earth, 12 Moon). Posters: 21 → **14**.
- Mission stars: up to **9** (3 reports × 3). The mission panel (J) shows MISSION STARS instead of OPTIONAL MISSIONS.
- Trip days: Earth → Moon 3, shield deployment 90, Moon → Earth 3.
- Debug keys (solo): F9 Earth, F10 Moon (F11 Mars is gone).

## Files touched

| File | Change |
|---|---|
| `game/dawn/story.gd` | Moon-only objectives, holds and effects; after the shield report `_fly_home()` → `_land_on_earth()` |
| `game/dawn/story_ui.gd` | Homecoming travel scene, new ending (capsule landing, stars → title), mission board |
| `game/dawn/dawn.gd` | Shared state without Mars/optional keys, act numbers 1–3, `mission_stars()`, no Mars hazard |
| `game/dawn/designers.gd`, `minigames.gd`, `title.gd` | Mars designer, Mars minigames and Mars credits line removed |
| `game/dawn/crew.gd`, `room_view.gd`, `world_data.gd`, `world_map.gd`, `pixel.gd` | No Mars world or robots |
| `game/player/player.gd`, `role_sprites.gd` | Robot body removed (uniform and spacesuit only) |
| `data/*.json`, `assets/` | Mars rooms, map, room pictures, posters and robot sprites removed; optional-room locks removed |
| `tests/` | Room count, Mars tests replaced by Moon/ending tests |

## How to check it

```
godot --headless --path . -s res://tests/run_tests.gd          # 25 rules
godot --headless --path . -s res://tests/review_mode_test.gd   # every minigame still completes
godot --headless --path . -s res://tests/all_doors_test.gd     # all 24 rooms, every door
```

Fast play-through: F8 (review mode) makes every minigame one click. The full story then takes a few
minutes: Earth → Moon → shield → HOMECOMING → ending.
