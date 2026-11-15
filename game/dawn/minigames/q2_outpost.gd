extends "res://game/dawn/minigames/mini_game.gd"
## ACT 2 · QUARTERMASTER · Pack the outpost payload. The outpost must FIND ICE, WATCH RADIATION and
## SEE INTO SHADOWS within 100 kg, 100 W and 3 Mbps. Moon Solar Ridge, before the power design.
## Data: team instruments.csv (NASA fact sheets); 100 kg / 100 W = LRO payload allowance.
## Photos: assets/minigames/<key>.jpg (lend, lamp, diviner, lola, lroc, crater, hirise, omi, sam).

const ITEMS := [
	{"key": "lend", "n": "LEND", "p": "Neutron counter", "f": "ice_finder", "kg": 26.3, "w": 13.0, "mb": 0.0029},
	{"key": "lamp", "n": "LAMP", "p": "UV frost finder", "f": "ice_finder+shadow_imager", "kg": 6.1, "w": 4.0, "mb": 0.01},
	{"key": "diviner", "n": "Diviner", "p": "Heat mapper", "f": "heat_mapper", "kg": 11.0, "w": 24.7, "mb": 0.02},
	{"key": "lola", "n": "LOLA", "p": "Laser altimeter", "f": "terrain_mapper", "kg": 9.6, "w": 26.2, "mb": 0.01},
	{"key": "lroc", "n": "LROC NAC", "p": "Shadow camera", "f": "shadow_imager", "kg": 8.2, "w": 6.4, "mb": 2.0},
	{"key": "lroc", "n": "LROC WAC", "p": "Wide camera", "f": "camera", "kg": 0.9, "w": 2.6, "mb": 1.0},
	{"key": "crater", "n": "CRaTER", "p": "Radiation meter", "f": "radiation_meter", "kg": 5.53, "w": 6.66, "mb": 0.0891},
	{"key": "hirise", "n": "HiRISE", "p": "Big camera", "f": "terrain_mapper", "kg": 65.0, "w": 60.0, "mb": 4.0},
	{"key": "omi", "n": "OMI", "p": "Ozone mapper", "f": "ozone_mapper", "kg": 65.0, "w": 66.0, "mb": 0.8},
	{"key": "sam", "n": "SAM", "p": "Chemistry lab", "f": "chemistry_lab", "kg": 40.0, "w": 60.0, "mb": 0.01}]
const NEEDS := [["ice_finder", "finds ice"], ["radiation_meter", "watches radiation"], ["shadow_imager", "sees into shadows"]]

var sel: Array = []
var wrong := 0


func _init() -> void:
	title = "PACK THE OUTPOST PAYLOAD"
	goal = "The outpost must FIND ICE, WATCH RADIATION (solar storms!) and SEE INTO SHADOWS. Click instrument photos to load them. Stay under 100 kg, 100 W and 3 Mbps, then SEAL. More than one set can work."


func setup() -> void:
	sel = []
	wrong = 0
	add_button("SEAL", func(_b): seal())
	say("Pick the lightest set that covers all three needs.")


func _tot() -> Dictionary:
	var o := {"kg": 0.0, "w": 0.0, "mb": 0.0, "f": {}}
	for i in sel:
		o["kg"] += ITEMS[i]["kg"]
		o["w"] += ITEMS[i]["w"]
		o["mb"] += ITEMS[i]["mb"]
		for f in String(ITEMS[i]["f"]).split("+"):
			o["f"][f] = true
	return o


func _fname(f: String) -> String:
	return f.replace("_", " ").replace("+", " + ")


func seal() -> void:
	var t := _tot()
	var miss := []
	for n in NEEDS:
		if not t["f"].has(n[0]):
			miss.append(_fname(n[0]))
	if not miss.is_empty():
		wrong += 1
		say("Missing: %s." % ", ".join(miss), "bad")
		return
	if t["kg"] > 100 or t["w"] > 100 or t["mb"] > 3:
		wrong += 1
		say("Over the limit: %.1f kg, %.1f W, %.2f Mbps. Something has to stay home." % [t["kg"], t["w"], t["mb"]], "bad")
		return
	finish(3 if t["kg"] <= 25 else (2 if t["kg"] <= 50 else 1),
		"Sealed at %.1f kg, %.1f W and %.2f Mbps. Every extra instrument costs mass, power and data, so you pack what the mission needs and leave the rest. Different sets can work: LAMP alone finds ice AND sees into shadows." % [t["kg"], t["w"], t["mb"]],
		"NASA's LRO carried seven instruments within about 100 kg and 100 W.")


func _card(i: int) -> Rect2:
	return Rect2(8 + (i % 5) * 126, 184 + floori(i / 5.0) * 88, 122, 84)


func press(q: Vector2) -> void:
	for i in ITEMS.size():
		if _card(i).has_point(q):
			var it: Dictionary = ITEMS[i]
			if i in sel:
				sel.erase(i)
			else:
				sel.append(i)
			say("%s (%s): %s, %s kg, %s W, %s Mbps." % [it["p"], it["n"], _fname(it["f"]), num(it["kg"]), num(it["w"]), num(it["mb"])])


func _scene() -> void:
	R(0, 0, W, 178, P["k"])
	for i in 50:
		var st: Array = STARS[i]
		R(st[0], st[1] * 0.4, 1, 1, Color(1, 1, 1, st[3]))
	# ground (stepped hills)
	var pts := [[0, 178]]
	for x in range(0, 641, 16):
		var gy := 140.0 - 10 * sin(x / 70.0) - 6 * sin(x / 23.0)
		pts.append([x, gy])
	pts.append([640, 178])
	fill_poly(pts, P["gy"])
	R(0, 160, W, 18, P["st"])
	# shadowed crater with ice
	disc(548, 150, 17, Color("#0b1228"))
	R(462, 142, 172, 16, Color("#0b1228"))
	for c in [[520, 150], [545, 154], [570, 148], [590, 152], [535, 146]]:
		R(c[0] - 1, c[1] - 1, 3, 3, P["b"])
	T("SHADOWED CRATER (ice)", 548, 164, P["b"], 1, 10)
	# solar tower
	R(98, 76, 5, 64, P["lg"])
	RR(60, 60, 80, 22, Color("#124e89"), P["lg"], 2)
	for i in range(64, 140, 8):
		line(i, 60, i, 82, Color("#0099db"), 1)
	T("SOLAR TOWER", 100, 146, P["lg"], 1, 10)
	# habitat
	RR(210, 102, 130, 34, P["lg"], P["w"], 2)
	for x in [232, 262, 292, 322]:
		R(x, 110, 14, 10, P["bl"])
	disc(236, 102, 24, P["w"])
	R(212, 102, 50, 26, P["lg"])
	RR(344, 112, 52, 24, P["gy"], P["w"], 2)
	T("HABITAT", 275, 138, P["lg"], 1, 10)
	# antenna
	R(440, 92, 4, 44, P["lg"])
	disc(442, 90, 12, P["w"])
	R(440, 84, 5, 5, P["r"])
	T("ANTENNA", 442, 138, P["lg"], 1, 10)
	# rover
	R(480, 128, 24, 8, P["lg"])
	R(483, 135, 6, 6, P["sl"])
	R(495, 135, 6, 6, P["sl"])
	# instrument rack with lines to what each one looks at
	for kk in sel.size():
		var i: int = sel[kk]
		var x := 214.0 + kk * 30
		pic(ITEMS[i]["key"], x, 60, 26, 26)
		var fs := String(ITEMS[i]["f"]).split("+")
		var tg := Vector2(-1, -1)
		if "ice_finder" in fs or "shadow_imager" in fs:
			tg = Vector2(548, 142)
		elif "radiation_meter" in fs:
			tg = Vector2(275, 100)
		if tg.x >= 0:
			dline(x + 13, 86, tg.x, tg.y, P["y"] if "radiation_meter" in fs else P["b"], 1, 3)
	if not sel.is_empty():
		T("INSTRUMENT RACK", 214, 48, P["y"], 0, 10)


func paint() -> void:
	R(0, 0, W, H, P["nv"])
	_scene()
	var t := _tot()
	var rows := [["MASS", t["kg"] / 100.0, "%.1f/100 kg" % t["kg"], t["kg"] > 100], ["POWER", t["w"] / 100.0, "%.1f/100 W" % t["w"], t["w"] > 100],
		["DATA", t["mb"] / 3.0, "%.2f/3 Mbps" % t["mb"], t["mb"] > 3]]
	for i in rows.size():
		T(rows[i][0], 10, 8 + i * 18, P["lg"], 0, 11)
		bar(58, 10 + i * 18, 88, 8, rows[i][1], P["r"] if rows[i][3] else P["g"])
		T(rows[i][2], 152, 8 + i * 18, P["r"] if rows[i][3] else P["w"], 0, 11)
	for i in NEEDS.size():
		var ok: bool = t["f"].has(NEEDS[i][0])
		T("%s %s" % ["✔" if ok else "○", NEEDS[i][1]], W - 12, 8 + i * 18, P["g"] if ok else P["r"], 2, 12)
	for i in ITEMS.size():
		var it: Dictionary = ITEMS[i]
		var r := _card(i)
		var on := i in sel
		var x := r.position.x
		var y := r.position.y
		RR(x, y, r.size.x, r.size.y, Color("#265c42") if on else P["nv"], P["g"] if on else P["st"], 3 if on else 2)
		pic(it["key"], x + 5, y + 5, 34, 34, it["n"])
		T(it["n"], x + 44, y + 6, P["y"], 0, 12)
		wrap_text(it["p"], x + 44, y + 22, 74, 12, P["w"], 9.5)
		T(_fname(it["f"]).replace("ice finder + shadow imager", "ice + shadows"), x + 5, y + 46, P["b"], 0, 9.5)
		T("%s kg  %s W  %s Mb/s" % [num(it["kg"]), num(it["w"]), num(it["mb"])], x + 5, y + 64, P["lg"], 0, 9.5)
