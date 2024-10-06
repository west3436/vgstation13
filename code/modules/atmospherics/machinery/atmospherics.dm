/*
Quick overview:

Pipes combine to form pipelines
Pipelines and other atmospheric objects combine to form pipe_networks
	Note: A single pipe_network represents a completely open space

Pipes -> Pipelines
Pipelines + Other Objects -> Pipe network

*/

#define PIPE_TYPE_STANDARD 0
#define PIPE_TYPE_HE       1

//Pipe bitflags
#define IS_MIRROR	1
#define ALL_LAYER	2 //if the pipe can connect at any layer, instead of just the specific one

/obj/machinery/atmospherics
	anchored = TRUE
	plane = ABOVE_TURF_PLANE
	layer = PIPE_LAYER
	idle_power_usage = 0
	active_power_usage = 0
	power_channel = ENVIRON

	var/piping_layer = PIPING_LAYER_DEFAULT //used in multi-pipe-on-tile - pipes only connect if they're on the same pipe layer

	/// Can this be unwrenched?
	var/can_unwrench = FALSE
	/// Can this be put under a tile?
	var/can_be_undertile = FALSE
	/// If the machine is currently operating or not.
	var/on = FALSE
	/// The amount of pressure the machine wants to operate at.
	var/target_pressure = 0


	// Vars below this point are all pipe related
	// I know not all subtypes are pipes, but this helps

	/// Type of pipes this machine can connect to
	var/list/connect_types = list(CONNECT_TYPE_NORMAL)
	/// What this machine is connected to
	var/connected_to = CONNECT_TYPE_NORMAL
	/// Icon suffix for connection, can be "-supply" or "-scrubbers"
	var/icon_connect_type = ""
	/// Directions to initialize in to grab pipes
	var/initialize_directions = 0
	/// Pipe colour, not used for all subtypes
	var/pipe_color
	/// Pipe image, not used for all subtypes
	var/image/pipe_image

	var/can_be_coloured = 1 //set to 0 to blacklist your atmos thing from being colored
	var/image/centre_overlay = null
	// Investigation logs
	var/log

	/// ID for automatic linkage of stuff. This is used to assist in connections at mapload. Dont try use it for other stuff
	var/autolink_id = null

	/// Whether or not this can be unwrenched while on.
	var/can_unwrench_while_on = TRUE

	internal_gravity = 1 // Ventcrawlers can move in pipes without gravity since they have traction.


/obj/machinery/atmospherics/Initialize(mapload)
	. = ..()
	SSair.atmos_machinery += src


	if(!pipe_color)
		pipe_color = color

	color = null


/obj/machinery/atmospherics/New()
	..()
	machines.Remove(src)
	SSair.atmos_machinery |= src
	SSair.pipenets_to_build |= src
	update_planes_and_layers()

/obj/machinery/atmospherics/supports_holomap()
	return TRUE

/obj/machinery/atmospherics/proc/update_planes_and_layers()
	return

/obj/machinery/atmospherics/proc/icon_node_con(var/dir)
	var/static/list/node_con = list(
		"[NORTH]" = image('icons/obj/pipes.dmi', "pipe_intact", dir = NORTH),
		"[SOUTH]" = image('icons/obj/pipes.dmi', "pipe_intact", dir = SOUTH),
		"[EAST]"  = image('icons/obj/pipes.dmi', "pipe_intact", dir = EAST),
		"[WEST]"  = image('icons/obj/pipes.dmi', "pipe_intact", dir = WEST)
	)

	return node_con["[dir]"]

/obj/machinery/atmospherics/proc/icon_node_ex(var/dir)
	var/static/list/node_ex = list(
		"[NORTH]" = image('icons/obj/pipes.dmi', "pipe_exposed", dir = NORTH),
		"[SOUTH]" = image('icons/obj/pipes.dmi', "pipe_exposed", dir = SOUTH),
		"[EAST]"  = image('icons/obj/pipes.dmi', "pipe_exposed", dir = EAST),
		"[WEST]"  = image('icons/obj/pipes.dmi', "pipe_exposed", dir = WEST)
	)

	return node_ex["[dir]"]

/obj/machinery/atmospherics/proc/icon_directions()
	. = list()
	for(var/direction in cardinal)
		if(direction & initialize_directions)
			. += direction

/obj/machinery/atmospherics/proc/node_color_for(var/obj/machinery/atmospherics/other)
	if (default_colour && other.default_colour && (other.default_colour != default_colour)) // if both pipes have special colours - average them
		var/list/centre_colour = GetHexColors(default_colour)
		var/list/other_colour = GetHexColors(other.default_colour)
		var/list/average_colour = list(((centre_colour[1]+other_colour[1])/2),((centre_colour[2]+other_colour[2])/2),((centre_colour[3]+other_colour[3])/2))
		return rgb(average_colour[1],average_colour[2],average_colour[3])
	if (color)
		return null
	if (other.color)
		return other.color

	if (default_colour)
		return default_colour

	if (other.default_colour && other.default_colour != PIPE_COLOR_GREY)
		return other.default_colour

	return PIPE_COLOR_GREY

/obj/machinery/atmospherics/proc/node_layer()
	var/new_layer = level == LEVEL_BELOW_FLOOR ? PIPE_LAYER : EXPOSED_PIPE_LAYER
	return PIPING_LAYER(new_layer, piping_layer)

/obj/machinery/atmospherics/proc/node_plane()
	return relative_plane(level == LEVEL_BELOW_FLOOR ? ABOVE_PLATING_PLANE : ABOVE_TURF_PLANE)

/obj/machinery/atmospherics/proc/process_atmos() //If you dont use process why are you here
	// Any proc that wants MILLA to be synchronous should not sleep.
	SHOULD_NOT_SLEEP(TRUE)
	return PROCESS_KILL

/obj/machinery/atmospherics/proc/atmos_init()
	// Updates all pipe overlays and underlays
	update_underlays()

/obj/machinery/atmospherics/Destroy()
	SSair.atmos_machinery -= src
	SSair.pipenets_to_build -= src
	for(var/mob/living/L in src) //ventcrawling is serious business
		L.remove_ventcrawl()
		L.forceMove(get_turf(src))
	if(pipe_image)
		for(var/mob/living/M in player_list)
			if(M.client)
				M.client.images -= pipe_image
				M.pipes_shown -= pipe_image
		pipe_image = null
	centre_overlay = null
	return ..()

// Icons/overlays/underlays
/obj/machinery/atmospherics/update_icon(var/adjacent_procd,node_list)
	update_planes_and_layers()
	if(!can_be_coloured && color)
		default_colour = color
		color = null
	else if(can_be_coloured && default_colour)
		color = default_colour
		default_colour = null
	alpha = invisibility ? 128 : 255
	if (!update_icon_ready)
		update_icon_ready = 1
	else
		underlays.Cut()
	if(!anchored)
		return //the rest isn't needed for unanchored things
	var/list/missing_nodes = icon_directions()
	for (var/obj/machinery/atmospherics/connected_node in node_list)
		var/con_dir = get_dir(src, connected_node)
		missing_nodes -= con_dir // finds all the directions that aren't pointed to by a node
		var/image/nodecon = icon_node_con(con_dir)
		if(nodecon)
			nodecon.color = node_color_for(connected_node)
			nodecon.plane = node_plane()
			nodecon.layer = node_layer()
			underlays += nodecon
		if (!adjacent_procd && connected_node.update_icon_ready && !(istype(connected_node,/obj/machinery/atmospherics/pipe/simple)))
			connected_node.update_icon(1)
	for (var/missing_dir in missing_nodes)
		var/image/nodeex = icon_node_ex(missing_dir)
		if(!color)
			nodeex.color = default_colour ? default_colour : PIPE_COLOR_GREY
		else
			nodeex.color = null
		nodeex.plane = node_plane()
		nodeex.layer = node_layer()
		switch (missing_dir)
			if (NORTH)
				nodeex.pixel_y = ex_node_offset

			if (SOUTH)
				nodeex.pixel_y = -ex_node_offset

			if (EAST)
				nodeex.pixel_x = ex_node_offset

			if (WEST)
				nodeex.pixel_x = -ex_node_offset

		underlays += nodeex

/obj/machinery/atmospherics/proc/setPipingLayer(new_layer = PIPING_LAYER_DEFAULT)
	piping_layer = new_layer
	pixel_x = (piping_layer - PIPING_LAYER_DEFAULT) * PIPING_LAYER_P_X
	pixel_y = (piping_layer - PIPING_LAYER_DEFAULT) * PIPING_LAYER_P_Y
	update_planes_and_layers()

// Connect types
/obj/machinery/atmospherics/proc/check_connect_types(obj/machinery/atmospherics/atmos1, obj/machinery/atmospherics/atmos2)
	var/list/list1 = atmos1.connect_types
	var/list/list2 = atmos2.connect_types
	for(var/i in 1 to length(list1))
		for(var/j in 1 to length(list2))
			if(list1[i] == list2[j])
				var/n = list1[i]
				return n
	return 0

/obj/machinery/atmospherics/proc/check_connect_types_construction(obj/machinery/atmospherics/atmos1, obj/item/pipe/pipe2)
	var/list/list1 = atmos1.connect_types
	var/list/list2 = pipe2.connect_types
	for(var/i in 1 to length(list1))
		for(var/j in 1 to length(list2))
			if(list1[i] == list2[j])
				var/n = list1[i]
				return n
	return 0

// Pipenet related functions
/obj/machinery/atmospherics/proc/returnPipenet()
	return

/**
 * Whether or not this atmos machine has multiple pipenets attached to it
 * Used to determine if a ventcrawler should update their vision or not
 */
/obj/machinery/atmospherics/proc/is_pipenet_split()
	return FALSE

/obj/machinery/atmospherics/proc/returnPipenetAir()
	return

/obj/machinery/atmospherics/proc/setPipenet()
	return

/obj/machinery/atmospherics/proc/replacePipenet()
	return

/obj/machinery/atmospherics/proc/build_network(remove_deferral = FALSE)
	// Called to build a network from this node
	if(remove_deferral)
		SSair.pipenets_to_build -= src

/obj/machinery/atmospherics/proc/defer_build_network()
	SSair.pipenets_to_build += src

/obj/machinery/atmospherics/proc/disconnect(obj/machinery/atmospherics/reference)
	return

/obj/machinery/atmospherics/proc/nullifyPipenet(datum/pipeline/P)
	if(P)
		P.other_atmosmch -= src

/obj/machinery/atmospherics/ex_act(severity)
	for(var/atom/movable/A in src) //ventcrawling is serious business
		A.ex_act(severity)
	..()

/obj/machinery/atmospherics/wrench_act(mob/living/user, obj/item/wrench/W)
	var/turf/T = get_turf(src)
	if(!can_unwrench_while_on && !(stat & NOPOWER) && on)
		to_chat(user, "<span class='alert'>You cannot unwrench this [name], turn it off first.</span>")
		return TRUE
	if(!can_unwrench)
		return FALSE
	. = TRUE
	if(level == 1 && T.transparent_floor && istype(src, /obj/machinery/atmospherics/pipe))
		to_chat(user, "<span class='danger'>You can't interact with something that's under the floor!</span>")
		return
	if(level == 1 && isturf(T) && T.intact)
		to_chat(user, "<span class='danger'>You must remove the plating first.</span>")
		return
	var/datum/gas_mixture/int_air = return_obj_air()
	var/datum/gas_mixture/env_air = T.get_readonly_air()
	add_fingerprint(user)


	var/unsafe_wrenching = FALSE
	var/safefromgusts = FALSE
	var/I = int_air ? int_air.return_pressure() : 0
	var/E = env_air ? env_air.return_pressure() : 0
	var/internal_pressure = I - E

	to_chat(user, "<span class='notice'>You begin to unfasten [src]...</span>")

	if(HAS_TRAIT(user, TRAIT_MAGPULSE))
		safefromgusts = TRUE

	if(internal_pressure > 2 * ONE_ATMOSPHERE)
		unsafe_wrenching = TRUE //Oh dear oh dear
		if(internal_pressure > 1750 && !safefromgusts) // 1750 is the pressure limit to do 60 damage when thrown
			to_chat(user, "<span class='userdanger'>As you struggle to unwrench [src] a huge gust of gas blows in your face! This seems like a terrible idea!</span>")
		else
			to_chat(user, "<span class='warning'>As you begin unwrenching [src] a gust of air blows in your face... maybe you should reconsider?</span>")

	if(!W.use_tool(src, user, 4 SECONDS, volume = 50) || QDELETED(src))
		return

	safefromgusts = FALSE

	if(HAS_TRAIT(user, TRAIT_MAGPULSE))
		safefromgusts = TRUE

	user.visible_message(
		"<span class='notice'>[user] unfastens [src].</span>",
		"<span class='notice'>You have unfastened [src].</span>",
		"<span class='italics'>You hear ratcheting.</span>"
	)

	//You unwrenched a pipe full of pressure? let's splat you into the wall silly.
	if(unsafe_wrenching)
		if(safefromgusts)
			to_chat(user, "<span class='notice'>Your magboots cling to the floor as a great burst of wind bellows against you.</span>")
		else
			unsafe_pressure_release(user,internal_pressure)
	deconstruct(TRUE)

//(De)construction
/obj/machinery/atmospherics/attackby(obj/item/W, mob/user)
	var/turf/T = get_turf(src)
	if(T.transparent_floor)
		to_chat(user, "<span class='danger'>You can't interact with something that's under the floor!</span>")
		return TRUE
	return ..()

//Called when an atmospherics object is unwrenched while having a large pressure difference
//with it's locs air contents.
/obj/machinery/atmospherics/proc/unsafe_pressure_release(mob/user, pressures)
	if(!user)
		return

	if(!pressures)
		var/datum/gas_mixture/int_air = return_obj_air()
		var/turf/T = get_turf(src)
		var/datum/gas_mixture/env_air = T.get_readonly_air()
		pressures = int_air.return_pressure() - env_air.return_pressure()

	var/fuck_you_dir = get_dir(src, user)
	if(!fuck_you_dir)
		fuck_you_dir = pick(GLOB.alldirs)

	var/turf/general_direction = get_edge_target_turf(user, fuck_you_dir)
	user.visible_message("<span class='danger'>[user] is sent flying by pressure!</span>","<span class='userdanger'>The pressure sends you flying!</span>")
	//Values based on 2*ONE_ATMOS (the unsafe pressure), resulting in 20 range and 4 speed
	user.throw_at(general_direction, pressures/10, pressures/50)

/obj/machinery/atmospherics/deconstruct(disassembled = TRUE)
	if(!(flags & NODECONSTRUCT))
		if(can_unwrench)
			var/obj/item/pipe/stored = new(loc, null, null, src)
			if(!disassembled)
				stored.obj_integrity = stored.max_integrity * 0.5
			transfer_fingerprints_to(stored)
	..()

/obj/machinery/atmospherics/on_construction(D, P, C)
	if(C)
		color = C
	dir = D
	initialize_directions = P
	var/turf/T = loc
	if(!T.transparent_floor)
		level = (T.intact || !can_be_undertile) ? 2 : 1
	else
		level = 2
	update_icon_state()
	add_fingerprint(usr)
	if(!SSair.initialized) //If there's no atmos subsystem, we can't really initialize pipenets
		SSair.machinery_to_construct.Add(src)
		return
	initialize_atmos_network()

/obj/machinery/atmospherics/proc/initialize_atmos_network()
	atmos_init()
	var/list/nodes = pipeline_expansion()
	for(var/obj/machinery/atmospherics/A in nodes)
		A.atmos_init()
		A.addMember(src)
	build_network()

// Find a connecting /obj/machinery/atmospherics in specified direction.
/obj/machinery/atmospherics/proc/findConnecting(direction)
	for(var/obj/machinery/atmospherics/target in get_step(src,direction))
		var/can_connect = check_connect_types(target, src)
		if(can_connect && (target.initialize_directions & get_dir(target,src)))
			return target

// Ventcrawling
#define VENT_SOUND_DELAY 30
/obj/machinery/atmospherics/relaymove(mob/living/user, direction)
	direction &= initialize_directions
	if(!direction || !(direction in GLOB.cardinal)) //cant go this way.
		return

	if(user in buckled_mobs)// fixes buckle ventcrawl edgecase fuck bug
		return

	var/obj/machinery/atmospherics/target_move = findConnecting(direction)
	if(target_move)
		if(is_type_in_list(target_move, GLOB.ventcrawl_machinery) && target_move.can_crawl_through())
			user.remove_ventcrawl()
			user.forceMove(target_move.loc) //handles entering and so on
			user.visible_message("You hear something squeezing through the ducts.", "You climb out of the ventilation system.")
		else if(target_move.can_crawl_through())
			if(is_pipenet_split()) // Going away from a split means we want to update the view of the pipenet
				user.update_pipe_vision(target_move)
			user.forceMove(target_move)
			if(world.time - user.last_played_vent > VENT_SOUND_DELAY)
				user.last_played_vent = world.time
				playsound(src, 'sound/machines/ventcrawl.ogg', 50, TRUE, -3)
	else
		if((direction & initialize_directions) || is_type_in_list(src, GLOB.ventcrawl_machinery)) //if we move in a way the pipe can connect, but doesn't - or we're in a vent
			user.remove_ventcrawl()
			user.forceMove(loc)
			user.visible_message("You hear something squeezing through the pipes.", "You climb out of the ventilation system.")
	ADD_TRAIT(user, TRAIT_IMMOBILIZED, "ventcrawling")
	spawn(1) // this is awful
		REMOVE_TRAIT(user, TRAIT_IMMOBILIZED, "ventcrawling")

/obj/machinery/atmospherics/AltClick(mob/living/L)
	if(is_type_in_list(src, GLOB.ventcrawl_machinery))
		L.handle_ventcrawl(src)
		return
	..()

/obj/machinery/atmospherics/proc/can_crawl_through()
	return TRUE

/obj/machinery/atmospherics/extinguish_light(force)
	set_light(0)
	update_icon(UPDATE_OVERLAYS)

/obj/machinery/atmospherics/proc/change_color(new_color)
	//only pass valid pipe colors please ~otherwise your pipe will turn invisible
	if(!pipe_color_check(new_color))
		return

	pipe_color = new_color
	update_icon()

// Additional icon procs
/obj/machinery/atmospherics/proc/universal_underlays(obj/machinery/atmospherics/node, direction)
	var/turf/T = get_turf(src)
	if(!istype(T)) return
	if(node)
		var/node_dir = get_dir(src,node)
		if(node.icon_connect_type == "-supply")
			add_underlay_adapter(T, null, node_dir, "")
			add_underlay_adapter(T, node, node_dir, "-supply")
			add_underlay_adapter(T, null, node_dir, "-scrubbers")
		else if(node.icon_connect_type == "-scrubbers")
			add_underlay_adapter(T, null, node_dir, "")
			add_underlay_adapter(T, null, node_dir, "-supply")
			add_underlay_adapter(T, node, node_dir, "-scrubbers")
		else
			add_underlay_adapter(T, node, node_dir, "")
			add_underlay_adapter(T, null, node_dir, "-supply")
			add_underlay_adapter(T, null, node_dir, "-scrubbers")
	else
		add_underlay_adapter(T, null, direction, "-supply")
		add_underlay_adapter(T, null, direction, "-scrubbers")
		add_underlay_adapter(T, null, direction, "")

/obj/machinery/atmospherics/proc/add_underlay_adapter(turf/T, obj/machinery/atmospherics/node, direction, icon_connect_type) //modified from add_underlay, does not make exposed underlays
	if(node)
		if(T.intact && node.level == 1 && istype(node, /obj/machinery/atmospherics/pipe) && !T.transparent_floor)
			underlays += GLOB.pipe_icon_manager.get_atmos_icon("underlay", direction, color_cache_name(node), "down" + icon_connect_type)
		else
			underlays += GLOB.pipe_icon_manager.get_atmos_icon("underlay", direction, color_cache_name(node), "intact" + icon_connect_type)
	else
		if(T.transparent_floor) //we want to keep pipes under transparent floors connected normally
			underlays += GLOB.pipe_icon_manager.get_atmos_icon("underlay", direction, color_cache_name(node), "intact" + icon_connect_type)
		else
			underlays += GLOB.pipe_icon_manager.get_atmos_icon("underlay", direction, color_cache_name(node), "retracted" + icon_connect_type)

/obj/machinery/atmospherics/singularity_pull(S, current_size)
	if(current_size >= STAGE_FIVE)
		deconstruct(FALSE)
	return ..()

/obj/machinery/atmospherics/update_remote_sight(mob/user)
	user.sight |= (SEE_TURFS|BLIND)
	. = ..()

//Used for certain children of obj/machinery/atmospherics to not show pipe vision when mob is inside it.
/obj/machinery/atmospherics/proc/can_see_pipes()
	return TRUE

/**
 * Turns the machine either on, or off. If this is done by a user, display a message to them.
 *
 * NOTE: Only applies to atmospherics machines which can be toggled on or off, such as pumps, or other devices.
 *
 * Arguments:
 * * user - the mob who is toggling the machine.
 */
/obj/machinery/atmospherics/proc/toggle(mob/living/user)
	if(!has_power())
		return
	on = !on
	update_icon()
	if(user)
		to_chat(user, "<span class='notice'>You toggle [src] [on ? "on" : "off"].</span>")

/**
 * Maxes the output pressure of the machine. If this is done by a user, display a message to them.
 *
 * NOTE: Only applies to atmospherics machines which allow a `target_pressure` to be set, such as pumps, or other devices.
 *
 * Arguments:
 * * user - the mob who is setting the output pressure to maximum.
 */
/obj/machinery/atmospherics/proc/set_max(mob/living/user)
	if(!has_power())
		return
	target_pressure = MAX_OUTPUT_PRESSURE
	update_icon()
	if(user)
		to_chat(user, "<span class='notice'>You set the target pressure of [src] to maximum.</span>")

#undef VENT_SOUND_DELAY
