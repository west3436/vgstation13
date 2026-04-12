// Overmap utility procs. Pure, side-effect-free helpers used by SSovermap, the
// helm UI, and shuttle route resolvers.

/proc/chessboard_dist(dx, dy)
	// Chessboard (Chebyshev) distance: max of absolute coordinate deltas.
	// Diagonal-counts-as-one. Matches the spec's tile-walk model.
	return max(abs(dx), abs(dy))

/proc/chessboard_path(x1, y1, x2, y2)
	// Returns list of list(x,y) tile coords from (x1,y1) EXCLUSIVE to (x2,y2) INCLUSIVE,
	// one tile per step, 8-directional. The starting tile is intentionally omitted —
	// callers iterate the result and treat each entry as a discrete waypoint.
	var/list/path = list()
	var/cx = x1
	var/cy = y1
	while(cx != x2 || cy != y2)
		if(cx < x2)
			cx++
		else if(cx > x2)
			cx--
		if(cy < y2)
			cy++
		else if(cy > y2)
			cy--
		path += list(list(cx, cy))
	return path
