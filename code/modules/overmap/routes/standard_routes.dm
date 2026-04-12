// Generic preset routes that apply to most converted shuttles. Phase 6 uses
// `return_to_outpost` as a baseline so every overmap-controlled shuttle has at
// least one usable route in its helm UI. Phase 6 follow-ups can add more
// shuttle-specific routes (mining → asteroid, trade → bazaar, etc.).

// Returns a chessboard path from the caller's current overmap position to the
// nearest body of /datum/overmap_body/outpost type. If none exists, returns
// null and the route is non-launchable.
/datum/shuttle_route/return_to_outpost
	name = "Return to NT Outpost"
	description_text = "Plot a course to the nearest NT outpost on the overmap."
	throttle_override = 1.0


/datum/shuttle_route/return_to_outpost/is_available(datum/shuttle/caller, mob/user)
	if(!find_outpost_target())
		return FALSE
	return ..()


/datum/shuttle_route/return_to_outpost/resolve_waypoints(datum/shuttle/caller)
	var/datum/overmap_body/op = find_outpost_target()
	if(!op || !caller)
		return null
	destination = op
	return chessboard_path(caller.x || 13, caller.y || 13, op.x, op.y)


/proc/find_outpost_target()
	if(!SSovermap)
		return null
	for(var/datum/overmap_body/B in SSovermap.bodies)
		if(istype(B, /datum/overmap_body/outpost))
			return B
	return null
