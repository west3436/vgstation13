// Reusable Valid_*() predicates and static structural validation for mindUI.
// Combine predicates inside a UI's Valid() override instead of re-implementing
// the same mob/role/adjacency checks. Each predicate returns TRUE or FALSE.
//
// Usage:
//   /datum/mind_ui/my_ui/Valid()
//       return Valid_Living() && Valid_HasRole(MALF) && Valid_Adjacent(target)


////////////////////////////////////////////////////////////////////
//																  //
//						  MOB STATE / ROLE						  //
//																  //
////////////////////////////////////////////////////////////////////

/datum/mind_ui/proc/Valid_Living()
	var/mob/living/L = GetUserAs(/mob/living)
	if (!L)
		return FALSE
	if (L.stat == DEAD)
		return FALSE
	return TRUE

/datum/mind_ui/proc/Valid_Conscious()
	var/mob/living/L = GetUserAs(/mob/living)
	if (!L)
		return FALSE
	return L.stat == CONSCIOUS

/datum/mind_ui/proc/Valid_HasRole(role_id)
	if (!mind)
		return FALSE
	// GetRole returns the role datum or FALSE (not null), so !isnull would be a constant TRUE.
	return mind.GetRole(role_id) ? TRUE : FALSE

/datum/mind_ui/proc/Valid_IsSilicon()
	if (!mind || !mind.current)
		return FALSE
	return issilicon(mind.current)

/datum/mind_ui/proc/Valid_IsAdmin()
	if (!mind || !mind.current || !mind.current.client)
		return FALSE
	var/client/C = mind.current.client
	return C.holder && (C.holder.rights & R_ADMIN)


////////////////////////////////////////////////////////////////////
//																  //
//						 LOCATION / ADJACENCY					  //
//																  //
////////////////////////////////////////////////////////////////////

// Uses mob.Adjacent(); handles diagonal/non-tile adjacency cases that get_dist does not.
/datum/mind_ui/proc/Valid_Adjacent(atom/target)
	if (!target)
		return FALSE
	if (!mind || !mind.current)
		return FALSE
	return mind.current.Adjacent(target)

// Uses get_dist() (Chebyshev distance in integer tiles). Use Valid_Adjacent for the strict "next to" case.
/datum/mind_ui/proc/Valid_InRange(atom/target, range = 1)
	if (!target)
		return FALSE
	if (!mind || !mind.current)
		return FALSE
	return get_dist(mind.current, target) <= range

/datum/mind_ui/proc/Valid_SamevZ(atom/target)
	if (!target)
		return FALSE
	if (!mind || !mind.current)
		return FALSE
	var/datum/virtual_z/vz = mind.current.get_virtual_z()
	return vz && vz == target.get_virtual_z()

/datum/mind_ui/proc/Valid_OnVLevel(vz_type)
	if (!mind || !mind.current)
		return FALSE
	var/mob/M = mind.current
	var/datum/virtual_z/vz = vz_at_loc(M.x, M.y, M.z)
	if (!vz)
		return FALSE
	return vz.level_type == vz_type


////////////////////////////////////////////////////////////////////
//																  //
//						 INVENTORY / CONTAINER					  //
//																  //
////////////////////////////////////////////////////////////////////

/datum/mind_ui/proc/Valid_LockedTo(wanted_type)
	if (!mind || !mind.current)
		return FALSE
	return istype(mind.current.locked_to, wanted_type)

// Held items live in held_items[GRASP_LEFT_HAND] / held_items[GRASP_RIGHT_HAND]
// in this codebase, not the legacy l_hand/r_hand vars.
/datum/mind_ui/proc/Valid_HoldingItemOfType(wanted_type)
	var/mob/living/carbon/C = GetUserAs(/mob/living/carbon)
	if (!C)
		return FALSE
	if (istype(C.held_items[GRASP_LEFT_HAND], wanted_type))
		return TRUE
	if (istype(C.held_items[GRASP_RIGHT_HAND], wanted_type))
		return TRUE
	return FALSE

/datum/mind_ui/proc/Valid_InsideItemOfType(wanted_type)
	if (!mind || !mind.current)
		return FALSE
	return istype(mind.current.loc, wanted_type)


////////////////////////////////////////////////////////////////////
//																  //
//					   STATIC STRUCTURAL VALIDATION				  //
//																  //
////////////////////////////////////////////////////////////////////

// Walks a /datum/mind_ui subtype's initial() values and returns one of the
// MINDUI_VALID / MINDUI_INVALID_* codes. Called at unit-test time over every
// non-abstract subtype to catch schema mistakes (missing uniqueID, bad element
// path, out-of-range anchor, etc.) before they reach a runtime.

/proc/mindui_static_validate(var/uitype)
	var/datum/mind_ui/proto = uitype

	var/id = initial(proto.uniqueID)
	if (!id || id == "Default")
		return MINDUI_INVALID_NO_ID

	var/list/elems = initial(proto.element_types_to_spawn)
	if (elems)
		for (var/etype in elems)
			if (!ispath(etype, /obj/abstract/mind_ui_element))
				return MINDUI_INVALID_BAD_ICON

	var/list/subs = initial(proto.sub_uis_to_spawn)
	if (subs)
		for (var/stype in subs)
			if (!ispath(stype, /datum/mind_ui))
				return MINDUI_INVALID_BAD_SUB_UI

	var/x_val = initial(proto.x)
	if (!isnull(x_val) && !(x_val in list("LEFT", "RIGHT", "CENTER")))
		return MINDUI_INVALID_BAD_LOC

	var/y_val = initial(proto.y)
	if (!isnull(y_val) && !(y_val in list("TOP", "BOTTOM", "CENTER")))
		return MINDUI_INVALID_BAD_LOC

	var/grp = initial(proto.offset_layer)
	if (!(grp in list(MIND_UI_GROUP_A, MIND_UI_GROUP_B, MIND_UI_GROUP_C, MIND_UI_GROUP_D)))
		return MINDUI_INVALID_BAD_LOC

	return MINDUI_VALID

/proc/mindui_validate_code_name(code)
	switch (code)
		if (MINDUI_VALID)               return "VALID"
		if (MINDUI_INVALID_NO_ID)       return "NO_ID (uniqueID missing or 'Default')"
		if (MINDUI_INVALID_DUP_ID)      return "DUP_ID (duplicate uniqueID)"
		if (MINDUI_INVALID_BAD_ICON)    return "BAD_ICON (element_types_to_spawn entry is not /obj/abstract/mind_ui_element)"
		if (MINDUI_INVALID_BAD_LOC)     return "BAD_LOC (x/y anchor or offset_layer out of range)"
		if (MINDUI_INVALID_NO_VALID)    return "NO_VALID (reserved)"
		if (MINDUI_INVALID_BAD_SUB_UI)  return "BAD_SUB_UI (sub_uis_to_spawn entry is not /datum/mind_ui)"
	return "UNKNOWN([code])"
