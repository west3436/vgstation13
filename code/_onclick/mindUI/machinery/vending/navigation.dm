//////////////////////////////////////////
//~~~~~~~~~~~~~ NAVIGATION ~~~~~~~~~~~~~//
//////////////////////////////////////////
// Move and close buttons for vending machine UIs


/////////// Navigation UI ///////////
/datum/mind_ui/machine/vending/inventory_selector
	display_with_parent = TRUE
	element_types_to_spawn = list(
		/obj/abstract/mind_ui_element/machine/vending/selector_base,
		/obj/abstract/mind_ui_element/hoverable/machine/vending/selector_prev,
		/obj/abstract/mind_ui_element/hoverable/machine/vending/selector_next,
		/obj/abstract/mind_ui_element/machine/vending/selector_label,
	)

/datum/mind_ui/machine/vending/inventory_selector/Valid()
	if (!parent || !istype(parent, /datum/mind_ui/machine/vending))
		return FALSE
	return parent.Valid()

/datum/mind_ui/machine/vending/inventory_selector/Display()
	var/datum/mind_ui/vending/parent_ui = parent
	if (!parent_ui || !istype(parent_ui))
		return
	var/list/available = parent_ui.get_available_inventories()
	if (available.len <= 1)
		return
	..()


/////////// Selector Elements ///////////
/obj/abstract/mind_ui_element/machine/vending/selector_base
	icon = 'icons/ui/vending/selection.dmi'
	icon_state = "base"
	layer = MIND_UI_BUTTON
	width = 192
	height = 32
	mouse_opacity = 0

/obj/abstract/mind_ui_element/hoverable/machine/vending/selector_prev
	icon = 'icons/ui/vending/selection.dmi'
	icon_state = "prev"
	layer = MIND_UI_BUTTON
	hover_state = TRUE
	width = 32
	height = 32

/obj/abstract/mind_ui_element/hoverable/machine/vending/selector_prev/Click()
	var/datum/mind_ui/vending/ui = parent.parent
	if (!ui || !istype(ui))
		return
	// Check adjacency
	var/mob/user = GetUser()
	if (!user || !ui.vendor_ref || !user.Adjacent(ui.vendor_ref))
		return null
	ui.cycle_inventory(-1)

/obj/abstract/mind_ui_element/hoverable/machine/vending/selector_next
	icon = 'icons/ui/vending/selection.dmi'
	icon_state = "next"
	layer = MIND_UI_BUTTON
	hover_state = TRUE
	width = 32
	height = 32

/obj/abstract/mind_ui_element/hoverable/machine/vending/selector_next/Click()
	var/datum/mind_ui/machine/vending/ui = parent.parent
	if (!ui || !istype(ui))
		return
	// Check adjacency
	var/mob/user = GetUser()
	if (!user || !ui.vendor_ref || !user.Adjacent(ui.vendor_ref))
		return null
	ui.cycle_inventory(1)

/obj/abstract/mind_ui_element/machine/vending/selector_label
	icon = 'icons/ui/vending/selection.dmi'
	icon_state = "standard"
	layer = MIND_UI_BUTTON
	width = 96
	height = 32
	mouse_opacity = 0

/obj/abstract/mind_ui_element/machine/vending/selector_label/UpdateIcon(var/appear = FALSE)
	..()
	var/datum/mind_ui/vending/ui = parent?.parent
	if (!ui || !istype(ui))
		return

	switch(ui.inv_displayed)
		if(VEND_CAT_NORMAL)
			icon_state = "standard"
		if(VEND_CAT_HIDDEN)
			icon_state = "contraband"
		if(VEND_CAT_COIN)
			icon_state = "premium"
		if(VEND_CAT_HOLIDAY)
			icon_state = "holiday"
