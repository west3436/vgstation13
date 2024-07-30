//Quality = base score (75) + clarity score (25) + aging score (bonus)
//Quality = 75 * cleanliness * temperature * (1 - abs(fermenting duration - target duration)) * fermenting vessel quality + 25 * fermenting vessel quality * (1 - abs(secondary duration - target duration)) + aging duration * aging vessel quality

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
	var/seal_quality = 1.0

/obj/item/airlock/ghetto
	name = "ghetto fermentation airlock"
	desc = "A makeshift airlock used to mostly prevent air entering a fermentation vessel."
	icon_state = "TBD"
	starting_materials = list(MAT_FABRIC = 3*CC_PER_SHEET_FABRIC)
	w_type = RECYK_FABRIC
	seal_quality = 0.5

///Reagent Dispensers
//Fermentation
/obj/structure/reagent_dispensers/fermentation
	var/fermentation_vessel_quality = 1
	var/aging_vessel_quality = 1
	var/fermentation_progress = 0
	var/obj/item/airlock/attached_airlock

/obj/structure/reagent_dispensers/fermentation/examine(mob/user)
	if(reagents.reagent_list.len)
		var/fermentable = FALSE
		var/non_fermentable = FALSE
		for(var/datum/reagent/R in reagents.reagent_list)
			if(istype(R,/datum/reagent/yeast))
				continue
			else if(R.ferment && !fermentable)
				fermentable = TRUE
			else if(!R.ferment)
				non_fermentable = TRUE
		if(fermentable)
			if(non_fermentable)
				to_chat(user, "<span class='warning'>There is a mix of fermentable and non-fermentable liquids inside. Fermentation will not be possible!</span>")
			else
				if(is_fermenting())
					to_chat(user, "<span class='notice'>There are fermentable liquids inside.</span>")
					examine_fermentation_progress(user)
				else
					to_chat(user, "<span class='warning'>There are fermentable liquids inside. Add yeast to begin fermentation!</span>")
		else
			to_chat(user, "<span class='notice'>The contained liquids are not fermentable.</span>")

/obj/structure/reagent_dispensers/fermentation/update_icon()
	if(attached_airlock)
		icon_state = "[icon_state]_fermenting"
		if(istype(attached_airlock, /obj/item/airlock/ghetto))
			icon_state = "[icon_state]_ghetto"
	else
		icon_state = initial(icon_state)

/obj/structure/reagent_dispensers/fermentation/process()
	if(is_fermenting())
		process_fermenting()
	else
		..()

/obj/structure/reagent_dispensers/fermentation/proc/add_airlock(var/obj/item/airlock/A,var/mob/user)
	spawn(0)
		if(!user.drop_item(A))
			to_chat(user, "<span class='warning'>You can't let go of \the [A].</span>")
			return
	if(!do_after(user, src, 1 SECONDS))
		to_chat(user, "<span class='warning'>You need to stand still to install \the [A] into \the [src].</span>")
		return
	attached_airlock = A
	A.forceMove(src)
	update_icon()
	start_fermenting()

/obj/structure/reagent_dispensers/fermentation/proc/remove_airlock()
	return

/obj/structure/reagent_dispensers/fermentation/proc/start_fermenting()
	SSferment.add_fermenting(src)
	return

/obj/structure/reagent_dispensers/fermentation/proc/process_fermenting()
	return

/obj/structure/reagent_dispensers/fermentation/proc/stop_fermenting()
	SSferment.remove_fermenting(src)
	return

/obj/structure/reagent_dispensers/fermentation/proc/is_fermenting()
	return(src in processing_fermenting)

/obj/structure/reagent_dispensers/fermentation/proc/check_SG()
	return

/obj/structure/reagent_dispensers/fermentation/proc/examine_fermentation_progress(mob/user)
	if(!is_fermenting())
		return
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

//Glass Carboy
/obj/structure/reagent_dispensers/fermentation/carboy
	name = "glass carboy"
	icon_state = "carboy"
	desc = "A glass vessel used to ferment liquids into alcohol."
	layer = TABLE_LAYER
	flags = FPRINT | TWOHANDABLE | MUSTTWOHAND | OPENCONTAINER
	health = 50
	aging_vessel_quality = 0.5

/obj/structure/reagent_dispensers/fermentation/carboy/take_damage(incoming_damage, damage_type, skip_break, mute, var/sound_effect = 1) //Custom take_damage() proc because of sound_effect behavior.
	health = max(0, health - incoming_damage)
	if(sound_effect)
		var/S = pick('sound/effects/Glassbr1.ogg','sound/effects/Glassbr2.ogg','sound/effects/Glassbr3.ogg')
		playsound(loc, S, 75, 1)

/obj/structure/reagent_dispensers/fermentation/carboy/try_break()
	if(health <= 0)
		spawn(1)
			Destroy()
		return TRUE
	else
		return FALSE

/obj/structure/reagent_dispensers/fermentation/carboy/attackby(obj/item/weapon/W as obj, mob/user as mob)
	..()
	if(iswelder(W))
		var/obj/item/tool/weldingtool/WT = W
		to_chat(user, "<span class='notice'>You begin deconstructing \the [src].</span>")
		if(WT.do_weld(user, src, 50, 1))
			to_chat(user, "<span class='notice'>You finish deconstructing \the [src].</span>")
			new /obj/item/stack/sheet/glass/(loc, 20)
			qdel(src)
	else
		take_damage(W.force)
		user.delayNextAttack(10)

/obj/structure/reagent_dispensers/fermentation/carboy/wrenchable()
	return 1

/obj/structure/reagent_dispensers/fermentation/carboy/bullet_act(var/obj/item/projectile/Proj)
	. = ..()
	if(Proj.damage)
		take_damage(Proj.damage)

/obj/structure/reagent_dispensers/fermentation/carboy/ex_act(severity)
	switch(severity)
		if(1)
			Destroy()
		if(2)
			Destroy()
		if(3)
			take_damage(rand(15,45), sound_effect = 0)

/obj/structure/reagent_dispensers/fermentation/carboy/attack_animal(var/mob/living/simple_animal/M)
	if(take_damage(rand(M.melee_damage_lower, M.melee_damage_upper)))
		M.visible_message("<span class='danger'>[M] shatters \the [src]!</span>")
	else
		M.visible_message("<span class='danger'>[M] [M.attacktext] \the [src]!</span>")
	M.delayNextAttack(10)
	return 1

/obj/structure/reagent_dispensers/fermentation/carboy/attack_alien(mob/user)
	user.visible_message("<span class='danger'>[user] shatters \the [src]!</span>")
	Destroy()

//Aging keg
/obj/structure/reagent_dispensers/fermentation/agingkeg
	name = "aging keg"
	desc = "A wooden keg used to store and age wines."
	icon = 'icons/obj/objects.dmi'
	icon_state = "bloodkeg"
	amount_per_transfer_from_this = 10

/obj/structure/reagent_dispensers/fermentation/agingkeg/wrenchable()
	return 1

/obj/structure/reagent_dispensers/fermentation/agingkeg/attackby(obj/item/weapon/W as obj, mob/user as mob)
	..()
	if(iscrowbar(W))
		to_chat(user, "<span class='notice'>You begin deconstructing \the [src].</span>")
		if(do_after(user, src, 50))
			to_chat(user, "<span class='notice'>You finish deconstructing \the [src].</span>")
			new /obj/item/stack/sheet/wood/(loc, 20)
			qdel(src)

/obj/structure/reagent_dispensers/fermentation/ghetto
	name = "ghetto fermenter"
	desc = "Bedsheets haphazrdly strewn over a trash can. This should work fine..."
	icon = 'icons/obj/objects.dmi'
	icon_state = "bloodkeg"
	amount_per_transfer_from_this = 10
	fermentation_vessel_quality = 0.5
	aging_vessel_quality = 0.1

/obj/structure/reagent_dispensers/fermentation/ghetto/wrenchable()
	return 1
