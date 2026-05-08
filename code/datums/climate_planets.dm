/********************************************
*       Climates for Procgen Planet Types    *
*  meat / cult / robotic / haunted / spore   *
*  + /datum/climate/random for distorted     *
********************************************/

///////////////////////// MEAT /////////////////////////
/datum/climate/meat
	name = "visceral"
	starting_weather_type = /datum/weather/meat
	weather_image_type = /obj/effect/weather_holder/meat
	allowed_weather_types = list(
		/datum/weather/meat,
		/datum/weather/meat/blood_rain,
		/datum/weather/meat/heart_palpitation,
	)
	weather_intensities = list(
		/datum/weather/meat = 0,
		/datum/weather/meat/blood_rain = 1,
		/datum/weather/meat/heart_palpitation = 2,
	)
	weather_transitions = list(
		/datum/weather/meat = list(
			/datum/weather/meat = 50,
			/datum/weather/meat/blood_rain = 30,
			/datum/weather/meat/heart_palpitation = 20,
		),
		/datum/weather/meat/blood_rain = list(
			/datum/weather/meat = 40,
			/datum/weather/meat/blood_rain = 40,
			/datum/weather/meat/heart_palpitation = 20,
		),
		/datum/weather/meat/heart_palpitation = list(
			/datum/weather/meat = 50,
			/datum/weather/meat/blood_rain = 30,
			/datum/weather/meat/heart_palpitation = 20,
		),
	)

/datum/weather/meat
	name = "warm and humid"
	precip_intensity = WEATHER_CALM
	temperature = T20C + 10
	precip_estimate = "none expected"

/datum/weather/meat/blood_rain
	name = "blood rain"
	precip_intensity = WEATHER_HEAVY
	temperature = T20C + 8
	precip_estimate = "<font color='red'>arterial</font>"
	light_modifier = 0.7

/datum/weather/meat/heart_palpitation
	name = "<font color='red'>palpitations</font>"
	precip_intensity = WEATHER_CALM
	temperature = T20C + 12
	precip_estimate = "anomalous"
	var/last_pulse = 0
	var/pulse_interval = 10 SECONDS
	var/pulse_sound = 'sound/effects/heart_beat_single.ogg'

/datum/weather/meat/heart_palpitation/New()
	..()
	last_pulse = world.time + pulse_interval

/datum/weather/meat/heart_palpitation/tick()
	..()
	if(world.time < last_pulse + pulse_interval)
		return
	last_pulse = world.time
	for(var/mob/living/M in get_weather_affected_players())
		shake_camera(M, 2, 1)
		M << sound(pulse_sound, repeat = 0, wait = 0, channel = CHANNEL_AMBIENCE, volume = 60)

///////////////////////// CULT /////////////////////////
/datum/climate/cult
	name = "desecrated"
	starting_weather_type = /datum/weather/cult
	weather_image_type = /obj/effect/weather_holder/cult
	allowed_weather_types = list(
		/datum/weather/cult,
		/datum/weather/cult/fog,
		/datum/weather/cult/dark_fog,
		/datum/weather/cult/eclipse,
		/datum/weather/cult/blood_moon,
	)
	weather_intensities = list(
		/datum/weather/cult = 0,
		/datum/weather/cult/fog = 1,
		/datum/weather/cult/dark_fog = 2,
		/datum/weather/cult/eclipse = 3,
		/datum/weather/cult/blood_moon = 4,
	)
	weather_transitions = list(
		/datum/weather/cult = list(
			/datum/weather/cult = 40,
			/datum/weather/cult/fog = 30,
			/datum/weather/cult/dark_fog = 15,
			/datum/weather/cult/eclipse = 10,
			/datum/weather/cult/blood_moon = 5,
		),
		/datum/weather/cult/fog = list(
			/datum/weather/cult = 30,
			/datum/weather/cult/fog = 40,
			/datum/weather/cult/dark_fog = 30,
		),
		/datum/weather/cult/dark_fog = list(
			/datum/weather/cult/fog = 40,
			/datum/weather/cult/dark_fog = 30,
			/datum/weather/cult/eclipse = 20,
			/datum/weather/cult/blood_moon = 10,
		),
		/datum/weather/cult/eclipse = list(
			/datum/weather/cult = 60,
			/datum/weather/cult/eclipse = 30,
			/datum/weather/cult/blood_moon = 10,
		),
		/datum/weather/cult/blood_moon = list(
			/datum/weather/cult = 70,
			/datum/weather/cult/blood_moon = 30,
		),
	)

/datum/weather/cult
	name = "still"
	precip_intensity = WEATHER_CALM
	temperature = T20C - 10
	precip_estimate = "none expected"
	light_modifier = 0.85

/datum/weather/cult/fog
	name = "fog"
	precip_intensity = WEATHER_HEAVY
	temperature = T20C - 12
	precip_estimate = "dense fog"
	light_modifier = 0.7
	vision_reduction = 1

/datum/weather/cult/dark_fog
	name = "<font color='purple'>dark fog</font>"
	precip_intensity = WEATHER_HEAVY
	temperature = T20C - 12
	precip_estimate = "<font color='purple'>oppressive</font>"
	light_modifier = 0.5
	vision_reduction = 2
	var/last_whisper = 0
	var/whisper_interval = 14 SECONDS
	var/last_rune_spawn = 0
	var/rune_spawn_interval = 30 SECONDS
	var/static/list/whispers = list(
		"...you should not be here...",
		"...come closer...",
		"...do you hear it...",
		"...the door is open...",
		"...we have been waiting...",
		"...it stirs beneath you...",
		"...your name is known...",
	)

/datum/weather/cult/dark_fog/New()
	..()
	last_whisper = world.time + whisper_interval
	last_rune_spawn = world.time + rune_spawn_interval

/datum/weather/cult/dark_fog/tick()
	..()
	if(world.time >= last_whisper + whisper_interval)
		last_whisper = world.time
		for(var/mob/living/M in get_weather_affected_players())
			to_chat(M, "<span class='warning'><i>[pick(whispers)]</i></span>")

	if(world.time >= last_rune_spawn + rune_spawn_interval)
		last_rune_spawn = world.time
		try_spawn_rune()

/datum/weather/cult/dark_fog/proc/try_spawn_rune()
	var/datum/virtual_z/vz = parent.v
	if(!vz)
		return
	var/list/turf/turfs = vz.get_turfs()
	if(!turfs.len)
		return
	for(var/i in 1 to 3)
		var/turf/T = pick(turfs)
		if(!isturf(T) || iswall(T))
			continue
		var/area/planet/P = get_area(T)
		if(!istype(P) || !P.is_open_surface)
			continue
		new /obj/effect/decal/cleanable/wizrune(T)
		break

/datum/weather/cult/eclipse
	name = "<font color='black'>eclipse</font>"
	precip_intensity = WEATHER_CALM
	temperature = T20C - 15
	precip_estimate = "<font color='black'>fully dark</font>"
	light_modifier = 0.05

/datum/weather/cult/blood_moon
	name = "<font color='red'>blood moon</font>"
	precip_intensity = WEATHER_CALM
	temperature = T20C - 10
	precip_estimate = "<font color='red'>crimson</font>"
	light_modifier = 0.6
	var/has_revived = FALSE
	var/last_revive_pass = 0
	var/revive_interval = 20 SECONDS

/datum/weather/cult/blood_moon/execute()
	..()
	revive_dead_on_planet()
	has_revived = TRUE
	last_revive_pass = world.time

/datum/weather/cult/blood_moon/tick()
	..()
	if(world.time >= last_revive_pass + revive_interval)
		last_revive_pass = world.time
		revive_dead_on_planet()

/datum/weather/cult/blood_moon/proc/revive_dead_on_planet()
	var/datum/virtual_z/vz = parent.v
	if(!vz)
		return
	for(var/mob/living/M in vz.get_mobs())
		if(M.stat != DEAD)
			continue
		if(M.client)
			continue
		M.revive()

///////////////////////// ROBOTIC /////////////////////////
/datum/climate/robotic
	name = "synthetic"
	starting_weather_type = /datum/weather/robotic
	weather_image_type = /obj/effect/weather_holder/robotic
	allowed_weather_types = list(
		/datum/weather/robotic,
		/datum/weather/robotic/static_storm,
		/datum/weather/robotic/smog,
		/datum/weather/robotic/power_surge,
	)
	weather_intensities = list(
		/datum/weather/robotic = 0,
		/datum/weather/robotic/static_storm = 1,
		/datum/weather/robotic/smog = 2,
		/datum/weather/robotic/power_surge = 3,
	)
	weather_transitions = list(
		/datum/weather/robotic = list(
			/datum/weather/robotic = 40,
			/datum/weather/robotic/static_storm = 25,
			/datum/weather/robotic/smog = 25,
			/datum/weather/robotic/power_surge = 10,
		),
		/datum/weather/robotic/static_storm = list(
			/datum/weather/robotic = 35,
			/datum/weather/robotic/static_storm = 35,
			/datum/weather/robotic/power_surge = 30,
		),
		/datum/weather/robotic/smog = list(
			/datum/weather/robotic = 30,
			/datum/weather/robotic/smog = 50,
			/datum/weather/robotic/static_storm = 20,
		),
		/datum/weather/robotic/power_surge = list(
			/datum/weather/robotic = 50,
			/datum/weather/robotic/static_storm = 30,
			/datum/weather/robotic/power_surge = 20,
		),
	)

/datum/weather/robotic
	name = "still air"
	precip_intensity = WEATHER_CALM
	temperature = T20C
	precip_estimate = "none expected"

/datum/weather/robotic/static_storm
	name = "static storm"
	precip_intensity = WEATHER_MODERATE
	temperature = T20C
	precip_estimate = "atmospheric ionization"
	light_modifier = 0.8
	var/spark_chance = 25

/datum/weather/robotic/static_storm/tick()
	..()
	if(!prob(spark_chance))
		return
	var/datum/virtual_z/vz = parent.v
	if(!vz)
		return
	var/list/turf/turfs = parent.weather_turfs
	if(!turfs.len)
		return
	for(var/i in 1 to rand(2, 5))
		var/turf/T = pick(turfs)
		if(!T || iswall(T))
			continue
		spark_at_turf(T)

/datum/weather/robotic/static_storm/proc/spark_at_turf(turf/T)
	var/obj/effect/sparks/S = new /obj/effect/sparks/nosurfaceburn(T)
	S.start(pick(alldirs))

/datum/weather/robotic/smog
	name = "industrial smog"
	precip_intensity = WEATHER_HEAVY
	temperature = T20C + 4
	precip_estimate = "<font color='orange'>opaque haze</font>"
	light_modifier = 0.5
	exposed_damage = 1
	damage_type = TOX
	slowdown = 0.85
	vision_reduction = 2
	weather_sound = 'sound/effects/wind/wind_4_1.ogg'
	weather_sound_volume = 50

/datum/weather/robotic/power_surge
	name = "<font color='cyan'>power surge</font>"
	precip_intensity = WEATHER_MODERATE
	temperature = T20C + 2
	precip_estimate = "<font color='cyan'>field instability</font>"
	light_modifier = 0.9
	var/zap_interval = 8 SECONDS
	var/last_zap = 0

/datum/weather/robotic/power_surge/New()
	..()
	last_zap = world.time + zap_interval

/datum/weather/robotic/power_surge/tick()
	..()
	if(world.time < last_zap + zap_interval)
		return
	last_zap = world.time

	// Spark VFX at random outdoor turfs
	var/list/turf/turfs = parent.weather_turfs
	if(turfs.len)
		for(var/i in 1 to rand(3, 6))
			var/turf/T = pick(turfs)
			if(!T || iswall(T))
				continue
			var/obj/effect/sparks/S = new /obj/effect/sparks/nosurfaceburn(T)
			S.start(pick(alldirs))

	// Damage humans only — bots are immune to keep the planet's main population intact
	for(var/mob/living/M in get_weather_affected_players())
		if(!ishuman(M))
			continue
		M.take_overall_damage(0, 5)
		to_chat(M, "<span class='warning'>A static charge crackles across your skin.</span>")

///////////////////////// HAUNTED /////////////////////////
/datum/climate/haunted
	name = "funereal"
	starting_weather_type = /datum/weather/haunted
	weather_image_type = /obj/effect/weather_holder/haunted
	allowed_weather_types = list(
		/datum/weather/haunted,
		/datum/weather/haunted/mist,
		/datum/weather/haunted/miasma,
		/datum/weather/haunted/witching_hour,
		/datum/weather/haunted/soul_lights,
		/datum/weather/haunted/funeral_knell,
	)
	weather_intensities = list(
		/datum/weather/haunted = 0,
		/datum/weather/haunted/mist = 1,
		/datum/weather/haunted/soul_lights = 1,
		/datum/weather/haunted/funeral_knell = 2,
		/datum/weather/haunted/miasma = 3,
		/datum/weather/haunted/witching_hour = 4,
	)
	weather_transitions = list(
		/datum/weather/haunted = list(
			/datum/weather/haunted = 35,
			/datum/weather/haunted/mist = 25,
			/datum/weather/haunted/miasma = 10,
			/datum/weather/haunted/soul_lights = 15,
			/datum/weather/haunted/funeral_knell = 10,
			/datum/weather/haunted/witching_hour = 5,
		),
		/datum/weather/haunted/mist = list(
			/datum/weather/haunted = 30,
			/datum/weather/haunted/mist = 30,
			/datum/weather/haunted/miasma = 25,
			/datum/weather/haunted/soul_lights = 15,
		),
		/datum/weather/haunted/miasma = list(
			/datum/weather/haunted/mist = 40,
			/datum/weather/haunted/miasma = 30,
			/datum/weather/haunted/witching_hour = 20,
			/datum/weather/haunted/funeral_knell = 10,
		),
		/datum/weather/haunted/witching_hour = list(
			/datum/weather/haunted = 60,
			/datum/weather/haunted/miasma = 30,
			/datum/weather/haunted/witching_hour = 10,
		),
		/datum/weather/haunted/soul_lights = list(
			/datum/weather/haunted = 40,
			/datum/weather/haunted/mist = 30,
			/datum/weather/haunted/soul_lights = 30,
		),
		/datum/weather/haunted/funeral_knell = list(
			/datum/weather/haunted = 50,
			/datum/weather/haunted/funeral_knell = 30,
			/datum/weather/haunted/miasma = 20,
		),
	)

/datum/weather/haunted
	name = "still"
	precip_intensity = WEATHER_CALM
	temperature = T20C - 15
	precip_estimate = "none expected"
	light_modifier = 0.6

/datum/weather/haunted/mist
	name = "mist"
	precip_intensity = WEATHER_HEAVY
	temperature = T20C - 17
	precip_estimate = "low-lying mist"
	light_modifier = 0.55
	vision_reduction = 1

/datum/weather/haunted/miasma
	name = "<font color='purple'>miasma</font>"
	precip_intensity = WEATHER_HEAVY
	temperature = T20C - 18
	precip_estimate = "<font color='purple'>thick miasma</font>"
	light_modifier = 0.4
	vision_reduction = 2
	var/last_whisper = 0
	var/whisper_interval = 14 SECONDS
	var/static/list/whispers = list(
		"...don't look back...",
		"...someone is behind you...",
		"...we remember you...",
		"...stay with us...",
		"...the bell tolls...",
		"...you are cold...",
	)

/datum/weather/haunted/miasma/New()
	..()
	last_whisper = world.time + whisper_interval

/datum/weather/haunted/miasma/tick()
	..()
	if(world.time < last_whisper + whisper_interval)
		return
	last_whisper = world.time
	for(var/mob/living/M in get_weather_affected_players())
		to_chat(M, "<span class='warning'><i>[pick(whispers)]</i></span>")

/datum/weather/haunted/witching_hour
	name = "<font color='red'>witching hour</font>"
	precip_intensity = WEATHER_CALM
	temperature = T20C - 18
	precip_estimate = "<font color='red'>restless</font>"
	light_modifier = 0.35
	var/last_revive_pass = 0
	var/revive_interval = 25 SECONDS

/datum/weather/haunted/witching_hour/execute()
	..()
	revive_dead_on_planet()
	last_revive_pass = world.time

/datum/weather/haunted/witching_hour/tick()
	..()
	if(world.time >= last_revive_pass + revive_interval)
		last_revive_pass = world.time
		revive_dead_on_planet()

/datum/weather/haunted/witching_hour/proc/revive_dead_on_planet()
	var/datum/virtual_z/vz = parent.v
	if(!vz)
		return
	for(var/mob/living/M in vz.get_mobs())
		if(M.stat != DEAD)
			continue
		if(M.client)
			continue
		M.revive()

/datum/weather/haunted/soul_lights
	name = "<font color='cyan'>soul lights</font>"
	precip_intensity = WEATHER_CALM
	temperature = T20C - 14
	precip_estimate = "<font color='cyan'>luminous drift</font>"
	light_modifier = 0.85
	var/last_wisp = 0
	var/wisp_interval = 12 SECONDS

/datum/weather/haunted/soul_lights/New()
	..()
	last_wisp = world.time + wisp_interval

/datum/weather/haunted/soul_lights/tick()
	..()
	if(world.time < last_wisp + wisp_interval)
		return
	last_wisp = world.time
	var/list/turf/turfs = parent.weather_turfs
	if(!turfs.len)
		return
	for(var/i in 1 to rand(2, 4))
		var/turf/T = pick(turfs)
		if(!T)
			continue
		var/obj/effect/sparks/S = new /obj/effect/sparks/nosurfaceburn(T)
		S.start(pick(alldirs))

/datum/weather/haunted/funeral_knell
	name = "<font color='gray'>funeral knell</font>"
	precip_intensity = WEATHER_CALM
	temperature = T20C - 16
	precip_estimate = "<font color='gray'>distant tolling</font>"
	light_modifier = 0.55
	var/last_toll = 0
	var/toll_interval = 30 SECONDS
	var/toll_sound = 'sound/items/jinglebell1.ogg'

/datum/weather/haunted/funeral_knell/New()
	..()
	last_toll = world.time + toll_interval

/datum/weather/haunted/funeral_knell/tick()
	..()
	if(world.time < last_toll + toll_interval)
		return
	last_toll = world.time
	for(var/mob/living/M in get_weather_affected_players())
		M << sound(toll_sound, repeat = 0, wait = 0, channel = CHANNEL_AMBIENCE, volume = 50)

///////////////////////// SPORE /////////////////////////
/datum/climate/spore
	name = "spore-laden"
	starting_weather_type = /datum/weather/spore
	weather_image_type = /obj/effect/weather_holder/spore
	allowed_weather_types = list(
		/datum/weather/spore,
		/datum/weather/spore/drift,
		/datum/weather/spore/pollen,
		/datum/weather/spore/glow_tide,
		/datum/weather/spore/bloom,
		/datum/weather/spore/sporebloom,
	)
	weather_intensities = list(
		/datum/weather/spore = 0,
		/datum/weather/spore/drift = 1,
		/datum/weather/spore/glow_tide = 1,
		/datum/weather/spore/sporebloom = 2,
		/datum/weather/spore/pollen = 3,
		/datum/weather/spore/bloom = 4,
	)
	weather_transitions = list(
		/datum/weather/spore = list(
			/datum/weather/spore = 35,
			/datum/weather/spore/drift = 25,
			/datum/weather/spore/pollen = 10,
			/datum/weather/spore/glow_tide = 15,
			/datum/weather/spore/sporebloom = 10,
			/datum/weather/spore/bloom = 5,
		),
		/datum/weather/spore/drift = list(
			/datum/weather/spore = 30,
			/datum/weather/spore/drift = 30,
			/datum/weather/spore/pollen = 25,
			/datum/weather/spore/glow_tide = 15,
		),
		/datum/weather/spore/pollen = list(
			/datum/weather/spore/drift = 40,
			/datum/weather/spore/pollen = 30,
			/datum/weather/spore/bloom = 20,
			/datum/weather/spore/sporebloom = 10,
		),
		/datum/weather/spore/glow_tide = list(
			/datum/weather/spore = 40,
			/datum/weather/spore/glow_tide = 30,
			/datum/weather/spore/sporebloom = 30,
		),
		/datum/weather/spore/bloom = list(
			/datum/weather/spore = 60,
			/datum/weather/spore/pollen = 30,
			/datum/weather/spore/bloom = 10,
		),
		/datum/weather/spore/sporebloom = list(
			/datum/weather/spore = 30,
			/datum/weather/spore/glow_tide = 30,
			/datum/weather/spore/sporebloom = 40,
		),
	)

/datum/weather/spore
	name = "still"
	precip_intensity = WEATHER_CALM
	temperature = T20C + 4
	precip_estimate = "none expected"
	light_modifier = 0.85

/datum/weather/spore/drift
	name = "spore drift"
	precip_intensity = WEATHER_HEAVY
	temperature = T20C + 4
	precip_estimate = "drifting spores"
	light_modifier = 0.7
	vision_reduction = 1

/datum/weather/spore/pollen
	name = "<font color='orange'>pollen storm</font>"
	precip_intensity = WEATHER_HEAVY
	temperature = T20C + 6
	precip_estimate = "<font color='orange'>thick pollen</font>"
	light_modifier = 0.6
	vision_reduction = 2
	slowdown = 0.85
	var/last_cough = 0
	var/cough_interval = 12 SECONDS

/datum/weather/spore/pollen/New()
	..()
	last_cough = world.time + cough_interval

/datum/weather/spore/pollen/tick()
	..()
	if(world.time < last_cough + cough_interval)
		return
	last_cough = world.time
	for(var/mob/living/M in get_weather_affected_players())
		if(!ishuman(M))
			continue
		var/mob/living/carbon/human/H = M
		H.emote("cough")
		if(H.reagents)
			H.reagents.add_reagent(MINDBREAKER, 1)

/datum/weather/spore/glow_tide
	name = "<font color='green'>glow tide</font>"
	precip_intensity = WEATHER_CALM
	temperature = T20C + 6
	precip_estimate = "<font color='green'>bioluminescent</font>"
	light_modifier = 1.3

/datum/weather/spore/bloom
	name = "<font color='magenta'>hallucinogenic bloom</font>"
	precip_intensity = WEATHER_HEAVY
	temperature = T20C + 8
	precip_estimate = "<font color='magenta'>psychedelic</font>"
	light_modifier = 0.8
	vision_reduction = 1
	var/last_dose = 0
	var/dose_interval = 8 SECONDS

/datum/weather/spore/bloom/New()
	..()
	last_dose = world.time + dose_interval

/datum/weather/spore/bloom/tick()
	..()
	if(world.time < last_dose + dose_interval)
		return
	last_dose = world.time
	for(var/mob/living/M in get_weather_affected_players())
		if(!ishuman(M))
			continue
		var/mob/living/carbon/human/H = M
		if(H.reagents)
			H.reagents.add_reagent(MINDBREAKER, 3)

/datum/weather/spore/sporebloom
	name = "<font color='cyan'>sporebloom</font>"
	precip_intensity = WEATHER_MODERATE
	temperature = T20C + 5
	precip_estimate = "<font color='cyan'>seeding</font>"
	light_modifier = 0.95
	var/last_seed = 0
	var/seed_interval = 6 SECONDS

/datum/weather/spore/sporebloom/New()
	..()
	last_seed = world.time + seed_interval

/datum/weather/spore/sporebloom/tick()
	..()
	if(world.time < last_seed + seed_interval)
		return
	last_seed = world.time
	var/list/turf/turfs = parent.weather_turfs
	if(!turfs.len)
		return
	for(var/i in 1 to rand(2, 5))
		var/turf/T = pick(turfs)
		if(!T || iswall(T))
			continue
		if(locate(/obj/effect/glowshroom) in T)
			continue
		new /obj/effect/glowshroom(T)

///////////////////////// RANDOM /////////////////////////
// Used by /datum/planet_type/distorted; can also be applied to any vlevel
// via the admin "Randomize Climate" Fun verb.
/datum/climate/random
	name = "random"
	weather_image_type = /obj/effect/weather_holder

/datum/climate/random/setup_weather_system()
	var/static/list/weather_pool = list(
		// Standard
		/datum/weather/standard,
		/datum/weather/cloudy,
		/datum/weather/cloudy/fog,
		/datum/weather/cloudy/rain,
		/datum/weather/cloudy/rain/heavy,
		/datum/weather/cloudy/storm,
		// Hostile
		/datum/weather/dust_storm,
		/datum/weather/sand_storm,
		/datum/weather/heatwave,
		/datum/weather/ash,
		/datum/weather/ash/storm,
		/datum/weather/fallout,
		/datum/weather/fallout/storm,
		/datum/weather/cloudy/rain/toxic,
		/datum/weather/cloudy/rain/heavy/toxic,
		/datum/weather/cloudy/rain/acid,
		/datum/weather/cloudy/rain/heavy/acid,
		// Snow
		/datum/weather/snow/calm,
		/datum/weather/snow/light,
		/datum/weather/snow/heavy,
		// Themed planet weathers
		/datum/weather/meat,
		/datum/weather/meat/blood_rain,
		/datum/weather/meat/heart_palpitation,
		/datum/weather/cult/fog,
		/datum/weather/cult/dark_fog,
		/datum/weather/cult/eclipse,
		/datum/weather/robotic/static_storm,
		/datum/weather/robotic/smog,
		/datum/weather/robotic/power_surge,
		/datum/weather/haunted/mist,
		/datum/weather/haunted/miasma,
		/datum/weather/haunted/soul_lights,
		/datum/weather/haunted/funeral_knell,
		/datum/weather/spore/drift,
		/datum/weather/spore/pollen,
		/datum/weather/spore/glow_tide,
		/datum/weather/spore/bloom,
		/datum/weather/spore/sporebloom,
	)

	allowed_weather_types = list()
	weather_intensities = list()
	weather_transitions = list()

	var/picks = rand(3, 6)
	var/list/available = weather_pool.Copy()
	for(var/i in 1 to picks)
		if(!available.len)
			break
		var/picked = pick(available)
		available -= picked
		allowed_weather_types += picked
		weather_intensities[picked] = i - 1

	// Build random transition weights between picked weather types
	for(var/wt in allowed_weather_types)
		var/list/transitions = list()
		for(var/wt2 in allowed_weather_types)
			transitions[wt2] = rand(10, 50)
		weather_transitions[wt] = transitions

	starting_weather_type = pick(allowed_weather_types)
