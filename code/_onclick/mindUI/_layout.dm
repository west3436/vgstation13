// Layout containers and anchors for mindUI.
// Containers compute element offsets so UIs don't hand-pack pixel positions.


////////////////////////////////////////////////////////////////////
//																  //
//						 LAYOUT CONTAINERS						  //
//																  //
////////////////////////////////////////////////////////////////////

// Each layout owns a list of elements and rewrites their offset_x/offset_y in Apply().

/datum/mindui_layout
	var/datum/mind_ui/ui
	var/list/items = list()
	var/spacing = 4

/datum/mindui_layout/New(datum/mind_ui/U)
	ui = U

/datum/mindui_layout/proc/Add(obj/abstract/mind_ui_element/e)
	items += e

/datum/mindui_layout/proc/Apply()
	return

/datum/mindui_layout/Destroy()
	ui = null
	items = null
	return ..()

// Returns the element's icon height (or width) in pixels
/datum/mindui_layout/proc/_element_height(obj/abstract/mind_ui_element/e)
	if (!e || !e.icon)
		return 32
	var/icon/I = new(e.icon, e.icon_state)
	if (!I)
		return 32
	var/h = I.Height()
	if (!h)
		return 32
	return h

/datum/mindui_layout/proc/_element_width(obj/abstract/mind_ui_element/e)
	if (!e || !e.icon)
		return 32
	var/icon/I = new(e.icon, e.icon_state)
	if (!I)
		return 32
	var/w = I.Width()
	if (!w)
		return 32
	return w

// Vertical stack: items flow top-to-bottom with spacing between them.
/datum/mindui_layout/vstack
	var/anchor_offset_x = 0
	var/anchor_offset_y = 0

/datum/mindui_layout/vstack/Apply()
	var/cursor = anchor_offset_y
	for (var/obj/abstract/mind_ui_element/e in items)
		e.offset_x = anchor_offset_x
		e.offset_y = cursor
		cursor += _element_height(e) + spacing

// Horizontal stack: items flow left-to-right with spacing between them.
/datum/mindui_layout/hstack
	var/anchor_offset_x = 0
	var/anchor_offset_y = 0

/datum/mindui_layout/hstack/Apply()
	var/cursor = anchor_offset_x
	for (var/obj/abstract/mind_ui_element/e in items)
		e.offset_y = anchor_offset_y
		e.offset_x = cursor
		cursor += _element_width(e) + spacing

// Fixed-cell grid: items fill rows then wrap to the next row at `cols`.
/datum/mindui_layout/grid
	var/cols = 4
	var/anchor_offset_x = 0
	var/anchor_offset_y = 0
	var/cell_width = 32
	var/cell_height = 32

/datum/mindui_layout/grid/Apply()
	var/i = 0
	for (var/obj/abstract/mind_ui_element/e in items)
		var/col = i % cols
		var/row = (i - col) / cols
		e.offset_x = anchor_offset_x + col * (cell_width + spacing)
		e.offset_y = anchor_offset_y + row * (cell_height + spacing)
		i++


////////////////////////////////////////////////////////////////////
//																  //
//							 ANCHORS							  //
//																  //
////////////////////////////////////////////////////////////////////

// Walks elements and resolves anchor_to relationships in a single pass.
// Chained anchors (A->B->C) require multiple ResolveAnchors() calls to stabilize.
/datum/mind_ui/proc/ResolveAnchors()
	for (var/obj/abstract/mind_ui_element/e in elements)
		if (!e.anchor_to)
			continue
		var/obj/abstract/mind_ui_element/target = e.anchor_to
		if (!(target in elements))
			continue
		var/icon/I = (target.icon ? new(target.icon, target.icon_state) : null)
		var/tw = (I ? I.Width() : 32)
		var/th = (I ? I.Height() : 32)
		if (!tw) tw = 32
		if (!th) th = 32
		switch (e.anchor_side)
			if ("below")
				e.offset_x = target.offset_x
				e.offset_y = target.offset_y + th
			if ("above")
				e.offset_x = target.offset_x
				e.offset_y = target.offset_y - th
			if ("right")
				e.offset_x = target.offset_x + tw
				e.offset_y = target.offset_y
			if ("left")
				e.offset_x = target.offset_x - tw
				e.offset_y = target.offset_y
