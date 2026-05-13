/datum/level_manager
	var/mob/user
	var/datum/station_holomap/active_holomap = null
	var/active_holomap_z = null  // Only tracks holomaps (z <= 6), not MindUI

/datum/level_manager/New(mob/M)
	user = M

/datum/level_manager/Destroy()
	close_holomap()
	..()

/datum/level_manager/proc/close_holomap()
	if(active_holomap && user && user.client)
		user.client.images -= active_holomap.station_map
		animate(active_holomap.station_map, alpha = 0, time = 5, easing = LINEAR_EASING)
		QDEL_NULL(active_holomap)
		active_holomap_z = null

/datum/level_manager/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "LevelManager")
		ui.set_autoupdate(TRUE)
		ui.open()

/datum/level_manager/ui_data(mob/user)
	var/list/data = list()
	data["zLevels"] = list()

	for(var/z_index = 1 to map.zLevels.len)
		var/datum/zLevel/Z = map.zLevels[z_index]
		if(!Z)
			continue

		var/list/z_data = list()
		z_data["index"] = z_index
		z_data["name"] = Z.name
		z_data["ref"] = "\ref[Z]"
		// vLevelCount: count only anchors (groups), not every floor in the parent z.
		var/anchor_count = 0
		for(var/datum/virtual_z/Vc in Z.virtual_z_levels)
			if(Vc.floor == 1)
				anchor_count++
		z_data["vLevelCount"] = anchor_count
		z_data["hasHolomap"] = ((HOLOMAP_EXTRA_STATIONMAP + "_[Z.z]") in extraMiniMaps)
		z_data["usesHolomap"] = !istype(Z, /datum/zLevel/dynamic)

		// Check if map is active - holomap for static z-levels, MindUI for dynamic
		var/map_active = FALSE
		if(z_data["usesHolomap"])
			map_active = (active_holomap_z == Z.z)
		else if(user && user.mind && ("zlevel_map" in user.mind.activeUIs))
			var/datum/mind_ui/zlevel_map/zmap = user.mind.activeUIs["zlevel_map"]
			// Only consider it active if it's actually showing AND it's showing this z-level
			// We check the first virtual_z_display element to see which z it's displaying
			if(zmap && zmap.active)
				for(var/obj/abstract/mind_ui_element/hoverable/virtual_z_display/vz_disp in zmap.elements)
					if(vz_disp.v && vz_disp.v.parent_z.z == Z.z)
						map_active = TRUE
						break

		z_data["holomapActive"] = map_active
		z_data["vLevels"] = list()

		for(var/datum/virtual_z/V in Z.virtual_z_levels)
			// Anchor-only emission: non-anchor floors are surfaced inside their anchor's `floors` list.
			if(V.floor != 1)
				continue

			var/list/connected_floors = GetConnectedFloors(V)
			var/list/v_data = list()
			v_data["id"] = V.id
			v_data["display_id"] = V.get_display_id()
			v_data["name"] = V.name
			v_data["ref"] = "\ref[V]"
			v_data["is_multifloor"] = V.is_multifloor()
			v_data["floor_count"] = length(connected_floors)
			v_data["active"] = V.get_active()
			v_data["sizeX"] = V.size_x
			v_data["sizeY"] = V.size_y

			// Planet and shuttle data (group-level; read via getters where available)
			var/datum/planet_type/group_planet = V.get_planet()
			if(group_planet)
				v_data["planetRef"] = "\ref[group_planet]"
				v_data["planetName"] = group_planet.name
			var/datum/shuttle/group_shuttle = V.get_linked_shuttle()
			if(group_shuttle)
				v_data["shuttleRef"] = "\ref[group_shuttle]"
				v_data["shuttleName"] = group_shuttle.name

			// Group-level settings (read via getters so non-anchor reads would still resolve correctly)
			v_data["movementJammed"] = V.get_movement_jammed()
			v_data["gpsAllowed"] = V.get_gps_allowed()
			v_data["teleJammed"] = V.get_tele_jammed()
			v_data["transitionLoops"] = V.get_transition_loops()
			v_data["transitionChannel"] = V.get_transition_channel()

			// Transition crosswrap data (group-level)
			var/list/group_crosswrap = V.get_transition_crosswrap()
			if(group_crosswrap && group_crosswrap.len >= 4)
				v_data["crosswrapNorth"] = group_crosswrap[1]
				v_data["crosswrapSouth"] = group_crosswrap[2]
				v_data["crosswrapEast"] = group_crosswrap[3]
				v_data["crosswrapWest"] = group_crosswrap[4]
				v_data["hasCrosswrap"] = TRUE
			else
				v_data["hasCrosswrap"] = FALSE

			// Per-floor entries and aggregate counts.
			v_data["floors"] = list()
			var/aggregate_mobs = 0
			var/aggregate_players = 0
			var/aggregate_processing = 0
			var/aggregate_paused = 0
			for(var/datum/virtual_z/F in connected_floors)
				// Per-floor mob/player counts using the existing helper (scopes to F's footprint on F.parent_z).
				var/list/mob/floor_mobs = F.get_mobs()
				var/list/mob/floor_players = F.get_players()
				var/floor_processing = 0
				var/floor_paused = 0
				for(var/mob/living/L in floor_mobs)
					if(L.paused)
						floor_paused++
					else
						floor_processing++

				var/list/floor_entry = list()
				floor_entry["floor"] = F.floor
				floor_entry["id"] = F.id
				floor_entry["display_id"] = F.get_display_id()
				floor_entry["ref"] = "\ref[F]"
				floor_entry["parent_z"] = F.parent_z ? F.parent_z.z : 0
				floor_entry["x_min"] = F.x_min
				floor_entry["x_max"] = F.x_max
				floor_entry["y_min"] = F.y_min
				floor_entry["y_max"] = F.y_max
				floor_entry["sizeX"] = F.size_x
				floor_entry["sizeY"] = F.size_y
				floor_entry["mob_count"] = floor_mobs.len
				floor_entry["player_count"] = floor_players.len
				floor_entry["processingMobs"] = floor_processing
				floor_entry["pausedMobs"] = floor_paused
				v_data["floors"] += list(floor_entry)

				aggregate_mobs += floor_mobs.len
				aggregate_players += floor_players.len
				aggregate_processing += floor_processing
				aggregate_paused += floor_paused

			v_data["mob_count"] = aggregate_mobs
			v_data["player_count"] = aggregate_players
			// Legacy fields preserved for the TGUI until Task 15 lands.
			v_data["players"] = aggregate_players
			v_data["processingMobs"] = aggregate_processing
			v_data["pausedMobs"] = aggregate_paused

			z_data["vLevels"] += list(v_data)

		data["zLevels"] += list(z_data)

	return data

/datum/level_manager/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	switch(action)
		if("jump")
			// Accepts either a legacy `ref` or the new `id` (+ optional `floor`) parameter.
			var/datum/virtual_z/V = null
			if(params["id"])
				var/vid = text2num("[params["id"]]") || params["id"]
				var/target_floor = params["floor"] ? (text2num("[params["floor"]]") || 1) : 1
				V = map.getVLevelFloor(vid, target_floor)
			else
				V = locate(params["ref"])
			if(!V || !istype(V) || !V.parent_z)
				to_chat(usr, "<span class='warning'>Invalid virtual z-level reference.</span>")
				return FALSE
			var/center_x = round((V.x_min + V.x_max) / 2)
			var/center_y = round((V.y_min + V.y_max) / 2)
			var/turf/T = locate(center_x, center_y, V.parent_z.z)
			if(T)
				usr.forceMove(T)
				log_admin("[key_name(usr)] jumped to vZ-[V.get_display_id()] ([V.name]) at [center_x],[center_y],[V.parent_z.z].")
				message_admins("<span class='notice'>[key_name_admin(usr)] jumped to vZ-[V.get_display_id()] ([V.name]).</span>", 1)
			return TRUE

		if("add_floor_above")
			var/vid = text2num("[params["id"]]") || params["id"]
			var/datum/virtual_z/anchor = map.getVLevel(vid)
			if(!anchor)
				to_chat(usr, "<span class='warning'>Invalid virtual z-level id.</span>")
				return TRUE
			var/datum/virtual_z/new_floor = map.addFloorAbove(anchor)
			if(new_floor)
				log_admin("[key_name(usr)] added a new floor (floor=[new_floor.floor]) to vZ-[anchor.id] ([anchor.name]).")
				message_admins("<span class='notice'>[key_name_admin(usr)] added a new floor to vZ-[anchor.id] ([anchor.name]).</span>", 1)
			else
				to_chat(usr, "<span class='warning'>Failed to add new floor.</span>")
			return TRUE

		if("remove_top_floor")
			var/vid = text2num("[params["id"]]") || params["id"]
			var/force = params["force"] ? TRUE : FALSE
			var/datum/virtual_z/anchor = map.getVLevel(vid)
			if(!anchor)
				to_chat(usr, "<span class='warning'>Invalid virtual z-level id.</span>")
				return TRUE
			var/result = map.removeTopFloor(anchor, force)
			if(!result)
				if(!force)
					to_chat(usr, "<span class='warning'>Top floor has mobs or structures. Use force to remove anyway.</span>")
				else
					to_chat(usr, "<span class='warning'>Failed to remove top floor.</span>")
			else
				log_admin("[key_name(usr)] removed the top floor of vZ-[anchor.id] ([anchor.name])[force ? " (forced)" : ""].")
				message_admins("<span class='notice'>[key_name_admin(usr)] removed the top floor of vZ-[anchor.id] ([anchor.name]).</span>", 1)
			return TRUE

		if("refresh_footprint")
			var/vid = text2num("[params["id"]]") || params["id"]
			var/target_floor = params["floor"] ? (text2num("[params["floor"]]") || 1) : 1
			var/datum/virtual_z/v = map.getVLevelFloor(vid, target_floor)
			if(!v)
				to_chat(usr, "<span class='warning'>Invalid virtual z-level floor.</span>")
				return TRUE
			if(v.floor == 1)
				to_chat(usr, "<span class='warning'>Anchor floor footprint is authoritative and cannot be recomputed.</span>")
				return TRUE
			v.recompute_footprint()
			log_admin("[key_name(usr)] recomputed footprint for vZ-[v.get_display_id()] ([v.name]).")
			return TRUE

		if("toggle_pause")
			var/datum/virtual_z/V = locate(params["ref"])
			if(!V || !istype(V))
				to_chat(usr, "<span class='warning'>Invalid virtual z-level reference.</span>")
				return FALSE
			// Group-level state lives on the anchor; flip via the setter so the change applies group-wide.
			var/new_active = !V.get_active()
			V.set_active(new_active)
			// set_status handles mob pause propagation; call it on the anchor so the whole group's mobs follow.
			V.group_anchor.set_status(new_active)
			log_admin("[key_name(usr)] [new_active ? "activated" : "paused"] vZ-[V.get_display_id()] ([V.name]).")
			message_admins("<span class='notice'>[key_name_admin(usr)] [new_active ? "activated" : "paused"] vZ-[V.get_display_id()] ([V.name]).</span>", 1)
			return TRUE

		if("vv_zlevel")
			var/datum/zLevel/Z = locate(params["ref"])
			if(!Z || !istype(Z))
				return FALSE
			usr.client.debug_variables(Z)
			return TRUE

		if("vv_vlevel")
			var/datum/virtual_z/V = locate(params["ref"])
			if(!V || !istype(V))
				return FALSE
			usr.client.debug_variables(V)
			return TRUE

		if("vv_planet")
			var/datum/virtual_z/V = locate(params["ref"])
			if(!V || !istype(V) || !V.planet)
				return FALSE
			usr.client.debug_variables(V.planet)
			return TRUE

		if("vv_shuttle")
			var/datum/virtual_z/V = locate(params["ref"])
			if(!V || !istype(V) || !V.linked_shuttle)
				return FALSE
			usr.client.debug_variables(V.linked_shuttle)
			return TRUE

		if("toggle_movement_jam")
			var/datum/virtual_z/V = locate(params["ref"])
			if(!V || !istype(V))
				return FALSE
			// Group-level write goes through the setter so the anchor's field is updated.
			var/new_value = !V.get_movement_jammed()
			V.set_movement_jammed(new_value)
			V.group_anchor.update_settings()
			log_admin("[key_name(usr)] [new_value ? "enabled" : "disabled"] movement jamming for vZ-[V.get_display_id()] ([V.name]).")
			return TRUE

		if("toggle_gps")
			var/datum/virtual_z/V = locate(params["ref"])
			if(!V || !istype(V))
				return FALSE
			var/new_value = !V.get_gps_allowed()
			V.set_gps_allowed(new_value)
			log_admin("[key_name(usr)] [new_value ? "enabled" : "disabled"] GPS for vZ-[V.get_display_id()] ([V.name]).")
			return TRUE

		if("cycle_teleport")
			var/datum/virtual_z/V = locate(params["ref"])
			if(!V || !istype(V))
				return FALSE
			// Cycle through: ALLOWED -> EXPENSIVE -> FORBIDDEN -> ALLOWED on the group anchor.
			var/cur = V.get_tele_jammed()
			var/next
			switch(cur)
				if(VZ_TELEPORTATION_ALLOWED)
					next = VZ_TELEPORTATION_EXPENSIVE
				if(VZ_TELEPORTATION_EXPENSIVE)
					next = VZ_TELEPORTATION_FORBIDDEN
				if(VZ_TELEPORTATION_FORBIDDEN)
					next = VZ_TELEPORTATION_ALLOWED
				else
					next = VZ_TELEPORTATION_FORBIDDEN
			V.set_tele_jammed(next)
			var/tele_text
			switch(next)
				if(VZ_TELEPORTATION_ALLOWED)
					tele_text = "allowed"
				if(VZ_TELEPORTATION_EXPENSIVE)
					tele_text = "expensive (requires crystals)"
				if(VZ_TELEPORTATION_FORBIDDEN)
					tele_text = "forbidden"
			log_admin("[key_name(usr)] set teleportation to [tele_text] for vZ-[V.get_display_id()] ([V.name]).")
			return TRUE

		if("toggle_transition_loops")
			var/datum/virtual_z/V = locate(params["ref"])
			if(!V || !istype(V))
				return FALSE
			// Crosswrap / transition channel / transition loops are forbidden on multi-floor groups.
			var/datum/virtual_z/anchor_check = V.group_anchor
			if(anchor_check && anchor_check.is_multifloor())
				to_chat(usr, "<span class='warning'>Crosswrap and transition channel are not permitted on multi-floor vlevels.</span>")
				return TRUE
			// transitionLoops lives on the anchor; write it directly there.
			anchor_check.transitionLoops = !anchor_check.transitionLoops
			log_admin("[key_name(usr)] [anchor_check.transitionLoops ? "enabled" : "disabled"] transition loops for vZ-[V.get_display_id()] ([V.name]).")
			return TRUE

		if("change_transition_channel")
			var/datum/virtual_z/V = locate(params["ref"])
			if(!V || !istype(V))
				return FALSE
			var/datum/virtual_z/anchor_check = V.group_anchor
			if(anchor_check && anchor_check.is_multifloor())
				to_chat(usr, "<span class='warning'>Crosswrap and transition channel are not permitted on multi-floor vlevels.</span>")
				return TRUE
			// Operate on the anchor for the remainder of this branch so transition_channel state stays group-coherent.
			V = anchor_check

			// Build list of existing channels
			var/list/channel_choices = list()
			for(var/channel_name in accessable_v_levels)
				channel_choices += channel_name
			channel_choices += "Create New Channel..."

			var/old_channel = V.transition_channel
			var/channel_choice = input(usr, "Select transition channel for vZ-[V.id] ([V.name]):\n(Current: [old_channel])", "Transition Channel") as null|anything in channel_choices
			if(!channel_choice)
				return FALSE

			var/new_channel = channel_choice
			if(channel_choice == "Create New Channel...")
				new_channel = input(usr, "Enter name for new transition channel:", "New Channel") as null|text
				if(!new_channel)
					return FALSE
				// Create the new channel if it doesn't exist
				if(!(new_channel in accessable_v_levels))
					accessable_v_levels[new_channel] = list()

			// Remove from old channel if not movement jammed
			if(!V.movementJammed && (old_channel in accessable_v_levels))
				accessable_v_levels[old_channel] -= "[V.id]"

			// Update the channel
			V.transition_channel = new_channel

			// Add to new channel if not movement jammed
			if(!V.movementJammed)
				if(!(new_channel in accessable_v_levels))
					accessable_v_levels[new_channel] = list()
				accessable_v_levels[new_channel] += list("[V.id]" = V.movementChance)

			log_admin("[key_name(usr)] changed transition channel for vZ-[V.id] ([V.name]) from '[old_channel]' to '[new_channel]'.")
			return TRUE

		if("configure_crosswrap")
			var/datum/virtual_z/V = locate(params["ref"])
			if(!V || !istype(V))
				return FALSE
			var/datum/virtual_z/anchor_check = V.group_anchor
			if(anchor_check && anchor_check.is_multifloor())
				to_chat(usr, "<span class='warning'>Crosswrap and transition channel are not permitted on multi-floor vlevels.</span>")
				return TRUE
			// Crosswrap state lives on the anchor; mutate it there so reads via getters stay coherent.
			V = anchor_check

			// Build list of available vLevels for selection
			var/list/vlevel_choices = list("None" = null)
			for(var/datum/virtual_z/vz in map.getAllVLevels())
				if(vz.id != V.id) // Don't allow self-reference (anchor only — non-anchor floors share the same id)
					if(vz.floor != 1)
						continue
					vlevel_choices["vZ-[vz.id]: [vz.name]"] = vz.id

			// Get current values
			var/current_north = null
			var/current_south = null
			var/current_east = null
			var/current_west = null
			if(V.transition_crosswrap_v && V.transition_crosswrap_v.len >= 4)
				current_north = V.transition_crosswrap_v[1]
				current_south = V.transition_crosswrap_v[2]
				current_east = V.transition_crosswrap_v[3]
				current_west = V.transition_crosswrap_v[4]

			// Ask for each direction
			var/north_choice = input(usr, "Select vLevel to crosswrap NORTH edge to:\n(Current: [current_north ? "vZ-[current_north]" : "None"])", "Crosswrap North") as null|anything in vlevel_choices
			var/south_choice = input(usr, "Select vLevel to crosswrap SOUTH edge to:\n(Current: [current_south ? "vZ-[current_south]" : "None"])", "Crosswrap South") as null|anything in vlevel_choices
			var/east_choice = input(usr, "Select vLevel to crosswrap EAST edge to:\n(Current: [current_east ? "vZ-[current_east]" : "None"])", "Crosswrap East") as null|anything in vlevel_choices
			var/west_choice = input(usr, "Select vLevel to crosswrap WEST edge to:\n(Current: [current_west ? "vZ-[current_west]" : "None"])", "Crosswrap West") as null|anything in vlevel_choices

			// Get the vLevel IDs from the choices
			var/north_id = vlevel_choices[north_choice]
			var/south_id = vlevel_choices[south_choice]
			var/east_id = vlevel_choices[east_choice]
			var/west_id = vlevel_choices[west_choice]

			// Check if all are null - if so, clear the crosswrap
			if(!north_id && !south_id && !east_id && !west_id)
				V.transition_crosswrap_v = null
				log_admin("[key_name(usr)] cleared transition crosswraps for vZ-[V.id] ([V.name]).")
			else
				V.transition_crosswrap_v = list(north_id, south_id, east_id, west_id)
				log_admin("[key_name(usr)] set transition crosswraps for vZ-[V.id] ([V.name]): N=[north_id], S=[south_id], E=[east_id], W=[west_id].")

			return TRUE

		if("create_zlevel")
			// Build list of available zLevel types
			var/list/zlevel_types = list(
				"Dynamic" = /datum/zLevel/dynamic,
				"Space" = /datum/zLevel/space,
				"Mining" = /datum/zLevel/mining,
				"Away" = /datum/zLevel/away
			)
			var/type_choice = input(usr, "Select Z-Level type:", "New Z-Level") as null|anything in list("Dynamic", "Space", "Mining", "Away")
			if(!type_choice)
				return FALSE
			var/zlevel_type = zlevel_types[type_choice]

			var/name = input(usr, "Enter a name for the new Z-Level:", "New Z-Level") as null|text
			if(!name)
				return FALSE

			// Increment world.maxz and create the new zLevel
			skip_turf_init = TRUE
			world.maxz++
			skip_turf_init = FALSE

			var/datum/zLevel/new_z = new zlevel_type()
			new_z.name = name
			new_z.z = world.maxz
			map.zLevels += new_z

			log_admin("[key_name(usr)] created a new Z-Level: [name] (Z: [world.maxz], Type: [type_choice]).")
			message_admins("<span class='notice'>[key_name_admin(usr)] created a new Z-Level: [name] (Z: [world.maxz], Type: [type_choice]).</span>", 1)
			return TRUE

		if("show_map")
			var/datum/zLevel/Z = locate(params["ref"])
			if(!Z || !istype(Z))
				to_chat(usr, "<span class='warning'>Invalid z-level reference.</span>")
				return FALSE

			// Static z-levels use holomap, dynamic z-levels use MindUI
			if(!istype(Z, /datum/zLevel/dynamic))
				// Toggle holomap for base z-levels
				if(active_holomap_z == Z.z)
					// Close currently active holomap
					close_holomap()
					to_chat(usr, "<span class='notice'>Closed holomap for Z-Level [Z.z]: [Z.name]</span>")
					log_admin("[key_name(usr)] closed holomap for Z-[Z.z] ([Z.name]).")
					return TRUE

				// Show holomap for base z-levels
				if(!usr.client || !usr.hud_used || !usr.hud_used.holomap_obj)
					to_chat(usr, "<span class='warning'>Cannot display holomap - HUD not available.</span>")
					return FALSE

				// Check if holomap exists for this z-level
				var/holomap_key = HOLOMAP_EXTRA_STATIONMAP + "_[Z.z]"
				if(!(holomap_key in extraMiniMaps))
					to_chat(usr, "<span class='warning'>No holomap available for Z-Level [Z.z].</span>")
					return FALSE

				// Close any existing holomap first
				close_holomap()

				// Create new holomap datum
				active_holomap = new()
				active_holomap_z = Z.z
				var/turf/target_turf = locate(round(world.maxx/2), round(world.maxy/2), Z.z)
				if(!target_turf)
					to_chat(usr, "<span class='warning'>Failed to find valid location on Z-Level [Z.z].</span>")
					close_holomap()
					return FALSE

				active_holomap.initialize_holomap(target_turf, FALSE, usr)
				active_holomap.station_map.loc = usr.hud_used.holomap_obj
				active_holomap.station_map.alpha = 0
				animate(active_holomap.station_map, alpha = 255, time = 5, easing = LINEAR_EASING)

				usr.client.images |= active_holomap.station_map
				to_chat(usr, "<span class='notice'>Displaying holomap for Z-Level [Z.z]: [Z.name]</span>")
				log_admin("[key_name(usr)] opened holomap for Z-[Z.z] ([Z.name]).")

			else
				// Toggle MindUI for virtual z-levels
				if(!usr.mind)
					to_chat(usr, "<span class='warning'>You need a mind to view the virtual z-level map.</span>")
					return FALSE

				// Check if it's already open for this z-level
				var/datum/mind_ui/zlevel_map/existing_zmap
				var/showing_this_z = FALSE
				if("zlevel_map" in usr.mind.activeUIs)
					existing_zmap = usr.mind.activeUIs["zlevel_map"]
					// Check if it's showing this specific z-level
					if(existing_zmap.active)
						for(var/obj/abstract/mind_ui_element/hoverable/virtual_z_display/vz_disp in existing_zmap.elements)
							if(vz_disp.v && vz_disp.v.parent_z.z == Z.z)
								showing_this_z = TRUE
								break

				// If already showing this z-level, hide it
				if(showing_this_z)
					existing_zmap.Hide()
					to_chat(usr, "<span class='notice'>Closed virtual z-level map for Z-[Z.z] ([Z.name]).</span>")
					log_admin("[key_name(usr)] closed virtual z-level map for Z-[Z.z] ([Z.name]).")
					return TRUE

				// Get or create the zlevel_map UI
				var/datum/mind_ui/zlevel_map/zmap
				if(existing_zmap)
					zmap = existing_zmap
				else
					// Create new UI by calling DisplayUI, which will instantiate it
					usr.DisplayUI("zlevel_map")
					if("zlevel_map" in usr.mind.activeUIs)
						zmap = usr.mind.activeUIs["zlevel_map"]

				if(!zmap)
					to_chat(usr, "<span class='warning'>Failed to initialize z-level map interface.</span>")
					return FALSE

				// Display with the specific z-level (don't set active_holomap_z - that's only for holomaps)
				zmap.Display(Z.z)
				log_admin("[key_name(usr)] opened virtual z-level map for Z-[Z.z] ([Z.name]).")

			return TRUE

		if("create_vlevel")
			var/list/vlevel_options = list(
				"Generate Planet",
				"Generate Encounter",
				"Load Map Element",
				"Create Transit Level",
				"Manual Creation"
			)
			var/vlevel_choice = input(usr, "Select vLevel creation method:", "New vLevel") as null|anything in vlevel_options
			if(!vlevel_choice)
				return FALSE

			switch(vlevel_choice)
				if("Generate Encounter")
					// Get list of available shuttles
					var/list/shuttle_names = list()
					for(var/datum/shuttle/S in shuttles)
						shuttle_names[S.name] = S

					if(!shuttle_names.len)
						to_chat(usr, "<span class='warning'>No shuttles available!</span>")
						return FALSE

					var/shuttle_choice = input(usr, "Select a shuttle for the encounter:", "Generate Encounter") as null|anything in shuttle_names
					if(!shuttle_choice)
						return FALSE

					var/datum/shuttle/chosen_shuttle = shuttle_names[shuttle_choice]

					if(!chosen_shuttle.linked_port)
						to_chat(usr, "<span class='warning'>Shuttle has no linked docking port!</span>")
						return FALSE

					if(!chosen_shuttle.linked_area)
						to_chat(usr, "<span class='warning'>Shuttle has no linked area!</span>")
						return FALSE

					var/datum/encounter/enc = SSmapping.generate_scanner_encounter(chosen_shuttle)
					if(enc)
						log_admin("[key_name(usr)] generated encounter '[enc.encounter_name]' for shuttle '[shuttle_choice]' (vZ: [enc.v.id]).")
						message_admins("<span class='notice'>[key_name_admin(usr)] generated encounter '[enc.encounter_name]' for shuttle '[shuttle_choice]' (vZ: [enc.v.id]).</span>", 1)
					else
						to_chat(usr, "<span class='warning'>Failed to generate encounter!</span>")
					return TRUE

				if("Generate Planet")
					// Open the procedural generation panel
					var/datum/admins/admin_holder = usr.client?.holder
					if(admin_holder)
						admin_holder.procedural_generation_panel()
					return TRUE

				if("Load Map Element")
					// Get list of available map elements
					var/list/map_element_types = subtypesof(/datum/map_element) - /datum/map_element/dungeon - /datum/map_element/ruin - /datum/map_element/fixedvault
					var/list/map_element_names = list()
					for(var/path in map_element_types)
						var/datum/map_element/ME = path
						var/element_name = initial(ME.name)
						if(element_name)
							map_element_names[element_name] = path

					if(!map_element_names.len)
						to_chat(usr, "<span class='warning'>No map elements available!</span>")
						return FALSE

					var/element_choice = input(usr, "Select a map element to load:", "Load Map Element") as null|anything in map_element_names
					if(!element_choice)
						return FALSE

					var/element_path = map_element_names[element_choice]
					var/datum/map_element/ME = new element_path()
					ME.assign_dimensions()

					var/buffer_size = 0
					var/turf_type = /turf/space
					var/teleport_choice = VZ_TELEPORTATION_FORBIDDEN
					var/gps_allowed = FALSE
					var/movement_jammed = TRUE
					var/transition_loops = FALSE
					var/list/transition_crosswrap = null
					var/list/adv_settings_opt = list("Yes", "No")
					var/adv_settings = input(usr, "Configure advanced settings (buffer size, base turf type, teleportation blocking, etc)?", "Advanced Settings", "No") as null|anything in adv_settings_opt
					if(adv_settings == "Yes")
						// Buffer size
						buffer_size = input(usr, "Enter buffer size (tiles around map element, 0-50):\n(0 = no buffer, vLevel matches map element size)", "Buffer Size", 10) as null|num
						if(isnull(buffer_size) || buffer_size < 0 || buffer_size > 50)
							buffer_size = 0

						// Base turf type
						turf_type = null
						if(alert(usr, "Set a base turf type for the vLevel?", "Base Turf", "Yes", "No") == "Yes")
							turf_type = input(usr, "Select base turf type:", "Turf Type") as null|anything in typesof(/turf)
							if(!turf_type)
								turf_type = /turf/space

						// Teleportation blocking
						var/teleport_options = list(
							"Allowed" = VZ_TELEPORTATION_ALLOWED,
							"Requires Natural Bluespace Crystals" = VZ_TELEPORTATION_EXPENSIVE,
							"Forbidden" = VZ_TELEPORTATION_FORBIDDEN
						)
						teleport_choice = input(usr, "Select teleportation setting for the vLevel:", "Teleportation Setting") as null|anything in teleport_options
						if(!teleport_choice)
							teleport_choice = VZ_TELEPORTATION_FORBIDDEN

						// GPS allowance
						if(alert(usr, "Allow regular GPS functions in this vLevel?", "GPS Functionality", "Yes", "No") == "Yes")
							gps_allowed = TRUE

						// Movement jamming
						if(alert(usr, "Prevent access to this vLevel by drifting?", "Movement Jamming", "Yes", "No") == "No")
							movement_jammed = FALSE

						// Transition loops
						if(alert(usr, "Should hitting this vLevel's border send you back to this vLevel?", "Transition Loops", "Yes", "No") == "Yes")
							transition_loops = TRUE

						// Transition crosswraps
						if(alert(usr, "Configure transition crosswraps?\n(Define specific vLevels to transition to when hitting each edge)", "Transition Crosswraps", "Yes", "No") == "Yes")
							// Build list of existing vLevels for selection
							var/list/vlevel_choices = list("None" = null)
							for(var/datum/virtual_z/vz in map.getAllVLevels())
								vlevel_choices["vZ-[vz.id]: [vz.name]"] = vz.id

							var/north_choice = input(usr, "Select vLevel to crosswrap NORTH edge to:", "Crosswrap North") as null|anything in vlevel_choices
							var/south_choice = input(usr, "Select vLevel to crosswrap SOUTH edge to:", "Crosswrap South") as null|anything in vlevel_choices
							var/east_choice = input(usr, "Select vLevel to crosswrap EAST edge to:", "Crosswrap East") as null|anything in vlevel_choices
							var/west_choice = input(usr, "Select vLevel to crosswrap WEST edge to:", "Crosswrap West") as null|anything in vlevel_choices

							var/north_id = vlevel_choices[north_choice]
							var/south_id = vlevel_choices[south_choice]
							var/east_id = vlevel_choices[east_choice]
							var/west_id = vlevel_choices[west_choice]

							if(north_id || south_id || east_id || west_id)
								transition_crosswrap = list(north_id, south_id, east_id, west_id)

					// Re-fetch dimensions fresh to avoid any caching issues
					var/list/fresh_dims = ME.get_dimensions()
					var/map_width = fresh_dims[1]
					var/map_height = fresh_dims[2]

					// Validate dimensions
					if(!map_width || !map_height || map_width < 1 || map_height < 1)
						to_chat(usr, "<span class='warning'>Could not determine map element dimensions! (Got [map_width]x[map_height])</span>")
						return FALSE

					// Create vLevel with explicit size calculation
					var/vlevel_width = map_width + (buffer_size * 2)
					var/vlevel_height = map_height + (buffer_size * 2)
					var/datum/virtual_z/new_vz = map.addVLevel(vlevel_width, vlevel_height, FALSE, turf_type)
					if(new_vz)
						new_vz.name = "Map Element: [ME.name]"
						new_vz.level_type = VZ_PROTECTED
						// Load the actual map element content into the vLevel
						// The maploader adds 1 to these offsets, so we subtract 1 to compensate
						var/load_x = new_vz.x_min + buffer_size - 1
						var/load_y = new_vz.y_min + buffer_size - 1
						UNTIL(ME.load(load_x, load_y, new_vz.parent_z.z, 0, TRUE))

						if(adv_settings == "Yes")
							new_vz.gps_allowed = gps_allowed
							new_vz.teleJammed = teleport_choice
							new_vz.movementJammed = movement_jammed
							new_vz.transitionLoops = transition_loops
							new_vz.transition_crosswrap_v = transition_crosswrap
							new_vz.update_settings()

						for(var/turf/T in new_vz.get_turfs())
							T.v = new_vz
						log_admin("[key_name(usr)] loaded map element '[element_choice]' as vLevel (vZ: [new_vz.id], MapSize: [map_width]x[map_height], vLevelSize: [vlevel_width]x[vlevel_height], Buffer: [buffer_size], LoadPos: [load_x],[load_y]).")
						message_admins("<span class='notice'>[key_name_admin(usr)] loaded map element '[element_choice]' as vLevel (vZ: [new_vz.id], Size: [map_width]x[map_height]).</span>", 1)
					return TRUE

				if("Create Transit Level")
					// Get list of available shuttles
					var/list/shuttle_names = list()
					for(var/datum/shuttle/S in shuttles)
						shuttle_names[S.name] = S

					if(!shuttle_names.len)
						to_chat(usr, "<span class='warning'>No shuttles available!</span>")
						return FALSE

					var/shuttle_choice = input(usr, "Select a shuttle for transit level:", "Transit Level") as null|anything in shuttle_names
					if(!shuttle_choice)
						return FALSE

					var/datum/shuttle/chosen_shuttle = shuttle_names[shuttle_choice]

					// Check if shuttle has a linked port
					if(!chosen_shuttle.linked_port)
						to_chat(usr, "<span class='warning'>Shuttle has no linked docking port!</span>")
						return FALSE

					// Get shuttle dimensions and direction
					var/list/shuttle_size = chosen_shuttle.get_size()
					if(!shuttle_size || shuttle_size.len < 2)
						to_chat(usr, "<span class='warning'>Could not determine shuttle size!</span>")
						return FALSE

					var/shuttle_width = shuttle_size[1]
					var/shuttle_height = shuttle_size[2]

					// Use shuttle's current direction
					var/direction = chosen_shuttle.dir

					// Calculate transit area size: shuttle dimensions + 10 on each side
					var/padding = 10
					var/transit_width = shuttle_width + (padding * 2)
					var/transit_height = shuttle_height + (padding * 2)

					var/datum/virtual_z/new_vz = map.addTransitVLevel(chosen_shuttle)
					if(new_vz)
						// Create the transit docking port
						// Get the shuttle docking port's offset from the shuttle's lower left corner
						var/list/offsets = chosen_shuttle.get_docking_port_offset()
						if(offsets && offsets.len >= 2)
							var/port_x = offsets[1]
							var/port_y = offsets[2]

							// Calculate destination turf for the docking port
							var/dest_x = new_vz.x_min + padding + port_x
							var/dest_y = new_vz.y_min + padding + port_y
							var/turf/destination_turf = get_step(locate(dest_x, dest_y, new_vz.parent_z.z), chosen_shuttle.linked_port.dir)

							// Create the transit docking port
							var/obj/docking_port/destination/transit/transit_dock = new(destination_turf)
							transit_dock.dir = turn(chosen_shuttle.linked_port.dir, 180)
							transit_dock.areaname = "[chosen_shuttle.name] transit"
							transit_dock.generate_borders = TRUE

							// Link the transit port to the shuttle
							chosen_shuttle.transit_port = transit_dock
							new_vz.level_type = VZ_TRANSIT

							log_admin("[key_name(usr)] created transit vLevel for shuttle '[shuttle_choice]' (vZ: [new_vz.id], Size: [transit_width]x[transit_height], Dir: [dir2text(direction)]).")
							message_admins("<span class='notice'>[key_name_admin(usr)] created transit vLevel for shuttle '[shuttle_choice]' (vZ: [new_vz.id]).</span>", 1)
						else
							to_chat(usr, "<span class='warning'>Could not determine shuttle docking port offset!</span>")
							return FALSE
					return TRUE

				if("Manual Creation")
					var/name = input(usr, "Enter a name for the new vLevel:", "New vLevel") as null|text
					if(!name)
						return FALSE

					var/width = input(usr, "Enter width (tiles, 10-255):", "vLevel Width", 50) as null|num
					if(!width || width < 10 || width > 255)
						return FALSE

					var/height = input(usr, "Enter height (tiles, 10-255):", "vLevel Height", 50) as null|num
					if(!height || height < 10 || height > 255)
						return FALSE

					var/turf_type = null
					if(alert(usr, "Set a base turf type for the vLevel?", "Base Turf", "Yes", "No") == "Yes")
						turf_type = input(usr, "Select base turf type:", "Turf Type") as null|anything in typesof(/turf)
						if(!turf_type)
							return FALSE

					// Advanced settings for manual creation
					var/teleport_choice = VZ_TELEPORTATION_FORBIDDEN
					var/gps_allowed = FALSE
					var/movement_jammed = TRUE
					var/transition_loops = FALSE
					var/list/transition_crosswrap = null

					if(alert(usr, "Configure advanced settings (teleportation, GPS, movement jamming, crosswraps)?", "Advanced Settings", "Yes", "No") == "Yes")
						// Teleportation blocking
						var/teleport_options = list(
							"Allowed" = VZ_TELEPORTATION_ALLOWED,
							"Requires Natural Bluespace Crystals" = VZ_TELEPORTATION_EXPENSIVE,
							"Forbidden" = VZ_TELEPORTATION_FORBIDDEN
						)
						teleport_choice = input(usr, "Select teleportation setting for the vLevel:", "Teleportation Setting") as null|anything in teleport_options
						if(!teleport_choice)
							teleport_choice = VZ_TELEPORTATION_FORBIDDEN

						// GPS allowance
						if(alert(usr, "Allow regular GPS functions in this vLevel?", "GPS Functionality", "Yes", "No") == "Yes")
							gps_allowed = TRUE

						// Movement jamming
						if(alert(usr, "Prevent access to this vLevel by drifting?", "Movement Jamming", "Yes", "No") == "No")
							movement_jammed = FALSE

						// Transition loops
						if(alert(usr, "Should hitting this vLevel's border send you back to this vLevel?", "Transition Loops", "Yes", "No") == "Yes")
							transition_loops = TRUE

						// Transition crosswraps
						if(alert(usr, "Configure transition crosswraps?\\n(Define specific vLevels to transition to when hitting each edge)", "Transition Crosswraps", "Yes", "No") == "Yes")
							// Build list of existing vLevels for selection
							var/list/vlevel_choices = list("None" = null)
							for(var/datum/virtual_z/vz in map.getAllVLevels())
								vlevel_choices["vZ-[vz.id]: [vz.name]"] = vz.id

							var/north_choice = input(usr, "Select vLevel to crosswrap NORTH edge to:", "Crosswrap North") as null|anything in vlevel_choices
							var/south_choice = input(usr, "Select vLevel to crosswrap SOUTH edge to:", "Crosswrap South") as null|anything in vlevel_choices
							var/east_choice = input(usr, "Select vLevel to crosswrap EAST edge to:", "Crosswrap East") as null|anything in vlevel_choices
							var/west_choice = input(usr, "Select vLevel to crosswrap WEST edge to:", "Crosswrap West") as null|anything in vlevel_choices

							var/north_id = vlevel_choices[north_choice]
							var/south_id = vlevel_choices[south_choice]
							var/east_id = vlevel_choices[east_choice]
							var/west_id = vlevel_choices[west_choice]

							if(north_id || south_id || east_id || west_id)
								transition_crosswrap = list(north_id, south_id, east_id, west_id)

					var/datum/virtual_z/new_vz = map.addVLevel(width, height, fill_turf_type = turf_type)
					if(new_vz)
						new_vz.name = name
						new_vz.level_type = VZ_SPACE
						new_vz.gps_allowed = gps_allowed
						new_vz.teleJammed = teleport_choice
						new_vz.movementJammed = movement_jammed
						new_vz.transitionLoops = transition_loops
						new_vz.transition_crosswrap_v = transition_crosswrap
						new_vz.update_settings()
						log_admin("[key_name(usr)] created manual vLevel '[name]' (vZ: [new_vz.id], Size: [width]x[height], Turf: [turf_type]).")
						message_admins("<span class='notice'>[key_name_admin(usr)] created manual vLevel '[name]' (vZ: [new_vz.id], Size: [width]x[height]).</span>", 1)
					return TRUE

			return TRUE

	return FALSE

/datum/level_manager/ui_state(mob/user)
	return global.admin_state

/datum/admins/proc/level_manager()
	if (!map.zLevels.len)
		alert("This map has no z-levels!")
		return

	var/datum/level_manager/LM = new(usr)
	LM.tgui_interact(usr)
