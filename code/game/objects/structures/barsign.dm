// Should be global var, because all bar signs should have the same icon.
var/bar_sing_global = pick("lv426", "zocalo", "4theemprah", "ishimura",\
                           "tardis", "thecavern", "quarks", "tenforward",\
                           "thepranicngpony", "vault13", "solaris", "thehive",\
                           "cantina", "theouterspess", "milliways42", "thetimeofeve",\
                           "spaceasshole", "dwarffortress", "maltesefalcon")

/obj/structure/sign/double/barsign
	icon = 'icons/obj/barsigns.dmi'
	icon_state = "empty"
	anchored = 1

/obj/structure/sign/double/barsign/New()

	ChangeSign(bar_sing_global)
	return

/obj/structure/sign/double/barsign/proc/ChangeSign(Text)
	src.icon_state = "[Text]"
	return

/obj/structure/sign/double/barsign/attackby(obj/item/I, mob/user)
	if(istype(I, /obj/item/weapon/card/emag) && !(icon_state == "syndiebar"))
		emag_act()
	else
		return

/obj/structure/sign/double/barsign/proc/emag_act()
	ChangeSign("syndiebar")
	return
