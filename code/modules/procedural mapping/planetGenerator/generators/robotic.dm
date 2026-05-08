/datum/planetGenerator/robotic
	mountain_height = 0.7
	perlin_zoom = 60

	primary_area_type = /area/planet/robotic

	biome_table = list(
		BIOME_COLDEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/robotic/rusted,
			BIOME_LOW_HUMIDITY = /datum/biome/robotic/rusted,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/robotic,
			BIOME_HIGH_HUMIDITY = /datum/biome/robotic/blocks,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/robotic/blocks
		),
		BIOME_COLD = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/robotic/rusted,
			BIOME_LOW_HUMIDITY = /datum/biome/robotic,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/robotic,
			BIOME_HIGH_HUMIDITY = /datum/biome/robotic/blocks,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/robotic/asphalt
		),
		BIOME_WARM = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/robotic/rusted,
			BIOME_LOW_HUMIDITY = /datum/biome/robotic,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/robotic/blocks,
			BIOME_HIGH_HUMIDITY = /datum/biome/robotic/asphalt,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/robotic/asphalt
		),
		BIOME_TEMPERATE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/robotic,
			BIOME_LOW_HUMIDITY = /datum/biome/robotic/blocks,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/robotic/blocks,
			BIOME_HIGH_HUMIDITY = /datum/biome/robotic/asphalt,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/robotic/asphalt
		),
		BIOME_HOT = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/robotic/rusted,
			BIOME_LOW_HUMIDITY = /datum/biome/robotic/blocks,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/robotic/asphalt,
			BIOME_HIGH_HUMIDITY = /datum/biome/robotic/asphalt,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/robotic/asphalt
		),
		BIOME_HOTTEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/robotic/rusted,
			BIOME_LOW_HUMIDITY = /datum/biome/robotic/asphalt,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/robotic/asphalt,
			BIOME_HIGH_HUMIDITY = /datum/biome/robotic/asphalt,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/robotic/asphalt
		)
	)

	cave_biome_table = list(
		BIOME_COLDEST_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/robotic,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/robotic,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/robotic,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/robotic,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/robotic/core
		),
		BIOME_COLD_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/robotic,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/robotic,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/robotic,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/robotic/core,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/robotic/core
		),
		BIOME_WARM_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/robotic,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/robotic,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/robotic/core,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/robotic/core,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/robotic/core
		),
		BIOME_HOT_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/robotic/core,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/robotic/core,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/robotic/core,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/robotic/core,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/robotic/core
		)
	)

// Surface biomes: only mechanical/electronic mobs and constructible bots; no plants.
/datum/biome/robotic
	biome_temperature = T20C
	open_turf_types = list(/turf/unsimulated/floor/planetary/paved = 1)
	flora_spawn_chance = 4
	flora_spawn_list = list(
		/obj/structure/flora/rock = 6,
		/obj/structure/flora/rock/pile = 4,
		/obj/structure/grille/broken = 8,
		/obj/item/weapon/shard = 6
	)
	mob_spawn_chance = 4
	mob_spawn_list = list(
		/mob/living/simple_animal/hostile/hivebot = 30,
		/mob/living/simple_animal/hostile/hivebot/range = 18,
		/mob/living/simple_animal/hostile/hivebot/strong = 6,
		/mob/living/simple_animal/hostile/hivebot/rapid = 6,
		/mob/living/simple_animal/hostile/viscerator = 8,
		/mob/living/simple_animal/hostile/roboduck = 4,
		/obj/machinery/bot/floorbot = 6,
		/obj/machinery/bot/cleanbot = 6,
		/obj/machinery/bot/medbot = 5,
		/obj/machinery/bot/mulebot = 3,
		/obj/machinery/bot/secbot = 3
	)
	loot_spawn_chance = 1
	loot_spawners = list(
		/obj/abstract/loot_spawner/engineering = 4,
		/obj/abstract/loot_spawner/module = 3,
		/obj/abstract/loot_spawner/structure = 1
	)

/datum/biome/robotic/blocks
	open_turf_types = list(/turf/unsimulated/floor/planetary/paved/blocks = 1)
	flora_spawn_chance = 8
	flora_spawn_list = list(
		/obj/structure/grille/broken = 12,
		/obj/item/weapon/shard = 6,
		/obj/structure/flora/rock = 5
	)
	mob_spawn_chance = 5
	mob_spawn_list = list(
		/mob/living/simple_animal/hostile/hivebot = 35,
		/mob/living/simple_animal/hostile/hivebot/range = 25,
		/mob/living/simple_animal/hostile/hivebot/rapid = 12,
		/mob/living/simple_animal/hostile/hivebot/tele = 5,
		/mob/living/simple_animal/hostile/viscerator = 10,
		/obj/machinery/bot/floorbot = 8,
		/obj/machinery/bot/cleanbot = 6,
		/obj/machinery/bot/medbot = 5,
		/obj/machinery/bot/secbot = 5,
		/obj/machinery/bot/ed209 = 2
	)

/datum/biome/robotic/asphalt
	open_turf_types = list(/turf/unsimulated/floor/planetary/paved/asphalt = 1)
	flora_spawn_chance = 5
	flora_spawn_list = list(
		/obj/structure/grille/broken = 10,
		/obj/item/weapon/shard = 8,
		/obj/structure/flora/rock = 4
	)
	mob_spawn_chance = 6
	mob_spawn_list = list(
		/mob/living/simple_animal/hostile/hivebot/strong = 25,
		/mob/living/simple_animal/hostile/hivebot/range = 25,
		/mob/living/simple_animal/hostile/hivebot/rapid = 20,
		/mob/living/simple_animal/hostile/hivebot/tele = 8,
		/mob/living/simple_animal/hostile/viscerator = 12,
		/mob/living/simple_animal/hostile/roboduck = 5,
		/obj/machinery/bot/secbot = 8,
		/obj/machinery/bot/secbot/beepsky = 3,
		/obj/machinery/bot/ed209 = 4,
		/obj/machinery/bot/mulebot = 4
	)
	loot_spawn_chance = 2

/datum/biome/robotic/rusted
	open_turf_types = list(/turf/unsimulated/floor/planetary/rusted = 1)
	flora_spawn_chance = 10
	flora_spawn_list = list(
		/obj/structure/grille/broken = 15,
		/obj/item/weapon/shard = 10,
		/obj/structure/flora/rock/pile = 6
	)
	mob_spawn_chance = 3
	mob_spawn_list = list(
		/mob/living/simple_animal/hostile/hivebot = 40,
		/mob/living/simple_animal/hostile/hivebot/range = 20,
		/mob/living/simple_animal/hostile/viscerator = 8,
		/obj/machinery/bot/floorbot = 10,
		/obj/machinery/bot/cleanbot = 6,
		/obj/machinery/bot/mulebot = 4
	)

// Cave biomes: standard rock cave wall (same as grass planets); tech-focused loot.
/datum/biome/cave/robotic
	biome_temperature = T20C
	open_turf_types = list(/turf/unsimulated/floor/planetary/cave = 1)
	closed_turf_types = list(/turf/unsimulated/mineral/random/cave = 1)
	flora_spawn_chance = 4
	flora_spawn_list = list(
		/obj/structure/grille/broken = 10,
		/obj/item/weapon/shard = 6,
		/obj/structure/flora/rock/pile = 6
	)
	mob_spawn_chance = 4
	mob_spawn_list = list(
		/mob/living/simple_animal/hostile/hivebot = 40,
		/mob/living/simple_animal/hostile/hivebot/range = 25,
		/mob/living/simple_animal/hostile/hivebot/strong = 10,
		/mob/living/simple_animal/hostile/hivebot/rapid = 10,
		/mob/living/simple_animal/hostile/hivebot/tele = 5,
		/mob/living/simple_animal/hostile/viscerator = 12,
		/obj/machinery/bot/floorbot = 5,
		/obj/machinery/bot/medbot = 5,
		/obj/machinery/bot/secbot = 4
	)
	loot_spawners = list(
		/obj/abstract/loot_spawner/engineering = 5,
		/obj/abstract/loot_spawner/module = 4,
		/obj/abstract/loot_spawner/structure = 2
	)

/datum/biome/cave/robotic/core
	open_turf_types = list(/turf/unsimulated/floor/planetary/paved/blocks = 1)
	closed_turf_types = list(/turf/unsimulated/mineral/random/cave = 1)
	mob_spawn_chance = 7
	loot_spawn_chance = 4
