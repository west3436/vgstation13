////////////////////////////////////
//~~~~~~~~~~~~~~ UI ~~~~~~~~~~~~~~//
////////////////////////////////////
/datum/mind_ui/vending/cigarette
	uniqueID = "Cigarette Vending"
	primary_element_type = /obj/abstract/mind_ui_element/vending/cigarette
	element_types_to_spawn = list(
		/obj/abstract/mind_ui_element/vending/cigarette,
		/obj/abstract/mind_ui_element/vending/coinslot/cigarette,
		/obj/abstract/mind_ui_element/vending/maintenance_panel/cigarette,
	)
	sub_uis_to_spawn = list(
		/datum/mind_ui/vending/navigation,
		/datum/mind_ui/vending/inventory_selector/cigarette,
		/datum/mind_ui/vending/keypad/cigarette,
		/datum/mind_ui/vending/products/cigarette,
		/datum/mind_ui/processor/vending,
		/datum/mind_ui/vending/wires/cigarette,
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

/datum/mind_ui/vending/wires/cigarette
	offset_x = 86
	offset_y = 9

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

/obj/abstract/mind_ui_element/vending/maintenance_panel/cigarette
	icon = 'icons/ui/vending/cigarette/base.dmi'
	icon_state = "panel"
	layer = MIND_UI_FRONT
	width = 128
	height = 141

/obj/abstract/mind_ui_element/vending/maintenance_panel/cigarette/UpdateIcon(var/appear = FALSE)
	// Skip the parent's UpdateIcon to avoid adding shadow
	// Just clear overlays and underlays
	overlays.len = 0
	underlays.len = 0

/obj/abstract/mind_ui_element/vending/maintenance_panel/cigarette/Appear()
	..()
	update_visibility()

/obj/abstract/mind_ui_element/vending/maintenance_panel/cigarette/update_visibility()
	var/datum/mind_ui/vending/ui = parent
	if(!ui?.vendor_ref)
		return
	// Hide panel when maintenance panel is open
	invisibility = ui.vendor_ref.panel_open ? 101 : 0

/obj/abstract/mind_ui_element/vending/maintenance_panel/cigarette/MouseDown(location, control, params)
	. = ..()

	var/datum/mind_ui/vending/ui = parent
	if(!ui?.vendor_ref)
		return

	var/mob/user = GetUser()
	if(!user)
		return

	// Adjacency check
	if(!user.Adjacent(ui.vendor_ref))
		return

	var/obj/item/held_item = user.get_active_hand()

	// Check if holding a screwdriver - toggle panel
	if(held_item && held_item.is_screwdriver(user))
		ui.vendor_ref.panel_open = !ui.vendor_ref.panel_open
		ui.vendor_ref.update_icon()
		// Processor will automatically update UI elements
		return
