// /datum/shuttle_route — declarative description of a launch destination, used
// by the preset-helm UI and reachable as a fallback by the free-helm UI.
//
// Phase 1 only declares the type. Phase 2 wires `is_available` to the shuttle's
// docked_at field; Phase 4 introduces dynamic-origin subtypes that override
// resolve_waypoints. Phase 7+ adds end-of-shift, mining, etc. variants.

/datum/shuttle_route
	var/name = "Unnamed Route"
	var/desc = null
	var/list/waypoints = list()                 // static fallback waypoints, list(list(x,y), ...)
	var/datum/overmap_body/origin = null        // must match shuttle.docked_at to be selectable
	var/datum/overmap_body/destination = null   // final docking target (optional if route ends in empty space)
	var/list/req_access = list()
	var/throttle_override = 1.0                 // throttle preset shuttles fly at
	var/description_text = null                 // shown on the route button


// Resolve a route to a concrete waypoint sequence at launch time. Subtypes
// override this to pathfind dynamically (e.g. Outpost-to-Odyssey).
/datum/shuttle_route/proc/resolve_waypoints(datum/shuttle/caller)
	return waypoints.Copy()


// Visibility / launch gate. Phase 2 patches this to honor caller.docked_at.
/datum/shuttle_route/proc/is_available(datum/shuttle/caller, mob/user)
	if(req_access.len && user && !can_access(user.GetAccess(), req_access))
		return FALSE
	return TRUE
