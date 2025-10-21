/////////// MAIN UI SETUP ///////////
// UI
/datum/mind_ui/vending/cigarette
	uniqueID = "Cigarette Vending"
	ui_width = 160
	x = "CENTER"
	y = "CENTER"

	element_types_to_spawn = list(
		/obj/abstract/mind_ui_element/vending/cigarette,
//		/obj/abstract/mind_ui_element/vending/cigarette/input_display,
	)
	sub_uis_to_spawn = list(
		/datum/mind_ui/vending/base,
		/datum/mind_ui/vending/keypad/cigarette,
		/datum/mind_ui/vending/products/cigarette,
//		/datum/mind_ui/vending/contraband/cigarette,
//		/datum/mind_ui/vending/premium/cigarette,
	)

/datum/mind_ui/vending/cigarette/New(var/datum/mind/M, var/obj/machinery/vending/cigarette/vendor)
	. = ..()
	if (vendor)
		vendor_ref = vendor

// UI Elements
/obj/abstract/mind_ui_element/vending/cigarette/UpdateIcon(var/appear = FALSE)
	..()
	overlays.len = 0

	var/datum/mind_ui/vending/cigarette/ui = parent
	if(!ui?.vendor_ref)
		return

	// Where the items drop
	var/image/bin = image('icons/ui/vending/cigarette/160x192.dmi', src, "bin")
	bin.layer = MIND_UI_GROUP_A
	overlays += bin

	// Where the items are shown
	var/image/inventory = image('icons/ui/vending/cigarette/160x192.dmi', src, "inventory")
	inventory.layer = MIND_UI_GROUP_A
	overlays += inventory

	if (!ui.premium_check())
		var/image/premium_cover = image('icons/ui/vending/cigarette/160x192.dmi', src, "premium_cover")
		premium_cover.layer = MIND_UI_FRONT
		overlays += premium_cover

	if (ui.contraband_check())
		var/image/contraband_cover = image('icons/ui/vending/cigarette/160x192.dmi', src, "contraband_cover")
		contraband_cover.layer = MIND_UI_FRONT
		overlays += contraband_cover

/////////// KEYPAD SETUP ///////////
// UI
/datum/mind_ui/vending/keypad/cigarette
	icon_to_use = 'icons/ui/vending/cigarette/9x9.dmi'

//UI Elements
/obj/abstract/mind_ui_element/vending/cigarette
	icon = 'icons/ui/vending/cigarette/160x192.dmi'
	icon_state = "main"
	layer = MIND_UI_BACK

/////////// PRODUCTS SETUP ///////////
// UI
/datum/mind_ui/vending/products/cigarette
	icon_to_use = 'icons/ui/vending/cigarette/32x32.dmi'
