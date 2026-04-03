#pragma once

// Number of gas types tracked by the simulation.
// Order must match registration order from DM at init.
constexpr int NUM_GASES = 9;

// Default atmospheric constants (overridden by DM at init via atmos_set_constants)
constexpr double R_IDEAL_GAS_EQUATION = 8.314;  // kPa*L / (K*mol)
constexpr double CELL_VOLUME = 2500.0;           // liters per turf cell
constexpr double ONE_ATMOSPHERE = 101.325;       // kPa
constexpr double T0C = 273.15;                   // 0 degrees C in Kelvin
constexpr double T20C = 293.15;                  // 20 degrees C in Kelvin
constexpr double TCMB = 2.73;                    // cosmic microwave background
constexpr double MINIMUM_HEAT_CAPACITY = 0.0003;

// Similarity thresholds for compare() -- determines when zones can merge/sleep
constexpr double MINIMUM_TEMPERATURE_DELTA_TO_SUSPEND = 4.0;
constexpr double MINIMUM_TEMPERATURE_RATIO_TO_SUSPEND = 0.012;
constexpr double MINIMUM_PRESSURE_DELTA_TO_SUSPEND = 0.1;
constexpr double MINIMUM_PRESSURE_RATIO_TO_SUSPEND = 0.05;
constexpr double MINIMUM_AIR_RATIO_TO_SUSPEND = 0.05;

// Derived: minimum molar density delta to suspend
// MOLES_CELLSTANDARD / CELL_VOLUME * MINIMUM_AIR_RATIO_TO_SUSPEND
// ~ 103.934 / 2500 * 0.05 ~ 0.002079
constexpr double MINIMUM_AIR_TO_SUSPEND_DEFAULT = 0.002079;

// Sharing lookup table: proportion of gas shared per tick by number of connecting tiles
constexpr int SHARING_LOOKUP_SIZE = 6;
constexpr double SHARING_LOOKUP_DEFAULT[SHARING_LOOKUP_SIZE] = {
    0.30, 0.40, 0.48, 0.54, 0.60, 0.66
};

// ============================================================================
// Gas indices (must match DM registration order in atmos_native_init)
// ============================================================================
constexpr int GAS_IDX_O2       = 0;
constexpr int GAS_IDX_N2       = 1;
constexpr int GAS_IDX_CO2      = 2;
constexpr int GAS_IDX_PLASMA   = 3;
constexpr int GAS_IDX_N2O      = 4;
constexpr int GAS_IDX_CRYO     = 5;
constexpr int GAS_IDX_VOLATILE = 6;
constexpr int GAS_IDX_OXAGENT  = 7;
constexpr int GAS_IDX_RADON    = 8;

// ============================================================================
// Reaction constants
// ============================================================================

// Visibility thresholds (moles in a standard cell)
constexpr double MOLES_PLASMA_VISIBLE    = 0.7;
constexpr double MOLES_CRYOTHEUM_VISIBLE = 0.7;

// QUANTIZE precision (matches DM's round(variable, 0.0001))
constexpr double QUANTIZE_PRECISION = 0.0001;

// Cryotheum-Oxygen reaction
constexpr double CRYO_O2_TEMP_LOSS        = -170000.0;  // J per mole O2 consumed
constexpr double CRYO_O2_MIN_TEMP         = 242.8952;   // K minimum temperature
constexpr double CRYO_O2_CATALYST_RATIO   = 50.0;       // cryo:O2 ratio for peak efficiency
constexpr double CRYO_O2_CONSUMPTION_RATE = 0.0015;     // fraction of O2 consumed per tick

// Cryotheum-Plasma catalyzed reaction
constexpr double CRYO_PLASMA_MIN_TEMP         = 0.1;       // K minimum temperature
constexpr double CRYO_PLASMA_BASE_LOSS        = -240000.0; // J per mole cryo consumed (base)
constexpr double CRYO_PLASMA_CATALYST_RATIO   = 10.0;      // plasma:cryo ratio for peak
constexpr double CRYO_PLASMA_CONSUMPTION_RATE = 0.2;       // fraction of cryo consumed per tick

// N2O thermal decomposition
constexpr double N2O_DECOMP_MIN_TEMP = 573.15;  // 300 + T0C (K)
constexpr double N2O_DECOMP_ENERGY   = 82050.0; // J per mole N2O decomposed

// ============================================================================
// Graphic overlay flags (must match DM's __DEFINES/gases.dm)
// ============================================================================
constexpr int SHOW_PLASMA   = 1;
constexpr int SHOW_SLEEPING = 2;
constexpr int SHOW_CRYOTHEUM = 4;

// Overlay density thresholds (molar_density above which gas is visible)
// From XGM_gases.dm: plasma = MOLES_PLASMA_VISIBLE/CELL_VOLUME, N2O = 1/CELL_VOLUME, cryo = MOLES_CRYOTHEUM_VISIBLE/CELL_VOLUME
constexpr double OVERLAY_LIMIT_PLASMA = MOLES_PLASMA_VISIBLE / CELL_VOLUME;
constexpr double OVERLAY_LIMIT_N2O    = 1.0 / CELL_VOLUME;
constexpr double OVERLAY_LIMIT_CRYO   = MOLES_CRYOTHEUM_VISIBLE / CELL_VOLUME;

// Reaction result bitmask
constexpr int REACTION_CRYO_O2     = 1;
constexpr int REACTION_CRYO_PLASMA = 2;
constexpr int REACTION_N2O_DECOMP  = 4;
