/turf/unsimulated/beach
	name = "Beach"
	icon = 'icons/misc/beach.dmi'

/turf/unsimulated/beach/sand
	name = "Sand"
	icon_state = "sand"

/turf/unsimulated/beach/sand/spread/New()
	..()
	var/image/img = image('icons/turf/rock_overlay.dmi', "sand_overlay",layer = SIDE_LAYER)
	img.pixel_x = -4*PIXEL_MULTIPLIER
	img.pixel_y = -4*PIXEL_MULTIPLIER
	img.plane = BELOW_TURF_PLANE
	overlays += img

/turf/unsimulated/beach/coastline
	name = "Coastline"
	icon = 'icons/misc/beach2.dmi'
	icon_state = "sandwater"

/turf/unsimulated/beach/water
	name = "Water"
	icon_state = "water"

/obj/effect/beach_water
	plane =	ABOVE_HUMAN_PLANE-1 // turf_plane is -1 without the float stuff
	icon = 'icons/misc/beach.dmi'
	icon_state = "water5"

/obj/effect/beach_water/unsimmed
	plane =	MOB_PLANE-1 // turf_plane is -1 without the float stuff
	layer = MOB_LAYER+0.1
	icon_state = "water2"

var/obj/effect/beach_water/BW
var/obj/effect/beach_water/unsimmed/BWU

/turf/unsimulated/beach/water/New()
	..()
	if(!BWU)
		BWU = new
	vis_contents.Add(BWU)

/turf/unsimulated/beach/water/Destroy()
	vis_contents.Cut()
	..()

/turf/unsimulated/beach/water/deep
	name = "deep water"
	density = 1

/turf/unsimulated/beach/sandbar
	name = "sandbar"
	desc = "Very shallow water that conceals a layer of sand."
	icon_state = "sandbar"

/turf/unsimulated/beach/shallows
	name = "Shallows"
	desc = "Shallow water that you can submerge in only waist deep."
	icon_state = "water"
	var/image/water

/turf/unsimulated/beach/shallows/New()
	..()
	water = image("icon"='icons/misc/beach.dmi',"icon_state"="shallow-water","layer"=MOB_LAYER+0.1)
	water.plane = MOB_PLANE

//Entered() takes place after the object enters
/turf/unsimulated/beach/shallows/Entered(atom/A, atom/OL)
	. = ..()
	//the atom was permitted entry, but we also have no previous contents
	if(isliving(A) || ismecha(A) || isbot(A))
		spawn(!istype(OL,/turf/unsimulated/beach/shallows)) //very small delay to reduce clipping on entry; 0 if already in shallows
			A.overlays += water //This thing is likely to move, so it gets to carry an overlay with it for smoother transitions
		return .
	if(count_objs() == 1) //just us here
		//objects however are less likely to move and have a tendency to pile up
		//therefore, they all share one for the turf
		overlays += water
	return .

//Exited() is after it exits
/turf/unsimulated/beach/shallows/Exited(atom/A, atom/newloc)
	. = ..()
	if(isliving(A) || ismecha(A) || isbot(A))
		A.overlays -= water
		return .
	if(!count_objs()) //nothing left, get rid of it
		overlays -= water
	return .

/turf/unsimulated/beach/cultify()
	return

/turf/proc/count_objs()
	var/count = 0
	for(var/atom/A in contents)
		if(isrealobject(A) && !A.invisibility)
			count++
	return count