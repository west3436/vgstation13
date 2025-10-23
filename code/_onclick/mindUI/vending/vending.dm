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

/datum/mind_ui/vending/proc/holiday_check()
	if (!vendor_ref || !istype(vendor_ref))
		return FALSE
	return vendor_ref.holiday_records && vendor_ref.holiday_records.len > 0

/datum/mind_ui/vending/proc/get_available_inventories()
	var/list/inventories = list(VEND_CAT_NORMAL)

	if (contraband_check())
		inventories += VEND_CAT_HIDDEN
	if (premium_check())
		inventories += VEND_CAT_COIN
	if (holiday_check())
		inventories += VEND_CAT_HOLIDAY

	return inventories

/datum/mind_ui/vending/proc/cycle_inventory(var/direction = 1)
	var/list/available = get_available_inventories()
	if (available.len <= 1)
		return // Nothing to cycle to

	var/current_index = available.Find(inv_displayed)
	if (!current_index)
		current_index = 1

	var/new_index = current_index + direction
	if (new_index > available.len)
		new_index = 1
	else if (new_index < 1)
		new_index = available.len

	var/old_inventory = inv_displayed
	inv_displayed = available[new_index]

	update_selector_label()

	// Update shelf immediately
	var/obj/abstract/mind_ui_element/vending/shelf/shelf_element = shelf()
	if (shelf_element)
		shelf_element.UpdateIcon()

	animate_inventory_transition(old_inventory, inv_displayed)

/datum/mind_ui/vending/proc/update_selector_label()
	var/datum/mind_ui/vending/inventory_selector/selector_ui = inventory_selector()
	if (selector_ui)
		for (var/obj/abstract/mind_ui_element/vending/selector_label/label in selector_ui.elements)
			label.UpdateIcon()

/datum/mind_ui/vending/proc/animate_inventory_transition(var/old_inv, var/new_inv)
	var/obj/abstract/mind_ui_element/base_element = primary()
	if (!base_element)
		return

	var/datum/mind_ui/vending/products/products_ui = products()
	if (!products_ui)
		return

	// Animate the shelf and products moving down
	for (var/obj/abstract/mind_ui_element/element in products_ui.elements)
		animate(element, pixel_y = element.pixel_y - 96, time = 5)

	// Wait for animation to complete, pause, then bring new inventory up
	spawn(15) // 5 ticks down + 10 tick pause (1 second)
		// Update the UI to show new inventory shelf
		base_element.UpdateIcon()

		// Refresh products for new inventory
		products_ui.refresh_products()

		// Animate new products rising up from below
		for (var/obj/abstract/mind_ui_element/element in products_ui.elements)
			element.pixel_y -= 96
			animate(element, pixel_y = element.pixel_y + 96, time = 5)

/datum/mind_ui/vending/proc/ProcessVend()
	if (!vendor_ref || !istype(vendor_ref))
		return
	if (!input_str || length(input_str) == 0)
		Error("No product code entered")
		return
	if (length(input_str) != 2)
		Error("Product code must be 2 digits")
		return
	var/product_code = text2num(input_str)
	if (isnull(product_code))
		Error("Invalid product code")
		return

	var/list/products
	switch(inv_displayed)
		if(VEND_CAT_NORMAL)
			products = vendor_ref.product_records.Copy()
		if(VEND_CAT_HIDDEN)
			products = vendor_ref.hidden_records.Copy()
		if(VEND_CAT_COIN)
			products = vendor_ref.coin_records.Copy()
		if(VEND_CAT_HOLIDAY)
			products = vendor_ref.holiday_records.Copy()
		else
			products = vendor_ref.product_records.Copy()

	if (product_code < 1 || product_code > products.len)
		Error("Invalid product code")
		return

	var/datum/data/vending_product/selected = products[product_code]
	if (!selected || selected.amount <= 0)
		Error("Product out of stock")
		return

	var/was_premium = (inv_displayed == VEND_CAT_COIN)

	// Vend the product
	Vend(product_code)
	vendor_ref.vend(selected, mind.current)

	// Add "vend" overlay to the main UI element
	var/obj/abstract/mind_ui_element/base_element = primary()
	if (base_element)
		var/image/vend_overlay = image(icon = base_element.icon, icon_state = "vend", layer = MIND_UI_FRONT)
		base_element.overlays += vend_overlay
	hide_input_display()

	// Wait 1 second for animation to complete, then reset display
	spawn(10)  // 1 second delay
		input_str = ""
		if (base_element)
			base_element.UpdateIcon()  // Clear the vend overlay

		// Check if premium purchase consumed the coin (after animation completes)
		if (was_premium && !premium_check())
			// Switch back to standard inventory
			inv_displayed = VEND_CAT_NORMAL
			update_selector_label()

			// Update shelf to show standard inventory
			var/obj/abstract/mind_ui_element/vending/shelf/shelf_element = shelf()
			if (shelf_element)
				shelf_element.UpdateIcon()

			// Refresh products to standard inventory
			var/datum/mind_ui/vending/products/products_ui = products()
			if (products_ui)
				products_ui.refresh_products()

			// Hide selector if no other special inventories available
			var/datum/mind_ui/vending/inventory_selector/selector_ui = inventory_selector()
			if (selector_ui)
				var/list/available = get_available_inventories()
				if (available.len <= 1)
					selector_ui.Hide()


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

/datum/mind_ui/vending/proc/inventory_selector() //returns the inventory selector sub-ui
	for (var/datum/mind_ui/vending/inventory_selector/selector_ui in subUIs)
		return selector_ui


/////////// Element Locators ///////////
/datum/mind_ui/vending/proc/shelf() //returns the shelf element
	var/datum/mind_ui/vending/products/products_ui = products()
	if (products_ui)
		for (var/obj/abstract/mind_ui_element/vending/shelf/shelf_element in products_ui.elements)
			return shelf_element
	return null

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

	// Inventory selector base
	var/image/inv_select_base = image(icon, src, "inv_select")
	inv_select_base.layer = MIND_UI_BACK + 0.1
	overlays += inv_select_base

	// Where the items drop
	var/image/bin = image(icon, src, "bin")
	bin.layer = MIND_UI_GROUP_B
	underlays += bin

	// Behind the sliding inventory shelves
	var/image/inventory_back = image(icon, src, "inventory_back")
	inventory_back.layer = MIND_UI_GROUP_A
	overlays += inventory_back

	// Glass pane over the products
	var/image/glass = image(icon, src, "glass")
	glass.layer = MIND_UI_FRONT + 1
	overlays += glass
