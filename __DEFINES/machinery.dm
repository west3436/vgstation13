#define MACHINE_POWER_USE_NONE   0
#define MACHINE_POWER_USE_IDLE   1
#define MACHINE_POWER_USE_ACTIVE 2

// AI (i.e. game AI, not the AI player) controlled bots
#define BOT_PATROL 1
#define BOT_BEACON 2
#define BOT_CONTROL 4
#define BOT_DENSE 8
#define BOT_NOT_CHASING 16
#define BOT_SPACEWORTHY 32

// Vendor flags
#define VEND_CAT_NORMAL 	1
#define VEND_CAT_HIDDEN 	2
#define VEND_CAT_COIN   	3
#define VEND_CAT_VOUCH  	4
#define VEND_CAT_HOLIDAY	5

#define VEND_PRODUCT_RING	(1<<1) //does the vended product have a ring dispenser
#define VEND_PRODUCT_LABEL	(1<<2) //does the vended product have a label
#define VEND_PRODUCT_ICON 	(1<<3) //does the vended product have a custom icon

#define WIRES_NORMAL 0
#define WIRES_CUT    1
#define WIRES_PULSED 2
