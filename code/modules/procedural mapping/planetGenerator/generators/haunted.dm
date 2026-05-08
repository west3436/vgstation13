/datum/planetGenerator/haunted
	mountain_height = 0.6
	perlin_zoom = 65

	primary_area_type = /area/planet/haunted

	biome_table = list(
		BIOME_COLDEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/haunted/barrens,
			BIOME_LOW_HUMIDITY = /datum/biome/haunted/barrens,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/haunted,
			BIOME_HIGH_HUMIDITY = /datum/biome/haunted/mire,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/haunted/mire
		),
		BIOME_COLD = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/haunted/barrens,
			BIOME_LOW_HUMIDITY = /datum/biome/haunted,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/haunted,
			BIOME_HIGH_HUMIDITY = /datum/biome/haunted/mire,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/haunted/mire
		),
		BIOME_WARM = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/haunted/barrens,
			BIOME_LOW_HUMIDITY = /datum/biome/haunted,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/haunted/cemetery,
			BIOME_HIGH_HUMIDITY = /datum/biome/haunted,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/haunted/mire
		),
		BIOME_TEMPERATE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/haunted,
			BIOME_LOW_HUMIDITY = /datum/biome/haunted/cemetery,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/haunted/cemetery,
			BIOME_HIGH_HUMIDITY = /datum/biome/haunted/mire,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/haunted/mire
		),
		BIOME_HOT = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/haunted/barrens,
			BIOME_LOW_HUMIDITY = /datum/biome/haunted,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/haunted/cemetery,
			BIOME_HIGH_HUMIDITY = /datum/biome/haunted,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/haunted
		),
		BIOME_HOTTEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/haunted/barrens,
			BIOME_LOW_HUMIDITY = /datum/biome/haunted/barrens,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/haunted,
			BIOME_HIGH_HUMIDITY = /datum/biome/haunted/cemetery,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/haunted
		)
	)

	cave_biome_table = list(
		BIOME_COLDEST_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/haunted,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/haunted,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/haunted,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/haunted,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/haunted/crypt
		),
		BIOME_COLD_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/haunted,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/haunted,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/haunted,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/haunted/crypt,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/haunted/crypt
		),
		BIOME_WARM_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/haunted,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/haunted,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/haunted/crypt,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/haunted/crypt,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/haunted/crypt
		),
		BIOME_HOT_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/haunted/crypt,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/haunted/crypt,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/haunted/crypt,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/haunted/crypt,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/haunted/crypt
		)
	)

/datum/biome/haunted
	biome_temperature = T20C - 15
	open_turf_types = list(/turf/unsimulated/floor/planetary/dirt = 1)
	flora_spawn_chance = 6
	flora_spawn_list = list(
		/obj/structure/flora/tree/dead = 6,
		/obj/structure/flora/tree/dead/barren = 5,
		/obj/structure/flora/tree/dead/tall/grey = 4,
		/obj/structure/flora/rock = 4,
		/obj/structure/flora/rock/pile = 3
	)
	mob_spawn_chance = 4
	mob_spawn_list = list(
		/mob/living/simple_animal/hostile/necro/skeleton = 35,
		/mob/living/simple_animal/hostile/necro/zombie = 30,
		/mob/living/simple_animal/hostile/scarybat = 18,
		/mob/living/simple_animal/hostile/syphoner = 10,
		/mob/living/simple_animal/hostile/creature = 8,
		/mob/living/simple_animal/shade = 5
	)
	loot_spawn_chance = 1
	loot_spawners = list(
		/obj/abstract/loot_spawner/clothing = 2,
		/obj/abstract/loot_spawner/decoration = 2,
		/obj/abstract/loot_spawner/exotic = 1,
		/obj/abstract/loot_spawner/trash = 2
	)

/datum/biome/haunted/barrens
	open_turf_types = list(/turf/unsimulated/floor/planetary/wasteland = 1)
	flora_spawn_chance = 4
	flora_spawn_list = list(
		/obj/structure/flora/tree/dead/barren = 8,
		/obj/structure/flora/rock = 8,
		/obj/structure/flora/rock/pile = 5
	)

/datum/biome/haunted/cemetery
	open_turf_types = list(/turf/unsimulated/floor/planetary/dirt = 1)
	flora_spawn_chance = 8
	flora_spawn_list = list(
		/obj/structure/flora/tree/dead = 8,
		/obj/structure/flora/tree/dead/tall/grey = 6,
		/obj/structure/flora/rock/pile = 8
	)
	feature_spawn_chance = 2
	feature_spawn_list = list(
		/obj/structure/flora/rock = 20,
		/obj/structure/flora/tree/dead/barren = 10
	)
	mob_spawn_chance = 6
	mob_spawn_list = list(
		/mob/living/simple_animal/hostile/necro/skeleton = 50,
		/mob/living/simple_animal/hostile/necro/zombie = 35,
		/mob/living/simple_animal/shade = 12,
		/mob/living/simple_animal/hostile/scarybat = 18
	)

/datum/biome/haunted/mire
	open_turf_types = list(/turf/unsimulated/floor/planetary/mud = 1)
	flora_spawn_chance = 10
	flora_spawn_list = list(
		/obj/structure/flora/tree/dead = 8,
		/obj/structure/flora/tree/dead/tall/grey = 6,
		/obj/structure/flora/rock/pile = 4
	)
	mob_spawn_chance = 6
	mob_spawn_list = list(
		/mob/living/simple_animal/hostile/necro/zombie = 40,
		/mob/living/simple_animal/hostile/necro/skeleton = 25,
		/mob/living/simple_animal/hostile/syphoner = 15,
		/mob/living/simple_animal/hostile/scarybat = 20,
		/mob/living/simple_animal/hostile/creature = 12,
		/mob/living/simple_animal/shade = 8
	)

/datum/biome/cave/haunted
	biome_temperature = T20C - 15
	open_turf_types = list(/turf/unsimulated/floor/planetary/cave = 1)
	closed_turf_types = list(
		/turf/unsimulated/mineral/random/cave = 3,
		/turf/unsimulated/mineral/random/high_chance/cave = 1
	)
	flora_spawn_chance = 5
	flora_spawn_list = list(
		/obj/structure/flora/rock/pile = 8,
		/obj/effect/glowshroom = 12
	)
	mob_spawn_chance = 4
	mob_spawn_list = list(
		/mob/living/simple_animal/hostile/necro/skeleton = 40,
		/mob/living/simple_animal/hostile/necro/zombie = 30,
		/mob/living/simple_animal/hostile/scarybat/cave = 25,
		/mob/living/simple_animal/shade = 10,
		/mob/living/simple_animal/hostile/creature = 12,
		/mob/living/simple_animal/hostile/syphoner = 12
	)
	loot_spawners = list(
		/obj/abstract/loot_spawner/clothing = 3,
		/obj/abstract/loot_spawner/decoration = 2,
		/obj/abstract/loot_spawner/exotic = 2,
		/obj/abstract/loot_spawner/structure = 2
	)

/datum/biome/cave/haunted/crypt
	open_turf_types = list(/turf/unsimulated/floor/planetary/cave = 1)
	closed_turf_types = list(
		/turf/unsimulated/mineral/random/cave = 2,
		/turf/unsimulated/mineral/random/high_chance/cave = 1
	)
	mob_spawn_chance = 6
	loot_spawn_chance = 4
