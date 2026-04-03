#pragma once

#include "constants.h"
#include <cmath>
#include <algorithm>

struct GasInfo {
    double specific_heat = 0.0;
    double molar_mass = 0.0;
};

// Forward declaration -- gas info array is stored in the global state
extern GasInfo g_gas_info[NUM_GASES];
extern double g_sharing_lookup[SHARING_LOOKUP_SIZE];
extern double g_min_air_to_suspend;

struct GasMixture {
    double gas[NUM_GASES] = {};
    double temperature = 0.0;
    double volume = CELL_VOLUME;

    // Cached derived values
    double total_moles = 0.0;
    double pressure = 0.0;

    // Recalculate total_moles and pressure from current gas values.
    void update_values();

    // Sum of (specific_heat[i] * moles[i]) for all gases, floored at MINIMUM_HEAT_CAPACITY.
    double heat_capacity() const;

    // temperature * heat_capacity()
    double thermal_energy() const;

    // Merge all gas from another mixture into this one, temperature-averaging by heat capacity.
    // Does not modify `other`.
    void merge(const GasMixture& other);

    // Remove `ratio` (0..1) of gas from this mixture.
    // Returns a new GasMixture containing the removed gas.
    GasMixture remove_ratio(double ratio);

    // Remove `moles` total moles proportionally. Delegates to remove_ratio.
    GasMixture remove(double moles);

    // Share gas with another mixture at the given ratio. Modifies both mixtures.
    void share_ratio(GasMixture& other, double ratio);

    // Share gas based on number of connecting tiles (uses sharing lookup table).
    // Returns true if the two mixtures are now equivalent (compare() passes).
    bool share_tiles(GasMixture& other, int connecting_tiles);

    // Share gas with an unsimulated (infinite) air source.
    // Returns true if equivalent after sharing.
    bool share_space(const GasMixture& unsim_air, int connecting_tiles);

    // Compare two mixtures for similarity (used for zone merging/edge sleeping).
    // Returns true if they are close enough to be considered equal.
    bool compare(const GasMixture& other) const;

    // Copy gas contents from another mixture, scaled by volume ratio.
    void copy_from(const GasMixture& sample);

    // Multiply all gas moles by a factor. Calls update_values().
    void multiply(double factor);

    // Add thermal energy (joules). Returns actual energy change. Clamps to min_temp.
    double add_thermal_energy(double energy, double min_temp = TCMB);

    // Molar density of a specific gas (moles / volume).
    double molar_density(int gas_id) const;

    // Total molar density (total_moles / volume).
    double total_molar_density() const;

    // Run all pure-gas reactions (cryo-O2, cryo-plasma, N2O decomposition).
    // Returns bitmask of which reactions fired (REACTION_CRYO_O2 | REACTION_CRYO_PLASMA | REACTION_N2O_DECOMP).
    int run_reactions();

    // Quantize a value to QUANTIZE_PRECISION (matches DM's QUANTIZE macro).
    static inline double quantize(double v) {
        return std::round(v / QUANTIZE_PRECISION) * QUANTIZE_PRECISION;
    }
};
