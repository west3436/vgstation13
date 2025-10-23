//////////////////////////////////////////
//~~~~~~~~~~~~~ NAVIGATION ~~~~~~~~~~~~~//
//////////////////////////////////////////
// Move and close buttons for vending machine UIs


/////////// Navigation UI ///////////
/datum/mind_ui/vending/navigation
	display_with_parent = TRUE
	element_types_to_spawn = list(
		/obj/abstract/mind_ui_element/hoverable/close,
		/obj/abstract/mind_ui_element/hoverable/movable/drag,
	)

/datum/mind_ui/vending/navigation/Valid()
	if (!parent || !istype(parent, /datum/mind_ui/vending))
		return FALSE
	return parent.Valid()


/////////// Navigation Elements ///////////
/obj/abstract/mind_ui_element/hoverable/close
	icon = 'icons/ui/16x16.dmi'
	icon_state = "close"
	layer = MIND_UI_BUTTON
	hover_state = TRUE
	width = 16
	height = 16

/obj/abstract/mind_ui_element/hoverable/close/Appear()
	..()
	var/datum/mind_ui/vending/ui = parent?.parent
	if (!ui || !istype(ui))
		return
	var/obj/abstract/mind_ui_element/primary = ui.primary()
	if (!primary)
		return
	offset_x = round(primary.width - (width / 2))
	offset_y = round(primary.height - (height / 2))
	UpdateUIScreenLoc()

/obj/abstract/mind_ui_element/hoverable/close/Click()
	var/datum/mind_ui/ancestor = parent.GetAncestor()
	ancestor.Hide()

/obj/abstract/mind_ui_element/hoverable/movable/drag
	icon = 'icons/ui/16x16.dmi'
	icon_state = "move"
	layer = MIND_UI_BUTTON
	hover_state = TRUE
	move_whole_ui = TRUE
	move_all_uis = TRUE
	width = 16
	height = 16

/obj/abstract/mind_ui_element/hoverable/movable/drag/Appear()
	..()
	var/datum/mind_ui/vending/ui = parent?.parent
	if (!ui || !istype(ui))
		return
	var/obj/abstract/mind_ui_element/primary = ui.primary()
	if (!primary)
		return
	offset_x = round(-width/2)
	offset_y = round(primary.height - (height / 2))
	UpdateUIScreenLoc()


/////////// Inventory Selector Sub-UI ///////////
/datum/mind_ui/vending/inventory_selector
	display_with_parent = TRUE
	element_types_to_spawn = list(
		/obj/abstract/mind_ui_element/vending/selector_base,
		/obj/abstract/mind_ui_element/hoverable/vending/selector_prev,
		/obj/abstract/mind_ui_element/hoverable/vending/selector_next,
		/obj/abstract/mind_ui_element/vending/selector_label,
	)

/datum/mind_ui/vending/inventory_selector/Valid()
	if (!parent || !istype(parent, /datum/mind_ui/vending))
		return FALSE
	return parent.Valid()

/datum/mind_ui/vending/inventory_selector/Display()
	var/datum/mind_ui/vending/parent_ui = parent
	if (!parent_ui || !istype(parent_ui))
		return
	var/list/available = parent_ui.get_available_inventories()
	if (available.len <= 1)
		return
	..()


/////////// Selector Elements ///////////
/obj/abstract/mind_ui_element/vending/selector_base
	icon = 'icons/ui/vending/selection.dmi'
	icon_state = "base"
	layer = MIND_UI_BUTTON
	width = 192
	height = 32
	mouse_opacity = 0

/obj/abstract/mind_ui_element/hoverable/vending/selector_prev
	icon = 'icons/ui/vending/selection.dmi'
	icon_state = "prev"
	layer = MIND_UI_BUTTON
	hover_state = TRUE
	width = 32
	height = 32

/obj/abstract/mind_ui_element/hoverable/vending/selector_prev/Click()
	var/datum/mind_ui/vending/ui = parent.parent
	if (!ui || !istype(ui))
		return
	ui.cycle_inventory(-1)

/obj/abstract/mind_ui_element/hoverable/vending/selector_next
	icon = 'icons/ui/vending/selection.dmi'
	icon_state = "next"
	layer = MIND_UI_BUTTON
	hover_state = TRUE
	width = 32
	height = 32

/obj/abstract/mind_ui_element/hoverable/vending/selector_next/Click()
	var/datum/mind_ui/vending/ui = parent.parent
	if (!ui || !istype(ui))
		return
	ui.cycle_inventory(1)

/obj/abstract/mind_ui_element/vending/selector_label
	icon = 'icons/ui/vending/selection.dmi'
	icon_state = "standard"
	layer = MIND_UI_BUTTON
	width = 96
	height = 32
	mouse_opacity = 0

/obj/abstract/mind_ui_element/vending/selector_label/UpdateIcon(var/appear = FALSE)
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
