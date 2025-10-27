#define VENDOR_WIRE_COUNT 4

#define VENDOR_LED_OFF 	0
#define VENDOR_LED_ON 	1

#define VENDOR_LED_ORANGE	"orange"
#define VENDOR_LED_RED 		"red"
#define VENDOR_LED_GREEN	"green"
#define VENDOR_LED_PURPLE	"purple"

/////////////////////////////////////
//~~~~~~~~~~~~~ WIRES ~~~~~~~~~~~~~//
/////////////////////////////////////
// Visual representation of vending machine wires UI

//////////////// Wires UI ////////////////
/datum/mind_ui/wires
	display_with_parent = TRUE
	never_move = FALSE
	offset_layer = MIND_UI_BACK

/datum/mind_ui/wires/vending
	uniqueID = "Vending Wires"
	var/obj/machinery/vending/vendor_ref = null
	var/wire_count = 0
	var/list/wire_ids = list(
		VENDING_WIRE_THROW,
		VENDING_WIRE_CONTRABAND,
		VENDING_WIRE_ELECTRIFY,
		VENDING_WIRE_IDSCAN
	)
	var/list/led_colors = list(
		VENDOR_LED_ORANGE,
		VENDOR_LED_RED,
		VENDOR_LED_GREEN,
		VENDOR_LED_PURPLE
	)
	element_types_to_spawn = list(
		/obj/abstract/mind_ui_element/wires/vending,
		/obj/abstract/mind_ui_element/wires/vending/wire,
		/obj/abstract/mind_ui_element/wires/vending/wire,
		/obj/abstract/mind_ui_element/wires/vending/wire,
		/obj/abstract/mind_ui_element/wires/vending/wire,
		/obj/abstract/mind_ui_element/wires/vending/led,
		/obj/abstract/mind_ui_element/wires/vending/led,
		/obj/abstract/mind_ui_element/wires/vending/led,
		/obj/abstract/mind_ui_element/wires/vending/led,
	)
	sub_uis_to_spawn = list(
		/datum/mind_ui/vending/navigation,
		/datum/mind_ui/processor/vending,
		/datum/mind_ui/processor/wires/vending,
	)

/datum/mind_ui/wires/vending/New(var/datum/mind/M, var/obj/machinery/vending/vendor)
	if(vendor)
		vendor_ref = vendor
	. = ..()

/datum/mind_ui/wires/vending/Valid()
	if(!vendor_ref)
		return FALSE
	// Main wires UI requires panel to be open
	if(!vendor_ref.panel_open)
		return FALSE
	if(!mind?.current)
		return FALSE
	if(!mind.current.Adjacent(vendor_ref))
		return FALSE
	return TRUE

/datum/mind_ui/wires/vending/proc/get_vendor_ref()
	return vendor_ref

/datum/mind_ui/wires/vending/proc/link_to_mini_ui(var/datum/mind_ui/vending/wires/mini_ui)
	if(!mini_ui)
		return
	// Note: elements[1] is the failsafe, actual elements start at index 2
	// Link the base elements (index 2)
	if(elements.len >= 2 && mini_ui.elements.len >= 2)
		var/obj/abstract/mind_ui_element/wires/vending/main_base = elements[2]
		main_base.mini_ui_ref = mini_ui
		main_base.mini_element_ref = mini_ui.elements[2]
	// Link the wires (elements 3-6 in main, 3-6 in mini)
	for(var/i = 3 to 6)
		if(elements.len >= i && mini_ui.elements.len >= i)
			var/obj/abstract/mind_ui_element/wires/vending/wire/main_wire = elements[i]
			main_wire.mini_ui_ref = mini_ui
			main_wire.mini_element_ref = mini_ui.elements[i]
	// Link the LEDs (elements 7-10 in main, 7-10 in mini)
	for(var/i = 7 to 10)
		if(elements.len >= i && mini_ui.elements.len >= i)
			var/obj/abstract/mind_ui_element/wires/vending/led/main_led = elements[i]
			main_led.mini_ui_ref = mini_ui
			main_led.mini_element_ref = mini_ui.elements[i]

/datum/mind_ui/wires/vending/proc/refresh_elements()
	if(!vendor_ref)
		return
	// Update all wire elements
	for(var/obj/abstract/mind_ui_element/wires/vending/wire/W in elements)
		W.update_status(vendor_ref)
		W.UpdateIcon()
	// Update all LED elements
	for(var/obj/abstract/mind_ui_element/wires/vending/led/L in elements)
		L.update_status(vendor_ref)
		L.UpdateIcon()


/obj/abstract/mind_ui_element/wires/vending
	icon = 'icons/ui/vending/wires.dmi'
	icon_state = "base"
	layer = MIND_UI_BACK
	width = 160
	height = 100
	var/datum/mind_ui/vending/wires/mini_ui_ref
	var/obj/abstract/mind_ui_element/vending/wire/mini_element_ref

/obj/abstract/mind_ui_element/wires/vending/proc/update_status(var/obj/machinery/vending/vendor)
	return

/obj/abstract/mind_ui_element/wires/vending/proc/sync_to_mini()
	if(!mini_element_ref)
		return
	mini_element_ref.icon_state = icon_state
	mini_element_ref.color = color
	mini_element_ref.invisibility = invisibility

/obj/abstract/mind_ui_element/wires/vending/wire
	icon = 'icons/ui/vending/wires.dmi'
	icon_state = "wire_"
	base_icon_state = "wire_"
	var/ID
	var/state
	layer = MIND_UI_FRONT
	width = 160
	height = 100

/obj/abstract/mind_ui_element/wires/vending/wire/New(turf/loc, var/datum/mind_ui/wires/vending/P)
	..()
	P.wire_count += 1
	ID = pick_n_take(P.wire_ids)
	icon_state = base_icon_state + "[ID]"
	// Position wires - they stack on top of the base element
	offset_x = 0
	offset_y = 0
	UpdateUIScreenLoc()
	var/obj/machinery/vending/vendor = P.get_vendor_ref()
	if(vendor)
		update_status(vendor)
		UpdateIcon()

/obj/abstract/mind_ui_element/wires/vending/wire/update_status(var/obj/machinery/vending/vendor)
	state = vendor.wires.GetStatus(ID)

/obj/abstract/mind_ui_element/wires/vending/wire/UpdateIcon(var/appear = FALSE)
	..()
	var/stat = state == WIRES_CUT ? "_cut" : ""
	icon_state = base_icon_state + "[ID][stat]"
	var/datum/mind_ui/wires/vending/ui
	if(istype(parent,/datum/mind_ui/wires/vending))
		ui = parent
	if(!ui)
		return
	var/obj/machinery/vending/vendor = ui.vendor_ref
	if(!vendor)
		return
	var/datum/wires/vending/W = vendor.wires
	color = W.GetColour(ID)
	sync_to_mini()

/obj/abstract/mind_ui_element/wires/vending/wire/proc/show_sparks(var/params)
	// Parse mouse position from params
	var/list/PM = params2list(params)
	var/icon_x = text2num(PM["icon-x"]) || 80  // Default to center if not available
	var/icon_y = text2num(PM["icon-y"]) || 50

	// Create a temporary visual element for the spark effect
	var/obj/abstract/mind_ui_element/wires/vending/spark_overlay/spark = new(null, parent)
	// Position relative to this wire element - adjust based on mouse click position
	spark.offset_x = offset_x + icon_x - 16  // Center the 32x32 spark on the mouse
	spark.offset_y = offset_y + icon_y - 16
	// Ensure layer is set correctly with parent's offset_layer
	spark.layer = initial(spark.layer) + parent.offset_layer
	spark.UpdateUIScreenLoc()

	// Add to parent elements and send to client
	parent.elements += spark
	var/mob/user = GetUser()
	if(user && user.client)
		user.client.screen += spark

	// Play spark animation (sound handled by spark() proc at user location)
	flick("sparks", spark)

	// Remove after animation completes
	spawn(7)
		parent.elements -= spark
		if(user && user.client)
			user.client.screen -= spark
		qdel(spark)

/obj/abstract/mind_ui_element/wires/vending/spark_overlay
	icon = 'icons/effects/effects.dmi'
	icon_state = "blank"
	layer = MIND_UI_FRONT + 5  // Much higher layer to ensure it's always on top
	mouse_opacity = 0

/obj/abstract/mind_ui_element/wires/vending/wire/MouseDown(location, control, params)
	. = ..()

	var/datum/mind_ui/wires/vending/ui = parent
	if(!istype(ui))
		return

	var/obj/machinery/vending/vendor = ui.vendor_ref
	if(!vendor)
		return

	var/mob/user = GetUser()
	if(!user)
		return

	// Adjacency check
	if(!user.Adjacent(vendor))
		return

	var/mob/living/L = user
	if(!L || !istype(L, /mob/living))
		return

	// Check if vendor is electrified - shock user but still allow interaction
	if(vendor.seconds_electrified > 0)
		if(!istype(L, /mob/living/silicon))
			var/obj/item/held_item_check = L.get_active_hand()
			if(vendor.shock(L, 100, get_conductivity(held_item_check)))
				spark(L, 5, TRUE)
				show_sparks(params)

	// Check if wires can be interacted with
	if(!vendor.wires.CanUse(L))
		to_chat(L, "<span class='notice'>You are incapable of this right now.</span>")
		return

	var/obj/item/held_item = L.get_active_hand()
	if(!held_item)
		return

	// Get the wire color for this wire ID
	var/wire_colour = vendor.wires.GetColour(ID)
	if(!wire_colour)
		return

	// Check for wirecutters - cut/mend wire
	if(held_item.is_wirecutter(L))
		if(held_item.arcanetampered || vendor.arcanetampered)
			if(L.electrocute_act(30, vendor))
				spark(L, 5, TRUE)
				show_sparks(params)
		// Always perform the action, even if shocked
		vendor.wires.CutWireColour(wire_colour, L)
		vendor.investigation_log(I_WIRES, "|| [vendor.wires.GetWireName(ID) || wire_colour] wire [vendor.wires.IsColourCut(wire_colour) ? "cut" : "mended"] by [key_name(L)] via UI ([vendor.wires.type])")
		// Refresh the UI
		ui.refresh_elements()

	// Check for multitool - pulse wire
	else if(held_item.is_multitool(L))
		if(held_item.arcanetampered || vendor.arcanetampered)
			if(L.electrocute_act(30, vendor))
				spark(L, 5, TRUE)
				show_sparks(params)
		// Always perform the action, even if shocked
		vendor.wires.PulseColour(wire_colour, L)
		vendor.investigation_log(I_WIRES, "|| [vendor.wires.GetWireName(ID) || wire_colour] wire pulsed by [key_name(L)] via UI ([vendor.wires.type])")
		// Refresh the UI to show pulsed effects
		ui.refresh_elements()

/obj/abstract/mind_ui_element/wires/vending/led
	icon = 'icons/ui/vending/wires.dmi'
	var/state
	var/led_color
	layer = MIND_UI_FRONT
	width = 160
	height = 100

/obj/abstract/mind_ui_element/wires/vending/led/New(turf/loc, var/datum/mind_ui/wires/vending/P)
	..()
	led_color = pick_n_take(P.led_colors)
	icon_state = led_color
	var/obj/machinery/vending/vendor = P.get_vendor_ref()
	if(vendor)
		update_status(vendor)
	// Position LEDs - they stack on top of the base element
	offset_x = 0
	offset_y = 0
	UpdateUIScreenLoc()
	UpdateIcon()

/obj/abstract/mind_ui_element/wires/vending/led/update_status(var/obj/machinery/vending/vendor)
	switch(led_color)
		if("orange")
			state = vendor.seconds_electrified ? VENDOR_LED_ON : VENDOR_LED_OFF
		if("red")
			state = vendor.shoot_inventory ? VENDOR_LED_OFF : VENDOR_LED_ON
		if("green")
			state = vendor.extended_inventory ? VENDOR_LED_ON : VENDOR_LED_OFF
		if("purple")
			state = vendor.scan_id ? VENDOR_LED_ON : VENDOR_LED_OFF

/obj/abstract/mind_ui_element/wires/vending/led/UpdateIcon(var/appear = FALSE)
	..()
	invisibility = state ? 101 : 0
	sync_to_mini()


/datum/mind_ui/vending/wires
	display_with_parent = TRUE
	var/wire_count = 0
	var/list/wire_ids = list(
		VENDING_WIRE_THROW,
		VENDING_WIRE_CONTRABAND,
		VENDING_WIRE_ELECTRIFY,
		VENDING_WIRE_IDSCAN
	)
	var/list/led_colors = list(
		VENDOR_LED_ORANGE,
		VENDOR_LED_RED,
		VENDOR_LED_GREEN,
		VENDOR_LED_PURPLE
	)
	element_types_to_spawn = list(
		/obj/abstract/mind_ui_element/vending/wire,
		/obj/abstract/mind_ui_element/vending/wire/wire,
		/obj/abstract/mind_ui_element/vending/wire/wire,
		/obj/abstract/mind_ui_element/vending/wire/wire,
		/obj/abstract/mind_ui_element/vending/wire/wire,
		/obj/abstract/mind_ui_element/vending/wire/led,
		/obj/abstract/mind_ui_element/vending/wire/led,
		/obj/abstract/mind_ui_element/vending/wire/led,
		/obj/abstract/mind_ui_element/vending/wire/led,
	)

/datum/mind_ui/vending/wires/Display()
	..()
	// Update all element states when displayed
	refresh_elements()

/datum/mind_ui/vending/wires/proc/refresh_elements()
	var/obj/machinery/vending/vendor = get_vendor_ref()
	if(!vendor)
		return
	for(var/obj/abstract/mind_ui_element/vending/wire/wire/W in elements)
		W.update_status(vendor)
		W.UpdateIcon()
	for(var/obj/abstract/mind_ui_element/vending/wire/led/L in elements)
		L.update_status(vendor)
		L.UpdateIcon()
	// Also update maintenance panel visibility
	var/datum/mind_ui/vending/vending_ui = get_parent_ui()
	if(vending_ui)
		for(var/obj/abstract/mind_ui_element/vending/maintenance_panel/P in vending_ui.elements)
			P.update_visibility()

/datum/mind_ui/vending/wires/proc/get_vendor_ref()
	// Check if we have vendor_ref directly
	if(vendor_ref)
		return vendor_ref
	// Otherwise get it from parent vending UI
	var/datum/mind_ui/vending/parent_vending = get_parent_ui()
	if(parent_vending)
		return parent_vending.vendor_ref
	return null

/datum/mind_ui/vending/wires/proc/get_parent_ui()
	var/datum/mind_ui/current = parent
	while(current)
		if(istype(current, /datum/mind_ui/vending))
			return current
		current = current.parent
	return null

/obj/abstract/mind_ui_element/vending/wire
	icon = 'icons/ui/vending/wires_small.dmi'
	icon_state = "base"
	layer = MIND_UI_FRONT
	width = 33
	height = 21
	var/datum/mind_ui/wires/vending/main_ref

/obj/abstract/mind_ui_element/vending/wire/proc/update_status(var/obj/machinery/vending/vendor)
	return

/obj/abstract/mind_ui_element/vending/wire/MouseDown(location, control, params)
	. = ..()

	var/datum/mind_ui/vending/wires/mini_ui = parent
	if(!istype(mini_ui))
		return

	var/datum/mind_ui/vending/vending_ui = mini_ui.get_parent_ui()
	if(!vending_ui?.vendor_ref)
		return

	var/mob/user = GetUser()
	if(!user)
		return

	// Adjacency check
	if(!user.Adjacent(vending_ui.vendor_ref))
		return

	var/obj/item/held_item = user.get_active_hand()

	// Check if holding a screwdriver - toggle panel
	if(held_item && held_item.is_screwdriver(user))
		vending_ui.vendor_ref.panel_open = !vending_ui.vendor_ref.panel_open
		vending_ui.vendor_ref.update_icon()
		// Processor will automatically update UI elements
		return

	// Empty hand or multitool - open main wires UI
	if(!held_item || held_item.is_multitool(user))
		var/datum/mind_ui/wires/vending/main_ui
		if("Vending Wires" in user.mind.activeUIs)
			main_ui = user.mind.activeUIs["Vending Wires"]
			main_ui.vendor_ref = vending_ui.vendor_ref
		else
			main_ui = new /datum/mind_ui/wires/vending(user.mind, vending_ui.vendor_ref)

		// Link the main UI to this mini UI
		main_ui.link_to_mini_ui(mini_ui)

		if(!main_ui.Valid())
			main_ui.Hide()
			return

		main_ui.Display()

/obj/abstract/mind_ui_element/vending/wire/wire
	icon = 'icons/ui/vending/wires_small.dmi'
	icon_state = "wire_"
	base_icon_state = "wire_"
	var/ID
	var/state
	width = 33
	height = 21

/obj/abstract/mind_ui_element/vending/wire/wire/New(turf/loc, var/datum/mind_ui/vending/wires/P)
	..()
	P.wire_count += 1
	ID = pick_n_take(P.wire_ids)
	icon_state = base_icon_state + "[ID]"
	// Position wires - they stack on top of the base element
	offset_x = 0
	offset_y = 0
	UpdateUIScreenLoc()
	var/obj/machinery/vending/vendor = P.get_vendor_ref()
	if(vendor)
		update_status(vendor)
	UpdateIcon()

/obj/abstract/mind_ui_element/vending/wire/wire/update_status(var/obj/machinery/vending/vendor)
	state = vendor.wires.GetStatus(ID)

/obj/abstract/mind_ui_element/vending/wire/wire/UpdateIcon(var/appear = FALSE)
	..()
	var/stat = state == WIRES_CUT ? "_cut" : ""
	icon_state = base_icon_state + "[ID][stat]"
	var/datum/mind_ui/vending/wires/ui
	if(istype(parent,/datum/mind_ui/vending/wires))
		ui = parent
	if(!ui)
		return
	var/obj/machinery/vending/vendor = ui.get_vendor_ref()
	if(!vendor)
		return
	var/datum/wires/vending/W = vendor.wires
	color = W.GetColour(ID)
	// Note: Mini UI doesn't sync back to main, only main syncs to mini

/obj/abstract/mind_ui_element/vending/wire/led
	icon = 'icons/ui/vending/wires_small.dmi'
	var/state
	var/led_color
	width = 33
	height = 21

/obj/abstract/mind_ui_element/vending/wire/led/New(turf/loc, var/datum/mind_ui/vending/wires/P)
	..()
	led_color = pick_n_take(P.led_colors)
	icon_state = led_color
	var/obj/machinery/vending/vendor = P.get_vendor_ref()
	if(vendor)
		update_status(vendor)
	// Position LEDs - they stack on top of the base element
	offset_x = 0
	offset_y = 0
	UpdateUIScreenLoc()
	UpdateIcon()

/obj/abstract/mind_ui_element/vending/wire/led/update_status(var/obj/machinery/vending/vendor)
	switch(led_color)
		if("orange")
			state = vendor.seconds_electrified ? VENDOR_LED_ON : VENDOR_LED_OFF
		if("red")
			state = vendor.shoot_inventory ? VENDOR_LED_OFF : VENDOR_LED_ON
		if("green")
			state = vendor.extended_inventory ? VENDOR_LED_ON : VENDOR_LED_OFF
		if("purple")
			state = vendor.scan_id ? VENDOR_LED_ON : VENDOR_LED_OFF

/obj/abstract/mind_ui_element/vending/wire/led/UpdateIcon(var/appear = FALSE)
	..()
	// Preserve the LED color as icon_state
	if(led_color)
		icon_state = led_color
	invisibility = state ? 101 : 0
	// Note: Mini UI doesn't sync back to main, only main syncs to mini

//////////////// Wires Processor ////////////////
/datum/mind_ui/processor/wires/vending
	uniqueID = "Vending Wires Processor"
	element_types_to_spawn = list(
		/obj/abstract/mind_ui_element/processor/wires/vending,
	)

/obj/abstract/mind_ui_element/processor/wires/vending
	element_flags = MINDUI_FLAG_PROCESSING
	var/last_panel_open = FALSE

/obj/abstract/mind_ui_element/processor/wires/vending/New(turf/loc, var/datum/mind_ui/P)
	if(!istype(P))
		qdel(src)
		return
	// Temporarily clear the processing flag to prevent auto-add
	var/temp_flags = element_flags
	element_flags = 0
	..()
	// Restore the flag
	element_flags = temp_flags

/obj/abstract/mind_ui_element/processor/wires/vending/process()
	..()
	var/datum/mind_ui/wires/vending/wires_ui = get_wires_ui()
	if(!wires_ui)
		return

	var/obj/machinery/vending/vendor = wires_ui.vendor_ref
	if(!vendor)
		return

	var/mob/user = GetUser()
	if(!user || !user.client)
		return

	// Adjacency check
	if(!user.Adjacent(vendor))
		wires_ui.Hide()
		return

	// Panel state check
	if(!vendor.panel_open)
		wires_ui.Hide()
		return

	// Refresh wires if needed
	var/current_panel_open = vendor.panel_open ? TRUE : FALSE
	if(current_panel_open != last_panel_open)
		last_panel_open = current_panel_open
		wires_ui.refresh_elements()

/obj/abstract/mind_ui_element/processor/wires/vending/proc/get_wires_ui()
	var/datum/mind_ui/current = parent
	while(current)
		if(istype(current, /datum/mind_ui/wires/vending))
			return current
		current = current.parent
	return null

/obj/abstract/mind_ui_element/processor/wires/vending/Appear()
	..()
	var/datum/mind_ui/wires/vending/wires_ui = get_wires_ui()
	if(wires_ui && wires_ui.vendor_ref)
		last_panel_open = wires_ui.vendor_ref.panel_open ? TRUE : FALSE
	if((element_flags & MINDUI_FLAG_PROCESSING) && !(src in processing_objects))
		processing_objects.Add(src)

/obj/abstract/mind_ui_element/processor/wires/vending/Hide()
	var/mob/user = GetUser()
	if(!user)
		return
	if(src in processing_objects)
		processing_objects.Remove(src)

#undef VENDOR_WIRE_COUNT
#undef VENDOR_LED_OFF
#undef VENDOR_LED_ON
#undef VENDOR_LED_ORANGE
#undef VENDOR_LED_RED
#undef VENDOR_LED_GREEN
#undef VENDOR_LED_PURPLE
