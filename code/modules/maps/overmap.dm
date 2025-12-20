//vgstation interpretation of the overmap using mindui

var/datum/overmap/Overmap

/datum/overmap
	var/list/sectors = list() //cordinate-based sector map which relates an overmap sector to a specific zlevel or planet
	var/size = 11 //square overmap

/datum/overmap/New()
	..()
	for(var/i = 1; i <= size; i++)
		sectors += list(list())  // Add a new row (list) to sectors
		for(var/j = 1; j <= size; j++)
			var/datum/sector/S = new
			S.x = i
			S.y = j
			sectors[i] += S  // Add the sector to the row

	// Place a star in the center of the map
	var/center = round(size / 2) + 1
	var/datum/sector/center_sector = sectors[center][center]
	center_sector.place_star()

/datum/overmap/proc/populate()
	var/list/zs_to_assign = list(map.zCentcomm, map.zMainStation, map.zAsteroid, map.zDerelict)
	for(var/z_to_assign in zs_to_assign)
		if(!z_to_assign)
			continue // Skip null/0 z-levels
		var/placed = FALSE
		var/tries = 0
		while(!placed)
			var/i = rand(1, size)
			var/j = rand(1, size)
			var/datum/sector/S = sectors[i][j]
			if(!S.contained_entity)
				S.add_entity(z_to_assign)
				placed = TRUE
			else
				tries++
				if(tries > size**size)
					CRASH("Could not place zLevel [z_to_assign] on overmap. This is very bad!")
	var/spawned = 0
	for(var/datum/planet_type/planet_to_assign in SSmapping.planets)
		var/placed = FALSE
		var/tries = 0
		while(!placed)
			var/i = rand(1, size)
			var/j = rand(1, size)
			var/datum/sector/S = sectors[i][j]
			if(!S.contained_entity)
				S.add_entity(planet_to_assign)
				placed = TRUE
			else
				tries++
				if(tries > size**size)
					CRASH("Could not place planet type [planet_to_assign.name] on overmap - no free sectors! Placed [spawned] of [SSmapping.planets.len] planets.")
		spawned++

/datum/sector
	var/x = null
	var/y = null
	var/contained_entity = null
	var/icon/icon = null
	var/icon_path = null
	var/overmap_icon_state = null
	var/accessible = TRUE //if FALSE, travel to this sector is blocked
	var/is_star = FALSE //if TRUE, this sector contains a star

/datum/sector/proc/place_star()
	is_star = TRUE
	accessible = FALSE
	overmap_icon_state = "star_new"
	icon = icon('icons/misc/overmap.dmi', overmap_icon_state)

/datum/sector/proc/add_entity(var/datum/entity)
	contained_entity = entity
	if(istype(entity, /datum/planet_type))
		var/datum/planet_type/P = entity
		overmap_icon_state = P.overmap_icon_state
	else
		if(entity == map.zCentcomm)
			overmap_icon_state = "station-nt"
			accessible = FALSE
		else if(entity == map.zMainStation)
			overmap_icon_state = "station_classic"
		else if(entity == map.zAsteroid)
			overmap_icon_state = "station_asteroid"
		else if(entity == map.zDerelict)
			overmap_icon_state = "outpost_small"
	icon = icon('icons/misc/overmap.dmi', overmap_icon_state)

////////////////////////////////////////////////////////////////////
//                                                                //
//                        OVERMAP MIND UI                         //
//                                                                //
////////////////////////////////////////////////////////////////////

/datum/mind_ui/overmap
	uniqueID = "Overmap"
	x = "CENTER"
	y = "CENTER"
	element_types_to_spawn = list(
		/obj/abstract/mind_ui_element/overmap_background,
		/obj/abstract/mind_ui_element/hoverable/overmap_close,
		/obj/abstract/mind_ui_element/hoverable/movable/overmap_move,
	)
	display_with_parent = TRUE

/datum/mind_ui/overmap/SpawnElements()
	..()
	// Create grid cells dynamically based on overmap size
	if(!Overmap)
		return
	var/grid_size = Overmap.size
	var/cell_size = 32
	var/half_grid = (grid_size * cell_size) / 2

	for(var/i = 1; i <= grid_size; i++)
		for(var/j = 1; j <= grid_size; j++)
			var/obj/abstract/mind_ui_element/hoverable/overmap_cell/cell = new(null, src)
			cell.grid_x = i
			cell.grid_y = j
			// Position cells in a grid pattern, centered on the UI
			// Y is inverted so row 1 is at the bottom
			cell.offset_x = ((i - 1) * cell_size) - half_grid + (cell_size / 2)
			cell.offset_y = ((j - 1) * cell_size) - half_grid + (cell_size / 2)
			cell.UpdateUIScreenLoc()
			elements += cell

/datum/mind_ui/overmap/Display()
	..()
	// Update all cell icons when displaying
	for(var/obj/abstract/mind_ui_element/hoverable/overmap_cell/cell in elements)
		cell.UpdateIcon()

//------------------------------------------------------------
// Background panel for the overmap grid
//------------------------------------------------------------

/obj/abstract/mind_ui_element/overmap_background
	name = "Overmap Background"
	icon = 'icons/ui/32x32.dmi'
	icon_state = "grid_cell"
	layer = MIND_UI_BACK
	mouse_opacity = 1
	alpha = 220

/obj/abstract/mind_ui_element/overmap_background/New(turf/loc, datum/mind_ui/P)
	..()
	// Calculate size based on overmap grid
	if(Overmap)
		var/grid_size = Overmap.size
		var/total_size = grid_size * 32
		var/half_size = total_size / 2
		offset_x = -half_size
		offset_y = -half_size
		UpdateUIScreenLoc()

/obj/abstract/mind_ui_element/overmap_background/UpdateIcon()
	// Background is handled by individual cells - no overlays needed here
	return

//------------------------------------------------------------
// Individual grid cell for each sector
//------------------------------------------------------------

/obj/abstract/mind_ui_element/hoverable/overmap_cell
	name = "Empty Sector"
	icon = 'icons/ui/32x32.dmi'
	icon_state = "grid_cell"
	layer = MIND_UI_BUTTON
	mouse_opacity = 1
	hover_state = FALSE
	element_flags = MINDUI_FLAG_TOOLTIP

	var/grid_x = 0
	var/grid_y = 0

/obj/abstract/mind_ui_element/hoverable/overmap_cell/UpdateIcon()
	if(!Overmap)
		return
	if(grid_x < 1 || grid_x > Overmap.size || grid_y < 1 || grid_y > Overmap.size)
		return

	var/datum/sector/S = Overmap.sectors[grid_x][grid_y]
	overlays.len = 0

	if(S.overmap_icon_state)
		// Use the sector icon directly as the base icon
		icon = 'icons/misc/overmap.dmi'
		icon_state = S.overmap_icon_state

		// Update tooltip
		if(S.is_star)
			tooltip_title = "Star"
			tooltip_content = "Sector ([grid_x], [grid_y]) - Travel blocked"
		else if(S.contained_entity)
			if(istype(S.contained_entity, /datum/planet_type))
				var/datum/planet_type/P = S.contained_entity
				tooltip_title = P.name
				tooltip_content = "Planet at sector ([grid_x], [grid_y])"
			else
				// Handle station z-levels with proper names
				if(S.contained_entity == map.zCentcomm)
					tooltip_title = "Central Command"
				else if(S.contained_entity == map.zMainStation)
					tooltip_title = "Station"
				else if(S.contained_entity == map.zAsteroid)
					tooltip_title = "Mining Asteroid"
				else if(S.contained_entity == map.zDerelict)
					tooltip_title = "Derelict"
				else
					tooltip_title = "Unknown Sector"
				tooltip_content = "Sector ([grid_x], [grid_y])"
		name = tooltip_title
	else
		// Empty sector - show grid cell
		icon = 'icons/ui/32x32.dmi'
		icon_state = "grid_cell"
		tooltip_title = "Empty Sector"
		tooltip_content = "Sector ([grid_x], [grid_y])"
		name = "Empty Sector ([grid_x], [grid_y])"

	// Add accessibility indicator
	if(!S.accessible)
		var/image/blocked = image('icons/ui/32x32.dmi', src, "grid_cell")
		if(blocked)
			blocked.layer = MIND_UI_FRONT
			overlays += blocked

/obj/abstract/mind_ui_element/hoverable/overmap_cell/Click()
	var/mob/M = GetUser()
	if(!M || !Overmap)
		return
	if(grid_x < 1 || grid_x > Overmap.size || grid_y < 1 || grid_y > Overmap.size)
		return

	var/datum/sector/S = Overmap.sectors[grid_x][grid_y]
	if(S.is_star)
		to_chat(M, "<span class='warning'>Sector ([grid_x], [grid_y]): Star - Travel blocked</span>")
	else if(S.contained_entity)
		if(istype(S.contained_entity, /datum/planet_type))
			var/datum/planet_type/P = S.contained_entity
			to_chat(M, "<span class='notice'>Sector ([grid_x], [grid_y]): [P.name]</span>")
		else
			var/sector_name = "Unknown"
			if(S.contained_entity == map.zCentcomm)
				sector_name = "Central Command"
			else if(S.contained_entity == map.zMainStation)
				sector_name = "Station"
			else if(S.contained_entity == map.zAsteroid)
				sector_name = "Mining Asteroid"
			else if(S.contained_entity == map.zDerelict)
				sector_name = "Derelict"
			to_chat(M, "<span class='notice'>Sector ([grid_x], [grid_y]): [sector_name]</span>")
	else
		to_chat(M, "<span class='notice'>Sector ([grid_x], [grid_y]): Empty</span>")

//------------------------------------------------------------
// Close button
//------------------------------------------------------------

/obj/abstract/mind_ui_element/hoverable/overmap_close
	name = "Close Overmap"
	icon = 'icons/ui/32x32.dmi'
	icon_state = "close"
	layer = MIND_UI_FRONT
	mouse_opacity = 1

/obj/abstract/mind_ui_element/hoverable/overmap_close/New(turf/loc, datum/mind_ui/P)
	..()
	if(Overmap)
		var/grid_size = Overmap.size
		var/half_size = (grid_size * 32) / 2
		offset_x = half_size
		offset_y = half_size
		UpdateUIScreenLoc()

/obj/abstract/mind_ui_element/hoverable/overmap_close/Click()
	var/datum/mind_ui/ancestor = parent.GetAncestor()
	ancestor.Hide()

//------------------------------------------------------------
// Move/drag handle
//------------------------------------------------------------

/obj/abstract/mind_ui_element/hoverable/movable/overmap_move
	name = "Move Overmap"
	icon = 'icons/ui/32x32.dmi'
	icon_state = "move"
	layer = MIND_UI_FRONT
	mouse_opacity = 1
	move_whole_ui = TRUE

/obj/abstract/mind_ui_element/hoverable/movable/overmap_move/New(turf/loc, datum/mind_ui/P)
	..()
	if(Overmap)
		var/grid_size = Overmap.size
		var/half_size = (grid_size * 32) / 2
		offset_x = -half_size
		offset_y = half_size
		UpdateUIScreenLoc()

//------------------------------------------------------------
// Admin verb to view overmap
//------------------------------------------------------------

/client/verb/view_overmap()
	set name = "View Overmap"
	set category = "Admin"

	if(!holder)
		to_chat(src, "<span class='warning'>You need admin privileges to use this.</span>")
		return
	if(!Overmap)
		to_chat(src, "<span class='warning'>Overmap has not been initialized!</span>")
		return
	if(!mob)
		return
	mob.DisplayUI("Overmap")
