#define TURF_DRY 0
#define TURF_WET_WATER 1
#define TURF_WET_LUBE 2
#define TURF_WET_ICE 3

#define TURF_CONTAINS_ROCKERNAUT 1
#define TURF_CONTAINS_BOSS 2

#define SLIP_HAS_MAGBOOTS -1 // Magbooties !


#define MINE_DIFFICULTY_NORM 1
#define MINE_DIFFICULTY_TOUGH 3
#define MINE_DIFFICULTY_DENSE 5
#define MINE_DIFFICULTY_GLHF 9

#define MINE_DURATION 100

/// Returns the turfs on the edge of a square with CENTER in the middle and with the given RADIUS. If used near the edge of the map, will still work fine.
// order of the additions: top edge + bottom edge + left edge + right edge
#define RANGE_EDGE_TURFS(RADIUS, CENTER)\
	(CENTER.y + RADIUS < world.maxy ? 	block(max(CENTER.x - RADIUS, 1), 			min(CENTER.y + RADIUS, world.maxy), 	CENTER.z, min(CENTER.x + RADIUS, world.maxx), 	min(CENTER.y + RADIUS, world.maxy), CENTER.z) : list()) +\
	(CENTER.y - RADIUS > 1 ? 			block(max(CENTER.x - RADIUS, 1), 			max(CENTER.y - RADIUS, 1), 				CENTER.z, min(CENTER.x + RADIUS, world.maxx), 	max(CENTER.y - RADIUS, 1), 			CENTER.z) : list()) +\
	(CENTER.x - RADIUS > 1 ? 			block(max(CENTER.x - RADIUS, 1), 			min(CENTER.y + RADIUS - 1, world.maxy), CENTER.z, max(CENTER.x - RADIUS, 1), 			max(CENTER.y - RADIUS + 1, 1), 		CENTER.z) : list()) +\
	(CENTER.x + RADIUS < world.maxx ? 	block(min(CENTER.x + RADIUS, world.maxx), 	min(CENTER.y + RADIUS - 1, world.maxy), CENTER.z, min(CENTER.x + RADIUS, world.maxx), 	max(CENTER.y - RADIUS + 1, 1), 		CENTER.z) : list())
