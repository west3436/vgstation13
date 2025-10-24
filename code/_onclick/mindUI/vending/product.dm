////////////////////////////////////////
//~~~~~~~~~~~~~ PRODUCTS ~~~~~~~~~~~~~//
////////////////////////////////////////
// The products displayed in the vending machine UI
// Add or remove flags to control product display features
//
// To configure for your vending machine:
// 1. Create a new mind_ui vending/products datum that inherits from /datum/mind_ui/vending/products
// 2. Set the product_type variable to your desired product display element type (must inherit from /obj/abstract/mind_ui_element/hoverable/vending/product_display)
// 3. Set offset_x and offset_y to position the products within your vending machine's UI
// 4. Set products_per_row to control how many products are shown per row
// 5. Optionally set flags to control product display features (see VEND_PRODUCT_* constants)
// 6. In your vending machine's mind_ui datum, include your new products datum in the elements spawned
// 7. If using VEND_PRODUCT_ICON, create sprites for each product in the vendor and set their icon/icon_state vars

//////////////// Product UI ////////////////
/datum/mind_ui/vending/products
	var/product_type = /obj/abstract/mind_ui_element/hoverable/vending/product_display
	var/product_size = 32
	var/products_per_row = 4
	display_with_parent = TRUE
	never_move = FALSE
	offset_layer = MIND_UI_GROUP_A  // Products use layers 0-9, below main UI at 10
	var/animating = FALSE  // Prevent multiple simultaneous animations
	var/flags = VEND_PRODUCT_RING|VEND_PRODUCT_LABEL
	var/max_width = 100
	var/max_height = 100
	var/vend_target_x = 0  // X position for falling product animation target
	var/vend_target_y = 0 // Y position for falling product animation target

/datum/mind_ui/vending/products/Display()
	populate_products()
	..()

/datum/mind_ui/vending/products/proc/clear_products()
	for (var/obj/abstract/mind_ui_element/element in elements)
		// Preserve shelf elements - they should persist across inventory changes
		if (istype(element, /obj/abstract/mind_ui_element/shelf))
			continue
		if (mind?.current?.client)
			mind.current.client.screen -= element
		qdel(element)
	// Remove all non-shelf elements from the list
	for (var/obj/abstract/mind_ui_element/element in elements)
		if (!istype(element, /obj/abstract/mind_ui_element/shelf))
			elements -= element

/datum/mind_ui/vending/products/proc/refresh_products()
	clear_products()
	populate_products()
	for (var/obj/abstract/mind_ui_element/element in elements)
		if (mind?.current?.client)
			mind.current.client.screen += element

/datum/mind_ui/vending/products/proc/populate_products()
	var/datum/mind_ui/vending/parent_ui = parent
	if (!parent_ui || !istype(parent_ui))
		return
	var/obj/machinery/vending/vendor = parent_ui.vendor_ref
	if (!vendor)
		return

	// Get the appropriate product list based on current inventory
	var/list/products
	switch(parent_ui.inv_displayed)
		if(VEND_CAT_NORMAL)
			products = vendor.product_records.Copy()
		if(VEND_CAT_HIDDEN)
			products = vendor.hidden_records.Copy()
		if(VEND_CAT_COIN)
			products = vendor.coin_records.Copy()
		if(VEND_CAT_HOLIDAY)
			products = vendor.holiday_records.Copy()
		else
			products = vendor.product_records.Copy()

	var/total_products = products.len

	// Setup spacing
	var/max_rows = round((total_products + products_per_row - 1) / products_per_row)

	var/horizontal_spacing = 0
	if (products_per_row > 1)
		horizontal_spacing = (max_width - products_per_row * product_size) / (products_per_row - 1)

	var/vertical_spacing = 0
	if (max_rows > 1)
		vertical_spacing = (max_height - max_rows * product_size) / (max_rows - 1)

	// Create icons
	var/index = 0
	for (var/datum/data/vending_product/product in products)
		var/obj/abstract/mind_ui_element/hoverable/vending/product_display/display = new product_type(null, src)
		display.set_product(product, index + 1)

		var/obj/item/temp = product.product_path
		if(!(flags & VEND_PRODUCT_ICON))
			display.icon = temp.icon
		display.icon_state = temp.icon_state

		display.product_icon_state = display.icon_state
		display.icon_state = ""
		display.update_stack_visual()

		var/row = 0
		var/col = index
		while (col >= products_per_row)
			row++
			col -= products_per_row

		display.offset_x = round(col * (product_size + horizontal_spacing))
		display.offset_y = round(-row * (product_size + vertical_spacing))

		display.UpdateUIScreenLoc()

		elements += display

		// Send to client immediately
		if (mind?.current?.client)
			mind.current.client.screen += display

		if(flags & VEND_PRODUCT_RING) // add a ring dispenser
			var/obj/abstract/mind_ui_element/vending/dispenser/dispenser = new(null, src)
			dispenser.offset_x = display.offset_x
			dispenser.offset_y = display.offset_y - 2
			dispenser.UpdateUIScreenLoc()
			elements += dispenser
			display.dispenser = dispenser

			// Send to client immediately
			if (mind?.current?.client)
				mind.current.client.screen += dispenser

		if(flags & VEND_PRODUCT_LABEL) // add an ID label
			var/obj/abstract/mind_ui_element/vending/id_label/id_label = new(null, src, index + 1)
			id_label.offset_x = display.offset_x + 2
			id_label.offset_y = display.offset_y - product_size + 34
			id_label.UpdateUIScreenLoc()
			elements += id_label

			// Send to client immediately
			if (mind?.current?.client)
				mind.current.client.screen += id_label

		index++


/////////// Product Element ///////////
/obj/abstract/mind_ui_element/hoverable/vending/product_display
	tooltip_title = "Product"
	tooltip_content = "A product from the vending machine."
	element_flags = MINDUI_FLAG_TOOLTIP
	hover_state = FALSE
	width = 32
	height = 32

	var/obj/abstract/mind_ui_element/vending/dispenser/dispenser = null

	var/datum/data/vending_product/product = null
	var/product_code = 0
	var/product_icon_state = ""

	var/max_stack_display = 5

	var/shadow_offset_x = 1
	var/shadow_offset_y = -1
	var/shadow_alpha = 100

/obj/abstract/mind_ui_element/hoverable/vending/product_display/proc/set_product(var/datum/data/vending_product/product_input, var/code = 0)
	product = product_input
	product_code = code
	if (product)
		tooltip_title = "[product.product_name] (#[code])"
		var/price_display = product.price ? product.price : 0
		tooltip_content = "Stock: [product.amount] | Price: [price_display] credits"

/obj/abstract/mind_ui_element/hoverable/vending/product_display/proc/update_stack_visual()
	overlays.len = 0
	if (!product)
		return

	var/stack_count = min(product.amount, max_stack_display)
	if (stack_count <= 0)
		return

	// Draw from back to front so front item is on top
	for(var/i = 1; i <= stack_count; i++)
		var/pixel_offset_x = (stack_count - i)
		var/pixel_offset_y = (stack_count - i)
		var/item_layer = round((i - 1) * 9 / max(stack_count - 1, 1))

		// Add shadow first (so it appears behind the item)
		var/image/shadow = image(icon, src, product_icon_state)
		shadow.pixel_x = pixel_offset_x + shadow_offset_x
		shadow.pixel_y = pixel_offset_y + shadow_offset_y
		shadow.layer = item_layer
		shadow.color = "#000000"
		shadow.alpha = shadow_alpha
		overlays += shadow

		// Add the actual item
		var/image/stack_image = image(icon, src, product_icon_state)
		stack_image.pixel_x = pixel_offset_x
		stack_image.pixel_y = pixel_offset_y
		// Assign layer from 0-9: back items (i=1) at 0, front items (i=stack_count) at 9
		stack_image.layer = item_layer
		overlays += stack_image

/obj/abstract/mind_ui_element/hoverable/vending/product_display/proc/vend_front_item()
	if (!product || !parent || !istype(parent, /datum/mind_ui/vending/products))
		return

	var/datum/mind_ui/vending/products/ui = parent

	// Update the stack visual immediately to show one fewer item
	update_stack_visual()
	if (product)
		var/price_display = product.price ? product.price : 0
		tooltip_content = "Stock: [product.amount] | Price: [price_display] credits"

	// Create temporary animated element at the front position
	var/obj/abstract/mind_ui_element/vending/product_vend_anim/temp_item = new(null, ui)
	temp_item.icon = icon
	temp_item.icon_state = product_icon_state
	temp_item.offset_x = offset_x
	temp_item.offset_y = offset_y
	temp_item.layer = MIND_UI_GROUP_D  // Item will pass under the primary UI but in front of the bin
	temp_item.UpdateUIScreenLoc()

	// Add to parent's elements temporarily
	ui.elements += temp_item

	// Send to client
	if (ui.mind?.current?.client)
		ui.mind.current.client.screen += temp_item

	// Animate the temp item to the bin
	temp_item.SlideUIElement(ui.vend_target_x + rand(-15,15), ui.vend_target_y, duration = 3, layer = MIND_UI_GROUP_D, hide_after = FALSE)

	// Clean up the temp element after animation
	spawn(3 SECONDS)
		ui.elements -= temp_item
		qdel(temp_item)

/obj/abstract/mind_ui_element/hoverable/vending/product_display/Click()
	var/datum/mind_ui/vending/ui = parent?.parent
	if (!ui || !istype(ui))
		return
	// Check adjacency
	var/mob/user = GetUser()
	if (!user || !ui.vendor_ref || !user.Adjacent(ui.vendor_ref))
		return null
	if (!product || product.amount <= 0)
		ui.Error("Product out of stock")
		return
	// Zero-pad to 2 digits
	ui.input_str = length("[product_code]") == 1 ? "0[product_code]" : "[product_code]"
	ui.clear_display()

/////////// Dispenser Element ///////////
/obj/abstract/mind_ui_element/vending/dispenser
	icon = 'icons/ui/vending/product.dmi'
	icon_state = "dispenser"
	layer = MIND_UI_FRONT
	mouse_opacity = 0

/obj/abstract/mind_ui_element/vending/dispenser/proc/dispense()
	flick("dispenser_moving", src)

/////////// Vending Animation Element ///////////
/obj/abstract/mind_ui_element/vending/product_vend_anim
	mouse_opacity = 0

/////////// ID Label Element ///////////
/obj/abstract/mind_ui_element/vending/id_label
	icon = 'icons/ui/vending/product.dmi'
	icon_state = "label"
	layer = MIND_UI_FRONT
	mouse_opacity = 0
	var/product_id = 0

/obj/abstract/mind_ui_element/vending/id_label/New(turf/loc, var/datum/mind_ui/P, var/id = 0)
	product_id = id
	..()
	UpdateIcon()

/obj/abstract/mind_ui_element/vending/id_label/UpdateIcon(var/appear = FALSE)
	..()
	overlays.len = 0
	if (product_id > 0)
		overlays += String2Image("[product_id]", spacing = 6, _color = "#FFFFFF", _pixel_x = 16, _pixel_y = 0, shadows = FALSE)

/////////// Shelf Element ///////////
/obj/abstract/mind_ui_element/shelf
	// icon and icon_state should be defined by vendor-specific subtypes
	layer = MIND_UI_GROUP_A + 1
	width = 100
	height = 100
	mouse_opacity = 0

/obj/abstract/mind_ui_element/shelf/Appear()
	..()
	// Position at origin of base vending UI (negate products UI offset)
	var/datum/mind_ui/vending/products/products_ui = parent
	if (products_ui && istype(products_ui))
		offset_x = -products_ui.offset_x
		offset_y = -products_ui.offset_y
	else
		offset_x = 0
		offset_y = 0
	UpdateUIScreenLoc()
	UpdateIcon()

/obj/abstract/mind_ui_element/shelf/UpdateIcon(var/appear = FALSE)
	..()
	var/datum/mind_ui/vending/products/products_ui = parent
	if (!products_ui || !istype(products_ui))
		return
	var/datum/mind_ui/vending/parent_ui = products_ui.parent
	if (!parent_ui || !istype(parent_ui))
		return

	var/icon_state_to_use = "inventory"
	switch(parent_ui.inv_displayed)
		if(VEND_CAT_HIDDEN) //contraband
			icon_state_to_use += "_contraband"
		if(VEND_CAT_COIN) //premium
			icon_state_to_use += "_premium"
		if(VEND_CAT_HOLIDAY) //special
			icon_state_to_use += "_holiday"

	icon_state = icon_state_to_use
