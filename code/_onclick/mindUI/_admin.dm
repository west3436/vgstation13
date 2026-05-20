// Admin tooling for mindUI


////////////////////////////////////////////////////////////////////
//																  //
//						  ELEMENT INSPECTOR						  //
//																  //
////////////////////////////////////////////////////////////////////

// Toggles a "what's on my HUD?" mode that overlays every active mindUI element with its type / parent uniqueID / offset.
// Per-client state (see /client/var/mindui_inspect_mode) so multiple admins can toggle independently.
/client/verb/mindui_inspect()
	set name = "MindUI Inspect"
	set category = "Debug"
	if (!check_rights(R_DEBUG))
		return
	mindui_inspect_mode = !mindui_inspect_mode
	to_chat(src, "<span class='notice'>MindUI Inspect: [mindui_inspect_mode ? "ON" : "OFF"]</span>")
	if (!mob || !mob.mind)
		return
	for (var/uikey in mob.mind.activeUIs)
		var/datum/mind_ui/U = mob.mind.activeUIs[uikey]
		for (var/obj/abstract/mind_ui_element/E in U.elements)
			if (mindui_inspect_mode)
				E.AddInspectorOverlay(U)
			else
				E.RemoveInspectorOverlay()

/obj/abstract/mind_ui_element/proc/AddInspectorOverlay(datum/mind_ui/U)
	if (_inspector_overlay)
		RemoveInspectorOverlay()
	var/short_type = "[type]"
	var/parent_id = U ? U.uniqueID : "?"
	var/label = "[short_type]\n[parent_id]\n([offset_x],[offset_y])"
	var/image/I = image(icon = null)
	I.maptext = {"<span style="color:#FFFF66;font-size:6pt;font-family:'Consolas';background:rgba(0,0,0,0.5);">[label]</span>"}
	I.maptext_height = 64
	I.maptext_width = 96
	I.maptext_x = 0
	I.maptext_y = 0
	I.plane = HUD_PLANE
	I.layer = MIND_UI_FRONT
	_inspector_overlay = I
	overlays += I

/obj/abstract/mind_ui_element/proc/RemoveInspectorOverlay()
	if (!_inspector_overlay)
		return
	overlays -= _inspector_overlay
	_inspector_overlay = null


////////////////////////////////////////////////////////////////////
//																  //
//							SCHEMA DUMP							  //
//																  //
////////////////////////////////////////////////////////////////////

// Surfaces the full mindUI state of an admin's mob in a browser popup, including validator results per UI.
// The line-building logic lives on /datum/mind_ui as BuildSchemaDumpLines() so unit tests can exercise it without a real client.
/client/verb/mindui_dump()
	set name = "MindUI Dump"
	set category = "Debug"
	if (!check_rights(R_DEBUG))
		return
	if (!mob || !mob.mind)
		to_chat(src, "<span class='warning'>No mind to inspect.</span>")
		return
	var/list/lines = list("<b>MindUI Schema Dump for [mob.name]</b>")
	for (var/uikey in mob.mind.activeUIs)
		var/datum/mind_ui/U = mob.mind.activeUIs[uikey]
		lines += U.BuildSchemaDumpLines()
	src << browse(jointext(lines, "<br>"), "window=mindui_dump;size=800x600")

// Per-UI dump body for unit tests.
/datum/mind_ui/proc/BuildSchemaDumpLines()
	var/list/out = list()
	out += "<b>[uniqueID]</b> ([type])"
	out += "Elements: [elements.len], SubUIs: [subUIs ? subUIs.len : 0]"
	out += "Active: [active], AutoDisplay: [auto_display], CleanupWhenInvalid: [cleanup_when_invalid]"
	out += "Validator: [mindui_validate_code_name(mindui_static_validate(type))]"
	for (var/obj/abstract/mind_ui_element/E in elements)
		out += "&nbsp;&nbsp;[E.type] @ ([E.offset_x],[E.offset_y]) icon_state=[E.icon_state]"
	return out
