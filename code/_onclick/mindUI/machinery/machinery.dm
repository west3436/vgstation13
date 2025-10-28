/datum/mind_ui/machinery
	var/obj/machinery/machine_ref = null
	x = "CENTER"
	y = "CENTER"
	var/input_str = ""
	var/primary_element_type = /obj/abstract/mind_ui_element/machinery //main ui screen

/datum/mind_ui/machinery/Valid()
	var/obj/machinery/machine = machine_ref
	if (!machine && parent && istype(parent, /datum/mind_ui/machinery))
		var/datum/mind_ui/machinery/parent_ui = parent
		machine = parent_ui.machine_ref

	if (!machine)
		return FALSE
	if (!mind?.current)
		return FALSE
	if (!(mind.current.Adjacent(machine)))
		return FALSE
	if (machine.stat & (BROKEN|NOPOWER|FORCEDISABLE))
		return FALSE
	return TRUE

/datum/mind_ui/machinery/Destroy()
	machine_ref = null
	..()
