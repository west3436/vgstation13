#include "byondapi.h"
#include "byondapi_cpp_wrappers.h"
#include "state.h"
#include "gas_mixture.h"
#include <cstring>
#include <algorithm>
#include <vector>

// Helper: read a float from a ByondValue arg, return as double
static inline double arg_num(ByondValue& v) {
    return static_cast<double>(ByondValue_GetNum(reinterpret_cast<CByondValue*>(&v)));
}

// Helper: return a ByondValue containing a float number
static inline ByondValueResult make_num(double val) {
    ByondValue bv;
    ByondValue_SetNum(reinterpret_cast<CByondValue*>(&bv), static_cast<float>(val));
    return bv;
}

// Helper: return null ByondValue (represents success where no data is needed)
static inline ByondValueResult make_null() {
    ByondValue bv;
    ByondValue_Clear(reinterpret_cast<CByondValue*>(&bv));
    return bv;
}

// Helper: create a BYOND list of floats from a vector of doubles
static inline ByondValueResult make_list(const std::vector<double>& values) {
    CByondValue list_val;
    if (!Byond_CreateListLen(&list_val, static_cast<u4c>(values.size()))) {
        return make_null();
    }

    for (u4c i = 0; i < static_cast<u4c>(values.size()); ++i) {
        CByondValue idx, val;
        ByondValue_SetNum(&idx, static_cast<float>(i + 1));  // 1-indexed
        ByondValue_SetNum(&val, static_cast<float>(values[i]));
        Byond_WriteListIndex(&list_val, &idx, &val);
    }

    ByondValue result;
    std::memcpy(reinterpret_cast<CByondValue*>(&result), &list_val, sizeof(CByondValue));
    return result;
}

// Helper: pack a GasMixture into a flat list of values
// Format: [gas0, gas1, ..., gas8, temperature, volume, pressure, total_moles]
static inline void pack_mixture(const GasMixture& mix, std::vector<double>& out) {
    for (int i = 0; i < NUM_GASES; ++i) {
        out.push_back(mix.gas[i]);
    }
    out.push_back(mix.temperature);
    out.push_back(mix.volume);
    out.push_back(mix.pressure);
    out.push_back(mix.total_moles);
}

// Helper: unpack gas values from ByondValue args starting at offset into a GasMixture
// Expects NUM_GASES moles + temperature + volume = 11 args
static inline void unpack_mixture_args(ByondValue args[], u4c offset, GasMixture& mix) {
    for (int i = 0; i < NUM_GASES; ++i) {
        mix.gas[i] = arg_num(args[offset + i]);
    }
    mix.temperature = arg_num(args[offset + NUM_GASES]);
    mix.volume = arg_num(args[offset + NUM_GASES + 1]);
    mix.update_values();
}

// Number of args needed to specify gas state: 9 gases + temperature + volume
constexpr u4c GAS_ARG_COUNT = NUM_GASES + 2;  // 11

// ============================================================================
// Initialization
// ============================================================================

// atmos_init() -- Reset all state
extern "C" BYOND_EXPORT CByondValue atmos_init(u4c argc, CByondValue argv[]) {
    g_state.reset();
    return reinterpret_cast<CByondValue&>(make_null());
}

// atmos_register_gas(gas_index, specific_heat, molar_mass)
extern "C" BYOND_EXPORT CByondValue atmos_register_gas(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    int idx = static_cast<int>(arg_num(args[0]));
    if (idx < 0 || idx >= NUM_GASES) return reinterpret_cast<CByondValue&>(make_null());

    g_gas_info[idx].specific_heat = arg_num(args[1]);
    g_gas_info[idx].molar_mass = arg_num(args[2]);
    return reinterpret_cast<CByondValue&>(make_null());
}

// atmos_set_constants(r_ideal, cell_volume, min_air_to_suspend, share0, share1, ..., share5)
extern "C" BYOND_EXPORT CByondValue atmos_set_constants(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    u4c i = 0;
    // We don't modify the compile-time constants, but we can override the globals
    // that control behavior. For now the key one is min_air_to_suspend and sharing table.
    if (argc > i) g_min_air_to_suspend = arg_num(args[i++]);
    for (int j = 0; j < SHARING_LOOKUP_SIZE && i < argc; ++j) {
        g_sharing_lookup[j] = arg_num(args[i++]);
    }
    return reinterpret_cast<CByondValue&>(make_null());
}

// ============================================================================
// Zone Management
// ============================================================================

// atmos_add_zone(zone_id, o2, n2, co2, plasma, n2o, cryo, volatile, oxagent, radon, temp, volume)
extern "C" BYOND_EXPORT CByondValue atmos_add_zone(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    uint32_t zone_id = static_cast<uint32_t>(arg_num(args[0]));

    Zone zone;
    zone.id = zone_id;
    unpack_mixture_args(args, 1, zone.air);
    zone.turf_count = 1;

    g_state.zones[zone_id] = zone;
    return reinterpret_cast<CByondValue&>(make_null());
}

// atmos_remove_zone(zone_id)
extern "C" BYOND_EXPORT CByondValue atmos_remove_zone(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    uint32_t zone_id = static_cast<uint32_t>(arg_num(args[0]));

    auto it = g_state.zones.find(zone_id);
    if (it != g_state.zones.end()) {
        it->second.invalid = true;
        g_state.zones.erase(it);
    }
    return reinterpret_cast<CByondValue&>(make_null());
}

// atmos_merge_zones(from_id, into_id)
extern "C" BYOND_EXPORT CByondValue atmos_merge_zones(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    uint32_t from_id = static_cast<uint32_t>(arg_num(args[0]));
    uint32_t into_id = static_cast<uint32_t>(arg_num(args[1]));

    auto from_it = g_state.zones.find(from_id);
    auto into_it = g_state.zones.find(into_id);

    if (from_it != g_state.zones.end() && into_it != g_state.zones.end()) {
        into_it->second.air.merge(from_it->second.air);
        into_it->second.turf_count += from_it->second.turf_count;
        g_state.zones.erase(from_it);
    }
    return reinterpret_cast<CByondValue&>(make_null());
}

// atmos_zone_add_turf(zone_id, o2, n2, ..., temp, volume)
extern "C" BYOND_EXPORT CByondValue atmos_zone_add_turf(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    uint32_t zone_id = static_cast<uint32_t>(arg_num(args[0]));

    auto it = g_state.zones.find(zone_id);
    if (it == g_state.zones.end()) return reinterpret_cast<CByondValue&>(make_null());

    GasMixture turf_air;
    unpack_mixture_args(args, 1, turf_air);

    it->second.air.volume += turf_air.volume;
    it->second.air.merge(turf_air);
    it->second.turf_count++;

    return reinterpret_cast<CByondValue&>(make_null());
}

// atmos_zone_remove_turf(zone_id, turf_volume) -> returns list of removed gas values
extern "C" BYOND_EXPORT CByondValue atmos_zone_remove_turf(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    uint32_t zone_id = static_cast<uint32_t>(arg_num(args[0]));
    double turf_volume = arg_num(args[1]);

    auto it = g_state.zones.find(zone_id);
    if (it == g_state.zones.end()) return reinterpret_cast<CByondValue&>(make_null());

    Zone& zone = it->second;
    double ratio = (zone.air.volume > 0.0) ? (turf_volume / zone.air.volume) : 0.0;

    // Scale down zone air proportionally
    zone.air.multiply(1.0 - ratio);
    zone.air.volume -= turf_volume;
    if (zone.air.volume < 0.0) zone.air.volume = 0.0;
    zone.turf_count--;

    // Return the removed air state
    std::vector<double> result;
    // Approximate the removed gas as (original * ratio)
    // Since we already modified the zone, reconstruct from what we know
    GasMixture removed;
    removed.temperature = zone.air.temperature;
    removed.volume = turf_volume;
    // The removed gas was ratio of the pre-removal total, but we've already subtracted.
    // The DM side handles getting the exact copy via c_copy_air(), so just return zone state.
    pack_mixture(zone.air, result);
    return reinterpret_cast<CByondValue&>(make_list(result));
}

// atmos_get_zone_air(zone_id) -> returns list [o2, n2, ..., temp, volume, pressure, total_moles]
extern "C" BYOND_EXPORT CByondValue atmos_get_zone_air(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    uint32_t zone_id = static_cast<uint32_t>(arg_num(args[0]));

    auto it = g_state.zones.find(zone_id);
    if (it == g_state.zones.end()) return reinterpret_cast<CByondValue&>(make_null());

    std::vector<double> result;
    pack_mixture(it->second.air, result);
    return reinterpret_cast<CByondValue&>(make_list(result));
}

// atmos_set_zone_air(zone_id, o2, n2, ..., temp, volume)
extern "C" BYOND_EXPORT CByondValue atmos_set_zone_air(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    uint32_t zone_id = static_cast<uint32_t>(arg_num(args[0]));

    auto it = g_state.zones.find(zone_id);
    if (it == g_state.zones.end()) return reinterpret_cast<CByondValue&>(make_null());

    unpack_mixture_args(args, 1, it->second.air);
    return reinterpret_cast<CByondValue&>(make_null());
}

// ============================================================================
// Edge Management
// ============================================================================

// atmos_add_edge(type_num, zone_a_id, zone_b_id_or_gas_args...)
// type_num: 0 = zone-to-zone, 1 = zone-to-unsimulated
// For zone: (0, zone_a, zone_b) -> returns edge_id
// For unsim: (1, zone_a, o2, n2, ..., temp, volume) -> returns edge_id
extern "C" BYOND_EXPORT CByondValue atmos_add_edge(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    int type = static_cast<int>(arg_num(args[0]));
    uint32_t zone_a = static_cast<uint32_t>(arg_num(args[1]));

    Edge edge;
    edge.id = g_state.next_edge_id++;
    edge.zone_a = zone_a;

    if (type == 0) {
        // Zone-to-zone
        edge.kind = EdgeKind::ZoneToZone;
        edge.zone_b = static_cast<uint32_t>(arg_num(args[2]));
    } else {
        // Zone-to-unsimulated
        edge.kind = EdgeKind::ZoneToUnsimulated;
        edge.zone_b = 0;
        unpack_mixture_args(args, 2, edge.unsim_air);
    }

    edge.sleeping = true;
    edge.coefficient = 0;
    edge.direct = 0;

    g_state.edges[edge.id] = edge;
    return reinterpret_cast<CByondValue&>(make_num(static_cast<double>(edge.id)));
}

// atmos_remove_edge(edge_id)
extern "C" BYOND_EXPORT CByondValue atmos_remove_edge(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    uint32_t edge_id = static_cast<uint32_t>(arg_num(args[0]));

    auto it = g_state.edges.find(edge_id);
    if (it != g_state.edges.end()) {
        // Remove from active edges if present
        if (!it->second.sleeping) {
            auto& ae = g_state.active_edges;
            ae.erase(std::remove(ae.begin(), ae.end(), edge_id), ae.end());
        }
        g_state.edges.erase(it);
    }
    return reinterpret_cast<CByondValue&>(make_null());
}

// atmos_edge_add_conn(edge_id, is_direct)
extern "C" BYOND_EXPORT CByondValue atmos_edge_add_conn(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    uint32_t edge_id = static_cast<uint32_t>(arg_num(args[0]));
    bool is_direct = arg_num(args[1]) != 0.0;

    auto it = g_state.edges.find(edge_id);
    if (it != g_state.edges.end()) {
        it->second.coefficient++;
        if (is_direct) it->second.direct++;
    }
    return reinterpret_cast<CByondValue&>(make_null());
}

// atmos_edge_remove_conn(edge_id, was_direct)
extern "C" BYOND_EXPORT CByondValue atmos_edge_remove_conn(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    uint32_t edge_id = static_cast<uint32_t>(arg_num(args[0]));
    bool was_direct = arg_num(args[1]) != 0.0;

    auto it = g_state.edges.find(edge_id);
    if (it != g_state.edges.end()) {
        it->second.coefficient--;
        if (was_direct) it->second.direct--;
        if (it->second.coefficient <= 0) {
            // Edge should be erased
            if (!it->second.sleeping) {
                auto& ae = g_state.active_edges;
                ae.erase(std::remove(ae.begin(), ae.end(), edge_id), ae.end());
            }
            g_state.edges.erase(it);
        }
    }
    return reinterpret_cast<CByondValue&>(make_null());
}

// atmos_edge_set_sleeping(edge_id, sleeping)
extern "C" BYOND_EXPORT CByondValue atmos_edge_set_sleeping(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    uint32_t edge_id = static_cast<uint32_t>(arg_num(args[0]));
    bool sleeping = arg_num(args[1]) != 0.0;

    auto it = g_state.edges.find(edge_id);
    if (it != g_state.edges.end()) {
        bool was_sleeping = it->second.sleeping;
        it->second.sleeping = sleeping;

        if (was_sleeping && !sleeping) {
            // Waking up: add to active list
            g_state.active_edges.push_back(edge_id);
        } else if (!was_sleeping && sleeping) {
            // Going to sleep: remove from active list
            auto& ae = g_state.active_edges;
            ae.erase(std::remove(ae.begin(), ae.end(), edge_id), ae.end());
        }
    }
    return reinterpret_cast<CByondValue&>(make_null());
}

// ============================================================================
// Tick Processing
// ============================================================================

// atmos_tick_edges() -> flat list of results
// Each result group (EDGE_RESULT_STRIDE values):
//   [edge_id, differential, equiv, merge_flag,
//    za_id, za_gas0..8, za_temp, za_volume, za_pressure, za_total_moles,
//    zb_id, zb_gas0..8, zb_temp, zb_volume, zb_pressure, zb_total_moles]
// EDGE_RESULT_STRIDE = 4 + 2*(1+13) = 32
extern "C" BYOND_EXPORT CByondValue atmos_tick_edges(u4c argc, CByondValue argv[]) {
    std::vector<double> results;

    // Process a snapshot of active edges (edges may be removed during processing)
    std::vector<uint32_t> edges_to_process = g_state.active_edges;

    for (uint32_t edge_id : edges_to_process) {
        auto it = g_state.edges.find(edge_id);
        if (it == g_state.edges.end()) continue;

        Edge& edge = it->second;
        if (edge.sleeping) continue;

        auto zone_a_it = g_state.zones.find(edge.zone_a);
        if (zone_a_it == g_state.zones.end()) continue;

        Zone& za = zone_a_it->second;
        if (za.invalid) continue;

        bool equiv = false;
        double differential = 0.0;
        uint32_t zb_id = 0;
        GasMixture* zb_air_ptr = nullptr;

        if (edge.kind == EdgeKind::ZoneToZone) {
            auto zone_b_it = g_state.zones.find(edge.zone_b);
            if (zone_b_it == g_state.zones.end()) continue;

            Zone& zb = zone_b_it->second;
            if (zb.invalid) continue;

            equiv = za.air.share_tiles(zb.air, edge.coefficient);
            differential = za.air.pressure - zb.air.pressure;
            zb_id = zb.id;
            zb_air_ptr = &zb.air;
        } else {
            equiv = za.air.share_space(edge.unsim_air, edge.coefficient);
            differential = za.air.pressure - edge.unsim_air.pressure;

            if (equiv) {
                za.air.copy_from(edge.unsim_air);
            }
            zb_air_ptr = &edge.unsim_air;
        }

        bool merge_flag = false;
        if (equiv && edge.kind == EdgeKind::ZoneToZone && edge.direct > 0) {
            merge_flag = true;
        }

        // Header: edge_id, differential, equiv, merge_flag
        results.push_back(static_cast<double>(edge_id));
        results.push_back(differential);
        results.push_back(equiv ? 1.0 : 0.0);
        results.push_back(merge_flag ? 1.0 : 0.0);
        // Zone A air inline: id, gas0..8, temp, volume, pressure, total_moles
        results.push_back(static_cast<double>(za.id));
        pack_mixture(za.air, results);
        // Zone B air inline: id, gas0..8, temp, volume, pressure, total_moles
        results.push_back(static_cast<double>(zb_id));
        pack_mixture(*zb_air_ptr, results);
    }

    return reinterpret_cast<CByondValue&>(make_list(results));
}

// atmos_bulk_set_zone_air(count, [zone_id, gas0..8, temp, volume] * count)
// Sets multiple zone airs in a single call. Returns null.
extern "C" BYOND_EXPORT CByondValue atmos_bulk_set_zone_air(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    int count = static_cast<int>(arg_num(args[0]));

    u4c offset = 1;
    constexpr u4c PER_ZONE = 1 + GAS_ARG_COUNT;  // zone_id + 11 gas args
    for (int n = 0; n < count; ++n) {
        uint32_t zone_id = static_cast<uint32_t>(arg_num(args[offset]));
        auto it = g_state.zones.find(zone_id);
        if (it != g_state.zones.end()) {
            unpack_mixture_args(args, offset + 1, it->second.air);
        }
        offset += PER_ZONE;
    }
    return reinterpret_cast<CByondValue&>(make_null());
}

// atmos_tick_zones() -> flat list of results
// Each result group (ZONE_RESULT_STRIDE = 5 values):
//   [zone_id, reactions_occurred, graphic_flags, temperature, pressure]
// Runs gas reactions on every zone and computes graphic overlay flags.
extern "C" BYOND_EXPORT CByondValue atmos_tick_zones(u4c argc, CByondValue argv[]) {
    std::vector<double> results;

    for (auto& [zone_id, zone] : g_state.zones) {
        if (zone.invalid) continue;

        int reactions = zone.air.run_reactions();

        // Compute graphic overlay flags
        int graphic_flags = 0;
        if (zone.air.molar_density(GAS_IDX_PLASMA) > OVERLAY_LIMIT_PLASMA)
            graphic_flags |= SHOW_PLASMA;
        if (zone.air.molar_density(GAS_IDX_N2O) > OVERLAY_LIMIT_N2O)
            graphic_flags |= SHOW_SLEEPING;
        if (zone.air.molar_density(GAS_IDX_CRYO) > OVERLAY_LIMIT_CRYO)
            graphic_flags |= SHOW_CRYOTHEUM;

        // Only report zones where something happened
        if (reactions || graphic_flags) {
            results.push_back(static_cast<double>(zone_id));
            results.push_back(reactions > 0 ? 1.0 : 0.0);
            results.push_back(static_cast<double>(graphic_flags));
            results.push_back(zone.air.temperature);
            results.push_back(zone.air.pressure);
        }
    }

    return reinterpret_cast<CByondValue&>(make_list(results));
}

// atmos_batch_reconcile(count, [gas0..gas8, temp, volume] * count) -> result list
// Takes N inline-packed gas mixtures, merges all into a transient, runs reactions,
// returns equalized state: [reacted, gas0..gas8, temp, total_volume, pressure, total_moles]
extern "C" BYOND_EXPORT CByondValue atmos_batch_reconcile(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    int count = static_cast<int>(arg_num(args[0]));

    if (count <= 0)
        return reinterpret_cast<CByondValue&>(make_null());

    // Build transient mixture by merging all inputs
    GasMixture transient;
    transient.temperature = 0.0;
    transient.volume = 0.0;
    for (int i = 0; i < NUM_GASES; ++i) transient.gas[i] = 0.0;

    u4c offset = 1;
    for (int n = 0; n < count; ++n) {
        GasMixture seg;
        unpack_mixture_args(args, offset, seg);  // reads 11 args: gas0..gas8, temp, volume
        transient.volume += seg.volume;
        transient.merge(seg);
        offset += GAS_ARG_COUNT;
    }

    transient.update_values();

    double reacted = 0.0;
    if (transient.volume > 0.0) {
        int rxn = transient.run_reactions();
        if (rxn) reacted = 1.0;
        transient.update_values();
    }

    // Pack result: [reacted, gas0..gas8, temp, volume, pressure, total_moles]
    std::vector<double> result;
    result.push_back(reacted);
    pack_mixture(transient, result);  // appends gas0..gas8, temp, volume, pressure, total_moles
    return reinterpret_cast<CByondValue&>(make_list(result));
}

// ============================================================================
// Standalone Gas Mixture Operations
// ============================================================================

// atmos_mix_create(volume, o2, n2, ..., temp) -> returns mixture_id
extern "C" BYOND_EXPORT CByondValue atmos_mix_create(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);

    GasMixture mix;
    mix.volume = arg_num(args[0]);
    for (int i = 0; i < NUM_GASES; ++i) {
        mix.gas[i] = arg_num(args[1 + i]);
    }
    mix.temperature = arg_num(args[1 + NUM_GASES]);
    mix.update_values();

    uint32_t id = g_state.next_mixture_id++;
    g_state.mixtures[id] = mix;
    return reinterpret_cast<CByondValue&>(make_num(static_cast<double>(id)));
}

// atmos_mix_destroy(mixture_id)
extern "C" BYOND_EXPORT CByondValue atmos_mix_destroy(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    uint32_t id = static_cast<uint32_t>(arg_num(args[0]));
    g_state.mixtures.erase(id);
    return reinterpret_cast<CByondValue&>(make_null());
}

// atmos_mix_get(mixture_id) -> list [o2, n2, ..., temp, volume, pressure, total_moles]
extern "C" BYOND_EXPORT CByondValue atmos_mix_get(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    uint32_t id = static_cast<uint32_t>(arg_num(args[0]));

    auto it = g_state.mixtures.find(id);
    if (it == g_state.mixtures.end()) return reinterpret_cast<CByondValue&>(make_null());

    std::vector<double> result;
    pack_mixture(it->second, result);
    return reinterpret_cast<CByondValue&>(make_list(result));
}

// atmos_mix_set(mixture_id, o2, n2, ..., temp, volume)
extern "C" BYOND_EXPORT CByondValue atmos_mix_set(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    uint32_t id = static_cast<uint32_t>(arg_num(args[0]));

    auto it = g_state.mixtures.find(id);
    if (it == g_state.mixtures.end()) return reinterpret_cast<CByondValue&>(make_null());

    unpack_mixture_args(args, 1, it->second);
    return reinterpret_cast<CByondValue&>(make_null());
}

// atmos_mix_merge(target_id, source_id)
extern "C" BYOND_EXPORT CByondValue atmos_mix_merge(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    uint32_t target_id = static_cast<uint32_t>(arg_num(args[0]));
    uint32_t source_id = static_cast<uint32_t>(arg_num(args[1]));

    auto target_it = g_state.mixtures.find(target_id);
    auto source_it = g_state.mixtures.find(source_id);
    if (target_it == g_state.mixtures.end() || source_it == g_state.mixtures.end()) {
        return reinterpret_cast<CByondValue&>(make_null());
    }

    target_it->second.merge(source_it->second);
    return reinterpret_cast<CByondValue&>(make_null());
}

// atmos_mix_remove_ratio(mixture_id, ratio) -> list of removed gas values
extern "C" BYOND_EXPORT CByondValue atmos_mix_remove_ratio(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    uint32_t id = static_cast<uint32_t>(arg_num(args[0]));
    double ratio = arg_num(args[1]);

    auto it = g_state.mixtures.find(id);
    if (it == g_state.mixtures.end()) return reinterpret_cast<CByondValue&>(make_null());

    GasMixture removed = it->second.remove_ratio(ratio);

    std::vector<double> result;
    pack_mixture(removed, result);
    return reinterpret_cast<CByondValue&>(make_list(result));
}

// atmos_mix_heat_capacity(mixture_id) -> number
extern "C" BYOND_EXPORT CByondValue atmos_mix_heat_capacity(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    uint32_t id = static_cast<uint32_t>(arg_num(args[0]));

    auto it = g_state.mixtures.find(id);
    if (it == g_state.mixtures.end()) return reinterpret_cast<CByondValue&>(make_num(MINIMUM_HEAT_CAPACITY));

    return reinterpret_cast<CByondValue&>(make_num(it->second.heat_capacity()));
}

// atmos_mix_compare(id_a, id_b) -> 1.0 if equivalent, 0.0 if not
extern "C" BYOND_EXPORT CByondValue atmos_mix_compare(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    uint32_t id_a = static_cast<uint32_t>(arg_num(args[0]));
    uint32_t id_b = static_cast<uint32_t>(arg_num(args[1]));

    auto a_it = g_state.mixtures.find(id_a);
    auto b_it = g_state.mixtures.find(id_b);
    if (a_it == g_state.mixtures.end() || b_it == g_state.mixtures.end()) {
        return reinterpret_cast<CByondValue&>(make_num(0.0));
    }

    bool result = a_it->second.compare(b_it->second);
    return reinterpret_cast<CByondValue&>(make_num(result ? 1.0 : 0.0));
}

// atmos_mix_share_ratio(id_a, id_b, ratio)
extern "C" BYOND_EXPORT CByondValue atmos_mix_share_ratio(u4c argc, CByondValue argv[]) {
    ByondValue* args = reinterpret_cast<ByondValue*>(argv);
    uint32_t id_a = static_cast<uint32_t>(arg_num(args[0]));
    uint32_t id_b = static_cast<uint32_t>(arg_num(args[1]));
    double ratio = arg_num(args[2]);

    auto a_it = g_state.mixtures.find(id_a);
    auto b_it = g_state.mixtures.find(id_b);
    if (a_it == g_state.mixtures.end() || b_it == g_state.mixtures.end()) {
        return reinterpret_cast<CByondValue&>(make_null());
    }

    a_it->second.share_ratio(b_it->second, ratio);
    return reinterpret_cast<CByondValue&>(make_null());
}

// ============================================================================
// Debug / Utility
// ============================================================================

// atmos_get_version() -> returns version string as a number (for simple version checking)
extern "C" BYOND_EXPORT CByondValue atmos_get_version(u4c argc, CByondValue argv[]) {
    // Version 3.0 = Phase 3 (all phases complete)
    return reinterpret_cast<CByondValue&>(make_num(3.0));
}

// atmos_zone_count() -> number of zones
extern "C" BYOND_EXPORT CByondValue atmos_zone_count(u4c argc, CByondValue argv[]) {
    return reinterpret_cast<CByondValue&>(make_num(static_cast<double>(g_state.zones.size())));
}

// atmos_edge_count() -> number of edges
extern "C" BYOND_EXPORT CByondValue atmos_edge_count(u4c argc, CByondValue argv[]) {
    return reinterpret_cast<CByondValue&>(make_num(static_cast<double>(g_state.edges.size())));
}

// atmos_active_edge_count() -> number of active (non-sleeping) edges
extern "C" BYOND_EXPORT CByondValue atmos_active_edge_count(u4c argc, CByondValue argv[]) {
    return reinterpret_cast<CByondValue&>(make_num(static_cast<double>(g_state.active_edges.size())));
}
