/obj/machinery/autoprocessor/robotic_arm
	name = "Robotic Arm"
	desc = "Assembles things using its mounted tool."
	icon = 'icons/obj/machines/logistics.dmi'
	icon_state = "inactive"
	density = 0

	var/obj/item/tool/active_tool
	var/fueled = FALSE

/obj/machinery/autoprocessor/robotic_arm/New()
	. = ..()

	component_parts = newlist(
		/obj/item/weapon/circuitboard/autoprocessor/robotic_arm,
		/obj/item/weapon/stock_parts/matter_bin,
		/obj/item/weapon/stock_parts/manipulator,
		/obj/item/weapon/reagent_containers/glass/beaker,
		/obj/item/weapon/reagent_containers/glass/beaker
	)

	RefreshParts()

/obj/machinery/autoprocessor/robotic_arm/attackby(var/obj/item/I, mob/user)
	if(istype(I,obj/item/weapon/reagent_containers))
		return
	else if(istype(I,obj/item/tool))
		var/obj/item/tool/T = I
		if(active_tool)
			to_chat(user, "<span class='notice'>Remove \the [active_tool] from \the [src]'s tool chamber first!</span>")
			return 0
		user.drop_item(T)
		src.active_tool = T
		T.forceMove(src)
		to_chat(user, "<span class='notice'>You place \the [T] into \the [src]'s tool chamber.</span>")
		if(T.max_fuel)
			fueled = TRUE
			to_chat(user, "<span class='notice'>Insert fuel for the [T].</span>")
		return 1
	else
		error_buzz()
		to_chat(user, "<span class='notice'>You can only insert tools into \the [src].</span>")
		return 0

/obj/machinery/autoprocessor/robotic_arm/attack_hand(mob/user)
	if(active_tool)
		to_chat(user, "<span class='notice'>You remove \the [active_tool] from \the [src]'s tool chamber.</span>")
		user.put_in_hands(active_tool)
		active_tool = null

// /obj/machinery/autoprocessor/robotic_arm/Crossed(atom/movable/A)
// 	icon_state = "active"
// 	if(fueled)
// 		if(!check_fuel)
// 			error_buzz()
// 			return 0
// 	if(ishuman(A))
// 		if(!emagged)
// 			error_buzz()
// 			return 0
// 	A.attackby(active_tool)

// /obj/machinery/autoprocessor/robotic_arm/Uncrossed(atom/movable/A)
// 	icon_state = "inactive"

/obj/machinery/autoprocessor/robotic_arm/proc/check_fuel(var/material)
	for(var/obj/item/weapon/reagent_containers/RC in component_parts)
		reagent_total += RC.reagents.get_reagent_amount(material)
	return reagent_total

/obj/machinery/autoprocessor/robotic_arm/emag_act(var/mob/user, var/obj/item/weapon/card/emag/E)
	if(!src.emagged)
		spark(src, 1)
		src.emagged = 1
		if(user)
			to_chat(user, "<span class = 'warning'>You disable the [src]'s safety checks.</span>")
		return 1
	return 0

/obj/machinery/autoprocessor/hydraulic_press //Sponsored by LiveLeak(tm)
	name = "Hydraulic Press"
	desc = "Forms items out of various materials."
	icon_state = "inactive"
	density = 0

/obj/machinery/autoprocessor/hydraulic_press/New()
	. = ..()

	component_parts = newlist(
		/obj/item/weapon/circuitboard/autoprocessor/hydraulic_press,
		/obj/item/weapon/stock_parts/manipulator,
		/obj/item/weapon/stock_parts/manipulator,
		/obj/item/weapon/stock_parts/scanning_module
	)

	RefreshParts()

/obj/machinery/autoprocessor/applicator
	name = "Applicator"
	desc = "Adds items to any object that passes through it, if compatible."
	icon_state = "inactive"
	density = 0

/obj/machinery/autoprocessor/applicator/New()
	. = ..()

	component_parts = newlist(
		/obj/item/weapon/circuitboard/autoprocessor/applicator,
		/obj/item/weapon/stock_parts/manipulator,
		/obj/item/weapon/stock_parts/manipulator,
		/obj/item/weapon/stock_parts/scanning_module
	)

	RefreshParts()

/obj/machinery/autoprocessor/filling_machine
	name = "Filling Machine"
	desc = "Adds fluids to anything which passes through it, if compatible."
	icon_state = "inactive"
	density = 0

/obj/machinery/autoprocessor/filling_machine/New()
	. = ..()

	component_parts = newlist(
		/obj/item/weapon/circuitboard/autoprocessor/filling_machine,
		/obj/item/weapon/stock_parts/scanning_module,
		/obj/item/weapon/stock_parts/manipulator,
		/obj/item/weapon/reagent_containers/glass/beaker,
		/obj/item/weapon/reagent_containers/glass/beaker
	)

	RefreshParts()
