/datum/planetGenerator/meat
	// Extremely cavernous: nearly all of the map sits above mountain_height so cave
	// biomes dominate, and the cellular automaton is tuned to keep passages tight
	// (more starting walls, walls survive erosion, open cells fill in easily).
	mountain_height = 0.2
	perlin_zoom = 25

	primary_area_type = /area/planet/meat
	// Cave biomes share the surface area so weather registers on every floor turf
	// (cave areas have is_open_surface = FALSE which would block weather).
	cave_area_type = /area/planet/meat

	biome_table = list(
		BIOME_COLDEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/meat,
			BIOME_LOW_HUMIDITY = /datum/biome/meat,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/meat,
			BIOME_HIGH_HUMIDITY = /datum/biome/meat,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/meat
		),
		BIOME_COLD = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/meat,
			BIOME_LOW_HUMIDITY = /datum/biome/meat,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/meat,
			BIOME_HIGH_HUMIDITY = /datum/biome/meat,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/meat
		),
		BIOME_WARM = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/meat,
			BIOME_LOW_HUMIDITY = /datum/biome/meat,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/meat,
			BIOME_HIGH_HUMIDITY = /datum/biome/meat,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/meat
		),
		BIOME_TEMPERATE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/meat,
			BIOME_LOW_HUMIDITY = /datum/biome/meat,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/meat,
			BIOME_HIGH_HUMIDITY = /datum/biome/meat,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/meat
		),
		BIOME_HOT = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/meat,
			BIOME_LOW_HUMIDITY = /datum/biome/meat,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/meat,
			BIOME_HIGH_HUMIDITY = /datum/biome/meat,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/meat
		),
		BIOME_HOTTEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/meat,
			BIOME_LOW_HUMIDITY = /datum/biome/meat,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/meat,
			BIOME_HIGH_HUMIDITY = /datum/biome/meat,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/meat
		)
	)

	cave_biome_table = list(
		BIOME_COLDEST_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/meat/guts,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/meat/guts,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/meat/guts,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/meat/viscera,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/meat/blood
		),
		BIOME_COLD_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/meat/guts,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/meat/guts,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/meat/guts,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/meat/viscera,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/meat/blood
		),
		BIOME_WARM_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/meat/guts,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/meat/guts,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/meat/viscera,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/meat/blood,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/meat/blood
		),
		BIOME_HOT_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/meat/guts,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/meat/viscera,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/meat/blood,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/meat/blood,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/meat/blood
		)
	)

/datum/biome/meat
	biome_temperature = T20C + 10
	open_turf_types = list(/turf/unsimulated/floor/planetary/flesh = 1)
	flora_spawn_chance = 8
	flora_spawn_list = list(
		/obj/structure/puddle/blood = 2,
		/obj/structure/bone_cocoon = 3,
		/obj/effect/decal/cleanable/blood = 12,
		/obj/effect/decal/cleanable/blood/gibs = 8,
		/obj/effect/gibspawner/human = 3
	)
	mob_spawn_chance = 5
	mob_spawn_list = list(
		/obj/abstract/meatblob_spawner = 35,
		/mob/living/simple_animal/hostile/necro/meat_ghoul = 35,
		/mob/living/simple_animal/hostile/necro/necromorph = 15,
		/mob/living/simple_animal/hostile/blood_splot = 10,
		/mob/living/simple_animal/hostile/humanoid/kitchen/meatballer = 6,
		/mob/living/simple_animal/hostile/humanoid/kitchen/poutine = 2,
		/mob/living/simple_animal/hostile/retaliate/tomato = 6
	)
	loot_spawn_chance = 2
	loot_spawners = list(
		/obj/abstract/loot_spawner/food_or_drink = 3,
		/obj/abstract/loot_spawner/trash = 3,
		/obj/abstract/loot_spawner/medical = 2,
		/obj/abstract/loot_spawner/exotic = 1
	)

// Cave biomes: guts (default), viscera (transitional) and blood (hot/wet).
/datum/biome/cave/meat/guts
	biome_temperature = T20C + 10
	open_turf_types = list(/turf/unsimulated/floor/planetary/flesh = 1)
	closed_turf_types = list(/turf/unsimulated/mineral/cave/guts = 1)
	flora_spawn_chance = 10
	flora_spawn_list = list(
		/obj/structure/puddle/blood = 4,
		/obj/structure/bone_cocoon = 4,
		/obj/effect/decal/cleanable/blood = 14,
		/obj/effect/decal/cleanable/blood/gibs = 10,
		/obj/effect/gibspawner/human = 4
	)
	mob_spawn_chance = 6
	mob_spawn_list = list(
		/obj/abstract/meatblob_spawner = 40,
		/mob/living/simple_animal/hostile/necro/meat_ghoul = 35,
		/mob/living/simple_animal/hostile/necro/necromorph = 18,
		/mob/living/simple_animal/hostile/blood_splot = 12,
		/mob/living/simple_animal/hostile/humanoid/kitchen/meatballer = 5,
		/mob/living/simple_animal/hostile/humanoid/kitchen/poutine = 2,
		/mob/living/simple_animal/hostile/retaliate/tomato = 6
	)
	loot_spawn_chance = 2
	loot_spawners = list(
		/obj/abstract/loot_spawner/food_or_drink = 3,
		/obj/abstract/loot_spawner/trash = 2,
		/obj/abstract/loot_spawner/medical = 3,
		/obj/abstract/loot_spawner/exotic = 2
	)

/datum/biome/cave/meat/blood
	biome_temperature = T20C + 10
	open_turf_types = list(/turf/unsimulated/floor/planetary/flesh = 1)
	closed_turf_types = list(/turf/unsimulated/mineral/cave/blood = 1)
	flora_spawn_chance = 10
	flora_spawn_list = list(
		/obj/structure/puddle/blood = 5,
		/obj/structure/bone_cocoon = 5,
		/obj/effect/decal/cleanable/blood = 15,
		/obj/effect/decal/cleanable/blood/gibs = 10,
		/obj/effect/gibspawner/human = 4
	)
	mob_spawn_chance = 6
	mob_spawn_list = list(
		/obj/abstract/meatblob_spawner = 40,
		/mob/living/simple_animal/hostile/necro/meat_ghoul = 40,
		/mob/living/simple_animal/hostile/necro/necromorph = 20,
		/mob/living/simple_animal/hostile/blood_splot = 12,
		/mob/living/simple_animal/hostile/humanoid/kitchen/meatballer = 5,
		/mob/living/simple_animal/hostile/humanoid/kitchen/poutine = 2,
		/mob/living/simple_animal/hostile/retaliate/tomato = 6
	)
	loot_spawn_chance = 2
	loot_spawners = list(
		/obj/abstract/loot_spawner/food_or_drink = 3,
		/obj/abstract/loot_spawner/trash = 2,
		/obj/abstract/loot_spawner/medical = 3,
		/obj/abstract/loot_spawner/exotic = 2
	)

/datum/biome/cave/meat/viscera
	biome_temperature = T20C + 10
	open_turf_types = list(/turf/unsimulated/floor/planetary/flesh = 1)
	closed_turf_types = list(/turf/unsimulated/mineral/cave/viscera = 1)
	flora_spawn_chance = 12
	flora_spawn_list = list(
		/obj/structure/puddle/blood = 6,
		/obj/structure/bone_cocoon = 5,
		/obj/effect/decal/cleanable/blood = 14,
		/obj/effect/decal/cleanable/blood/gibs = 12,
		/obj/effect/gibspawner/human = 5
	)
	mob_spawn_chance = 7
	mob_spawn_list = list(
		/obj/abstract/meatblob_spawner = 45,
		/mob/living/simple_animal/hostile/necro/meat_ghoul = 35,
		/mob/living/simple_animal/hostile/necro/necromorph = 18,
		/mob/living/simple_animal/hostile/blood_splot = 14,
		/mob/living/simple_animal/hostile/humanoid/kitchen/meatballer = 5,
		/mob/living/simple_animal/hostile/humanoid/kitchen/poutine = 2,
		/mob/living/simple_animal/hostile/retaliate/tomato = 6
	)
	loot_spawn_chance = 2
	loot_spawners = list(
		/obj/abstract/loot_spawner/food_or_drink = 3,
		/obj/abstract/loot_spawner/trash = 2,
		/obj/abstract/loot_spawner/medical = 3,
		/obj/abstract/loot_spawner/exotic = 2
	)
