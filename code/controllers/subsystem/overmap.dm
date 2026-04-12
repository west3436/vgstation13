// SSovermap — owns the canonical overmap world state: a 25x25 grid of bodies
// and hazards, plus per-tick shuttle detection sweeps and movement stepping.
//
// See OVERMAP_DESIGN.md "Subsystem: SSovermap" for the full design. Phase 1
// stands up the data structures, populates the grid at roundstart, and exposes
// query / lifecycle procs. fire() is a no-op stub until Phase 2 wires in
// shuttle movement.

var/datum/subsystem/overmap/SSovermap


/datum/subsystem/overmap
	name        = "Overmap"
	init_order  = SS_INIT_MAP - 0.1            // run after SSmapping (SS_INIT_MAP=20)
	priority    = SS_PRIORITY_MAPPING
	wait        = 5                             // 0.5 second tick
	flags       = SS_BACKGROUND

	// Flat collections — order doesn't matter; iterate for tick-wide sweeps.
	var/list/bodies = list()
	var/list/hazards = list()

	// 2D spatial indices for O(1) tile lookups. tile_bodies[x][y] is either
	// null or a list of /datum/overmap_body. Same for tile_hazards.
	var/list/list/tile_bodies = null
	var/list/list/tile_hazards = null

	// Shuttles currently mid-flight on the overmap. Maintained by Phase 2.
	var/list/moving_shuttles = list()

	// Mind UIs subscribed to push updates. Phase 3 wires this up.
	var/list/listening_uis = list()

	// Reference to the dedicated parking vlevel allocated in Phase 2. Phase 1
	// leaves this null.
	var/datum/virtual_z/parking_vlevel = null


/datum/subsystem/overmap/New()
	NEW_SS_GLOBAL(SSovermap)


/datum/subsystem/overmap/Initialize(timeofday)
	// 1. Allocate the 2D lookup grids. Each cell starts as null and is
	//    promoted to a list lazily by add_body / add_hazard.
	tile_bodies = new /list(OVERMAP_WIDTH)
	tile_hazards = new /list(OVERMAP_WIDTH)
	for(var/i = 1 to OVERMAP_WIDTH)
		tile_bodies[i] = new /list(OVERMAP_HEIGHT)
		tile_hazards[i] = new /list(OVERMAP_HEIGHT)

	// 2. Populate bodies and hazards from the catalog + randomized fills.
	populate_grid()

	// 3. Validate preset routes on every existing shuttle. Routes referencing
	//    out-of-bounds tiles or missing bodies will warn() at this point.
	for(var/datum/shuttle/S in shuttles)
		if(!S.preset_routes || !S.preset_routes.len)
			continue
		for(var/datum/shuttle_route/R in S.preset_routes)
			validate_route(R, S)

	to_chat(world, "<span class='notice'>Overmap: [bodies.len] bodies, [hazards.len] hazards across [OVERMAP_WIDTH]x[OVERMAP_HEIGHT] grid.</span>")
	..()


/datum/subsystem/overmap/fire(resumed = 0)
	for(var/datum/shuttle/S in shuttles)
		if(!S.overmap_controlled)
			continue
		if(S.detection_radius > 0)
			run_detection_for(S)
	for(var/datum/shuttle/S in moving_shuttles)
		step_shuttle(S)


// ---------------------------------------------------------------------------
// Grid queries
// ---------------------------------------------------------------------------

/datum/subsystem/overmap/proc/is_in_bounds(tx, ty)
	return (tx >= 1 && tx <= OVERMAP_WIDTH && ty >= 1 && ty <= OVERMAP_HEIGHT)


/datum/subsystem/overmap/proc/get_bodies_at(tx, ty)
	if(!is_in_bounds(tx, ty))
		return list()
	var/list/L = tile_bodies[tx][ty]
	if(!L)
		return list()
	return L


/datum/subsystem/overmap/proc/get_hazards_at(tx, ty)
	if(!is_in_bounds(tx, ty))
		return list()
	var/list/L = tile_hazards[tx][ty]
	if(!L)
		return list()
	return L


// Returns every overmap-controlled shuttle parked or moving through (x, y).
/datum/subsystem/overmap/proc/get_shuttles_at(tx, ty)
	. = list()
	for(var/datum/shuttle/S in shuttles)
		if(!S.overmap_controlled)
			continue
		if(S.x == tx && S.y == ty)
			. += S


/datum/subsystem/overmap/proc/tile_is_passable(tx, ty)
	if(!is_in_bounds(tx, ty))
		return FALSE
	for(var/datum/overmap_hazard/H in get_hazards_at(tx, ty))
		if(!H.passable)
			return FALSE
	return TRUE


// ---------------------------------------------------------------------------
// Body lifecycle
// ---------------------------------------------------------------------------

/datum/subsystem/overmap/proc/add_body(datum/overmap_body/B)
	if(!B || !is_in_bounds(B.x, B.y))
		warning("Overmap: refused add_body([B]) at out-of-bounds ([B?.x],[B?.y])")
		return FALSE
	bodies += B
	if(!tile_bodies[B.x][B.y])
		tile_bodies[B.x][B.y] = list()
	tile_bodies[B.x][B.y] += B
	if(B.linked_vz)
		B.linked_vz.overmap_body = B
	return TRUE


/datum/subsystem/overmap/proc/remove_body(datum/overmap_body/B)
	if(!B)
		return
	bodies -= B
	if(is_in_bounds(B.x, B.y) && tile_bodies[B.x][B.y])
		tile_bodies[B.x][B.y] -= B
		if(!tile_bodies[B.x][B.y].len)
			tile_bodies[B.x][B.y] = null


// ---------------------------------------------------------------------------
// Hazard lifecycle
// ---------------------------------------------------------------------------

/datum/subsystem/overmap/proc/add_hazard(datum/overmap_hazard/H)
	if(!H || !is_in_bounds(H.x, H.y))
		warning("Overmap: refused add_hazard([H]) at out-of-bounds ([H?.x],[H?.y])")
		return FALSE
	hazards += H
	if(!tile_hazards[H.x][H.y])
		tile_hazards[H.x][H.y] = list()
	tile_hazards[H.x][H.y] += H
	return TRUE


/datum/subsystem/overmap/proc/remove_hazard(datum/overmap_hazard/H)
	if(!H)
		return
	hazards -= H
	if(is_in_bounds(H.x, H.y) && tile_hazards[H.x][H.y])
		tile_hazards[H.x][H.y] -= H
		if(!tile_hazards[H.x][H.y].len)
			tile_hazards[H.x][H.y] = null


// ---------------------------------------------------------------------------
// Free-tile search
// ---------------------------------------------------------------------------

// Find a random unoccupied tile within bounds. min_sep_from_bodies enforces a
// chessboard-distance buffer from every existing body — useful so randomized
// planets don't pile on top of anchor bodies. Returns list(x, y) or null.
/datum/subsystem/overmap/proc/find_free_tile(min_x = 1, max_x = OVERMAP_WIDTH, min_y = 1, max_y = OVERMAP_HEIGHT, require_no_body = TRUE, require_no_hazard = FALSE, min_sep_from_bodies = 0)
	for(var/attempt = 1 to 100)
		var/tx = rand(min_x, max_x)
		var/ty = rand(min_y, max_y)
		if(require_no_body && get_bodies_at(tx, ty).len)
			continue
		if(require_no_hazard && get_hazards_at(tx, ty).len)
			continue
		if(min_sep_from_bodies > 0)
			var/too_close = FALSE
			for(var/datum/overmap_body/B in bodies)
				if(chessboard_dist(B.x - tx, B.y - ty) < min_sep_from_bodies)
					too_close = TRUE
					break
			if(too_close)
				continue
		return list(tx, ty)
	return null


// Single-tile variant — checks only the requested tile, returns 1/0. Used by
// scanner / event encounter spawning when the caller already picked a target.
/datum/subsystem/overmap/proc/find_free_tile_at(tx, ty, require_no_body = TRUE, require_no_hazard = FALSE)
	if(!is_in_bounds(tx, ty))
		return FALSE
	if(require_no_body && get_bodies_at(tx, ty).len)
		return FALSE
	if(require_no_hazard && get_hazards_at(tx, ty).len)
		return FALSE
	return TRUE


// ---------------------------------------------------------------------------
// Per-shuttle detection / movement
// ---------------------------------------------------------------------------

// Sweep the shuttle's detection cone for hazards (rolled per-cycle) and the
// shuttle's body-scan cone for bodies (auto-learned). See
// OVERMAP_DESIGN.md "run_detection_for".
/datum/subsystem/overmap/proc/run_detection_for(datum/shuttle/S)
	if(S.detection_radius <= 0)
		return

	var/parked = (S.waypoints.len == 0)
	var/body_radius = parked ? S.body_scan_radius_parked : S.body_scan_radius_moving
	var/knowledge_changed = FALSE

	// Hazard detection sweep.
	for(var/dx = -S.detection_radius to S.detection_radius)
		for(var/dy = -S.detection_radius to S.detection_radius)
			var/tx = S.x + dx
			var/ty = S.y + dy
			if(!is_in_bounds(tx, ty))
				continue
			if(chessboard_dist(dx, dy) > S.detection_radius)
				continue
			S.reveal_tile(tx, ty)
			for(var/datum/overmap_hazard/H in get_hazards_at(tx, ty))
				if(!S.knows_hazard(H) && prob(S.hazard_detection_chance * 100))
					S.learn_hazard(H)
					knowledge_changed = TRUE

	// Body discovery sweep — larger radius (parked) or smaller (moving), auto-learn.
	if(body_radius > 0)
		for(var/dx = -body_radius to body_radius)
			for(var/dy = -body_radius to body_radius)
				var/tx = S.x + dx
				var/ty = S.y + dy
				if(!is_in_bounds(tx, ty))
					continue
				if(chessboard_dist(dx, dy) > body_radius)
					continue
				S.reveal_tile(tx, ty)
				for(var/datum/overmap_body/B in get_bodies_at(tx, ty))
					if(B.hidden)
						continue
					if(!S.knows_body(B))
						S.learn_body(B)
						knowledge_changed = TRUE

	if(knowledge_changed)
		notify_knowledge_changed(S)

	// Passive transit scanning. Phase 5 hooks the scanner here so a moving
	// ship occasionally stumbles into ambient encounters without any active
	// scan input from the player. See OVERMAP_DESIGN.md "Passive transit
	// scanning".
	if(S.scanner_passive_enabled && S.scanner_passive_chance_per_tick > 0)
		if(prob(S.scanner_passive_chance_per_tick * 100))
			spawn_encounter_near(S, min_dist = 4, max_dist = 10)


// Advance one shuttle by one tick's worth of progress. Quantizes to whole
// tiles via travel_progress accumulator.
/datum/subsystem/overmap/proc/step_shuttle(datum/shuttle/S)
	if(!S.waypoints.len || S.throttle <= 0)
		// Reset last_tick_time so the next resume doesn't credit accumulated wall
		// time toward this segment.
		S.last_tick_time = world.time
		return

	var/list/next_wp = S.waypoints[1]
	var/target_x = next_wp[1]
	var/target_y = next_wp[2]

	// Effective tile time = base time / throttle, plus current tile's hazard cost.
	var/effective_time_ds = S.base_tile_time / S.throttle
	if(!S.hazard_immune)
		for(var/datum/overmap_hazard/H in get_hazards_at(S.x, S.y))
			effective_time_ds += H.traverse_cost

	var/dt_ds = world.time - S.last_tick_time
	S.last_tick_time = world.time
	S.travel_progress += dt_ds / max(effective_time_ds, 1)

	if(S.travel_progress >= 1.0)
		enter_tile(S, target_x, target_y)
		S.waypoints.Cut(1, 2)
		S.travel_progress = 0
		if(!S.waypoints.len)
			try_arrive_at_body(S)

	notify_ship_moved(S)


// Move the shuttle's overmap (x,y) to (nx,ny). Fires hazard entry hooks and
// auto-learns any body present. Does not move turfs — that happens at flight
// completion.
/datum/subsystem/overmap/proc/enter_tile(datum/shuttle/S, nx, ny)
	S.x = nx
	S.y = ny
	if(S.tile_visited && nx >= 1 && nx <= OVERMAP_WIDTH && ny >= 1 && ny <= OVERMAP_HEIGHT)
		S.tile_visited[nx][ny] = OVERMAP_TILE_VISITED
		S.tile_scanned[nx][ny] = OVERMAP_TILE_SCANNED
	if(!S.hazard_immune)
		for(var/datum/overmap_hazard/H in get_hazards_at(nx, ny))
			H.on_ship_enter(S)
	for(var/datum/overmap_body/B in get_bodies_at(nx, ny))
		if(!B.hidden && !S.knows_body(B))
			S.learn_body(B)
	// Soft chime when the shuttle reaches its final waypoint, audible to
	// helm operators viewing the bound UI.
	if(S.waypoints.len <= 1)
		for(var/datum/mind_ui/overmap_base/ui in listening_uis)
			if(ui.linked_shuttle == S && ui.mind?.current)
				ui.mind.current << sound('sound/machines/ping.ogg', wait = 0, volume = 30)


// Called when the last waypoint of a course is reached. Decides between
// docking at a co-located body, rendezvousing with another shuttle, or parking
// in empty space. See OVERMAP_DESIGN.md "try_arrive_at_body".
/datum/subsystem/overmap/proc/try_arrive_at_body(datum/shuttle/S)
	var/list/bodies_here = get_bodies_at(S.x, S.y)
	var/list/shuttles_here = get_shuttles_at(S.x, S.y) - S
	if(!bodies_here.len && !shuttles_here.len)
		S.overmap_park()
		return

	var/datum/overmap_body/target = null
	for(var/datum/overmap_body/B in bodies_here)
		if(B.linked_port == S.destination_port)
			target = B
			break
	if(target)
		S.docked_at = target
		S.overmap_complete_flight()
		target.on_shuttle_arrived(S)
		return

	var/datum/shuttle/rendezvous = null
	for(var/datum/shuttle/other in shuttles_here)
		if(other.linked_port == S.destination_port)
			rendezvous = other
			break
	if(rendezvous)
		S.overmap_complete_flight()
		return

	// Stacked tile but no explicit target chosen — park alongside, helm must press Dock.
	S.overmap_park()


// ---------------------------------------------------------------------------
// Active deep scan. Reveals fog and rolls hazard detection in a wider sweep
// than the per-tick run_detection_for. Called from the planet scanner's active
// scan completion flow. See OVERMAP_DESIGN.md "Active deep scan".
// ---------------------------------------------------------------------------

/datum/subsystem/overmap/proc/deep_scan(datum/shuttle/S, radius)
	if(!S || radius <= 0)
		return
	for(var/dx = -radius to radius)
		for(var/dy = -radius to radius)
			var/tx = S.x + dx
			var/ty = S.y + dy
			if(!is_in_bounds(tx, ty))
				continue
			if(chessboard_dist(dx, dy) > radius)
				continue
			S.reveal_tile(tx, ty)
			for(var/datum/overmap_hazard/H in get_hazards_at(tx, ty))
				if(!S.knows_hazard(H))
					S.learn_hazard(H)
			for(var/datum/overmap_body/B in get_bodies_at(tx, ty))
				if(B.hidden)
					continue
				if(!S.knows_body(B))
					S.learn_body(B)
	notify_knowledge_changed(S)


// Allocate a new encounter body on a free tile within range of the given
// shuttle and add it to the grid. The body's vlevel is allocated lazily — for
// Phase 5 we allocate via SSmapping.generate_scanner_encounter when the helm
// actually arrives at the body. Returns the body, or null if no free tile.
/datum/subsystem/overmap/proc/spawn_encounter_near(datum/shuttle/near, min_dist = 2, max_dist = 8)
	if(!near)
		return null
	for(var/attempt = 1 to 30)
		var/tx = rand(max(1, near.x - max_dist), min(OVERMAP_WIDTH, near.x + max_dist))
		var/ty = rand(max(1, near.y - max_dist), min(OVERMAP_HEIGHT, near.y + max_dist))
		if(chessboard_dist(near.x - tx, near.y - ty) < min_dist)
			continue
		if(!find_free_tile_at(tx, ty, require_no_body = TRUE))
			continue
		var/datum/overmap_body/encounter/E = new(tx, ty)
		add_body(E)
		return E
	return null


// ---------------------------------------------------------------------------
// UI subscriber notifications. Each UI subscribes via register_ui; SSovermap
// dispatches per-shuttle events to UIs whose linked_shuttle matches.
// ---------------------------------------------------------------------------

/datum/subsystem/overmap/proc/notify_ship_moved(datum/shuttle/S)
	for(var/datum/mind_ui/overmap_base/ui in listening_uis)
		if(ui.linked_shuttle == S)
			ui.on_ship_moved()

/datum/subsystem/overmap/proc/notify_knowledge_changed(datum/shuttle/S)
	for(var/datum/mind_ui/overmap_base/ui in listening_uis)
		if(ui.linked_shuttle == S)
			ui.on_knowledge_changed()

/datum/subsystem/overmap/proc/register_ui(datum/mind_ui/overmap_base/ui)
	listening_uis |= ui

/datum/subsystem/overmap/proc/unregister_ui(datum/mind_ui/overmap_base/ui)
	listening_uis -= ui


// ---------------------------------------------------------------------------
// Roundstart route validation (Phase 1: warns about catalog mistakes)
// ---------------------------------------------------------------------------

/datum/subsystem/overmap/proc/validate_route(datum/shuttle_route/R, datum/shuttle/S)
	if(!R)
		return
	for(var/list/wp in R.waypoints)
		if(wp.len < 2 || !is_in_bounds(wp[1], wp[2]))
			warning("Overmap: shuttle route [R.name] on [S?.name] has invalid waypoint [json_encode(wp)]")
	if(R.origin && !(R.origin in bodies))
		warning("Overmap: shuttle route [R.name] origin body not on grid")
	if(R.destination && !(R.destination in bodies))
		warning("Overmap: shuttle route [R.name] destination body not on grid")
