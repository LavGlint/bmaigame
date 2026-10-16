extends RefCounted
class_name HanabiLobbyState

var selected_map: int = 0
var round_seconds: int = 150
var round_count: int = 3
var initial_hearts: int = 3
var characters: Array[int] = [0, 1, 2, 3]
var ready_slots: Array[bool] = [false, true, true, true]
var active_slot: int = 0
var launch_remaining: float = -1.0
var selection_modes: Array[String] = ["key1", "ai", "ai", "ai"]

func settings_valid() -> bool:
	return selected_map in range(4) and round_seconds in [120, 150, 180] and round_count in [1, 3, 5] and initial_hearts in [1, 3, 5] and round_seconds * round_count <= 720

func prepare(modes: Array[String]) -> void:
	selection_modes.assign(modes)
	launch_remaining = -1.0
	for slot in range(4): ready_slots[slot] = modes[slot] == "ai"
	advance_turn()

func advance_turn() -> void:
	for slot in range(4):
		if not ready_slots[slot]:
			active_slot = slot
			return

func can_select(slot: int) -> bool:
	return slot in range(4) and slot == active_slot and not ready_slots[slot] and selection_modes[slot] != "ai"

func confirm(slot: int) -> bool:
	if not can_select(slot): return false
	ready_slots[slot] = true
	launch_remaining = -1.0
	advance_turn()
	return true

func select_character(slot: int, character: int, bot: bool) -> bool:
	if bot or not can_select(slot): return false
	characters[slot] = posmod(character, 6)
	launch_remaining = -1.0
	return true

func cancel_ready(slot: int, bot: bool = false) -> bool:
	if bot or slot not in range(4) or selection_modes[slot] == "ai": return false
	if not ready_slots[slot] and slot != active_slot: return false
	for index in range(slot, 4): ready_slots[index] = selection_modes[index] == "ai"
	launch_remaining = -1.0
	advance_turn()
	return true

func invalidate_from(slot: int, modes: Array[String]) -> void:
	selection_modes.assign(modes)
	for index in range(slot, 4): ready_slots[index] = modes[index] == "ai"
	launch_remaining = -1.0
	advance_turn()

func previous_confirmed() -> int:
	var before := 4 if ready_slots.count(true) == 4 else active_slot
	for slot in range(before - 1, -1, -1):
		if ready_slots[slot] and selection_modes[slot] != "ai": return slot
	return -1

func schedule_launch(connected: bool) -> void:
	if ready_slots.count(true) == 4 and connected:
		if launch_remaining < 0.0: launch_remaining = 3.0
	else: launch_remaining = -1.0
