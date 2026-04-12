// Ambient overmap encounters fired by the standard /datum/event scheduler.
// Both events use the same SSovermap.spawn_encounter_near codepath as the
// scanner, so admins have a single dial for ambient encounter density via the
// existing event_manager weights.

/datum/event/derelict_detected
	announceWhen = 5
	endWhen = 30


/datum/event/derelict_detected/can_start(var/list/active_with_role)
	if(!SSovermap)
		return 0
	if(!pick_random_overmap_shuttle())
		return 0
	return 8  // weight


/datum/event/derelict_detected/start()
	var/datum/shuttle/S = pick_random_overmap_shuttle()
	if(!S)
		return
	var/datum/overmap_body/encounter/E = SSovermap.spawn_encounter_near(S, min_dist = 5, max_dist = 12)
	if(!E)
		return
	announce_to_shuttle(S, "Long-range sensors detect a derelict signal at bearing ([E.x],[E.y]).")


/datum/event/distress_signal
	announceWhen = 5
	endWhen = 30


/datum/event/distress_signal/can_start(var/list/active_with_role)
	if(!SSovermap)
		return 0
	if(!pick_random_overmap_shuttle())
		return 0
	return 5  // weight


/datum/event/distress_signal/start()
	var/datum/shuttle/S = pick_random_overmap_shuttle()
	if(!S)
		return
	var/datum/overmap_body/encounter/E = SSovermap.spawn_encounter_near(S, min_dist = 3, max_dist = 8)
	if(!E)
		return
	E.distress_flag = TRUE
	announce_to_shuttle(S, "Faint distress signal detected at bearing ([E.x],[E.y]).")


// Helper: pick a random overmap-controlled shuttle that has at least one mind
// currently viewing a helm UI for it. Returns null if no eligible shuttle.
/proc/pick_random_overmap_shuttle()
	if(!SSovermap || !shuttles || !shuttles.len)
		return null
	var/list/eligible = list()
	for(var/datum/shuttle/S in shuttles)
		if(!S.overmap_controlled)
			continue
		var/has_viewer = FALSE
		for(var/datum/mind_ui/overmap_base/ui in SSovermap.listening_uis)
			if(ui.linked_shuttle == S)
				has_viewer = TRUE
				break
		if(has_viewer)
			eligible += S
	if(!eligible.len)
		return null
	return pick(eligible)


// Helper: announce a message to all minds currently viewing a helm UI bound to
// the given shuttle. Falls back to all mobs in the shuttle's areas if no helm
// viewer is active.
/proc/announce_to_shuttle(datum/shuttle/S, message)
	if(!S || !message)
		return
	var/announced_to_anyone = FALSE
	for(var/datum/mind_ui/overmap_base/ui in SSovermap.listening_uis)
		if(ui.linked_shuttle == S && ui.mind?.current)
			to_chat(ui.mind.current, "<span class='notice'>\[Overmap\] [message]</span>")
			announced_to_anyone = TRUE
	if(!announced_to_anyone)
		for(var/area/A in S.linked_areas)
			for(var/mob/living/M in A)
				to_chat(M, "<span class='notice'>\[Overmap\] [message]</span>")
