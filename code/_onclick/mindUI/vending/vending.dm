/datum/mind_ui/vending
	var/obj/machinery/vending/vendor_ref = null
	var/list/contraband_elements = list()
	var/list/premium_elements = list()
	var/ui_height = 200
	var/ui_width = 200
	var/icon_to_use

/datum/mind_ui/vending/proc/UpdateDynamicProducts()
	for (var/obj/abstract/mind_ui_element/E in contraband_elements)
		elements -= E
		if (mind && mind.current && mind.current.client)
			mind.current.client.screen -= E
		qdel(E)
	contraband_elements.len = 0

	for (var/obj/abstract/mind_ui_element/E in premium_elements)
		elements -= E
		if (mind && mind.current && mind.current.client)
			mind.current.client.screen -= E
		qdel(E)
	premium_elements.len = 0

/datum/mind_ui/vending/proc/ShowError()
	return

/datum/mind_ui/vending/proc/ShowVend()
	return

/datum/mind_ui/vending/proc/premium_check()
	if (!vendor_ref || !istype(vendor_ref))
		return FALSE
	return vendor_ref.coin

/datum/mind_ui/vending/proc/contraband_check()
	if (!vendor_ref || !istype(vendor_ref))
		return FALSE
	return vendor_ref.extended_inventory


//////////////// BASE (move and close buttons) ////////////////
/datum/mind_ui/vending/base
	element_types_to_spawn = list(
		/obj/abstract/mind_ui_element/hoverable/close/vending,
		/obj/abstract/mind_ui_element/hoverable/movable/drag/vending,
	)

/obj/abstract/mind_ui_element/hoverable/close/vending
	icon = 'icons/ui/16x16.dmi'
	icon_state = "close"
	layer = MIND_UI_BUTTON
	hover_state = TRUE

/obj/abstract/mind_ui_element/hoverable/close/vending/New()
	..()
	var/datum/mind_ui/vending/P = parent
	if(!P || !istype(P,/datum/mind_ui/vending))
		qdel(src)
	offset_x = P.ui_width / 2
	offset_y = P.ui_height - 100

/obj/abstract/mind_ui_element/hoverable/close/vending/Click()
	var/datum/mind_ui/ancestor = parent.GetAncestor()
	ancestor.Hide()

/obj/abstract/mind_ui_element/hoverable/movable/drag/vending
	icon = 'icons/ui/16x16.dmi'
	icon_state = "move"
	layer = MIND_UI_BUTTON
	offset_x = -88
	offset_y = 92
	move_whole_ui = TRUE
	hover_state = TRUE

/obj/abstract/mind_ui_element/hoverable/movable/drag/vending/New()
	..()
	var/datum/mind_ui/vending/P = parent
	if(!P || !istype(P,/datum/mind_ui/vending))
		qdel(src)
	offset_x = -(P.ui_width / 2)
	offset_y = P.ui_height - 100

//////////////// KEYPADS ////////////////
/datum/mind_ui/vending/keypad
	var/button_size = 9 //in px, assumes squares
	var/horizontal_spacing = 6
	var/vertical_spacing = 6
	display_with_parent = TRUE
	never_move = FALSE
	offset_layer = MIND_UI_FRONT

/datum/mind_ui/vending/keypad/New(var/datum/mind/M, var/obj/machinery/vending/vendor)
	..()
	// Buttons 1-6
	for(var/i = 1 to 6)
		var/obj/abstract/mind_ui_element/vending/keypad_button/numerical/key = new()
		key.value = i
		key.icon = icon_to_use
		key.icon_state = "[i]"
		elements += key

	// Bottom row: Clear, 0, Enter
	var/list/bottom_row = list(
		new /obj/abstract/mind_ui_element/hoverable/vending/keypad_button/clear(),
		new /obj/abstract/mind_ui_element/vending/keypad_button/numerical(),
		new /obj/abstract/mind_ui_element/hoverable/vending/keypad_button/enter()
	)
	for(var/obj/abstract/mind_ui_element/elem in bottom_row)
		elem.icon = icon_to_use

	// Set 0 button properties
	var/obj/abstract/mind_ui_element/vending/keypad_button/numerical/zero_key = bottom_row[2]
	zero_key.value = 0
	zero_key.icon_state = "0"

	elements += bottom_row

/datum/mind_ui/vending/Valid()
	if (!vendor_ref)
		return FALSE
	if (!mind?.current)
		return FALSE
	if (!(mind.current.Adjacent(vendor_ref)))
		return FALSE
	if (vendor_ref.stat & (BROKEN|NOPOWER|FORCEDISABLE))
		return FALSE
	return TRUE

/obj/abstract/mind_ui_element/vending/keypad_button

/obj/abstract/mind_ui_element/vending/keypad_button/numerical
	var/value = 0

/obj/abstract/mind_ui_element/hoverable/vending/keypad_button/clear
	icon_state = "clear"
	tooltip_title = "Clear"
	tooltip_content = "Clear the current input"
	element_flags = MINDUI_FLAG_TOOLTIP

/obj/abstract/mind_ui_element/hoverable/vending/keypad_button/enter
	icon_state = "enter"
	tooltip_title = "Enter"
	tooltip_content = "Vend the selected product"
	element_flags = MINDUI_FLAG_TOOLTIP

//////////////// PRODUCT DISPLAYS ////////////////
/datum/mind_ui/vending/products
	var/product_size = 32 //in px, assumes squares
	var/horizontal_spacing = 4
	var/vertical_spacing = 4
	display_with_parent = TRUE
	never_move = FALSE
	offset_layer = MIND_UI_BUTTON

/datum/mind_ui/vending/products/New(var/datum/mind/M, var/obj/machinery/vending/vendor)
	..()
	var/list/products = vendor.products
	for (var/obj/item/product in products)
		var/obj/abstract/mind_ui_element/hoverable/vending/product_display/display = new(null,src)
		display.set_product(product)
		display.icon = icon_to_use
		display.icon_state = product.icon_state
		elements += display

/obj/abstract/mind_ui_element/hoverable/vending/product_display
	var/obj/item/product = null
	tooltip_title = "Product"
	tooltip_content = "A product from the vending machine."
	element_flags = MINDUI_FLAG_TOOLTIP

/obj/abstract/mind_ui_element/hoverable/vending/product_display/proc/set_product(var/obj/item/product_input)
	product = product_input
	tooltip_title = product.name
	tooltip_content = product.desc

/obj/abstract/mind_ui_element/vending/dispenser
	icon = 'icons/ui/vending/32x32.dmi'
	icon_state = "dispenser"

/obj/abstract/mind_ui_element/vending/dispenser/proc/dispense()
	flick("dispenser_moving", src)
