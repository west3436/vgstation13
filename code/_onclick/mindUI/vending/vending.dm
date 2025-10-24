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
	var/last_inventory_change = 0  // Track when inventory was last changed for cooldown

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
	if (world.time < last_inventory_change + 30)
		return

	var/list/available = get_available_inventories()
	if (available.len <= 1)
		return

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

	last_inventory_change = world.time

	update_selector_label()

	var/obj/abstract/mind_ui_element/shelf/shelf_element = shelf()
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

	for (var/obj/abstract/mind_ui_element/element in products_ui.elements)
		var/anim_layer = MIND_UI_GROUP_A - 1  // Products go behind everything, including the bin
		if (istype(element, /obj/abstract/mind_ui_element/shelf))
			anim_layer = MIND_UI_GROUP_A + 1  // Keep shelf visible above inventory_back
		element.SlideUIElement(element.offset_x, element.offset_y - 50, duration = 5, layer = anim_layer, hide_after = TRUE)

	spawn(20)
		base_element.UpdateIcon()

		products_ui.refresh_products()

		for (var/obj/abstract/mind_ui_element/element in products_ui.elements)
			element.invisibility = 101

		// Manually recalculate shelf position without calling Appear() to avoid visibility issues
		for (var/obj/abstract/mind_ui_element/element in products_ui.elements)
			if (istype(element, /obj/abstract/mind_ui_element/shelf))
				// Reset shelf position based on products UI offset (same logic as base shelf Appear())
				element.offset_x = -products_ui.offset_x
				element.offset_y = -products_ui.offset_y
				// Don't add vendor-specific adjustments here - they were already applied in the initial Appear()
				// and are causing the 4px/3px drift
				element.UpdateUIScreenLoc()
				element.UpdateIcon()

		// Slide new products from 50 pixels below up to their desired location
		for (var/obj/abstract/mind_ui_element/element in products_ui.elements)
			// Use element's current offset as target
			var/target_x = element.offset_x
			var/target_y = element.offset_y

			// Use appropriate layer for each element type
			var/anim_layer = MIND_UI_GROUP_A - 1  // Products start behind everything, including the bin
			if (istype(element, /obj/abstract/mind_ui_element/shelf))
				anim_layer = MIND_UI_GROUP_A + 1  // Keep shelf visible above inventory_back

			// Position them 50 pixels below their target
			element.offset_x = target_x
			element.offset_y = target_y - 50
			element.UpdateUIScreenLoc()
			// Slide them up to their target position, keeping them hidden during animation
			element.SlideUIElement(target_x, target_y, duration = 5, layer = anim_layer, hide_after = TRUE)

		// After the slide-up animation completes (5 ticks duration + extra buffer), make elements visible at their proper layers
		spawn(10)
			for (var/obj/abstract/mind_ui_element/element in products_ui.elements)
				element.invisibility = 0

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
			var/obj/abstract/mind_ui_element/shelf/shelf_element = shelf()
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
		for (var/obj/abstract/mind_ui_element/shelf/shelf_element in products_ui.elements)
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

/obj/abstract/mind_ui_element/vending/coinslot
	icon = 'icons/ui/vending/base.dmi'
	layer = MIND_UI_FRONT
	var/coin_overlay_type = /obj/abstract/mind_ui_element/vending/coin_overlay

/obj/abstract/mind_ui_element/vending/coinslot/UpdateIcon(var/appear = FALSE)
	// Skip the parent's UpdateIcon to avoid adding vending overlays
	// The base UpdateIcon just returns, so we only need to clear overlays
	overlays.len = 0
	underlays.len = 0

/obj/abstract/mind_ui_element/vending/coin_overlay
	icon = 'icons/ui/vending/base.dmi'
	icon_state = "insert_coin"
	layer = MIND_UI_FRONT + 2

/obj/abstract/mind_ui_element/vending/coinslot/proc/show_coin()
	var/obj/abstract/mind_ui_element/vending/coin_overlay/coin = new coin_overlay_type(null, parent)
	coin.offset_x = 0
	coin.offset_y = 0
	coin.UpdateUIScreenLoc()

	parent.elements += coin
	var/mob/user = GetUser()
	if (user && user.client)
		user.client.screen += coin

	spawn(7)
		parent.elements -= coin
		if (user && user.client)
			user.client.screen -= coin
		qdel(coin)

/obj/abstract/mind_ui_element/vending/spark_overlay
	icon = 'icons/effects/effects.dmi'
	icon_state = "blank"
	layer = MIND_UI_FRONT + 2
	mouse_opacity = 0

/obj/abstract/mind_ui_element/vending/coinslot/proc/show_sparks()
	// Create a temporary visual element for the spark effect
	var/obj/abstract/mind_ui_element/vending/spark_overlay/spark = new(null, parent)
	spark.offset_x = offset_x + 100  // ADJUST THESE to align horizontally
	spark.offset_y = offset_y + 40   // ADJUST THESE to align vertically
	spark.UpdateUIScreenLoc()

	// Add to parent elements and send to client
	parent.elements += spark
	var/mob/user = GetUser()
	if (user && user.client)
		user.client.screen += spark

	// Play spark animation and sound
	flick("sparks", spark)
	playsound(user, "sparks", 100, 1)

	// Remove after animation completes
	spawn(7)
		parent.elements -= spark
		if (user && user.client)
			user.client.screen -= spark
		qdel(spark)

/obj/abstract/mind_ui_element/vending/coinslot/MouseDown(location, control, params)
	. = ..()

	var/datum/mind_ui/vending/ui = parent
	if(!ui?.vendor_ref)
		return

	var/mob/user = GetUser()
	if(!user)
		return

	// Adjacency check
	if (!user.Adjacent(ui.vendor_ref))
		return

	if(user.a_intent == I_HURT)
		return

	var/obj/item/held_item = user.get_active_hand()
	if(!held_item)
		return

	if(isEmag(held_item))
		show_sparks()
		ui.vendor_ref.attackby(held_item, user, params)
	else if(is_type_in_list(held_item, ui.vendor_ref.accepted_coins))
		show_coin()
		ui.vendor_ref.attackby(held_item, user, params)

/datum/mind_ui/processor/vending
	uniqueID = "Vending Processor"
	element_types_to_spawn = list(
		/obj/abstract/mind_ui_element/processor/vending,
		)

/obj/abstract/mind_ui_element/processor/vending
	// Track vending machine state for UI updates
	var/last_extended_inventory = FALSE
	var/last_coin_state = FALSE

/obj/abstract/mind_ui_element/processor/vending/New(turf/loc, var/datum/mind_ui/P)
	if (!istype(P))
		qdel(src)
		return
	// Temporarily clear the processing flag to prevent auto-add
	var/temp_flags = element_flags
	element_flags = 0
	..()
	// Restore the flag - we'll manually handle adding to processing_objects in Appear()
	element_flags = temp_flags

/obj/abstract/mind_ui_element/processor/vending/process()
	..()
	var/datum/mind_ui/vending/vending_ui = get_vending_ui()
	if (!vending_ui)
		return

	var/obj/machinery/vending/vendor = vending_ui.vendor_ref
	if (!vendor)
		return

	var/mob/user = GetUser()
	if (!user || !user.client)
		return

	if (!user.Adjacent(vendor))
		vending_ui.Hide()
		return

	// INVENTORY CHANGE DETECTION
	var/current_extended = vendor.extended_inventory ? TRUE : FALSE
	var/current_coin = vendor.coin ? TRUE : FALSE

	if (current_extended != last_extended_inventory || current_coin != last_coin_state)
		last_extended_inventory = current_extended
		last_coin_state = current_coin

		var/datum/mind_ui/vending/inventory_selector/selector_ui = vending_ui.inventory_selector()
		if (selector_ui)
			var/list/available = vending_ui.get_available_inventories()
			if (available.len > 1)
				selector_ui.Display()
			else
				selector_ui.Hide()

		vending_ui.update_selector_label()

		var/list/available_invs = vending_ui.get_available_inventories()
		if (!(vending_ui.inv_displayed in available_invs))
			vending_ui.inv_displayed = VEND_CAT_NORMAL
			vending_ui.update_selector_label()

			var/obj/abstract/mind_ui_element/shelf/shelf_element = vending_ui.shelf()
			if (shelf_element)
				shelf_element.UpdateIcon()

			var/datum/mind_ui/vending/products/products_ui = vending_ui.products()
			if (products_ui)
				products_ui.refresh_products()

/obj/abstract/mind_ui_element/processor/vending/proc/get_vending_ui()
	var/datum/mind_ui/current = parent
	while (current)
		if (istype(current, /datum/mind_ui/vending))
			return current
		current = current.parent
	return null

/obj/abstract/mind_ui_element/processor/vending/Appear()
	..()
	var/datum/mind_ui/vending/vending_ui = get_vending_ui()
	if (vending_ui && vending_ui.vendor_ref)
		last_extended_inventory = vending_ui.vendor_ref.extended_inventory ? TRUE : FALSE
		last_coin_state = vending_ui.vendor_ref.coin ? TRUE : FALSE
	if ((element_flags & MINDUI_FLAG_PROCESSING) && !(src in processing_objects))
		processing_objects.Add(src)

/obj/abstract/mind_ui_element/processor/vending/Hide()
	var/mob/user = GetUser()
	if (user && user.client && cursor_modified)
		user.client.mouse_pointer_icon = initial(user.client.mouse_pointer_icon)
		cursor_modified = FALSE
	if (element_flags & MINDUI_FLAG_PROCESSING)
		processing_objects.Remove(src)
	..()

/obj/abstract/mind_ui_element/processor/vending/Destroy()
	var/mob/user = GetUser()
	if (user && user.client && cursor_modified)
		user.client.mouse_pointer_icon = initial(user.client.mouse_pointer_icon)
		cursor_modified = FALSE
	..()

/obj/abstract/mind_ui_element/processor/vending/Disappear()
	var/mob/user = GetUser()
	if (user && user.client && cursor_modified)
		user.client.mouse_pointer_icon = initial(user.client.mouse_pointer_icon)
		cursor_modified = FALSE
	if (element_flags & MINDUI_FLAG_PROCESSING)
		processing_objects.Remove(src)
	..()
