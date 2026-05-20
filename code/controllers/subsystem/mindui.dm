var/datum/subsystem/mindui/SSmindui

/datum/subsystem/mindui
	name     = "mindUI"
	wait     = 1 SECONDS
	priority = SS_PRIORITY_MINDUI
	flags    = SS_NO_INIT | SS_KEEP_TIMING

	var/list/currentrun

/datum/subsystem/mindui/New()
	NEW_SS_GLOBAL(SSmindui)

/datum/subsystem/mindui/fire(resumed = FALSE)
	if (!resumed)
		currentrun = list()
		for (var/client/C in clients)
			if (C.mob && C.mob.mind)
				currentrun += C.mob.mind

	while (currentrun.len)
		var/datum/mind/M = currentrun[currentrun.len]
		currentrun.len--
		if (!M)
			continue
		HeartbeatOne(M)
		if (MC_TICK_CHECK)
			return

// One mind's worth of heartbeat work. Exposed so tests can drive it deterministically.
// Iterates a snapshot of activeUIs keys so Cleanup() mid-heartbeat (which mutates the live activeUIs) doesn't skip entries or runtime-error.
/datum/subsystem/mindui/proc/HeartbeatOne(datum/mind/M)
	if (!M)
		return
	for (var/uikey in M.activeUIs.Copy())
		var/datum/mind_ui/U = M.activeUIs[uikey]
		if (!U)
			continue
		var/valid_now = U.Valid()
		if (U.active && !valid_now)
			U.Hide()
		else if (!U.active && valid_now && U.auto_display)
			U.Display()
