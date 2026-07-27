extends Node

# Autoload singleton registered as "Global" — state for the hospital /
# nanobot quest.
#
# NOTE: This is intentionally DISTINCT from the lowercase "global" autoload
# (scripts/core/global.gd), which holds the shared farm / pedestal / barn
# state. The hospital quest scripts reference this one as `Global` (capital G):
#   door.gd, hospital_hallway.gd, patient_1..4_room.gd,
#   patient_1..4_level.gd, patient1..4.gd
# It was lost during a refactor, which is what broke the quest.

# Where to place the player when a hospital scene loads. Written by door.gd
# (to the door's spawn_id) and by the levels (to "from_level"); read by the
# rooms / hallway in their _ready() via `match Global.spawn_point`.
var spawn_point: String = "Default"

# Patient ids ("patient_1".."patient_4") whose nanobot level has been cleared.
var completed_patients: Array = []

# True once every patient's level has been completed (drives the congrats
# screen in patient_1_room.gd).
func all_patients_complete() -> bool:
	for id in ["patient_1", "patient_2", "patient_3", "patient_4"]:
		if not completed_patients.has(id):
			return false
	return true
