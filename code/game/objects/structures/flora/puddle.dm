/obj/structure/puddle
	name = "puddle"
	icon = 'icons/obj/flora/puddle.dmi'
	anchored = 1
	var/liquid

/obj/structure/puddle/New()
	..()
	if(liquid)
		create_reagents(100)
		reagents.add_reagent(liquid, 100)

/obj/structure/puddle/splashable()
	return FALSE

/obj/structure/puddle/Crossed(AM)
	if(isliving(AM) && isturf(src.loc))

		var/mob/living/L = AM

		if(L.on_foot()) //Flying mobs won't suffer the consequences of stepping in the acid, nor will lying mobs (we're assuming they're being smart and crawling around the pool)
			if(ishuman(L))
				var/mob/living/carbon/human/H = L
				if(H.m_intent == "run") // Running over the puddle has a 60% chance of stepping in it, to various results
					if(prob(60))
						crossed_effect(H)
					else
						to_chat(H, "<span class='warning'>You stumble over [src], barely avoiding stepping in it!</span>") // Fair warning to be careful, if you were spared.
				else // Walking is safe
					to_chat(H, "<span class='notice'>You step carefully over [src].</span>")
					return

/obj/structure/puddle/proc/crossed_effect(var/mob/living/carbon/human/the_fool)
	to_chat(the_fool, "<span class='warning'>You step in [src]!</span>")
	if(reagents && reagents.total_volume && liquid)
		reagents.reaction(the_fool, TOUCH, amount_override = 5)
		reagents.add_reagent(liquid, 5) // Refill to keep the puddle as an infinite source

/obj/structure/puddle/acid
	name = "acid puddle"
	desc = "Watch your step..."
	icon_state = "pacid"
	var/acid_level

/obj/structure/puddle/acid/crossed_effect(var/mob/living/carbon/human/the_fool)
	to_chat(the_fool, "<span class='warning'>You step in [src]!</span>")
	var /obj/item/clothing/shoes/melting_shoes = the_fool.shoes
	playsound(src, 'sound/effects/grue_burn.ogg', 50, 1) // Audio feedback is always good, so a player knows something just happened.

	if(melting_shoes && !(melting_shoes.dissolvable() == acid_level)) // Are our shoes acid proof? Lucky us!
		to_chat(the_fool, "<span class='warning'>Your footwear sizzles on contact, but remains intact.</span>")

	if(melting_shoes && (melting_shoes.dissolvable() == acid_level)) // If not, they melt away. Still not the worst thing that can happen.
		to_chat(the_fool, "<span class='warning'>Your footwear sizzles on contact, and dissolves!</span>")
		the_fool.drop_from_inventory(melting_shoes)
		qdel(melting_shoes)
		new/obj/effect/decal/cleanable/molten_item(the_fool.loc)

	if(!melting_shoes && isgrey(the_fool)) // Are we a grey? We don't have any trouble with acid, even barefoot.
		to_chat(the_fool, "<span class='warning'>You feel a slight tingling as you step in [src], but it quickly subsides.</span>")

	if(!melting_shoes && !isgrey(the_fool)) // Otherwise we just lost a foot. How unfortunate.
		var/datum/organ/external/foot_organ = the_fool.pick_usable_organ(LIMB_RIGHT_FOOT, LIMB_LEFT_FOOT)
		to_chat(the_fool, "<span class='danger'>You feel a horrific pain as you step in [src], and your foot melts away!</span>")
		the_fool.audible_scream()
		foot_organ.droplimb(1, 0, 0)

/obj/structure/puddle/acid/pacid
	name = "acid puddle"
	acid_level = PACID

/obj/structure/puddle/acid/sacid
	name = "sulfuric acid puddle"
	desc = "This could make SO many circuits."
	icon_state = "sacid"
	acid_level = SACID

/obj/structure/puddle/blood
	name = "bloody puddle"
	desc = "Vampires love these."
	icon_state = "blood"
	liquid = BLOOD

/obj/structure/puddle/blood/crossed_effect(var/mob/living/carbon/human/the_fool)
	..()
	the_fool.add_blood_to_feet(5, DEFAULT_BLOOD)
