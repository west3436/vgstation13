// Procedural icon generation and theming for mindUI.
// Build icons (panels, gradients, & circles) at runtime instead of authoring a DMI per shape.
// Themes provide named color palettes.


////////////////////////////////////////////////////////////////////
//																  //
//						 PANELS / SHAPES						  //
//																  //
////////////////////////////////////////////////////////////////////

/proc/mindui_gen_panel(w, h, fill = "#202020", border = null, corner_radius = 0, alpha = 255)
	if (w <= 0 || h <= 0)
		CRASH("mindui_gen_panel: invalid size [w]x[h]")
	var/icon/I = new /icon('icons/effects/uristrunes.dmi', "blank")
	I.Scale(w, h)
	// "blank" is fully transparent; fill it so the panel actually has pixels.
	var/fill_rgba = (alpha < 255) ? "[fill][copytext(rgb(0,0,0,alpha), 8)]" : fill
	I.DrawBox(fill_rgba, 1, 1, w, h)
	if (border)
		I.DrawBox(border, 1, 1, w, 1)
		I.DrawBox(border, 1, h, w, h)
		I.DrawBox(border, 1, 1, 1, h)
		I.DrawBox(border, w, 1, w, h)
	if (corner_radius > 0)
		// BYOND has no rounded-rect primitive; knock out pixels outside the corner radius.
		var/transparent = rgb(0, 0, 0, 0)
		for (var/cx in 1 to corner_radius)
			for (var/cy in 1 to corner_radius)
				if ((cx * cx + cy * cy) > (corner_radius * corner_radius))
					I.DrawBox(transparent, cx, cy, cx, cy)
					I.DrawBox(transparent, w - cx + 1, cy, w - cx + 1, cy)
					I.DrawBox(transparent, cx, h - cy + 1, cx, h - cy + 1)
					I.DrawBox(transparent, w - cx + 1, h - cy + 1, w - cx + 1, h - cy + 1)
	return I

/proc/mindui_gen_gradient(w, h, color_top = "#FFFFFF", color_bottom = "#000000")
	if (w <= 0 || h <= 0)
		CRASH("mindui_gen_gradient: invalid size [w]x[h]")
	var/icon/I = new /icon('icons/effects/uristrunes.dmi', "blank")
	I.Scale(w, h)
	var/r1 = hex2num(copytext(color_top, 2, 4))
	var/g1 = hex2num(copytext(color_top, 4, 6))
	var/b1 = hex2num(copytext(color_top, 6, 8))
	var/r2 = hex2num(copytext(color_bottom, 2, 4))
	var/g2 = hex2num(copytext(color_bottom, 4, 6))
	var/b2 = hex2num(copytext(color_bottom, 6, 8))
	// y=1 is the bottom row in BYOND icon coordinates.
	for (var/y in 1 to h)
		var/frac = (h > 1) ? ((y - 1) / (h - 1)) : 0
		var/r = round(r2 + (r1 - r2) * frac)
		var/g = round(g2 + (g1 - g2) * frac)
		var/b = round(b2 + (b1 - b2) * frac)
		I.DrawBox(rgb(r, g, b), 1, y, w, y)
	return I

/proc/mindui_gen_circle(diameter, fill = "#FFFFFF")
	if (diameter <= 0)
		CRASH("mindui_gen_circle: invalid diameter [diameter]")
	var/icon/I = new /icon('icons/effects/uristrunes.dmi', "blank")
	I.Scale(diameter, diameter)
	I.DrawBox(fill, 1, 1, diameter, diameter)
	var/radius = diameter / 2
	var/center = (diameter + 1) / 2
	var/transparent = rgb(0, 0, 0, 0)
	for (var/x in 1 to diameter)
		for (var/y in 1 to diameter)
			var/dx = x - center
			var/dy = y - center
			if ((dx * dx + dy * dy) > (radius * radius))
				I.DrawBox(transparent, x, y, x, y)
	return I

////////////////////////////////////////////////////////////////////
//																  //
//							  THEMES							  //
//																  //
////////////////////////////////////////////////////////////////////

var/global/list/mindui_theme_default = list(
	"background" = "#202020",
	"border"     = "#404040",
	"text"       = "#FFFFFF",
	"hover"      = "#606060",
)

var/global/list/mindui_theme_cult = list(
	"background" = "#1a0405",
	"border"     = "#8b0000",
	"text"       = "#ffeeee",
	"hover"      = "#bb1111",
)

/datum/mind_ui/proc/GetThemeColor(key)
	var/list/palette = global.vars["mindui_theme_[theme]"]
	if (!palette)
		return "#FFFFFF"
	var/color = palette[key]
	if (!color)
		return "#FFFFFF"
	return color
