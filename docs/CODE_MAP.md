# Code map: which file does what

This is the Godot version of the Project Dawn demo. The HTML demo is the reference: when the two
disagree, the HTML is right. Start the game from `game/dawn/title.tscn` (open it, press F6).

## How a game runs (follow the arrows)

```
title.gd  ──START──▶  dawn.tscn (dawn.gd)
 lobby: pick role,          │ builds 24 rooms (room_view.gd), the crew (crew.gd),
 solo crew mode             │ the HUD (dawn_ui.gd), the world map (world_map.gd)
 (Network meta)             ▼
                      story.gd  ── decides what happens: objective, holds, what E does at a console
                            │      changes the shared state S (host only)
                            ▼
                      story_ui.gd / designers.gd / minigames.gd  ── full-screen scenes and panels
```

Every computer shows the same shared state `S` (a Dictionary in dawn.gd). Only the host changes it:
a guest calls `act()`, the host runs `story.do_effect()`, then `commit()` sends `S` to everyone.
Solo play is simply "you are the host".

## Files, one line each

| File | What it is responsible for | Look here when… |
|---|---|---|
| `game/dawn/title.gd` | Title screen, credits, SOLO / HOST / JOIN lobbies, role cards you click | you cannot pick a role, the lobby looks wrong |
| `game/net/network.gd` | Autoload `Network`: host, join, player list, `claim_slot()` for roles, `start_game()` | players do not connect, roles clash online |
| `game/dawn/dawn.gd` | Main game scene: shared state `S`, `act/commit`, doors, hazards (UV, cold, battery), holds, HUD text, keys | a key does nothing, a door misbehaves, hazards, sync bugs |
| `game/dawn/crew.gd` | Who controls each crew member: TAB switching, F follow, C autopilot, "only the X can do this" rule | autopilot does not move, TAB does not switch, a role is blocked |
| `game/dawn/world_map.gd` | The overview map (M) and the corridor walk when you use a door | the map looks wrong, you get stuck between rooms |
| `game/dawn/room_view.gd` | Draws one room: the HTML picture + doors, hold rings, CERES, highlights | a room looks wrong, a ring does not show |
| `game/dawn/world_data.gd` | Pure data/geometry: rooms, doors, stations, paths, clock text (no nodes, tested) | a door or station is in the wrong place, pathfinding |
| `game/dawn/story.gd` | The three acts (Earth → Moon → home, see docs/STORY_MOON_ONLY.md): objective, holds, what each console does, effects, storms | the story does not advance, wrong objective |
| `game/dawn/story_ui.gd` | Full-screen scenes: intro, wake-up, workshop, poll, launch, report, travel, ending | an animation or story screen is wrong |
| `game/dawn/designers.gd` | NASA numbers, the two designers (Moon outpost power, shield) and their rules | a design passes/fails when it should not |
| `game/dawn/minigames.gd` | The role minigames (UV sensor timing, tuning, bolts, burn, cargo…), and review mode (F8: one-click placeholders) | a minigame crashes or cannot be won |
| `game/dawn/dawn_ui.gd` | HUD (top bar, objective, crew bar), toasts, dialogue box + portrait, panels | HUD layout, dialogue box, buttons |
| `game/dawn/pixel.gd` | 320×180 pixel canvas with the HTML drawing helpers (sky, rocket, person, CERES robot) | a drawn animation looks different from HTML |
| `game/audio/sound.gd` | Autoload `Sound`: music per situation (title, Earth, Moon, corridor, minigame, storm, ending) and one-shot sounds. File paths in `MUSIC` / `SFX` (see docs/SOUND.md) | a sound is wrong, missing or too loud |
| `game/dawn/dawn_theme.gd` | Colours, fonts, button and panel styles (`DawnTheme`) | colours or fonts |
| `game/player/player.gd` | One crew member body: walking, E to use, online position sync | movement, the E key |
| `game/player/role_sprites.gd` | Sprite sheets per role (uniform, spacesuit) | a character sprite is wrong |
| `game/input_setup.gd` | Key bindings (WASD/arrows + E/Enter) | change controls |
| `game/camera/room_camera.gd` | Camera that snaps to the room you are in | camera |
| `tests/run_tests.gd` | Unit tests for the pure rules (geometry, paths, designers) | run after every change |
| `tools/export_world_maps.js` | Runs the HTML's own code and exports the map and room pictures | the HTML maps/rooms changed and Godot must follow |

## Data files

| File | Contents |
|---|---|
| `data/worlds.json` | Rooms (shape, tone, grid cell), edges (doors), stations, room info text |
| `data/map.json` | Overview map: room shapes in map pixels, tones, labels (from the HTML) |
| `data/interiors.json` | Per room: HTML door spots, station spots, furniture you cannot walk through |
| `data/posters.json` | The 21 fun-fact posters |
| `assets/map/*.png` | Map layers: floor + corridors (`_under`), furniture (`_over`); `_h` = Hydroponics open |
| `assets/rooms/int_*.png` | One picture per room, drawn by the HTML code |

To refresh the pictures after the HTML changes: `node tools/export_world_maps.js <out dir>` with the
HTML sources in `/home/claude/v2` (edit the path `V` at the top), then copy the PNGs and JSON into
`assets/map`, `assets/rooms` and `data/`.

## Crew control rules (crew.gd)

- **Solo:** all four crew members are on your computer. You control one (picked in the lobby).
  TAB or a click on the crew bar switches. The lobby (and C in game) chooses what the others do:
  - **CERES autopilot:** they walk to the spots a hold needs and into shelters during storms.
  - **I move everyone:** they wait. Only storms still move them (after 8 s) so nobody dies off-screen.
- **F:** the others follow you, including through doors.
- **Online:** each person controls the role they picked. Roles nobody picked run on the host
  as autopilot, and the host can TAB to them.
- **Jobs for another role:** solo says "press TAB"; online, a role nobody plays can be covered;
  a role a teammate plays says "ask your teammate".

## Keys

WASD or arrows walk · E or Enter use · Space/click next line · TAB switch crew · F follow ·
C autopilot · M world map · J mission details · Esc close · F8 review mode (minigames become one click) · F9/F10 jump to Earth/Moon (solo debug)

## Checking your change

```
godot --headless --path . -s res://tests/run_tests.gd       # pure rules (25 tests)
godot --headless --path . -s res://tests/crew_test.gd       # TAB, follow, autopilot, role rule
godot --headless --path . -s res://tests/door_test.gd       # walk out a door → map trip → next room
godot --headless --path . -s res://tests/sound_test.gd       # music follows the situation, sounds play
godot --headless --path . -s res://tests/all_doors_test.gd  # every door in all 24 rooms can be walked through
godot --headless --path . -s res://tests/minigame_test.gd   # plays each minigame through its buttons
godot --headless --path . -s res://tests/review_mode_test.gd  # F8 review mode: every minigame is a one-click placeholder
```
(The two "bolts" minigames have a moving target and time out in the test; that is expected.)
