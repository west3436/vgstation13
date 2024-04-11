var/list/valid_brewing_containers = list(
	/obj/item/weapon/reagent_containers/glass/jar,
	/obj/item/weapon/reagent_containers/glass/bucket,
	/obj/item/weapon/reagent_containers/glass/carboy,
	)

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
