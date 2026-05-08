/datum/planetGenerator/cult
	mountain_height = 0.6
	perlin_zoom = 65

	primary_area_type = /area/planet/cult

	biome_table = list(
		BIOME_COLDEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cult/ash,
			BIOME_LOW_HUMIDITY = /datum/biome/cult/ash,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cult,
			BIOME_HIGH_HUMIDITY = /datum/biome/cult/bog,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cult/bog
		),
		BIOME_COLD = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cult/ash,
			BIOME_LOW_HUMIDITY = /datum/biome/cult,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cult,
			BIOME_HIGH_HUMIDITY = /datum/biome/cult/bog,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cult/bog
		),
		BIOME_WARM = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cult/ash,
			BIOME_LOW_HUMIDITY = /datum/biome/cult,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cult/monoliths,
			BIOME_HIGH_HUMIDITY = /datum/biome/cult,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cult/bog
		),
		BIOME_TEMPERATE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cult,
			BIOME_LOW_HUMIDITY = /datum/biome/cult/monoliths,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cult/monoliths,
			BIOME_HIGH_HUMIDITY = /datum/biome/cult,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cult/bog
		),
		BIOME_HOT = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cult/ash,
			BIOME_LOW_HUMIDITY = /datum/biome/cult,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cult/monoliths,
			BIOME_HIGH_HUMIDITY = /datum/biome/cult,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cult
		),
		BIOME_HOTTEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cult/ash,
			BIOME_LOW_HUMIDITY = /datum/biome/cult/ash,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cult,
			BIOME_HIGH_HUMIDITY = /datum/biome/cult/monoliths,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cult
		)
	)

	cave_biome_table = list(
		BIOME_COLDEST_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/cult,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/cult,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/cult,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/cult,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/cult/catacomb
		),
		BIOME_COLD_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/cult,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/cult,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/cult,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/cult/catacomb,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/cult/catacomb
		),
		BIOME_WARM_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/cult,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/cult,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/cult/catacomb,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/cult/catacomb,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/cult/catacomb
		),
		BIOME_HOT_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/cult/catacomb,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/cult/catacomb,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/cult/catacomb,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/cult/catacomb,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/cult/catacomb
		)
	)

/datum/biome/cult
	biome_temperature = T20C - 10
	open_turf_types = list(/turf/unsimulated/floor/planetary/wasteland = 1)
	flora_spawn_chance = 4
	flora_spawn_list = list(
		/obj/structure/flora/rock = 8,
		/obj/structure/flora/rock/pile = 5,
		/obj/structure/flora/tree/dead/barren = 4,
		/obj/structure/flora/tree/dead/tall/grey = 3
	)
	mob_spawn_chance = 3
	mob_spawn_list = list(
		/mob/living/simple_animal/hostile/necro/zombie = 20,
		/mob/living/simple_animal/hostile/necro/skeleton = 25,
		/mob/living/simple_animal/hostile/scarybat = 15,
		/mob/living/simple_animal/hostile/creature = 10,
		/mob/living/simple_animal/hostile/syphoner = 8
	)
	loot_spawn_chance = 1
	loot_spawners = list(
		/obj/abstract/loot_spawner/exotic = 2,
		/obj/abstract/loot_spawner/clothing = 1,
		/obj/abstract/loot_spawner/decoration = 1
	)

/datum/biome/cult/ash
	open_turf_types = list(/turf/unsimulated/floor/planetary/sand/volcanic = 1)
	flora_spawn_chance = 6
	flora_spawn_list = list(
		/obj/structure/flora/rock = 10,
		/obj/structure/flora/rock/pile = 8,
		/obj/structure/flora/tree/dead/barren = 5,
		/obj/structure/flora/tree/dead/tall/grey = 5
	)

/datum/biome/cult/monoliths
	open_turf_types = list(/turf/unsimulated/floor/planetary/wasteland = 1)
	flora_spawn_chance = 5
	flora_spawn_list = list(
		/obj/structure/flora/rock = 20,
		/obj/structure/flora/rock/pile = 12,
		/obj/structure/flora/tree/dead/barren = 4
	)
	feature_spawn_chance = 2
	feature_spawn_list = list(
		/obj/structure/flora/rock = 30,
		/obj/structure/flora/rock/pile = 20,
		/obj/structure/flora/tree/dead/tall/grey = 10
	)

/datum/biome/cult/bog
	open_turf_types = list(/turf/unsimulated/floor/planetary/mud = 1)
	flora_spawn_chance = 8
	flora_spawn_list = list(
		/obj/structure/flora/tree/dead = 6,
		/obj/structure/flora/tree/dead/tall/grey = 4,
		/obj/structure/flora/rock/pile = 4
	)
	mob_spawn_chance = 5
	mob_spawn_list = list(
		/mob/living/simple_animal/hostile/necro/zombie = 30,
		/mob/living/simple_animal/hostile/necro/skeleton = 20,
		/mob/living/simple_animal/hostile/syphoner = 12,
		/mob/living/simple_animal/hostile/scarybat = 20,
		/mob/living/simple_animal/hostile/creature = 12
	)

/datum/biome/cave/cult
	biome_temperature = T20C - 10
	open_turf_types = list(/turf/unsimulated/floor/planetary/cave = 1)
	closed_turf_types = list(
		/turf/unsimulated/mineral/random/cave = 3,
		/turf/unsimulated/mineral/random/high_chance/cave = 1
	)
	flora_spawn_chance = 4
	flora_spawn_list = list(
		/obj/structure/flora/rock = 10,
		/obj/structure/flora/rock/pile = 6,
		/obj/effect/glowshroom = 6
	)
	mob_spawn_chance = 4
	mob_spawn_list = list(
		/mob/living/simple_animal/hostile/necro/zombie = 25,
		/mob/living/simple_animal/hostile/necro/skeleton = 30,
		/mob/living/simple_animal/hostile/scarybat/cave = 20,
		/mob/living/simple_animal/hostile/creature = 15,
		/mob/living/simple_animal/hostile/syphoner = 15,
		/mob/living/simple_animal/shade = 5
	)
	loot_spawners = list(
		/obj/abstract/loot_spawner/exotic = 3,
		/obj/abstract/loot_spawner/clothing = 1,
		/obj/abstract/loot_spawner/structure = 2,
		/obj/abstract/loot_spawner/combat = 1
	)

/datum/biome/cave/cult/catacomb
	open_turf_types = list(/turf/unsimulated/floor/planetary/cave = 1)
	closed_turf_types = list(
		/turf/unsimulated/mineral/random/cave = 2,
		/turf/unsimulated/mineral/random/high_chance/cave = 1
	)
	flora_spawn_chance = 6
	flora_spawn_list = list(
		/obj/structure/flora/rock/pile = 8,
		/obj/effect/glowshroom = 12
	)
	mob_spawn_chance = 6
	loot_spawn_chance = 3
