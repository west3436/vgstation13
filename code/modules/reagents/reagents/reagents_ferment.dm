//Fermentation reagents. Yeast is in reagents_reactive.dm and fermentation products are in reagents_ethanol.dm.
/datum/reagent/fermentation_activator //kicks off fermentation; deletes itself on creation
	name = "Fermentation Activator"
	id = FERMENTATION_ACTIVATOR
	description = "You shouldn't be seeing this!"
	color = "#ffffff"

/datum/reagent/must
	name = "Must"
	id = MUST
	description = "This doesn't taste very good.."
	reagent_state = REAGENT_STATE_LIQUID
	nutriment_factor = 0.25 * REAGENTS_METABOLISM
	color = "#ffffff"
	custom_metabolism = FOOD_METABOLISM
	density = 1.0 //changes according to composition
	specheatcap = 2.46
	var/health = 100

/datum/reagent/must/red
	name = "Red Wine Must"
	id = RWINE_MUST
	color = "#800080"

/datum/reagent/must/white
	name = "White Wine Must"
	id = WWINE_MUST
	color = "#C6C693"

/datum/reagent/must/cider
	name = "Cider Must"
	id = CIDER_MUST
	color = "#f29224"

/datum/reagent/must/berry
	name = "Berry Must"
	id = BERRY_MUST
	color = "#C760A2"

/datum/reagent/must/pberry
	name = "Berry Must"
	id = PBERRY_MUST
	color = "#C760A2"

/datum/reagent/must/banana
	name = "Banana Must"
	id = BANANA_MUST
	color = "#FFE777"
