// Overmap constants. Loaded into the global #define namespace at compile time
// — every overmap module file references these. Lives in __DEFINES/ rather
// than code/modules/overmap/ so it's seen by SSovermap (a controller subsystem
// included much earlier in the .dme than the overmap module files).
//
// Coordinate system: integer (1..OVERMAP_WIDTH, 1..OVERMAP_HEIGHT). Chessboard distance.

#define OVERMAP_WIDTH 25
#define OVERMAP_HEIGHT 25
#define OVERMAP_VIEW_TILES 5
#define OVERMAP_TILE_PIXELS 52        // nav mode: 5 * 52 = 260
#define OVERMAP_MAP_TILE_PIXELS 10    // map mode: 25 * 10 = 250
#define OVERMAP_VIEWPORT_SIZE 260

// Per-shuttle fog states.
#define OVERMAP_TILE_FOG 0
#define OVERMAP_TILE_SCANNED 1
#define OVERMAP_TILE_VISITED 2

// View modes for overmap_base.view_mode
#define OVERMAP_VIEW_NAV 0
#define OVERMAP_VIEW_MAP 1

// Body type discriminator. Read by UI to pick icon_state and tooltip behavior.
#define OVERMAP_BODY_GENERIC 0
#define OVERMAP_BODY_PLANET 1
#define OVERMAP_BODY_STATION 2
#define OVERMAP_BODY_OUTPOST 3
#define OVERMAP_BODY_HOMEBASE 4
#define OVERMAP_BODY_ENCOUNTER 5
#define OVERMAP_BODY_CENTCOMM 6

// Helm click modes (free-nav UI).
#define OVERMAP_CLICK_SET_COURSE 0
#define OVERMAP_CLICK_ADD_WAYPOINT 1
#define OVERMAP_CLICK_REMOVE_WAYPOINT 2
