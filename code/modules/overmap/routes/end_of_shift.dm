// End-of-shift bluespace jump route + admin approval flow.
//
// /datum/shuttle_route/end_of_shift_centcomm is added to every overmap-
// controlled shuttle's preset_routes list during setup_shuttles(). It is only
// `is_available` during the shift-end window (see is_overmap_shift_end_lockout
// in mindUI/overmap.dm). Launching it routes through the admin-approval flow
// because the Centcomm body is `requires_admin_approval = TRUE`.

/datum/shuttle_route/end_of_shift_centcomm
	name = "Bluespace Jump: Central Command"
	description_text = "End-of-shift jump. Crew aboard now."
	throttle_override = 1.0


/datum/shuttle_route/end_of_shift_centcomm/is_available(datum/shuttle/caller, mob/user)
	if(!is_overmap_shift_end_lockout())
		return FALSE
	return ..()


/datum/shuttle_route/end_of_shift_centcomm/resolve_waypoints(datum/shuttle/caller)
	if(!SSovermap)
		return null
	var/datum/overmap_body/cc = get_centcomm_body()
	if(!cc)
		return null
	return chessboard_path(caller.x, caller.y, cc.x, cc.y)


/proc/get_centcomm_body()
	if(!SSovermap)
		return null
	for(var/datum/overmap_body/B in SSovermap.bodies)
		if(istype(B, /datum/overmap_body/centcomm))
			return B
	return null


// Admin-approval gate for `requires_admin_approval` bodies. Phase 2 left this
// as an early-return stub on /datum/shuttle/begin_overmap_travel; Phase 4
// wires it to the existing message_admins flow.
/proc/request_admin_approval_for_dock(datum/shuttle/S, datum/overmap_body/target, mob/user)
	if(!S || !target || !user)
		return
	var/href = "<a href='?_src_=holder;overmap_admin_approve_dock=1;shuttle=\ref[S];body=\ref[target];user=\ref[user]'>APPROVE</a>"
	var/href_deny = "<a href='?_src_=holder;overmap_admin_approve_dock=0;shuttle=\ref[S];body=\ref[target];user=\ref[user]'>DENY</a>"
	message_admins("[key_name(user)] is requesting permission to dock [S.name] at [target.name] (overmap). [href] / [href_deny]")
	to_chat(user, "<span class='notice'>Awaiting admin approval to dock at [target.name]...</span>")
