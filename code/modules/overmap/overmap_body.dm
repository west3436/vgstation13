// /datum/overmap_body — a single dockable, scannable, or flavor-only object on
// the overmap grid. Owned by SSovermap. See OVERMAP_DESIGN.md "Data model".

/datum/overmap_body
	var/name = "Unknown Object"
	var/desc = null
	var/x = 0                                  // 1..OVERMAP_WIDTH
	var/y = 0                                  // 1..OVERMAP_HEIGHT
	var/body_type = OVERMAP_BODY_GENERIC
	var/icon = 'icons/ui/overmap/bodies.dmi'
	var/icon_state = "planet"
	var/color = null
	var/hidden = FALSE                          // never appears in UI even if scanned
	var/is_anchor = FALSE                       // pre-revealed to all shuttles at roundstart
	var/requires_admin_approval = FALSE         // begin_overmap_travel routes through admin request before launching
	var/list/sub_pois = list()                  // flavor-only POIs surfaced via tooltip text

	// vlevel + dock binding. Both nullable: a body without linked_port is non-dockable
	// (flavor only); a body without linked_vz has nothing to land on.
	var/datum/virtual_z/linked_vz = null
	var/obj/docking_port/destination/linked_port = null

	// Despawn lifecycle. auto_despawn flips on for encounter subtypes; the others ignore it.
	var/auto_despawn = FALSE
	var/despawn_timer_id = null
	var/despawn_idle_time = 10 MINUTES
	var/created_at = 0

	// Per-body event hooks fired by SSovermap and the shuttle pipeline.
	// Phase 1 leaves these empty; later phases attach event handlers.
	var/list/on_arrival_events = list()
	var/list/on_discovery_events = list()


/datum/overmap_body/New(loc_x = 0, loc_y = 0)
	. = ..()
	x = loc_x
	y = loc_y
	created_at = world.time


/datum/overmap_body/Destroy()
	cancel_despawn_timer()
	if(linked_vz)
		linked_vz.overmap_body = null
		linked_vz = null
	linked_port = null
	..()


/datum/overmap_body/proc/distance_to(datum/overmap_body/B)
	if(!B)
		return -1
	return chessboard_dist(x - B.x, y - B.y)


// Default arrival/departure hooks. Subtypes (encounter, etc.) override.
/datum/overmap_body/proc/on_shuttle_arrived(datum/shuttle/S)
	return

/datum/overmap_body/proc/on_shuttle_departed(datum/shuttle/S)
	return


/datum/overmap_body/proc/can_despawn()
	if(!auto_despawn)
		return FALSE
	if(linked_vz && linked_vz.get_living_players().len)
		return FALSE
	return TRUE


/datum/overmap_body/proc/reset_despawn_timer()
	if(!auto_despawn)
		return
	cancel_despawn_timer()
	despawn_timer_id = add_timer(new /callback(src, nameof(src::despawn())), despawn_idle_time)


/datum/overmap_body/proc/cancel_despawn_timer()
	if(despawn_timer_id)
		del_timer(despawn_timer_id)
		despawn_timer_id = null


/datum/overmap_body/proc/despawn()
	despawn_timer_id = null
	if(!can_despawn())
		reset_despawn_timer()
		return
	if(SSovermap)
		SSovermap.remove_body(src)
	qdel(src)


// ---------------------------------------------------------------------------
// Stub subtypes — Phase 1 only declares the type hierarchy. Phase 4 / 6 / 7
// add behavior.
// ---------------------------------------------------------------------------

/datum/overmap_body/generic
	body_type = OVERMAP_BODY_GENERIC
	icon_state = "generic"

/datum/overmap_body/planet
	name = "Uncharted Planet"
	body_type = OVERMAP_BODY_PLANET
	icon_state = "planet"

/datum/overmap_body/outpost
	name = "Outpost"
	body_type = OVERMAP_BODY_OUTPOST
	icon_state = "outpost"

/datum/overmap_body/homebase
	name = "Homebase"
	body_type = OVERMAP_BODY_HOMEBASE
	icon_state = "homebase"

/datum/overmap_body/encounter
	name = "Anomalous Signal"
	body_type = OVERMAP_BODY_ENCOUNTER
	icon_state = "encounter"
	auto_despawn = TRUE
	var/distress_flag = FALSE


/datum/overmap_body/encounter/New(loc_x = 0, loc_y = 0)
	. = ..()
	reset_despawn_timer()


/datum/overmap_body/encounter/on_shuttle_arrived(datum/shuttle/S)
	cancel_despawn_timer()


/datum/overmap_body/encounter/on_shuttle_departed(datum/shuttle/S)
	if(!linked_vz || !linked_vz.get_living_players().len)
		reset_despawn_timer()

/datum/overmap_body/centcomm
	name = "Central Command"
	body_type = OVERMAP_BODY_CENTCOMM
	icon_state = "centcomm"
	requires_admin_approval = TRUE
