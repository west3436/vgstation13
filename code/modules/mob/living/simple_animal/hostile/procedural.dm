var/list/mob/living/simple_animal/hostile/procedural/procedural_mobs = list()

#define PROCMOB_FRIENDLY_CREATURE_TYPES list(/datum/procedural_mob_type/organic/friendly,/datum/procedural_mob_type/robotic/friendly)
#define PROCMOB_MELEE_CREATURE_TYPES list(/datum/procedural_mob_type/organic/melee,/datum/procedural_mob_type/robotic/melee)
#define PROCMOB_RANGED_CREATURE_TYPES list(/datum/procedural_mob_type/organic/ranged,/datum/procedural_mob_type/robotic/ranged)
#define PROCMOB_BOSS_CREATURE_TYPES list(/datum/procedural_mob_type/organic/boss,/datum/procedural_mob_type/robotic/boss)

//Mob buff flags for debug and research
#define PROCMOB_BUFFED_BRUTE		1<<1
#define PROCMOB_BUFFED_OXY			1<<2
#define PROCMOB_BUFFED_BURN			1<<3
#define PROCMOB_BUFFED_TOX			1<<4
#define PROCMOB_BUFFED_SPEED		1<<5
#define PROCMOB_BUFFED_DAMAGE		1<<6
#define PROCMOB_BUFFED_HEALTH		1<<7
#define PROCMOB_BUFFED_REGEN		1<<8
#define PROCMOB_BUFFED_DMGTYPE		1<<9
#define PROCMOB_BUFFED_SMASHING		1<<10
#define PROCMOB_BUFFED_CAMO			1<<11
#define PROCMOB_BUFFED_ATMOSIMMUNE	1<<12

//DEBUG
/turf/proc/spawn_procedural_mob(var/threat = 2)
	var/to_spawn
	var/power = 5
	switch(threat)
		if(1) //spawns friendly or weak mobs only
			if(prob(75))
				to_spawn = /mob/living/simple_animal/hostile/procedural/friendly
			else
				to_spawn = /mob/living/simple_animal/hostile/procedural/melee
				power = rand(1,3)
		if(2) //spawns melee mobs only
			to_spawn = /mob/living/simple_animal/hostile/procedural/melee
			power = rand(3,6)
		if(3) //spawns strong melee or ranged mobs with a chance of boss spawns
			if(prob(50))
				to_spawn = /mob/living/simple_animal/hostile/procedural/ranged
				power = rand(3,10)
			else if(prob(5))
				to_spawn = /mob/living/simple_animal/hostile/procedural/boss
				power = rand(5,7)
			else
				to_spawn = /mob/living/simple_animal/hostile/procedural/melee
				power = rand(7,10)
		if(4) //spawns boss mobs only
			to_spawn = /mob/living/simple_animal/hostile/procedural/boss
			power = rand(5,10)
	new to_spawn(src,revealed = TRUE,powerlevel = power)

/mob/living/simple_animal/hostile/procedural
	name = "unidentified creature"
	desc = "An undentified creature - research it at a Xenobiology Scanner to learn more about it."

	var/revealed_name = "" //name of the mob revealed after it has been studied
	var/power = 5 //relative strength of the mob
	var/buff_flags = 0 //used to track a mob's increased stats
	var/list/creature_typepaths = list()
	var/datum/procedural_mob_type/creature_type //robotic or organic
	var/list/possible_abilities = list()
	var/mob_effect_chance = 0 //%chance the mob will have an artifact effect
	var/datum/artifact_effect/mob_effect
	var/loot_chance = 0 //%chance the mob will drop loot on death
	var/last_effect_use = 0
	var/effect_cooldown = 1 MINUTES
	var/crit_effect_chance = 0

/mob/living/simple_animal/hostile/procedural/New(var/revealed = FALSE, var/powerlevel = 5)
	..()
	message_admins("starting New()")
	var/creature_typepath = pick(creature_typepaths)
	creature_type = new creature_typepath(src)
	message_admins("creature_type: [creature_type]")
	powerlevel = clamp(powerlevel,1,10)
	pick_icon()
	generate_name()
	if(revealed)
		name = revealed_name
	procedural_mobs += src
	power_up(powerlevel)
	assign_special_ability()
	pick_sounds()

/mob/living/simple_animal/hostile/procedural/proc/pick_icon()
	icon = creature_type.icon_path
	var/icon_index = pick(creature_type.possible_icon_states)
	message_admins("icon: [icon]")
	message_admins("icon index: [icon_index]")
	icon_state = "[icon_index]"
	message_admins("icon_state: [icon_state]")
	icon_living = "[icon_index]"
	message_admins("icon_living: [icon_living]")
	if("[icon_index]_dead" in icon_states(icon))
		icon_dead = "[icon_index]_dead"
	if("[icon_index]_attack" in icon_states(icon))
		icon_attack = "[icon_index]_attack"
	update_icon()
	message_admins("icon_state post update icon: [icon_state]")
	message_admins("icon: [icon]")

/mob/living/simple_animal/hostile/procedural/generate_name()
	var/taken = FALSE
	var/list/A = list("chu", "ska", "wen", "dra", "mor", "lur", "bal", "zin", "tar", "vak","grim", "zal", "kor", "vor", "snar", "kren", "thar", "gul", "kran", "zor")
	var/list/B = list("pa", "lo", "ka", "ra", "go", "ni", "tha", "va", "dra", "ku","lin", "var", "zol", "rin", "zor", "mel", "kun", "sal", "vor", "nar")
	var/list/C = list("bra", "ker", "go", "tha", "la", "nok", "ruk", "dar", "vor", "qu","mir", "dus", "rak", "zun", "voth", "gar", "kith", "zan", "rik", "lor")

	while(!revealed_name)
		var/AA = pick(A)
		var/BB = pick(B)
		var/CC = pick(C)

		var/check_name = pick(
			"[AA][BB][CC]",
			"[AA][CC]",
		)
		for(var/mob/living/simple_animal/hostile/procedural/procedural_mob in procedural_mobs)
			if(procedural_mob.name == check_name)
				taken = TRUE
				break
		if(!taken)
			revealed_name = check_name
			return

/mob/living/simple_animal/hostile/procedural/proc/reveal_name()
	name = revealed_name

/mob/living/simple_animal/hostile/procedural/proc/power_up(var/buffcount)
	var/i = 0
	while(buffcount)
		if(i >= 30) //circuit breaker
			break
		var/roll = rand(1,3)
		switch(roll)
			if(1) //increase a damage resist
				roll = rand(1,4)
				switch(roll)
					if(1) //brute resist
						brute_damage_modifier *= 0.9
						buff_flags |= PROCMOB_BUFFED_BRUTE
					if(2) //oxy resist
						oxy_damage_modifier *= 0.9
						buff_flags |= PROCMOB_BUFFED_OXY
					if(3) //burn resist
						burn_damage_modifier *= 0.9
						buff_flags |= PROCMOB_BUFFED_BURN
					if(4) //tox resist
						tox_damage_modifier *= 0.9
						buff_flags |= PROCMOB_BUFFED_TOX
			if(2) //lesser combat buff
				roll = rand(1,3)
				switch(roll)
					if(1) //increase speed
						speed *= 0.95
						speed = clamp(speed,0.8,1) //prevent sanic fast mobs
						buff_flags |= PROCMOB_BUFFED_SPEED
					if(2) //increase damage
						melee_damage_lower += 5
						melee_damage_upper += 10
						buff_flags |= PROCMOB_BUFFED_DAMAGE
					if(3) //increase health
						health += 10
						maxHealth += 20
						buff_flags |= PROCMOB_BUFFED_HEALTH
			if(3) //special buffs
				roll = rand(1,5)
				switch(roll)
					if(1) //allow regen
						if(!canRegenerate)
							canRegenerate = 1
							minRegenTime = 1 MINUTES
							maxRegenTime = 5 MINUTES
							buff_flags |= PROCMOB_BUFFED_REGEN
						else
							buffcount++ //refund point
					if(2) //change damage type
						if(melee_damage_type != BRUTE)
							melee_damage_type = pick(BURN, TOX, OXY, CLONE, HALLOSS, BRAIN)
							buff_flags |= PROCMOB_BUFFED_DMGTYPE
						else
							buffcount++ //refund point
					if(3) //allow env smashing
						if(prob(5)) //smashing rwalls
							environment_smash_flags = 3
							buff_flags |= PROCMOB_BUFFED_SMASHING
						else if(prob(25) && environment_smash_flags < 2) //smashing walls
							environment_smash_flags = 2
							buff_flags |= PROCMOB_BUFFED_SMASHING
						else if(environment_smash_flags < 1)//smashing tables
							environment_smash_flags = 1
							buff_flags |= PROCMOB_BUFFED_SMASHING
						else
							buffcount++ //refund point
					if(4) //give digital camo
						if(!digitalcamo)
							digitalcamo = 1
							buff_flags |= PROCMOB_BUFFED_CAMO
						else
							buffcount++ //refund point
					if(5) //make atmos-immune
						if(unsuitable_atmos_damage)
							unsuitable_atmos_damage = 0
							buff_flags |= PROCMOB_BUFFED_ATMOSIMMUNE
						else
							buffcount++ //refund point
		buffcount--
		i++

/mob/living/simple_animal/hostile/procedural/proc/assign_special_ability()
	if(prob(mob_effect_chance * 100) && length(possible_abilities))
		var/ability_type = pickweight(possible_abilities)
		mob_effect = new ability_type()
		mob_effect.holder = src
		mob_effect.ToggleActivate()
		effect_cooldown = clamp(120 - 12 * power,5,120) SECONDS //5s at max power (10), ~2min at lowest power (1)
		crit_effect_chance = power

/mob/living/simple_animal/hostile/procedural/proc/pick_sounds()
	var/emote_and_sound = pick(creature_type.sounds_emotes)
	if(!length(emote_and_sound))
		return
	emote_sound = list(emote_and_sound["sound"])
	emote_hear = list(emote_and_sound["emote"])
	speak_chance = rand(1,5)

/mob/living/simple_animal/hostile/procedural/attack_hand(mob/living/carbon/human/M as mob)
	..()
	if(mob_effect.effect == ARTIFACT_EFFECT_TOUCH)
		mob_effect.DoEffectTouch(M)

/mob/living/simple_animal/hostile/procedural/Life()
	..()
	if(mob_effect)
		if(world.time > last_effect_use + effect_cooldown)
			if(prob(crit_effect_chance) && mob_effect.effect == ARTIFACT_EFFECT_PULSE)
				mob_effect.DoEffectPulse(src)
			else if(mob_effect.effect == ARTIFACT_EFFECT_AURA)
				mob_effect.DoEffectAura(src)
				last_effect_use = world.time

/mob/living/simple_animal/hostile/procedural/friendly
	icon = 'icons/mob/procedural/friendly.dmi'
	health = 20
	maxHealth = 20
	melee_damage_lower = 0
	melee_damage_upper = 0
	aggro_vision_range = 1
	environment_smash_flags = 0
	response_help = "pets"
	creature_typepaths = PROCMOB_FRIENDLY_CREATURE_TYPES
	mob_effect_chance = 0.75
	possible_abilities = list(
		/datum/artifact_effect/cellcharge = 5,
		/datum/artifact_effect/clockwork = 10,
		/datum/artifact_effect/cultify = 10,
		/datum/artifact_effect/goodfeeling = 10,
		/datum/artifact_effect/heal = 5,
		/datum/artifact_effect/planthelper = 5,
		/datum/artifact_effect/recall = 5,
		/datum/artifact_effect/roboheal = 5,
		/datum/artifact_effect/teleport = 1,
		/datum/artifact_effect/timestop = 1
	)

/mob/living/simple_animal/hostile/procedural/friendly/power_up() //these fellas don't need buffs they're just here to be cute
	return

/mob/living/simple_animal/hostile/procedural/friendly/assign_special_ability()
	if(prob(10)) //10% chance for chillwax effect
		pacify_aura = TRUE
	if(prob(20)) //20% chance for regeneration
		canRegenerate = 1
		minRegenTime = 10 SECONDS
		maxRegenTime = 30 SECONDS
	..()

/mob/living/simple_animal/hostile/procedural/melee
	icon = 'icons/mob/procedural/melee.dmi'
	mob_effect_chance = 0.25
	creature_typepaths = PROCMOB_MELEE_CREATURE_TYPES

/mob/living/simple_animal/hostile/procedural/melee/New(var/revealed = FALSE, var/powerlevel = 5)
	..()
	if(power < 7)
		mob_effect_chance = 0

/mob/living/simple_animal/hostile/procedural/ranged
	icon = 'icons/mob/procedural/ranged.dmi'
	ranged = TRUE
	mob_effect_chance = 0
	creature_typepaths = PROCMOB_RANGED_CREATURE_TYPES
	var/possible_projectiles = list()

/mob/living/simple_animal/hostile/procedural/ranged/New(var/revealed = FALSE, var/powerlevel = 5)
	..()
	possible_projectiles = existing_typesof(/obj/item/projectile) - restricted_roulette_projectiles
	for(var/projectile_types in restrict_with_subtypes)
		possible_projectiles -= typesof(projectile_types)
	projectiletype = pick(possible_projectiles)

/mob/living/simple_animal/hostile/procedural/boss
	icon = 'icons/mob/procedural/boss.dmi'
	mob_effect_chance = 1
	creature_typepaths = PROCMOB_BOSS_CREATURE_TYPES
	possible_abilities = list(
		/datum/artifact_effect/badfeeling = 10,
		/datum/artifact_effect/darkness = 10,
		/datum/artifact_effect/celldrain = 10,
		/datum/artifact_effect/deadharvest = 5,
		/datum/artifact_effect/dnaswitch = 5,
		/datum/artifact_effect/emp = 5,
		/datum/artifact_effect/gravity = 10,
		/datum/artifact_effect/hurt = 5,
		/datum/artifact_effect/plantkiller = 5,
		/datum/artifact_effect/radiate = 1,
		/datum/artifact_effect/robohurt = 5,
		/datum/artifact_effect/sleepy = 5,
		/datum/artifact_effect/stun = 1,
		/datum/artifact_effect/teleport = 1,
		/datum/artifact_effect/timestop = 1
	)

/mob/living/simple_animal/hostile/procedural/boss/New(var/revealed = FALSE, var/powerlevel = 5)
	..()
	if(power < 7)
		mob_effect_chance = 0

//Procedural Mob Type Datums
//Contains icon state indices and their respective sounds and loot tables
/datum/procedural_mob_type
	var/list/sounds_emotes = list()
	var/list/possible_icon_states = list()
	var/icon_path

/datum/procedural_mob_type/organic
	sounds_emotes = list(
		list("sound" = "sound/voice/catmeow.ogg", "emote" = "meows"),
		list("sound" = "sound/voice/chicken.ogg", "emote" = "clucks"),
		list("sound" = "sound/voice/corgibark.ogg", "emote" = "barks"),
		list("sound" = "sound/voice/corgibark_echo.ogg", "emote" = "barks hauntingly"),
		list("sound" = "sound/voice/frogcroak.ogg", "emote" = "croaks"),
		list("sound" = "sound/voice/hiss1.ogg", "emote" = "hisses"),
		list("sound" = "sound/voice/hiss2.ogg", "emote" = "hisses"),
		list("sound" = "sound/voice/hiss3.ogg", "emote" = "hisses"),
		list("sound" = "sound/voice/hiss4.ogg", "emote" = "hisses"),
		list("sound" = "sound/voice/hiss5.ogg", "emote" = "hisses"),
		list("sound" = "sound/voice/hiss6.ogg", "emote" = "hisses"),
		list("sound" = "sound/voice/penguin.ogg", "emote" = "chirps"),
		list("sound" = "sound/voice/pigsnort.ogg", "emote" = "snorts"),
		list("sound" = "sound/voice/pigsqueal.ogg", "emote" = "squeals"),
		list("sound" = "sound/voice/pitbullbark.ogg", "emote" = "barks"),
		list("sound" = "sound/misc/grue_growl.ogg", "emote" = "growls"),
		list("sound" = "sound/misc/grue_screech.ogg", "emote" = "screeches"),
		list("sound" = "sound/misc/hiss1.ogg", "emote" = "hisses"),
		list("sound" = "sound/misc/hiss2.ogg", "emote" = "hisses"),
		list("sound" = "sound/misc/hiss3.ogg", "emote" = "hisses"),
		list("sound" = "sound/misc/shriek1.ogg", "emote" = "shrieks")
	)

/datum/procedural_mob_type/organic/friendly
	icon_path = 'icons/mob/procedural/friendly.dmi'
	possible_icon_states = list(2,3,4,5,6,7,10,11,12,13,14)

/datum/procedural_mob_type/organic/melee
	icon_path = 'icons/mob/procedural/melee.dmi'
	possible_icon_states = list(1,2,3,4,5,6,8,9,10,11,12,13,14,15,16,17,18,19,22,23,24,26,27,28)

/datum/procedural_mob_type/organic/ranged
	icon_path = 'icons/mob/procedural/ranged.dmi'
	possible_icon_states = list(1,2,3,9)

/datum/procedural_mob_type/organic/boss
	icon_path = 'icons/mob/procedural/boss.dmi'
	possible_icon_states = list(1,3,5,7)

/datum/procedural_mob_type/robotic
	sounds_emotes = list(
		list("sound" = "sound/voice/catmeow.ogg", "emote" = "meows"),
		list("sound" = "sound/voice/chicken.ogg", "emote" = "clucks"),
		list("sound" = "sound/voice/corgibark.ogg", "emote" = "barks"),
		list("sound" = "sound/voice/corgibark_echo.ogg", "emote" = "barks hauntingly"),
		list("sound" = "sound/voice/frogcroak.ogg", "emote" = "croaks"),
		list("sound" = "sound/voice/hiss1.ogg", "emote" = "hisses"),
		list("sound" = "sound/voice/hiss2.ogg", "emote" = "hisses"),
		list("sound" = "sound/voice/hiss3.ogg", "emote" = "hisses"),
		list("sound" = "sound/voice/hiss4.ogg", "emote" = "hisses"),
		list("sound" = "sound/voice/hiss5.ogg", "emote" = "hisses"),
		list("sound" = "sound/voice/hiss6.ogg", "emote" = "hisses"),
		list("sound" = "sound/voice/penguin.ogg", "emote" = "chirps"),
		list("sound" = "sound/voice/pigsnort.ogg", "emote" = "snorts"),
		list("sound" = "sound/voice/pigsqueal.ogg", "emote" = "squeals"),
		list("sound" = "sound/voice/pitbullbark.ogg", "emote" = "barks"),
		list("sound" = "sound/misc/grue_growl.ogg", "emote" = "growls"),
		list("sound" = "sound/misc/grue_screech.ogg", "emote" = "screeches"),
		list("sound" = "sound/misc/hiss1.ogg", "emote" = "hisses"),
		list("sound" = "sound/misc/hiss2.ogg", "emote" = "hisses"),
		list("sound" = "sound/misc/hiss3.ogg", "emote" = "hisses"),
		list("sound" = "sound/misc/shriek1.ogg", "emote" = "shrieks"),
		list("sound" = "sound/misc/voxvocal1.ogg", "emote" = "vocalizes"),
		list("sound" = "sound/misc/voxvocal2.ogg", "emote" = "vocalizes"),
		list("sound" = "sound/misc/voxvocal3.ogg", "emote" = "vocalizes"),
		list("sound" = "sound/misc/voxvocal4.ogg", "emote" = "vocalizes"),
		list("sound" = "sound/misc/voxvocal5.ogg", "emote" = "vocalizes")
	)

/datum/procedural_mob_type/robotic/friendly
	icon_path = 'icons/mob/procedural/friendly.dmi'
	possible_icon_states = list(1,8,9)

/datum/procedural_mob_type/robotic/melee
	icon_path = 'icons/mob/procedural/melee.dmi'
	possible_icon_states = list(7,20,21,25)

/datum/procedural_mob_type/robotic/ranged
	icon_path = 'icons/mob/procedural/ranged.dmi'
	possible_icon_states = list(4,5,6,7,8)

/datum/procedural_mob_type/robotic/boss
	icon_path = 'icons/mob/procedural/boss.dmi'
	possible_icon_states = list(2,4,6)

#undef PROCMOB_FRIENDLY_CREATURE_TYPES
#undef PROCMOB_MELEE_CREATURE_TYPES
#undef PROCMOB_RANGED_CREATURE_TYPES
#undef PROCMOB_BOSS_CREATURE_TYPES
