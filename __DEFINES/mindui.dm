// mindUI framework defines
//
// The MINDUI_* namespace is also used in __DEFINES/setup.dm for the legacy
// element flags (MINDUI_FLAG_PROCESSING, MINDUI_FLAG_TOOLTIP, MINDUI_MAX_CULT_SLOTS).
// When adding new defines here, verify there is no name collision with setup.dm.

// Layer aliases for the MIND_UI_* constants defined in __DEFINES/planes+layers.dm.
// TOOLTIP and MODAL are absolute layers above the per-element range.
#define MINDUI_LAYER_BACK       MIND_UI_BACK
#define MINDUI_LAYER_BUTTON     MIND_UI_BUTTON
#define MINDUI_LAYER_FRONT      MIND_UI_FRONT
#define MINDUI_LAYER_TOOLTIP    (MIND_UI_FRONT + 5)
#define MINDUI_LAYER_MODAL      (MIND_UI_FRONT + 10)

// Process throttle intervals (deciseconds)
#define MINDUI_TICK_EVERY       1
#define MINDUI_TICK_FAST        5
#define MINDUI_TICK_NORMAL      10
#define MINDUI_TICK_SLOW        50

// Element state machine
#define MINDUI_STATE_IDLE       "idle"
#define MINDUI_STATE_HOVER      "hover"
#define MINDUI_STATE_PRESSED    "pressed"
#define MINDUI_STATE_DISABLED   "disabled"
#define MINDUI_STATE_LOCKED     "locked"

// Hotkey modifier flags
#define MINDUI_MOD_SHIFT        (1<<0)
#define MINDUI_MOD_CTRL         (1<<1)
#define MINDUI_MOD_ALT          (1<<2)
#define MINDUI_MOD_MIDDLE       (1<<3)
#define MINDUI_MOD_RIGHT        (1<<4)

// Window flags
#define MINDUI_WINDOW_CLOSABLE  (1<<0)
#define MINDUI_WINDOW_MOVABLE   (1<<1)
#define MINDUI_WINDOW_PINNABLE  (1<<2)
#define MINDUI_WINDOW_MINIMIZE  (1<<3)
#define MINDUI_WINDOW_RESIZE    (1<<4)

// Validation / smoke-test return codes
#define MINDUI_VALID            0
#define MINDUI_INVALID_NO_ID    1
#define MINDUI_INVALID_DUP_ID   2
#define MINDUI_INVALID_BAD_ICON 3
#define MINDUI_INVALID_BAD_LOC  4
#define MINDUI_INVALID_NO_VALID 5
#define MINDUI_INVALID_BAD_SUB_UI  6

// Tooltip theme names. In addition to the built-in themes in icons/tooltip*.
#define MINDUI_TOOLTIP_DEFAULT  "default"
#define MINDUI_TOOLTIP_CULT     "radial-cult"
#define MINDUI_TOOLTIP_DANGER   "danger"
