extends "res://game/dawn/minigames/mini_game.gd"
## ACT 3 · SCIENTIST · Scan the Sun's light. Move the scanner along the spectrum and tag every band:
## stopped by AIR, stopped by OZONE (now missing) or reaches the GROUND. The OZONE bands become the
## shield's filter. Moon Factory, before the Engineer designs the shield.
## Real: UV-A 315–400, UV-B 280–315, UV-C 100–280 nm (edges vary by source); ozone absorbs all UV-C,
## most UV-B, little UV-A. Game: UV-B counts as fully stopped by ozone.

const BANDS := [{"n": "RADIO", "r": "> 1 mm", "a": "ground", "col": "#68386c"}, {"n": "INFRARED", "r": "700 nm – 1 mm", "a": "ground", "col": "#b86f50"},
	{"n": "VISIBLE", "r": "400 – 700 nm", "a": "ground", "col": "rainbow"}, {"n": "UV-A", "r": "315 – 400 nm", "a": "ground", "col": "#8b9bb4"},
	{"n": "UV-B", "r": "280 – 315 nm", "a": "ozone", "col": "#b55088"}, {"n": "UV-C", "r": "100 – 280 nm", "a": "ozone", "col": "#68386c"},
	{"n": "X-RAY", "r": "0.01 – 10 nm", "a": "air", "col": "#0099db"}, {"n": "GAMMA", "r": "< 0.01 nm", "a": "air", "col": "#ead4aa"}]
const TAGS := {"air": ["AIR", "blocked by air"], "ozone": ["OZONE", "blocked by ozone (now missing!)"], "ground": ["GROUND", "reaches the ground, OK"]}
const RAINBOW := ["#e43b44", "#f77622", "#fee761", "#63c74d", "#0099db", "#68386c"]

var sel := 0
var tags: Array = []
var wrong := 0
var flash: Array = []


func _init() -> void:
	lo = true
	title = "SCAN THE SUN'S LIGHT"
	goal = "Move the scanner along the Sun's light. Tag every band: stopped by AIR, stopped by OZONE (now missing), or reaches the GROUND safely. The OZONE bands become the shield's filter."


func setup() -> void:
	sel = 0
	tags = [null, null, null, null, null, null, null, null]
	wrong = 0
	flash = []
	for kk in TAGS:
		var id: String = kk
		add_button(TAGS[id][0], func(_b): _tag(id))
	add_button("CHECK", func(_b): check())
	say("Scan a band (click it or use ◄ ►), then tag it.")


func key(kc: int, down: bool) -> bool:
	if kc == KEY_LEFT or kc == KEY_RIGHT:
		if down:
			sel = clampi(sel + (1 if kc == KEY_RIGHT else -1), 0, 7)
		return true
	return false


func drag(q: Vector2) -> void:
	if mouse_down and q.y > 20 and q.y < 70 and q.x > 16 and q.x < 304:
		sel = clampi(floori((q.x - 16) / 36), 0, 7)


func press(q: Vector2) -> void:
	if q.y > 20 and q.y < 95 and q.x > 16 and q.x < 304:
		sel = clampi(floori((q.x - 16) / 36), 0, 7)


func _tag(id: String) -> void:
	tags[sel] = id
	flash.erase(sel)
	if sel < 7:
		sel += 1


func check() -> void:
	if null in tags:
		say("Tag every band first.", "bad")
		return
	var bad := []
	for i in BANDS.size():
		if BANDS[i]["a"] != tags[i]:
			bad.append(i)
	if not bad.is_empty():
		wrong += bad.size()
		flash = bad
		var b: Dictionary = BANDS[bad[0]]
		say("%d tag(s) wrong (flashing). Hint: %s is %s." % [bad.size(), b["n"], TAGS[b["a"]][1]], "bad")
		return
	finish(3 if wrong == 0 else (2 if wrong <= 2 else 1),
		"Our air already stops gamma rays and X-rays. Ozone used to stop UV-C and most UV-B. Visible light must still pass, or plants die and Earth goes dark. So the shield filters only the UV that the ozone layer used to stop.",
		"Solar spectrum measured by NASA missions such as SORCE and TSIS-1.")


func paint() -> void:
	sky(Color("#0b0913"))
	disc(-30, 50, 44, P["o"])
	disc(-30, 50, 38, P["y"])
	var blink := int(Time.get_ticks_msec() / 200) % 2 == 0
	for i in BANDS.size():
		var b: Dictionary = BANDS[i]
		var x := 16.0 + i * 36
		if b["col"] == "rainbow":
			for kk in RAINBOW.size():
				R(x + kk * 6, 24, 6, 40, Color(RAINBOW[kk]))
		else:
			R(x, 24, 36, 40, Color(b["col"]))
		R(x, 24, 0.6, 40, P["k"])
		T(b["n"], x + 18, 68, P["w"], 1, 5.5)
		var tg = tags[i]
		if tg != null:
			var fill: Color = P["pu"] if tg == "ozone" else (P["nv"] if tg == "air" else P["dg"])
			RR(x + 3, 78, 30, 12, fill, P["r"] if (i in flash and blink) else P["w"], 1.5)
			T(TAGS[tg][0], x + 18, 80, P["w"], 1, 5.5)
	RR(16 + sel * 36 - 2, 20, 40, 48, null, P["y"], 1.5)
	var b2: Dictionary = BANDS[sel]
	RR(16, 100, 288, 60, Color("#0b0913"), P["b"], 1.5)
	T("SCANNER", 22, 104, P["b"])
	T(b2["n"], 22, 116, P["y"], 0, 10)
	T("wavelength %s" % b2["r"], 22, 132, P["w"])
	T("shorter wavelength = more energy →", 300, 148, P["lg"], 2, 6)
	T("← long waves", 22, 148, P["lg"], 0, 6)
