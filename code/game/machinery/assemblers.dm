/obj/machinery/assembler/
	name = "Assembler"
	desc = "Assembles things using its mounted tool."
	icon = 'icons/obj/machines/logistics.dmi'
	density = 0

	var/obj/item/tool/active_tool

	var/next_sound = 0
	var/sound_delay = 20

/obj/machinery/assembler/attackby(var/obj/item/tool/T, mob/user)
	if(active_tool)
		to_chat(user, "<span class='notice'>Remove \the [active_tool] from \the [src]'s tool chamber first!</span>")
		return 0
	user.drop_item(T)
	src.active_tool = T
	T.forceMove(src)
	to_chat(user, "<span class='notice'>You place \the [T] into \the [src]'s tool chamber.</span>")
	return 1

/obj/machinery/assembler/attack_hand(mob/user)
	if(active_tool)
		to_chat(user, "<span class='notice'>You remove \the [active_tool] from \the [src]'s tool chamber.</span>")
		user.put_in_hands(active_tool)
		active_tool = null

/obj/machinery/assembler/Crossed(atom/movable/A)
	icon_state = "active"
//	if(istype(A,mob/living))
//		if(!emagged)
//			if (world.time > next_sound)
//				playsound(get_turf(src), 'sound/machines/buzz-sigh.ogg', 50, 1)
//				next_sound = world.time + sound_delay
//			return 0
	A.attackby(active_tool)

/obj/machinery/assembler/Uncrossed(atom/movable/A)
	icon_state = "inactive"

/obj/machinery/assembler/emag_act(var/mob/user, var/obj/item/weapon/card/emag/E)
	if(!src.emagged)
		spark(src, 1)
		src.emagged = 1
		if(user)
			to_chat(user, "<span class = 'warning'>You disable the [src]'s safety checks.</span>")
		return 1
	return 0
