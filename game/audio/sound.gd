extends Node
## Sound engine. Autoload name: "Sound". Owner: Wam (audio).
##
## Two kinds of sound:
##   MUSIC  one looping track at a time. The game asks for a situation ("earth", "corridor",
##          "minigame"...) and the engine crossfades to that situation's file.
##   SFX    short one-shot sounds ("success", "failure", "click"...). Several can overlap.
##
##   Sound.music("moon")        switch the music to the Moon situation (does nothing if already on it)
##   Sound.play("success")      play a one-shot sound
##   Sound.set_volume("Music", 0.5) / Sound.set_volume("SFX", 1.0)    0..1, per bus
##   Sound.toggle_mute()
##
## CHANGING A SOUND: put the file in assets/audio/ (.ogg, .wav or .mp3) and change its path in
## MUSIC or SFX below. Nothing else needs to change. An empty path "" for a music situation
## means "keep the world's background music playing" (corridor and minigame start that way).
## Who asks for which situation: dawn.gd → _music_situation(), title.gd, minigames.gd, dawn.gd.

const DIR := "res://assets/audio/html/"     ## sounds rendered from the HTML demo (tools/render_html_sounds.py)

## Music situations → file. "" = keep playing the world background.
const MUSIC := {
	"title":    DIR + "music_dawn.wav",     ## title screen and lobby
	"earth":    DIR + "music_earth.wav",    ## background on Earth (Bunker 4)
	"moon":     DIR + "music_moon.wav",     ## background on the Moon
	"corridor": "",                         ## walking a corridor on the map between rooms
	"minigame": "",                         ## while a role minigame is open
	"storm":    DIR + "music_alarm.wav",    ## solar storm: run to the shelter
	"ending":   DIR + "music_dawn.wav",     ## homecoming and the ending
}

## One-shot sounds → file.
const SFX := {
	"success": DIR + "chime.wav",           ## minigame won / task done
	"failure": DIR + "bad.wav",             ## minigame wrong try
	"click":   DIR + "blip.wav",            ## any button pressed
	"door":    DIR + "door_hum.wav",        ## walking into a room
	"alarm":   DIR + "alarm_beep.wav",      ## a storm starts
	"poster":  DIR + "chime.wav",           ## found a new poster
}

const BACKGROUNDS := ["title", "earth", "moon"]   ## situations that are a "background" for "" situations
const FADE := 0.6                           ## seconds to crossfade between music tracks
const SFX_VOICES := 6                       ## how many one-shot sounds can play at the same time
const BUSES := ["Music", "SFX"]

var _tracks: Array[AudioStreamPlayer] = []  ## two players, so one fades out while the other fades in
var _front := 0
var _situation := ""
var _path := ""                             ## file playing now
var _background := ""                       ## last world/title track, used when a situation's path is ""
var _voices: Array[AudioStreamPlayer] = []
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_tracks.append(p)
	for i in SFX_VOICES:
		var v := AudioStreamPlayer.new()
		v.bus = "SFX"
		add_child(v)
		_voices.append(v)
	get_tree().node_added.connect(_on_node_added)


# ---------------------------------------------------------------- music

## Switch to a music situation (a key of MUSIC). Safe to call every frame.
func music(situation: String) -> void:
	if situation == _situation:
		return
	_situation = situation
	var path: String = MUSIC.get(situation, "")
	if path == "":
		path = _background                  # e.g. corridor: keep the world music
	elif situation in BACKGROUNDS:
		_background = path
	if path == _path:
		return
	_path = path
	_crossfade(_load(path))


func current_situation() -> String:
	return _situation


func _crossfade(stream: AudioStream) -> void:
	var old := _tracks[_front]
	_front = 1 - _front
	var new := _tracks[_front]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(old, "volume_db", -80.0, FADE)
	tw.chain().tween_callback(old.stop)
	if stream:
		new.stream = stream
		new.volume_db = -80.0
		new.play()
		create_tween().tween_property(new, "volume_db", 0.0, FADE)


# ---------------------------------------------------------------- one-shot sounds

## Play a one-shot sound (a key of SFX).
func play(name: String) -> void:
	var stream := _load(SFX.get(name, ""))
	if stream == null:
		return
	for v in _voices:
		if not v.playing:
			v.stream = stream
			v.play()
			return
	_voices[0].stream = stream                # all busy: reuse the first voice
	_voices[0].play()


## Every button in the game clicks (also buttons made later, e.g. in panels).
func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.pressed.is_connected(_click):
		n.pressed.connect(_click)


func _click() -> void:
	play("click")


# ---------------------------------------------------------------- volume

## bus "Music" or "SFX" (or "Master"), level 0..1.
func set_volume(bus: String, level: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(clampf(level, 0.0, 1.0)))


func get_volume(bus: String) -> float:
	var i := AudioServer.get_bus_index(bus)
	return db_to_linear(AudioServer.get_bus_volume_db(i)) if i >= 0 else 0.0


func toggle_mute() -> bool:
	AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
	return AudioServer.is_bus_mute(0)


# ---------------------------------------------------------------- files

## Load once and remember. Music files loop; WAV files need their loop set by hand.
func _load(path: String) -> AudioStream:
	if path == "":
		return null
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		push_warning("Sound: missing file " + path)
		_cache[path] = null
		return null
	var s: AudioStream = load(path)
	if path in MUSIC.values():
		s = s.duplicate()
		if s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate)
		elif "loop" in s:
			s.loop = true                       # .ogg / .mp3
	_cache[path] = s
	return s
