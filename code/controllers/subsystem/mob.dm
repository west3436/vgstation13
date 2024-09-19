var/datum/subsystem/mob/SSmob


/datum/subsystem/mob
	name          = "Mob"
	wait          = 2 SECONDS
	flags         = SS_NO_INIT | SS_KEEP_TIMING
	priority      = SS_PRIORITY_MOB
	display_order = SS_DISPLAY_MOB

	var/list/currentrun

	/// List of player mobs by their stringified virtual z-level
	var/static/list/list/players_by_virtual_z = list()

	/// List of all dead player mobs by virtual z-level
	var/static/list/list/dead_players_by_virtual_z = list()

/datum/subsystem/mob/New()
	NEW_SS_GLOBAL(SSmob)


/datum/subsystem/mob/stat_entry()
	..("P:[mob_list.len]")


/datum/subsystem/mob/fire(resumed = FALSE)
	if (!resumed)
		currentrun = mob_list.Copy()

	while (currentrun.len)
		var/mob/M = currentrun[currentrun.len]
		currentrun.len--

		if (!M || M.gcDestroyed || M.timestopped)
			continue

		M.Life()

		if (MC_TICK_CHECK)
			return
