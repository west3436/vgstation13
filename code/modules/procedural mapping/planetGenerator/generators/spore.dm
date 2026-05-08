/datum/planetGenerator/spore
	mountain_height = 0.55
	perlin_zoom = 70

	primary_area_type = /area/planet/spore

	biome_table = list(
		BIOME_COLDEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/spore,
			BIOME_LOW_HUMIDITY = /datum/biome/spore,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/spore/myconid,
			BIOME_HIGH_HUMIDITY = /datum/biome/spore/myconid,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/spore/bog
		),
		BIOME_COLD = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/spore,
			BIOME_LOW_HUMIDITY = /datum/biome/spore/myconid,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/spore/myconid,
			BIOME_HIGH_HUMIDITY = /datum/biome/spore/bog,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/spore/bog
		),
		BIOME_WARM = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/spore,
			BIOME_LOW_HUMIDITY = /datum/biome/spore/myconid,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/spore/bloom,
			BIOME_HIGH_HUMIDITY = /datum/biome/spore/bog,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/spore/bog
		),
		BIOME_TEMPERATE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/spore/myconid,
			BIOME_LOW_HUMIDITY = /datum/biome/spore/bloom,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/spore/bloom,
			BIOME_HIGH_HUMIDITY = /datum/biome/spore/bog,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/spore/bog
		),
		BIOME_HOT = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/spore,
			BIOME_LOW_HUMIDITY = /datum/biome/spore/bloom,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/spore/bloom,
			BIOME_HIGH_HUMIDITY = /datum/biome/spore/bog,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/spore/bog
		),
		BIOME_HOTTEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/spore/myconid,
			BIOME_LOW_HUMIDITY = /datum/biome/spore/bloom,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/spore/bloom,
			BIOME_HIGH_HUMIDITY = /datum/biome/spore/bloom,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/spore/bog
		)
	)

	cave_biome_table = list(
		BIOME_COLDEST_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/spore,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/spore,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/spore,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/spore,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/spore/bloom
		),
		BIOME_COLD_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/spore,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/spore,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/spore,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/spore/bloom,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/spore/bloom
		),
		BIOME_WARM_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/spore,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/spore,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/spore/bloom,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/spore/bloom,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/spore/bloom
		),
		BIOME_HOT_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/spore/bloom,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/spore/bloom,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/spore/bloom,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/spore/bloom,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/spore/bloom
		)
	)

/datum/biome/spore
	biome_temperature = T20C + 5
	open_turf_types = list(/turf/unsimulated/floor/planetary/moss = 1)
	flora_spawn_chance = 8
	flora_spawn_list = list(
		/obj/effect/glowshroom = 30,
		/obj/structure/flora/ash/cap_shroom = 8,
		/obj/structure/flora/ash/stem_shroom = 8,
		/obj/structure/flora/ash/leaf_shroom = 6,
		/obj/structure/flora/ash/tall_shroom = 4
	)
	mob_spawn_chance = 4
	mob_spawn_list = list(
		/mob/living/simple_animal/hostile/mushroom = 60,
		/mob/living/simple_animal/hostile/tree = 15,
		/mob/living/simple_animal/hostile/creature = 12,
		/mob/living/simple_animal/cockroach = 25,
		/mob/living/simple_animal/mouse/common = 15
	)
	loot_spawn_chance = 1
	loot_spawners = list(
		/obj/abstract/loot_spawner/food_or_drink = 2,
		/obj/abstract/loot_spawner/medical = 1,
		/obj/abstract/loot_spawner/exotic = 1
	)

/datum/biome/spore/myconid
	open_turf_types = list(/turf/unsimulated/floor/planetary/moss = 1)
	flora_spawn_chance = 14
	flora_spawn_list = list(
		/obj/effect/glowshroom = 25,
		/obj/structure/flora/ash/cap_shroom = 12,
		/obj/structure/flora/ash/stem_shroom = 12,
		/obj/structure/flora/ash/tall_shroom = 8,
		/obj/structure/flora/ash/leaf_shroom = 6
	)

/datum/biome/spore/bloom
	open_turf_types = list(/turf/unsimulated/floor/planetary/moss = 1)
	flora_spawn_chance = 18
	flora_spawn_list = list(
		/obj/effect/glowshroom = 40,
		/obj/structure/flora/ash/cap_shroom = 15,
		/obj/structure/flora/ash/tall_shroom = 12,
		/obj/structure/flora/ash/fern = 8
	)
	feature_spawn_chance = 2
	feature_spawn_list = list(
		/obj/structure/flora/ash/tall_shroom = 30,
		/obj/structure/flora/ash/cap_shroom = 20
	)
	mob_spawn_chance = 5

/datum/biome/spore/bog
	open_turf_types = list(/turf/unsimulated/floor/planetary/mud = 1)
	flora_spawn_chance = 12
	flora_spawn_list = list(
		/obj/effect/glowshroom = 35,
		/obj/structure/flora/ash/cap_shroom = 10,
		/obj/structure/flora/ash/stem_shroom = 10,
		/obj/structure/flora/ash/fern = 6
	)
	mob_spawn_chance = 6
	mob_spawn_list = list(
		/mob/living/simple_animal/hostile/mushroom = 80,
		/mob/living/simple_animal/hostile/tree = 20,
		/mob/living/simple_animal/hostile/creature = 15,
		/mob/living/simple_animal/cockroach = 30
	)

/datum/biome/cave/spore
	biome_temperature = T20C + 5
	open_turf_types = list(/turf/unsimulated/floor/planetary/moss = 1)
	closed_turf_types = list(
		/turf/unsimulated/mineral/random/cave = 3,
		/turf/unsimulated/mineral/random/high_chance/cave = 1
	)
	flora_spawn_chance = 12
	flora_spawn_list = list(
		/obj/effect/glowshroom = 50,
		/obj/structure/flora/ash/cap_shroom = 12,
		/obj/structure/flora/ash/stem_shroom = 12,
		/obj/structure/flora/ash/tall_shroom = 8,
		/obj/structure/flora/ash/leaf_shroom = 6
	)
	mob_spawn_chance = 5
	mob_spawn_list = list(
		/mob/living/simple_animal/hostile/mushroom = 80,
		/mob/living/simple_animal/hostile/tree = 20,
		/mob/living/simple_animal/hostile/creature = 15,
		/mob/living/simple_animal/cockroach = 25,
		/mob/living/simple_animal/mouse/common = 15
	)
	loot_spawners = list(
		/obj/abstract/loot_spawner/medical = 3,
		/obj/abstract/loot_spawner/food_or_drink = 2,
		/obj/abstract/loot_spawner/exotic = 2
	)

/datum/biome/cave/spore/bloom
	open_turf_types = list(/turf/unsimulated/floor/planetary/moss = 1)
	closed_turf_types = list(
		/turf/unsimulated/mineral/random/cave = 2,
		/turf/unsimulated/mineral/random/high_chance/cave = 1
	)
	flora_spawn_chance = 18
	mob_spawn_chance = 7
	loot_spawn_chance = 3
