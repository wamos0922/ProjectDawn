# Sound engine: how sound works and how to change it

Everything lives in **`game/audio/sound.gd`** (autoload `Sound`). For now every slot uses the sounds of
the HTML demo, rendered to files in `assets/audio/html/` by `tools/render_html_sounds.py`.

## The slots

### Music (one track at a time, crossfades in 0.6 s)

| Situation | When it plays | File now |
|---|---|---|
| `title` | Title screen and lobby | `music_dawn.wav` |
| `earth` | Background on Earth (Bunker 4) | `music_earth.wav` |
| `moon` | Background on the Moon | `music_moon.wav` |
| `corridor` | Walking a corridor on the map when you use a door | *(empty = keeps the world music)* |
| `minigame` | While a role minigame is open | *(empty = keeps the world music)* |
| `storm` | Solar storm (run to the shelter) | `music_alarm.wav` |
| `ending` | Flight home and the ending | `music_dawn.wav` |

If two situations are true at once, the first in this order wins:
ending → storm → minigame → corridor → world background. (See `_music_situation()` in `game/dawn/dawn.gd`.)

### One-shot sounds (up to 6 at the same time)

| Name | When it plays | File now |
|---|---|---|
| `success` | A minigame is won (also COMPLETE in review mode) | `chime.wav` |
| `failure` | A wrong try in a minigame | `bad.wav` |
| `click` | Any button is pressed | `blip.wav` |
| `door` | You walk into a room | `door_hum.wav` |
| `alarm` | A storm starts | `alarm_beep.wav` |
| `poster` | You read a poster for the first time | `chime.wav` |

## Changing a sound (no code)

1. Put your file in `assets/audio/` (for example `assets/audio/corridor.ogg`). **.ogg** is best for music
   (small), **.wav** for short sounds. Open Godot once so it imports the file.
2. In `game/audio/sound.gd`, change the path in `MUSIC` or `SFX`:
   ```gdscript
   "corridor": "res://assets/audio/corridor.ogg",
   ```
3. Run the game. Music loops by itself (the engine turns looping on for every music file).

To make the corridor or minigame music go back to "keep the world music", set its path to `""`.

## Adding a new slot

- **New one-shot sound:** add a line to `SFX`, then call `Sound.play("my_sound")` where it should happen.
- **New music situation:** add a line to `MUSIC`, then return its name from `_music_situation()` in
  `game/dawn/dawn.gd` (put it at the right place in the order).

## Volume

```gdscript
Sound.set_volume("Music", 0.5)   # 0..1
Sound.set_volume("SFX", 1.0)
Sound.toggle_mute()
```
Music and sound effects have their own audio buses ("Music", "SFX"), so a settings slider can change each
one. (The Esc > SETTINGS page is a good place for those sliders later.)

## Where the engine is called

| File | Call | Why |
|---|---|---|
| `game/dawn/dawn.gd` | `_update_sound()` every frame | picks the music situation, beeps when a storm starts |
| `game/dawn/dawn.gd` | `Sound.play("door")`, `Sound.play("poster")` | entering a room, first time reading a poster |
| `game/dawn/minigames.gd` | `Game.win()` / `Game.fail()` | success and failure sounds; `is_open()` for the minigame music |
| `game/dawn/title.gd` | `Sound.music("title")` | title screen music |
| `game/audio/sound.gd` | every Button | click sound, added automatically |

Sound is local: every computer picks its own music from the shared game state, so online players hear
the same situation without sending anything over the network.

## Re-making the HTML sounds

```
python3 tools/render_html_sounds.py      # needs numpy; writes assets/audio/html/*.wav
```
It plays the same notes as the HTML demo's synth (`c1.js`: `chime`, `blip`, `bad`, `alarmBeep`, `doorHum`
and the `TRACKS` music) and saves each music track as one seamless loop.

## Check

```
godot --headless --path . -s res://tests/sound_test.gd
```
