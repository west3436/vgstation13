// Overmap MindUI. Provides the visual viewport for SSovermap state.
//
// Phase 3 introduces the abstract `overmap_base` parent and the read-only
// `starmap` subtype. Phase 4 extends with `helm/free` and `helm/preset`
// subtypes that add waypoint planning, throttle, and a dock selector.
//
// Architecture:
// - Each MindUI is bound to a single /datum/shuttle via `linked_shuttle`.
//   The UI reads the shuttle's per-shuttle fog and known_bodies/known_hazards
//   to render fog of war.
// - Tile elements are spawned dynamically as the camera window changes; the
//   element pool is rebuilt by `rebuild_tile_pool()`.
// - SSovermap calls `notify_ship_moved` / `notify_knowledge_changed` after
//   every tick. The UI dispatches those into the per-UI `on_ship_moved` /
//   `on_knowledge_changed` callbacks via the listening_uis registry.

#define OVERMAP_UI_SIZE OVERMAP_VIEWPORT_SIZE
#define OVERMAP_UI_PADDING 5

// Color palette. All Phase 3 rendering is solid-color block art on top of
// 1x1.dmi (a one-pixel placeholder DMI). Real sprites land in Phase 8 polish.
#define OVERMAP_COLOR_FOG       "#101018"
#define OVERMAP_COLOR_SCANNED   "#283050"
#define OVERMAP_COLOR_VISITED   "#3C5078"
#define OVERMAP_COLOR_GRID_LINE "#202830"

#define OVERMAP_COLOR_BODY_ANCHOR    "#FFFFFF"
#define OVERMAP_COLOR_BODY_PLANET    "#32C850"
#define OVERMAP_COLOR_BODY_OUTPOST   "#80C0FF"
#define OVERMAP_COLOR_BODY_HOMEBASE  "#FFFFAA"
#define OVERMAP_COLOR_BODY_ENCOUNTER "#00FFFF"
#define OVERMAP_COLOR_BODY_CENTCOMM  "#FF6464"
#define OVERMAP_COLOR_BODY_GENERIC   "#A0A0A0"

#define OVERMAP_COLOR_HAZARD     "#A02020"
#define OVERMAP_COLOR_SHIP       "#FFFFFF"
#define OVERMAP_COLOR_CONE       "#64C8FF"   // sensor cone tint
#define OVERMAP_COLOR_WAYPOINT   "#FFC832"   // Phase 4 helm uses this
#define OVERMAP_COLOR_COURSE     "#FFA040"   // Phase 4 helm uses this


////////////////////////////////////////////////////////////////////
//                                                                //
//                  /datum/mind_ui/overmap_base                   //
//                                                                //
////////////////////////////////////////////////////////////////////

/datum/mind_ui/overmap_base
	uniqueID = "overmap_base"
	x = "CENTER"
	y = "CENTER"
	element_types_to_spawn = list(
		/obj/abstract/mind_ui_element/overmap_base_bg,
		/obj/abstract/mind_ui_element/overmap_sensor_cone,
		/obj/abstract/mind_ui_element/overmap_ship_marker,
		/obj/abstract/mind_ui_element/overmap_hud_text,
		/obj/abstract/mind_ui_element/hoverable/overmap_close,
		/obj/abstract/mind_ui_element/hoverable/movable/overmap_move,
		/obj/abstract/mind_ui_element/hoverable/overmap_mode_toggle,
		/obj/abstract/mind_ui_element/hoverable/overmap_recenter,
	)

	var/datum/shuttle/linked_shuttle = null
	var/view_mode = OVERMAP_VIEW_NAV
	var/camera_x = 13
	var/camera_y = 13
	var/auto_follow = TRUE
	var/list/tile_elements = list()           // sparse, only spawned for visible tiles


/datum/mind_ui/overmap_base/New(datum/mind/M)
	. = ..()
	if(SSovermap)
		SSovermap.register_ui(src)


/datum/mind_ui/overmap_base/Destroy()
	if(SSovermap)
		SSovermap.unregister_ui(src)
	// Tear down every element from the user's screen and qdel each one. The
	// base /datum/mind_ui doesn't do this — without it, elements persist on
	// client.screen until the round ends, leaking icons and event handlers.
	if(mind?.current?.client)
		for(var/obj/abstract/mind_ui_element/E in elements)
			mind.current.client.screen -= E
	for(var/obj/abstract/mind_ui_element/E in elements)
		qdel(E)
	elements.Cut()
	tile_elements.Cut()
	..()


// Override SpawnElements so the tile pool is built immediately on first
// instantiation, not lazily on the first ship-moved notification.
/datum/mind_ui/overmap_base/SpawnElements()
	..()
	if(linked_shuttle)
		camera_x = linked_shuttle.x || 13
		camera_y = linked_shuttle.y || 13
	rebuild_tile_pool()


// Bind the UI to a shuttle. Called from the console's attack_hand right after
// DisplayUI returns and stashes the freshly-created UI in mind.activeUIs.
/datum/mind_ui/overmap_base/proc/bind_shuttle(datum/shuttle/S)
	linked_shuttle = S
	if(S)
		camera_x = S.x || 13
		camera_y = S.y || 13
	rebuild_tile_pool()
	UpdateUIScreenLoc()


// Compute the visible tile window. Nav mode shows a 5x5 (OVERMAP_VIEW_TILES)
// region centered on the camera. Map mode shows the full grid.
/datum/mind_ui/overmap_base/proc/get_visible_tile_window()
	var/list/window = list("min_x" = 1, "max_x" = OVERMAP_WIDTH, "min_y" = 1, "max_y" = OVERMAP_HEIGHT)
	if(view_mode == OVERMAP_VIEW_NAV)
		var/half = round(OVERMAP_VIEW_TILES / 2)
		window["min_x"] = max(1, camera_x - half)
		window["max_x"] = min(OVERMAP_WIDTH, camera_x + half)
		window["min_y"] = max(1, camera_y - half)
		window["max_y"] = min(OVERMAP_HEIGHT, camera_y + half)
	return window


// Pixels per tile depends on view mode.
/datum/mind_ui/overmap_base/proc/get_tile_pixels()
	if(view_mode == OVERMAP_VIEW_NAV)
		return OVERMAP_TILE_PIXELS
	return OVERMAP_MAP_TILE_PIXELS


// Convert overmap tile (tx, ty) to a UI offset relative to the UI's anchor.
/datum/mind_ui/overmap_base/proc/world_to_viewport(tx, ty)
	var/list/window = get_visible_tile_window()
	var/px = get_tile_pixels()
	// Viewport origin is the bottom-left corner of the visible window.
	var/dx = (tx - window["min_x"]) * px
	var/dy = (ty - window["min_y"]) * px
	// Anchor at viewport center: subtract half the visible width/height.
	var/visible_w = (window["max_x"] - window["min_x"] + 1) * px
	var/visible_h = (window["max_y"] - window["min_y"] + 1) * px
	return list("x" = dx - visible_w / 2 + px / 2, "y" = dy - visible_h / 2 + px / 2)


// Inverse — convert a click pixel offset to a tile coord. Caller passes the
// click offset_x/offset_y relative to the UI anchor.
/datum/mind_ui/overmap_base/proc/viewport_to_world(off_x, off_y)
	var/list/window = get_visible_tile_window()
	var/px = get_tile_pixels()
	var/visible_w = (window["max_x"] - window["min_x"] + 1) * px
	var/visible_h = (window["max_y"] - window["min_y"] + 1) * px
	var/raw_x = off_x + visible_w / 2 - px / 2
	var/raw_y = off_y + visible_h / 2 - px / 2
	var/tx = window["min_x"] + round(raw_x / px)
	var/ty = window["min_y"] + round(raw_y / px)
	return list("x" = tx, "y" = ty)


// Tear down old tile elements and spawn fresh ones for the current visible
// window. Called on init, on view-mode toggle, and whenever the camera moves
// to a new tile center.
/datum/mind_ui/overmap_base/proc/rebuild_tile_pool()
	for(var/obj/abstract/mind_ui_element/T in tile_elements)
		elements -= T
		if(mind?.current?.client)
			mind.current.client.screen -= T
		qdel(T)
	tile_elements.Cut()

	if(!linked_shuttle || !SSovermap)
		return

	var/list/window = get_visible_tile_window()
	for(var/tx = window["min_x"] to window["max_x"])
		for(var/ty = window["min_y"] to window["max_y"])
			var/obj/abstract/mind_ui_element/overmap_tile/tile = make_tile_element()
			tile.parent = src
			tile.tile_x = tx
			tile.tile_y = ty
			elements += tile
			tile_elements += tile
			tile.RefreshAppearance()
			tile.UpdateUIScreenLoc()
			if(mind?.current?.client)
				mind.current.client.screen |= tile
				tile.Appear()


// Subclassed by helm/free in Phase 4 to spawn the hoverable variant.
/datum/mind_ui/overmap_base/proc/make_tile_element()
	return new /obj/abstract/mind_ui_element/overmap_tile(null, src)


// Called by SSovermap.notify_ship_moved.
/datum/mind_ui/overmap_base/proc/on_ship_moved()
	if(!linked_shuttle)
		return
	if(auto_follow)
		var/old_camera_x = camera_x
		var/old_camera_y = camera_y
		camera_x = linked_shuttle.x || camera_x
		camera_y = linked_shuttle.y || camera_y
		if(camera_x != old_camera_x || camera_y != old_camera_y)
			rebuild_tile_pool()
	// Always refresh ship marker + HUD text + sensor cone.
	for(var/obj/abstract/mind_ui_element/E in elements)
		if(istype(E, /obj/abstract/mind_ui_element/overmap_ship_marker) \
			|| istype(E, /obj/abstract/mind_ui_element/overmap_sensor_cone) \
			|| istype(E, /obj/abstract/mind_ui_element/overmap_hud_text))
			E.UpdateIcon()
			E.UpdateUIScreenLoc()


// Called by SSovermap.notify_knowledge_changed. Rebuild tiles to redraw fog
// and any newly learned bodies/hazards.
/datum/mind_ui/overmap_base/proc/on_knowledge_changed()
	rebuild_tile_pool()


// Click-mode toggle target. Phase 4 helm/free overrides for waypoint planning;
// the base does nothing for view-only consoles.
/datum/mind_ui/overmap_base/proc/on_tile_clicked(tx, ty)
	return


////////////////////////////////////////////////////////////////////
//                                                                //
//             /datum/mind_ui/overmap_base/starmap                //
//                                                                //
////////////////////////////////////////////////////////////////////

/datum/mind_ui/overmap_base/starmap
	uniqueID = "starmap"
	// Inherits element list and procs from base. Click handler is a no-op so
	// the starmap is genuinely view-only.

/datum/mind_ui/overmap_base/starmap/on_tile_clicked(tx, ty)
	return


////////////////////////////////////////////////////////////////////
//                                                                //
//                          ELEMENTS                              //
//                                                                //
////////////////////////////////////////////////////////////////////

// ----- Background ---------------------------------------------------------

/obj/abstract/mind_ui_element/overmap_base_bg
	icon = 'icons/ui/overmap/hud.dmi'
	icon_state = "base"
	layer = MIND_UI_BACK
	offset_x = -OVERMAP_UI_SIZE/2
	offset_y = -OVERMAP_UI_SIZE/2

/obj/abstract/mind_ui_element/overmap_base_bg/New(turf/loc, datum/mind_ui/P)
	. = ..(loc, P)
	// Synthesize a solid black background sized to the viewport. We don't
	// rely on the placeholder DMI carrying a real "base" sprite.
	var/icon/bg = new /icon('icons/ui/overmap/bodies.dmi', "")
	bg.Scale(OVERMAP_UI_SIZE, OVERMAP_UI_SIZE)
	bg.Blend(rgb(8, 8, 16, 230), ICON_OVERLAY)
	icon = bg
	UpdateUIScreenLoc()


// ----- Tile (one per visible tile) ----------------------------------------

/obj/abstract/mind_ui_element/overmap_tile
	icon = 'icons/ui/overmap/bodies.dmi'
	icon_state = "tile"
	layer = MIND_UI_BACK + 0.1
	mouse_opacity = 1
	var/tile_x = 0
	var/tile_y = 0


/obj/abstract/mind_ui_element/overmap_tile/New(turf/loc, datum/mind_ui/P)
	. = ..(loc, P)


/obj/abstract/mind_ui_element/overmap_tile/proc/RefreshAppearance()
	var/datum/mind_ui/overmap_base/ovmui = parent
	if(!ovmui || !ovmui.linked_shuttle)
		return
	var/datum/shuttle/S = ovmui.linked_shuttle
	var/px = ovmui.get_tile_pixels()
	var/list/coord = ovmui.world_to_viewport(tile_x, tile_y)
	offset_x = coord["x"] - px / 2
	offset_y = coord["y"] - px / 2

	// Determine the fog state for this tile.
	var/fog_color = OVERMAP_COLOR_FOG
	if(S.tile_visited && S.tile_visited[tile_x][tile_y])
		fog_color = OVERMAP_COLOR_VISITED
	else if(S.tile_scanned && S.tile_scanned[tile_x][tile_y])
		fog_color = OVERMAP_COLOR_SCANNED

	var/icon/tile_icon = new /icon('icons/ui/overmap/bodies.dmi', "")
	tile_icon.Scale(px, px)
	tile_icon.Blend(fog_color, ICON_OVERLAY)
	// Subtle grid border so tiles are visually separable.
	tile_icon.DrawBox(OVERMAP_COLOR_GRID_LINE, 1, 1, px, 1)
	tile_icon.DrawBox(OVERMAP_COLOR_GRID_LINE, 1, 1, 1, px)

	// If scanned, paint known bodies and hazards on top.
	if(fog_color != OVERMAP_COLOR_FOG)
		for(var/datum/overmap_body/B in SSovermap.get_bodies_at(tile_x, tile_y))
			if(B.hidden)
				continue
			if(!S.knows_body(B))
				continue
			var/icon/body_dot = new /icon('icons/ui/overmap/bodies.dmi', "")
			var/dot_size = max(round(px * 0.6), 4)
			body_dot.Scale(dot_size, dot_size)
			body_dot.Blend(body_color_for(B), ICON_OVERLAY)
			tile_icon.Blend(body_dot, ICON_OVERLAY, round((px - dot_size) / 2), round((px - dot_size) / 2))
		for(var/datum/overmap_hazard/H in SSovermap.get_hazards_at(tile_x, tile_y))
			if(!S.knows_hazard(H))
				continue
			var/icon/haz = new /icon('icons/ui/overmap/bodies.dmi', "")
			var/haz_size = max(round(px * 0.4), 3)
			haz.Scale(haz_size, haz_size)
			haz.Blend(H.color || OVERMAP_COLOR_HAZARD, ICON_OVERLAY)
			tile_icon.Blend(haz, ICON_OVERLAY, 1, 1)

	icon = tile_icon
	UpdateUIScreenLoc()


/obj/abstract/mind_ui_element/overmap_tile/Click(location, control, params)
	var/datum/mind_ui/overmap_base/ovmui = parent
	if(!ovmui)
		return
	ovmui.on_tile_clicked(tile_x, tile_y)


/proc/body_color_for(datum/overmap_body/B)
	if(B.is_anchor)
		return OVERMAP_COLOR_BODY_ANCHOR
	switch(B.body_type)
		if(OVERMAP_BODY_PLANET)
			return OVERMAP_COLOR_BODY_PLANET
		if(OVERMAP_BODY_OUTPOST)
			return OVERMAP_COLOR_BODY_OUTPOST
		if(OVERMAP_BODY_HOMEBASE)
			return OVERMAP_COLOR_BODY_HOMEBASE
		if(OVERMAP_BODY_ENCOUNTER)
			return OVERMAP_COLOR_BODY_ENCOUNTER
		if(OVERMAP_BODY_CENTCOMM)
			return OVERMAP_COLOR_BODY_CENTCOMM
	return OVERMAP_COLOR_BODY_GENERIC


// ----- Ship marker --------------------------------------------------------

/obj/abstract/mind_ui_element/overmap_ship_marker
	icon = 'icons/ui/overmap/bodies.dmi'
	icon_state = "ship"
	layer = MIND_UI_FRONT + 0.2

/obj/abstract/mind_ui_element/overmap_ship_marker/New(turf/loc, datum/mind_ui/P)
	. = ..(loc, P)
	UpdateIcon()
	UpdateUIScreenLoc()

/obj/abstract/mind_ui_element/overmap_ship_marker/UpdateIcon(appear = FALSE)
	var/datum/mind_ui/overmap_base/ovmui = parent
	if(!ovmui || !ovmui.linked_shuttle)
		return
	var/px = ovmui.get_tile_pixels()
	var/marker_size = max(round(px * 0.5), 6)
	var/icon/I = new /icon('icons/ui/overmap/bodies.dmi', "")
	I.Scale(marker_size, marker_size)
	I.Blend(OVERMAP_COLOR_SHIP, ICON_OVERLAY)
	icon = I
	var/list/coord = ovmui.world_to_viewport(ovmui.linked_shuttle.x || ovmui.camera_x, ovmui.linked_shuttle.y || ovmui.camera_y)
	offset_x = coord["x"] - marker_size / 2
	offset_y = coord["y"] - marker_size / 2


// ----- Sensor cone --------------------------------------------------------

/obj/abstract/mind_ui_element/overmap_sensor_cone
	icon = 'icons/ui/overmap/bodies.dmi'
	icon_state = "cone"
	layer = MIND_UI_FRONT + 0.1
	mouse_opacity = 0

/obj/abstract/mind_ui_element/overmap_sensor_cone/New(turf/loc, datum/mind_ui/P)
	. = ..(loc, P)
	UpdateIcon()
	UpdateUIScreenLoc()

/obj/abstract/mind_ui_element/overmap_sensor_cone/UpdateIcon(appear = FALSE)
	var/datum/mind_ui/overmap_base/ovmui = parent
	if(!ovmui || !ovmui.linked_shuttle || ovmui.linked_shuttle.detection_radius <= 0)
		invisibility = 101
		return
	invisibility = 0
	var/px = ovmui.get_tile_pixels()
	var/r = ovmui.linked_shuttle.detection_radius
	var/cone_size = (2 * r + 1) * px
	var/icon/I = new /icon('icons/ui/overmap/bodies.dmi', "")
	I.Scale(cone_size, cone_size)
	I.Blend(OVERMAP_COLOR_CONE + "30", ICON_OVERLAY)
	icon = I
	var/list/coord = ovmui.world_to_viewport(ovmui.linked_shuttle.x || ovmui.camera_x, ovmui.linked_shuttle.y || ovmui.camera_y)
	offset_x = coord["x"] - cone_size / 2
	offset_y = coord["y"] - cone_size / 2


// ----- HUD text -----------------------------------------------------------

/obj/abstract/mind_ui_element/overmap_hud_text
	layer = MIND_UI_FRONT + 0.5
	offset_x = -OVERMAP_UI_SIZE/2
	offset_y = OVERMAP_UI_SIZE/2 - 50

/obj/abstract/mind_ui_element/overmap_hud_text/New(turf/loc, datum/mind_ui/P)
	. = ..(loc, P)
	maptext_width = OVERMAP_UI_SIZE
	maptext_height = 50
	UpdateIcon()

/obj/abstract/mind_ui_element/overmap_hud_text/UpdateIcon(appear = FALSE)
	var/datum/mind_ui/overmap_base/ovmui = parent
	if(!ovmui || !ovmui.linked_shuttle)
		maptext = ""
		return
	var/datum/shuttle/S = ovmui.linked_shuttle
	var/wp_count = S.waypoints.len
	var/throttle_pct = round(S.throttle * 100)
	var/list/lines = list()
	lines += "[S.name]"
	lines += "Pos: ([S.x],[S.y])  Throttle: [throttle_pct]%"
	if(wp_count)
		var/list/next_wp = S.waypoints[1]
		lines += "Next: ([next_wp[1]],[next_wp[2]])  Queue: [wp_count]"
	else
		lines += S.docked_at ? "Docked: [S.docked_at.name]" : "Idle"
	maptext = {"<div style="font-family: Fixedsys, monospace; font-size: 7pt; color: #C0E0FF; line-height: 11px; padding: 4px;">[jointext(lines, "<br>")]</div>"}


// ----- Buttons ------------------------------------------------------------

/obj/abstract/mind_ui_element/hoverable/overmap_close
	icon = 'icons/ui/16x16.dmi'
	icon_state = "close"
	layer = MIND_UI_BUTTON
	offset_x = OVERMAP_UI_SIZE/2 - 8
	offset_y = OVERMAP_UI_SIZE/2 - 8

/obj/abstract/mind_ui_element/hoverable/overmap_close/Click()
	var/datum/mind_ui/ancestor = parent.GetAncestor()
	ancestor.Hide()


/obj/abstract/mind_ui_element/hoverable/movable/overmap_move
	icon = 'icons/ui/16x16.dmi'
	icon_state = "move"
	layer = MIND_UI_BUTTON
	offset_x = -OVERMAP_UI_SIZE/2 - 8
	offset_y = OVERMAP_UI_SIZE/2 - 8
	move_whole_ui = TRUE


/obj/abstract/mind_ui_element/hoverable/overmap_mode_toggle
	icon = 'icons/ui/16x16.dmi'
	icon_state = "expand"
	layer = MIND_UI_BUTTON
	offset_x = OVERMAP_UI_SIZE/2 - 26
	offset_y = OVERMAP_UI_SIZE/2 - 8

/obj/abstract/mind_ui_element/hoverable/overmap_mode_toggle/Click()
	var/datum/mind_ui/overmap_base/ovmui = parent
	if(!ovmui)
		return
	ovmui.view_mode = (ovmui.view_mode == OVERMAP_VIEW_NAV) ? OVERMAP_VIEW_MAP : OVERMAP_VIEW_NAV
	ovmui.rebuild_tile_pool()
	for(var/obj/abstract/mind_ui_element/E in ovmui.elements)
		if(istype(E, /obj/abstract/mind_ui_element/overmap_ship_marker) \
			|| istype(E, /obj/abstract/mind_ui_element/overmap_sensor_cone))
			E.UpdateIcon()


/obj/abstract/mind_ui_element/hoverable/overmap_recenter
	icon = 'icons/ui/16x16.dmi'
	icon_state = "rewind"
	layer = MIND_UI_BUTTON
	offset_x = OVERMAP_UI_SIZE/2 - 44
	offset_y = OVERMAP_UI_SIZE/2 - 8

/obj/abstract/mind_ui_element/hoverable/overmap_recenter/Click()
	var/datum/mind_ui/overmap_base/ovmui = parent
	if(!ovmui || !ovmui.linked_shuttle)
		return
	ovmui.auto_follow = TRUE
	ovmui.camera_x = ovmui.linked_shuttle.x || 13
	ovmui.camera_y = ovmui.linked_shuttle.y || 13
	ovmui.rebuild_tile_pool()


////////////////////////////////////////////////////////////////////
//                                                                //
//          /datum/mind_ui/overmap_base/helm — abstract           //
//                                                                //
////////////////////////////////////////////////////////////////////

// Base helm UI. Adds throttle slider, click-mode toggle, and dock button on
// top of the read-only viewport. Subtypes (free / preset) own click handling
// and route enumeration.

/datum/mind_ui/overmap_base/helm
	uniqueID = "overmap_base_helm"
	element_types_to_spawn = list(
		/obj/abstract/mind_ui_element/overmap_base_bg,
		/obj/abstract/mind_ui_element/overmap_sensor_cone,
		/obj/abstract/mind_ui_element/overmap_ship_marker,
		/obj/abstract/mind_ui_element/overmap_hud_text,
		/obj/abstract/mind_ui_element/hoverable/overmap_close,
		/obj/abstract/mind_ui_element/hoverable/movable/overmap_move,
		/obj/abstract/mind_ui_element/hoverable/overmap_mode_toggle,
		/obj/abstract/mind_ui_element/hoverable/overmap_recenter,
		/obj/abstract/mind_ui_element/hoverable/movable/overmap_throttle,
		/obj/abstract/mind_ui_element/hoverable/overmap_full_stop,
		/obj/abstract/mind_ui_element/hoverable/overmap_dock_button,
	)


////////////////////////////////////////////////////////////////////
//                                                                //
//             /datum/mind_ui/overmap_base/helm/free              //
//                                                                //
////////////////////////////////////////////////////////////////////

/datum/mind_ui/overmap_base/helm/free
	uniqueID = "shuttle_helm_free"
	var/click_mode = OVERMAP_CLICK_SET_COURSE


/datum/mind_ui/overmap_base/helm/free/SpawnElements()
	..()
	// Add click-mode toggle and abort button (free-only).
	var/obj/abstract/mind_ui_element/E1 = new /obj/abstract/mind_ui_element/hoverable/overmap_click_mode_toggle(null, src)
	elements += E1
	var/obj/abstract/mind_ui_element/E2 = new /obj/abstract/mind_ui_element/hoverable/overmap_abort_course(null, src)
	elements += E2
	if(mind?.current?.client)
		mind.current.client.screen |= E1
		mind.current.client.screen |= E2


// Free-nav uses hoverable tile elements so the player can click them.
/datum/mind_ui/overmap_base/helm/free/make_tile_element()
	return new /obj/abstract/mind_ui_element/hoverable/overmap_tile_clickable(null, src)


/datum/mind_ui/overmap_base/helm/free/on_tile_clicked(tx, ty)
	if(!linked_shuttle)
		return
	if(is_overmap_shift_end_lockout())
		var/mob/M = mind?.current
		if(M)
			to_chat(M, "<span class='warning'>Shift-end lockout — only preset routes allowed.</span>")
		return

	var/list/bodies = SSovermap.get_bodies_at(tx, ty)
	var/list/co_shuttles = SSovermap.get_shuttles_at(tx, ty) - linked_shuttle

	switch(click_mode)
		if(OVERMAP_CLICK_SET_COURSE)
			// Multi-target tiles open the dock selector first.
			if(bodies.len + co_shuttles.len > 1)
				open_dock_selector(tx, ty)
				return
			var/datum/overmap_body/target = bodies.len ? bodies[1] : null
			var/list/path = chessboard_path(linked_shuttle.x, linked_shuttle.y, tx, ty)
			linked_shuttle.begin_overmap_travel(path, target, mind?.current)
		if(OVERMAP_CLICK_ADD_WAYPOINT)
			linked_shuttle.append_waypoint(tx, ty, mind?.current)
		if(OVERMAP_CLICK_REMOVE_WAYPOINT)
			for(var/list/wp in linked_shuttle.waypoints)
				if(wp.len >= 2 && wp[1] == tx && wp[2] == ty)
					linked_shuttle.waypoints -= list(wp)
					break
			SSovermap.notify_ship_moved(linked_shuttle)


/datum/mind_ui/overmap_base/helm/free/proc/open_dock_selector(tx, ty)
	var/datum/mind_ui/overmap_base/helm/free/dock_selector/sub = new(mind)
	sub.parent = src
	sub.linked_shuttle = linked_shuttle
	sub.target_x = tx
	sub.target_y = ty
	subUIs += sub
	sub.populate_targets()
	sub.Display()


////////////////////////////////////////////////////////////////////
//                                                                //
//             /datum/mind_ui/overmap_base/helm/preset            //
//                                                                //
////////////////////////////////////////////////////////////////////

/datum/mind_ui/overmap_base/helm/preset
	uniqueID = "shuttle_helm_preset"
	var/datum/shuttle_route/selected_route = null


/datum/mind_ui/overmap_base/helm/preset/SpawnElements()
	..()
	var/obj/abstract/mind_ui_element/E = new /obj/abstract/mind_ui_element/overmap_route_list(null, src)
	elements += E
	if(mind?.current?.client)
		mind.current.client.screen |= E


// Preset helms ignore tile clicks entirely — routing is via the route list.
/datum/mind_ui/overmap_base/helm/preset/on_tile_clicked(tx, ty)
	return


// Filter callback applied to preset_routes when rendering the route list.
// During shift-end lockout, only Outpost-pickup and Centcomm-jump survive.
/datum/mind_ui/overmap_base/helm/preset/proc/route_filter(datum/shuttle_route/R)
	if(is_overmap_shift_end_lockout())
		if(istype(R, /datum/shuttle_route/end_of_shift_centcomm))
			return TRUE
		// Outpost-pickup will be added in Phase 6 — for now, allow only the
		// end_of_shift route during lockout.
		return FALSE
	return TRUE


/datum/mind_ui/overmap_base/helm/preset/proc/launch_selected_route()
	if(!selected_route || !linked_shuttle)
		return
	if(!selected_route.is_available(linked_shuttle, mind?.current))
		var/mob/M = mind?.current
		if(M)
			to_chat(M, "<span class='warning'>Route is not available.</span>")
		return
	var/list/path = selected_route.resolve_waypoints(linked_shuttle)
	if(!path)
		var/mob/M = mind?.current
		if(M)
			to_chat(M, "<span class='warning'>Route could not resolve a path.</span>")
		return
	linked_shuttle.set_throttle(selected_route.throttle_override, mind?.current)
	linked_shuttle.begin_overmap_travel(path, selected_route.destination, mind?.current)


////////////////////////////////////////////////////////////////////
//                                                                //
//      /datum/mind_ui/overmap_base/helm/free/dock_selector       //
//                                                                //
////////////////////////////////////////////////////////////////////

// Sub-UI surfaced when a free-nav helm clicks a tile that has multiple
// dockable targets — bodies and / or other shuttles. Enumerates everything
// and lets the player commit to one.
/datum/mind_ui/overmap_base/helm/free/dock_selector
	uniqueID = "overmap_dock_selector"
	display_with_parent = TRUE
	x = "CENTER"
	y = "CENTER"

	var/datum/shuttle/linked_shuttle = null
	var/target_x = 0
	var/target_y = 0
	var/list/dockable_bodies = list()
	var/list/dockable_shuttles = list()


/datum/mind_ui/overmap_base/helm/free/dock_selector/proc/populate_targets()
	dockable_bodies = list()
	dockable_shuttles = list()
	if(!SSovermap)
		return
	for(var/datum/overmap_body/B in SSovermap.get_bodies_at(target_x, target_y))
		if(B.linked_port)
			dockable_bodies += B
	for(var/datum/shuttle/other in SSovermap.get_shuttles_at(target_x, target_y))
		if(other == linked_shuttle)
			continue
		if(other.linked_port)
			dockable_shuttles += other


/datum/mind_ui/overmap_base/helm/free/dock_selector/proc/select_body(datum/overmap_body/B)
	if(!B || !linked_shuttle)
		return
	var/list/path = chessboard_path(linked_shuttle.x, linked_shuttle.y, target_x, target_y)
	linked_shuttle.begin_overmap_travel(path, B, mind?.current)
	Hide()


/datum/mind_ui/overmap_base/helm/free/dock_selector/proc/select_shuttle(datum/shuttle/other)
	if(!other || !linked_shuttle)
		return
	linked_shuttle.destination_port = other.linked_port
	var/list/path = chessboard_path(linked_shuttle.x, linked_shuttle.y, target_x, target_y)
	linked_shuttle.begin_overmap_travel(path, null, mind?.current)
	Hide()


////////////////////////////////////////////////////////////////////
//                                                                //
//                       HELM ELEMENTS                            //
//                                                                //
////////////////////////////////////////////////////////////////////

// ----- Throttle slider ----------------------------------------------------

/obj/abstract/mind_ui_element/hoverable/movable/overmap_throttle
	icon = 'icons/ui/overmap/bodies.dmi'
	icon_state = "throttle"
	layer = MIND_UI_BUTTON
	offset_x = -OVERMAP_UI_SIZE/2 - 24
	offset_y = 0
	move_whole_ui = FALSE
	var/slider_min_y = -50
	var/slider_max_y = 50

/obj/abstract/mind_ui_element/hoverable/movable/overmap_throttle/New(turf/loc, datum/mind_ui/P)
	. = ..(loc, P)
	var/icon/I = new /icon('icons/ui/overmap/bodies.dmi', "")
	I.Scale(16, 16)
	I.Blend("#80E080", ICON_OVERLAY)
	icon = I
	UpdateUIScreenLoc()

/obj/abstract/mind_ui_element/hoverable/movable/overmap_throttle/MoveLoc(params)
	..()
	// After ..() updates offset_y, clamp it and translate to a 0..1 throttle.
	offset_y = clamp(offset_y, slider_min_y, slider_max_y)
	UpdateUIScreenLoc()
	var/datum/mind_ui/overmap_base/helm/parent_helm = parent
	if(!parent_helm || !parent_helm.linked_shuttle)
		return
	var/throttle_value = (offset_y - slider_min_y) / (slider_max_y - slider_min_y)
	parent_helm.linked_shuttle.set_throttle(throttle_value, parent_helm.mind?.current)


// ----- Full-stop button ---------------------------------------------------

/obj/abstract/mind_ui_element/hoverable/overmap_full_stop
	icon = 'icons/ui/16x16.dmi'
	icon_state = "stop"
	layer = MIND_UI_BUTTON
	offset_x = -OVERMAP_UI_SIZE/2 - 24
	offset_y = -64

/obj/abstract/mind_ui_element/hoverable/overmap_full_stop/Click()
	var/datum/mind_ui/overmap_base/helm/parent_helm = parent
	if(!parent_helm || !parent_helm.linked_shuttle)
		return
	parent_helm.linked_shuttle.full_stop(parent_helm.mind?.current)


// ----- Click-mode toggle (free-nav only) ----------------------------------

/obj/abstract/mind_ui_element/hoverable/overmap_click_mode_toggle
	icon = 'icons/ui/16x16.dmi'
	icon_state = "expand"
	layer = MIND_UI_BUTTON
	offset_x = OVERMAP_UI_SIZE/2 - 8
	offset_y = -32
	element_flags = MINDUI_FLAG_TOOLTIP
	tooltip_title = "Click mode"
	tooltip_content = "Toggle between Set Course / Add Waypoint / Remove Waypoint"

/obj/abstract/mind_ui_element/hoverable/overmap_click_mode_toggle/Click()
	var/datum/mind_ui/overmap_base/helm/free/parent_free = parent
	if(!parent_free)
		return
	parent_free.click_mode = (parent_free.click_mode + 1) % 3


// ----- Abort-course button (free-nav only) --------------------------------

/obj/abstract/mind_ui_element/hoverable/overmap_abort_course
	icon = 'icons/ui/16x16.dmi'
	icon_state = "close"
	layer = MIND_UI_BUTTON
	offset_x = OVERMAP_UI_SIZE/2 - 8
	offset_y = -50

/obj/abstract/mind_ui_element/hoverable/overmap_abort_course/Click()
	var/datum/mind_ui/overmap_base/helm/parent_helm = parent
	if(!parent_helm || !parent_helm.linked_shuttle)
		return
	parent_helm.linked_shuttle.clear_waypoints(parent_helm.mind?.current)


// ----- Dock button (parked-only) ------------------------------------------

/obj/abstract/mind_ui_element/hoverable/overmap_dock_button
	icon = 'icons/ui/16x16.dmi'
	icon_state = "rewind"
	layer = MIND_UI_BUTTON
	offset_x = OVERMAP_UI_SIZE/2 - 8
	offset_y = -68

/obj/abstract/mind_ui_element/hoverable/overmap_dock_button/Click()
	var/datum/mind_ui/overmap_base/helm/parent_helm = parent
	if(!parent_helm || !parent_helm.linked_shuttle)
		return
	var/datum/shuttle/S = parent_helm.linked_shuttle
	if(S.docked_at)
		return  // already docked
	var/total_targets = SSovermap.get_bodies_at(S.x, S.y).len + SSovermap.get_shuttles_at(S.x, S.y).len
	if(!total_targets)
		return
	if(istype(parent_helm, /datum/mind_ui/overmap_base/helm/free))
		var/datum/mind_ui/overmap_base/helm/free/parent_free = parent_helm
		parent_free.open_dock_selector(S.x, S.y)


// ----- Hoverable tile (free-nav variant) ----------------------------------

/obj/abstract/mind_ui_element/hoverable/overmap_tile_clickable
	icon = 'icons/ui/overmap/bodies.dmi'
	icon_state = "tile"
	layer = MIND_UI_BACK + 0.1
	mouse_opacity = 1
	element_flags = MINDUI_FLAG_TOOLTIP
	var/tile_x = 0
	var/tile_y = 0

/obj/abstract/mind_ui_element/hoverable/overmap_tile_clickable/proc/RefreshAppearance()
	// Same body as the read-only overmap_tile.RefreshAppearance — duplicated
	// because BYOND DM doesn't let us inherit Click() from one base and
	// Refresh from another. Keep these in sync.
	var/datum/mind_ui/overmap_base/ovmui = parent
	if(!ovmui || !ovmui.linked_shuttle)
		return
	var/datum/shuttle/S = ovmui.linked_shuttle
	var/px = ovmui.get_tile_pixels()
	var/list/coord = ovmui.world_to_viewport(tile_x, tile_y)
	offset_x = coord["x"] - px / 2
	offset_y = coord["y"] - px / 2

	var/fog_color = "#101018"
	if(S.tile_visited && S.tile_visited[tile_x][tile_y])
		fog_color = "#3C5078"
	else if(S.tile_scanned && S.tile_scanned[tile_x][tile_y])
		fog_color = "#283050"

	var/icon/tile_icon = new /icon('icons/ui/overmap/bodies.dmi', "")
	tile_icon.Scale(px, px)
	tile_icon.Blend(fog_color, ICON_OVERLAY)
	tile_icon.DrawBox("#202830", 1, 1, px, 1)
	tile_icon.DrawBox("#202830", 1, 1, 1, px)

	if(fog_color != "#101018")
		for(var/datum/overmap_body/B in SSovermap.get_bodies_at(tile_x, tile_y))
			if(B.hidden || !S.knows_body(B))
				continue
			var/icon/dot = new /icon('icons/ui/overmap/bodies.dmi', "")
			var/dot_size = max(round(px * 0.6), 4)
			dot.Scale(dot_size, dot_size)
			dot.Blend(body_color_for(B), ICON_OVERLAY)
			tile_icon.Blend(dot, ICON_OVERLAY, round((px - dot_size) / 2), round((px - dot_size) / 2))
		for(var/datum/overmap_hazard/H in SSovermap.get_hazards_at(tile_x, tile_y))
			if(!S.knows_hazard(H))
				continue
			var/icon/haz = new /icon('icons/ui/overmap/bodies.dmi', "")
			var/haz_size = max(round(px * 0.4), 3)
			haz.Scale(haz_size, haz_size)
			haz.Blend(H.color || "#A02020", ICON_OVERLAY)
			tile_icon.Blend(haz, ICON_OVERLAY, 1, 1)

	icon = tile_icon
	tooltip_title = "Tile ([tile_x],[tile_y])"
	var/list/tooltip_lines = list()
	for(var/datum/overmap_body/B in SSovermap.get_bodies_at(tile_x, tile_y))
		if(S.knows_body(B))
			tooltip_lines += B.name
	for(var/datum/overmap_hazard/H in SSovermap.get_hazards_at(tile_x, tile_y))
		if(S.knows_hazard(H))
			tooltip_lines += "Hazard: [H.name]"
	tooltip_content = tooltip_lines.len ? jointext(tooltip_lines, "\n") : "Empty space."
	UpdateUIScreenLoc()


/obj/abstract/mind_ui_element/hoverable/overmap_tile_clickable/Click(location, control, params)
	var/datum/mind_ui/overmap_base/ovmui = parent
	if(!ovmui)
		return
	ovmui.on_tile_clicked(tile_x, tile_y)


// ----- Route list (preset helm) -------------------------------------------

/obj/abstract/mind_ui_element/overmap_route_list
	layer = MIND_UI_FRONT + 0.5
	offset_x = OVERMAP_UI_SIZE/2 + 16
	offset_y = OVERMAP_UI_SIZE/2 - 50

/obj/abstract/mind_ui_element/overmap_route_list/New(turf/loc, datum/mind_ui/P)
	. = ..(loc, P)
	maptext_width = 200
	maptext_height = 240
	UpdateIcon()

/obj/abstract/mind_ui_element/overmap_route_list/UpdateIcon(appear = FALSE)
	var/datum/mind_ui/overmap_base/helm/preset/parent_preset = parent
	if(!parent_preset || !parent_preset.linked_shuttle)
		maptext = ""
		return
	var/list/lines = list("<b>Routes</b>")
	for(var/datum/shuttle_route/R in parent_preset.linked_shuttle.preset_routes)
		if(!parent_preset.route_filter(R))
			continue
		if(!R.is_available(parent_preset.linked_shuttle, parent_preset.mind?.current))
			continue
		// One line for the route name + a smaller-font description below it.
		lines += "<a href='?src=\ref[parent_preset];route=\ref[R]'>[R.name]</a>"
		if(R.description_text)
			lines += "<span style='color:#A0A0A0;font-size:6pt;'>&nbsp;&nbsp;[R.description_text]</span>"
	if(lines.len <= 1)
		lines += "(no routes available)"
	maptext = {"<div style="font-family: Fixedsys, monospace; font-size: 7pt; color: #FFE0A0; line-height: 11px; padding: 4px;">[jointext(lines, "<br>")]</div>"}


// Topic handler on the helm/preset UI for route-link clicks.
/datum/mind_ui/overmap_base/helm/preset/Topic(href, list/href_list)
	if(href_list["route"])
		var/datum/shuttle_route/R = locate(href_list["route"])
		if(R && (R in linked_shuttle.preset_routes))
			selected_route = R
			launch_selected_route()


////////////////////////////////////////////////////////////////////
//                                                                //
//                          HELPERS                               //
//                                                                //
////////////////////////////////////////////////////////////////////

// Returns TRUE during the shift-end lockout window. vg has no
// SSticker.shuttle_end_phase flag — we use the emergency_shuttle online state
// as the canonical signal. If a future PR adds an explicit flag, switch here.
/proc/is_overmap_shift_end_lockout()
	if(emergency_shuttle && emergency_shuttle.online)
		return TRUE
	return FALSE


#undef OVERMAP_UI_SIZE
#undef OVERMAP_UI_PADDING
#undef OVERMAP_COLOR_FOG
#undef OVERMAP_COLOR_SCANNED
#undef OVERMAP_COLOR_VISITED
#undef OVERMAP_COLOR_GRID_LINE
#undef OVERMAP_COLOR_BODY_ANCHOR
#undef OVERMAP_COLOR_BODY_PLANET
#undef OVERMAP_COLOR_BODY_OUTPOST
#undef OVERMAP_COLOR_BODY_HOMEBASE
#undef OVERMAP_COLOR_BODY_ENCOUNTER
#undef OVERMAP_COLOR_BODY_CENTCOMM
#undef OVERMAP_COLOR_BODY_GENERIC
#undef OVERMAP_COLOR_HAZARD
#undef OVERMAP_COLOR_SHIP
#undef OVERMAP_COLOR_CONE
#undef OVERMAP_COLOR_WAYPOINT
#undef OVERMAP_COLOR_COURSE
