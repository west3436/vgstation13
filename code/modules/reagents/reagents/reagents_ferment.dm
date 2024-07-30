#define BASE_QUALITY 75
#define MAX_CLARITY 25

//Fermentation reagents. Yeast is in reagents_reactive.dm and fermentation products are in reagents_ethanol.dm.
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
	var/SG = 1.0
	var/health = 100
	var/primary_complete = FALSE
	var/quality = 0
	var/clarity = 0

/datum/reagent/must/New()
	..()
	SG = density

//Quality = base score (75) + clarity score (25)
//Quality = 75 * cleanliness * yeast health * (1 - abs(fermenting duration - target duration)) * fermenting vessel quality
/datum/reagent/must/proc/check_quality(obj/structure/reagent_dispensers/fermentation/container)
	quality = BASE_QUALITY * container.cleanliness * (1 - abs((container.fermentation_progress * SS_WAIT_FERMENT) - container.target_duration)) * container.fermentation_vessel_quality + clarity

/datum/reagent/must/proc/clarify(obj/structure/reagent_dispensers/fermentation/container)
	clarity = MAX_CLARITY * container.cleanliness * (1 - abs((container.fermentation_progress * SS_WAIT_FERMENT) - container.target_duration)) * container.fermentation_vessel_quality

/datum/reagent/must/red
	name = "Red Wine Must"
	id = RWINE_MUST
	color = "#800080"
	density = 1.07

/datum/reagent/must/white
	name = "White Wine Must"
	id = WWINE_MUST
	color = "#C6C693"
	density = 1.07

/datum/reagent/must/cider
	name = "Cider Must"
	id = CIDER_MUST
	color = "#f29224"
	density = 1.33

/datum/reagent/must/berry
	name = "Berry Must"
	id = BERRY_MUST
	color = "#C760A2"
	density = 1.01

/datum/reagent/must/pberry
	name = "Berry Must"
	id = PBERRY_MUST
	color = "#C760A2"
	density = 1.01

/datum/reagent/must/banana
	name = "Banana Must"
	id = BANANA_MUST
	color = "#FFE777"
	density = 1.13

#undef BASE_QUALITY
#undef MAX_CLARITY
