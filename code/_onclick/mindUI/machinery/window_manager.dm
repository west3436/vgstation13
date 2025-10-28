/////////////////////////////////////////////////
//~~~~~~~~~~~~~ WINDOW MANAGER ~~~~~~~~~~~~~//
/////////////////////////////////////////////////
// Move and close buttons for machine UIs

/datum/mind_ui/manager/machinery
	display_with_parent = TRUE
	offset_layer = MIND_UI_FRONT
	element_types_to_spawn = list(
		/obj/abstract/mind_ui_element/hoverable/close,
		/obj/abstract/mind_ui_element/hoverable/movable/drag,
	)

/datum/mind_ui/vending/manager/Valid()
	if (!parent)
		return FALSE
	return parent.Valid()


/////////// Manager Elements ///////////
/obj/abstract/mind_ui_element/hoverable/close
	icon = 'icons/ui/16x16.dmi'
	icon_state = "close"
	layer = MIND_UI_FRONT
	hover_state = TRUE
	width = 16
	height = 16

/obj/abstract/mind_ui_element/hoverable/close/Appear()
	..()
	var/datum/mind_ui/ui = parent?.parent
	if (!ui || !istype(ui))
		return
	var/w = ui.get_width()
	var/h = ui.get_height()
	offset_x = round(w - (width / 2))
	offset_y = round(h - (height / 2))
	UpdateUIScreenLoc()

/obj/abstract/mind_ui_element/hoverable/close/Click()
	var/datum/mind_ui/ancestor = parent.GetAncestor()
	ancestor.Hide()

/obj/abstract/mind_ui_element/hoverable/movable/drag
	icon = 'icons/ui/16x16.dmi'
	icon_state = "move"
	layer = MIND_UI_FRONT
	hover_state = TRUE
	move_whole_ui = TRUE
	move_all_uis = TRUE
	width = 16
	height = 16

/obj/abstract/mind_ui_element/hoverable/movable/drag/Appear()
	..()
	var/datum/mind_ui/ui = parent?.parent
	if (!ui || !istype(ui))
		return
	var/h = ui.get_height()
	offset_x = round(-width/2)
	offset_y = round(h - (height / 2))
	UpdateUIScreenLoc()
