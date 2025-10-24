////////////////////////////////////
//~~~~~~~~~~~~~~ UI ~~~~~~~~~~~~~~//
////////////////////////////////////
/datum/mind_ui/vending/cigarette
	uniqueID = "Cigarette Vending"
	primary_element_type = /obj/abstract/mind_ui_element/vending/cigarette
	element_types_to_spawn = list(
		/obj/abstract/mind_ui_element/vending/cigarette,
		/obj/abstract/mind_ui_element/vending/coinslot/cigarette,
	)
	sub_uis_to_spawn = list(
		/datum/mind_ui/vending/navigation,
		/datum/mind_ui/vending/inventory_selector/cigarette,
		/datum/mind_ui/vending/keypad/cigarette,
		/datum/mind_ui/vending/products/cigarette,
		/datum/mind_ui/processor/vending,
	)

/datum/mind_ui/vending/cigarette/New(var/datum/mind/M, var/obj/machinery/vending/cigarette/vendor)
	if (vendor)
		vendor_ref = vendor
	. = ..()

/datum/mind_ui/vending/keypad/cigarette
	input_display_type = /obj/abstract/mind_ui_element/vending/keypad/input_display/cigarette
	offset_x = 86
	offset_y = 74
	horizontal_spacing = 1
	vertical_spacing = 1

/datum/mind_ui/vending/products/cigarette
	product_type = /obj/abstract/mind_ui_element/hoverable/vending/product_display/cigarette
	offset_x = 4
	offset_y = 98
	products_per_row = 4
	max_width = 84
	max_height = 64
	flags = VEND_PRODUCT_RING|VEND_PRODUCT_LABEL|VEND_PRODUCT_ICON
	vend_target_x = 15
	vend_target_y = -90
	element_types_to_spawn = list(
		/obj/abstract/mind_ui_element/shelf/cigarette
	)

/datum/mind_ui/vending/inventory_selector/cigarette
	offset_x = 8
	offset_y = 55

//////////////////////////////////////////
//~~~~~~~~~~~~~~ ELEMENTS ~~~~~~~~~~~~~~//
//////////////////////////////////////////

// Primary element
/obj/abstract/mind_ui_element/vending/cigarette
	icon = 'icons/ui/vending/cigarette/base.dmi'
	icon_state = "main"
	layer = MIND_UI_BACK
	width = 128
	height = 141

// Input display
/obj/abstract/mind_ui_element/vending/keypad/input_display/cigarette
	icon = 'icons/ui/vending/cigarette/base.dmi'
	icon_state = ""
	offset_x = 8
	offset_y = 40

// Product display
/obj/abstract/mind_ui_element/hoverable/vending/product_display/cigarette
	icon = 'icons/ui/vending/cigarette/products.dmi'

/obj/abstract/mind_ui_element/shelf/cigarette
	icon = 'icons/ui/vending/cigarette/base.dmi'
	icon_state = "inventory"


/obj/abstract/mind_ui_element/vending/coinslot/cigarette
	icon = 'icons/ui/vending/cigarette/base.dmi'
	icon_state = "coin"
	coin_overlay_type = /obj/abstract/mind_ui_element/vending/coin_overlay/cigarette

/obj/abstract/mind_ui_element/vending/coin_overlay/cigarette
	icon = 'icons/ui/vending/cigarette/base.dmi'
	icon_state = "insert_coin"
