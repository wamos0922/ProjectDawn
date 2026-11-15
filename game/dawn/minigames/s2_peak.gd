extends "res://game/dawn/minigames/mini_game.gd"
## ACT 2 · SCIENTIST · Find the peak. Round 1 (emission): click the tallest peak of the LCROSS glow,
## then the substance with the nearest wavelength. Round 2 (absorbance): click the three water
## peaks in the infrared. Moon Science Lab: this is how the crew finds the ice.
## Real: LCROSS saw OH at ~308 nm and H2O+ at 619 nm, plus sodium and silver (Colaprete et al. 2010);
## silver 328.068 / 338.289 nm (NIST); water absorption near 1.4, 1.85 µm (LCROSS) and 2.8–3.0 µm (M3).
## Game: curve shapes and heights are simplified.

const LINES := [{"n": "OH", "nm": "hydroxyl", "l": 308.0, "a": 1.0, "s": 3.5}, {"n": "Ag", "nm": "silver", "l": 328.07, "a": 0.34, "s": 2.2},
	{"n": "Ag", "nm": "silver", "l": 338.29, "a": 0.30, "s": 2.2}, {"n": "Na", "nm": "sodium", "l": 589.0, "a": 0.55, "s": 3.0},
	{"n": "H2O+", "nm": "ionized water", "l": 619.0, "a": 0.40, "s": 3.5}]
const GX := 70.0
const GY := 104.0
const GW := 370.0
const GH := 186.0
const ABS := [1.4, 1.85, 2.9]

var round_ := 1
var stage := "peak"
var mist := 0
var found: Array = []
var mark := -1.0
var noise: Array = []


func _init() -> void:
	title = "FIND THE PEAK"
	goal = "Round 1: LCROSS hit the crater and the cloud GLOWED. Click the tallest peak, read its wavelength, then click the substance whose number is nearest. Round 2: water soaks up infrared light. Click all three absorbance peaks."


func setup() -> void:
	round_ = 1
	stage = "peak"
	mist = 0
	found = []
	mark = -1.0
	noise = []
	for j in 400:
		noise.append(randf())
	say("Move the cursor along the graph. Click the tallest peak.")


func _range() -> Vector2:
	return Vector2(270, 650) if round_ == 1 else Vector2(1.0, 3.0)


func _val(l: float) -> float:
	if round_ == 1:
		var vv := 0.05
		for L in LINES:
			vv += L["a"] * exp(-pow(l - L["l"], 2) / (2 * L["s"] * L["s"]))
		return vv
	return 0.1 + 0.5 * exp(-pow(l - 1.4, 2) / (2 * 0.045 * 0.045)) + 0.42 * exp(-pow(l - 1.85, 2) / (2 * 0.055 * 0.055)) + 0.78 * exp(-pow(l - 2.9, 2) / (2 * 0.14 * 0.14))


func _x_to_l(x: float) -> float:
	var r := _range()
	return r.x + (x - GX) / GW * (r.y - r.x)


func _l_to_x(l: float) -> float:
	var r := _range()
	return GX + (l - r.x) / (r.y - r.x) * GW


func _row(i: int) -> Rect2:
	return Rect2(462, 150 + i * 34, 170, 30)


func press(q: Vector2) -> void:
	if round_ == 1 and stage == "pick":
		for i in LINES.size():
			if _row(i).has_point(q):
				_pick(i)
		return
	if q.x < GX or q.x > GX + GW or q.y < GY or q.y > GY + GH:
		return
	var l := _x_to_l(q.x)
	if round_ == 1:
		if stage != "peak":
			return
		if absf(l - 308) <= 7:
			stage = "pick"
			mark = _l_to_x(308)
			say("Peak at %d nm. Which substance glows nearest that number? Click a row in the table." % roundi(l), "ok")
		else:
			mist += 1
			say("That's %d nm. There's a taller peak." % roundi(l), "bad")
	else:
		var hit := -1.0
		for d in ABS:
			if absf(l - d) < (0.22 if d > 2 else 0.06) and not d in found:
				hit = d
		if hit > 0:
			found.append(hit)
			say(("Absorbance peak at %s µm: water vapor soaks up this light (LCROSS plume)." % str(hit)) if hit < 2 else "Broad peak at 2.8–3.0 µm: OH / water in the Moon's soil (M3).", "ok")
			if found.size() == 3:
				finish(3 if mist == 0 else (2 if mist <= 2 else 1),
					"Glowing gas shows PEAKS in brightness at its own wavelengths (OH at 308 nm, a piece of water broken by sunlight). Absorbing material shows PEAKS in absorbance where it soaks up light (water near 1.4, 1.85 and 2.8–3.0 µm). Two kinds of fingerprint, one answer: water.",
					"LCROSS (2009) saw OH glowing in its visible spectrometer and water absorption in its infrared spectrometer; M3 (Chandrayaan-1) saw OH/water absorption near 3 µm.")
		else:
			mist += 1
			say("Not a peak. Look for where the absorbance line rises.", "bad")


func _pick(i: int) -> void:
	var L: Dictionary = LINES[i]
	if i == 0:
		round_ = 2
		stage = "abs"
		mark = -1.0
		say("OH! A piece of water, split by sunlight. Round 2: now the infrared graph. Click all three absorbance peaks.", "ok")
	else:
		mist += 1
		say("%s (%s) glows at %s nm, which is farther from 308 nm than OH. The nearest number wins." % [L["n"], L["nm"], num(L["l"])], "bad")


func paint() -> void:
	R(0, 0, W, H, P["k"])
	var r1 := round_ == 1
	T("ROUND 1 · EMISSION: glowing gas makes PEAKS" if r1 else "ROUND 2 · ABSORBANCE: water soaks up light, so PEAKS again", 14, 10, P["y"], 0, 16)
	wrap_text("Left axis (y) = how bright the glow is. Bottom axis (x) = wavelength, the \"colour\" of the light in nanometres (nm). Each chemical glows at its own wavelengths." if r1
		else "Left axis (y) = ABSORBANCE: how much light the material soaks up (higher = more absorbed). Bottom axis (x) = wavelength in micrometres (µm), infrared light.", 14, 34, 610, 16, P["lg"], 12)
	RR(GX - 2, GY - 2, GW + 4, GH + 4, Color("#0b0913"), P["st"], 2)
	var rg := _range()
	var top := 1.15 if r1 else 0.95
	var col: Color = P["b"] if r1 else P["g"]
	var pts := []
	for x in range(0, int(GW) + 1, 2):
		var l := rg.x + x / GW * (rg.y - rg.x)
		var vv: float = _val(l) + (noise[x] - 0.5) * 0.015
		var y := clampf(GY + GH - vv / top * GH, GY, GY + GH)
		R(GX + x, y, 2, GY + GH - y, Color(col, 0.22))
		pts.append([GX + x, y])
	poly(pts, col, 2)
	for tk in ([300, 400, 500, 600] if r1 else [1.0, 1.5, 2.0, 2.5, 3.0]):
		var x := _l_to_x(tk)
		line(x, GY + GH, x, GY + GH + 5, P["lg"], 1)
		T(str(tk) if r1 else "%.1f" % tk, x, GY + GH + 7, P["lg"], 1, 11)
	T("Wavelength (nm)  →  longer wavelength" if r1 else "Wavelength (µm)  →  longer wavelength", GX + GW / 2, GY + GH + 24, P["w"], 1, 13)
	T("BRIGHT ↑" if r1 else "ABSORBED ↑", GX - 6, GY + 2, P["gy"], 2, 10)
	T("low", GX - 8, GY + GH - 12, P["gy"], 2, 10)
	if mark > 0:
		line(mark, GY, mark, GY + GH, P["y"], 1.5)
	for d in found:
		var x := _l_to_x(d)
		line(x, GY, x, GY + GH, P["g"], 1.5)
		T("%s µm" % str(d), x, GY + 4, P["g"], 1, 11)
	if started and mouse.x > GX and mouse.x < GX + GW and mouse.y > GY and mouse.y < GY + GH:
		line(mouse.x, GY, mouse.x, GY + GH, Color(1, 1, 1, 0.4), 1)
		var l := _x_to_l(mouse.x)
		var bx := minf(mouse.x + 6, GX + GW - 70)
		RR(bx, GY + 4, 66, 20, Color("#0b0913"), P["y"], 1)
		T("%d nm" % roundi(l) if r1 else "%.2f µm" % l, bx + 5, GY + 7, P["y"], 0, 12)
	if r1:
		T("SUBSTANCES THAT GLOW", 462, 128, P["w"], 0, 12)
		for i in LINES.size():
			var L: Dictionary = LINES[i]
			var rr := _row(i)
			var on := stage == "pick"
			RR(rr.position.x, rr.position.y, rr.size.x, rr.size.y, P["nv"] if on else Color("#181425"), P["b"] if on else P["sl"], 2)
			T("%s  %s nm" % [L["n"], num(L["l"])], rr.position.x + 10, rr.position.y + 8, P["w"] if on else P["gy"], 0, 13)
			if String(L["nm"]).length() < 9:
				T(L["nm"], rr.end.x - 8, rr.position.y + 10, P["gy"], 2, 10)
		T("Click the nearest number" if stage == "pick" else "Find the peak first", 462, 324, P["y"] if stage == "pick" else P["gy"], 0, 11)
	else:
		T("WHAT THE PEAKS MEAN", 462, 128, P["w"], 0, 12)
		var lab := [[1.4, "1.4 µm · water vapor (LCROSS plume)"], [1.85, "1.85 µm · water vapor (LCROSS plume)"], [2.9, "2.8–3.0 µm · OH / water in soil (M3)"]]
		for i in lab.size():
			var ok: bool = lab[i][0] in found
			RR(462, 150 + i * 50, 170, 44, Color("#265c42") if ok else Color("#181425"), P["g"] if ok else P["sl"], 2)
			wrap_text(lab[i][1] if ok else "? ? ?", 472, 157 + i * 50, 150, 14, P["w"] if ok else P["gy"], 11)
		T("found %d/3" % found.size(), 462, 306, P["y"], 0, 13)
	T("mistakes %d" % mist, W - 12, H - 20, P["gy"], 2, 11)
