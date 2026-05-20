#if UNIT_TESTS_ENABLED

////////////////////////////////////////////////////////////////////
// SHARED TEST HELPERS
////////////////////////////////////////////////////////////////////

/proc/mindui_test_mob()
	var/mob/living/carbon/human/H = new(locate(1,1,1))
	if (!H.mind)
		H.mind = new
		H.mind.current = H
		H.mind.key = "TEST"
	return H

// Bypasses /datum/mind_ui/New() side-effects (SpawnElements/SendToClient/activeUIs)
// so tests can drive a UI datum headlessly without a client.
/datum/mind_ui/unit_test_stub
	abstract = TRUE
	uniqueID = "unit_test_stub"

/datum/mind_ui/unit_test_stub/New(datum/mind/M)
	mind = M

// Empty start() overrides for abstract parent test types; without these the
// runner's default start() runs fail("not implemented") on every grouping type.
/datum/unit_test/mindui_helpers/start()
/datum/unit_test/mindui_structure/start()
/datum/unit_test/mindui_smoke/start()
/datum/unit_test/mindui_predicates/start()
/datum/unit_test/mindui_heartbeat/start()
/datum/unit_test/mindui_cleanup/start()
/datum/unit_test/mindui_throttle/start()
/datum/unit_test/mindui_events/start()
/datum/unit_test/mindui_batched/start()
/datum/unit_test/mindui_lazy/start()
/datum/unit_test/mindui_pool/start()
/datum/unit_test/mindui_layout/start()
/datum/unit_test/mindui_visual/start()
/datum/unit_test/mindui_machine/start()
/datum/unit_test/mindui_admin/start()
/datum/unit_test/mindui_button/start()
/datum/unit_test/mindui_checkbox/start()
/datum/unit_test/mindui_gauge/start()
/datum/unit_test/mindui_tab/start()
/datum/unit_test/mindui_text_input/start()
/datum/unit_test/mindui_slider/start()
/datum/unit_test/mindui_window/start()
/datum/unit_test/mindui_dropdown/start()
/datum/unit_test/mindui_virtual_list/start()
/datum/unit_test/mindui_radio_group/start()
/datum/unit_test/mindui_canvas/start()
/datum/unit_test/mindui_interactivity/start()
/datum/unit_test/mindui_qol/start()
/datum/unit_test/mindui_shared/start()

////////////////////////////////////////////////////////////////////
// HELPERS & STRUCTURAL VALIDATION
////////////////////////////////////////////////////////////////////

/datum/unit_test/mindui_helpers/get_user_as_returns_typed_or_null
	name = "mindUI GetUserAs returns typed mob or null"

/datum/unit_test/mindui_helpers/get_user_as_returns_typed_or_null/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_stub/test_ui = new(H.mind)

	var/mob/positive = test_ui.GetUserAs(/mob/living/carbon/human)
	assert_eq(positive, H)

	var/mob/negative = test_ui.GetUserAs(/mob/living/silicon/robot)
	assert_eq(negative, null)

	// qdel test_ui first; it holds a ref to H.mind, so reverse order would dangle.
	qdel(test_ui)
	qdel(H)

/datum/unit_test/mindui_helpers/parse_modifiers_extracts_flags
	name = "mindUI mindui_parse_modifiers extracts flags correctly"

/datum/unit_test/mindui_helpers/parse_modifiers_extracts_flags/start()
	var/list/params = list("shift" = "1", "ctrl" = "1")
	var/flags = mindui_parse_modifiers(params)
	assert_eq(flags & MINDUI_MOD_SHIFT, MINDUI_MOD_SHIFT)
	assert_eq(flags & MINDUI_MOD_CTRL, MINDUI_MOD_CTRL)
	assert_eq(flags & MINDUI_MOD_ALT, 0)
	assert_eq(flags & MINDUI_MOD_RIGHT, 0)

/datum/unit_test/mindui_helpers/parse_modifiers_empty_returns_zero
	name = "mindUI mindui_parse_modifiers empty params returns zero"

/datum/unit_test/mindui_helpers/parse_modifiers_empty_returns_zero/start()
	var/list/params = list()
	assert_eq(mindui_parse_modifiers(params), 0)

/datum/unit_test/mindui_helpers/split_screen_loc_basic
	name = "mindUI mindui_split_screen_loc parses anchor and offset"

/datum/unit_test/mindui_helpers/split_screen_loc_basic/start()
	var/list/r = mindui_split_screen_loc("LEFT:5,TOP:-3")
	assert_eq(r["x_anchor"], "LEFT")
	assert_eq(r["x_off"], 5)
	assert_eq(r["y_anchor"], "TOP")
	assert_eq(r["y_off"], -3)

/datum/unit_test/mindui_helpers/split_screen_loc_no_pixel_offset
	name = "mindUI mindui_split_screen_loc handles anchors without offsets"

/datum/unit_test/mindui_helpers/split_screen_loc_no_pixel_offset/start()
	var/list/r = mindui_split_screen_loc("CENTER,CENTER")
	assert_eq(r["x_anchor"], "CENTER")
	assert_eq(r["x_off"], 0)
	assert_eq(r["y_anchor"], "CENTER")
	assert_eq(r["y_off"], 0)

/datum/unit_test/mindui_helpers/split_screen_loc_malformed_returns_null
	name = "mindUI mindui_split_screen_loc malformed input returns null"

/datum/unit_test/mindui_helpers/split_screen_loc_malformed_returns_null/start()
	var/r = mindui_split_screen_loc("just-one-part")
	assert_eq(r, null)

/datum/unit_test/mindui_structure
	name = "mindUI structural validation base"

/datum/unit_test/mindui_structure/all_uis_pass_static_validation
	name = "mindUI all non-abstract subtypes pass static validation"

/datum/unit_test/mindui_structure/all_uis_pass_static_validation/start()
	var/list/failures = list()
	for (var/uitype in subtypesof(/datum/mind_ui))
		var/datum/mind_ui/proto = uitype
		if (initial(proto.abstract))
			continue
		var/code = mindui_static_validate(uitype)
		if (code != MINDUI_VALID)
			failures += "[uitype]: [mindui_validate_code_name(code)]"
	if (failures.len)
		fail("Static validation failed for [failures.len] subtype(s):\n[failures.Join("\n")]")

/datum/unit_test/mindui_structure/unique_ids_are_unique
	name = "mindUI all non-abstract subtypes have unique uniqueIDs"

/datum/unit_test/mindui_structure/unique_ids_are_unique/start()
	var/list/seen = list()
	var/list/dups = list()
	for (var/uitype in subtypesof(/datum/mind_ui))
		var/datum/mind_ui/proto = uitype
		if (initial(proto.abstract))
			continue
		var/id = initial(proto.uniqueID)
		if (id in seen)
			dups += "[uitype] reuses uniqueID '[id]' from [seen[id]]"
		else
			seen[id] = uitype
	if (dups.len)
		fail("Duplicate uniqueIDs found:\n[dups.Join("\n")]")

////////////////////////////////////////////////////////////////////
// SMOKE: spawn/Display/Hide/qdel every non-abstract subtype
////////////////////////////////////////////////////////////////////

// A UI whose Valid() returns FALSE is fine; Display() routes to Hide(TRUE).
// Each subtype is wrapped in try/catch so a single failure doesn't abort the run.
/datum/unit_test/mindui_smoke/spawn_and_hide_every_ui
	name = "mindUI smoke: spawn/Display/Hide/qdel every non-abstract subtype"

/datum/unit_test/mindui_smoke/spawn_and_hide_every_ui/start()
	var/list/failures = list()

	for (var/uitype in subtypesof(/datum/mind_ui))
		var/datum/mind_ui/proto = uitype
		if (initial(proto.abstract))
			continue

		var/mob/living/carbon/human/H = new(run_loc_bottom_left)
		if (!H.mind)
			H.mind = new /datum/mind
			H.mind.current = H
			H.mind.key = "UNIT_TEST_SMOKE"

		try
			var/datum/mind_ui/U = new uitype(H.mind)
			U.Display()
			U.Hide(TRUE)
			qdel(U)
		catch (var/exception/E)
			failures += "[uitype]: [E.name] at [E.file]:[E.line]"

		qdel(H)

	if (failures.len)
		fail("Smoke test caught runtime(s) in [failures.len] subtype(s):\n[failures.Join("\n")]")

////////////////////////////////////////////////////////////////////
// PREDICATES
////////////////////////////////////////////////////////////////////

/datum/unit_test/mindui_predicates/living_predicate_alive_human_passes
	name = "mindUI Valid_Living returns TRUE for a living human"

/datum/unit_test/mindui_predicates/living_predicate_alive_human_passes/start()
	var/mob/living/carbon/human/H = new(run_loc_bottom_left)
	if (!H.mind)
		H.mind = new /datum/mind
		H.mind.current = H
		H.mind.key = "UNIT_TEST_LIVING"
	var/datum/mind_ui/unit_test_stub/u = new(H.mind)
	assert_eq(u.Valid_Living(), TRUE)
	qdel(u)
	qdel(H)

/datum/unit_test/mindui_predicates/living_predicate_dead_human_fails
	name = "mindUI Valid_Living returns FALSE for a dead human"

/datum/unit_test/mindui_predicates/living_predicate_dead_human_fails/start()
	var/mob/living/carbon/human/H = new(run_loc_bottom_left)
	if (!H.mind)
		H.mind = new /datum/mind
		H.mind.current = H
		H.mind.key = "UNIT_TEST_DEAD"
	H.stat = DEAD
	var/datum/mind_ui/unit_test_stub/u = new(H.mind)
	assert_eq(u.Valid_Living(), FALSE)
	qdel(u)
	qdel(H)

/datum/unit_test/mindui_predicates/adjacent_predicate_uses_adjacency
	name = "mindUI Valid_Adjacent returns TRUE when adjacent, FALSE when not"

/datum/unit_test/mindui_predicates/adjacent_predicate_uses_adjacency/start()
	// Avoid the map's transition-edge zone; turfs near (1,1) reroute movers to safe spawns.
	var/turf/safe_loc = locate(round(world.maxx / 2), round(world.maxy / 2), 1)
	var/mob/living/carbon/human/H = new(safe_loc)
	H.forceMove(safe_loc)
	if (!H.mind)
		H.mind = new /datum/mind
		H.mind.current = H
		H.mind.key = "UNIT_TEST_ADJ"
	var/obj/test_atom = new /obj(safe_loc)
	var/datum/mind_ui/unit_test_stub/u = new(H.mind)
	assert_eq(u.Valid_Adjacent(test_atom), TRUE)
	var/turf/far = locate(round(world.maxx / 2) + 20, round(world.maxy / 2) + 20, 1)
	if (far)
		test_atom.forceMove(far)
		assert_eq(u.Valid_Adjacent(test_atom), FALSE)
	qdel(test_atom)
	qdel(u)
	qdel(H)

/datum/unit_test/mindui_predicates/adjacent_predicate_null_target_returns_false
	name = "mindUI Valid_Adjacent returns FALSE for null target"

/datum/unit_test/mindui_predicates/adjacent_predicate_null_target_returns_false/start()
	var/mob/living/carbon/human/H = new(run_loc_bottom_left)
	if (!H.mind)
		H.mind = new /datum/mind
		H.mind.current = H
		H.mind.key = "UNIT_TEST_ADJ_NULL"
	var/datum/mind_ui/unit_test_stub/u = new(H.mind)
	assert_eq(u.Valid_Adjacent(null), FALSE)
	qdel(u)
	qdel(H)

/datum/unit_test/mindui_predicates/has_role_returns_false_without_role
	name = "mindUI Valid_HasRole returns FALSE when mob has no role"

/datum/unit_test/mindui_predicates/has_role_returns_false_without_role/start()
	var/mob/living/carbon/human/H = new(run_loc_bottom_left)
	if (!H.mind)
		H.mind = new /datum/mind
		H.mind.current = H
		H.mind.key = "UNIT_TEST_ROLE"
	var/datum/mind_ui/unit_test_stub/u = new(H.mind)
	assert_eq(u.Valid_HasRole(MALF), FALSE)
	qdel(u)
	qdel(H)

/datum/unit_test/mindui_predicates/locked_to_returns_false_when_unlocked
	name = "mindUI Valid_LockedTo returns FALSE when mob is not buckled"

/datum/unit_test/mindui_predicates/locked_to_returns_false_when_unlocked/start()
	var/mob/living/carbon/human/H = new(run_loc_bottom_left)
	if (!H.mind)
		H.mind = new /datum/mind
		H.mind.current = H
		H.mind.key = "UNIT_TEST_LOCKED"
	var/datum/mind_ui/unit_test_stub/u = new(H.mind)
	assert_eq(u.Valid_LockedTo(/obj/structure/bed/chair), FALSE)
	qdel(u)
	qdel(H)

/datum/unit_test/mindui_predicates/locked_to_returns_true_when_locked
	name = "mindUI Valid_LockedTo returns TRUE when mob is buckled to a matching type"

/datum/unit_test/mindui_predicates/locked_to_returns_true_when_locked/start()
	var/mob/living/carbon/human/H = new(run_loc_bottom_left)
	if (!H.mind)
		H.mind = new /datum/mind
		H.mind.current = H
		H.mind.key = "UNIT_TEST_LOCKED2"
	var/obj/structure/bed/chair/C = new(run_loc_bottom_left)
	// Direct assignment bypasses buckle machinery; the predicate only checks istype.
	H.locked_to = C
	var/datum/mind_ui/unit_test_stub/u = new(H.mind)
	assert_eq(u.Valid_LockedTo(/obj/structure/bed/chair), TRUE)
	qdel(u)
	qdel(C)
	qdel(H)

/datum/unit_test/mindui_predicates/insideitem_returns_true_when_inside
	name = "mindUI Valid_InsideItemOfType returns TRUE when mob is inside a closet"

/datum/unit_test/mindui_predicates/insideitem_returns_true_when_inside/start()
	var/mob/living/carbon/human/H = new(run_loc_bottom_left)
	if (!H.mind)
		H.mind = new /datum/mind
		H.mind.current = H
		H.mind.key = "UNIT_TEST_INSIDE"
	var/obj/structure/closet/closet = new(run_loc_bottom_left)
	H.forceMove(closet)
	var/datum/mind_ui/unit_test_stub/u = new(H.mind)
	assert_eq(u.Valid_InsideItemOfType(/obj/structure/closet), TRUE)
	qdel(u)
	qdel(closet)
	qdel(H)

/datum/unit_test/mindui_predicates/silicon_returns_false_for_human
	name = "mindUI Valid_IsSilicon returns FALSE for a carbon human"

/datum/unit_test/mindui_predicates/silicon_returns_false_for_human/start()
	var/mob/living/carbon/human/H = new(run_loc_bottom_left)
	if (!H.mind)
		H.mind = new /datum/mind
		H.mind.current = H
		H.mind.key = "UNIT_TEST_SILICON"
	var/datum/mind_ui/unit_test_stub/u = new(H.mind)
	assert_eq(u.Valid_IsSilicon(), FALSE)
	qdel(u)
	qdel(H)

/datum/unit_test/mindui_predicates/conscious_predicate_passes_for_default_human
	name = "mindUI Valid_Conscious returns TRUE for a conscious human"

/datum/unit_test/mindui_predicates/conscious_predicate_passes_for_default_human/start()
	var/mob/living/carbon/human/H = new(run_loc_bottom_left)
	if (!H.mind)
		H.mind = new /datum/mind
		H.mind.current = H
		H.mind.key = "UNIT_TEST_CONSCIOUS"
	var/datum/mind_ui/unit_test_stub/u = new(H.mind)
	assert_eq(u.Valid_Conscious(), TRUE)
	qdel(u)
	qdel(H)

/datum/unit_test/mindui_predicates/conscious_predicate_fails_for_dead_human
	name = "mindUI Valid_Conscious returns FALSE for a dead human"

/datum/unit_test/mindui_predicates/conscious_predicate_fails_for_dead_human/start()
	var/mob/living/carbon/human/H = new(run_loc_bottom_left)
	if (!H.mind)
		H.mind = new /datum/mind
		H.mind.current = H
		H.mind.key = "UNIT_TEST_CONSCIOUS_DEAD"
	H.stat = DEAD
	var/datum/mind_ui/unit_test_stub/u = new(H.mind)
	assert_eq(u.Valid_Conscious(), FALSE)
	qdel(u)
	qdel(H)

/datum/unit_test/mindui_predicates/holding_item_returns_true_when_holding
	name = "mindUI Valid_HoldingItemOfType returns TRUE when holding a matching item"

/datum/unit_test/mindui_predicates/holding_item_returns_true_when_holding/start()
	var/mob/living/carbon/human/H = new(run_loc_bottom_left)
	if (!H.mind)
		H.mind = new /datum/mind
		H.mind.current = H
		H.mind.key = "UNIT_TEST_HOLDING"
	var/obj/item/I = new /obj/item(run_loc_bottom_left)
	H.held_items[GRASP_LEFT_HAND] = I
	var/datum/mind_ui/unit_test_stub/u = new(H.mind)
	assert_eq(u.Valid_HoldingItemOfType(/obj/item), TRUE)
	qdel(u)
	qdel(I)
	qdel(H)

/datum/unit_test/mindui_predicates/holding_item_returns_false_when_empty
	name = "mindUI Valid_HoldingItemOfType returns FALSE when hands are empty"

/datum/unit_test/mindui_predicates/holding_item_returns_false_when_empty/start()
	var/mob/living/carbon/human/H = new(run_loc_bottom_left)
	if (!H.mind)
		H.mind = new /datum/mind
		H.mind.current = H
		H.mind.key = "UNIT_TEST_HOLDING_EMPTY"
	var/datum/mind_ui/unit_test_stub/u = new(H.mind)
	assert_eq(u.Valid_HoldingItemOfType(/obj/item), FALSE)
	qdel(u)
	qdel(H)

////////////////////////////////////////////////////////////////////
// HEARTBEAT
////////////////////////////////////////////////////////////////////

/datum/mind_ui/unit_test_heartbeat
	abstract = TRUE
	uniqueID = "unit_test_heartbeat"
	var/test_valid = TRUE

/datum/mind_ui/unit_test_heartbeat/New(datum/mind/M)
	mind = M

/datum/mind_ui/unit_test_heartbeat/Valid()
	return test_valid

/datum/unit_test/mindui_heartbeat/hides_when_validity_drops
	name = "SSmindui heartbeat - hides UI when Valid() flips to FALSE"

/datum/unit_test/mindui_heartbeat/hides_when_validity_drops/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_heartbeat/U = new(H.mind)
	H.mind.activeUIs[U.uniqueID] = U
	U.active = TRUE
	U.test_valid = FALSE
	SSmindui.HeartbeatOne(H.mind)
	if (U.active)
		fail("expected UI to be inactive after heartbeat saw Valid()=FALSE")
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_heartbeat/auto_displays_when_validity_returns
	name = "SSmindui heartbeat - re-shows UI with auto_display when Valid() flips back to TRUE"

/datum/unit_test/mindui_heartbeat/auto_displays_when_validity_returns/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_heartbeat/U = new(H.mind)
	U.auto_display = TRUE
	H.mind.activeUIs[U.uniqueID] = U
	U.active = FALSE
	U.test_valid = TRUE
	SSmindui.HeartbeatOne(H.mind)
	if (!U.active)
		fail("expected UI to be active after heartbeat saw Valid()=TRUE with auto_display")
	qdel(U)
	qdel(H)

////////////////////////////////////////////////////////////////////
// CLEANUP
////////////////////////////////////////////////////////////////////

/datum/mind_ui/unit_test_cleanup
	abstract = TRUE
	uniqueID = "unit_test_cleanup"
	cleanup_when_invalid = TRUE

/datum/mind_ui/unit_test_cleanup/New(datum/mind/M)
	mind = M

/datum/mind_ui/unit_test_cleanup/Valid()
	return FALSE

/datum/unit_test/mindui_cleanup/removes_from_activeUIs_on_hide
	name = "mindUI cleanup_when_invalid - UI is removed from mind.activeUIs after Hide()"

/datum/unit_test/mindui_cleanup/removes_from_activeUIs_on_hide/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_cleanup/U = new(H.mind)
	H.mind.activeUIs[U.uniqueID] = U
	U.Hide()
	if (U.uniqueID in H.mind.activeUIs)
		fail("expected UI removed from activeUIs after Hide(); still present")
	qdel(H)

////////////////////////////////////////////////////////////////////
// THROTTLE
////////////////////////////////////////////////////////////////////

/obj/abstract/mind_ui_element/unit_test_throttle
	var/tick_count = 0

/obj/abstract/mind_ui_element/unit_test_throttle/New()
	return

/obj/abstract/mind_ui_element/unit_test_throttle/Tick()
	tick_count++

/datum/unit_test/mindui_throttle/skips_when_interval_not_elapsed
	name = "mindUI process_interval - Tick is skipped when interval hasn't elapsed"

/datum/unit_test/mindui_throttle/skips_when_interval_not_elapsed/start()
	var/obj/abstract/mind_ui_element/unit_test_throttle/E = new
	E.process_interval = 100
	E.last_process = world.time
	E.process()
	assert_eq(E.tick_count, 0)
	qdel(E)

/datum/unit_test/mindui_throttle/runs_when_interval_elapsed
	name = "mindUI process_interval - Tick runs when interval has elapsed"

/datum/unit_test/mindui_throttle/runs_when_interval_elapsed/start()
	var/obj/abstract/mind_ui_element/unit_test_throttle/E = new
	E.process_interval = 10
	E.last_process = world.time - 20
	E.process()
	assert_eq(E.tick_count, 1)
	qdel(E)

/datum/unit_test/mindui_throttle/updates_last_process_after_tick
	name = "mindUI process_interval - last_process is set to world.time after a successful Tick"

/datum/unit_test/mindui_throttle/updates_last_process_after_tick/start()
	var/obj/abstract/mind_ui_element/unit_test_throttle/E = new
	E.process_interval = 10
	E.last_process = world.time - 20
	E.process()
	assert_eq(E.last_process, world.time)
	qdel(E)

////////////////////////////////////////////////////////////////////
// EVENTS
////////////////////////////////////////////////////////////////////

/obj/abstract/mind_ui_element/unit_test_event_counter
	var/refresh_count = 0

/obj/abstract/mind_ui_element/unit_test_event_counter/New()
	return

/obj/abstract/mind_ui_element/unit_test_event_counter/UpdateIcon()
	refresh_count++

/datum/mind_ui/unit_test_event_stub
	abstract = TRUE
	uniqueID = "unit_test_event_stub"

/datum/mind_ui/unit_test_event_stub/New(datum/mind/M)
	mind = M
	var/obj/abstract/mind_ui_element/unit_test_event_counter/c = new
	elements += c

/datum/unit_test/mindui_events/whole_ui_refresh_on_event
	name = "mindUI BindEvent - whole-UI refresh on event"

/datum/unit_test/mindui_events/whole_ui_refresh_on_event/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_event_stub/U = new(H.mind)
	var/datum/test_source = new
	U.BindEvent(test_source, /event/mindui_test_refresh)
	INVOKE_EVENT(test_source, /event/mindui_test_refresh)
	var/obj/abstract/mind_ui_element/unit_test_event_counter/c = U.elements[1]
	assert_eq(c.refresh_count, 1)
	qdel(test_source)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_events/element_typed_refresh_on_event
	name = "mindUI BindEvent - typed element-only refresh on event"

/datum/unit_test/mindui_events/element_typed_refresh_on_event/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_event_stub/U = new(H.mind)
	var/datum/test_source = new
	U.BindEvent(test_source, /event/mindui_test_refresh, /obj/abstract/mind_ui_element/unit_test_event_counter)
	INVOKE_EVENT(test_source, /event/mindui_test_refresh)
	var/obj/abstract/mind_ui_element/unit_test_event_counter/c = U.elements[1]
	assert_eq(c.refresh_count, 1)
	qdel(test_source)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_events/unbind_stops_refresh
	name = "mindUI UnbindEvent stops further refreshes"

/datum/unit_test/mindui_events/unbind_stops_refresh/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_event_stub/U = new(H.mind)
	var/datum/test_source = new
	U.BindEvent(test_source, /event/mindui_test_refresh)
	INVOKE_EVENT(test_source, /event/mindui_test_refresh)
	U.UnbindEvent(test_source, /event/mindui_test_refresh)
	INVOKE_EVENT(test_source, /event/mindui_test_refresh)
	var/obj/abstract/mind_ui_element/unit_test_event_counter/c = U.elements[1]
	assert_eq(c.refresh_count, 1)
	qdel(test_source)
	qdel(U)
	qdel(H)

////////////////////////////////////////////////////////////////////
// BATCHED SEND
////////////////////////////////////////////////////////////////////

/obj/abstract/mind_ui_element/unit_test_batched

/datum/mind_ui/unit_test_batched_stub
	abstract = TRUE
	uniqueID = "unit_test_batched_stub"

/datum/mind_ui/unit_test_batched_stub/New(datum/mind/M)
	mind = M

/datum/unit_test/mindui_batched/send_to_client_no_crash_empty_elements
	name = "mindUI SendToClient - does not crash with empty elements list"

/datum/unit_test/mindui_batched/send_to_client_no_crash_empty_elements/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_batched_stub/U = new(H.mind)
	U.SendToClient()
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_batched/send_to_client_skips_when_no_client
	name = "mindUI SendToClient - early-returns when there is no client"

/datum/unit_test/mindui_batched/send_to_client_skips_when_no_client/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_batched_stub/U = new(H.mind)
	U.SendToClient()
	qdel(U)
	qdel(H)

////////////////////////////////////////////////////////////////////
// LAZY SPAWN
////////////////////////////////////////////////////////////////////

/obj/abstract/mind_ui_element/unit_test_lazy_dummy

/datum/mind_ui/unit_test_lazy
	abstract = TRUE
	uniqueID = "unit_test_lazy"
	lazy = TRUE
	element_types_to_spawn = list(
		/obj/abstract/mind_ui_element/unit_test_lazy_dummy,
	)

/datum/unit_test/mindui_lazy/elements_empty_until_display
	name = "mindUI lazy=TRUE - elements list is empty until Display() is called"

/datum/unit_test/mindui_lazy/elements_empty_until_display/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_lazy/U = new(H.mind)
	assert_eq(U.elements.len, 0)
	U.Display()
	if (U.elements.len < 1)
		fail("expected elements after Display(), got [U.elements.len]")
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_lazy/ensure_spawned_is_idempotent
	name = "mindUI lazy=TRUE - EnsureSpawned does not re-spawn after first call"

/datum/unit_test/mindui_lazy/ensure_spawned_is_idempotent/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_lazy/U = new(H.mind)
	U.EnsureSpawned()
	var/first_len = U.elements.len
	U.EnsureSpawned()
	assert_eq(U.elements.len, first_len)
	qdel(U)
	qdel(H)

////////////////////////////////////////////////////////////////////
// ELEMENT POOL
////////////////////////////////////////////////////////////////////

/obj/abstract/mind_ui_element/unit_test_pool_elem

/datum/mind_ui/unit_test_pool_owner
	abstract = TRUE
	uniqueID = "unit_test_pool_owner"

/datum/mind_ui/unit_test_pool_owner/New(datum/mind/M)
	mind = M

/datum/unit_test/mindui_pool/preallocates_correct_count
	name = "mindui_element_pool - preallocates the requested count of inactive elements"

/datum/unit_test/mindui_pool/preallocates_correct_count/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_pool_owner/U = new(H.mind)
	var/datum/mindui_element_pool/P = new(U, /obj/abstract/mind_ui_element/unit_test_pool_elem, 5)
	assert_eq(P.inactive.len, 5)
	assert_eq(P.active.len, 0)
	qdel(P)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_pool/acquire_pulls_from_inactive
	name = "mindui_element_pool - Acquire pulls from inactive and moves to active"

/datum/unit_test/mindui_pool/acquire_pulls_from_inactive/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_pool_owner/U = new(H.mind)
	var/datum/mindui_element_pool/P = new(U, /obj/abstract/mind_ui_element/unit_test_pool_elem, 3)
	var/obj/abstract/mind_ui_element/e = P.Acquire()
	if (!e)
		fail("Acquire returned null")
	assert_eq(P.inactive.len, 2)
	assert_eq(P.active.len, 1)
	qdel(P)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_pool/acquire_grows_when_inactive_empty
	name = "mindui_element_pool - Acquire creates new element when pool is empty"

/datum/unit_test/mindui_pool/acquire_grows_when_inactive_empty/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_pool_owner/U = new(H.mind)
	var/datum/mindui_element_pool/P = new(U, /obj/abstract/mind_ui_element/unit_test_pool_elem, 1)
	P.Acquire()
	P.Acquire()
	assert_eq(P.active.len, 2)
	qdel(P)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_pool/release_returns_to_inactive
	name = "mindui_element_pool - Release moves an active element back to inactive"

/datum/unit_test/mindui_pool/release_returns_to_inactive/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_pool_owner/U = new(H.mind)
	var/datum/mindui_element_pool/P = new(U, /obj/abstract/mind_ui_element/unit_test_pool_elem, 2)
	var/obj/abstract/mind_ui_element/e = P.Acquire()
	P.Release(e)
	assert_eq(P.active.len, 0)
	assert_eq(P.inactive.len, 2)
	qdel(P)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_pool/release_all_releases_everything
	name = "mindui_element_pool - ReleaseAll moves all active elements to inactive"

/datum/unit_test/mindui_pool/release_all_releases_everything/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_pool_owner/U = new(H.mind)
	var/datum/mindui_element_pool/P = new(U, /obj/abstract/mind_ui_element/unit_test_pool_elem, 3)
	P.Acquire()
	P.Acquire()
	P.ReleaseAll()
	assert_eq(P.active.len, 0)
	assert_eq(P.inactive.len, 3)
	qdel(P)
	qdel(U)
	qdel(H)

////////////////////////////////////////////////////////////////////
// LAYOUT
////////////////////////////////////////////////////////////////////

/datum/mind_ui/unit_test_layout_host
	abstract = TRUE
	uniqueID = "unit_test_layout_host"

/datum/mind_ui/unit_test_layout_host/New(datum/mind/M)
	mind = M

/obj/abstract/mind_ui_element/unit_test_layout_box
	icon = 'icons/ui/32x32.dmi'
	icon_state = "blank"

/datum/unit_test/mindui_layout/vstack_places_items_with_spacing
	name = "mindUI layout - vstack stacks items with spacing between them"

/datum/unit_test/mindui_layout/vstack_places_items_with_spacing/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_layout_host/U = new(H.mind)
	var/obj/abstract/mind_ui_element/unit_test_layout_box/A = new(null, U)
	var/obj/abstract/mind_ui_element/unit_test_layout_box/B = new(null, U)
	var/obj/abstract/mind_ui_element/unit_test_layout_box/C = new(null, U)
	var/datum/mindui_layout/vstack/L = new(U)
	L.spacing = 4
	L.Add(A)
	L.Add(B)
	L.Add(C)
	L.Apply()
	assert_eq(A.offset_x, 0)
	assert_eq(A.offset_y, 0)
	assert_eq(B.offset_x, 0)
	assert_eq(B.offset_y, 36)
	assert_eq(C.offset_x, 0)
	assert_eq(C.offset_y, 72)
	qdel(L)
	qdel(A)
	qdel(B)
	qdel(C)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_layout/hstack_places_items_with_spacing
	name = "mindUI layout - hstack stacks items horizontally with spacing"

/datum/unit_test/mindui_layout/hstack_places_items_with_spacing/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_layout_host/U = new(H.mind)
	var/obj/abstract/mind_ui_element/unit_test_layout_box/A = new(null, U)
	var/obj/abstract/mind_ui_element/unit_test_layout_box/B = new(null, U)
	var/obj/abstract/mind_ui_element/unit_test_layout_box/C = new(null, U)
	var/datum/mindui_layout/hstack/L = new(U)
	L.spacing = 4
	L.Add(A)
	L.Add(B)
	L.Add(C)
	L.Apply()
	assert_eq(A.offset_y, 0)
	assert_eq(A.offset_x, 0)
	assert_eq(B.offset_y, 0)
	assert_eq(B.offset_x, 36)
	assert_eq(C.offset_y, 0)
	assert_eq(C.offset_x, 72)
	qdel(L)
	qdel(A)
	qdel(B)
	qdel(C)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_layout/grid_lays_out_in_rows
	name = "mindUI layout - grid wraps items into rows at cols boundary"

/datum/unit_test/mindui_layout/grid_lays_out_in_rows/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_layout_host/U = new(H.mind)
	var/list/boxes = list()
	for (var/i in 1 to 6)
		boxes += new /obj/abstract/mind_ui_element/unit_test_layout_box(null, U)
	var/datum/mindui_layout/grid/L = new(U)
	L.cols = 3
	L.spacing = 4
	L.cell_width = 32
	L.cell_height = 32
	for (var/obj/abstract/mind_ui_element/e in boxes)
		L.Add(e)
	L.Apply()
	var/obj/abstract/mind_ui_element/e0 = boxes[1]
	var/obj/abstract/mind_ui_element/e1 = boxes[2]
	var/obj/abstract/mind_ui_element/e2 = boxes[3]
	var/obj/abstract/mind_ui_element/e3 = boxes[4]
	var/obj/abstract/mind_ui_element/e4 = boxes[5]
	var/obj/abstract/mind_ui_element/e5 = boxes[6]
	assert_eq(e0.offset_x, 0)
	assert_eq(e0.offset_y, 0)
	assert_eq(e1.offset_x, 36)
	assert_eq(e1.offset_y, 0)
	assert_eq(e2.offset_x, 72)
	assert_eq(e2.offset_y, 0)
	assert_eq(e3.offset_x, 0)
	assert_eq(e3.offset_y, 36)
	assert_eq(e4.offset_x, 36)
	assert_eq(e4.offset_y, 36)
	assert_eq(e5.offset_x, 72)
	assert_eq(e5.offset_y, 36)
	qdel(L)
	for (var/obj/abstract/mind_ui_element/e in boxes)
		qdel(e)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_layout/anchor_below_inherits_offset
	name = "mindUI layout - anchor_to with side=below places element directly under target"

/datum/unit_test/mindui_layout/anchor_below_inherits_offset/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_layout_host/U = new(H.mind)
	var/obj/abstract/mind_ui_element/unit_test_layout_box/A = new(null, U)
	var/obj/abstract/mind_ui_element/unit_test_layout_box/B = new(null, U)
	A.offset_x = 50
	A.offset_y = 100
	U.elements += A
	U.elements += B
	B.anchor_to = A
	B.anchor_side = "below"
	U.ResolveAnchors()
	assert_eq(B.offset_x, 50)
	assert_eq(B.offset_y, 132)
	qdel(A)
	qdel(B)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_layout/snap_to_edge_pulls_to_zero
	name = "mindUI layout - SnapToEdge() rounds near-zero offsets to 0"

/datum/unit_test/mindui_layout/snap_to_edge_pulls_to_zero/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_layout_host/U = new(H.mind)
	var/obj/abstract/mind_ui_element/hoverable/movable/M = new(null, U)
	M.snap_to_edge = TRUE
	M.move_whole_ui = FALSE
	M.offset_x = 3
	M.offset_y = 4
	M.SnapToEdge()
	assert_eq(M.offset_x, 0)
	assert_eq(M.offset_y, 0)
	qdel(M)
	qdel(U)
	qdel(H)

////////////////////////////////////////////////////////////////////
// VISUAL: panels & themes
////////////////////////////////////////////////////////////////////

/datum/mind_ui/unit_test_visual_default
	abstract = TRUE
	uniqueID = "unit_test_visual_default"

/datum/mind_ui/unit_test_visual_default/New(datum/mind/M)
	mind = M

/datum/unit_test/mindui_visual/gen_panel_returns_icon_with_size
	name = "mindUI mindui_gen_panel returns an icon at the requested dimensions"

/datum/unit_test/mindui_visual/gen_panel_returns_icon_with_size/start()
	var/icon/I = mindui_gen_panel(64, 48)
	if (!I)
		fail("mindui_gen_panel(64, 48) returned null")
		return
	assert_eq(I.Width(), 64)
	assert_eq(I.Height(), 48)

/datum/unit_test/mindui_visual/gen_panel_with_border
	name = "mindUI mindui_gen_panel with border returns a non-null icon"

/datum/unit_test/mindui_visual/gen_panel_with_border/start()
	var/icon/I = mindui_gen_panel(32, 32, fill = "#202020", border = "#FF0000")
	if (!I)
		fail("mindui_gen_panel with border returned null")
		return
	assert_eq(I.Width(), 32)
	assert_eq(I.Height(), 32)

/datum/unit_test/mindui_visual/theme_lookup_returns_color
	name = "mindUI GetThemeColor returns the configured color for a known key"

/datum/unit_test/mindui_visual/theme_lookup_returns_color/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_visual_default/U = new(H.mind)
	U.theme = "default"
	assert_eq(U.GetThemeColor("background"), "#202020")
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_visual/theme_unknown_key_returns_white
	name = "mindUI GetThemeColor returns white for an unknown key"

/datum/unit_test/mindui_visual/theme_unknown_key_returns_white/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_visual_default/U = new(H.mind)
	U.theme = "default"
	assert_eq(U.GetThemeColor("does_not_exist"), "#FFFFFF")
	qdel(U)
	qdel(H)

////////////////////////////////////////////////////////////////////
// MACHINE UI
////////////////////////////////////////////////////////////////////

/datum/mind_ui/machine/unit_test_machine_stub
	abstract = TRUE
	uniqueID = "unit_test_machine_stub"

/datum/mind_ui/machine/unit_test_machine_stub/New(datum/mind/M, atom/source = null)
	mind = M
	if (source)
		source_ref = makeweakref(source)

// Real-flow stub for Open_mindUI tests: lets the full /datum/mind_ui/New chain run.
/datum/mind_ui/machine/unit_test_machine_real
	uniqueID = "unit_test_machine_real"

/datum/unit_test/mindui_machine/machine_base_is_abstract
	name = "mindUI machine base /datum/mind_ui/machine is abstract"

/datum/unit_test/mindui_machine/machine_base_is_abstract/start()
	var/datum/mind_ui/machine/proto = /datum/mind_ui/machine
	if (!initial(proto.abstract))
		fail("/datum/mind_ui/machine must be abstract = TRUE so the structural validator skips it")

/datum/unit_test/mindui_machine/machine_with_no_source_is_invalid
	name = "mindUI machine Valid() returns FALSE when source is null"

/datum/unit_test/mindui_machine/machine_with_no_source_is_invalid/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/machine/unit_test_machine_stub/U = new(H.mind, null)
	if (U.Valid())
		fail("expected Valid()=FALSE with no source bound")
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_machine/machine_with_living_source_in_range_is_valid
	name = "mindUI machine Valid() returns TRUE when user is alive and source is in range"

/datum/unit_test/mindui_machine/machine_with_living_source_in_range_is_valid/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/obj/source = new(get_turf(H))
	var/datum/mind_ui/machine/unit_test_machine_stub/U = new(H.mind, source)
	if (!U.Valid())
		fail("expected Valid()=TRUE for living user with source on the same turf")
	qdel(U)
	qdel(source)
	qdel(H)

/datum/unit_test/mindui_machine/machine_out_of_range_is_invalid
	name = "mindUI machine Valid() returns FALSE when source is out of range"

/datum/unit_test/mindui_machine/machine_out_of_range_is_invalid/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/obj/source = new(get_turf(H))
	var/datum/mind_ui/machine/unit_test_machine_stub/U = new(H.mind, source)
	var/turf/far = locate(20, 20, 1)
	if (far)
		source.forceMove(far)
		if (U.Valid())
			fail("expected Valid()=FALSE when source is moved beyond source_distance_limit")
	qdel(U)
	qdel(source)
	qdel(H)

/datum/unit_test/mindui_machine/open_mindui_returns_false_when_no_mind
	name = "mindUI Open_mindUI returns FALSE when user has no mind"

/datum/unit_test/mindui_machine/open_mindui_returns_false_when_no_mind/start()
	var/obj/source = new(locate(1, 1, 1))
	source.mind_ui_type = /datum/mind_ui/machine/unit_test_machine_real
	var/mob/living/carbon/human/H = new(locate(1, 1, 1))
	H.mind = null
	if (source.Open_mindUI(H) != FALSE)
		fail("expected Open_mindUI to return FALSE when user.mind is null")
	qdel(source)
	qdel(H)

/datum/unit_test/mindui_machine/open_mindui_creates_ui_instance
	name = "mindUI Open_mindUI registers the typed UI in mind.activeUIs"

/datum/unit_test/mindui_machine/open_mindui_creates_ui_instance/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/obj/source = new(get_turf(H))
	source.mind_ui_type = /datum/mind_ui/machine/unit_test_machine_real
	if (source.Open_mindUI(H) != TRUE)
		fail("expected Open_mindUI to return TRUE when mind_ui_type and user.mind are set")
	if (!("unit_test_machine_real" in H.mind.activeUIs))
		fail("expected the spawned UI to register itself in mind.activeUIs under its uniqueID")
	var/datum/mind_ui/machine/U = H.mind.activeUIs["unit_test_machine_real"]
	if (!istype(U, /datum/mind_ui/machine/unit_test_machine_real))
		fail("expected the registered UI to be /datum/mind_ui/machine/unit_test_machine_real")
	U.Cleanup()
	qdel(source)
	qdel(H)

////////////////////////////////////////////////////////////////////
// ADMIN TOOLING
////////////////////////////////////////////////////////////////////

/datum/mind_ui/unit_test_admin_host
	abstract = TRUE
	uniqueID = "unit_test_admin_host"

/datum/mind_ui/unit_test_admin_host/New(datum/mind/M)
	mind = M

/obj/abstract/mind_ui_element/unit_test_admin_element

/obj/abstract/mind_ui_element/unit_test_admin_element/New()
	return

/datum/unit_test/mindui_admin/inspector_overlay_add_remove
	name = "mindUI inspector - Add/RemoveInspectorOverlay toggles _inspector_overlay handle"

/datum/unit_test/mindui_admin/inspector_overlay_add_remove/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_admin_host/U = new(H.mind)
	var/obj/abstract/mind_ui_element/unit_test_admin_element/E = new()
	E.AddInspectorOverlay(U)
	if (E._inspector_overlay == null)
		fail("AddInspectorOverlay did not set _inspector_overlay")
	E.RemoveInspectorOverlay()
	assert_eq(E._inspector_overlay, null)
	E.RemoveInspectorOverlay()
	assert_eq(E._inspector_overlay, null)
	E.AddInspectorOverlay(U)
	var/first = E._inspector_overlay
	E.AddInspectorOverlay(U)
	if (E._inspector_overlay == first)
		fail("Second AddInspectorOverlay did not replace the prior overlay handle")
	E.RemoveInspectorOverlay()
	qdel(E)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_admin/schema_dump_builds_lines
	name = "mindUI schema dump - BuildSchemaDumpLines returns header + per-element rows"

/datum/unit_test/mindui_admin/schema_dump_builds_lines/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_admin_host/U = new(H.mind)
	var/obj/abstract/mind_ui_element/unit_test_admin_element/E1 = new()
	var/obj/abstract/mind_ui_element/unit_test_admin_element/E2 = new()
	U.elements = list(E1, E2)
	var/list/lines = U.BuildSchemaDumpLines()
	if (!islist(lines))
		fail("BuildSchemaDumpLines returned non-list")
		qdel(E1)
		qdel(E2)
		qdel(U)
		qdel(H)
		return
	// Header (UI line) + Elements count + Active/AutoDisplay + Validator + 2 element rows = 6.
	assert_eq(lines.len, 6)
	if (findtext(lines[1], "unit_test_admin_host") == 0)
		fail("First dump line missing uniqueID. Got: [lines[1]]")
	if (findtext(lines[6], "unit_test_admin_element") == 0)
		fail("Element row missing element type. Got: [lines[6]]")
	qdel(E1)
	qdel(E2)
	qdel(U)
	qdel(H)

////////////////////////////////////////////////////////////////////
// BUTTON
////////////////////////////////////////////////////////////////////

/datum/mindui_button_test_target
	var/call_count = 0
	var/last_arg = null

/datum/mindui_button_test_target/proc/Increment(arg)
	call_count++
	last_arg = arg

/datum/mind_ui/unit_test_button_host
	abstract = TRUE
	uniqueID = "unit_test_button_host"

/datum/mind_ui/unit_test_button_host/New(datum/mind/M)
	mind = M

/datum/unit_test/mindui_button/click_invokes_callback
	name = "mindUI button - Click invokes the bound callback"

/datum/unit_test/mindui_button/click_invokes_callback/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_button_host/U = new(H.mind)
	var/datum/mindui_button_test_target/T = new
	var/obj/abstract/mind_ui_element/hoverable/button/B = new(null, U)
	B.callback = new /callback(T, TYPE_PROC_REF(/datum/mindui_button_test_target, Increment), "clicked")
	B.Click()
	assert_eq(T.call_count, 1)
	assert_eq(T.last_arg, "clicked")
	qdel(B)
	qdel(T)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_button/click_without_callback_does_not_crash
	name = "mindUI button - Click without callback returns cleanly"

/datum/unit_test/mindui_button/click_without_callback_does_not_crash/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_button_host/U = new(H.mind)
	var/obj/abstract/mind_ui_element/hoverable/button/B = new(null, U)
	B.callback = null
	B.Click()
	qdel(B)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_button/addbutton_appends_to_elements
	name = "mindUI AddButton - element is appended to UI.elements and returned"

/datum/unit_test/mindui_button/addbutton_appends_to_elements/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_button_host/U = new(H.mind)
	var/datum/mindui_button_test_target/T = new
	var/before = U.elements.len
	var/obj/abstract/mind_ui_element/hoverable/button/B = U.AddButton('icons/ui/32x32.dmi', "close", 80, 16, new /callback(T, TYPE_PROC_REF(/datum/mindui_button_test_target, Increment), null))
	if (!B)
		fail("AddButton returned null")
	assert_eq(U.elements.len, before + 1)
	assert_eq(B.icon_state, "close")
	assert_eq(B.offset_x, 80)
	assert_eq(B.offset_y, 16)
	qdel(T)
	qdel(U)
	qdel(H)

////////////////////////////////////////////////////////////////////
// CHECKBOX
////////////////////////////////////////////////////////////////////

/datum/mindui_checkbox_test_target
	var/last_state = null
	var/toggle_count = 0

/datum/mindui_checkbox_test_target/proc/OnToggle(state)
	last_state = state
	toggle_count++

/datum/mind_ui/unit_test_checkbox_host
	abstract = TRUE
	uniqueID = "unit_test_checkbox_host"

/datum/mind_ui/unit_test_checkbox_host/New(datum/mind/M)
	mind = M

/datum/unit_test/mindui_checkbox/click_flips_state
	name = "mindUI checkbox - Click flips checked state"

/datum/unit_test/mindui_checkbox/click_flips_state/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_checkbox_host/U = new(H.mind)
	var/obj/abstract/mind_ui_element/hoverable/checkbox/C = new(null, U)
	C.checked = FALSE
	C.Click()
	assert_eq(C.checked, TRUE)
	C.Click()
	assert_eq(C.checked, FALSE)
	qdel(C)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_checkbox/click_invokes_on_toggle
	name = "mindUI checkbox - Click invokes on_toggle with new state"

/datum/unit_test/mindui_checkbox/click_invokes_on_toggle/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_checkbox_host/U = new(H.mind)
	var/datum/mindui_checkbox_test_target/T = new
	var/obj/abstract/mind_ui_element/hoverable/checkbox/C = new(null, U)
	C.checked = FALSE
	C.on_toggle = new /callback(T, TYPE_PROC_REF(/datum/mindui_checkbox_test_target, OnToggle))
	C.Click()
	assert_eq(T.toggle_count, 1)
	assert_eq(T.last_state, TRUE)
	qdel(C)
	qdel(T)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_checkbox/icon_state_reflects_checked
	name = "mindUI checkbox - icon_state uses on_state when checked, off_state otherwise"

/datum/unit_test/mindui_checkbox/icon_state_reflects_checked/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_checkbox_host/U = new(H.mind)
	var/obj/abstract/mind_ui_element/hoverable/checkbox/C = new(null, U)
	C.off_state = "checkbox-off"
	C.on_state = "checkbox-on"
	C.checked = FALSE
	C.UpdateIcon()
	assert_eq(C.icon_state, "checkbox-off")
	C.checked = TRUE
	C.UpdateIcon()
	assert_eq(C.icon_state, "checkbox-on")
	qdel(C)
	qdel(U)
	qdel(H)

////////////////////////////////////////////////////////////////////
// GAUGE
////////////////////////////////////////////////////////////////////

/datum/mind_ui/unit_test_gauge_host
	abstract = TRUE
	uniqueID = "unit_test_gauge_host"

/datum/mind_ui/unit_test_gauge_host/New(datum/mind/M)
	mind = M

/obj/abstract/mind_ui_element/gauge/unit_test_gauge_fixed
	direction = "vertical"
	gauge_length = 200

/obj/abstract/mind_ui_element/gauge/unit_test_gauge_fixed/ReadValue()
	return 5

/obj/abstract/mind_ui_element/gauge/unit_test_gauge_fixed/ReadMax()
	return 10

/datum/unit_test/mindui_gauge/read_value_and_max_via_overrides
	name = "mindUI gauge - ReadValue and ReadMax return overridden values"

/datum/unit_test/mindui_gauge/read_value_and_max_via_overrides/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_gauge_host/U = new(H.mind)
	var/obj/abstract/mind_ui_element/gauge/unit_test_gauge_fixed/G = new(null, U)
	assert_eq(G.ReadValue(), 5)
	assert_eq(G.ReadMax(), 10)
	qdel(G)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_gauge/default_read_returns_zero
	name = "mindUI gauge - default ReadValue / ReadMax return 0"

/datum/unit_test/mindui_gauge/default_read_returns_zero/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_gauge_host/U = new(H.mind)
	var/obj/abstract/mind_ui_element/gauge/G = new(null, U)
	assert_eq(G.ReadValue(), 0)
	assert_eq(G.ReadMax(), 0)
	qdel(G)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_gauge/update_icon_with_zero_max_returns_early
	name = "mindUI gauge - UpdateIcon with max=0 returns without crashing"

/datum/unit_test/mindui_gauge/update_icon_with_zero_max_returns_early/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_gauge_host/U = new(H.mind)
	var/obj/abstract/mind_ui_element/gauge/G = new(null, U)
	G.UpdateIcon()
	qdel(G)
	qdel(U)
	qdel(H)

////////////////////////////////////////////////////////////////////
// TAB
////////////////////////////////////////////////////////////////////

/datum/mindui_tab_test_target
	var/last_tab = null
	var/call_count = 0

/datum/mindui_tab_test_target/proc/OnTabChange(new_tab)
	last_tab = new_tab
	call_count++

/datum/mind_ui/unit_test_tab_host
	abstract = TRUE
	uniqueID = "unit_test_tab_host"

/datum/mind_ui/unit_test_tab_host/New(datum/mind/M)
	mind = M

/datum/unit_test/mindui_tab/click_activates_tab
	name = "mindUI tab - Click sets host active_tab to tab_id"

/datum/unit_test/mindui_tab/click_activates_tab/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_tab_host/U = new(H.mind)
	var/obj/abstract/mind_ui_element/hoverable/tab/T = new(null, U)
	T.tab_id = "alpha"
	U.active_tab = ""
	T.Click()
	assert_eq(U.active_tab, "alpha")
	qdel(T)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_tab/set_active_tab_invokes_callback
	name = "mindUI SetActiveTab - on_tab_change callback fires with new tab_id"

/datum/unit_test/mindui_tab/set_active_tab_invokes_callback/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_tab_host/U = new(H.mind)
	var/datum/mindui_tab_test_target/Target = new
	U.on_tab_change = new /callback(Target, TYPE_PROC_REF(/datum/mindui_tab_test_target, OnTabChange))
	U.SetActiveTab("beta")
	assert_eq(Target.call_count, 1)
	assert_eq(Target.last_tab, "beta")
	qdel(Target)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_tab/set_active_tab_refreshes_icons
	name = "mindUI SetActiveTab - tab elements repaint active vs inactive"

/datum/unit_test/mindui_tab/set_active_tab_refreshes_icons/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_tab_host/U = new(H.mind)
	var/obj/abstract/mind_ui_element/hoverable/tab/A = new(null, U)
	A.tab_id = "alpha"
	A.active_state = "alpha-on"
	A.inactive_state = "alpha-off"
	var/obj/abstract/mind_ui_element/hoverable/tab/B = new(null, U)
	B.tab_id = "beta"
	B.active_state = "beta-on"
	B.inactive_state = "beta-off"
	U.elements += A
	U.elements += B
	U.SetActiveTab("alpha")
	assert_eq(A.icon_state, "alpha-on")
	assert_eq(B.icon_state, "beta-off")
	U.SetActiveTab("beta")
	assert_eq(A.icon_state, "alpha-off")
	assert_eq(B.icon_state, "beta-on")
	qdel(A)
	qdel(B)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_tab/addtab_factory
	name = "mindUI AddTab - factory creates a tab and appends to elements"

/datum/unit_test/mindui_tab/addtab_factory/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_tab_host/U = new(H.mind)
	var/before = U.elements.len
	var/obj/abstract/mind_ui_element/hoverable/tab/T = U.AddTab('icons/ui/32x32.dmi', "alpha-off", "alpha-on", 0, 0, "alpha")
	if (!T)
		fail("AddTab returned null")
	assert_eq(U.elements.len, before + 1)
	assert_eq(T.tab_id, "alpha")
	assert_eq(T.inactive_state, "alpha-off")
	assert_eq(T.active_state, "alpha-on")
	qdel(U)
	qdel(H)

////////////////////////////////////////////////////////////////////
// TEXT INPUT
////////////////////////////////////////////////////////////////////

/datum/mindui_text_input_test_target
	var/received = null
	var/call_count = 0

/datum/mindui_text_input_test_target/proc/OnChange(new_value)
	received = new_value
	call_count++

/datum/mind_ui/unit_test_text_input_host
	abstract = TRUE
	uniqueID = "unit_test_text_input_host"

/datum/mind_ui/unit_test_text_input_host/New(datum/mind/M)
	mind = M

/datum/unit_test/mindui_text_input/set_value_stores_value
	name = "mindUI text_input - SetValue stores new value"

/datum/unit_test/mindui_text_input/set_value_stores_value/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_text_input_host/U = new(H.mind)
	var/obj/abstract/mind_ui_element/hoverable/text_input/I = new(null, U)
	I.current_value = "old"
	I.SetValue("new")
	assert_eq(I.current_value, "new")
	qdel(I)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_text_input/set_value_invokes_on_change
	name = "mindUI text_input - SetValue invokes on_change with new value"

/datum/unit_test/mindui_text_input/set_value_invokes_on_change/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_text_input_host/U = new(H.mind)
	var/datum/mindui_text_input_test_target/T = new
	var/obj/abstract/mind_ui_element/hoverable/text_input/I = new(null, U)
	I.on_change = new /callback(T, TYPE_PROC_REF(/datum/mindui_text_input_test_target, OnChange))
	I.SetValue("hello")
	assert_eq(T.call_count, 1)
	assert_eq(T.received, "hello")
	qdel(T)
	qdel(I)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_text_input/set_value_null_is_noop
	name = "mindUI text_input - SetValue(null) does not change state or fire callback"

/datum/unit_test/mindui_text_input/set_value_null_is_noop/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_text_input_host/U = new(H.mind)
	var/datum/mindui_text_input_test_target/T = new
	var/obj/abstract/mind_ui_element/hoverable/text_input/I = new(null, U)
	I.current_value = "keep"
	I.on_change = new /callback(T, TYPE_PROC_REF(/datum/mindui_text_input_test_target, OnChange))
	I.SetValue(null)
	assert_eq(I.current_value, "keep")
	assert_eq(T.call_count, 0)
	qdel(T)
	qdel(I)
	qdel(U)
	qdel(H)

////////////////////////////////////////////////////////////////////
// SLIDER
////////////////////////////////////////////////////////////////////

/datum/mindui_slider_test_target
	var/last_value = null
	var/call_count = 0

/datum/mindui_slider_test_target/proc/OnChange(new_value)
	last_value = new_value
	call_count++

/datum/mind_ui/unit_test_slider_host
	abstract = TRUE
	uniqueID = "unit_test_slider_host"

/datum/mind_ui/unit_test_slider_host/New(datum/mind/M)
	mind = M

/datum/unit_test/mindui_slider/step_up_increments_clamped
	name = "mindUI slider - StepUp increments and clamps to max_value"

/datum/unit_test/mindui_slider/step_up_increments_clamped/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_slider_host/U = new(H.mind)
	var/obj/abstract/mind_ui_element/hoverable/slider/S = new(null, U)
	S.min_value = 0
	S.max_value = 3
	S.step = 1
	S.value = 2
	S.StepUp()
	assert_eq(S.value, 3)
	S.StepUp()
	assert_eq(S.value, 3)
	qdel(S)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_slider/step_down_decrements_clamped
	name = "mindUI slider - StepDown decrements and clamps to min_value"

/datum/unit_test/mindui_slider/step_down_decrements_clamped/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_slider_host/U = new(H.mind)
	var/obj/abstract/mind_ui_element/hoverable/slider/S = new(null, U)
	S.min_value = 0
	S.max_value = 3
	S.step = 1
	S.value = 1
	S.StepDown()
	assert_eq(S.value, 0)
	S.StepDown()
	assert_eq(S.value, 0)
	qdel(S)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_slider/set_value_fires_callback_on_change
	name = "mindUI slider - SetValue invokes on_change only when value actually changes"

/datum/unit_test/mindui_slider/set_value_fires_callback_on_change/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_slider_host/U = new(H.mind)
	var/datum/mindui_slider_test_target/T = new
	var/obj/abstract/mind_ui_element/hoverable/slider/S = new(null, U)
	S.min_value = 0
	S.max_value = 10
	S.step = 1
	S.value = 5
	S.on_change = new /callback(T, TYPE_PROC_REF(/datum/mindui_slider_test_target, OnChange))
	S.SetValue(5)
	assert_eq(T.call_count, 0)
	S.SetValue(7)
	assert_eq(T.call_count, 1)
	assert_eq(T.last_value, 7)
	qdel(T)
	qdel(S)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_slider/onclickat_routes_to_step
	name = "mindUI slider - OnClickAt picks StepUp/StepDown by coord vs center"

/datum/unit_test/mindui_slider/onclickat_routes_to_step/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_slider_host/U = new(H.mind)
	var/obj/abstract/mind_ui_element/hoverable/slider/S = new(null, U)
	S.min_value = 0
	S.max_value = 10
	S.step = 1
	S.value = 5
	S.icon_center = 16
	S.OnClickAt(20)
	assert_eq(S.value, 6)
	S.OnClickAt(5)
	assert_eq(S.value, 5)
	qdel(S)
	qdel(U)
	qdel(H)

////////////////////////////////////////////////////////////////////
// COMPOSITE COMPONENTS: window, dropdown, virtual_list, radio_group, canvas
////////////////////////////////////////////////////////////////////

/datum/mindui_components_test_target
	var/call_count = 0
	var/last_arg = null
	var/list/render_log = list()

/datum/mindui_components_test_target/proc/Capture(arg)
	call_count++
	last_arg = arg

/datum/mindui_components_test_target/proc/RenderRow(obj/abstract/mind_ui_element/row, data_item, row_index)
	render_log += list(list("row" = row, "data" = data_item, "index" = row_index))

/datum/mind_ui/unit_test_components_host
	abstract = TRUE
	uniqueID = "unit_test_components_host"

/datum/mind_ui/unit_test_components_host/New(datum/mind/M)
	mind = M

/datum/mind_ui/window/unit_test_window
	uniqueID = "unit_test_window"
	width = 192
	height = 192
	window_flags = MINDUI_WINDOW_CLOSABLE | MINDUI_WINDOW_MOVABLE

/datum/mind_ui/window/unit_test_window/New(datum/mind/M)
	mind = M

/datum/unit_test/mindui_window/spawns_close_button_at_expected_offset
	name = "mindUI window - SpawnElements places close button at (width/2 - 16, height/2 - 16)"

/datum/unit_test/mindui_window/spawns_close_button_at_expected_offset/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/window/unit_test_window/W = new(H.mind)
	W.SpawnElements()
	var/obj/abstract/mind_ui_element/hoverable/window_close/close = null
	for (var/obj/abstract/mind_ui_element/hoverable/window_close/c in W.elements)
		close = c
		break
	if (!close)
		fail("Window did not spawn a close button when MINDUI_WINDOW_CLOSABLE was set")
		qdel(W)
		qdel(H)
		return
	assert_eq(close.offset_x, round(W.width/2) - 16)
	assert_eq(close.offset_y, round(W.height/2) - 16)
	qdel(W)
	qdel(H)

/datum/unit_test/mindui_dropdown/select_sets_index_and_fires_callback
	name = "mindUI dropdown - Select() updates index, fires callback, and closes"

/datum/unit_test/mindui_dropdown/select_sets_index_and_fires_callback/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_components_host/U = new(H.mind)
	var/datum/mindui_components_test_target/T = new
	var/obj/abstract/mind_ui_element/hoverable/dropdown/D = new(null, U)
	D.options = list("alpha", "beta", "gamma")
	D.selected_index = 1
	D.is_open = TRUE
	D.on_select = new /callback(T, TYPE_PROC_REF(/datum/mindui_components_test_target, Capture))
	D.Select(2)
	assert_eq(D.selected_index, 2)
	assert_eq(T.call_count, 1)
	assert_eq(T.last_arg, "beta")
	assert_eq(D.is_open, FALSE)
	qdel(D)
	qdel(T)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_virtual_list/refresh_binds_rows
	name = "mindUI virtual_list - Refresh invokes render_row for each visible slot"

/datum/unit_test/mindui_virtual_list/refresh_binds_rows/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_components_host/U = new(H.mind)
	var/datum/mindui_components_test_target/T = new
	var/obj/abstract/mind_ui_element/virtual_list/V = new(null, U)
	V.data_source = list("a","b","c","d","e","f","g")
	V.row_count = 3
	V.scroll_offset = 2
	V.render_row = new /callback(T, TYPE_PROC_REF(/datum/mindui_components_test_target, RenderRow))
	V.Refresh()
	assert_eq(T.render_log.len, 3)
	var/list/entry1 = T.render_log[1]
	var/list/entry2 = T.render_log[2]
	var/list/entry3 = T.render_log[3]
	assert_eq(entry1["data"], "c")
	assert_eq(entry2["data"], "d")
	assert_eq(entry3["data"], "e")
	assert_eq(entry1["index"], 1)
	assert_eq(entry2["index"], 2)
	assert_eq(entry3["index"], 3)
	qdel(V)
	qdel(T)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_virtual_list/scroll_clamps
	name = "mindUI virtual_list - ScrollBy clamps to \[0, len - row_count\]"

/datum/unit_test/mindui_virtual_list/scroll_clamps/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_components_host/U = new(H.mind)
	var/obj/abstract/mind_ui_element/virtual_list/V = new(null, U)
	V.data_source = list("a","b","c","d","e")
	V.row_count = 3
	V.scroll_offset = 0
	V.ScrollBy(-5)
	assert_eq(V.scroll_offset, 0)
	V.ScrollBy(100)
	assert_eq(V.scroll_offset, 2)
	V.ScrollBy(-1)
	assert_eq(V.scroll_offset, 1)
	qdel(V)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_radio_group/select_unchecks_others
	name = "mindUI radio_group - Select unchecks every other member, fires callback"

/datum/unit_test/mindui_radio_group/select_unchecks_others/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_components_host/U = new(H.mind)
	var/datum/mindui_components_test_target/T = new
	var/obj/abstract/mind_ui_element/hoverable/checkbox/A = new(null, U)
	var/obj/abstract/mind_ui_element/hoverable/checkbox/B = new(null, U)
	var/obj/abstract/mind_ui_element/hoverable/checkbox/C = new(null, U)
	A.checked = TRUE
	B.checked = FALSE
	C.checked = TRUE
	var/datum/mindui_radio_group/G = new
	G.on_change = new /callback(T, TYPE_PROC_REF(/datum/mindui_components_test_target, Capture))
	G.Register(A, "a")
	G.Register(B, "b")
	G.Register(C, "c")
	G.Select("b")
	assert_eq(A.checked, FALSE)
	assert_eq(B.checked, TRUE)
	assert_eq(C.checked, FALSE)
	assert_eq(G.selected_id, "b")
	assert_eq(T.call_count, 1)
	assert_eq(T.last_arg, "b")
	qdel(G)
	qdel(A)
	qdel(B)
	qdel(C)
	qdel(T)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_canvas/plot_and_clear
	name = "mindUI canvas - Plot, DrawBox, and Clear run without crashing"

/datum/unit_test/mindui_canvas/plot_and_clear/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_components_host/U = new(H.mind)
	var/obj/abstract/mind_ui_element/canvas/CV = new(null, U)
	CV.Plot(5, 5, "#FF0000")
	CV.DrawBox(1, 1, 10, 10, "#00FF00")
	CV.Clear()
	if (!CV.canvas_icon)
		fail("canvas_icon is null after Clear()")
	qdel(CV)
	qdel(U)
	qdel(H)

////////////////////////////////////////////////////////////////////
// INTERACTIVITY: modifier clicks, wheel, drag-drop, state, context menus
////////////////////////////////////////////////////////////////////

/datum/mindui_interactivity_target
	var/call_count = 0
	var/last_arg = null
	var/last_delta = 0
	var/last_source = null

/datum/mindui_interactivity_target/proc/Increment(arg)
	call_count++
	last_arg = arg

/datum/mindui_interactivity_target/proc/CaptureDelta(delta)
	call_count++
	last_delta = delta

/datum/mindui_interactivity_target/proc/CaptureSource(source)
	call_count++
	last_source = source

/datum/mind_ui/unit_test_interactivity_host
	abstract = TRUE
	uniqueID = "unit_test_interactivity_host"

/datum/mind_ui/unit_test_interactivity_host/New(datum/mind/M)
	mind = M

/obj/abstract/mind_ui_element/hoverable/unit_test_modifier
	var/shift_calls = 0
	var/ctrl_calls = 0
	var/alt_calls = 0

/obj/abstract/mind_ui_element/hoverable/unit_test_modifier/New()
	return

/obj/abstract/mind_ui_element/hoverable/unit_test_modifier/ShiftClick(mob/user)
	shift_calls++

/obj/abstract/mind_ui_element/hoverable/unit_test_modifier/CtrlClick(mob/user)
	ctrl_calls++

/obj/abstract/mind_ui_element/hoverable/unit_test_modifier/AltClick(mob/user)
	alt_calls++

/obj/abstract/mind_ui_element/unit_test_wheel
	var/last_wheel_delta = null
	var/wheel_calls = 0

/obj/abstract/mind_ui_element/unit_test_wheel/New()
	return

/obj/abstract/mind_ui_element/unit_test_wheel/Wheel(delta)
	wheel_calls++
	last_wheel_delta = delta

/obj/abstract/mind_ui_element/hoverable/unit_test_state
/obj/abstract/mind_ui_element/hoverable/unit_test_state/New()
	return

/datum/unit_test/mindui_interactivity/modifier_shift_click_dispatches
	name = "mindUI HandleModifiers - shift dispatches to ShiftClick and returns TRUE"

/datum/unit_test/mindui_interactivity/modifier_shift_click_dispatches/start()
	var/obj/abstract/mind_ui_element/hoverable/unit_test_modifier/E = new
	var/handled = E.HandleModifiers("shift=1")
	assert_eq(handled, TRUE)
	assert_eq(E.shift_calls, 1)
	assert_eq(E.ctrl_calls, 0)
	assert_eq(E.alt_calls, 0)
	qdel(E)

/datum/unit_test/mindui_interactivity/modifier_ctrl_click_dispatches
	name = "mindUI HandleModifiers - ctrl dispatches to CtrlClick"

/datum/unit_test/mindui_interactivity/modifier_ctrl_click_dispatches/start()
	var/obj/abstract/mind_ui_element/hoverable/unit_test_modifier/E = new
	var/handled = E.HandleModifiers("ctrl=1")
	assert_eq(handled, TRUE)
	assert_eq(E.ctrl_calls, 1)
	qdel(E)

/datum/unit_test/mindui_interactivity/modifier_alt_click_dispatches
	name = "mindUI HandleModifiers - alt dispatches to AltClick"

/datum/unit_test/mindui_interactivity/modifier_alt_click_dispatches/start()
	var/obj/abstract/mind_ui_element/hoverable/unit_test_modifier/E = new
	var/handled = E.HandleModifiers("alt=1")
	assert_eq(handled, TRUE)
	assert_eq(E.alt_calls, 1)
	qdel(E)

/datum/unit_test/mindui_interactivity/modifier_no_modifier_returns_false
	name = "mindUI HandleModifiers - empty params returns FALSE and dispatches nothing"

/datum/unit_test/mindui_interactivity/modifier_no_modifier_returns_false/start()
	var/obj/abstract/mind_ui_element/hoverable/unit_test_modifier/E = new
	var/handled = E.HandleModifiers("")
	assert_eq(handled, FALSE)
	assert_eq(E.shift_calls, 0)
	assert_eq(E.ctrl_calls, 0)
	assert_eq(E.alt_calls, 0)
	qdel(E)

/datum/unit_test/mindui_interactivity/wheel_dispatches_to_wheel_proc
	name = "mindUI MouseWheel - delta_y is forwarded to Wheel(delta)"

/datum/unit_test/mindui_interactivity/wheel_dispatches_to_wheel_proc/start()
	var/obj/abstract/mind_ui_element/unit_test_wheel/E = new
	E.MouseWheel(0, 1, null, null, "")
	assert_eq(E.wheel_calls, 1)
	assert_eq(E.last_wheel_delta, 1)
	E.MouseWheel(0, -2, null, null, "")
	assert_eq(E.wheel_calls, 2)
	assert_eq(E.last_wheel_delta, -2)
	qdel(E)

/datum/unit_test/mindui_interactivity/virtual_list_wheel_scrolls
	name = "mindUI virtual_list - Wheel(1) scrolls forward by one row"

/datum/unit_test/mindui_interactivity/virtual_list_wheel_scrolls/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_interactivity_host/U = new(H.mind)
	var/obj/abstract/mind_ui_element/virtual_list/V = new(null, U)
	V.data_source = list("a", "b", "c", "d", "e", "f", "g")
	V.row_count = 3
	V.Refresh()
	V.Wheel(1)
	assert_eq(V.scroll_offset, 1)
	V.Wheel(-1)
	assert_eq(V.scroll_offset, 0)
	qdel(V)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_interactivity/drop_target_invokes_callback
	name = "mindUI TryDispatchDrop - receiver with can_receive_drops fires on_drop"

/datum/unit_test/mindui_interactivity/drop_target_invokes_callback/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_interactivity_host/U = new(H.mind)
	var/datum/mindui_interactivity_target/T = new
	var/obj/abstract/mind_ui_element/source = new(null, U)
	var/obj/abstract/mind_ui_element/target = new(null, U)
	target.can_receive_drops = TRUE
	target.on_drop = new /callback(T, TYPE_PROC_REF(/datum/mindui_interactivity_target, CaptureSource))

	var/dispatched = source.TryDispatchDrop(target)
	assert_eq(dispatched, TRUE)
	assert_eq(T.call_count, 1)
	assert_eq(T.last_source, source)

	qdel(source)
	qdel(target)
	qdel(T)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_interactivity/drop_without_target_returns_false
	name = "mindUI TryDispatchDrop - non-element over_object returns FALSE"

/datum/unit_test/mindui_interactivity/drop_without_target_returns_false/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_interactivity_host/U = new(H.mind)
	var/obj/abstract/mind_ui_element/source = new(null, U)
	var/dispatched = source.TryDispatchDrop(null)
	assert_eq(dispatched, FALSE)
	qdel(source)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_interactivity/state_machine_set_state_updates_icon
	name = "mindUI SetState - icon_state is rewritten from the state_icons template"

/datum/unit_test/mindui_interactivity/state_machine_set_state_updates_icon/start()
	var/obj/abstract/mind_ui_element/hoverable/unit_test_state/E = new
	E.base_icon_state = "close"
	E.state_icons = list(
		MINDUI_STATE_IDLE = "%",
		MINDUI_STATE_HOVER = "%-hover",
		MINDUI_STATE_PRESSED = "%-pressed",
		MINDUI_STATE_DISABLED = "%-disabled",
	)

	E.SetState(MINDUI_STATE_HOVER)
	assert_eq(E.current_state, MINDUI_STATE_HOVER)
	assert_eq(E.icon_state, "close-hover")

	E.SetState(MINDUI_STATE_PRESSED)
	assert_eq(E.icon_state, "close-pressed")

	E.SetState(MINDUI_STATE_IDLE)
	assert_eq(E.icon_state, "close")

	qdel(E)

/datum/unit_test/mindui_interactivity/state_machine_no_state_icons_is_noop
	name = "mindUI SetState - no state_icons leaves icon_state unchanged"

/datum/unit_test/mindui_interactivity/state_machine_no_state_icons_is_noop/start()
	var/obj/abstract/mind_ui_element/hoverable/unit_test_state/E = new
	E.icon_state = "original"
	E.base_icon_state = "original"
	E.state_icons = null
	E.SetState(MINDUI_STATE_HOVER)
	assert_eq(E.current_state, MINDUI_STATE_HOVER)
	assert_eq(E.icon_state, "original")
	qdel(E)

// Context-menu test needs parent New to run so context_menu / sub-UI allocation work.
/obj/abstract/mind_ui_element/hoverable/unit_test_ctxmenu_host
/obj/abstract/mind_ui_element/hoverable/unit_test_ctxmenu_host/New(turf/loc, datum/mind_ui/P)
	..()

/datum/unit_test/mindui_interactivity/context_menu_open_creates_buttons
	name = "mindUI ShowContextMenu - opens a sub-UI with one button per entry"

/datum/unit_test/mindui_interactivity/context_menu_open_creates_buttons/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/unit_test_interactivity_host/U = new(H.mind)
	var/datum/mindui_interactivity_target/T = new
	var/obj/abstract/mind_ui_element/hoverable/unit_test_ctxmenu_host/E = new(null, U)
	E.context_menu = list(
		"Open" = new /callback(T, TYPE_PROC_REF(/datum/mindui_interactivity_target, Increment), "open"),
		"Close" = new /callback(T, TYPE_PROC_REF(/datum/mindui_interactivity_target, Increment), "close"),
	)
	var/datum/mind_ui/context_menu/menu = E.ShowContextMenu("right=1")
	if (!istype(menu))
		fail("ShowContextMenu returned non-context_menu UI")
		qdel(E)
		qdel(T)
		qdel(U)
		qdel(H)
		return

	assert_eq(menu.entries.len, 2)
	var/button_count = 0
	for (var/obj/abstract/mind_ui_element/hoverable/button/B in menu.elements)
		button_count++
	assert_eq(button_count, 2)

	qdel(menu)
	qdel(E)
	qdel(T)
	qdel(U)
	qdel(H)

////////////////////////////////////////////////////////////////////
// QOL: window pin/minimize, stack manager
////////////////////////////////////////////////////////////////////

/datum/mind_ui/window/unit_test_qol_window
	uniqueID = "unit_test_qol_window"
	width = 192
	height = 192
	window_flags = MINDUI_WINDOW_CLOSABLE | MINDUI_WINDOW_MOVABLE | MINDUI_WINDOW_PINNABLE | MINDUI_WINDOW_MINIMIZE

/datum/mind_ui/window/unit_test_qol_window/New(datum/mind/M)
	mind = M

/datum/unit_test/mindui_qol/window_minimize_hides_content_elements
	name = "mindUI window - ApplyMinimize hides non-chrome elements, restore shows them"

/datum/unit_test/mindui_qol/window_minimize_hides_content_elements/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/window/unit_test_qol_window/W = new(H.mind)
	W.SpawnElements()
	var/obj/abstract/mind_ui_element/hoverable/checkbox/content = new(null, W)
	W.elements += content
	W.minimized = FALSE
	W.ApplyMinimize()
	assert_eq(content.invisibility, 0)
	W.minimized = TRUE
	W.ApplyMinimize()
	assert_eq(content.invisibility, 101)
	var/obj/abstract/mind_ui_element/hoverable/window_close/close_btn = null
	for (var/obj/abstract/mind_ui_element/hoverable/window_close/c in W.elements)
		close_btn = c
		break
	if (!close_btn)
		fail("Window did not spawn a close button - test harness misconfigured")
	else
		assert_eq(close_btn.invisibility, 0)
	W.minimized = FALSE
	W.ApplyMinimize()
	assert_eq(content.invisibility, 0)
	qdel(W)
	qdel(H)

/datum/unit_test/mindui_qol/window_pin_click_toggles_flag
	name = "mindUI window - window_pin/Click toggles parent.pinned"

/datum/unit_test/mindui_qol/window_pin_click_toggles_flag/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/window/unit_test_qol_window/W = new(H.mind)
	W.SpawnElements()
	var/obj/abstract/mind_ui_element/hoverable/window_pin/pin = null
	for (var/obj/abstract/mind_ui_element/hoverable/window_pin/p in W.elements)
		pin = p
		break
	if (!pin)
		fail("Window did not spawn a pin button when MINDUI_WINDOW_PINNABLE was set")
		qdel(W)
		qdel(H)
		return
	assert_eq(W.pinned, FALSE)
	pin.Click()
	assert_eq(W.pinned, TRUE)
	pin.Click()
	assert_eq(W.pinned, FALSE)
	qdel(W)
	qdel(H)

// Sentinel UI: counts Hide() calls so eviction is observable without inspecting client.screen.
/datum/mind_ui/unit_test_qol_sentinel
	abstract = TRUE
	uniqueID = "unit_test_qol_sentinel"
	var/hide_count = 0

/datum/mind_ui/unit_test_qol_sentinel/New(datum/mind/M)
	mind = M

/datum/mind_ui/unit_test_qol_sentinel/Hide(var/override = FALSE)
	hide_count++

// Pinned variant: inherits from /datum/mind_ui/window so IsPinnedUI's istype check succeeds.
/datum/mind_ui/window/unit_test_qol_pinned_sentinel
	uniqueID = "unit_test_qol_pinned_sentinel"
	var/hide_count = 0

/datum/mind_ui/window/unit_test_qol_pinned_sentinel/New(datum/mind/M)
	mind = M
	pinned = TRUE

/datum/mind_ui/window/unit_test_qol_pinned_sentinel/Hide(var/override = FALSE)
	hide_count++

/datum/unit_test/mindui_qol/stack_manager_evicts_oldest_unpinned
	name = "mindUI stack_manager - EnforceVisibleCapOnList evicts oldest unpinned UI past the cap"

/datum/unit_test/mindui_qol/stack_manager_evicts_oldest_unpinned/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/list/order = list()
	var/list/uis = list()
	for (var/i = 1 to 6)
		var/datum/mind_ui/unit_test_qol_sentinel/U = new(H.mind)
		uis += U
		order.Insert(1, U)
	uis[1].EnforceVisibleCapOnList(order, 5)
	var/datum/mind_ui/unit_test_qol_sentinel/oldest = uis[1]
	assert_eq(oldest.hide_count, 1)
	assert_eq(order.len, 5)
	if (oldest in order)
		fail("Oldest unpinned UI still in display_order after EnforceVisibleCapOnList")
	for (var/datum/mind_ui/U in uis)
		qdel(U)
	qdel(H)

/datum/unit_test/mindui_qol/stack_manager_skips_pinned
	name = "mindUI stack_manager - EnforceVisibleCapOnList skips pinned UIs and evicts the next unpinned tail entry"

/datum/unit_test/mindui_qol/stack_manager_skips_pinned/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	// Order (index 1 = most recent): unpinned A, pinned P1..P4, unpinned B. Cap=5 -> B evicts.
	var/list/order = list()
	var/datum/mind_ui/unit_test_qol_sentinel/A = new(H.mind)
	var/datum/mind_ui/window/unit_test_qol_pinned_sentinel/P1 = new(H.mind)
	var/datum/mind_ui/window/unit_test_qol_pinned_sentinel/P2 = new(H.mind)
	var/datum/mind_ui/window/unit_test_qol_pinned_sentinel/P3 = new(H.mind)
	var/datum/mind_ui/window/unit_test_qol_pinned_sentinel/P4 = new(H.mind)
	var/datum/mind_ui/unit_test_qol_sentinel/B = new(H.mind)
	order += B
	order.Insert(1, P4)
	order.Insert(1, P3)
	order.Insert(1, P2)
	order.Insert(1, P1)
	order.Insert(1, A)
	A.EnforceVisibleCapOnList(order, 5)
	assert_eq(B.hide_count, 1)
	assert_eq(P1.hide_count, 0)
	assert_eq(P2.hide_count, 0)
	assert_eq(P3.hide_count, 0)
	assert_eq(P4.hide_count, 0)
	assert_eq(A.hide_count, 0)
	assert_eq(order.len, 5)
	if (B in order)
		fail("Unpinned tail UI still in display_order after EnforceVisibleCapOnList")
	qdel(A)
	qdel(P1)
	qdel(P2)
	qdel(P3)
	qdel(P4)
	qdel(B)
	qdel(H)

////////////////////////////////////////////////////////////////////
// SHARED STATE: multi-viewer fan-out, spectator gating, role visibility
////////////////////////////////////////////////////////////////////

// UpdateAllElementIcons is overridden so NotifyAll fan-out is observable.
/datum/mind_ui/shared/unit_test_shared
	abstract = TRUE
	uniqueID = "unit_test_shared"
	var/update_calls = 0

/datum/mind_ui/shared/unit_test_shared/New(datum/mind/M, datum/shared_mind_ui_state/state = null)
	mind = M
	if (state)
		shared_state = state
		shared_state.RegisterViewer(src)

/datum/mind_ui/shared/unit_test_shared/UpdateAllElementIcons()
	update_calls++

// Hoverable stub with state_icons so production MouseDown's PRESSED write is the spectator-gate probe.
/obj/abstract/mind_ui_element/hoverable/unit_test_shared_mousedown

/obj/abstract/mind_ui_element/hoverable/unit_test_shared_mousedown/New(turf/loc, datum/mind_ui/P)
	parent = P
	base_icon_state = "test"
	state_icons = list(
		MINDUI_STATE_IDLE = "%",
		MINDUI_STATE_HOVER = "%-hover",
		MINDUI_STATE_PRESSED = "%-pressed",
		MINDUI_STATE_DISABLED = "%-disabled",
	)

/datum/unit_test/mindui_shared/register_unregister_viewer
	name = "mindUI shared - RegisterViewer adds, UnregisterViewer removes"

/datum/unit_test/mindui_shared/register_unregister_viewer/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/shared_mind_ui_state/state = new
	var/datum/mind_ui/shared/unit_test_shared/U = new(H.mind, state)

	if (!(U in state.viewers))
		fail("viewer not registered after New()")
	assert_eq(state.viewers.len, 1)

	state.UnregisterViewer(U)
	if (U in state.viewers)
		fail("viewer still present after UnregisterViewer")
	assert_eq(state.viewers.len, 0)

	state.RegisterViewer(U)
	state.RegisterViewer(U)
	assert_eq(state.viewers.len, 1)

	qdel(U)
	qdel(state)
	qdel(H)

/datum/unit_test/mindui_shared/notify_all_calls_update_on_each_viewer
	name = "mindUI shared - NotifyAll() calls UpdateAllElementIcons on every registered viewer"

/datum/unit_test/mindui_shared/notify_all_calls_update_on_each_viewer/start()
	var/mob/living/carbon/human/H1 = mindui_test_mob()
	var/mob/living/carbon/human/H2 = mindui_test_mob()
	var/datum/shared_mind_ui_state/state = new
	var/datum/mind_ui/shared/unit_test_shared/A = new(H1.mind, state)
	var/datum/mind_ui/shared/unit_test_shared/B = new(H2.mind, state)

	assert_eq(state.viewers.len, 2)
	assert_eq(A.update_calls, 0)
	assert_eq(B.update_calls, 0)

	state.NotifyAll()
	assert_eq(A.update_calls, 1)
	assert_eq(B.update_calls, 1)

	state.NotifyAll()
	assert_eq(A.update_calls, 2)
	assert_eq(B.update_calls, 2)

	qdel(A)
	qdel(B)
	qdel(state)
	qdel(H1)
	qdel(H2)

/datum/unit_test/mindui_shared/viewer_destruction_unregisters
	name = "mindUI shared - qdel'd viewer is removed from state.viewers and NotifyAll does not crash"

/datum/unit_test/mindui_shared/viewer_destruction_unregisters/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/shared_mind_ui_state/state = new
	var/datum/mind_ui/shared/unit_test_shared/U = new(H.mind, state)

	assert_eq(state.viewers.len, 1)
	qdel(U)
	assert_eq(state.viewers.len, 0)

	state.NotifyAll()

	qdel(state)
	qdel(H)

/datum/unit_test/mindui_shared/spectator_mode_short_circuits_mousedown
	name = "mindUI shared - spectator=TRUE causes MouseDown to short-circuit before observable side-effects"

/datum/unit_test/mindui_shared/spectator_mode_short_circuits_mousedown/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/shared_mind_ui_state/state = new
	var/datum/mind_ui/shared/unit_test_shared/U = new(H.mind, state)
	var/obj/abstract/mind_ui_element/hoverable/unit_test_shared_mousedown/E = new(null, U)

	E.current_state = MINDUI_STATE_IDLE

	U.spectator = FALSE
	E.MouseDown(null, null, "")
	assert_eq(E.current_state, MINDUI_STATE_PRESSED)

	E.current_state = MINDUI_STATE_IDLE
	U.spectator = TRUE
	E.MouseDown(null, null, "")
	assert_eq(E.current_state, MINDUI_STATE_IDLE)

	U.spectator = TRUE
	assert_eq(E.IsParentSpectator(), TRUE)
	U.spectator = FALSE
	assert_eq(E.IsParentSpectator(), FALSE)

	qdel(E)
	qdel(U)
	qdel(state)
	qdel(H)

/datum/unit_test/mindui_shared/role_visibility_default_allows_all
	name = "mindUI shared - visible_to_roles=null returns TRUE regardless of viewer role"

/datum/unit_test/mindui_shared/role_visibility_default_allows_all/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/shared/unit_test_shared/U = new(H.mind, null)
	var/obj/abstract/mind_ui_element/hoverable/unit_test_shared_mousedown/E = new(null, U)

	E.visible_to_roles = null
	assert_eq(E.IsVisibleForViewer(U), TRUE)

	E.visible_to_roles = list()
	assert_eq(E.IsVisibleForViewer(U), TRUE)

	qdel(E)
	qdel(U)
	qdel(H)

/datum/unit_test/mindui_shared/role_visibility_filters_non_matching
	name = "mindUI shared - visible_to_roles list excludes viewer whose mind.assigned_role is not in the list"

/datum/unit_test/mindui_shared/role_visibility_filters_non_matching/start()
	var/mob/living/carbon/human/H = mindui_test_mob()
	var/datum/mind_ui/shared/unit_test_shared/U = new(H.mind, null)
	var/obj/abstract/mind_ui_element/hoverable/unit_test_shared_mousedown/E = new(null, U)

	E.visible_to_roles = list("cultist")

	H.mind.assigned_role = "security"
	assert_eq(E.IsVisibleForViewer(U), FALSE)

	H.mind.assigned_role = "cultist"
	assert_eq(E.IsVisibleForViewer(U), TRUE)

	H.mind.assigned_role = null
	assert_eq(E.IsVisibleForViewer(U), FALSE)

	qdel(E)
	qdel(U)
	qdel(H)

#endif
