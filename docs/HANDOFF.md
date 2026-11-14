# Handoff log

Newest entry at the top. Write one at the end of every AI session. Read the last 3 at the start of every session.

---

## 2026-11-15 · Sufi (with Claude) · branch feat/review-mode
Done:
- Review mode for team testing: every minigame becomes a placeholder panel with one COMPLETE button.
  COMPLETE calls the same on_win as a real win, so the task is recorded exactly the same way (online too).
  - Turn it on/off: F8 in game, or Esc > SETTINGS > REVIEW MODE. Per computer, kept across scenes
    (Network meta "review_mode"). Off by default: the real minigames are unchanged.
  - minigames.gd: _review() at the top of all 10 minigames (timing, sliders, fuel, orbit, wind, scan,
    wires, wipe, pack, pick). esc_menu.gd: the SETTINGS switch + F8 in CONTROLS.
  - Also covered: the Engineer's rocket workshop (COMPLETE locks the first design that passes every
    check) and question panels with a right answer (ice spot, shield satellites, Mars fuel, Mars mystery,
    all optional quizzes): COMPLETE picks the right one (choices marked "best": true in story.gd).
  - Not affected: the shield/power designers, story choices with no right answer (radiation burst),
    press-and-wait tasks, holds.
- Test: tests/review_mode_test.gd (39 checks). All other suites pass.

## 2026-11-14 · Wam (with Claude) · branch fix/playtest-round1
Done:
- Minigame crash on win fixed (Scientist UV sensor and the others with a STOP/LAUNCH button).
- crew.gd: solo picks a starting role; TAB / crew bar switches crew member, F follow, C CERES autopilot.
  The F1-F4 shared keyboard mode is gone (it was why autopilot never ran in solo).
- Lobby: click a role card in SOLO, HOST and JOIN (Network.claim_slot).
- world_map.gd: M shows the whole map like the HTML; using a door walks the corridor on the map.
- Rooms now use the HTML's own pictures (tools/export_world_maps.js); furniture blocks walking.
- CERES is the wake-up robot everywhere (portrait, rooms, map).
- docs/CODE_MAP.md explains every file. New tests: tests/crew_test.gd, door_test.gd, minigame_test.gd.

## 2026-11-14 20:30 · Wam (with Claude)
Done:
- feat/mission-designers (same as the HTML demo): shield satellite designer (Moon Factory, Engineer), Moon outpost
  power designer (Solar Ridge, Quartermaster), Mars greenhouse power designer (Power Shed, Quartermaster), all in
  game/dawn/designers.gd. A mission report with stars and a NASA DATA box after every mission (shared online,
  TRY ANOTHER DESIGN rewinds). Ozone meter in Dobson Units. Optional missions B C D G H are quick choices.
  Title: impact line + CREDITS & NASA DATA. Numbers listed in docs/SOURCES.md for Dino to check.
- Tests: 25 passing.

## 2026-11-14 21:30 · Wam (with Claude)
Done:
- feat/html-look: the Godot screens now look and move like the HTML demo.
  - game/dawn/pixel.gd: the demo's 320x180 pixel drawing (sky, cracked ozone, mountains, bunker, workshop,
    periscope, bunker map, planets, CERES, rocket) scaled 4x.
  - Intro (7 animated slides, fixed-size text box with typewriter text), the interactive wake-up room
    (alarm, CERES robot, periscope, map, crew capsules, hangar door), workshop, readiness vote, launch with
    smoke, report, trips, ending: all ported from the demo.
  - game/dawn/title.tscn: title screen + lobby (PLAY SOLO / HOST A CREW / JOIN A CREW, crew code = host IP).
  - dawn_theme.gd + assets/fonts (Press Start 2P, Pixelify Sans, OFL): same buttons, panels and dialogue box.
Open questions:
- Imran: set Run → Main Scene to res://game/dawn/title.tscn when you are happy with it (project.godot is yours).

## 2026-11-14 20:15 · Wam (with Claude)
Done:
- feat/role-minigames: game/dawn/minigames.gd, 10 minigames (timing, sliders, fuel burns, orbit/perigee/launch
  window, wind, neutron scan, wires, panel wiping, cargo packing, picture picks). Every role has prep jobs
  before Act 1's review, the Moon trip, the shield launch and the Mars departure (PREP/TASKS in story.gd).
- Automated playthrough with every minigame opened reaches the ending with no errors.

## 2026-11-14 19:30 · Wam (with Claude)
Done:
- feat/story: the whole story of the HTML demo in Godot (game/dawn/story.gd + story_ui.gd): intro and wake-up,
  mission board, workshop (rocket designer), readiness review, launch with the UV-storm choice, mission report,
  trips with "+N days later", Moon (ice, cable, mine hold, solar storm, shield), Mars robots (panels, MOXIE,
  greenhouse, dust storm, seeds, fuel, ascent), optional missions B C D G H J, three endings.
- Holds (everyone on their spot) and storms work online; autopilot crew walk to their spots.
- .shot-style automated playthrough reached the ending with no errors.
Next:
- feat/role-minigames: replace the simple "press and wait" tasks with the role minigames.

## 2026-11-14 18:40 · Wam (with Claude)
Done:
- feat/moon-mars-maps: `game/dawn/dawn.tscn` replaces the bunker scene. All 37 rooms of Earth, Moon and Mars
  from data/worlds.json (world_data.gd), all 21 posters, Mars robots (robot_<role>.png), hazards:
  UV on Earth's surface, cold + darkness in the Moon's ice mine, robot batteries on Mars.
- Always 4 crew: people play some roles, CERES autopilot runs the rest (player.gd `ai`).
- Debug (offline): F9/F10/F11 jump to Earth/Moon/Mars.
Next:
- feat/story: the five acts, holds, storms, travel and ending. Then feat/role-minigames.

## 2026-11-14 17:45 · Wam (with Claude)
Done:
- feat/earth-bunker: `game/dawn/bunker.tscn`, first Godot slice of the HTML demo (web/demo). 12 Earth rooms with
  their own shapes, doors that lead to the next room, furniture, 8 wall posters (data/posters.json, all 21 included),
  role outfits, spacesuit locker, UV burns on the surface, game clock, mission panel (TAB or click the objective).
  Works offline (F1-F4 local players) and online (test_network.tscn → "Start Bunker (host)").
- Tests: door/station geometry, path finding, clock text (14 passing).
For Sufi:
- Next slices: story steps + role minigames for Act 1, then the Moon and Mars maps (same bunker_data format).
- player.gd now has `role`, `sprite_scale` and `suited` (builds its Sprite from game/player/role_sprites.gd).
For Zaliq:
- Bunker HUD is plain Labels/Buttons in bunker.gd; restyle freely or move it to ui/.
Open questions:
- Character sprites are AI-assisted pixel art (see assets/CREDITS.md). Check the Space Apps AI-content rule.

## 2026-11-14 10:15 · Imran
Done:
- Repo created with HANDOVER.md, CONTRACT.md v1, CLAUDE.md/AGENTS.md, stub engine, sample data.
For Sufi:
- Run the stub, confirm it loads, push. Then data_loader.gd.
For Zaliq:
- Build title → brief → designer → review → report against the stub's fake results.
Open questions:
- none

<!-- Template
## YYYY-MM-DD HH:MM · Sufi|Zaliq
Done:
-
For the other side:
-
Open questions:
-
-->
