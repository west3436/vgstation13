// /obj/machinery/computer/shuttle_helm — interactive overmap helm console.
//
// Picks the helm UI subtype based on the bound shuttle's `free_nav` flag.
// Free-nav shuttles open the free helm; preset shuttles open the preset helm.

/obj/item/weapon/circuitboard/shuttle_helm
	name = "Circuit board (Shuttle Helm)"
	desc = "A circuit board for an interactive shuttle helm console."
	build_path = /obj/machinery/computer/shuttle_helm
	origin_tech = Tc_PROGRAMMING + "=3;" + Tc_MAGNETS + "=2"


/obj/machinery/computer/shuttle_helm
	name = "shuttle helm"
	desc = "A piloting console for steering a shuttle across the overmap."
	icon = 'icons/obj/computer.dmi'
	icon_state = "shuttle"
	circuit = "/obj/item/weapon/circuitboard/shuttle_helm"
	light_color = LIGHT_COLOR_BLUE

	var/datum/shuttle/linked_shuttle = null
	var/list/active_viewers = list()


/obj/machinery/computer/shuttle_helm/initialize()
	..()
	identify_linked_shuttle()


/obj/machinery/computer/shuttle_helm/proc/identify_linked_shuttle()
	var/area/A = get_area(src)
	if(!A)
		return
	for(var/datum/shuttle/S in shuttles)
		if(S.linked_area == A || (A in S.linked_areas))
			linked_shuttle = S
			return


/obj/machinery/computer/shuttle_helm/attack_hand(mob/user)
	if(..())
		return
	if(!linked_shuttle)
		to_chat(user, "<span class='warning'>No shuttle linked to this console.</span>")
		return
	if(!linked_shuttle.overmap_controlled)
		to_chat(user, "<span class='warning'>This shuttle is not equipped for overmap navigation.</span>")
		return
	if(linked_shuttle.req_access.len && !can_access(user.GetAccess(), linked_shuttle.req_access))
		to_chat(user, "<span class='warning'>Access denied.</span>")
		return

	var/ui_id = linked_shuttle.free_nav ? "shuttle_helm_free" : "shuttle_helm_preset"
	user.DisplayUI(ui_id)
	if(user.mind && user.mind.activeUIs[ui_id])
		var/datum/mind_ui/overmap_base/helm/H = user.mind.activeUIs[ui_id]
		H.bind_shuttle(linked_shuttle)
	active_viewers |= user


/obj/machinery/computer/shuttle_helm/process()
	..()
	for(var/mob/M in active_viewers)
		if(get_dist(M, src) > 3 || !(src in view(3, M)))
			M.HideUI("shuttle_helm_free")
			M.HideUI("shuttle_helm_preset")
			active_viewers -= M
