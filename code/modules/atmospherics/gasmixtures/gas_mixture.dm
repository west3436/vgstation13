 /*
What are the archived variables for?
	Calculations are done using the archived variables with the results merged into the regular variables.
	This prevents race conditions that arise based on the order of tile processing.
*/
#define SPECIFIC_HEAT_TOXIN		200
#define SPECIFIC_HEAT_AIR		20
#define SPECIFIC_HEAT_CDO		30
#define SPECIFIC_HEAT_N2O		40
#define SPECIFIC_HEAT_AGENT_B	300

#define HEAT_CAPACITY_CALCULATION(oxygen, carbon_dioxide, nitrogen, toxins, sleeping, oxagent, innate_heat_capacity) \
	(carbon_dioxide * SPECIFIC_HEAT_CDO + (oxygen + nitrogen) * SPECIFIC_HEAT_AIR + toxins * SPECIFIC_HEAT_TOXIN + sleeping * SPECIFIC_HEAT_N2O + oxagent * SPECIFIC_HEAT_AGENT_B + innate_heat_capacity)

#define MINIMUM_HEAT_CAPACITY	0.0003
#define MINIMUM_MOLE_COUNT		0.01

/datum/gas_mixture
	/// The volume this gas mixture fills.
	var/volume = CELL_VOLUME
	/// Heat capacity intrinsic to the container of this gas mixture.
	var/innate_heat_capacity = 0
	/// How much fuel this gas mixture burnt last reaction.
	var/fuel_burnt = 0

	// Private fields. Use the matching procs to get and set them.
	// e.g. GM.oxygen(), GM.set_oxygen()
	var/private_oxygen = 0
	var/private_carbon = 0
	var/private_nitrogen = 0
	var/private_plasma = 0
	var/private_sleeping = 0
	var/private_oxagent = 0
	var/private_temperature = 0 //in Kelvin

	// Archived versions of the private fields.
	// Only gas_mixture should use these.
	var/private_oxygen_archived = 0
	var/private_carbon_archived = 0
	var/private_nitrogen_archived = 0
	var/private_plasma_archived = 0
	var/private_sleeping_archived = 0
	var/private_oxagent_archived = 0
	var/private_temperature_archived = 0

	/// Is this mixture currently synchronized with MILLA? Always true for non-bound mixtures.
	var/synchronized = TRUE

	/// Tracks the callbacks from synchronize() that haven't run yet.
	var/list/waiting_for_sync = list()

/datum/gas_mixture/Destroy()
	waiting_for_sync.Cut()
	return ..()

/// Marks this gas mixture as changed from MILLA. Does nothing on non-bound mixtures.
/datum/gas_mixture/proc/set_dirty()
	return

/datum/gas_mixture/proc/oxygen()
	return private_oxygen

/datum/gas_mixture/proc/set_oxygen(value)
	private_oxygen = value

/datum/gas_mixture/proc/carbon_dioxide()
	return private_carbon

/datum/gas_mixture/proc/set_carbon_dioxide(value)
	private_carbon = value

/datum/gas_mixture/proc/nitrogen()
	return private_nitrogen

/datum/gas_mixture/proc/set_nitrogen(value)
	private_nitrogen = value

/datum/gas_mixture/proc/plasma()
	return private_plasma

/datum/gas_mixture/proc/set_plasma(value)
	private_plasma = value

/datum/gas_mixture/proc/sleeping()
	return private_sleeping

/datum/gas_mixture/proc/set_sleeping(value)
	private_sleeping = value

/datum/gas_mixture/proc/oxagent()
	return private_oxagent

/datum/gas_mixture/proc/set_oxagent(value)
	private_oxagent = value

/datum/gas_mixture/proc/temperature()
	return private_temperature

/datum/gas_mixture/proc/set_temperature(value)
	private_temperature = value

	///joules per kelvin
/datum/gas_mixture/proc/heat_capacity()
	return HEAT_CAPACITY_CALCULATION(private_oxygen, private_carbon, private_nitrogen, private_plasma, private_sleeping, private_oxagent, innate_heat_capacity)

/datum/gas_mixture/proc/heat_capacity_archived()
	return HEAT_CAPACITY_CALCULATION(private_oxygen_archived, private_carbon_archived, private_nitrogen_archived, private_plasma_archived, private_sleeping_archived, private_oxagent_archived, innate_heat_capacity)

	/// Calculate moles
/datum/gas_mixture/proc/total_moles()
	var/moles = private_oxygen + private_carbon + private_nitrogen + private_plasma + private_sleeping + private_oxagent
	return moles

/datum/gas_mixture/proc/total_trace_moles()
	var/moles = private_oxagent
	return moles

	/// Calculate pressure in kilopascals
/datum/gas_mixture/proc/return_pressure()
	if(volume > 0)
		return total_moles() * R_IDEAL_GAS_EQUATION * private_temperature / volume
	return 0

	/// Calculate volume in liters
/datum/gas_mixture/proc/return_volume()
	return max(0, volume)

	/// Calculate thermal energy in joules
/datum/gas_mixture/proc/thermal_energy()
	return private_temperature * heat_capacity()

	///Update archived versions of variables. Returns: TRUE in all cases
/datum/gas_mixture/proc/archive()
	private_oxygen_archived = private_oxygen
	private_carbon_archived = private_carbon
	private_nitrogen_archived =  private_nitrogen
	private_plasma_archived = private_plasma
	private_sleeping_archived = private_sleeping
	private_oxagent_archived = private_oxagent

	private_temperature_archived = private_temperature

	return TRUE

	///Merges all air from giver into self. Deletes giver. Returns: TRUE if we are mutable, FALSE otherwise
/datum/gas_mixture/proc/merge(datum/gas_mixture/giver)
	if(!giver)
		return FALSE


	if(abs(private_temperature - giver.private_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		var/self_heat_capacity = heat_capacity()
		var/giver_heat_capacity = giver.heat_capacity()
		var/combined_heat_capacity = giver_heat_capacity + self_heat_capacity
		if(combined_heat_capacity != 0)
			private_temperature = (giver.private_temperature * giver_heat_capacity + private_temperature * self_heat_capacity) / combined_heat_capacity

	private_oxygen += giver.private_oxygen
	private_carbon += giver.private_carbon
	private_nitrogen += giver.private_nitrogen
	private_plasma += giver.private_plasma
	private_sleeping += giver.private_sleeping
	private_oxagent += giver.private_oxagent

	set_dirty()
	return TRUE

	/// Only removes the gas if we have more than the amount
/datum/gas_mixture/proc/boolean_remove(amount)
	if(amount > total_moles())
		return FALSE
	return remove(amount)

	///Proportionally removes amount of gas from the gas_mixture.
	///Returns: gas_mixture with the gases removed
/datum/gas_mixture/proc/remove(amount)

	var/sum = total_moles()
	amount = min(amount, sum) //Can not take more air than tile has!
	if(amount <= 0)
		return null

	var/datum/gas_mixture/removed = new


	removed.private_oxygen = QUANTIZE((private_oxygen / sum) * amount)
	removed.private_nitrogen = QUANTIZE((private_nitrogen/  sum) * amount)
	removed.private_carbon = QUANTIZE((private_carbon / sum) * amount)
	removed.private_plasma = QUANTIZE((private_plasma / sum) * amount)
	removed.private_sleeping = QUANTIZE((private_sleeping / sum) * amount)
	removed.private_oxagent = QUANTIZE((private_oxagent / sum) * amount)

	private_oxygen = max(private_oxygen - removed.private_oxygen, 0)
	private_nitrogen = max(private_nitrogen - removed.private_nitrogen, 0)
	private_carbon = max(private_carbon - removed.private_carbon, 0)
	private_plasma = max(private_plasma - removed.private_plasma, 0)
	private_sleeping = max(private_sleeping - removed.private_sleeping, 0)
	private_oxagent = max(private_oxagent - removed.private_oxagent, 0)

	removed.private_temperature = private_temperature

	set_dirty()
	return removed

	///Proportionally removes amount of gas from the gas_mixture.
	///Returns: gas_mixture with the gases removed
/datum/gas_mixture/proc/remove_ratio(ratio)

	if(ratio <= 0)
		return null

	ratio = min(ratio, 1)

	var/datum/gas_mixture/removed = new

	removed.private_oxygen = QUANTIZE(private_oxygen * ratio)
	removed.private_nitrogen = QUANTIZE(private_nitrogen * ratio)
	removed.private_carbon = QUANTIZE(private_carbon * ratio)
	removed.private_plasma = QUANTIZE(private_plasma * ratio)
	removed.private_sleeping = QUANTIZE(private_sleeping * ratio)
	removed.private_oxagent = QUANTIZE(private_oxagent * ratio)

	private_oxygen = max(private_oxygen - removed.private_oxygen, 0)
	private_nitrogen = max(private_nitrogen - removed.private_nitrogen, 0)
	private_carbon = max(private_carbon - removed.private_carbon, 0)
	private_plasma = max(private_plasma - removed.private_plasma, 0)
	private_sleeping = max(private_sleeping - removed.private_sleeping, 0)
	private_oxagent = max(private_oxagent - removed.private_oxagent, 0)

	removed.private_temperature = private_temperature
	set_dirty()

	return removed

	//Copies variables from sample
/datum/gas_mixture/proc/copy_from(datum/gas_mixture/sample)
	private_oxygen = sample.private_oxygen
	private_carbon = sample.private_carbon
	private_nitrogen = sample.private_nitrogen
	private_plasma = sample.private_plasma
	private_sleeping = sample.private_sleeping
	private_oxagent = sample.private_oxagent

	private_temperature = sample.private_temperature
	set_dirty()

	return TRUE

	///Copies all gas info from the turf into the gas list along with temperature
	///Returns: TRUE if we are mutable, FALSE otherwise
/datum/gas_mixture/proc/copy_from_turf(turf/model)
	private_oxygen = model.oxygen
	private_carbon = model.carbon_dioxide
	private_nitrogen = model.nitrogen
	private_plasma = model.toxins
	private_sleeping = model.sleeping
	private_oxagent = model.oxagent

	//acounts for changes in temperature
	var/turf/model_parent = model.parent_type
	if(model.temperature != initial(model.temperature) || model.temperature != initial(model_parent.temperature))
		private_temperature = model.temperature
	set_dirty()

	return TRUE

	///Performs air sharing calculations between two gas_mixtures assuming only 1 boundary length
	///Returns: amount of gas exchanged (+ if sharer received)
/datum/gas_mixture/proc/share(datum/gas_mixture/sharer, atmos_adjacent_turfs = 4)
	if(!sharer)
		return 0
	/// Don't make calculations if there is no difference.
	if(private_oxygen_archived == sharer.private_oxygen_archived && private_carbon_archived == sharer.private_carbon_archived && private_nitrogen_archived == sharer.private_nitrogen_archived &&\
	private_plasma_archived == sharer.private_plasma_archived && private_sleeping_archived == sharer.private_sleeping_archived && private_oxagent_archived == sharer.private_oxagent_archived && private_temperature_archived == sharer.private_temperature_archived)
		return 0
	var/delta_oxygen = QUANTIZE(private_oxygen_archived - sharer.private_oxygen_archived) / (atmos_adjacent_turfs + 1)
	var/delta_carbon_dioxide = QUANTIZE(private_carbon_archived - sharer.private_carbon_archived) / (atmos_adjacent_turfs + 1)
	var/delta_nitrogen = QUANTIZE(private_nitrogen_archived - sharer.private_nitrogen_archived) / (atmos_adjacent_turfs + 1)
	var/delta_toxins = QUANTIZE(private_plasma_archived - sharer.private_plasma_archived) / (atmos_adjacent_turfs + 1)
	var/delta_sleeping = QUANTIZE(private_sleeping_archived - sharer.private_sleeping_archived) / (atmos_adjacent_turfs + 1)
	var/delta_oxagent = QUANTIZE(private_oxagent_archived - sharer.private_oxagent_archived) / (atmos_adjacent_turfs + 1)

	var/delta_temperature = (private_temperature_archived - sharer.private_temperature_archived)

	var/old_self_heat_capacity = 0
	var/old_sharer_heat_capacity = 0

	var/heat_capacity_self_to_sharer = 0
	var/heat_capacity_sharer_to_self = 0

	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)

		var/delta_air = delta_oxygen + delta_nitrogen
		if(delta_air)
			var/air_heat_capacity = SPECIFIC_HEAT_AIR * delta_air
			if(delta_air > 0)
				heat_capacity_self_to_sharer += air_heat_capacity
			else
				heat_capacity_sharer_to_self -= air_heat_capacity

		if(delta_carbon_dioxide)
			var/carbon_dioxide_heat_capacity = SPECIFIC_HEAT_CDO * delta_carbon_dioxide
			if(delta_carbon_dioxide > 0)
				heat_capacity_self_to_sharer += carbon_dioxide_heat_capacity
			else
				heat_capacity_sharer_to_self -= carbon_dioxide_heat_capacity

		if(delta_toxins)
			var/toxins_heat_capacity = SPECIFIC_HEAT_TOXIN * delta_toxins
			if(delta_toxins > 0)
				heat_capacity_self_to_sharer += toxins_heat_capacity
			else
				heat_capacity_sharer_to_self -= toxins_heat_capacity

		if(delta_sleeping)
			var/sleeping_heat_capacity = SPECIFIC_HEAT_N2O * delta_sleeping
			if(delta_sleeping > 0)
				heat_capacity_self_to_sharer += sleeping_heat_capacity
			else
				heat_capacity_sharer_to_self -= sleeping_heat_capacity

		if(delta_oxagent)
			var/oxagent_heat_capacity = SPECIFIC_HEAT_AGENT_B * delta_oxagent
			if(delta_oxagent > 0)
				heat_capacity_self_to_sharer += oxagent_heat_capacity
			else
				heat_capacity_sharer_to_self -= oxagent_heat_capacity

		old_self_heat_capacity = heat_capacity()
		old_sharer_heat_capacity = sharer.heat_capacity()

	private_oxygen -= delta_oxygen
	sharer.private_oxygen += delta_oxygen

	private_carbon -= delta_carbon_dioxide
	sharer.private_carbon += delta_carbon_dioxide

	private_nitrogen -= delta_nitrogen
	sharer.private_nitrogen += delta_nitrogen

	private_plasma -= delta_toxins
	sharer.private_plasma += delta_toxins

	private_sleeping -= delta_sleeping
	sharer.private_sleeping += delta_sleeping

	private_oxagent -= delta_oxagent
	sharer.private_oxagent += delta_oxagent

	var/moved_moles = (delta_oxygen + delta_carbon_dioxide + delta_nitrogen + delta_toxins + delta_sleeping + delta_oxagent)

	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		var/new_self_heat_capacity = old_self_heat_capacity + heat_capacity_sharer_to_self - heat_capacity_self_to_sharer
		var/new_sharer_heat_capacity = old_sharer_heat_capacity + heat_capacity_self_to_sharer - heat_capacity_sharer_to_self

		if(new_self_heat_capacity > MINIMUM_HEAT_CAPACITY)
			private_temperature = (old_self_heat_capacity * private_temperature - heat_capacity_self_to_sharer * private_temperature_archived + heat_capacity_sharer_to_self * sharer.private_temperature_archived) / new_self_heat_capacity

		if(new_sharer_heat_capacity > MINIMUM_HEAT_CAPACITY)
			sharer.private_temperature = (old_sharer_heat_capacity * sharer.private_temperature - heat_capacity_sharer_to_self * sharer.private_temperature_archived + heat_capacity_self_to_sharer * private_temperature_archived) / new_sharer_heat_capacity

			if(abs(old_sharer_heat_capacity) > MINIMUM_HEAT_CAPACITY)
				if(abs(new_sharer_heat_capacity / old_sharer_heat_capacity - 1) < 0.10) // <10% change in sharer heat capacity
					temperature_share(sharer, OPEN_HEAT_TRANSFER_COEFFICIENT)

	set_dirty()
	if((delta_temperature > MINIMUM_TEMPERATURE_TO_MOVE) || abs(moved_moles) > MINIMUM_MOLES_DELTA_TO_MOVE)
		var/delta_pressure = private_temperature_archived * (total_moles() + moved_moles) - sharer.private_temperature_archived * (sharer.total_moles() - moved_moles)
		return delta_pressure * R_IDEAL_GAS_EQUATION / volume

	//Similar to share(...), except the model is not modified
	//Return: amount of gas exchanged
/datum/gas_mixture/proc/mimic(turf/model, atmos_adjacent_turfs = 4) //I want this proc to die a painful death
	var/delta_oxygen = QUANTIZE(private_oxygen_archived - model.oxygen) / (atmos_adjacent_turfs + 1)
	var/delta_carbon_dioxide = QUANTIZE(private_carbon_archived - model.carbon_dioxide) / (atmos_adjacent_turfs + 1)
	var/delta_nitrogen = QUANTIZE(private_nitrogen_archived - model.nitrogen) / (atmos_adjacent_turfs + 1)
	var/delta_toxins = QUANTIZE(private_plasma_archived - model.toxins) / (atmos_adjacent_turfs + 1)
	var/delta_sleeping = QUANTIZE(private_sleeping_archived - model.sleeping) / (atmos_adjacent_turfs + 1)
	var/delta_oxagent = QUANTIZE(private_oxagent_archived - model.oxagent) / (atmos_adjacent_turfs + 1)

	var/delta_temperature = (private_temperature_archived - model.temperature)

	var/heat_transferred = 0
	var/old_self_heat_capacity = 0
	var/heat_capacity_transferred = 0

	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)

		var/delta_air = delta_oxygen + delta_nitrogen
		if(delta_air)
			var/air_heat_capacity = SPECIFIC_HEAT_AIR * delta_air
			heat_transferred -= air_heat_capacity * model.temperature
			heat_capacity_transferred -= air_heat_capacity

		if(delta_carbon_dioxide)
			var/carbon_dioxide_heat_capacity = SPECIFIC_HEAT_CDO * delta_carbon_dioxide
			heat_transferred -= carbon_dioxide_heat_capacity * model.temperature
			heat_capacity_transferred -= carbon_dioxide_heat_capacity

		if(delta_toxins)
			var/toxins_heat_capacity = SPECIFIC_HEAT_TOXIN * delta_toxins
			heat_transferred -= toxins_heat_capacity * model.temperature
			heat_capacity_transferred -= toxins_heat_capacity

		if(delta_sleeping)
			var/sleeping_heat_capacity = SPECIFIC_HEAT_N2O * delta_sleeping
			heat_transferred -= sleeping_heat_capacity * model.temperature
			heat_capacity_transferred -= sleeping_heat_capacity

		if(delta_oxagent)
			var/oxagent_heat_capacity = SPECIFIC_HEAT_AGENT_B * delta_oxagent
			heat_transferred -= oxagent_heat_capacity * model.temperature
			heat_capacity_transferred -= oxagent_heat_capacity

		old_self_heat_capacity = heat_capacity()

	private_oxygen -= delta_oxygen
	private_carbon -= delta_carbon_dioxide
	private_nitrogen -= delta_nitrogen
	private_plasma -= delta_toxins
	private_sleeping -= delta_sleeping
	private_oxagent -= delta_oxagent

	var/moved_moles = (delta_oxygen + delta_carbon_dioxide + delta_nitrogen + delta_toxins + delta_sleeping + delta_oxagent)

	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		var/new_self_heat_capacity = old_self_heat_capacity - heat_capacity_transferred
		if(new_self_heat_capacity > MINIMUM_HEAT_CAPACITY)
			private_temperature = (old_self_heat_capacity * private_temperature - heat_capacity_transferred * private_temperature_archived) / new_self_heat_capacity

		temperature_mimic(model, model.thermal_conductivity)

	set_dirty()
	if((delta_temperature > MINIMUM_TEMPERATURE_TO_MOVE) || abs(moved_moles) > MINIMUM_MOLES_DELTA_TO_MOVE)
		var/delta_pressure = private_temperature_archived * (total_moles() + moved_moles) - model.temperature * (model.oxygen + model.carbon_dioxide + model.nitrogen + model.toxins + model.sleeping + model.oxagent)
		return delta_pressure * R_IDEAL_GAS_EQUATION / volume
	else
		return 0

	//Returns: FALSE if self-check failed or TRUE if check passes
/datum/gas_mixture/proc/check_turf(turf/model, atmos_adjacent_turfs = 4) //I want this proc to die a painful death
	var/delta_oxygen = (private_oxygen_archived - model.oxygen) / (atmos_adjacent_turfs + 1)
	var/delta_carbon_dioxide = (private_carbon_archived - model.carbon_dioxide) / (atmos_adjacent_turfs + 1)
	var/delta_nitrogen = (private_nitrogen_archived - model.nitrogen) / (atmos_adjacent_turfs + 1)
	var/delta_toxins = (private_plasma_archived - model.toxins) / (atmos_adjacent_turfs + 1)
	var/delta_sleeping = (private_sleeping_archived - model.sleeping) / (atmos_adjacent_turfs + 1)
	var/delta_oxagent = (private_oxagent_archived - model.oxagent) / (atmos_adjacent_turfs + 1)

	var/delta_temperature = (private_temperature_archived - model.temperature)

	if(((abs(delta_oxygen) > MINIMUM_AIR_TO_SUSPEND) && (abs(delta_oxygen) >= private_oxygen_archived * MINIMUM_AIR_RATIO_TO_SUSPEND)) \
		|| ((abs(delta_carbon_dioxide) > MINIMUM_AIR_TO_SUSPEND) && (abs(delta_carbon_dioxide) >= private_carbon_archived * MINIMUM_AIR_RATIO_TO_SUSPEND)) \
		|| ((abs(delta_nitrogen) > MINIMUM_AIR_TO_SUSPEND) && (abs(delta_nitrogen) >= private_nitrogen_archived * MINIMUM_AIR_RATIO_TO_SUSPEND)) \
		|| ((abs(delta_toxins) > MINIMUM_AIR_TO_SUSPEND) && (abs(delta_toxins) >= private_plasma_archived * MINIMUM_AIR_RATIO_TO_SUSPEND)) \
		|| ((abs(delta_sleeping) > MINIMUM_AIR_TO_SUSPEND) && (abs(delta_sleeping) >= private_sleeping_archived * MINIMUM_AIR_RATIO_TO_SUSPEND)) \
		|| ((abs(delta_oxagent) > MINIMUM_AIR_TO_SUSPEND) && (abs(delta_oxagent) >= private_oxagent_archived * MINIMUM_AIR_RATIO_TO_SUSPEND)))
		return FALSE
	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_SUSPEND)
		return FALSE

	return TRUE

/datum/gas_mixture/proc/temperature_mimic(turf/model, conduction_coefficient) //I want this proc to die a painful death
	set_dirty()
	var/delta_temperature = (private_temperature - model.temperature())
	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		var/self_heat_capacity = heat_capacity()

		if((model.heat_capacity > MINIMUM_HEAT_CAPACITY) && (self_heat_capacity > MINIMUM_HEAT_CAPACITY))
			var/heat = conduction_coefficient * delta_temperature * \
				(self_heat_capacity * model.heat_capacity / (self_heat_capacity + model.heat_capacity))

			private_temperature -= heat / self_heat_capacity

	///Performs temperature sharing calculations (via conduction) between two gas_mixtures assuming only 1 boundary length
	///Returns: new temperature of the sharer
/datum/gas_mixture/proc/temperature_share(datum/gas_mixture/sharer, conduction_coefficient)

	var/delta_temperature = (private_temperature_archived - sharer.private_temperature_archived)
	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		set_dirty()
		var/self_heat_capacity = heat_capacity_archived()
		var/sharer_heat_capacity = sharer.heat_capacity_archived()

		if((sharer_heat_capacity > MINIMUM_HEAT_CAPACITY) && (self_heat_capacity > MINIMUM_HEAT_CAPACITY))
			var/heat = conduction_coefficient*delta_temperature * \
				(self_heat_capacity * sharer_heat_capacity / (self_heat_capacity + sharer_heat_capacity))

			private_temperature -= heat / self_heat_capacity
			sharer.private_temperature += heat / sharer_heat_capacity

/datum/gas_mixture/proc/temperature_turf_share(turf/simulated/sharer, conduction_coefficient) //I want this proc to die a painful death
	var/delta_temperature = (private_temperature_archived - sharer.temperature)
	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER)
		set_dirty()
		var/self_heat_capacity = heat_capacity()

		if((sharer.heat_capacity > MINIMUM_HEAT_CAPACITY) && (self_heat_capacity > MINIMUM_HEAT_CAPACITY))
			var/heat = conduction_coefficient * delta_temperature * \
				(self_heat_capacity * sharer.heat_capacity / (self_heat_capacity + sharer.heat_capacity))

			private_temperature -= heat / self_heat_capacity
			sharer.temperature += heat / sharer.heat_capacity

	//Compares sample to self to see if within acceptable ranges that group processing may be enabled
/datum/gas_mixture/proc/compare(datum/gas_mixture/sample)
	if((abs(private_oxygen - sample.private_oxygen) > MINIMUM_AIR_TO_SUSPEND) && \
		((private_oxygen < (1 - MINIMUM_AIR_RATIO_TO_SUSPEND) * sample.private_oxygen) || (private_oxygen > (1 + MINIMUM_AIR_RATIO_TO_SUSPEND) * sample.private_oxygen)))
		return FALSE
	if((abs(private_nitrogen - sample.private_nitrogen) > MINIMUM_AIR_TO_SUSPEND) && \
		((private_nitrogen < (1 - MINIMUM_AIR_RATIO_TO_SUSPEND) * sample.private_nitrogen) || (private_nitrogen > (1 + MINIMUM_AIR_RATIO_TO_SUSPEND) * sample.private_nitrogen)))
		return FALSE
	if((abs(private_carbon - sample.private_carbon) > MINIMUM_AIR_TO_SUSPEND) && \
		((private_carbon < (1 - MINIMUM_AIR_RATIO_TO_SUSPEND) * sample.private_carbon) || (private_carbon > (1 + MINIMUM_AIR_RATIO_TO_SUSPEND) * sample.private_carbon)))
		return FALSE
	if((abs(private_plasma - sample.private_plasma) > MINIMUM_AIR_TO_SUSPEND) && \
		((private_plasma < (1 - MINIMUM_AIR_RATIO_TO_SUSPEND) * sample.private_plasma) || (private_plasma > (1 + MINIMUM_AIR_RATIO_TO_SUSPEND) * sample.private_plasma)))
		return FALSE
	if((abs(private_sleeping - sample.private_sleeping) > MINIMUM_AIR_TO_SUSPEND) && \
		((private_sleeping < (1 - MINIMUM_AIR_RATIO_TO_SUSPEND) * sample.private_sleeping) || (private_sleeping > (1 + MINIMUM_AIR_RATIO_TO_SUSPEND) * sample.private_sleeping)))
		return FALSE
	if((abs(private_oxagent - sample.private_oxagent) > MINIMUM_AIR_TO_SUSPEND) && \
		((private_oxagent < (1 - MINIMUM_AIR_RATIO_TO_SUSPEND) * sample.private_oxagent) || (private_oxagent > (1 + MINIMUM_AIR_RATIO_TO_SUSPEND) * sample.private_oxagent)))
		return FALSE

	if(total_moles() > MINIMUM_AIR_TO_SUSPEND)
		if((abs(private_temperature - sample.private_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_SUSPEND) && \
			((private_temperature < (1 - MINIMUM_TEMPERATURE_RATIO_TO_SUSPEND) * sample.private_temperature) || (private_temperature > (1 + MINIMUM_TEMPERATURE_RATIO_TO_SUSPEND) * sample.private_temperature)))
			return FALSE
	return TRUE

/datum/gas_mixture/proc/check_turf_total(turf/model) //I want this proc to die a painful death
	var/delta_oxygen = (private_oxygen - model.oxygen)
	var/delta_carbon_dioxide = (private_carbon - model.carbon_dioxide)
	var/delta_nitrogen = (private_nitrogen - model.nitrogen)
	var/delta_toxins = (private_plasma - model.toxins)
	var/delta_sleeping = (private_sleeping - model.sleeping)
	var/delta_oxagent = (private_oxagent - model.oxagent)

	var/delta_temperature = (private_temperature - model.temperature)

	if(((abs(delta_oxygen) > MINIMUM_AIR_TO_SUSPEND) && (abs(delta_oxygen) >= private_oxygen * MINIMUM_AIR_RATIO_TO_SUSPEND)) \
		|| ((abs(delta_carbon_dioxide) > MINIMUM_AIR_TO_SUSPEND) && (abs(delta_carbon_dioxide) >= private_carbon * MINIMUM_AIR_RATIO_TO_SUSPEND)) \
		|| ((abs(delta_nitrogen) > MINIMUM_AIR_TO_SUSPEND) && (abs(delta_nitrogen) >= private_nitrogen * MINIMUM_AIR_RATIO_TO_SUSPEND)) \
		|| ((abs(delta_toxins) > MINIMUM_AIR_TO_SUSPEND) && (abs(delta_toxins) >= private_plasma * MINIMUM_AIR_RATIO_TO_SUSPEND)) \
		|| ((abs(delta_sleeping) > MINIMUM_AIR_TO_SUSPEND) && (abs(delta_sleeping) >= private_sleeping * MINIMUM_AIR_RATIO_TO_SUSPEND)) \
		|| ((abs(delta_oxagent) > MINIMUM_AIR_TO_SUSPEND) && (abs(delta_oxagent) >= private_oxagent * MINIMUM_AIR_RATIO_TO_SUSPEND)))
		return FALSE
	if(abs(delta_temperature) > MINIMUM_TEMPERATURE_DELTA_TO_SUSPEND)
		return FALSE

	return TRUE

	///Performs various reactions such as combustion or fusion (LOL)
	///Returns: TRUE if any reaction took place; FALSE otherwise
/datum/gas_mixture/proc/react(atom/dump_location)
	var/reacting = FALSE //set to TRUE if a notable reaction occured (used by pipe_network)

	if((private_oxagent > MINIMUM_MOLE_COUNT) && private_temperature > 900)
		if(private_plasma > MINIMUM_HEAT_CAPACITY && private_carbon > MINIMUM_HEAT_CAPACITY)
			var/reaction_rate = min(private_carbon * 0.75, private_plasma * 0.25, private_oxagent * 0.05)

			private_carbon -= reaction_rate
			private_oxygen += reaction_rate

			private_oxagent -= reaction_rate * 0.05

			private_temperature += (reaction_rate * 20000) / heat_capacity()

			reacting = TRUE

	if((private_sleeping > MINIMUM_MOLE_COUNT) && private_temperature > N2O_DECOMPOSITION_MIN_ENERGY)
		var/energy_released = 0
		var/old_heat_capacity = heat_capacity()
		var/burned_fuel = 0
		burned_fuel = min((1 - (N2O_DECOMPOSITION_COEFFICIENT_A  / ((private_temperature + N2O_DECOMPOSITION_COEFFICIENT_C) ** 2))) * private_sleeping, private_sleeping)
		private_sleeping -= burned_fuel

		if(burned_fuel)
			energy_released += (N2O_DECOMPOSITION_ENERGY_RELEASED * burned_fuel)

			private_oxygen += burned_fuel * 0.5
			private_nitrogen += burned_fuel

			var/new_heat_capacity = heat_capacity()
			if(new_heat_capacity > MINIMUM_HEAT_CAPACITY)
				private_temperature = (private_temperature * old_heat_capacity + energy_released) / new_heat_capacity
			reacting = TRUE

	fuel_burnt = 0
	//Handle plasma burning
	if((private_plasma > MINIMUM_MOLE_COUNT) && (private_oxygen > MINIMUM_MOLE_COUNT) && private_temperature > FIRE_MINIMUM_TEMPERATURE_TO_EXIST)
		var/energy_released = 0
		var/old_heat_capacity = heat_capacity()
		var/plasma_burn_rate = 0
		var/private_oxygen_burn_rate = 0
		//more plasma released at higher temperatures
		var/private_temperature_scale = 0

		if(private_temperature > PLASMA_UPPER_TEMPERATURE)
			private_temperature_scale = 1
		else
			private_temperature_scale = (private_temperature - PLASMA_MINIMUM_BURN_TEMPERATURE) / (PLASMA_UPPER_TEMPERATURE - PLASMA_MINIMUM_BURN_TEMPERATURE)
		if(private_temperature_scale > 0)
			private_oxygen_burn_rate = OXYGEN_BURN_RATE_BASE - private_temperature_scale
			if(private_oxygen > private_plasma * PLASMA_OXYGEN_FULLBURN)
				plasma_burn_rate = (private_plasma * private_temperature_scale) / PLASMA_BURN_RATE_DELTA
			else
				plasma_burn_rate = (private_temperature_scale * (private_oxygen / PLASMA_OXYGEN_FULLBURN)) / PLASMA_BURN_RATE_DELTA
			if(plasma_burn_rate > MINIMUM_HEAT_CAPACITY)
				plasma_burn_rate = min(plasma_burn_rate, private_plasma, private_oxygen / private_oxygen_burn_rate) //Ensures matter is conserved properly
				private_plasma = QUANTIZE(private_plasma - plasma_burn_rate)
				private_oxygen = QUANTIZE(private_oxygen - (plasma_burn_rate * private_oxygen_burn_rate))
				private_carbon += plasma_burn_rate

				energy_released += FIRE_PLASMA_ENERGY_RELEASED * (plasma_burn_rate)

				fuel_burnt += (plasma_burn_rate) * (1 + private_oxygen_burn_rate)

		if(energy_released > 0)
			var/new_heat_capacity = heat_capacity()
			if(new_heat_capacity > MINIMUM_HEAT_CAPACITY)
				private_temperature = (private_temperature * old_heat_capacity + energy_released) / new_heat_capacity

		if(fuel_burnt)
			reacting = TRUE

	set_dirty()
	return reacting

///Takes the amount of the gas you want to PP as an argument
///So I don't have to do some hacky switches/defines/magic strings
///eg:
///Tox_PP = get_partial_pressure(gas_mixture.toxins)
///O2_PP = get_partial_pressure(gas_mixture.oxygen)

/datum/gas_mixture/proc/get_breath_partial_pressure(gas_pressure)
	return (gas_pressure * R_IDEAL_GAS_EQUATION * private_temperature) / BREATH_VOLUME

///inverse
/datum/gas_mixture/proc/get_true_breath_pressure(partial_pressure)
	return (partial_pressure * BREATH_VOLUME) / (R_IDEAL_GAS_EQUATION * private_temperature)

/datum/gas_mixture/proc/copy_from_milla(list/milla)
	private_oxygen = milla[MILLA_INDEX_OXYGEN]
	private_carbon = milla[MILLA_INDEX_CARBON]
	private_nitrogen = milla[MILLA_INDEX_NITROGEN]
	private_plasma = milla[MILLA_INDEX_PLASMA]
	private_sleeping = milla[MILLA_INDEX_SLEEPING]
	private_oxagent = milla[MILLA_INDEX_OXAGENT]
	innate_heat_capacity = milla[MILLA_INDEX_INNATE_HEAT_CAPACITY]
	private_temperature = milla[MILLA_INDEX_TEMPERATURE]

/proc/share_many_airs(list/mixtures)
	var/total_volume = 0
	var/total_thermal_energy = 0
	var/total_heat_capacity = 0
	var/total_oxygen = 0
	var/total_nitrogen = 0
	var/total_toxins = 0
	var/total_carbon_dioxide = 0
	var/total_sleeping = 0
	var/total_oxagent = 0

	for(var/datum/gas_mixture/G as anything in mixtures)
		total_volume += G.volume
		var/heat_capacity = G.heat_capacity()
		total_heat_capacity += heat_capacity
		total_thermal_energy += G.private_temperature * heat_capacity

		total_oxygen += G.private_oxygen
		total_nitrogen += G.private_nitrogen
		total_toxins += G.private_plasma
		total_carbon_dioxide += G.private_carbon
		total_sleeping += G.private_sleeping
		total_oxagent += G.private_oxagent

	if(total_volume > 0)
		//Calculate temperature
		var/temperature = 0

		if(total_heat_capacity > 0)
			temperature = total_thermal_energy/total_heat_capacity

		//Update individual gas_mixtures by volume ratio
		for(var/datum/gas_mixture/G as anything in mixtures)
			G.private_oxygen = total_oxygen * G.volume / total_volume
			G.private_nitrogen = total_nitrogen * G.volume / total_volume
			G.private_plasma = total_toxins * G.volume / total_volume
			G.private_carbon = total_carbon_dioxide * G.volume / total_volume
			G.private_sleeping = total_sleeping * G.volume / total_volume
			G.private_oxagent = total_oxagent * G.volume / total_volume

			G.private_temperature = temperature
			G.set_dirty()



///Mathematical proofs:
/**
get_breath_partial_pressure(gas_pp) --> gas_pp/total_moles()*breath_pp = pp
get_true_breath_pressure(pp) --> gas_pp = pp/breath_pp*total_moles()

10/20*5 = 2.5
10 = 2.5/5*20
**/

#undef SPECIFIC_HEAT_TOXIN
#undef SPECIFIC_HEAT_AIR
#undef SPECIFIC_HEAT_CDO
#undef SPECIFIC_HEAT_N2O
#undef SPECIFIC_HEAT_AGENT_B
#undef HEAT_CAPACITY_CALCULATION
#undef MINIMUM_HEAT_CAPACITY
#undef MINIMUM_MOLE_COUNT
#undef QUANTIZE

/datum/gas_mixture/bound_to_turf
	var/dirty = FALSE
	var/lastread = 0
	var/turf/bound_turf = null
	var/datum/gas_mixture/readonly/readonly = null

/datum/gas_mixture/bound_to_turf/Destroy()
	bound_turf = null
	return ..()

/datum/gas_mixture/bound_to_turf/set_dirty()
	dirty = TRUE

	if(!isnull(readonly))
		readonly.private_oxygen = private_oxygen
		readonly.private_carbon = private_carbon
		readonly.private_nitrogen = private_nitrogen
		readonly.private_plasma = private_plasma
		readonly.private_sleeping = private_sleeping
		readonly.private_oxagent = private_oxagent
		readonly.private_temperature = private_temperature

	if(istype(bound_turf, /turf/simulated))
		var/turf/simulated/S = bound_turf
		S.update_visuals()
	ASSERT(SSair.is_in_milla_safe_code())

/datum/gas_mixture/bound_to_turf/set_oxygen(value)
	private_oxygen = value
	set_dirty()

/datum/gas_mixture/bound_to_turf/set_carbon_dioxide(value)
	private_carbon = value
	set_dirty()

/datum/gas_mixture/bound_to_turf/set_nitrogen(value)
	private_nitrogen = value
	set_dirty()

/datum/gas_mixture/bound_to_turf/set_plasma(value)
	private_plasma = value
	set_dirty()

/datum/gas_mixture/bound_to_turf/set_sleeping(value)
	private_sleeping = value
	set_dirty()

/datum/gas_mixture/bound_to_turf/set_oxagent(value)
	private_oxagent = value
	set_dirty()

/datum/gas_mixture/bound_to_turf/set_temperature(value)
	private_temperature = value
	set_dirty()

/datum/gas_mixture/bound_to_turf/proc/private_unsafe_write()
	set_tile_atmos(bound_turf, oxygen = private_oxygen, carbon_dioxide = private_carbon, nitrogen = private_nitrogen, toxins = private_plasma, sleeping = private_sleeping, oxagent = private_oxagent, temperature = private_temperature)

/datum/gas_mixture/bound_to_turf/proc/get_readonly()
	if(isnull(readonly))
		readonly = new(src)
	return readonly

/// A gas mixture that should not be modified after creation.
/datum/gas_mixture/readonly

/datum/gas_mixture/readonly/New(datum/gas_mixture/parent)
	private_oxygen = parent.private_oxygen
	private_carbon = parent.private_carbon
	private_nitrogen = parent.private_nitrogen
	private_plasma = parent.private_plasma
	private_sleeping = parent.private_sleeping
	private_oxagent = parent.private_oxagent

	private_temperature = parent.private_temperature

/datum/gas_mixture/readonly/set_dirty()
	CRASH("Attempted to modify a readonly gas_mixture.")

/datum/gas_mixture/readonly/set_oxygen(value)
	CRASH("Attempted to modify a readonly gas_mixture.")

/datum/gas_mixture/readonly/set_carbon_dioxide(value)
	CRASH("Attempted to modify a readonly gas_mixture.")

/datum/gas_mixture/readonly/set_nitrogen(value)
	CRASH("Attempted to modify a readonly gas_mixture.")

/datum/gas_mixture/readonly/set_plasma(value)
	CRASH("Attempted to modify a readonly gas_mixture.")

/datum/gas_mixture/readonly/set_sleeping(value)
	CRASH("Attempted to modify a readonly gas_mixture.")

/datum/gas_mixture/readonly/set_oxagent(value)
	CRASH("Attempted to modify a readonly gas_mixture.")

/datum/gas_mixture/readonly/set_temperature(value)
	CRASH("Attempted to modify a readonly gas_mixture.")
