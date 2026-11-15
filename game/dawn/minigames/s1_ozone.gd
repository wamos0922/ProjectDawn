extends "res://game/dawn/minigames/mini_game.gd"
## ACT 1 · SCIENTIST · Ozone through the decades. Five Antarctic ozone maps 10 years apart, shuffled.
## Part 1: find the THICKEST ozone. Part 2: find the LARGEST hole. Earth Ozone Lab (UV sensor).
## Numbers: NASA Ozone Watch annual table (lowest daily ozone, largest daily hole). 1994 holds the record
## low of 73 DU. Pictures: assets/minigames/ozone_1984.jpg ... ozone_2024.jpg (NASA Earth Observatory
## "World of Change"). Until they are uploaded, each map is drawn from the numbers.

## y = year, du = lowest ozone that year (Dobson Units), area = largest hole (million km²), date = day of lowest ozone
const OZ := [{"y": 1984, "du": 144, "area": 14.7, "date": "3 Oct"}, {"y": 1994, "du": 73, "area": 25.2, "date": "30 Sep"},
	{"y": 2004, "du": 102, "area": 22.8, "date": "4 Oct"}, {"y": 2014, "du": 114, "area": 24.1, "date": "30 Sep"},
	{"y": 2024, "du": 107, "area": 22.4, "date": "5 Oct"}]
## colour bar sampled from the legend on the NASA Earth Observatory maps (500 DU at the top = thick, blue;
## 100 DU at the bottom = thin, red)
const LEGEND := ["#383b6f", "#3851a3", "#426db2", "#5488c2", "#699fcb", "#80b7d6", "#9acbe3", "#b1daec", "#c8e8ee", "#e2f4f6", "#eff9e0", "#fcfdc4", "#fee597", "#feb867", "#ef7a46", "#d43a28", "#98092c"]
const DU_TOP := 500.0
const DU_BOTTOM := 100.0

var order: Array = []
var sel := 0
var tries := 0
var part := 1
var reveal := false
var rev_area := false
var lock_btn: Button


func _init() -> void:
	title = "OZONE THROUGH THE DECADES"
	goal = "Five NASA maps of the Antarctic ozone hole, ten years apart, in shuffled order. Part 1: slide to the map with the THICKEST ozone and lock it in. Part 2: find the map with the LARGEST hole."


func setup() -> void:
	order = range(OZ.size())
	order.shuffle()
	sel = 0
	tries = 0
	part = 1
	reveal = false
	rev_area = false
	add_slider("MAP", 0, 4, 1, 0, func(x): sel = int(x))
	lock_btn = add_button("LOCK IN: THICKEST OZONE", func(_b): lock())
	say("Slide through the five maps. Compare the colours with the Total Ozone bar on the right.")


func key(kc: int, down: bool) -> bool:
	if kc == KEY_LEFT or kc == KEY_RIGHT:
		if down:
			sel = clampi(sel + (1 if kc == KEY_RIGHT else -1), 0, 4)
		return true
	return false


func lock() -> void:
	var d: Dictionary = OZ[order[sel]]
	tries += 1
	if part == 1:
		var best: Dictionary = OZ[0]
		for o in OZ:
			if o["du"] > best["du"]:
				best = o
		if d["y"] == best["y"]:
			part = 2
			reveal = true
			lock_btn.text = "LOCK IN: LARGEST HOLE"
			say("Part 1 done: %d had the thickest ozone (lowest value %d DU). Part 2: which map has the LARGEST hole?" % [d["y"], d["du"]], "ok")
		else:
			say("Not this one: its ozone gets thinner. Look for the map where the low-ozone area is smallest and the colours stay highest.", "bad")
	else:
		var big: Dictionary = OZ[0]
		for o in OZ:
			if o["area"] > big["area"]:
				big = o
		if d["y"] == big["y"]:
			rev_area = true
			var thick: Dictionary = OZ[0]
			for o in OZ:
				if o["du"] > thick["du"]:
					thick = o
			finish(3 if tries <= 2 else (2 if tries <= 4 else 1),
				"%d had the largest hole: %s million km². Thickest ozone (%d) and largest hole (%d) are different questions. The hole grew while CFC chemicals destroyed ozone, then began to heal after the 1987 Montreal Protocol banned them." % [d["y"], str(d["area"]), thick["y"], d["y"]],
				"NASA Ozone Watch: ozone hole = below 220 Dobson Units. The deepest hole ever was 73 DU on 30 Sep 1994. NASA and NOAA ranked the 2024 hole 7th smallest since recovery began in 1992.")
		else:
			say("Not the largest. Compare the size of the low-ozone region between maps.", "bad")


func _du_col(du: float) -> Color:
	var f := clampf((DU_TOP - du) / (DU_TOP - DU_BOTTOM), 0.0, 1.0) * (LEGEND.size() - 1)
	var i := int(f)
	return Color(LEGEND[i]).lerp(Color(LEGEND[mini(i + 1, LEGEND.size() - 1)]), f - i)


## The map: NASA picture if uploaded, else a polar map drawn from the Ozone Watch numbers.
func _map(d: Dictionary, x: float, y: float, w: float, h: float, big: bool) -> void:
	var tex := _pic("ozone_%d" % d["y"])
	if tex:
		R(x, y, w, h, P["w"])           # the NASA maps have a white background
		var s := minf(w / tex.get_width(), h / tex.get_height())
		var iw := tex.get_width() * s
		var ih := tex.get_height() * s
		draw_texture_rect(tex, Rect2(x + (w - iw) / 2, y + (h - ih) / 2, iw, ih), false)
		return
	var cx := x + w / 2
	var cy := y + h / 2
	var r := minf(w, h) * 0.46
	disc(cx, cy, r, _du_col(330))
	disc(cx, cy, r * 0.8, _du_col(290))
	var hr := r * 0.78 * sqrt(d["area"] / 26.0)
	disc(cx, cy, maxf(hr, r * 0.08), _du_col(220))
	disc(cx, cy, maxf(hr * 0.7, r * 0.05), _du_col(d["du"]))
	ring(cx, cy, r * 0.32, Color(1, 1, 1, 0.5), -1, 1)     # Antarctica outline
	if big:
		T("NASA MAP COMING SOON · drawn from the Ozone Watch numbers", cx, y + h - 18, P["gy"], 1, 10)


func paint() -> void:
	R(0, 0, W, H, P["k"])
	T("Ozone Hole Area", 14, 10, P["w"], 0, 15)
	T("(millions of km²)", 14, 28, P["gy"], 0, 10)
	var cx0 := 40.0
	var cy0 := 62.0
	var ch := 232.0
	for vv in [0, 10, 20, 30]:
		var yy: float = cy0 + ch - vv / 30.0 * ch
		line(cx0, yy, cx0 + 70, yy, P["sl"], 1)
		T(str(vv), cx0 - 6, yy - 6, P["lg"], 2, 10)
	line(cx0, cy0, cx0, cy0 + ch, P["st"], 1.2)
	if rev_area:
		for o in OZ:
			var px: float = cx0 + 8 + (o["y"] - 1984) / 40.0 * 62
			var py: float = cy0 + ch - o["area"] / 30.0 * ch
			R(px - 3, py - 3, 6, 6, P["y"])
			T(str(o["y"]), px + 5, py - 5, P["lg"], 0, 9)
	elif reveal:
		T("area appears after Part 2", 14, 46, P["gy"], 0, 9)
	T("1984", cx0 - 12, cy0 + ch + 6, P["lg"], 0, 9)
	T("2024", cx0 + 44, cy0 + ch + 6, P["lg"], 0, 9)
	# main map
	var bx := 130.0
	var by := 34.0
	var bw := 390.0
	var bh := 256.0
	var d: Dictionary = OZ[order[sel]]
	RR(bx, by, bw, bh, P["k"], P["sl"], 2)
	_map(d, bx + 2, by + 2, bw - 4, bh - 4, true)
	# filmstrip
	for i in order.size():
		var e: Dictionary = OZ[order[i]]
		var fx := bx + i * 79
		var fy := by + bh + 8
		RR(fx, fy, 74, 54, P["k"], P["y"] if i == sel else P["sl"], 3 if i == sel else 2)
		_map(e, fx + 2, fy + 2, 70, 50, false)
		var lab := str(e["y"]) if reveal else char(65 + i)
		R(fx + 37 - TW(lab, 13) / 2 - 3, fy + 36, TW(lab, 13) + 6, 16, P["k"])
		T(lab, fx + 37, fy + 37, P["y"] if i == sel else P["w"], 1, 13)
	# title top right
	T("%s %d" % [d["date"], d["y"]] if reveal else "MAP %s" % char(65 + sel), W - 14, 10, P["w"], 2, 22)
	T("lowest ozone that year: %d DU" % d["du"] if reveal else "year hidden", W - 14, 38, P["gy"], 2, 11)
	# colour bar
	var lx := 556.0
	var ly := 96.0
	var lh := 200.0
	T("Total Ozone", W - 44, 56, P["w"], 1, 13)
	T("(Dobson Units)", W - 44, 72, P["gy"], 1, 10)
	var bands := 28
	for i in bands:
		R(lx, ly + i * lh / bands, 16, lh / bands + 1, _du_col(DU_TOP - (DU_TOP - DU_BOTTOM) * i / bands))
	RR(lx, ly, 16, lh, null, P["w"], 1)
	for vv in [100, 200, 300, 400, 500]:
		var yy: float = ly + lh - (vv - DU_BOTTOM) / (DU_TOP - DU_BOTTOM) * lh
		line(lx + 16, yy, lx + 21, yy, P["lg"], 1)
		T(str(vv), lx + 25, yy - 6, P["lg"], 0, 10)
	var y220 := ly + lh - (220.0 - DU_BOTTOM) / (DU_TOP - DU_BOTTOM) * lh
	line(lx - 6, y220, lx + 22, y220, P["y"], 2)
	T("hole < 220 DU", lx - 8, y220 - 14, P["y"], 2, 10)
	T("NASA EO colours", W - 44, 306, P["gy"], 1, 9)
