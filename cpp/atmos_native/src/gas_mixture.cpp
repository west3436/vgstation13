#include "gas_mixture.h"
#include <cstring>

// These are defined in state.cpp and initialized by atmos_register_gas / atmos_set_constants
GasInfo g_gas_info[NUM_GASES] = {};
double g_sharing_lookup[SHARING_LOOKUP_SIZE] = {0.30, 0.40, 0.48, 0.54, 0.60, 0.66};
double g_min_air_to_suspend = MINIMUM_AIR_TO_SUSPEND_DEFAULT;

void GasMixture::update_values() {
    total_moles = 0.0;
    for (int i = 0; i < NUM_GASES; ++i) {
        if (gas[i] > 0.0) {
            total_moles += gas[i];
        } else {
            gas[i] = 0.0;  // Cull negative/zero values
        }
    }
    if (volume > 0.0) {
        pressure = total_moles * R_IDEAL_GAS_EQUATION * temperature / volume;
    } else {
        pressure = 0.0;
    }
}

double GasMixture::heat_capacity() const {
    double hc = 0.0;
    for (int i = 0; i < NUM_GASES; ++i) {
        hc += g_gas_info[i].specific_heat * gas[i];
    }
    return std::max(MINIMUM_HEAT_CAPACITY, hc);
}

double GasMixture::thermal_energy() const {
    return temperature * heat_capacity();
}

void GasMixture::merge(const GasMixture& other) {
    double self_hc = heat_capacity();
    double other_hc = other.heat_capacity();
    double combined_hc = self_hc + other_hc;

    if (combined_hc > 0.0) {
        temperature = (temperature * self_hc + other.temperature * other_hc) / combined_hc;
    }

    for (int i = 0; i < NUM_GASES; ++i) {
        gas[i] += other.gas[i];
    }

    update_values();
}

GasMixture GasMixture::remove_ratio(double ratio) {
    GasMixture removed;

    if (ratio <= 0.0 || total_moles <= 0.0) {
        removed.update_values();
        return removed;
    }

    ratio = std::min(ratio, 1.0);

    for (int i = 0; i < NUM_GASES; ++i) {
        double moles = gas[i] * ratio;
        gas[i] -= moles;
        removed.gas[i] = moles;
    }

    removed.temperature = temperature;
    removed.update_values();
    update_values();

    return removed;
}

GasMixture GasMixture::remove(double moles) {
    if (total_moles <= 0.0) {
        GasMixture empty;
        empty.update_values();
        return empty;
    }
    moles = std::min(moles, total_moles);
    double ratio = moles / total_moles;
    return remove_ratio(ratio);
}

void GasMixture::share_ratio(GasMixture& other, double ratio) {
    double total_volume = volume + other.volume;
    if (total_volume <= 0.0) return;

    // Remove proportional amounts from each, then swap and merge
    GasMixture from_self = remove_ratio(ratio * other.volume / total_volume);
    GasMixture from_other = other.remove_ratio(ratio * volume / total_volume);

    merge(from_other);
    other.merge(from_self);
}

bool GasMixture::share_tiles(GasMixture& other, int connecting_tiles) {
    int idx = std::min(connecting_tiles, SHARING_LOOKUP_SIZE) - 1;
    if (idx < 0) idx = 0;
    double ratio = g_sharing_lookup[idx];

    share_ratio(other, ratio);
    return compare(other);
}

bool GasMixture::share_space(const GasMixture& unsim_air, int connecting_tiles) {
    // Create a copy of the unsimulated air with inflated volume
    GasMixture sharer;
    sharer.volume = unsim_air.volume + volume + 3.0 * CELL_VOLUME;

    // Copy gas from unsimulated air, scaled by volume ratio
    sharer.copy_from(unsim_air);

    return share_tiles(sharer, connecting_tiles);
}

// Helper: check if two values fail the similarity test
static inline bool fail_similarity(double own, double sample, double absolute, double relative) {
    return (std::abs(own - sample) > absolute) &&
           ((own < (1.0 - relative) * sample) || (own > (1.0 + relative) * sample));
}

bool GasMixture::compare(const GasMixture& other) const {
    // Temperature check
    if (fail_similarity(temperature, other.temperature,
                        MINIMUM_TEMPERATURE_DELTA_TO_SUSPEND,
                        MINIMUM_TEMPERATURE_RATIO_TO_SUSPEND)) {
        return false;
    }

    // Pressure check
    if (fail_similarity(pressure, other.pressure,
                        MINIMUM_PRESSURE_DELTA_TO_SUSPEND,
                        MINIMUM_PRESSURE_RATIO_TO_SUSPEND)) {
        return false;
    }

    // Per-gas molar density check
    for (int i = 0; i < NUM_GASES; ++i) {
        double own_density = molar_density(i);
        double other_density = other.molar_density(i);
        if (fail_similarity(own_density, other_density,
                            g_min_air_to_suspend,
                            MINIMUM_AIR_RATIO_TO_SUSPEND)) {
            return false;
        }
    }

    return true;
}

void GasMixture::copy_from(const GasMixture& sample) {
    if (sample.volume <= 0.0) return;

    for (int i = 0; i < NUM_GASES; ++i) {
        gas[i] = sample.gas[i];
    }
    temperature = sample.temperature;

    // Scale by volume ratio
    double factor = volume / sample.volume;
    for (int i = 0; i < NUM_GASES; ++i) {
        gas[i] *= factor;
    }

    update_values();
}

void GasMixture::multiply(double factor) {
    for (int i = 0; i < NUM_GASES; ++i) {
        gas[i] *= factor;
    }
    update_values();
}

double GasMixture::add_thermal_energy(double energy, double min_temp) {
    if (total_moles == 0.0) return 0.0;

    double hc = heat_capacity();
    if (energy < 0.0) {
        if (temperature <= min_temp) return 0.0;
        energy = std::max(energy, (min_temp - temperature) * hc);
    }
    temperature += energy / hc;
    return energy;
}

double GasMixture::molar_density(int gas_id) const {
    if (volume <= 0.0) return 0.0;
    return gas[gas_id] / volume;
}

double GasMixture::total_molar_density() const {
    if (volume <= 0.0) return 0.0;
    return total_moles / volume;
}

int GasMixture::run_reactions() {
    // Phase 1: Check which reactions are possible
    bool cryo_o2 = gas[GAS_IDX_CRYO] > 0.0 &&
        quantize(molar_density(GAS_IDX_CRYO)) * CELL_VOLUME > MOLES_CRYOTHEUM_VISIBLE &&
        gas[GAS_IDX_O2] > 0.0;

    bool cryo_plasma = gas[GAS_IDX_CRYO] > 0.0 &&
        quantize(molar_density(GAS_IDX_PLASMA)) * CELL_VOLUME > MOLES_PLASMA_VISIBLE;

    bool n2o_decomp = temperature >= N2O_DECOMP_MIN_TEMP && gas[GAS_IDX_N2O] > 0.0;

    if (!cryo_o2 && !cryo_plasma && !n2o_decomp)
        return 0;

    // Phase 2: Collect requested amounts per gas per reaction
    // requested[reaction_idx][gas_idx] = moles requested
    double requested[3][NUM_GASES] = {};
    int active[3];
    int active_count = 0;

    if (cryo_o2) {
        double catalyst = std::min(1.0, gas[GAS_IDX_CRYO] / gas[GAS_IDX_O2] * CRYO_O2_CATALYST_RATIO);
        requested[0][GAS_IDX_O2] = catalyst * gas[GAS_IDX_O2] * CRYO_O2_CONSUMPTION_RATE;
        active[active_count++] = 0;
    }

    if (cryo_plasma) {
        double catalyst = std::min(1.0, gas[GAS_IDX_PLASMA] / gas[GAS_IDX_CRYO] * CRYO_PLASMA_CATALYST_RATIO);
        requested[1][GAS_IDX_CRYO] = catalyst * gas[GAS_IDX_CRYO] * CRYO_PLASMA_CONSUMPTION_RATE;
        active[active_count++] = 1;
    }

    if (n2o_decomp) {
        double cratio = (temperature - 300.0 - T0C) / 900.0;
        cratio *= 1.0 - (1.0 / ((pressure / ONE_ATMOSPHERE) + 1.0));
        cratio = std::min(0.95, std::pow(std::max(0.0, cratio), 0.5));
        requested[2][GAS_IDX_N2O] = gas[GAS_IDX_N2O] * cratio;
        active[active_count++] = 2;
    }

    // Phase 3: Scale down if multiple reactions compete for same gas
    if (active_count > 1) {
        double total_req[NUM_GASES] = {};
        for (int a = 0; a < active_count; ++a) {
            for (int g = 0; g < NUM_GASES; ++g) {
                total_req[g] += requested[active[a]][g];
            }
        }

        double worst = 1.0;
        for (int g = 0; g < NUM_GASES; ++g) {
            if (total_req[g] > 0.0 && gas[g] > 0.0) {
                worst = std::max(worst, total_req[g] / gas[g]);
            }
        }

        if (worst > 1.0) {
            for (int a = 0; a < active_count; ++a) {
                for (int g = 0; g < NUM_GASES; ++g) {
                    requested[active[a]][g] /= worst;
                }
            }
        }
    }

    // Phase 4: Execute reactions
    int result = 0;

    if (cryo_o2) {
        double o2_consumed = requested[0][GAS_IDX_O2];
        gas[GAS_IDX_O2] = std::max(0.0, gas[GAS_IDX_O2] - o2_consumed);
        add_thermal_energy(o2_consumed * CRYO_O2_TEMP_LOSS, CRYO_O2_MIN_TEMP);
        result |= REACTION_CRYO_O2;
    }

    if (cryo_plasma) {
        double cryo_consumed = requested[1][GAS_IDX_CRYO];
        gas[GAS_IDX_CRYO] = std::max(0.0, gas[GAS_IDX_CRYO] - cryo_consumed);
        double distance = std::max(0.00001, temperature - CRYO_PLASMA_MIN_TEMP);
        double cooling = std::min(1.0, 80.0 / distance) + std::min(5.0, 50.0 / distance);
        add_thermal_energy(cooling * cryo_consumed * CRYO_PLASMA_BASE_LOSS, CRYO_PLASMA_MIN_TEMP);
        result |= REACTION_CRYO_PLASMA;
    }

    if (n2o_decomp) {
        double n2o_consumed = requested[2][GAS_IDX_N2O];
        gas[GAS_IDX_O2] += n2o_consumed * 0.5;
        gas[GAS_IDX_N2] += n2o_consumed;
        gas[GAS_IDX_N2O] = std::max(0.0, gas[GAS_IDX_N2O] - n2o_consumed);
        add_thermal_energy(n2o_consumed * N2O_DECOMP_ENERGY);
        result |= REACTION_N2O_DECOMP;
    }

    update_values();
    return result;
}
