var/list/fermenting_vessels = list(
	/obj/structure/reagent_dispensers/cauldron/barrel,
	/obj/structure/reagent_dispensers/carboy,
	)

var/list/aging_vessels = list(
	/obj/structure/reagent_dispensers/cauldron/barrel,
	/obj/structure/reagent_dispensers/cauldron/barrel/wood,
	/obj/structure/reagent_dispensers/agingkeg,
	)

////Fermenting objects
///Items
//Airlocks
/obj/item/airlock
	name = "fermentation airlock"
	desc = "An airlock used to prevent air entering a fermentation vessel."
	icon_state = "TBD"
	w_class = W_CLASS_TINY
	starting_materials = list(MAT_PLASTIC = 3*CC_PER_SHEET_PLASTIC)
	w_type = RECYK_PLASTIC

/obj/item/airlock/ghetto
	name = "ghetto fermentation airlock"
	desc = "A makeshift airlock used to mostly prevent air entering a fermentation vessel.."
	icon_state = "TBD"
	starting_materials = list(MAT_FABRIC = 3*CC_PER_SHEET_FABRIC)
	w_type = RECYK_FABRIC

///Reagent Dispensers
//Fermentation
/obj/structure/reagent_dispensers/add_airlock()
	return

/obj/structure/reagent_dispensers/remove_airlock()
	return

/obj/structure/reagent_dispensers/start_fermenting()
	SSferment.add_fermenting(src)
	return

/obj/structure/reagent_dispensers/process_fermenting()
	return

/obj/structure/reagent_dispensers/stop_fermenting()
	SSferment.remove_fermenting(src)
	return

/obj/structure/reagent_dispensers/check_SG()
	return

/obj/structure/reagent_dispensers/examine_fermentation_progress(mob/user)
	switch(fermentation_progress)
		if(0)
			to_chat(user, "<span class='notice'>The contained liquids are not bubbling.</span>")
		if(1 to 33)
			to_chat(user, "<span class='notice'>The contained liquids are beginning to bubble.</span>")
		if(34 to 66)
			to_chat(user, "<span class='notice'>The contained liquids are bubbling rapidly.</span>")
		if(66 to 99)
			to_chat(user, "<span class='notice'>The contained liquids are bubbling occasionally.</span>")
		if(100)
			to_chat(user, "<span class='notice'>The contained liquids are no longer bubbling.</span>")

//Aging


//Glass Carboy
/obj/structure/reagent_dispensers/carboy
	name = "glass carboy"
	icon_state = "carboy"
	desc = "A glass vessel used to ferment liquids into alcohol."
	layer = TABLE_LAYER
	flags = FPRINT | TWOHANDABLE | MUSTTWOHAND | OPENCONTAINER
	health = 50
	allows_dyeing = FALSE

/obj/structure/reagent_dispensers/cauldron/barrel/take_damage(incoming_damage, damage_type, skip_break, mute, var/sound_effect = 1) //Custom take_damage() proc because of sound_effect behavior.
	health = max(0, health - incoming_damage)
	if(sound_effect)
		var/S = pick('sound/effects/Glassbr1','sound/effects/Glassbr2','sound/effects/Glassbr3')
		playsound(loc, S, 75, 1)

/obj/item/weapon/reagent_dispensers/carboy/try_break()
	if(health <= 0)
		spawn(1)
			Destroy()
		return TRUE
	else
		return FALSE

/obj/item/weapon/reagent_dispensers/carboy/attackby(obj/item/weapon/W as obj, mob/user as mob)
	..()
	if(iswelder(W))
		var/obj/item/tool/weldingtool/WT = W
		to_chat(user, "<span class='notice'>You begin deconstructing \the [src].</span>")
		if(WT.do_weld(user, src, 50, 1))
			dump_reagents()
			to_chat(user, "<span class='notice'>You finish deconstructing \the [src].</span>")
			new /obj/item/stack/sheet/glass/(loc, 20)
			qdel(src)
	else
		take_damage(W.force)
		user.delayNextAttack(10)

/obj/item/weapon/reagent_dispensers/carboy/wrenchable()
	return 1

/obj/item/weapon/reagent_dispensers/carboy/bullet_act(var/obj/item/projectile/Proj)
	. = ..()
	if(Proj.damage)
		take_damage(Proj.damage)

/obj/item/weapon/reagent_dispensers/carboy/ex_act(severity)
	switch(severity)
		if(1)
			Destroy()
		if(2)
			Destroy()
		if(3)
			take_damage(rand(15,45), sound_effect = 0)

/obj/item/weapon/reagent_dispensers/carboy/attack_animal(var/mob/living/simple_animal/M)
	if(take_damage(rand(M.melee_damage_lower, M.melee_damage_upper)))
		M.visible_message("<span class='danger'>[M] shatters \the [src]!</span>")
	else
		M.visible_message("<span class='danger'>[M] [M.attacktext] \the [src]!</span>")
	M.delayNextAttack(10)
	return 1

/obj/item/weapon/reagent_dispensers/carboy/attack_alien(mob/user)
	user.visible_message("<span class='danger'>[user] shatters \the [src]!</span>")
	Destroy()

//Aging keg
/obj/structure/reagent_dispensers/agingkeg
	name = "aging keg"
	desc = "A wooden keg used to store and age wines."
	icon = 'icons/obj/objects.dmi'
	icon_state = "bloodkeg"
	amount_per_transfer_from_this = 10

/obj/structure/reagent_dispensers/agingkeg/wrenchable()
	return 1

/obj/structure/reagent_dispensers/agingkeg/attackby(obj/item/weapon/W as obj, mob/user as mob)
	..()
	if(iscrowbar(W))
		to_chat(user, "<span class='notice'>You begin deconstructing \the [src].</span>")
		if(do_after(user, src, 50))
			dump_reagents()
			to_chat(user, "<span class='notice'>You finish deconstructing \the [src].</span>")
			new /obj/item/stack/sheet/wood/(loc, 20)
			qdel(src)
