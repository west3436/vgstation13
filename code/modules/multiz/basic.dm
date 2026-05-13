// If you add a more comprehensive system, just untick this file.
//
// NOTE: The legacy z-id-based helpers (HasAbove, HasBelow, GetAbove, GetBelow,
// GetConnectedZlevels) have been removed. Use the vlevel-aware helpers in
// _HELPERS.dm: HasAboveAt(turf), HasBelowAt(turf), GetAboveTurf(turf),
// GetBelowTurf(turf), GetConnectedFloors(virtual_z).

/proc/AreConnectedZLevels(var/zA, var/zB)
	if(zA == zB)
		return TRUE
	if(zA < 1 || zB < 1 || zA > world.maxz || zB > world.maxz)
		return FALSE
	var/datum/zLevel/ZA = map.zLevels[zA]
	if(!ZA)
		return FALSE
	// Any vlevel sitting on ZA whose connected-floors chain includes a vlevel on ZB counts.
	for(var/datum/virtual_z/V in ZA.virtual_z_levels)
		for(var/datum/virtual_z/F in GetConnectedFloors(V))
			if(F.parent_z && F.parent_z.z == zB)
				return TRUE
	return FALSE

/proc/GetOpenConnectedZlevels(var/atom/atom)
	var/turf/turf = get_turf(atom)
	if(!turf)
		return list()
	. = list(turf.z)
	var/datum/virtual_z/here = vz_at_loc(turf.x, turf.y, turf.z)
	if(!here)
		return .
	// Walk down: at each floor, the level below counts only if the turf directly below is open/visible space.
	var/datum/virtual_z/cur = here
	var/turf/cursor = turf
	while(cur && cur.vlevel_below)
		var/turf/below = GetBelowTurf(cursor)
		if(!below || !isvisiblespace(below))
			break
		if(!(below.z in .))
			. += below.z
		cur = cur.vlevel_below
		cursor = below
	// Walk up: at each floor, the level above counts only if the turf above us (relative to our cursor) is open/visible space.
	cur = here
	cursor = turf
	while(cur && cur.vlevel_above)
		var/turf/above = GetAboveTurf(cursor)
		if(!above || !isvisiblespace(above))
			break
		if(!(above.z in .))
			. += above.z
		cur = cur.vlevel_above
		cursor = above

/proc/AreOpenConnectedZLevels(var/zA, var/zB)
	return zA == zB || (zB in GetOpenConnectedZlevels(zA))

/proc/get_zstep(ref, dir)
	if(dir == UP)
		. = GetAboveTurf(get_turf(ref))
	else if (dir == DOWN)
		. = GetBelowTurf(get_turf(ref))
	else
		. = get_step(ref, dir)
