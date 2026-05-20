// mindUI framework

////////////////////////////////////////////////////////////////////
//																  //
//						   TRANSITIONS							  //
//																  //
////////////////////////////////////////////////////////////////////

// Fade, slide, and bounce wrappers around BYOND's animate().
/obj/abstract/mind_ui_element/proc/FadeIn(duration = 5)
	alpha = 0
	animate(src, alpha = 255, time = duration)

/obj/abstract/mind_ui_element/proc/FadeOut(duration = 5, hide_after = TRUE)
	animate(src, alpha = 0, time = duration)
	if (hide_after)
		spawn(duration)
			if (!QDELETED(src))
				Disappear()

/obj/abstract/mind_ui_element/proc/SlideIn(from_dir, distance = 32, duration = 5)
	var/dx = 0
	var/dy = 0
	switch (from_dir)
		if ("LEFT")
			dx = -distance
		if ("RIGHT")
			dx = distance
		if ("UP")
			dy = distance
		if ("DOWN")
			dy = -distance
	var/rest_x = pixel_x
	var/rest_y = pixel_y
	pixel_x = rest_x + dx
	pixel_y = rest_y + dy
	animate(src, pixel_x = rest_x, pixel_y = rest_y, time = duration)

/obj/abstract/mind_ui_element/proc/Bounce(amount = 5, duration = 3)
	var/rest_y = pixel_y
	// Successive animate() calls on the same atom queue, so the second runs after the first.
	animate(src, pixel_y = rest_y + amount, time = duration)
	animate(src, pixel_y = rest_y, time = duration)


////////////////////////////////////////////////////////////////////
//																  //
//						   CONTEXT MENU							  //
//																  //
////////////////////////////////////////////////////////////////////

// A hoverable element with `context_menu = list("Label" = cb)` opens a popup of buttons on right-click.
/obj/abstract/mind_ui_element/hoverable/MouseDown(location, control, params)
	if (IsParentSpectator())
		return
	var/list/p = params2list(params)
	if (p && p["right"] && context_menu && context_menu.len)
		ShowContextMenu(params)
		return
	// Pressed-state opt-in: only flip when state_icons is configured, so legacy components keep their unmanaged icon_state behavior.
	if (state_icons)
		SetState(MINDUI_STATE_PRESSED)
	return ..()

/obj/abstract/mind_ui_element/hoverable/proc/ShowContextMenu(params)
	if (!parent)
		return null
	var/datum/mind_ui/context_menu/menu = new(parent.mind)
	menu.parent = parent
	menu.origin = parent
	menu.entries = context_menu.Copy()
	menu.SpawnElements()
	parent.subUIs += menu
	menu.SendToClient()
	return menu

/datum/mind_ui/context_menu
	uniqueID = "Context Menu"
	abstract = TRUE  // every spawn rewrites uniqueID in New(); the base prototype is never directly displayed.
	var/list/entries  // list("Label" = /callback)
	var/datum/mind_ui/origin

/datum/mind_ui/context_menu/New(datum/mind/M)
	if (!istype(M))
		qdel(src)
		return
	mind = M
	// Per-instance ID so multiple context menus coexist in mind.activeUIs.
	uniqueID = "Context Menu_[ref(src)]"
	mind.activeUIs[uniqueID] = src
	// Skip parent New's SpawnElements/SendToClient loop; the caller (ShowContextMenu) drives those steps explicitly once entries is populated.

/datum/mind_ui/context_menu/Destroy()
	entries = null
	origin = null
	return ..()

/datum/mind_ui/context_menu/SpawnElements()
	var/y_cursor = 0
	for (var/label in entries)
		var/callback/cb = entries[label]
		var/obj/abstract/mind_ui_element/hoverable/button/B = new(null, src)
		B.name = label
		B.icon = 'icons/ui/32x32.dmi'
		B.icon_state = "close"
		B.base_icon_state = B.icon_state
		B.offset_x = 0
		B.offset_y = y_cursor
		// Wrap so invocation auto-closes the menu.
		B.callback = new /callback(src, TYPE_PROC_REF(/datum/mind_ui/context_menu, RunEntry), cb)
		elements += B
		y_cursor -= 32

/datum/mind_ui/context_menu/proc/RunEntry(callback/cb)
	if (cb)
		cb.invoke()
	Hide()
	// Unlink before Cleanup so a later iteration over the parent's subUIs doesn't touch a freed datum.
	if (origin)
		origin.subUIs -= src
	Cleanup()


////////////////////////////////////////////////////////////////////
//																  //
//						 TYPED ACCESSORS						  //
//																  //
////////////////////////////////////////////////////////////////////

// Returns the user cast to `wanted_type`, or null if the user isn't of that type or there is no user.
/datum/mind_ui/proc/GetUserAs(var/wanted_type)
	// GetUser() ASSERTs on null mind/current. Guard explicitly so callers
	// get null, not a runtime, in early-init or torn-down states.
	if (!mind || !mind.current)
		return null
	var/mob/M = mind.current
	if (!istype(M, wanted_type))
		return null
	return M

/obj/abstract/mind_ui_element/proc/GetUserAs(var/wanted_type)
	var/mob/M = GetUser()
	if (!M)
		return null
	if (!istype(M, wanted_type))
		return null
	return M

// Convert a BYOND params2list() result into a bitmask of MINDUI_MOD_* flags.
/proc/mindui_parse_modifiers(var/list/params)
	var/flags = 0
	if (params["shift"])    flags |= MINDUI_MOD_SHIFT
	if (params["ctrl"])     flags |= MINDUI_MOD_CTRL
	if (params["alt"])      flags |= MINDUI_MOD_ALT
	if (params["middle"])   flags |= MINDUI_MOD_MIDDLE
	if (params["right"])    flags |= MINDUI_MOD_RIGHT
	return flags

// Parse a screen_loc like "LEFT:5,TOP:-3" into a list keyed by x_anchor, x_off, y_anchor, y_off.
/proc/mindui_split_screen_loc(var/loc_string)
	var/list/parts = splittext(loc_string, ",")
	if (parts.len < 2)
		return null
	var/list/result = list()
	var/list/x_parts = splittext(parts[1], ":")
	var/list/y_parts = splittext(parts[2], ":")
	result["x_anchor"] = x_parts[1]
	result["x_off"] = (x_parts.len > 1) ? text2num(x_parts[2]) : 0
	result["y_anchor"] = y_parts[1]
	result["y_off"] = (y_parts.len > 1) ? text2num(y_parts[2]) : 0
	return result


////////////////////////////////////////////////////////////////////
//																  //
//						  LIFECYCLE HELPERS						  //
//																  //
////////////////////////////////////////////////////////////////////

/datum/mind_ui/proc/EnsureSpawned()
	if (elements.len)
		return
	if (!lazy)
		return
	SpawnElements()
	SendToClient()

/datum/mind_ui/proc/Cleanup()
	for (var/obj/abstract/mind_ui_element/e in elements)
		qdel(e)
	elements.Cut()
	for (var/datum/mind_ui/child in subUIs)
		child.Cleanup()
	subUIs.Cut()
	if (mind && (uniqueID in mind.activeUIs))
		mind.activeUIs -= uniqueID
	qdel(src)


////////////////////////////////////////////////////////////////////
//																  //
//							 MACHINE UI							  //
//																  //
////////////////////////////////////////////////////////////////////

// Base class for mindUI windows tied to a source atom (typically machinery).
// Auto-closes when the user moves out of range (via SSmindui heartbeat calling Valid()) or when the source atom is destroyed (via /event/destroyed listener).
/datum/mind_ui/machine
	abstract = TRUE
	cleanup_when_invalid = TRUE
	auto_display = TRUE
	var/datum/weakref/source_ref
	var/source_distance_limit = 1
	var/source_being_destroyed = FALSE

/datum/mind_ui/machine/New(datum/mind/M, atom/source = null)
	..(M)
	if (source)
		source_ref = makeweakref(source)
		source.register_event(/event/destroyed, src, "OnSourceDestroyed")

/datum/mind_ui/machine/Destroy()
	if (source_ref && !source_being_destroyed)
		var/atom/source = source_ref.get()
		if (source)
			source.unregister_event(/event/destroyed, src, "OnSourceDestroyed")
	source_ref = null
	return ..()

/datum/mind_ui/machine/proc/OnSourceDestroyed()
	source_being_destroyed = TRUE
	cleanup_when_invalid = TRUE
	if (active)
		Hide()
	else
		Cleanup()

/datum/mind_ui/machine/Valid()
	var/atom/source = GetSource()
	if (!source)
		return FALSE
	if (!Valid_Living())
		return FALSE
	if (!Valid_InRange(source, source_distance_limit))
		return FALSE
	return TRUE

/datum/mind_ui/machine/proc/GetSource()
	if (!source_ref)
		return null
	var/atom/A = source_ref.get()
	return A

// Generic opt-in hook: any atom can declare a mind_ui_type and call Open_mindUI from its own click/attack handler to spawn the matching UI for the user.
/atom
	var/mind_ui_type = null  // path to a /datum/mind_ui/machine subclass

/atom/proc/Open_mindUI(mob/user)
	if (!mind_ui_type || !user || !user.mind)
		return FALSE
	new mind_ui_type(user.mind, src)
	return TRUE


////////////////////////////////////////////////////////////////////
//																  //
//					 MODIFIER CLICKS / MOUSE WHEEL				  //
//																  //
////////////////////////////////////////////////////////////////////

// Returns TRUE if a modifier handler fired so the caller can return early.
/obj/abstract/mind_ui_element/hoverable/proc/HandleModifiers(params)
	var/list/p = params2list(params)
	if (!p)
		return FALSE
	var/mob/M = GetUser()
	if (p["shift"])
		ShiftClick(M)
		return TRUE
	if (p["ctrl"])
		CtrlClick(M)
		return TRUE
	if (p["alt"])
		AltClick(M)
		return TRUE
	return FALSE

/obj/abstract/mind_ui_element/MouseWheel(delta_x, delta_y, location, control, params)
	Wheel(delta_y)

/obj/abstract/mind_ui_element/proc/Wheel(delta)
	return


////////////////////////////////////////////////////////////////////
//																  //
//						 THROTTLED PROCESS						  //
//																  //
////////////////////////////////////////////////////////////////////

// Elements that opt into MINDUI_FLAG_PROCESSING get process() called every tick.
/obj/abstract/mind_ui_element/proc/Tick()
	return

/obj/abstract/mind_ui_element/process()
	if (process_interval && (world.time - last_process) < process_interval)
		return
	last_process = world.time
	Tick()


////////////////////////////////////////////////////////////////////
//																  //
//						 PARTICLE ATTACHMENT					  //
//																  //
////////////////////////////////////////////////////////////////////

// Wraps the add_particles + adjust_particles pattern (originally in shade_timer.dm).
/obj/abstract/mind_ui_element/proc/AttachParticles(ps_type, list/overrides = null)
	if (!ps_type)
		return
	add_particles(ps_type)
	if (overrides)
		for (var/k in overrides)
			adjust_particles(k, overrides[k])


////////////////////////////////////////////////////////////////////
//																  //
//						   ELEMENT POOL							  //
//																  //
////////////////////////////////////////////////////////////////////

// Pre-allocate N elements of a given type, then Acquire / Release to reuse them instead of creating fresh ones each time.
/datum/mindui_element_pool
	var/element_type
	var/datum/mind_ui/parent_ui
	var/list/active = list()
	var/list/inactive = list()

/datum/mindui_element_pool/New(datum/mind_ui/owner, etype, prealloc = 0)
	parent_ui = owner
	element_type = etype
	for (var/i in 1 to prealloc)
		var/obj/abstract/mind_ui_element/e = new etype(null, parent_ui)
		e.invisibility = 101
		inactive += e
		parent_ui.elements += e

/datum/mindui_element_pool/Destroy()
	for (var/obj/abstract/mind_ui_element/e in active)
		qdel(e)
	for (var/obj/abstract/mind_ui_element/e in inactive)
		qdel(e)
	active.Cut()
	inactive.Cut()
	parent_ui = null
	return ..()

/datum/mindui_element_pool/proc/Acquire()
	var/obj/abstract/mind_ui_element/e
	if (inactive.len)
		e = inactive[1]
		inactive -= e
	else
		e = new element_type(null, parent_ui)
		parent_ui.elements += e
	active += e
	e.invisibility = 0
	return e

/datum/mindui_element_pool/proc/Release(obj/abstract/mind_ui_element/e)
	if (!e)
		return
	e.invisibility = 101
	active -= e
	inactive += e

/datum/mindui_element_pool/proc/ReleaseAll()
	var/list/snapshot = active.Copy()
	for (var/obj/abstract/mind_ui_element/e in snapshot)
		Release(e)


////////////////////////////////////////////////////////////////////
//																  //
//						  EVENT BINDINGS						  //
//																  //
////////////////////////////////////////////////////////////////////

// Bind a UI to a source datum's event; when the event fires on the source, the UI's matching elements (or all elements) get UpdateIcon() called.
/datum/mind_ui/proc/BindEvent(datum/source, event_type, element_type = null)
	if (!source || !event_type)
		return
	if (!bindings)
		bindings = list()
	var/key = "[ref(source)]:[event_type]"
	if (!bindings[key])
		bindings[key] = list("source" = source, "event" = event_type, "elements" = list())
		source.register_event(event_type, src, "OnBoundEvent")
	bindings[key]["elements"] |= element_type  // null means "every element"

/datum/mind_ui/proc/UnbindEvent(datum/source, event_type)
	if (!bindings)
		return
	var/key = "[ref(source)]:[event_type]"
	if (!bindings[key])
		return
	source.unregister_event(event_type, src, "OnBoundEvent")
	bindings -= key

/datum/mind_ui/proc/OnBoundEvent()
	for (var/key in bindings)
		var/list/binding = bindings[key]
		for (var/etype in binding["elements"])
			if (isnull(etype))
				for (var/obj/abstract/mind_ui_element/e in elements)
					e.UpdateIcon()
			else
				for (var/obj/abstract/mind_ui_element/e in elements)
					if (istype(e, etype))
						e.UpdateIcon()


////////////////////////////////////////////////////////////////////
//																  //
//						  SHARED / MULTI-VIEWER					  //
//																  //
////////////////////////////////////////////////////////////////////

// One /datum/shared_mind_ui_state lives on the source object (e.g. a chessboard atom).
// Multiple per-viewer /datum/mind_ui instances reference the same shared state and call NotifyAll() when state mutates, which fans out icon updates to every registered viewer.
/datum/shared_mind_ui_state
	var/list/viewers = list()  // list of /datum/mind_ui

/datum/shared_mind_ui_state/Destroy()
	viewers = null
	return ..()

// Adding the same viewer twice would double-update its icons per tick.
/datum/shared_mind_ui_state/proc/RegisterViewer(datum/mind_ui/U)
	if (!U)
		return
	if (!(U in viewers))
		viewers += U

/datum/shared_mind_ui_state/proc/UnregisterViewer(datum/mind_ui/U)
	if (!U || !viewers)
		return
	viewers -= U

// Defensive null-check so a freed mind_ui in the list doesn't crash the fan-out.
/datum/shared_mind_ui_state/proc/NotifyAll()
	if (!viewers)
		return
	for (var/datum/mind_ui/U in viewers)
		if (U)
			U.UpdateAllElementIcons()

/datum/mind_ui/proc/UpdateAllElementIcons()
	for (var/obj/abstract/mind_ui_element/element in elements)
		element.UpdateIcon()

/datum/mind_ui/shared
	abstract = TRUE
	var/datum/shared_mind_ui_state/shared_state
	var/spectator = FALSE  // when TRUE, hoverable elements short-circuit MouseDown

/datum/mind_ui/shared/New(datum/mind/M, datum/shared_mind_ui_state/state = null)
	..(M)
	if (state)
		shared_state = state
		shared_state.RegisterViewer(src)

/datum/mind_ui/shared/Destroy()
	if (shared_state)
		shared_state.UnregisterViewer(src)
	shared_state = null
	return ..()

// Role gate runs once on send; elements that fail are never added to client.screen.
/datum/mind_ui/shared/SendToClient()
	if (!mind || !mind.current || !mind.current.client)
		return
	if (!Valid() || !display_with_parent)
		Hide(TRUE)
	if (!elements.len)
		return
	var/list/to_add = list()
	for (var/obj/abstract/mind_ui_element/element in elements)
		if (!element.IsVisibleForViewer(src))
			continue
		to_add += element
	mind.current.client.screen |= to_add

/obj/abstract/mind_ui_element/proc/IsVisibleForViewer(datum/mind_ui/U)
	if (!visible_to_roles || !visible_to_roles.len)
		return TRUE
	if (!U || !U.mind)
		return FALSE
	var/role = U.mind.assigned_role
	if (!role)
		return FALSE
	return (role in visible_to_roles)

/obj/abstract/mind_ui_element/hoverable/proc/IsParentSpectator()
	if (!parent || !istype(parent, /datum/mind_ui/shared))
		return FALSE
	var/datum/mind_ui/shared/S = parent
	return S.spectator


////////////////////////////////////////////////////////////////////
//																  //
//						  DISPLAY STACK CAP						  //
//																  //
////////////////////////////////////////////////////////////////////

// When a player has too many mindUIs displayed at once (default cap 5), the oldest non-pinned one is auto-hidden to keep the screen readable.
/datum/mind_ui/proc/RegisterDisplayed()
	if (!mind)
		return
	var/mob/M = mind.current
	if (!M || !M.client)
		return
	var/client/C = M.client
	if (!C.mindui_display_order)
		C.mindui_display_order = list()
	C.mindui_display_order -= src
	C.mindui_display_order.Insert(1, src)
	EnforceVisibleCap(C)

/datum/mind_ui/proc/UnregisterDisplayed()
	if (!mind)
		return
	var/mob/M = mind.current
	if (!M || !M.client || !M.client.mindui_display_order)
		return
	M.client.mindui_display_order -= src

// Thin client-wrapper around the pure-method seam below, so tests can call EnforceVisibleCapOnList directly with a synthesized list and integer cap.
/datum/mind_ui/proc/EnforceVisibleCap(client/C)
	if (!C || !C.mindui_display_order)
		return
	EnforceVisibleCapOnList(C.mindui_display_order, C.mindui_max_visible)

/datum/mind_ui/proc/EnforceVisibleCapOnList(list/order, max_visible)
	if (!order || !max_visible)
		return
	while (order.len > max_visible)
		var/evicted = FALSE
		for (var/i = order.len, i > 0, i--)
			var/datum/mind_ui/candidate = order[i]
			if (IsPinnedUI(candidate))
				continue
			order.Cut(i, i + 1)
			candidate.Hide()
			evicted = TRUE
			break
		if (!evicted)
			// Every remaining UI is pinned; live over-cap.
			break

/datum/mind_ui/proc/IsPinnedUI(datum/mind_ui/U)
	if (!istype(U, /datum/mind_ui/window))
		return FALSE
	var/datum/mind_ui/window/W = U
	return W.pinned


////////////////////////////////////////////////////////////////////
//																  //
//						  STATE MACHINE							  //
//																  //
////////////////////////////////////////////////////////////////////

// Declarative icon_state swapping for mindUI hoverable elements.
/obj/abstract/mind_ui_element/hoverable/proc/SetState(new_state)
	current_state = new_state
	if (!state_icons || !state_icons[new_state])
		return
	var/template = state_icons[new_state]
	icon_state = replacetext(template, "%", base_icon_state)

/obj/abstract/mind_ui_element/hoverable/MouseUp(location, control, params)
	if (state_icons)
		SetState(hovering ? MINDUI_STATE_HOVER : MINDUI_STATE_IDLE)
	return ..()


////////////////////////////////////////////////////////////////////
//																  //
//						 DROP-TARGET DISPATCH					  //
//																  //
////////////////////////////////////////////////////////////////////

/obj/abstract/mind_ui_element/proc/TryDispatchDrop(over_object)
	if (!istype(over_object, /obj/abstract/mind_ui_element))
		return FALSE
	var/obj/abstract/mind_ui_element/target = over_object
	if (target.can_receive_drops && target.on_drop)
		target.on_drop.invoke(src)
		return TRUE
	return FALSE
