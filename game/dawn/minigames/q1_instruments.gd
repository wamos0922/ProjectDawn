extends "res://game/dawn/minigames/mini_game.gd"
## ACT 1 · QUARTERMASTER · Pick the rocket instruments. Load only instruments that answer the
## mission question (UV and ozone) and fit mass, power and data. Earth Comms room.
## Data: team instruments.csv (NASA fact sheets); rocket payload 454 kg (platforms.csv);
## 100 W and 1 Mbps are scaled game rules. Photos: assets/minigames/<key>.jpg (omi, marci, crater, lend, hirise, tega).

const ITEMS := [
	{"key": "omi", "n": "OMI", "p": "Ozone mapper", "f": "ozone_mapper", "kg": 65.0, "w": 66.0, "mb": 0.8, "why": "measures ozone and UV"},
	{"key": "marci", "n": "MARCI-UV", "p": "UV camera", "f": "ozone_mapper", "kg": 0.481, "w": 5.0, "mb": 0.0718, "why": "maps ozone with UV light"},
	{"key": "crater", "n": "CRaTER", "p": "Radiation meter", "f": "radiation_meter", "kg": 5.53, "w": 6.66, "mb": 0.0891, "why": "measures cosmic rays, not sunlight UV"},
	{"key": "lend", "n": "LEND", "p": "Neutron counter", "f": "ice_finder", "kg": 26.3, "w": 13.0, "mb": 0.0029, "why": "finds hidden hydrogen and ice"},
	{"key": "hirise", "n": "HiRISE", "p": "Big camera", "f": "terrain_mapper", "kg": 65.0, "w": 60.0, "mb": 4.0, "why": "photographs terrain in detail"},
	{"key": "tega", "n": "TEGA", "p": "Soil oven", "f": "chemistry_lab", "kg": 5.7, "w": 13.0, "mb": 0.01, "why": "bakes soil to find chemicals"}]
const MAX_KG := 454.0
const MAX_W := 100.0
const MAX_MB := 1.0

var loaded: Array = []          # indexes into ITEMS
var wrong := 0


func _init() -> void:
	title = "PICK THE ROCKET INSTRUMENTS"
	goal = "The sounding rocket flies to measure UV and ozone. Click instrument photos to load them into the payload bay, then LAUNCH. It must answer the mission question AND fit the mass, power and data limits."


func setup() -> void:
	loaded = []
	wrong = 0
	add_button("LAUNCH", func(_b): launch())
	say("Click a photo to load or unload it.")


func _tot() -> Dictionary:
	var o := {"kg": 0.0, "w": 0.0, "mb": 0.0}
	for i in loaded:
		o["kg"] += ITEMS[i]["kg"]
		o["w"] += ITEMS[i]["w"]
		o["mb"] += ITEMS[i]["mb"]
	return o


func launch() -> void:
	var t := _tot()
	if loaded.is_empty():
		say("The bay is empty. What will measure the UV?", "bad")
		return
	for i in loaded:
		var it: Dictionary = ITEMS[i]
		if it["f"] != "ozone_mapper":
			wrong += 1
			say("CERES: %s (%s) %s. It doesn't answer our question about UV and ozone." % [it["p"], it["n"], it["why"]], "bad")
			return
	if t["kg"] > MAX_KG:
		wrong += 1
		say("%d kg is more than the 454 kg the rocket can lift." % roundi(t["kg"]), "bad")
		return
	if t["w"] > MAX_W:
		wrong += 1
		say("%d W is more than the 100 W the rocket can supply." % roundi(t["w"]), "bad")
		return
	if t["mb"] > MAX_MB:
		wrong += 1
		say("%.2f Mbps is more than the 1 Mbps radio link can send." % t["mb"], "bad")
		return
	finish(3 if wrong == 0 else (2 if wrong == 1 else 1),
		"Only ozone instruments flew (%.1f kg, %d W, %.2f Mbps). Instruments are chosen to answer the mission's question and must fit mass, power and data limits." % [t["kg"], roundi(t["w"]), t["mb"]],
		"NASA sounding rockets fly short up-and-down science trips. OMI flies on NASA Aura and maps ozone every day.")


func _card(i: int) -> Rect2:
	return Rect2(10 + (i % 3) * 140, 52 + floori(i / 3.0) * 150, 134, 144)


func press(q: Vector2) -> void:
	for i in ITEMS.size():
		if _card(i).has_point(q):
			var it: Dictionary = ITEMS[i]
			if i in loaded:
				loaded.erase(i)
			else:
				loaded.append(i)
			say("%s (%s): %s. %s kg, %s W, %s Mbps." % [it["p"], it["n"], it["why"], num(it["kg"]), num(it["w"]), num(it["mb"])])


func paint() -> void:
	R(0, 0, W, H, P["k"])
	var t := _tot()
	var rows := [["MASS", t["kg"] / MAX_KG, "%.1f / 454 kg" % t["kg"], t["kg"] > MAX_KG],
		["POWER", t["w"] / MAX_W, "%d / 100 W" % roundi(t["w"]), t["w"] > MAX_W],
		["DATA", t["mb"] / MAX_MB, "%.2f / 1 Mbps" % t["mb"], t["mb"] > MAX_MB]]
	for i in rows.size():
		var x := 10.0 + i * 142
		T(rows[i][0], x, 8, P["lg"], 0, 11)
		bar(x + 46, 10, 86, 9, rows[i][1], P["r"] if rows[i][3] else P["g"])
		T(rows[i][2], x, 24, P["r"] if rows[i][3] else P["w"], 0, 11)
	for i in ITEMS.size():
		var it: Dictionary = ITEMS[i]
		var r := _card(i)
		var on := i in loaded
		RR(r.position.x, r.position.y, r.size.x, r.size.y, Color("#265c42") if on else P["nv"], P["g"] if on else P["st"], 3 if on else 2)
		pic(it["key"], r.position.x + 5, r.position.y + 5, r.size.x - 10, 70, it["n"])
		T(it["n"], r.position.x + 7, r.position.y + 80, P["y"], 0, 14)
		T(it["p"], r.position.x + 7, r.position.y + 97, P["w"], 0, 11)
		T("%s kg · %s W" % [num(it["kg"]), num(it["w"])], r.position.x + 7, r.position.y + 112, P["lg"], 0, 10.5)
		T("%s Mbps" % num(it["mb"]), r.position.x + 7, r.position.y + 126, P["b"], 0, 10.5)
		if on:
			T("LOADED", r.end.x - 8, r.position.y + 80, P["g"], 2, 11)
	# rocket
	var rx := 520.0
	RR(rx, 40, 60, 220, Color("#c0cbdc"), P["w"], 2)
	R(rx + 10, 10, 40, 32, P["r"])
	R(rx - 12, 214, 16, 50, P["r"])
	R(rx + 56, 214, 16, 50, P["r"])
	R(rx + 8, 258, 44, 18, P["gy"])
	RR(rx + 4, 92, 52, 98, P["k"], P["y"], 2)
	T("PAYLOAD", rx + 30, 96, P["y"], 1, 9)
	for kk in loaded.size():
		var it2: Dictionary = ITEMS[loaded[kk]]
		pic(it2["key"], rx + 8 + (kk % 2) * 22, 114 + floori(kk / 2.0) * 26, 20, 24)
	T("SOUNDING", rx + 30, 282, P["lg"], 1, 10)
	T("ROCKET", rx + 30, 295, P["lg"], 1, 10)
