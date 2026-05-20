// Reusable UI component elements for mindUI

////////////////////////////////////////////////////////////////////
//																  //
//							 BUTTON								  //
//																  //
////////////////////////////////////////////////////////////////////

/obj/abstract/mind_ui_element/hoverable/button
	layer = MIND_UI_BUTTON
	var/callback/callback
	var/click_sound

/obj/abstract/mind_ui_element/hoverable/button/Click()
	if (click_sound)
		var/mob/M = GetUser()
		if (M)
			playsound(M, click_sound, 30)
	if (callback)
		callback.invoke()

/obj/abstract/mind_ui_element/hoverable/button/Destroy()
	callback = null
	return ..()

// Create and attach a button to this UI in one call.
/datum/mind_ui/proc/AddButton(icon_path, state, off_x, off_y, callback/cb, sound = null)
	var/obj/abstract/mind_ui_element/hoverable/button/b = new(null, src)
	b.icon = icon_path
	b.icon_state = state
	b.base_icon_state = state
	b.offset_x = off_x
	b.offset_y = off_y
	b.callback = cb
	b.click_sound = sound
	elements += b
	return b


////////////////////////////////////////////////////////////////////
//																  //
//							 CANVAS								  //
//																  //
////////////////////////////////////////////////////////////////////

// Pixel-drawing surface
// Wraps a procedurally-built /icon so consumers can plot/box onto it without needing a pre-authored DMI per visualization.
/obj/abstract/mind_ui_element/canvas
	mouse_opacity = 0
	var/canvas_width = 256
	var/canvas_height = 256
	var/icon/canvas_icon

/obj/abstract/mind_ui_element/canvas/New(turf/loc, var/datum/mind_ui/P)
	..()
	canvas_icon = mindui_gen_panel(canvas_width, canvas_height, "#000000", null, 0, 0)
	if (canvas_icon)
		icon = canvas_icon

/obj/abstract/mind_ui_element/canvas/proc/DrawBox(x1, y1, x2, y2, color)
	if (!canvas_icon)
		return
	canvas_icon.DrawBox(color, x1, y1, x2, y2)
	icon = canvas_icon  // reassign to force the client to re-send the icon blob

/obj/abstract/mind_ui_element/canvas/proc/Plot(x, y, color)
	if (!canvas_icon)
		return
	canvas_icon.DrawBox(color, x, y, x, y)
	icon = canvas_icon

/obj/abstract/mind_ui_element/canvas/proc/Clear()
	if (!canvas_icon)
		return
	canvas_icon = mindui_gen_panel(canvas_width, canvas_height, "#000000", null, 0, 0)
	icon = canvas_icon

/obj/abstract/mind_ui_element/canvas/Destroy()
	canvas_icon = null
	return ..()


////////////////////////////////////////////////////////////////////
//																  //
//							CHECKBOX							  //
//																  //
////////////////////////////////////////////////////////////////////

// Two-state toggle. Click flips `checked` and invokes `on_toggle.invoke(new_state)`; visual state driven by `on_state` / `off_state` icon_states, applied by UpdateIcon.
/obj/abstract/mind_ui_element/hoverable/checkbox
	layer = MIND_UI_BUTTON
	var/checked = FALSE
	var/on_state = ""   // icon_state when checked=TRUE
	var/off_state = ""  // icon_state when checked=FALSE
	var/callback/on_toggle

/obj/abstract/mind_ui_element/hoverable/checkbox/Click()
	checked = !checked
	UpdateIcon()
	if (on_toggle)
		on_toggle.invoke(checked)

/obj/abstract/mind_ui_element/hoverable/checkbox/UpdateIcon(var/appear = FALSE)
	icon_state = checked ? on_state : off_state

/obj/abstract/mind_ui_element/hoverable/checkbox/Destroy()
	on_toggle = null
	return ..()


////////////////////////////////////////////////////////////////////
//																  //
//							DROPDOWN							  //
//																  //
////////////////////////////////////////////////////////////////////

// Click-to-expand dropdown
// Keeps option rows out of the parent UI tree until opened so we don't pay layout/render cost for closed pickers.

/obj/abstract/mind_ui_element/hoverable/dropdown
	layer = MIND_UI_BUTTON
	var/list/options = list()
	var/selected_index = 1
	var/is_open = FALSE
	var/option_row_height = 32
	var/callback/on_select
	var/list/option_elements = list()  // child rows we spawn into parent.elements when open

/obj/abstract/mind_ui_element/hoverable/dropdown/Click()
	if (is_open)
		Close()
	else
		Open()

/obj/abstract/mind_ui_element/hoverable/dropdown/proc/Open()
	if (is_open)
		return
	is_open = TRUE
	if (!parent)
		return
	for (var/i in 1 to options.len)
		var/obj/abstract/mind_ui_element/hoverable/dropdown_option/row = new(null, parent)
		row.icon = icon
		row.parent_dropdown = src
		row.option_index = i
		row.option_value = options[i]
		row.offset_x = offset_x
		// Options stack vertically beneath the dropdown; y decreases as i grows.
		row.offset_y = offset_y - (i * option_row_height)
		row.UpdateUIScreenLoc()
		parent.elements += row
		option_elements += row

/obj/abstract/mind_ui_element/hoverable/dropdown/proc/Close()
	if (!is_open)
		return
	is_open = FALSE
	if (parent)
		for (var/obj/abstract/mind_ui_element/hoverable/dropdown_option/row in option_elements)
			parent.elements -= row
			qdel(row)
	option_elements.Cut()

// Set the selection directly without going through Click(); used by tests.
/obj/abstract/mind_ui_element/hoverable/dropdown/proc/Select(index)
	if (index < 1 || index > options.len)
		return
	selected_index = index
	if (on_select)
		on_select.invoke(options[index])
	UpdateIcon()
	Close()

/obj/abstract/mind_ui_element/hoverable/dropdown/UpdateIcon(var/appear = FALSE)
	if (options.len && selected_index >= 1 && selected_index <= options.len)
		// Callers can author DMI states keyed by option value to swap on selection.
		icon_state = "[base_icon_state]-[options[selected_index]]"
	else
		icon_state = base_icon_state

/obj/abstract/mind_ui_element/hoverable/dropdown/Destroy()
	Close()
	on_select = null
	options = null
	option_elements = null
	return ..()

// Option-row element: a child of the dropdown's parent UI, not the dropdown itself.
/obj/abstract/mind_ui_element/hoverable/dropdown_option
	layer = MIND_UI_BUTTON
	var/obj/abstract/mind_ui_element/hoverable/dropdown/parent_dropdown
	var/option_index = 0
	var/option_value = null

/obj/abstract/mind_ui_element/hoverable/dropdown_option/Click()
	if (parent_dropdown)
		parent_dropdown.Select(option_index)

/obj/abstract/mind_ui_element/hoverable/dropdown_option/Destroy()
	parent_dropdown = null
	return ..()


////////////////////////////////////////////////////////////////////
//																  //
//							  GAUGE								  //
//																  //
////////////////////////////////////////////////////////////////////

// Generalized fill-bar
// Subclasses override ReadValue() / ReadMax() (or set value_proc / max_proc callbacks).
// UpdateIcon rebuilds the overlay stack with a fill image scaled to (cur/max) along the configured direction.

/obj/abstract/mind_ui_element/gauge
	var/direction = "vertical"   // or "horizontal"
	var/gauge_length = 200
	var/gauge_width = 18
	var/icon/fill_icon
	var/icon/cover_icon
	var/callback/value_proc  // optional; overrides ReadValue when set
	var/callback/max_proc    // optional; overrides ReadMax when set
	var/show_count = TRUE
	var/count_color = "#FFFFFF"

/obj/abstract/mind_ui_element/gauge/proc/ReadValue()
	if (value_proc)
		return value_proc.invoke()
	return 0

/obj/abstract/mind_ui_element/gauge/proc/ReadMax()
	if (max_proc)
		return max_proc.invoke()
	return 0

/obj/abstract/mind_ui_element/gauge/UpdateIcon(var/appear = FALSE)
	var/cur = ReadValue()
	var/max = ReadMax()
	if (!max)
		return  // avoid divide-by-zero; nothing to render
	overlays.len = 0
	if (fill_icon)
		var/image/fill = image(fill_icon, src)
		var/matrix/m = matrix()
		var/ratio = cur / max
		if (direction == "vertical")
			m.Scale(1, ratio)
			fill.transform = m
			fill.pixel_y = round(-gauge_length/2 + (gauge_length/2) * ratio)
		else
			m.Scale(ratio, 1)
			fill.transform = m
			fill.pixel_x = round(-gauge_length/2 + (gauge_length/2) * ratio)
		overlays += fill
	if (cover_icon)
		overlays += image(cover_icon, src)
	if (show_count)
		overlays += String2Image("[round(cur)]", _color = count_color)

/obj/abstract/mind_ui_element/gauge/Destroy()
	value_proc = null
	max_proc = null
	return ..()


////////////////////////////////////////////////////////////////////
//																  //
//						   RADIO GROUP							  //
//																  //
////////////////////////////////////////////////////////////////////

// Coordinator for a set of checkboxes (a datum, not an element) so the same
// group can span multiple checkboxes positioned independently inside a UI.
/datum/mindui_radio_group
	var/selected_id = ""
	var/callback/on_change
	var/list/members = list()  // keyed by id -> /obj/abstract/mind_ui_element/hoverable/checkbox

/datum/mindui_radio_group/Destroy()
	on_change = null
	members = null
	return ..()

/datum/mindui_radio_group/proc/Register(obj/abstract/mind_ui_element/hoverable/checkbox/cb, id)
	if (!cb || !id)
		return
	members[id] = cb

// Walks every member, leaves only the matching id checked, fires on_change.
/datum/mindui_radio_group/proc/Select(id)
	if (!(id in members))
		return
	selected_id = id
	for (var/member_id in members)
		var/obj/abstract/mind_ui_element/hoverable/checkbox/cb = members[member_id]
		if (!cb)
			continue
		var/want_checked = (member_id == id)
		if (cb.checked != want_checked)
			cb.checked = want_checked
			cb.UpdateIcon()
	if (on_change)
		on_change.invoke(id)


////////////////////////////////////////////////////////////////////
//																  //
//							 SLIDER								  //
//																  //
////////////////////////////////////////////////////////////////////

// Discrete-step slider
// Click() reads icon-x/icon-y from params and calls OnClickAt(coord).
// StepUp / StepDown / SetValue clamp and fire on_change only when the value actually changes.
//
// horizontal=TRUE reads icon-x; FALSE reads icon-y.
// icon_center is the midpoint (in icon pixels) used to choose up/down.

/obj/abstract/mind_ui_element/hoverable/slider
	layer = MIND_UI_BUTTON
	var/value = 0
	var/min_value = 0
	var/max_value = 10
	var/step = 1
	var/horizontal = TRUE
	var/icon_center = 16
	var/callback/on_change

/obj/abstract/mind_ui_element/hoverable/slider/Click(location, control, params)
	var/list/p = params2list(params)
	var/coord_text = horizontal ? p["icon-x"] : p["icon-y"]
	if (!coord_text)
		return
	OnClickAt(text2num(coord_text))

/obj/abstract/mind_ui_element/hoverable/slider/proc/OnClickAt(coord)
	if (coord > icon_center)
		StepUp()
	else
		StepDown()

/obj/abstract/mind_ui_element/hoverable/slider/proc/StepUp()
	SetValue(value + step)

/obj/abstract/mind_ui_element/hoverable/slider/proc/StepDown()
	SetValue(value - step)

/obj/abstract/mind_ui_element/hoverable/slider/proc/SetValue(new_value)
	var/clamped = max(min_value, min(max_value, new_value))
	if (clamped == value)
		return
	value = clamped
	if (on_change)
		on_change.invoke(value)

/obj/abstract/mind_ui_element/hoverable/slider/Destroy()
	on_change = null
	return ..()


////////////////////////////////////////////////////////////////////
//																  //
//							  TAB								  //
//																  //
////////////////////////////////////////////////////////////////////

// Clickable tab header
// Click() calls parent.SetActiveTab(tab_id); the host walks its tab elements and repaints each based on whether its tab_id matches active_tab.
// Content swapping is the consumer's responsibility (use on_tab_change).
/obj/abstract/mind_ui_element/hoverable/tab
	layer = MIND_UI_BUTTON
	var/tab_id = ""
	var/active_state = ""
	var/inactive_state = ""

/obj/abstract/mind_ui_element/hoverable/tab/Click()
	var/datum/mind_ui/U = parent
	if (U)
		U.SetActiveTab(tab_id)

/obj/abstract/mind_ui_element/hoverable/tab/UpdateIcon(var/appear = FALSE)
	var/datum/mind_ui/U = parent
	if (U && U.active_tab == tab_id)
		icon_state = active_state
	else
		icon_state = inactive_state

/datum/mind_ui/proc/SetActiveTab(new_tab_id)
	active_tab = new_tab_id
	for (var/obj/abstract/mind_ui_element/hoverable/tab/T in elements)
		T.UpdateIcon()
	if (on_tab_change)
		on_tab_change.invoke(new_tab_id)

// Create and attach a tab in one call.
/datum/mind_ui/proc/AddTab(icon_path, state_off, state_on, off_x, off_y, tab_id_value, callback/cb = null)
	var/obj/abstract/mind_ui_element/hoverable/tab/t = new(null, src)
	t.icon = icon_path
	t.icon_state = state_off
	t.base_icon_state = state_off
	t.inactive_state = state_off
	t.active_state = state_on
	t.offset_x = off_x
	t.offset_y = off_y
	t.tab_id = tab_id_value
	elements += t
	if (cb)
		on_tab_change = cb
	return t


////////////////////////////////////////////////////////////////////
//																  //
//						   TEXT INPUT							  //
//																  //
////////////////////////////////////////////////////////////////////

// Click-to-open text input
// Click() opens an input() modal; the result is passed through SetValue, which stores the new value and invokes on_change.
// SetValue(null) is a no-op (user cancelled the modal).
/obj/abstract/mind_ui_element/hoverable/text_input
	layer = MIND_UI_BUTTON
	var/prompt = "Enter text:"
	var/title = "Input"
	var/default_value = ""
	var/current_value = ""
	var/callback/on_change

/obj/abstract/mind_ui_element/hoverable/text_input/Click()
	var/mob/M = GetUser()
	if (!M)
		return
	var/seed = (current_value != "") ? current_value : default_value
	var/result = input(M, prompt, title, seed) as text|null
	SetValue(result)

/obj/abstract/mind_ui_element/hoverable/text_input/proc/SetValue(new_value)
	if (new_value == null)
		return
	current_value = new_value
	if (on_change)
		on_change.invoke(new_value)

/obj/abstract/mind_ui_element/hoverable/text_input/Destroy()
	on_change = null
	return ..()


////////////////////////////////////////////////////////////////////
//																  //
//						  VIRTUAL LIST							  //
//																  //
////////////////////////////////////////////////////////////////////

// Fixed-window scrollable list
// Renders only `row_count` row elements regardless of data_source size, rebinding them on scroll instead of churning element creation.

/obj/abstract/mind_ui_element/virtual_list
	mouse_opacity = 0
	var/list/data_source = list()
	var/row_count = 5
	var/row_height = 32
	var/scroll_offset = 0
	var/callback/render_row  // invoked as render_row.invoke(row_element, data_item, row_index)
	var/row_element_type = /obj/abstract/mind_ui_element/hoverable/button
	var/list/rows = list()

/obj/abstract/mind_ui_element/virtual_list/proc/BuildRows()
	if (!parent)
		return
	if (rows.len)
		return  // already built; caller can qdel+reassign rows for a hard rebuild
	for (var/i in 1 to row_count)
		var/obj/abstract/mind_ui_element/row = new row_element_type(null, parent)
		row.offset_x = offset_x
		// Rows stack downward: i=1 is top, lower i has higher y offset.
		row.offset_y = offset_y - ((i - 1) * row_height)
		row.UpdateUIScreenLoc()
		parent.elements += row
		rows += row

// Re-bind each row to the data slice at [scroll_offset .. scroll_offset+row_count].
/obj/abstract/mind_ui_element/virtual_list/proc/Refresh()
	BuildRows()  // lazy: first Refresh allocates row elements
	for (var/i in 1 to row_count)
		var/data_index = scroll_offset + i
		var/data_item = (data_index >= 1 && data_index <= data_source.len) ? data_source[data_index] : null
		var/obj/abstract/mind_ui_element/row = (i <= rows.len) ? rows[i] : null
		if (!row)
			continue
		if (data_item == null)
			row.invisibility = 101
			continue
		row.invisibility = 0
		if (render_row)
			render_row.invoke(row, data_item, i)

/obj/abstract/mind_ui_element/virtual_list/proc/ScrollBy(delta)
	var/max_offset = max(0, data_source.len - row_count)
	scroll_offset = max(0, min(max_offset, scroll_offset + delta))
	Refresh()

// "Wheel up" maps to scrolling backward (delta -1) so the data window moves intuitively with the user's input.
/obj/abstract/mind_ui_element/virtual_list/Wheel(delta)
	if (!delta)
		return
	ScrollBy((delta > 0) ? 1 : -1)

/obj/abstract/mind_ui_element/virtual_list/Destroy()
	if (parent)
		for (var/obj/abstract/mind_ui_element/row in rows)
			parent.elements -= row
			qdel(row)
	rows = null
	render_row = null
	data_source = null
	return ..()


////////////////////////////////////////////////////////////////////
//																  //
//							 WINDOW								  //
//																  //
////////////////////////////////////////////////////////////////////

// Generic window base
// Provides procedurally-rendered icons (background panel, close button, drag handle, optional pin/minimize) so consumers can extend instead of authoring DMIs per-feature.

/datum/mind_ui/window
	abstract = TRUE
	uniqueID = "window_base"
	var/title = ""
	var/width = 192
	var/height = 192
	var/icon/background_icon
	var/window_flags = MINDUI_WINDOW_CLOSABLE | MINDUI_WINDOW_MOVABLE
	var/pinned = FALSE
	var/minimized = FALSE

/datum/mind_ui/window/SpawnElements()
	// Build chrome before the failsafe so backgrounds render behind content.
	background_icon = mindui_gen_panel(width, height, GetThemeColor("background"), GetThemeColor("border"))
	var/obj/abstract/mind_ui_element/window_background/bg = new(null, src)
	bg.icon = background_icon
	bg.offset_x = -round(width/2)
	bg.offset_y = -round(height/2)
	elements += bg

	if (window_flags & MINDUI_WINDOW_MOVABLE)
		var/obj/abstract/mind_ui_element/hoverable/movable/window_move/move = new(null, src)
		// Drag handle sits along the top edge of the window: offset y to top, x centered.
		move.offset_x = -round(width/2)
		move.offset_y = round(height/2) - 16
		elements += move

	if (window_flags & MINDUI_WINDOW_CLOSABLE)
		var/obj/abstract/mind_ui_element/hoverable/window_close/close = new(null, src)
		close.offset_x = round(width/2) - 16
		close.offset_y = round(height/2) - 16
		elements += close

	if (window_flags & MINDUI_WINDOW_PINNABLE)
		var/obj/abstract/mind_ui_element/hoverable/window_pin/pin = new(null, src)
		pin.offset_x = round(width/2) - 32
		pin.offset_y = round(height/2) - 16
		elements += pin

	if (window_flags & MINDUI_WINDOW_MINIMIZE)
		var/obj/abstract/mind_ui_element/hoverable/window_minimize/mini = new(null, src)
		mini.offset_x = round(width/2) - 48
		mini.offset_y = round(height/2) - 16
		elements += mini

	..()

/datum/mind_ui/window/Destroy()
	background_icon = null
	return ..()

// Window chrome: background, close, drag handle, pin, minimize.

/obj/abstract/mind_ui_element/window_background
	icon_state = ""
	mouse_opacity = 0
	layer = MIND_UI_BACK

/obj/abstract/mind_ui_element/hoverable/window_close
	icon = 'icons/ui/32x32.dmi'
	icon_state = "close"
	layer = MIND_UI_BUTTON

/obj/abstract/mind_ui_element/hoverable/window_close/Click()
	if (parent)
		parent.Hide()

/obj/abstract/mind_ui_element/hoverable/movable/window_move
	icon = 'icons/ui/32x32.dmi'
	icon_state = "move"
	layer = MIND_UI_BUTTON
	move_whole_ui = TRUE

// Visually toggles between `pin` (unpinned) and `pin-active` (pinned).
/obj/abstract/mind_ui_element/hoverable/window_pin
	icon = 'icons/ui/32x32.dmi'
	icon_state = "pin"
	layer = MIND_UI_BUTTON

/obj/abstract/mind_ui_element/hoverable/window_pin/Click()
	var/datum/mind_ui/window/W = parent
	if (!istype(W))
		return
	W.pinned = !W.pinned
	UpdateIcon()

/obj/abstract/mind_ui_element/hoverable/window_pin/UpdateIcon(var/appear = FALSE)
	var/datum/mind_ui/window/W = parent
	if (!istype(W))
		return
	icon_state = W.pinned ? "pin-active" : "pin"

/obj/abstract/mind_ui_element/hoverable/window_minimize
	icon = 'icons/ui/32x32.dmi'
	icon_state = "minimize"
	layer = MIND_UI_BUTTON

/obj/abstract/mind_ui_element/hoverable/window_minimize/Click()
	var/datum/mind_ui/window/W = parent
	if (!istype(W))
		return
	W.minimized = !W.minimized
	W.ApplyMinimize()
	UpdateIcon()

/obj/abstract/mind_ui_element/hoverable/window_minimize/UpdateIcon(var/appear = FALSE)
	var/datum/mind_ui/window/W = parent
	if (!istype(W))
		return
	icon_state = W.minimized ? "minimize-active" : "minimize"

// Walks `elements` and hides/shows non-chrome children based on `minimized`.
// Chrome elements are detected by type; a subclass that adds custom chrome can override IsWindowChrome() to extend the skip list.
/datum/mind_ui/window/proc/ApplyMinimize()
	for (var/obj/abstract/mind_ui_element/E in elements)
		if (IsWindowChrome(E))
			continue
		if (minimized)
			E.invisibility = 101
		else
			E.invisibility = 0

/datum/mind_ui/window/proc/IsWindowChrome(obj/abstract/mind_ui_element/E)
	if (istype(E, /obj/abstract/mind_ui_element/window_background))
		return TRUE
	if (istype(E, /obj/abstract/mind_ui_element/hoverable/movable/window_move))
		return TRUE
	if (istype(E, /obj/abstract/mind_ui_element/hoverable/window_close))
		return TRUE
	if (istype(E, /obj/abstract/mind_ui_element/hoverable/window_pin))
		return TRUE
	if (istype(E, /obj/abstract/mind_ui_element/hoverable/window_minimize))
		return TRUE
	if (istype(E, /obj/abstract/mind_ui_element/failsafe))
		return TRUE
	return FALSE
