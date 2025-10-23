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
	var/datum/mind_ui/vending/ui = parent.parent //grandpa haha
	var/obj/abstract/mind_ui_element/primary = ui.primary()
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
	var/datum/mind_ui/vending/ui = parent.parent
	var/obj/abstract/mind_ui_element/primary = ui.primary()
	offset_x = round(-width/2)
	offset_y = round(primary.height - (height / 2))
	UpdateUIScreenLoc()
