#pragma once

#include "gas_mixture.h"
#include <unordered_map>
#include <vector>
#include <cstdint>

struct Zone {
    uint32_t id = 0;
    GasMixture air;
    bool invalid = false;
    bool needs_update = false;
    uint32_t turf_count = 0;
};

enum class EdgeKind : uint8_t {
    ZoneToZone,
    ZoneToUnsimulated
};

struct Edge {
    uint32_t id = 0;
    uint32_t zone_a = 0;
    EdgeKind kind = EdgeKind::ZoneToZone;

    // For ZoneToZone edges
    uint32_t zone_b = 0;
    // For ZoneToUnsimulated edges
    GasMixture unsim_air;

    int coefficient = 0;
    int direct = 0;
    bool sleeping = true;
};

struct AtmosState {
    // Zone and edge storage
    std::unordered_map<uint32_t, Zone> zones;
    std::unordered_map<uint32_t, Edge> edges;
    std::vector<uint32_t> active_edges;  // IDs of non-sleeping edges

    // Standalone gas mixtures (for pipenet buffers, machine air_contents, etc.)
    std::unordered_map<uint32_t, GasMixture> mixtures;

    // ID allocators
    uint32_t next_edge_id = 1;
    uint32_t next_mixture_id = 1;

    // Reset all state (called by atmos_init)
    void reset();
};

// Global singleton
extern AtmosState g_state;
