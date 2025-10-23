/////////////////////////////////////////
//~~~~~~~~~~~~~~ MAIN UI ~~~~~~~~~~~~~~//
/////////////////////////////////////////
/datum/mind_ui/vending
	var/obj/machinery/vending/vendor_ref = null
	x = "CENTER"
	y = "CENTER"
	var/input_str = ""
	var/primary_element_type = /obj/abstract/mind_ui_element/vending //main ui screen
	var/inv_displayed = VEND_CAT_NORMAL

/datum/mind_ui/vending/Valid()
	var/obj/machinery/vending/vendor = vendor_ref
	if (!vendor && parent && istype(parent, /datum/mind_ui/vending))
		var/datum/mind_ui/vending/parent_ui = parent
		vendor = parent_ui.vendor_ref

	if (!vendor)
		return FALSE
	if (!mind?.current)
		return FALSE
	if (!(mind.current.Adjacent(vendor)))
		return FALSE
	if (vendor.stat & (BROKEN|NOPOWER|FORCEDISABLE))
		return FALSE
	return TRUE

/datum/mind_ui/vending/proc/Vend(var/product_code)
	for (var/datum/mind_ui/vending/products/products_ui in subUIs)
		for (var/obj/abstract/mind_ui_element/hoverable/vending/product_display/display in products_ui.elements)
			if (display.product_code == product_code && display.dispenser)
				display.dispenser.dispense()
				spawn(5)
					display.vend_front_item()

/datum/mind_ui/vending/proc/Error(var/message = "Error")
	if (mind?.current)
		to_chat(mind.current, "<span class='warning'>\The [vendor_ref] displays: [message]</span>")

	input_str = ""

	var/obj/abstract/mind_ui_element/base_element = primary()
	base_element.UpdateIcon()
	var/image/error_overlay = image(icon = base_element.icon, icon_state = "error", layer = MIND_UI_FRONT)
	base_element.overlays += error_overlay
	hide_input_display()

	spawn(15)
		base_element.UpdateIcon()

/datum/mind_ui/vending/proc/clear_display()
	for(var/datum/mind_ui/vending/keypad/ui in subUIs)
		if(istype(ui))
			ui.clear_display()

/datum/mind_ui/vending/proc/hide_input_display()
	for(var/datum/mind_ui/vending/keypad/ui in subUIs)
		for(var/obj/abstract/mind_ui_element/vending/keypad/input_display/display in ui.elements)
			display.HideText()

/datum/mind_ui/vending/proc/premium_check()
	if (!vendor_ref || !istype(vendor_ref))
		return FALSE
	return vendor_ref.coin

/datum/mind_ui/vending/proc/contraband_check()
	if (!vendor_ref || !istype(vendor_ref))
		return FALSE
	return vendor_ref.extended_inventory

/datum/mind_ui/vending/proc/ProcessVend()
	if (!vendor_ref || !istype(vendor_ref))
		return
	if (!input_str || length(input_str) == 0)
		Error("No product code entered")
		return
	var/product_code = text2num(input_str)
	if (isnull(product_code))
		Error("Invalid product code")
		return

	var/list/products = vendor_ref.product_records.Copy()

	if (product_code < 1 || product_code > products.len)
		Error("Invalid product code")
		return

	var/datum/data/vending_product/selected = products[product_code]
	if (!selected || selected.amount <= 0)
		Error("Product out of stock")
		return

	for (var/datum/mind_ui/vending/keypad/keypad_ui in subUIs)
		for (var/obj/abstract/mind_ui_element/vending/keypad/input_display/display in keypad_ui.elements)
			display.ShowPrice(selected.price)
	var/obj/abstract/mind_ui_element/base_element = primary()
	if (base_element)
		var/image/cr_overlay = image(icon = base_element.icon, icon_state = "cr", layer = MIND_UI_FRONT)
		base_element.overlays += cr_overlay

	spawn(10)
		base_element.UpdateIcon()

		// Vend the product
		Vend(product_code)
		vendor_ref.vend(selected, mind.current)

		// Add "vend" overlay to the main UI element
		if (base_element)
			var/image/vend_overlay = image(icon = base_element, icon_state = "vend", layer = MIND_UI_FRONT)
			base_element.overlays += vend_overlay
			hide_input_display()

		// Wait 1 second, then reset display
		spawn(10)  // 1 second delay
			input_str = ""
			base_element.UpdateIcon()  // Clear the vend overlay


/////////// Sub-UI Locators ///////////
// Used to quickly find and manipulate sub-UIs
/datum/mind_ui/vending/proc/keypad() //returns the keypad sub-ui
	for (var/datum/mind_ui/vending/keypad/keypad_ui in subUIs)
		return keypad_ui

/datum/mind_ui/vending/proc/products() //returns the products sub-ui
	for (var/datum/mind_ui/vending/products/products_ui in subUIs)
		return products_ui

/datum/mind_ui/vending/proc/navigation() //returns the navigation sub-ui
	for (var/datum/mind_ui/vending/navigation/base_ui in subUIs)
		return base_ui


/////////// Element Locators ///////////
/datum/mind_ui/vending/proc/primary() //returns the primary element
	for( var/obj/abstract/mind_ui_element/element in elements)
		if (istype(element,primary_element_type))
			return element

//////////////////////////////////////////
//~~~~~~~~~~~~~~ Elements ~~~~~~~~~~~~~~//
//////////////////////////////////////////
/obj/abstract/mind_ui_element/vending
	layer = MIND_UI_BACK

/obj/abstract/mind_ui_element/vending/UpdateIcon(var/appear = FALSE)
	..()
	overlays.len = 0
	underlays.len = 0

	var/datum/mind_ui/vending/ui = parent
	if(!ui?.vendor_ref)
		return
	ui.clear_display()

	// Add drop shadow beneath all UI elements
	var/image/shadow = image(icon, src, icon_state)
	shadow.layer = MIND_UI_BACK
	shadow.color = "#000000"
	shadow.alpha = 128
	shadow.pixel_x = 2
	shadow.pixel_y = -2
	shadow.filters = list(filter(type="blur", size=1))
	underlays += shadow

	// Where the items drop
	var/image/bin = image(icon, src, "bin")
	bin.layer = MIND_UI_GROUP_B
	underlays += bin

	// Behind the sliding inventory shelves
	var/image/inventory_back = image(icon, src, "inventory_back")
	inventory_back.layer = MIND_UI_GROUP_A
	overlays += inventory_back

	var/icon_state_to_use = "inventory"
	switch(ui.inv_displayed)
		if(VEND_CAT_HIDDEN) //contraband
			icon_state_to_use += "_contraband"
		if(VEND_CAT_COIN) //premium
			icon_state_to_use += "_premium"
		if(VEND_CAT_HOLIDAY) //special
			icon_state_to_use += "_holiday"

	// Where the items are shown
	var/image/inventory = image(icon, src, icon_state_to_use)
	inventory.layer = MIND_UI_GROUP_B
	overlays += inventory
