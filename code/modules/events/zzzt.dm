/datum/event/zzzt
	var/list/valid_apcs = list()

/datum/event/zzzt/announce()
	command_alert(/datum/command_alert/zzzt)

/datum/event/zzzt/can_start(var/list/active_with_role)
	if((active_with_role["Engineer"] > 1 || active_with_role["Atmospherics Technician"] > 1) && active_with_role["Any"] > 6)
		return 15
	return 0

/datum/event/zzzt/start()
	for(var/obj/machinery/power/apc/A in power_machines)
		if(!A.opened && A.operating)
			valid_apcs += A
	if(!valid_apcs)
		message_admins("Zzzt event has failed! Could not find any viable APCs.")
		announceWhen = -1
		endWhen = 0
		return 0
	var/obj/machinery/power/apc/affected = pick(valid_apcs)
	affected.short_circuit()
	log_admin("The zzzt event has shorted \the [affected].")
	message_admins("The zzzt event has shorted \the [affected].")
