/datum/unit_test/vlevel_default_fields
	name = "VLEVEL: default fields on new vlevel"

/datum/unit_test/vlevel_default_fields/start()
	var/datum/virtual_z/v = new()
	if(v.floor != 1)
		fail("Expected floor=1, got [v.floor]")
		return
	if(v.vlevel_above != null)
		fail("Expected vlevel_above=null")
		return
	if(v.vlevel_below != null)
		fail("Expected vlevel_below=null")
		return
	if(v.group_anchor != v)
		fail("Expected group_anchor=self")
		return
	// All assertions passed

/datum/unit_test/vlevel_group_state_routing
	name = "VLEVEL: group state reads through anchor"

/datum/unit_test/vlevel_group_state_routing/start()
	var/datum/virtual_z/anchor = new()
	var/datum/virtual_z/upper = new()
	upper.group_anchor = anchor
	upper.floor = 2
	anchor.active = TRUE
	upper.active = FALSE              // stale local value; getter must ignore it
	if(!upper.get_active())
		fail("Expected upper.get_active() to read anchor.active")
		return
	anchor.active = FALSE
	if(upper.get_active())
		fail("Expected upper.get_active() to follow anchor.active=FALSE")
		return
	// All assertions passed

/datum/unit_test/vlevel_display_id
	name = "VLEVEL: display id formatting"

/datum/unit_test/vlevel_display_id/start()
	var/datum/virtual_z/solo = new()
	solo.id = 4
	if(solo.get_display_id() != "4")
		fail("Single-floor display id should be '4', got '[solo.get_display_id()]'")
		return
	var/datum/virtual_z/anchor = new()
	var/datum/virtual_z/upper = new()
	anchor.id = 4
	upper.id = 4
	upper.floor = 2
	upper.group_anchor = anchor
	anchor.vlevel_above = upper
	upper.vlevel_below = anchor
	if(anchor.get_display_id() != "4-1")
		fail("Multi-floor anchor display id should be '4-1', got '[anchor.get_display_id()]'")
		return
	if(upper.get_display_id() != "4-2")
		fail("Upper floor display id should be '4-2', got '[upper.get_display_id()]'")
		return
	// All assertions passed

/datum/unit_test/multiz_helpers_resolve_via_vlevel
	name = "MULTIZ: HasAboveAt_vz/HasBelowAt_vz walk chain links"

/datum/unit_test/multiz_helpers_resolve_via_vlevel/start()
	// Set up two stub vlevels with parent z's.
	var/datum/virtual_z/anchor = new()
	anchor.parent_z = locate(/datum/zLevel) in map.zLevels
	if(!anchor.parent_z)
		fail("Could not locate a zLevel for test setup")
		return
	anchor.x_min = 1; anchor.x_max = 5; anchor.y_min = 1; anchor.y_max = 5
	var/datum/virtual_z/upper = new()
	upper.x_min = 1; upper.x_max = 5; upper.y_min = 1; upper.y_max = 5
	upper.group_anchor = anchor
	upper.floor = 2
	anchor.vlevel_above = upper
	upper.vlevel_below = anchor
	// We can only assert the field-walking part here; turf return depends on parent_z setup.
	if(!HasAboveAt_vz(anchor))
		fail("Expected HasAboveAt_vz(anchor) = TRUE")
		return
	if(HasAboveAt_vz(upper))
		fail("Expected HasAboveAt_vz(upper) = FALSE")
		return
	if(!HasBelowAt_vz(upper))
		fail("Expected HasBelowAt_vz(upper) = TRUE")
		return
	// All assertions passed

/datum/unit_test/vlevel_recompute_footprint
	name = "VLEVEL: recompute_footprint bounds walls + 15 buffer"

/datum/unit_test/vlevel_recompute_footprint/start()
	// This test reserves a small dynamic z and places wall turfs.
	var/datum/virtual_z/anchor = map.addVLevel(20, 20)
	if(!anchor)
		fail("Could not allocate anchor vlevel for test")
		return
	// Add an upper floor (proc defined in Task 6 — this test runs after Task 6 lands; if running tasks in order, we depend on it).
	var/datum/virtual_z/upper = map.addFloorAbove(anchor)
	if(!upper)
		fail("Could not allocate upper floor")
		return
	// Place a single wall turf at the center of the anchor footprint, on upper's parent z.
	var/cx = (anchor.x_min + anchor.x_max) / 2
	var/cy = (anchor.y_min + anchor.y_max) / 2
	var/turf/T = locate(cx, cy, upper.parent_z.z)
	T.ChangeTurf(/turf/simulated/wall)
	upper.recompute_footprint()
	// Bounds should be [cx-15..cx+15] clamped to anchor.
	var/expected_xmin = max(anchor.x_min, cx - 15)
	var/expected_xmax = min(anchor.x_max, cx + 15)
	if(upper.x_min != expected_xmin)
		fail("Expected x_min=[expected_xmin], got [upper.x_min]")
		return
	if(upper.x_max != expected_xmax)
		fail("Expected x_max=[expected_xmax], got [upper.x_max]")
		return
	// All assertions passed

/datum/unit_test/map_add_floor_above
	name = "MAP: addFloorAbove links floors and clears crosswrap"

/datum/unit_test/map_add_floor_above/start()
	var/datum/virtual_z/anchor = map.addVLevel(20, 20)
	anchor.id = 999
	anchor.transition_channel = "test_channel"
	anchor.transition_crosswrap_v = list(7, 7, 7, 7)
	var/datum/virtual_z/f2 = map.addFloorAbove(anchor)
	if(!f2)
		fail("addFloorAbove returned null")
		return
	if(f2.id != 999)
		fail("Expected f2.id=999, got [f2.id]")
		return
	if(f2.floor != 2)
		fail("Expected f2.floor=2, got [f2.floor]")
		return
	if(f2.group_anchor != anchor)
		fail("Expected f2.group_anchor=anchor")
		return
	if(anchor.vlevel_above != f2)
		fail("Expected anchor.vlevel_above=f2")
		return
	if(f2.vlevel_below != anchor)
		fail("Expected f2.vlevel_below=anchor")
		return
	// Channel + crosswrap cleared on first multi-floor.
	if(anchor.transition_channel != null)
		fail("Expected anchor.transition_channel cleared, got [anchor.transition_channel]")
		return
	for(var/v in anchor.transition_crosswrap_v)
		if(v != null)
			fail("Expected crosswrap entries null")
			return
	// All assertions passed

/datum/unit_test/map_remove_top_floor_empty
	name = "MAP: removeTopFloor on empty top succeeds"

/datum/unit_test/map_remove_top_floor_empty/start()
	var/datum/virtual_z/anchor = map.addVLevel(20, 20)
	anchor.id = 998
	map.addFloorAbove(anchor)
	var/result = map.removeTopFloor(anchor)
	if(!result)
		fail("Expected removeTopFloor to return TRUE")
		return
	if(anchor.vlevel_above != null)
		fail("Expected anchor.vlevel_above=null after removal")
		return
	// All assertions passed

/datum/unit_test/map_remove_top_floor_refuses_with_mob
	name = "MAP: removeTopFloor refuses when mob present"

/datum/unit_test/map_remove_top_floor_refuses_with_mob/start()
	var/datum/virtual_z/anchor = map.addVLevel(20, 20)
	anchor.id = 997
	var/datum/virtual_z/f2 = map.addFloorAbove(anchor)
	var/turf/T = locate(anchor.x_min + 1, anchor.y_min + 1, f2.parent_z.z)
	var/mob/M = new /mob/living/carbon/human(T)
	var/result = map.removeTopFloor(anchor)
	if(result)
		fail("Expected removeTopFloor to refuse with mob present")
		qdel(M)
		return
	qdel(M)
	// All assertions passed

/datum/unit_test/map_get_vlevel_floor
	name = "MAP: getVLevelFloor returns specific floor"

/datum/unit_test/map_get_vlevel_floor/start()
	var/datum/virtual_z/anchor = map.addVLevel(20, 20)
	anchor.id = 996
	var/datum/virtual_z/f2 = map.addFloorAbove(anchor)
	if(map.getVLevelFloor(996, 1) != anchor)
		fail("Expected floor 1 to be anchor")
		return
	if(map.getVLevelFloor(996, 2) != f2)
		fail("Expected floor 2 to be f2")
		return
	if(map.getVLevelFloor(996, 99) != null)
		fail("Expected non-existent floor to return null")
		return
	// All assertions passed

/datum/unit_test/maploader_multiz_group_starts_new
	name = "MAPLOADER: multiz_group=MULTIZ_NEW returns an anchor vlevel"

/datum/unit_test/maploader_multiz_group_starts_new/start()
	var/datum/virtual_z/anchor = map.load_map_into_vlevel("maps/misc/keycards/easy1.dmm", multiz_group = MULTIZ_NEW)
	if(!anchor)
		fail("Loader did not return an anchor")
		return
	if(anchor.floor != 1)
		fail("Anchor floor should be 1")
		return
	if(anchor.group_anchor != anchor)
		fail("Anchor's group_anchor should be self")
		return
	// All assertions passed

/datum/unit_test/maploader_multiz_group_extends
	name = "MAPLOADER: multiz_group=<vlevel> extends existing group"

/datum/unit_test/maploader_multiz_group_extends/start()
	var/datum/virtual_z/anchor = map.load_map_into_vlevel("maps/misc/keycards/easy1.dmm", multiz_group = MULTIZ_NEW)
	var/datum/virtual_z/f2 = map.load_map_into_vlevel("maps/misc/keycards/easy1.dmm", multiz_group = anchor)
	if(!f2 || f2.floor != 2 || f2.group_anchor != anchor)
		fail("Extension did not produce floor 2 in the same group")
		return
	// All assertions passed

/datum/unit_test/level_manager_multifloor_roundtrip
	name = "LEVEL MANAGER: multifloor group end-to-end"

/datum/unit_test/level_manager_multifloor_roundtrip/start()
	var/datum/virtual_z/anchor = map.addVLevel(20, 20)
	anchor.id = 500
	anchor.name = "Test Multi"
	var/datum/virtual_z/f2 = map.addFloorAbove(anchor)
	if(!f2)
		fail("Setup: f2 missing")
		return
	if(!anchor.is_multifloor())
		fail("Setup: anchor should report multifloor")
		return
	if(anchor.get_transition_channel() != null)
		fail("Channel not cleared on multifloor extension")
		return
	var/list/floors = GetConnectedFloors(anchor)
	if(length(floors) != 2)
		fail("Expected 2 floors, got [length(floors)]")
		return
	if(!map.removeTopFloor(anchor))
		fail("Could not remove top floor")
		return
	if(anchor.is_multifloor())
		fail("Group should be single-floor after removal")
		return
	// All assertions passed
