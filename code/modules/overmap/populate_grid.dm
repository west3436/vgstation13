// Roundstart grid population. Called from /datum/subsystem/overmap/Initialize.
//
// Phase 1 places two hand-curated test bodies (homebase + outpost) and two
// randomized hazards. Phase 4 wires the homebase + outpost to real vlevels and
// docking ports. Phase 6 adds shuttle-route-driven bodies (mining asteroid,
// trade hub, ...). Phase 7 adds the real hazard set + encounter spawning.

/datum/subsystem/overmap/proc/populate_grid()
	place_anchor_bodies()
	place_randomized_planets(2)
	place_randomized_hazards(2)
	place_map_specific_bodies()


/datum/subsystem/overmap/proc/place_anchor_bodies()
	// Phase 1 test stand-in for the Odyssey homebase. Placed dead-center.
	// Phase 4 reassigns linked_vz / linked_port to the real Odyssey vlevel.
	var/datum/overmap_body/homebase/hb = new(13, 13)
	hb.name = "Odyssey Homebase (test)"
	hb.is_anchor = TRUE
	add_body(hb)

	// Phase 1 test outpost. Adjacent so the eventual UI can show two anchor
	// markers in close proximity.
	var/datum/overmap_body/outpost/op = new(10, 10)
	op.name = "NT Outpost (test)"
	op.is_anchor = TRUE
	add_body(op)


/datum/subsystem/overmap/proc/place_randomized_planets(target_count)
	for(var/i = 1 to target_count)
		var/list/coords = find_free_tile(min_sep_from_bodies = 2)
		if(!coords)
			warning("Overmap: place_randomized_planets exhausted free tiles after [i - 1] of [target_count]")
			return
		var/datum/overmap_body/planet/P = new(coords[1], coords[2])
		add_body(P)


/datum/subsystem/overmap/proc/place_randomized_hazards(target_count)
	for(var/i = 1 to target_count)
		var/list/coords = find_free_tile(require_no_body = FALSE, require_no_hazard = TRUE)
		if(!coords)
			warning("Overmap: place_randomized_hazards exhausted free tiles after [i - 1] of [target_count]")
			return
		var/datum/overmap_hazard/asteroid_field/H = new(coords[1], coords[2])
		add_hazard(H)


// Hook for Phase 4 / 6 to add map-specific bodies (Centcomm, Vox bazaar,
// mining asteroid, etc.). Phase 1 leaves it empty.
/datum/subsystem/overmap/proc/place_map_specific_bodies()
	return
