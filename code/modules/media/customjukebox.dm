//Ported from PsychonautStation with permission granted on 1/23/2024 with modifications made to fit our codebase.
//All credit and thanks to coder Seefaaa!

#define SHELLEO_ERRORLEVEL 1
#define SHELLEO_STDOUT 2
#define SHELLEO_STDERR 3

#define ERR_YTDL_NOT_CONFIGURED "Youtube-dl was not configured, action unavailable"
#define ERR_NOT_HTTPS "The media provider returned a content URL that isn't using the HTTP or HTTPS protocol. This is a security risk and the sound will not be played."
#define ERR_JSON_RETRIEVAL "Youtube-dl URL retrieval failed"
#define ERR_JSON_PARSING "Youtube-dl JSON parsing failed"
#define ERR_DURATION "Duration too long"

#define STOP(src) "(<a href='?src=[src];cancel=1'>STOP</a>)"
#define REMOVEQUEUE(src, track) "(<a href='?src=[src];removequeue=[track]'>REMOVE</a>)"
#define DENYREQUEST(src, track) "(<a href='?src=[src];deny=[track]'>DENY</a>)"
#define BANJUKEBOX(src, client) "(<a href='?src=[src];ban=[client]'>JUKEBOX BAN</a>)"
#define UNBANJUKEBOX(src, client) "(<a href='?src=[src];unban=[client]'>UNBAN</a>)"

#define CACHE_DURATION 5 MINUTES
#define MAX_SOUND_DURATION 10 MINUTES
#define REQUEST_COOLDOWN 20 SECONDS

#define YTDL_REGEX @"^(https?:\/\/)?(www\.)?(youtube\.com\/|youtu\.be\/)[\w\-\/?=&%]*$"

var/list/jukebox_bad_input = list()
var/list/jukebox_cache = list()
var/list/client/jukebox_ban = list()

/datum/web_track
	var/id = ""
	var/url = ""
	var/title = ""
	var/duration = 0
	var/display_duration = ""
	var/webpage_url = ""
	var/webpage_url_html = ""
	var/artist = ""
	var/album = ""
	var/timestamp = 0
	var/mob_name = ""
	var/mob_ckey = ""
	var/mob_key_name = ""
	var/list/as_list = list()

/datum/web_track/New(url, title, webpage_url, duration, artist, album, mob_name, mob_ckey, mob_key_name)
	src.url = url
	src.title = title
	src.duration = duration
	src.display_duration = DisplayTimeText(duration, 1)
	src.webpage_url = webpage_url
	src.webpage_url_html = webpage_url ? "<a href=\"[webpage_url]\">[title]</a>" : title
	src.artist = artist
	src.album = album
	timestamp = world.time
	src.mob_name = mob_name
	src.mob_ckey = mob_ckey
	src.mob_key_name = mob_key_name
	id = src
	as_list = parse_as_list()

/datum/web_track/proc/parse_as_list()
	var/list/track_as_list = list()
	track_as_list["title"] = title
	track_as_list["duration"] = display_duration
	track_as_list["link"] = webpage_url
	track_as_list["webpage_url"] = webpage_url
	track_as_list["webpage_url_html"] = webpage_url_html
	track_as_list["artist"] = artist
	track_as_list["album"] = album
	track_as_list["mob_name"] = mob_name
	track_as_list["mob_ckey"] = mob_ckey
	track_as_list["mob_key_name"] = mob_key_name
	track_as_list["id"] = id
	return track_as_list

/datum/web_track/Destroy(force, ...)
	qdel(as_list)
	return ..()

/obj/machinery/custom_jukebox
	name = "custom jukebox"
	desc = "An advanced music player which supports web music."
	icon = 'icons/obj/jukebox.dmi'
	icon_state = "jukebox2"
	density = TRUE

	var/id
	var/owner
	var/ytdl
	var/range = 16
	var/busy = FALSE
	var/loop = FALSE
	var/track_started_at = 0
	var/request_cooldown = 0
	var/list/queue = list()
	var/list/requests = list()
	var/list/listeners_in_range = list()
	// var/list/clients_in_range = list()
	var/datum/web_track/current_track
	var/datum/proximity_monitor/advanced/player_collector/proximity_monitor
	var/static/regex/ytdl_regex = regex(YTDL_REGEX, "s")

/obj/machinery/custom_jukebox/Topic(href, href_list)
	if(!isAdminGhost(usr))
		return
	var/admin_key_name = key_name(usr)
	if(href_list["cancel"])
		if(!current_track)
			to_chat(usr, span_admin("[src] is not playing"))
			return
		stop_music()
		var/area_name = get_area_name(src)
		message_admins("[admin_key_name] stopped [src] at [area_name].")
		log_admin_private("[admin_key_name] stopped [src] at [area_name].")
	if(href_list["removequeue"])
		var/datum/web_track/track = locate(href_list["removequeue"])
		var/mob_key_name = key_name(track.mob_key_name, TRUE)
		if(!queue.Find(track))
			if(current_track == track)
				skip_music()
				message_admins("[admin_key_name] removed track [track.webpage_url_html] added by [mob_key_name] while playing.")
				log_admin_private("[admin_key_name] removed track [track.webpage_url_html] added by [mob_key_name] while playing.")
			else
				to_chat(usr, span_admin("The track has already removed"))
		else
			queue -= track
			message_admins("[admin_key_name] removed track [track.webpage_url_html] from queue added by [mob_key_name].")
			log_admin_private("[admin_key_name] removed track [track.webpage_url_html] from queue added by [mob_key_name].")
			qdel(track)
	if(href_list["deny"])
		var/datum/web_track/track = locate(href_list["deny"])
		var/mob_key_name = key_name(track.mob_key_name, TRUE)
		if(!requests.Find(track))
			to_chat(usr, span_admin("The request has already approved/denied/discarded"))
			return
		requests -= track
		message_admins("[admin_key_name] denied [mob_key_name]'s web sound request [track.webpage_url_html].")
		log_admin_private("[admin_key_name] denied [mob_key_name]'s web sound request [track.webpage_url_html].")
		qdel(track)
	if(href_list["ban"])
		var/client/client = locate(href_list["ban"])
		var/client_key_name = key_name(client, TRUE)
		if(jukebox_ban.Find(client))
			to_chat(usr, span_admin("[client_key_name] has already banned from using jukebox."))
		else
			jukebox_ban += client
			message_admins("[admin_key_name] banned [client_key_name] from using jukebox. [UNBANJUKEBOX(src, client)]")
			log_admin_private("[admin_key_name] banned [client_key_name] from using jukebox.")
	if(href_list["unban"])
		var/client/client = locate(href_list["ban"])
		var/client_key_name = key_name(client, TRUE)
		if(jukebox_ban.Find(client))
			jukebox_ban -= client
			message_admins("[admin_key_name] unbanned [client_key_name] from using jukebox. [BANJUKEBOX(src, client)]")
			log_admin_private("[admin_key_name] unbanned [client_key_name] from using jukebox.")
		else
			to_chat(usr, span_admin("[client_key_name] has already unbanned from using jukebox."))

/obj/machinery/custom_jukebox/process()
	if(current_track && world.time - track_started_at > current_track.duration)
		skip_music()

/obj/machinery/custom_jukebox/update_icon()
	icon_state = "[initial(icon_state)][is_playing() ? "-active" : null]"
	return ..()

/obj/machinery/custom_jukebox/attackby(obj/item/I, mob/user)
	if(iswrench(I))
		if(busy || is_playing())
			to_chat(user, "<span class='warning'>You cannot unsecure [src] while it's on!</span>")
			return 0
	..()

/obj/machinery/custom_jukebox/ui_status(mob/user)
	if(!ytdl)
		to_chat(user, "<span class='warning'>Youtube-dl was not configured, action unavailable</span>")
		user.playsound_local(src, 'sound/weapons/heavysmash.ogg', 25, TRUE) //DEBUG - replace this
		return 0
	return ..()

/obj/machinery/custom_jukebox/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ElectricalJukebox", name)
		ui.open()

/obj/machinery/custom_jukebox/ui_data(mob/user)
	var/list/data = list()
	if(current_track)
		var/elapsed = world.time - track_started_at
		data["current_track"] = current_track.as_list
		data["elapsed"] = DisplayTimeText(elapsed <= (current_track.duration) ? elapsed : (current_track.duration), 1)
	else
		data["current_track"] = null
		data["elapsed"] = null
	data["active"] = is_playing()
	data["busy"] = busy
	data["loop"] = loop
	data["can_mob_use"] = can_mob_use(user)
	data["banned"] = GLOB.jukebox_ban.Find(user.client) ? TRUE : FALSE
	data["user_key_name"] = key_name(user)
	data["queue"] = list()
	for(var/datum/web_track/track in queue)
		data["queue"] += list(track.as_list)
	data["requests"] = list()
	for(var/datum/web_track/track in requests)
		data["requests"] += list(track.as_list)
	return data

/obj/machinery/custom_jukebox/ui_act(action, list/params)
	. = ..()

	if(. || busy || !usr.can_perform_action(src, FORBID_TELEKINESIS_REACH))
		return

	if(GLOB.jukebox_ban.Find(usr.client))
		to_chat(usr, span_warning("You are banned from using [src]."), confidential = TRUE)
		return

	if(action != "new_request" && action != "discard_request" && !can_mob_use(usr))
		to_chat(usr, span_warning("You are not allowed to use [src]."), confidential = TRUE)
		return

	switch(action)
		if("toggle")
			if(is_playing())
				stop_music()
			else
				if(!anchored)
					to_chat(usr, span_warning("\The [src] needs to be secured first!"), confidential = TRUE)
					balloon_alert(usr, "secure first!")
					return
				if(queue.len > 0)
					var/datum/web_track/track = queue[1]
					queue -= track
					play_music_by_track(track)
				else
					var/input = tgui_input_music("Play")
					if(input)
						play_music_by_input(usr, input)
			return
		if("skip")
			skip_music(manually = TRUE)
			return
		if("loop")
			loop = !loop
			return
		if("add_queue")
			var/input = tgui_input_music("Add to Queue")
			if(input)
				add_queue(usr, input)
			return
		if("clear_queue")
			for(var/track in queue)
				queue -= track
				qdel(track)
		if("remove_queue")
			var/datum/web_track/track = locate(params["id"])
			if(track && queue.Find(track))
				queue -= track
				qdel(track)
			return
		if("new_request")
			var/time_elapsed = request_cooldown != 0 ? world.time - request_cooldown : REQUEST_COOLDOWN
			if(time_elapsed >= REQUEST_COOLDOWN)
				var/input = tgui_input_music("New Request")
				if(input)
					new_request(usr, input)
			else
				var/display_time = DisplayTimeText(REQUEST_COOLDOWN - time_elapsed)
				say("You cannot request a new music for [display_time].")
				balloon_alert(usr, "[display_time]!")
			return
		if("approve_request")
			var/datum/web_track/track = locate(params["id"])
			if(track && requests.Find(track))
				requests -= track
				queue += track
				message_admins("[key_name(usr, TRUE, TRUE)] [usr.job] approved [key_name(track.mob_key_name, TRUE, TRUE)]'s web sound request [track.webpage_url_html] [REMOVEQUEUE(src, track)].")
			else
				to_chat(usr, span_warning("The request has already approved/denied/discarded."), confidential = TRUE)
			return
		if("discard_request")
			var/datum/web_track/track = locate(params["id"])
			if(track && requests.Find(track))
				requests -= track
				qdel(track)
			else
				to_chat(usr, span_warning("The request has already approved/denied/discarded."), confidential = TRUE)
			return

/obj/machinery/custom_jukebox/proc/add_queue(mob/user, input)
	if(busy)
		return

	var/cache = GLOB.jukebox_bad_input[input]
	if(cache)
		track_unavailable(user, cache)
		return

	var/datum/web_track/track = get_web_sound(input, user.name, user.ckey, key_name(user))

	if(!istype(track))
		track_unavailable(user, track)
		return

	queue += track

	var/area_name = get_area_name(src, TRUE)

	log_admin("[key_name(user)] added web sound [track.webpage_url_html] to queue on [src] at [area_name]")
	message_admins("[key_name(user, TRUE)] added web sound [track.title] to queue on [src] at [area_name]. [ADMIN_FULLMONTY_NONAME(user)] [ADMIN_JMP(src)] [REMOVEQUEUE(src, track)] [BANJUKEBOX(src, user.client)]")

/obj/machinery/custom_jukebox/proc/new_request(mob/user, input)
	if(busy)
		return

	var/cache = GLOB.jukebox_bad_input[input]
	if(cache)
		track_unavailable(user, cache)
		return

	var/datum/web_track/track = get_web_sound(input, user.name, user.ckey, key_name(user))
	request_cooldown = world.time

	if(!istype(track))
		track_unavailable(user, track)
		return

	requests += track

	var/area_name = get_area_name(src, TRUE)

	log_admin("[key_name(user)] requested a web sound [track.webpage_url_html] on [src] at [area_name]")
	message_admins("[key_name(user, TRUE)] requested a web sound [track.webpage_url_html] on [src] at [area_name]. [ADMIN_FULLMONTY_NONAME(user)] [ADMIN_JMP(src)] [DENYREQUEST(src, track)] [BANJUKEBOX(src, user.client)]")

	return

/obj/machinery/custom_jukebox/proc/get_web_sound_(input, mob_name, mob_ckey, mob_key_name)
	if(!ytdl)
		return ERR_YTDL_NOT_CONFIGURED

	var/list/data
	var/cached = GLOB.jukebox_cache[input]

	if(cached && world.time - cached["timestamp"] < CACHE_DURATION)
		data = cached
	else
		var/shell_scrubbed_input = shell_url_scrub(input)
		var/list/output = world.shelleo("[ytdl] --geo-bypass --format \"bestaudio\[ext=mp3]/best\[ext=mp4]\[height <= 360]/bestaudio\[ext=m4a]/bestaudio\[ext=aac]\" --dump-single-json --no-playlist -- \"[shell_scrubbed_input]\"")

		var/errorlevel = output[SHELLEO_ERRORLEVEL]
		var/stdout = output[SHELLEO_STDOUT]

		if(errorlevel)
			return ERR_JSON_RETRIEVAL
		try
			data = json_decode(stdout)
		catch
			return ERR_JSON_PARSING
		if(!findtext(data["url"], GLOB.is_http_protocol))
			return ERR_NOT_HTTPS
		if(data["duration"] > MAX_SOUND_DURATION / 10)
			return ERR_DURATION

		data["timestamp"] = world.time

		if(cached)
			qdel(cached)

		GLOB.jukebox_cache[input] = data

		qdel(output)

	var/datum/web_track/track = new(
		url = data["url"],
		title = data["title"],
		webpage_url = data["webpage_url"],
		duration = data["duration"] * 10,
		artist = data["artist"],
		album = data["album"],
		mob_name = mob_name,
		mob_ckey = mob_ckey,
		mob_key_name = mob_key_name
	)

	return track

/obj/machinery/custom_jukebox/proc/get_web_sound(input, mob_name, mob_ckey, mob_key_name)
	busy = TRUE
	var/datum/web_track/track = get_web_sound_(input, mob_name, mob_ckey, mob_key_name)
	busy = FALSE
	if(!istype(track))
		var/client/client = GLOB.directory[ckey(mob_ckey)]
		var/mob/user = client.mob
		message_admins("[key_name(mob_ckey, TRUE)] requested a bad url on [src] at [get_area_name(src)].\n[input]: [track]\n[ADMIN_FULLMONTY_NONAME(user)] [ADMIN_JMP(src)] [BANJUKEBOX(src, user.client)]")
		GLOB.jukebox_bad_input[input] = track
	return track

/obj/machinery/custom_jukebox/proc/play_in_mob_list(datum/web_track/track)
	say("Now playing: [track.title] added by [track.mob_name].")
	for(var/mob/user in listeners_in_range)
		if(user.client && user.client.prefs.read_preference(/datum/preference/toggle/sound_jukebox))
			to_chat(user, "[icon2html(src, user.client)] [span_boldnotice("Playing [track.webpage_url_html] added by [track.mob_name] on [src].")]")
			user.client.tgui_panel?.play_jukebox_music(id, track.url, track.as_list, get_volume(user))
	// for(var/client/client in clients_in_range)
	// 	if(client.prefs.read_preference(/datum/preference/toggle/sound_jukebox))
	// 		to_chat(client, "[icon2html(src, client)] [span_boldnotice("Playing [track.webpage_url_html] added by [track.mob_name] on [src].")]")
	// 		client.tgui_panel?.play_jukebox_music(id, track.url, track.as_list, get_volume(client.mob))

/obj/machinery/custom_jukebox/proc/stop_in_mob_list()
	for(var/mob/user in listeners_in_range)
		if(user.client)
			user.client.tgui_panel?.stop_jukebox_music(id)
	// for(var/client/client in clients_in_range)
	// 	client.tgui_panel?.stop_jukebox_music(id)

/obj/machinery/custom_jukebox/proc/play_music_by_track(datum/web_track/track, looped = FALSE)
	if(busy || is_playing() || !anchored || !is_operational)
		return

	if(world.time - track.timestamp > CACHE_DURATION)
		var/datum/web_track/new_track = get_web_sound(track.webpage_url, track.mob_name, track.mob_ckey, track.mob_key_name)
		qdel(track)
		track = new_track

	if(!istype(track))
		return

	if(!looped)
		QDEL_NULL(current_track)

	current_track = track
	track_started_at = world.time
	update_icon_state()

	play_in_mob_list(track)

	var/area_name = get_area_name(src, TRUE)
	var/client/client = GLOB.directory[ckey(track.mob_ckey)]

	log_admin("Playing web sound [track.webpage_url_html] on [src] added by [track.mob_key_name] at [area_name]")
	message_admins("Playing web sound [track.title] on [src] at added by [key_name(track.mob_key_name, TRUE)] at [area_name]. [ADMIN_FULLMONTY_NONAME(client.mob)] [ADMIN_JMP(src)] [STOP(src)] [BANJUKEBOX(src, client)]")
	SSblackbox.record_feedback("nested tally", "played_url", 1, list("[track.mob_ckey]", "[track.webpage_url]"))

/obj/machinery/custom_jukebox/proc/play_music_by_input(mob/user, input)
	if(busy || is_playing() || !anchored || !is_operational)
		return

	var/cache = GLOB.jukebox_bad_input[input]
	if(cache)
		track_unavailable(user, cache)
		return

	var/datum/web_track/track = get_web_sound(input, user.name, user.ckey, key_name(user))

	if(!istype(track))
		track_unavailable(user, track)
		return

	QDEL_NULL(current_track)
	current_track = track
	track_started_at = world.time
	update_icon_state()

	play_in_mob_list(track)

	var/area_name = get_area_name(src, TRUE)

	log_admin("[key_name(user)] played web sound [track.webpage_url_html] on [src] at [area_name]")
	message_admins("[key_name(user, TRUE)] played web sound [track.title] on [src] at [area_name]. [ADMIN_FULLMONTY_NONAME(user)] [ADMIN_JMP(src)] [STOP(src)] [BANJUKEBOX(src, user.client)]")
	SSblackbox.record_feedback("nested tally", "played_url", 1, list("[user.ckey]", "[input]"))

/obj/machinery/custom_jukebox/proc/stop_music()
	track_started_at = 0
	QDEL_NULL(current_track)
	stop_in_mob_list()
	update_icon_state()

/obj/machinery/custom_jukebox/proc/skip_music(manually = FALSE)
	if(loop && !manually)
		track_started_at = 0
		stop_in_mob_list()
		play_music_by_track(current_track, looped = TRUE)
	else
		stop_music()
		if(queue.len > 0)
			var/datum/web_track/track = queue[1]
			queue -= track
			play_music_by_track(track)

/obj/machinery/custom_jukebox/proc/is_playing()
	if(current_track && world.time - track_started_at < current_track.duration)
		return TRUE
	return FALSE

/obj/machinery/custom_jukebox/proc/can_mob_use(mob/user)
	if(owner == user || HAS_TRAIT(user, TRAIT_CAN_USE_JUKEBOX))
		return TRUE
	return FALSE

/obj/machinery/custom_jukebox/proc/track_unavailable(mob/user, reason)
	if(reason == ERR_DURATION)
		to_chat(user, span_warning("Track duration too long!"), confidential = TRUE)
		balloon_alert(user, "duration too long!")
	else
		say("Track is not available.")
		to_chat(user, span_warning("Track is not available."), confidential = TRUE)

/obj/machinery/custom_jukebox/proc/get_volume(mob/user)
	return (range - get_dist(src, user) - 0.9) / range

/obj/machinery/custom_jukebox/proc/tgui_input_music(title)
	var/input = tgui_input_text(usr, "Enter content URL (supported sites only, youtube)", title)
	if(input && usr.can_perform_action(src, FORBID_TELEKINESIS_REACH) && findtext(input, ytdl_regex))
		return input

/obj/machinery/custom_jukebox/on_set_is_operational(old_value)
	. = ..()
	if(!is_operational)
		stop_music()

/obj/machinery/custom_jukebox/proc/on_mob_moved(datum/source, mob/user)
	SIGNAL_HANDLER
	if(is_playing() && listeners_in_range.Find(user))
		user.client?.tgui_panel?.set_jukebox_volume(id, get_volume(user))
	// if(is_playing() && clients_in_range.Find(user.client))
	// 	user.client.tgui_panel?.set_jukebox_volume(id, get_volume(user))

/obj/machinery/custom_jukebox/proc/on_mob_entered(datum/source, mob/user)
	SIGNAL_HANDLER
	if(user.client?.prefs.read_preference(/datum/preference/toggle/sound_jukebox))
	// if(!clients_in_range.Find(user.client) && user.client?.prefs.read_preference(/datum/preference/toggle/sound_jukebox))
		listeners_in_range += user
		// clients_in_range += user.client
		if(is_playing())
			current_track.as_list["start"] = (world.time - track_started_at) / 10
			user.client.tgui_panel?.play_jukebox_music(id, current_track.url, current_track.as_list, get_volume(user))
		else
			user.client.tgui_panel?.create_jukebox_player(id)

/obj/machinery/custom_jukebox/proc/on_mob_left(datum/source, mob/user)
	SIGNAL_HANDLER
	if(listeners_in_range.Find(user))
		listeners_in_range -= user
		user.client?.tgui_panel?.destroy_jukebox_player(id)
	// if(clients_in_range.Find(user.client))
	// 	clients_in_range -= user.client
	// 	user.client?.tgui_panel?.destroy_jukebox_player(id)

/obj/item/custom_jukebox_beacon
	name = "electrical jukebox beacon"
	desc = "N.T. approved electrical jukebox beacon, toss it down and you will have a complementary electrical jukebox delivered to you."
	icon = 'icons/obj/machines/floor.dmi'
	icon_state = "floor_beacon"

/obj/item/custom_jukebox_beacon/attack_self(mob/user)
	loc.visible_message(span_warning("\The [src] begins to beep loudly!"))
	var/obj/structure/closet/supplypod/centcompod/pod = new()
	var/obj/machinery/custom_jukebox/jukebox = new(pod)
	new /obj/effect/pod_landingzone(drop_location(), pod)
	jukebox.owner = user
	jukebox.anchored = FALSE
	qdel(src)

#undef YTDL_REGEX

#undef REQUEST_COOLDOWN
#undef MAX_SOUND_DURATION
#undef CACHE_DURATION

#undef STOP
#undef BANJUKEBOX
#undef REMOVEQUEUE
#undef DENYREQUEST

#undef ERR_YTDL_NOT_CONFIGURED
#undef ERR_NOT_HTTPS
#undef ERR_JSON_RETRIEVAL
#undef ERR_JSON_PARSING
#undef ERR_DURATION

#undef SHELLEO_ERRORLEVEL
#undef SHELLEO_STDOUT
#undef SHELLEO_STDERR
