#define OPENSPACE_PLANE_START -23
#define OPENSPACE_PLANE_END -8
#define OPENSPACE_PLANE -25
#define OVER_OPENSPACE_PLANE -7

// Multi-z helpers — resolve through the mover's current vlevel.
// See docs/superpowers/specs/2026-05-13-multiz-vlevel-reconciliation-design.md

/proc/HasAboveAt(turf/T)
	if(!T)
		return FALSE
	var/datum/virtual_z/v = vz_at_loc(T.x, T.y, T.z)
	if(!v)
		return FALSE
	return HasAboveAt_vz(v)

/proc/HasAboveAt_vz(datum/virtual_z/v)
	return v.vlevel_above != null

/proc/HasBelowAt(turf/T)
	if(!T)
		return FALSE
	var/datum/virtual_z/v = vz_at_loc(T.x, T.y, T.z)
	if(!v)
		return FALSE
	return HasBelowAt_vz(v)

/proc/HasBelowAt_vz(datum/virtual_z/v)
	return v.vlevel_below != null

/proc/GetAboveTurf(turf/T)
	if(!T)
		return null
	var/datum/virtual_z/v = vz_at_loc(T.x, T.y, T.z)
	if(!v || !v.vlevel_above)
		return null
	var/datum/virtual_z/up = v.vlevel_above
	// Must fall inside upper floor's recomputed footprint.
	// Returns null if T sits outside the upper floor's recomputed footprint (no floor overhead here).
	if(T.x < up.x_min || T.x > up.x_max || T.y < up.y_min || T.y > up.y_max)
		return null
	if(!up.parent_z)
		return null
	return locate(T.x, T.y, up.parent_z.z)

/proc/GetBelowTurf(turf/T)
	if(!T)
		return null
	var/datum/virtual_z/v = vz_at_loc(T.x, T.y, T.z)
	if(!v || !v.vlevel_below)
		return null
	var/datum/virtual_z/down = v.vlevel_below
	if(!down.parent_z)
		return null
	return locate(T.x, T.y, down.parent_z.z)

/proc/GetConnectedFloors(datum/virtual_z/V)
	if(!V)
		return list()
	var/datum/virtual_z/anchor = V.group_anchor
	var/list/floors = list(anchor)
	var/datum/virtual_z/cur = anchor
	// Assumes acyclic vlevel_above chain (enforced by virtual_z setup; addFloorAbove/removeTopFloor preserve invariant).
	while(cur.vlevel_above)
		cur = cur.vlevel_above
		floors += cur
	return floors

/proc/GetVerticalDistance(turf/A, turf/B)
	if(!A || !B)
		return INFINITY
	var/datum/virtual_z/va = vz_at_loc(A.x, A.y, A.z)
	var/datum/virtual_z/vb = vz_at_loc(B.x, B.y, B.z)
	if(!va || !vb)
		return INFINITY
	if(va.group_anchor != vb.group_anchor)
		return INFINITY
	return abs(va.floor - vb.floor)

// ───────────────────────────────────────────────────────────────────────
// Z-level utility procs (distance math, openspace post-change hooks, etc.)
// Kept separate from the vlevel-aware directional helpers above; these
// operate on raw z-coords and atoms without caring about vlevel groups.
// ───────────────────────────────────────────────────────────────────────

/turf/proc/is_space()
	return 0

/turf/space/is_space()
	return 1

// Called after turf replaces old one
/turf/proc/post_change()
	levelupdate()
	var/turf/simulated/open/T = GetAboveTurf(src)
	if(istype(T))
		T.update_icon()

/proc/is_on_same_plane_or_station(var/z1, var/z2)
	if(z1 == z2)
		return 1
	if((z1 in map.zLevels) && (z2 in map.zLevels))
		return 1
	return 0

/proc/get_zs_away(atom/Loc1, atom/Loc2)
	if(Loc1.z == Loc2.z)
		return 0
	return GetVerticalDistance(get_turf(Loc1), get_turf(Loc2))

/proc/get_z_dist(atom/Loc1, atom/Loc2)
	var/dx = abs(Loc1.x - Loc2.x)
	var/dy = abs(Loc1.y - Loc2.y)
	var/dz = get_zs_away(Loc1, Loc2)
	return max(dx, dy, dz)

/proc/get_z_dist_euclidian(atom/Loc1, atom/Loc2)
	var/dx = Loc1.x - Loc2.x
	var/dy = Loc1.y - Loc2.y
	var/dz = get_zs_away(Loc1, Loc2)
	return sqrt(dx**2 + dy**2 + dz**2)

/proc/get_z_dist_squared(var/atom/a, var/atom/b)
	return ((b.x-a.x)**2) + ((b.y-a.y)**2) + ((get_zs_away(a, b))**2)

/proc/multi_z_spiral_block(var/turf/epicenter, var/max_range, var/draw_red=0, var/cube=1)
	var/turf/upturf = epicenter
	var/turf/downturf = epicenter
	. = spiral_block(epicenter, max_range, draw_red)
	for(var/i = 1, i < max_range, i++)
		if(HasAboveAt(upturf))
			upturf = GetAboveTurf(upturf)
			if(!upturf)
				break
			log_debug("Spiralling block of size [cube ? max_range : i + (max_range - i)] in [upturf.loc.name] ([upturf.x],[upturf.y],[upturf.z])")
			. += spiral_block(upturf, cube ? max_range : max_range - i, draw_red)
		if(HasBelowAt(downturf))
			downturf = GetBelowTurf(downturf)
			if(!downturf)
				break
			log_debug("Spiralling block of size [cube ? max_range : i + (max_range - i)] in [downturf.loc.name] ([downturf.x],[downturf.y],[downturf.z])")
			. += spiral_block(downturf, cube ? max_range : max_range - i, draw_red)

/client/proc/check_multi_z_spiral()
	set name = "Check Multi-Z Spiral Block"
	set category = "Debug"

	var/turf/epicenter = get_turf(usr)
	var/max_range = input("Set the max range") as num
	var/shape_txt = alert("What shape?", "Spiral Block", "Cube", "Octahedron")
	var/shape = shape_txt == "Cube" ? 1 : 0
	multi_z_spiral_block(epicenter, max_range, shape)

/proc/explosion_destroy_multi_z(turf/epicenter, turf/offcenter, const/devastation_range, const/heavy_impact_range, const/light_impact_range, const/flash_range, var/explosion_time, var/mob/whodunnit)
	if(HasAboveAt(offcenter) && (devastation_range >= 1 || heavy_impact_range >= 1 || light_impact_range >= 1 || flash_range >= 1))
		var/turf/upcenter = GetAboveTurf(offcenter)
		if(upcenter && upcenter.z > epicenter.z)
			explosion_destroy(epicenter, upcenter, devastation_range, heavy_impact_range, light_impact_range, flash_range, explosion_time, whodunnit)
	if(HasBelowAt(offcenter) && (devastation_range >= 1 || heavy_impact_range >= 1 || light_impact_range >= 1 || flash_range >= 1))
		var/turf/downcenter = GetBelowTurf(offcenter)
		if(downcenter && downcenter.z < epicenter.z)
			explosion_destroy(epicenter, downcenter, devastation_range, heavy_impact_range, light_impact_range, flash_range, explosion_time, whodunnit)
