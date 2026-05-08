// The "distorted" planet rolls a random donor generator on each instantiation
// and copies its biome_table / cave_biome_table. Loot, ruins, and mob faction
// stay tied to the planet_type itself (set in planet_types.dm).
/datum/planetGenerator/distorted
	mountain_height = 0.5
	perlin_zoom = 65

	primary_area_type = /area/planet/distorted

	// Defaults — overwritten in New() before the parent constructor runs the
	// biome grid build, so the grid uses the donor's tables.
	biome_table = list()
	cave_biome_table = list()

/datum/planetGenerator/distorted/New(var/generation_size, var/skip_cave_gen = FALSE)
	if(!skip_cave_gen)
		var/static/list/donor_types = list(
			/datum/planetGenerator/beach,
			/datum/planetGenerator/cult,
			/datum/planetGenerator/desert,
			/datum/planetGenerator/grass,
			/datum/planetGenerator/haunted,
			/datum/planetGenerator/jungle,
			/datum/planetGenerator/lava,
			/datum/planetGenerator/meat,
			/datum/planetGenerator/robotic,
			/datum/planetGenerator/snow,
			/datum/planetGenerator/spore,
			/datum/planetGenerator/urban,
			/datum/planetGenerator/xeno,
		)
		var/picked = pick(donor_types)
		var/datum/planetGenerator/donor = new picked(generation_size, TRUE)
		biome_table = donor.biome_table
		cave_biome_table = donor.cave_biome_table
		mountain_height = donor.mountain_height
		perlin_zoom = donor.perlin_zoom
		qdel(donor)
	return ..(generation_size, skip_cave_gen)
