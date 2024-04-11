var/datum/subsystem/ferment/SSferment

// Processes fermentation.
/datum/subsystem/ferment
	name          = "Fermentation"
	display_order = SS_DISPLAY_FERMENT
	priority      = SS_PRIORITY_FERMENT
	wait          = SS_WAIT_FERMENT

	var/list/processing_fermenting = list()
	var/list/currentrun

/datum/subsystem/ferment/New()
	NEW_SS_GLOBAL(SSferment)

/datum/subsystem/ferment/stat_entry()
	..("P:[processing_fermenting.len]")


/datum/subsystem/ferment/fire(var/resumed = FALSE)
	if (!resumed)
		currentrun = processing_fermenting.Copy()

	while (currentrun.len)
		var/obj/item/weapon/reagent_containers/fermenting = currentrun[currentrun.len]
		currentrun.len--

		if (!fermenting || fermenting.gcDestroyed)
			remove_fermenting(fermenting)
			continue
		if(fermenting.timestopped)
			continue

		fermenting.process()
		if (MC_TICK_CHECK)
			return

/datum/subsystem/ferment/proc/add_fermenting(var/obj/item/weapon/reagent_containers/fermenting)
	if(!istype(fermenting) || fermenting.gcDestroyed)
		return
	processing_fermenting |= fermenting

/datum/subsystem/ferment/proc/remove_fermenting(var/obj/item/weapon/reagent_containers/fermenting)
	processing_fermenting -= fermenting
