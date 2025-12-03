//the random offset applied to square coordinates, causes intermingling at biome borders
#define BIOME_RANDOM_SQUARE_DRIFT 1

// Perlin noise value ranges
#define PERLIN_NOISE_MIN 0
#define PERLIN_NOISE_MAX 1

// Humidity thresholds
#define HUMIDITY_THRESHOLD_LOW 0.20
#define HUMIDITY_THRESHOLD_MEDIUM_LOW 0.40
#define HUMIDITY_THRESHOLD_MEDIUM_HIGH 0.60
#define HUMIDITY_THRESHOLD_HIGH 0.80

// Standard heat level thresholds (for surface biomes)
#define HEAT_THRESHOLD_COLD 0.20
#define HEAT_THRESHOLD_WARM 0.40
#define HEAT_THRESHOLD_TEMPERATE_LOW 0.60
#define HEAT_THRESHOLD_TEMPERATE_HIGH 0.65
#define HEAT_THRESHOLD_HOT 0.80

// Cave heat level thresholds
#define CAVE_HEAT_THRESHOLD_COLD 0.25
#define CAVE_HEAT_THRESHOLD_WARM 0.5
#define CAVE_HEAT_THRESHOLD_HOT 0.75

#define MINOR_THREAT_REDUCTION 20
#define MODERATE_THREAT_REDUCTION 30
#define MAJOR_THREAT_REDUCTION 40


/datum/planetGenerator
	/// Higher values of this variable result in larger biomes.
	var/perlin_zoom = 65

	/// If a turf's perlin-calculated "height" is above this value, a cave biome will be used to generate it.
	/// For best results, avoid values around 0.5; basic perlin noise can create noticeable straight-line artifacts
	/// around the midpoint value. A value of 1 or greater disables caves entirely.
	var/mountain_height = 0.7

	/// Chance for a cell in the cavegen cellular automaton to start closed
	var/initial_closed_chance = 45
	/// # of steps that the cellular automaton is run for
	var/smoothing_iterations = 20
	/// If an open (dead) cell has greater than this many neighbors, it become closed (alive).
	var/birth_limit = 4
	/// If a closed (alive) cell has fewer than this many neighbors, it will become open (dead).
	var/death_limit = 3

	/// The type of the area that will be used for all non-cave biomes.
	var/area/planet/primary_area_type
	/// The area instance that will be used for all non-cave biomes.
	var/area/planet/primary_area

	/// The type of the area that will be used for all cave biomes.
	var/area/planet/cave_area_type = /area/planet/cave
	/// The area instance that will be used for all cave biomes.
	var/area/planet/cave_area

	/// Effectively a 2D array of biomes, organized by heat categories, then humidity.
	/// Note that the heat categories are NOT all equal-size.
	var/list/biome_table

	/// A 2D array of "cave" biomes that generate at "heights" above the mountain_height variable.
	/// Like normal biomes, they are organized by heat, then humidity; however, they do NOT
	/// use the same heat categories as the normal biome table does.
	var/list/cave_biome_table

	/// Perlin noise seed for height generation
	var/height_seed
	/// Perlin noise seed for humidity generation
	var/humidity_seed
	/// Perlin noise seed for heat/temperature generation
	var/heat_seed

	/// Cellular automaton output string used during cave generation
	var/cave_automaton_data

	/// Temporary list storing features created during population phase (cleared after use)
	var/list/created_features = list()
	/// Temporary list storing mobs created during population phase (cleared after use)
	var/list/created_mobs = list()

	/// Cache mapping turfs to their calculated biomes to avoid recalculation
	var/list/turf_biome_cache

	/// Merged loot table used for spawning loot on this planet
	var/datum/loot_table/planet_loot

	// Planet reference
	var/datum/planet_type/planet_ref

	/// Noise modifiers
	var/heat_mod
	var/humidity_mod

	var/base_heat
	var/input_heat
	var/base_humidity
	var/input_humidity
	var/base_terrain
	var/input_terrain
	var/base_atmosphere
	var/input_atmosphere
	var/list/atmosphere = list()

	// Actual values used (for reporting to UI)
	var/actual_heat
	var/actual_humidity
	var/actual_terrain
	var/actual_atmosphere

	var/remaining_threat = 0
	var/base_threat = PLANET_THREAT_NONE

/datum/planetGenerator/New(var/terrain = 0, var/humidity = 0, var/heat = 0, var/atmos_filter = 0)
	// Initialize perlin noise seeds with random values
	height_seed = rand(0, 50000)
	humidity_seed = rand(0, 50000)
	heat_seed = rand(0, 50000)

	input_terrain = terrain
	input_humidity = humidity
	input_heat = heat
	input_atmosphere = atmos_filter

	// Generate cellular automaton data for caves if they are enabled
	mountain_height = get_height()
	if(mountain_height < 1)
		cave_automaton_data = rustg_cnoise_generate("[initial_closed_chance]", "[smoothing_iterations]", "[birth_limit]", "[death_limit]", "[SECTOR_SIZE]", "[SECTOR_SIZE]")

	heat_mod = get_heat_mod()

	humidity_mod = get_humidity_mod()

	// Initialize area instances
	primary_area = new primary_area_type
	cave_area = new cave_area_type

	// Initialize the biome cache
	turf_biome_cache = list()

	// Setup atmos
	atmosphere = get_atmosphere()

	calculate_threat_level()

	return ..()

/datum/planetGenerator/proc/generate_turf(turf/gen_turf)
	var/area/turf_area = get_area(gen_turf)
	if(!(turf_area.flags & CAVES_ALLOWED))
		return

	var/datum/biome/turf_biome = get_biome(gen_turf)
	if(!turf_biome)
		return

	// Determine which area to use based on biome type
	var/area/used_area = istype(turf_biome, /datum/biome/cave) ? cave_area : primary_area
	turf_biome.generate_turf(gen_turf, used_area, cave_automaton_data, atmosphere)

/datum/planetGenerator/proc/populate_turf(turf/gen_turf, created_features, created_mobs, planet_loot, planet_faction = null)
	var/datum/biome/turf_biome = get_biome(gen_turf)
	if(!turf_biome)
		return
	remaining_threat -= turf_biome.populate_turf(gen_turf, created_features, created_mobs, planet_loot, planet_faction, remaining_threat)

/datum/planetGenerator/proc/post_process(datum/allocation/allocation)
	return

/// Gets the biome for a turf, using the cache if available, otherwise calculating and caching it.
/// Returns: The datum/biome for the given turf
/datum/planetGenerator/proc/get_biome(turf/a_turf)
	// Check cache first to avoid recalculation
	if(turf_biome_cache[a_turf])
		return turf_biome_cache[a_turf]

	// Apply random offset to coordinates to create fuzzy biome borders and hide perlin artifacts
	var/drift_x = (a_turf.x + rand(-BIOME_RANDOM_SQUARE_DRIFT, BIOME_RANDOM_SQUARE_DRIFT)) / perlin_zoom
	var/drift_y = (a_turf.y + rand(-BIOME_RANDOM_SQUARE_DRIFT, BIOME_RANDOM_SQUARE_DRIFT)) / perlin_zoom

	var/heat_level
	var/humidity_level

	var/datum/biome/sel_biome

	// Calculate humidity level from perlin noise
	var/humidity = clamp(text2num(rustg_noise_get_at_coordinates("[humidity_seed]", "[drift_x]", "[drift_y]")) + humidity_mod, PERLIN_NOISE_MIN, PERLIN_NOISE_MAX)
	switch(humidity)
		if(PERLIN_NOISE_MIN to HUMIDITY_THRESHOLD_LOW)
			humidity_level = BIOME_LOWEST_HUMIDITY
		if(HUMIDITY_THRESHOLD_LOW to HUMIDITY_THRESHOLD_MEDIUM_LOW)
			humidity_level = BIOME_LOW_HUMIDITY
		if(HUMIDITY_THRESHOLD_MEDIUM_LOW to HUMIDITY_THRESHOLD_MEDIUM_HIGH)
			humidity_level = BIOME_MEDIUM_HUMIDITY
		if(HUMIDITY_THRESHOLD_MEDIUM_HIGH to HUMIDITY_THRESHOLD_HIGH)
			humidity_level = BIOME_HIGH_HUMIDITY
		if(HUMIDITY_THRESHOLD_HIGH to PERLIN_NOISE_MAX)
			humidity_level = BIOME_HIGHEST_HUMIDITY

	// Calculate heat level from perlin noise
	var/heat = clamp(text2num(rustg_noise_get_at_coordinates("[heat_seed]", "[drift_x]", "[drift_y]")) + heat_mod, PERLIN_NOISE_MIN, PERLIN_NOISE_MAX)

	// Calculate height to determine if this is a cave or surface biome
	var/height = text2num(rustg_noise_get_at_coordinates("[height_seed]", "[drift_x]", "[drift_y]"))
	var/is_cave = height > mountain_height

	if(!is_cave)
		// Surface biome heat calculation
		switch(heat)
			if(PERLIN_NOISE_MIN to HEAT_THRESHOLD_COLD)
				heat_level = BIOME_COLDEST
			if(HEAT_THRESHOLD_COLD to HEAT_THRESHOLD_WARM)
				heat_level = BIOME_COLD
			if(HEAT_THRESHOLD_WARM to HEAT_THRESHOLD_TEMPERATE_LOW)
				heat_level = BIOME_WARM
			if(HEAT_THRESHOLD_TEMPERATE_LOW to HEAT_THRESHOLD_TEMPERATE_HIGH)
				heat_level = BIOME_TEMPERATE
			if(HEAT_THRESHOLD_TEMPERATE_HIGH to HEAT_THRESHOLD_HOT)
				heat_level = BIOME_HOT
			if(HEAT_THRESHOLD_HOT to PERLIN_NOISE_MAX)
				heat_level = BIOME_HOTTEST

		sel_biome = SSmapping.biomes[biome_table[heat_level][humidity_level]]
	else
		// Cave biome heat calculation
		switch(heat)
			if(PERLIN_NOISE_MIN to CAVE_HEAT_THRESHOLD_COLD)
				heat_level = BIOME_COLDEST_CAVE
			if(CAVE_HEAT_THRESHOLD_COLD to CAVE_HEAT_THRESHOLD_WARM)
				heat_level = BIOME_COLD_CAVE
			if(CAVE_HEAT_THRESHOLD_WARM to CAVE_HEAT_THRESHOLD_HOT)
				heat_level = BIOME_WARM_CAVE
			if(CAVE_HEAT_THRESHOLD_HOT to PERLIN_NOISE_MAX)
				heat_level = BIOME_HOT_CAVE

		sel_biome = SSmapping.biomes[cave_biome_table[heat_level][humidity_level]]

	turf_biome_cache[a_turf] = sel_biome
	return sel_biome

/datum/planetGenerator/proc/get_height()
	var/used_terrain = base_terrain
	if(input_terrain) //if a terrain has been picked, use it
		used_terrain = input_terrain
	else if(prob(25) || !planet_ref) //25% chance to definitely use base terrain, or if planet_ref not set yet
		used_terrain = base_terrain
	else
		used_terrain = pick(planet_ref.possible_terrain) //pick from all possible otherwise

	actual_terrain = used_terrain

	// Flat: 0.85 to 1.0 (fewer caves, flatter)
	// Hilly: 0.65 to 0.85 (moderate caves)
	// Mountainous: 0.45 to 0.65 (more caves, more mountainous)
	switch(used_terrain)
		if(PLANET_TERRAIN_FLAT)
			return rand(85, 100) / 100
		if(PLANET_TERRAIN_HILLY)
			return rand(65, 85) / 100
		if(PLANET_TERRAIN_MOUNTAINOUS)
			return pick(rand(45, 47),rand(53,65)) / 100 // values around 0.5 look bad
	return rand(65, 85) / 100


/datum/planetGenerator/proc/get_humidity_mod()
	var/used_humidity = base_humidity
	if(input_humidity) //if a humidity has been picked, use it
		used_humidity = input_humidity
	else if(prob(25) || !planet_ref) //25% chance to definitely use base humidity, or if planet_ref not set yet
		used_humidity = base_humidity
	else
		used_humidity = pick(planet_ref.possible_humidity) //pick from all possible otherwise

	actual_humidity = used_humidity

	if(used_humidity == base_humidity)
		return 0 // no mod needed

	// Very Low: -0.4 to -0.2 (drier)
	// Low: -0.2 to -0.1
	// Medium: -0.1 to 0.1 (neutral)
	// High: 0.1 to 0.2
	// Very High: 0.2 to 0.4 (wetter)
	switch(used_humidity)
		if(PLANET_VERY_LOW_HUMIDITY)
			return rand(-40, -20) / 100
		if(PLANET_LOW_HUMIDITY)
			return rand(-20, -10) / 100
		if(PLANET_MEDIUM_HUMIDITY)
			return rand(-10, 10) / 100
		if(PLANET_HIGH_HUMIDITY)
			return rand(10, 20) / 100
		if(PLANET_VERY_HIGH_HUMIDITY)
			return rand(20, 40) / 100
	return 0

/datum/planetGenerator/proc/get_heat_mod()
	var/used_heat = base_heat
	if(input_heat) //if a heat has been picked, use it
		used_heat = input_heat
	else if(prob(25) || !planet_ref) //25% chance to definitely use base heat, or if planet_ref not set yet
		used_heat = base_heat
	else
		used_heat = pick(planet_ref.possible_heat) //pick from all possible otherwise

	actual_heat = used_heat

	if(used_heat == base_heat)
		return 0 // no mod needed

	// Very Low: -0.4 to -0.2 (colder)
	// Low: -0.2 to -0.1
	// Medium: -0.1 to 0.1 (neutral)
	// High: 0.1 to 0.2
	// Very High: 0.2 to 0.4 (hotter)
	switch(used_heat)
		if(PLANET_VERY_LOW_TEMPERATURE)
			return rand(-40, -20) / 100
		if(PLANET_LOW_TEMPERATURE)
			return rand(-20, -10) / 100
		if(PLANET_MEDIUM_TEMPERATURE)
			return rand(-10, 10) / 100
		if(PLANET_HIGH_TEMPERATURE)
			return rand(10, 20) / 100
		if(PLANET_VERY_HIGH_TEMPERATURE)
			return rand(20, 40) / 100
	return 0

/datum/planetGenerator/proc/get_atmosphere()
	var/temp = T20C
	var/used_heat = input_heat ? input_heat : base_heat
	switch(used_heat)
		if(PLANET_VERY_LOW_TEMPERATURE to PLANET_LOW_TEMPERATURE)
			temp = rand(T_ARCTIC, T0C)
		if(PLANET_LOW_TEMPERATURE to PLANET_MEDIUM_TEMPERATURE)
			temp = rand(T0C, T20C)
		if(PLANET_MEDIUM_TEMPERATURE to PLANET_HIGH_TEMPERATURE)
			temp = rand(T20C, T20C + 20)
		if(PLANET_HIGH_TEMPERATURE to PLANET_VERY_HIGH_TEMPERATURE)
			temp = rand(T20C + 20, T20C + 40)
	var/used_atmos = base_atmosphere
	if(input_atmosphere) //if an atmosphere has been picked, use it
		used_atmos = input_atmosphere
	else if(prob(25) || !planet_ref) //25% chance to definitely use base atmosphere, or if planet_ref not set yet
		used_atmos = base_atmosphere
	else
		used_atmos = pick(planet_ref.possible_atmosphere) //pick from all possible otherwise

	actual_atmosphere = used_atmos

	var/pressure = ONE_ATMOSPHERE
	var/o2 = 0
	var/n2 = 0
	var/co2 = 0
	var/toxins = 0
	var/radon = 0
	switch(used_atmos)
		if(PLANET_ATMOSPHERE_NONE)
			return list(temp, 0, 0, 0, 0, 0) // No atmosphere - just temperature, no gases
		if(PLANET_ATMOSPHERE_THIN)
			pressure = MARS_ATMOSPHERE
			n2 = rand(0,100)/100
			co2 = 1-n2
		if(PLANET_ATMOSPHERE_BREATHABLE)
			o2 = rand(19,23)/100
			n2 = 1-o2
		if(PLANET_ATMOSPHERE_TOXIC)
			var/i = 1
			o2 = rand(0,15)/100
			i-=o2
			n2 = rand(0,i*100)/100
			i-=n2
			toxins = rand(0, i*100)/100
			co2 = i-toxins
		if(PLANET_ATMOSPHERE_RADIOACTIVE)
			var/i = 1
			o2 = rand(0,15)/100
			i-=o2
			n2 = rand(0,i*100)/100
			i-=n2
			radon = rand(0, i*100)/100
			co2 = i-radon
	var/moles = pressure*CELL_VOLUME/(temp*R_IDEAL_GAS_EQUATION)
	o2 *= moles
	n2 *= moles
	co2 *= moles
	toxins *= moles
	toxins = min(toxins, MOLES_PLASMA_VISIBLE - 0.1)
	radon *= moles

	return list(temp,o2,n2,co2,toxins,radon)

/datum/planetGenerator/proc/calculate_threat_level()
	remaining_threat = rand(0,100) + base_threat
	switch(actual_atmosphere)
		if(PLANET_ATMOSPHERE_NONE)
			remaining_threat -= MODERATE_THREAT_REDUCTION
		if(PLANET_ATMOSPHERE_THIN)
			remaining_threat -= MINOR_THREAT_REDUCTION
		if(PLANET_ATMOSPHERE_TOXIC)
			remaining_threat -= MAJOR_THREAT_REDUCTION
		if(PLANET_ATMOSPHERE_RADIOACTIVE)
			remaining_threat -= MAJOR_THREAT_REDUCTION
	switch(actual_heat)
		if(PLANET_VERY_LOW_TEMPERATURE)
			remaining_threat -= MINOR_THREAT_REDUCTION
		if(PLANET_VERY_HIGH_TEMPERATURE)
			remaining_threat -= MINOR_THREAT_REDUCTION
	remaining_threat = max(0, remaining_threat)

#undef BIOME_RANDOM_SQUARE_DRIFT
#undef PERLIN_NOISE_MIN
#undef PERLIN_NOISE_MAX
#undef HUMIDITY_THRESHOLD_LOW
#undef HUMIDITY_THRESHOLD_MEDIUM_LOW
#undef HUMIDITY_THRESHOLD_MEDIUM_HIGH
#undef HUMIDITY_THRESHOLD_HIGH
#undef HEAT_THRESHOLD_COLD
#undef HEAT_THRESHOLD_WARM
#undef HEAT_THRESHOLD_TEMPERATE_LOW
#undef HEAT_THRESHOLD_TEMPERATE_HIGH
#undef HEAT_THRESHOLD_HOT
#undef CAVE_HEAT_THRESHOLD_COLD
#undef CAVE_HEAT_THRESHOLD_WARM
#undef CAVE_HEAT_THRESHOLD_HOT
#undef MINOR_THREAT_REDUCTION
#undef MODERATE_THREAT_REDUCTION
#undef MAJOR_THREAT_REDUCTION
