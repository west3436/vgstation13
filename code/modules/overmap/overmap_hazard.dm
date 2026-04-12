// /datum/overmap_hazard — single hazard tile occupant. Owned by SSovermap.
// Phase 1 only declares the data shape and four stub subtypes — event wiring
// happens in Phase 7.

/datum/overmap_hazard
	var/name = "Hazard"
	var/desc = null
	var/x = 0
	var/y = 0
	var/icon = 'icons/ui/overmap/hazards.dmi'
	var/icon_state = "asteroid_field"
	var/color = "#A00000"

	// Detection model.
	var/base_detection = 0.5            // probability a single detection roll succeeds (modulated by scanner tier)
	var/passable = TRUE                 // FALSE forbids waypointing onto this tile (v1 always TRUE)
	var/traverse_cost = 0               // deciseconds added to per-tile traversal time
	var/persistent = TRUE               // FALSE = despawns after first on_ship_enter

	// Event hooks. Phase 7 fills these.
	var/list/possible_events = list()
	var/roll_cooldown = 30 SECONDS
	var/list/last_rolled = list()       // shuttle ref -> world.time of last roll


/datum/overmap_hazard/New(loc_x = 0, loc_y = 0)
	. = ..()
	x = loc_x
	y = loc_y


/datum/overmap_hazard/Destroy()
	last_rolled.Cut()
	..()


// Stub event hooks. Phase 7 wires the actual round-event behavior.
/datum/overmap_hazard/proc/on_ship_enter(datum/shuttle/S)
	return

/datum/overmap_hazard/proc/roll_event(datum/shuttle/S)
	return

/datum/overmap_hazard/proc/can_roll_for(datum/shuttle/S)
	if(!S)
		return FALSE
	if(last_rolled[S] && (world.time - last_rolled[S]) < roll_cooldown)
		return FALSE
	return TRUE


// ---------------------------------------------------------------------------
// Stub subtypes
// ---------------------------------------------------------------------------

// =====================================================================
// Asteroid field — hull damage on transit. Free-nav shuttles get hit;
// preset shuttles are hazard_immune (Q37).
// =====================================================================
/datum/overmap_hazard/asteroid_field
	name = "Asteroid Field"
	desc = "Dense rock and dust. Hull damage on transit."
	icon_state = "asteroid_field"
	color = "#A0A0A0"
	traverse_cost = 30

/datum/overmap_hazard/asteroid_field/on_ship_enter(datum/shuttle/S)
	if(!S || S.hazard_immune)
		return
	if(!can_roll_for(S))
		return
	last_rolled[S] = world.time
	// Damage random breakable objects in the shuttle — simulating impacts.
	var/list/targets = list()
	for(var/area/A in S.linked_areas)
		for(var/obj/O in A)
			if(O.health && O.health > 0)
				targets += O
	if(targets.len)
		for(var/i = 1 to min(rand(2, 5), targets.len))
			var/obj/O = pick(targets)
			O.take_damage(rand(5, 15))
	for(var/area/A in S.linked_areas)
		for(var/mob/living/M in A)
			to_chat(M, "<span class='warning'>The hull groans as the ship grinds through asteroid debris.</span>")


// =====================================================================
// Solar flare — non-persistent. Disables sensors briefly, then despawns.
// =====================================================================
/datum/overmap_hazard/solar_flare
	name = "Solar Flare"
	desc = "An ionized burst. Disables sensors briefly on entry, then dissipates."
	icon_state = "solar_flare"
	color = "#FFC020"
	persistent = FALSE

/datum/overmap_hazard/solar_flare/on_ship_enter(datum/shuttle/S)
	if(!S || S.hazard_immune)
		return
	for(var/area/A in S.linked_areas)
		for(var/mob/living/M in A)
			to_chat(M, "<span class='danger'>Sensors flicker as a solar flare engulfs the ship!</span>")
	// Temporarily zero out sensors. Phase 5's update_sensors_from_scanner will
	// restore them on the next scanner RefreshParts; in practice they'll be
	// off until the helm operator pokes the scanner.
	var/old_radius = S.detection_radius
	S.detection_radius = 0
	spawn(30 SECONDS)
		if(S.detection_radius == 0)
			S.detection_radius = old_radius
	// Solar flares are non-persistent — despawn after the first ship hit.
	if(SSovermap)
		SSovermap.remove_hazard(src)
		qdel(src)


// =====================================================================
// Carp territory — spawns hostile space carp in the shuttle.
// =====================================================================
/datum/overmap_hazard/carp_territory
	name = "Carp Territory"
	desc = "Sensor returns suggest a school of space carp."
	icon_state = "carp_territory"
	color = "#7030A0"

/datum/overmap_hazard/carp_territory/on_ship_enter(datum/shuttle/S)
	if(!S || S.hazard_immune)
		return
	if(!can_roll_for(S))
		return
	last_rolled[S] = world.time
	// Spawn 2-4 carp at random open turfs inside the shuttle.
	var/list/spawn_turfs = list()
	for(var/area/A in S.linked_areas)
		for(var/turf/simulated/floor/T in A)
			if(!T.density)
				spawn_turfs += T
	if(!spawn_turfs.len)
		return
	for(var/i = 1 to rand(2, 4))
		var/turf/spawn_turf = pick(spawn_turfs)
		new /mob/living/simple_animal/hostile/carp(spawn_turf)
	for(var/area/A in S.linked_areas)
		for(var/mob/living/M in A)
			to_chat(M, "<span class='danger'>Something just teleported aboard! Sensors can't tell what.</span>")


// =====================================================================
// Debris field — minor hull damage, no events.
// =====================================================================
/datum/overmap_hazard/debris
	name = "Debris Field"
	desc = "Scattered hulks and unexploded ordnance."
	icon_state = "debris"
	color = "#606060"
	traverse_cost = 15

/datum/overmap_hazard/debris/on_ship_enter(datum/shuttle/S)
	if(!S || S.hazard_immune)
		return
	for(var/area/A in S.linked_areas)
		for(var/mob/living/M in A)
			to_chat(M, "<span class='warning'>Debris pings off the hull.</span>")
