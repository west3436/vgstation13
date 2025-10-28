/////////////////////////////////////////
//~~~~~~~~~~~~~~ KEYPADS ~~~~~~~~~~~~~~//
/////////////////////////////////////////
// Configurable numeric keypad UI for vending machines
// Includes an input display which supports a two-digit input
//
// To configure for your vending machine:
// 1. Create a new mind_ui vending/keypad datum that inherits from /datum/mind_ui/vending/keypad
// 2. Set the input_display_type variable to your desired input display element type (must inherit from /obj/abstract/mind_ui_element/vending/keypad/input_display)
// 3. Set offset_x and offset_y to position the keypad within your vending machine's UI
// 4. Create sprites for the keypad buttons and input display as needed and set their icon/icon_state variables
// 5. In your vending machine's mind_ui datum, include your new keypad datum in the elements spawned


/////////// Keypad UI ///////////
/datum/mind_ui/vending/keypad
	var/button_size = 9 //in px, assumes squares
	var/horizontal_spacing = 6
	var/vertical_spacing = 6
	var/input_display_type = /obj/abstract/mind_ui_element/vending/keypad/input_display  // Type of input display to spawn
	display_with_parent = TRUE
	never_move = FALSE
	offset_layer = MIND_UI_FRONT

/datum/mind_ui/vending/keypad/SpawnElements()
	..()
	var/spacing_unit = button_size + vertical_spacing

	// 1 2 3
	// 4 5 6
	// 7 8 9
	for(var/i = 1 to 9)
		var/obj/abstract/mind_ui_element/hoverable/vending/keypad_button/numerical/key = new(null, src)
		key.value = i

		var/col = (i - 1) % 3
		key.offset_x = col * (button_size + horizontal_spacing)

		if(i >= 1 && i <= 3)
			key.offset_y = 3 * spacing_unit
		else if(i >= 4 && i <= 6)
			key.offset_y = 2 * spacing_unit
		else if(i >= 7 && i <= 9)
			key.offset_y = 1 * spacing_unit

		key.icon_state = "[i]"
		key.base_icon_state = "[i]"
		key.UpdateUIScreenLoc()

		elements += key

	// C 0 E
	var/obj/abstract/mind_ui_element/hoverable/vending/keypad_button/clear/clear_btn = new(null, src)
	clear_btn.offset_x = 0
	clear_btn.offset_y = 0
	clear_btn.UpdateUIScreenLoc()
	elements += clear_btn

	var/obj/abstract/mind_ui_element/hoverable/vending/keypad_button/numerical/zero_btn = new(null, src)
	zero_btn.value = 0
	zero_btn.icon_state = "0"
	zero_btn.base_icon_state = "0"
	zero_btn.offset_x = 1 * (button_size + horizontal_spacing)
	zero_btn.offset_y = 0
	zero_btn.UpdateUIScreenLoc()
	elements += zero_btn

	var/obj/abstract/mind_ui_element/hoverable/vending/keypad_button/enter/enter_btn = new(null, src)
	enter_btn.offset_x = 2 * (button_size + horizontal_spacing)
	enter_btn.offset_y = 0
	enter_btn.UpdateUIScreenLoc()
	elements += enter_btn

	var/obj/abstract/mind_ui_element/vending/keypad/input_display/display = new input_display_type(null, src)
	display.UpdateUIScreenLoc()
	elements += display

/datum/mind_ui/vending/keypad/clear_display()
	for (var/obj/abstract/mind_ui_element/vending/keypad/input_display/display in elements)
		display.UpdateIcon()


/////////// Keypad Elements ///////////
/obj/abstract/mind_ui_element/hoverable/vending/keypad_button
	icon = 'icons/ui/vending/keypad.dmi'
	width = 9
	height = 9

/obj/abstract/mind_ui_element/hoverable/vending/keypad_button/numerical
	var/value = 0
	hover_state = FALSE

/obj/abstract/mind_ui_element/hoverable/vending/keypad_button/numerical/Click()
	var/datum/mind_ui/vending/ui = parent?.parent
	if (!ui || !istype(ui))
		return
	// Check adjacency
	var/mob/user = GetUser()
	if (!user || !ui.vendor_ref || !user.Adjacent(ui.vendor_ref))
		return null
	if (length(ui.input_str) >= 2)
		return
	icon_state = "[base_icon_state]_pressed"
	spawn(2)
		icon_state = base_icon_state

	ui.input_str += "[value]"
	ui.clear_display()

	// Show price preview if 2 digits entered
	if (length(ui.input_str) == 2)
		show_price_preview(ui)

/obj/abstract/mind_ui_element/hoverable/vending/keypad_button/numerical/proc/show_price_preview(var/datum/mind_ui/vending/ui)
	if (!ui || !ui.vendor_ref)
		return

	var/product_code = text2num(ui.input_str)
	if (isnull(product_code))
		return

	var/list/products
	switch(ui.inv_displayed)
		if(VEND_CAT_NORMAL)
			products = ui.vendor_ref.product_records
		if(VEND_CAT_HIDDEN)
			products = ui.vendor_ref.hidden_records
		if(VEND_CAT_COIN)
			products = ui.vendor_ref.coin_records
		if(VEND_CAT_HOLIDAY)
			products = ui.vendor_ref.holiday_records
		else
			products = ui.vendor_ref.product_records

	if (product_code < 1 || product_code > products.len)
		return

	var/datum/data/vending_product/selected = products[product_code]
	if (!selected)
		return

	// Show the price for 1 second with cr overlay
	var/price_to_show = selected.price ? selected.price : 0
	for (var/datum/mind_ui/vending/keypad/keypad_ui in ui.subUIs)
		for (var/obj/abstract/mind_ui_element/vending/keypad/input_display/display in keypad_ui.elements)
			display.ShowPrice(price_to_show)

	// Add cr overlay to main UI element
	var/obj/abstract/mind_ui_element/base_element = ui.primary()
	if (base_element)
		var/image/cr_overlay = image(icon = base_element.icon, icon_state = "cr", layer = MIND_UI_FRONT)
		base_element.overlays += cr_overlay

	spawn(10) // 1 second
		ui.clear_display()
		// Clear the cr overlay
		if (base_element)
			base_element.UpdateIcon()

/obj/abstract/mind_ui_element/hoverable/vending/keypad_button/clear
	icon_state = "clear"
	tooltip_title = "Clear"
	tooltip_content = "Clear the current input"
	element_flags = MINDUI_FLAG_TOOLTIP
	hover_state = FALSE

/obj/abstract/mind_ui_element/hoverable/vending/keypad_button/clear/Click()
	var/datum/mind_ui/vending/ui = parent?.parent
	if (!ui || !istype(ui))
		return
	// Check adjacency
	var/mob/user = GetUser()
	if (!user || !ui.vendor_ref || !user.Adjacent(ui.vendor_ref))
		return null
	icon_state = "[base_icon_state]_pressed"
	spawn(2)
		icon_state = base_icon_state

	ui.input_str = ""
	ui.clear_display()

/obj/abstract/mind_ui_element/hoverable/vending/keypad_button/enter
	icon_state = "enter"
	tooltip_title = "Enter"
	tooltip_content = "Vend the selected product"
	element_flags = MINDUI_FLAG_TOOLTIP
	hover_state = FALSE

/obj/abstract/mind_ui_element/hoverable/vending/keypad_button/enter/Click()
	var/datum/mind_ui/vending/ui = parent?.parent
	if (!ui || !istype(ui))
		return
	// Check adjacency
	var/mob/user = GetUser()
	if (!user || !ui.vendor_ref || !user.Adjacent(ui.vendor_ref))
		return null
	icon_state = "[base_icon_state]_pressed"
	spawn(2)
		icon_state = base_icon_state

	ui.ProcessVend()

/////////// Input Display Elements ///////////
/obj/abstract/mind_ui_element/vending/keypad/input_display
	icon = 'icons/ui/32x32.dmi'
	icon_state = ""
	layer = MIND_UI_BUTTON
	width = 32
	height = 32
	offset_x = 0
	offset_y = 0

/obj/abstract/mind_ui_element/vending/keypad/input_display/New(turf/loc, var/datum/mind_ui/P)
	..()
	UpdateIcon()

/obj/abstract/mind_ui_element/vending/keypad/input_display/UpdateIcon(var/appear = FALSE)
	..()
	var/datum/mind_ui/vending/ui = parent?.parent
	if (!ui || !istype(ui))
		return

	overlays.Cut()

	var/display_text = ui.input_str
	if(length(display_text) == 0)
		display_text = "--"
	else
		while (length(display_text) < 2)
			display_text = "-[display_text]"

	var/image/text_overlay = String2Image(display_text, spacing = 7, _color = "#000000", shadows = FALSE)
	if(text_overlay)
		overlays += text_overlay

/obj/abstract/mind_ui_element/vending/keypad/input_display/proc/ShowPrice(var/price)
	overlays.Cut()
	var/image/price_overlay = String2Image("[price]", spacing = 7, _color = "#000000", shadows = FALSE)
	if(price_overlay)
		overlays += price_overlay

/obj/abstract/mind_ui_element/vending/keypad/input_display/proc/HideText()
	overlays.Cut()
