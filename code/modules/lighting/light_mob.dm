/mob
	var/obj/abstract/screen/plane/master/master_plane
	var/obj/abstract/screen/plane/dark/dark_plane
	var/obj/abstract/screen/backdrop/backdrop
	var/obj/abstract/screen/plane/self_vision/self_vision
	var/seedarkness = 1

/mob/proc/create_lighting_planes()
	if(!dark_plane)
		dark_plane = new(client)
	else
		client.screen |= dark_plane
	if(!master_plane)
		master_plane = new(client)
	else
		client.screen |= master_plane
	if(!backdrop)
		backdrop = new(client)
	else
		client.screen |= backdrop
	if (!self_vision)
		self_vision = new(client)
	else
		client.screen |= self_vision
	if(client)
		update_darkness()

/mob/proc/update_darkness()
	if(seedarkness)
		master_plane.color = LIGHTING_PLANEMASTER_COLOR
	else
		master_plane.color = ""

/mob/living/carbon/human/update_contained_lights(var/list/specific_contents)
	. = ..(contents-(internal_organs+organs))
