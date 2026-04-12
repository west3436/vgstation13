// /obj/machinery/computer/starmap_console — view-only overmap viewport.
//
// Binds to the shuttle whose linked_area contains this console at initialize()
// time. attack_hand opens the starmap MindUI for the user; process() hides it
// when the user walks out of range.

/obj/item/weapon/circuitboard/starmap_console
	name = "Circuit board (Starmap Console)"
	desc = "A circuit board for a starmap viewer console."
	build_path = /obj/machinery/computer/starmap_console
	origin_tech = Tc_PROGRAMMING + "=2;" + Tc_MAGNETS + "=2"


/obj/machinery/computer/starmap_console
	name = "starmap console"
	desc = "A read-only display of charted overmap bodies and hazards."
	icon = 'icons/obj/computer.dmi'
	icon_state = "computer"
	circuit = "/obj/item/weapon/circuitboard/starmap_console"

	var/datum/shuttle/linked_shuttle = null
	var/list/active_viewers = list()


/obj/machinery/computer/starmap_console/initialize()
	..()
	identify_linked_shuttle()


// Walk this console's containing area for a matching /datum/shuttle. Console
// binding follows the same area-membership rule as the shuttle's own ports.
/obj/machinery/computer/starmap_console/proc/identify_linked_shuttle()
	var/area/A = get_area(src)
	if(!A)
		return
	for(var/datum/shuttle/S in shuttles)
		if(S.linked_area == A || (A in S.linked_areas))
			linked_shuttle = S
			return


/obj/machinery/computer/starmap_console/attack_hand(mob/user)
	if(..())
		return
	if(!linked_shuttle)
		to_chat(user, "<span class='warning'>No shuttle linked to this console.</span>")
		return
	if(!linked_shuttle.overmap_controlled)
		to_chat(user, "<span class='warning'>This shuttle is not equipped for overmap navigation.</span>")
		return

	user.DisplayUI("starmap")
	if(user.mind && user.mind.activeUIs["starmap"])
		var/datum/mind_ui/overmap_base/starmap/sm = user.mind.activeUIs["starmap"]
		sm.bind_shuttle(linked_shuttle)
	active_viewers |= user


/obj/machinery/computer/starmap_console/process()
	..()
	for(var/mob/M in active_viewers)
		if(get_dist(M, src) > 3 || !(src in view(3, M)))
			M.HideUI("starmap")
			active_viewers -= M
