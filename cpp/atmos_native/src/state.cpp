#include "state.h"

AtmosState g_state;

void AtmosState::reset() {
    zones.clear();
    edges.clear();
    active_edges.clear();
    mixtures.clear();
    next_edge_id = 1;
    next_mixture_id = 1;

    // Reset gas info to defaults
    for (int i = 0; i < NUM_GASES; ++i) {
        g_gas_info[i] = {};
    }

    // Reset sharing lookup to defaults
    for (int i = 0; i < SHARING_LOOKUP_SIZE; ++i) {
        g_sharing_lookup[i] = SHARING_LOOKUP_DEFAULT[i];
    }

    g_min_air_to_suspend = MINIMUM_AIR_TO_SUSPEND_DEFAULT;
}
