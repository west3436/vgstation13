// Overmap admin debug verbs. Registered into admin_verbs_debug in
// code/modules/admin/admin_verbs.dm. Phase 1 ships two: a grid dump and a
// generic-body spawner. Later phases extend with cmd_overmap_drive_shuttle
// (Phase 2) and cmd_overmap_force_scan (Phase 5).

/client/proc/cmd_overmap_dump_grid()
	set category = "Debug"
	set name = "Overmap: Dump Grid"
	set desc = "Print every overmap body and hazard with coordinates."

	if(!holder)
		return
	if(!SSovermap)
		to_chat(usr, "<span class='warning'>SSovermap is not initialized.</span>")
		return

	to_chat(usr, "<span class='notice'>=== Overmap grid: [SSovermap.bodies.len] bodies, [SSovermap.hazards.len] hazards ===</span>")

	if(SSovermap.bodies.len)
		to_chat(usr, "<span class='notice'>--- Bodies ---</span>")
		for(var/datum/overmap_body/B in SSovermap.bodies)
			var/anchor_tag = B.is_anchor ? " \[anchor\]" : ""
			var/admin_tag = B.requires_admin_approval ? " \[admin-gated\]" : ""
			to_chat(usr, "  ([B.x],[B.y]) [B.name] ([B.type])[anchor_tag][admin_tag]")
	else
		to_chat(usr, "  (no bodies)")

	if(SSovermap.hazards.len)
		to_chat(usr, "<span class='notice'>--- Hazards ---</span>")
		for(var/datum/overmap_hazard/H in SSovermap.hazards)
			to_chat(usr, "  ([H.x],[H.y]) [H.name] ([H.type])")
	else
		to_chat(usr, "  (no hazards)")

	log_admin("[key_name(usr)] dumped overmap grid.")


/client/proc/cmd_overmap_spawn_test_body()
	set category = "Debug"
	set name = "Overmap: Spawn Test Body"
	set desc = "Place a generic flavor body at the requested coordinates."

	if(!holder)
		return
	if(!SSovermap)
		to_chat(usr, "<span class='warning'>SSovermap is not initialized.</span>")
		return

	var/tx = input(usr, "Tile X (1-[OVERMAP_WIDTH])", "Spawn Test Body", 13) as num|null
	if(isnull(tx))
		return
	var/ty = input(usr, "Tile Y (1-[OVERMAP_HEIGHT])", "Spawn Test Body", 13) as num|null
	if(isnull(ty))
		return
	if(!SSovermap.is_in_bounds(tx, ty))
		to_chat(usr, "<span class='warning'>([tx],[ty]) is out of bounds.</span>")
		return

	var/datum/overmap_body/generic/B = new(tx, ty)
	B.name = "Admin Test Marker"
	if(SSovermap.add_body(B))
		to_chat(usr, "<span class='notice'>Spawned test body at ([tx],[ty]).</span>")
		log_admin("[key_name(usr)] spawned overmap test body at ([tx],[ty]).")
	else
		qdel(B)
		to_chat(usr, "<span class='warning'>Failed to add test body.</span>")


/client/proc/cmd_overmap_drive_shuttle()
	set category = "Debug"
	set name = "Overmap: Drive Shuttle"
	set desc = "Force a shuttle into overmap mode and dispatch it to a tile coordinate."

	if(!holder)
		return
	if(!SSovermap)
		to_chat(usr, "<span class='warning'>SSovermap is not initialized.</span>")
		return
	if(!shuttles.len)
		to_chat(usr, "<span class='warning'>No shuttles registered.</span>")
		return

	var/datum/shuttle/S = input(usr, "Pick shuttle", "Drive Shuttle") as null|anything in shuttles
	if(!S)
		return

	var/tx = input(usr, "Target X (1-[OVERMAP_WIDTH])", "Drive Shuttle", S.x || 13) as num|null
	if(isnull(tx))
		return
	var/ty = input(usr, "Target Y (1-[OVERMAP_HEIGHT])", "Drive Shuttle", S.y || 13) as num|null
	if(isnull(ty))
		return
	if(!SSovermap.is_in_bounds(tx, ty))
		to_chat(usr, "<span class='warning'>([tx],[ty]) is out of bounds.</span>")
		return

	// Force the shuttle into free-nav overmap mode for testing.
	S.overmap_controlled = TRUE
	S.free_nav = TRUE
	S.hazard_immune = !S.free_nav

	// If the shuttle has no overmap position yet, drop it on the homebase tile
	// so chessboard_path has somewhere to start from.
	if(!S.x || !S.y)
		S.x = 13
		S.y = 13

	// Pick a target body if one exists at (tx, ty); otherwise dispatch with no
	// final body so the shuttle ends up parking.
	var/datum/overmap_body/final_body = null
	for(var/datum/overmap_body/B in SSovermap.get_bodies_at(tx, ty))
		final_body = B
		break

	var/list/path = chessboard_path(S.x, S.y, tx, ty)
	if(!path.len)
		to_chat(usr, "<span class='warning'>Already at ([tx],[ty]).</span>")
		return

	if(S.begin_overmap_travel(path, final_body, usr))
		to_chat(usr, "<span class='notice'>Dispatched [S.name] from ([S.x],[S.y]) to ([tx],[ty]) via [path.len] tiles.</span>")
		log_admin("[key_name(usr)] dispatched overmap shuttle [S.name] to ([tx],[ty]).")
	else
		to_chat(usr, "<span class='warning'>begin_overmap_travel returned FALSE.</span>")
