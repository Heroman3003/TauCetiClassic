#define SOLID 1
#define LIQUID 2
#define GAS 3
#define FOOD_METABOLISM 0.4
#define DRINK_METABOLISM 0.8
#define REAGENTS_OVERDOSE 30
#define REM REAGENTS_EFFECT_MULTIPLIER

//The reaction procs must ALWAYS set src = null, this detaches the proc from the object (the reagent)
//so that it can continue working when the reagent is deleted while the proc is still active.


datum
	reagent
		var/name = "Reagent"
		var/id = "reagent"
		var/description = ""
		var/datum/reagents/holder = null
		var/reagent_state = SOLID
		var/list/data = null
		var/volume = 0
		var/nutriment_factor = 0
		var/custom_metabolism = REAGENTS_METABOLISM
		var/overdose = 0
		var/overdose_dam = 1
		//var/list/viruses = list()
		var/color = "#000000" // rgb: 0, 0, 0 (does not support alpha channels - yet!)

		proc
			reaction_mob(mob/M, method=TOUCH, volume) //By default we have a chance to transfer some
				if(!istype(M, /mob/living))	return 0
				var/datum/reagent/self = src
				src = null										  //of the reagent to the mob on TOUCHING it.

				if(self.holder)		//for catching rare runtimes
					if(!istype(self.holder.my_atom, /obj/effect/effect/smoke/chem))
						// If the chemicals are in a smoke cloud, do not try to let the chemicals "penetrate" into the mob's system (balance station 13) -- Doohl

						if(method == TOUCH)

							var/chance = 1
							var/block  = 0

							for(var/obj/item/clothing/C in M.get_equipped_items())
								if(C.permeability_coefficient < chance) chance = C.permeability_coefficient
								if(istype(C, /obj/item/clothing/suit/bio_suit))
									// bio suits are just about completely fool-proof - Doohl
									// kind of a hacky way of making bio suits more resistant to chemicals but w/e
									if(prob(75))
										block = 1

								if(istype(C, /obj/item/clothing/head/bio_hood))
									if(prob(75))
										block = 1

							chance = chance * 100

							if(prob(chance) && !block)
								if(M.reagents)
									M.reagents.add_reagent(self.id,self.volume/2)
				return 1

			reaction_obj(var/obj/O, var/volume) //By default we transfer a small part of the reagent to the object
				src = null						//if it can hold reagents. nope!
				//if(O.reagents)
				//	O.reagents.add_reagent(id,volume/3)
				return

			reaction_turf(var/turf/T, var/volume)
				src = null
				return

			on_mob_life(mob/living/M, alien)
				if(!M || !holder)
					return
				if(!isliving(M))
					return //Noticed runtime errors from pacid trying to damage ghosts, this should fix. --NEO
				if((overdose > 0) && (volume >= overdose))//Overdosing, wooo
					M.adjustToxLoss(overdose_dam)
				return TRUE

			on_move(mob/M)
				return

			// Called after add_reagents creates a new reagent.
			on_new(var/data)
				return

			// Called when two reagents of the same are mixing.
			on_merge(data)
				return

			on_update(atom/A)
				return



		blood
			data = new/list("donor"=null,"viruses"=null,"blood_DNA"=null,"blood_type"=null,"resistances"=null,"trace_chem"=null, "antibodies" = null)
			name = "Blood"
			id = "blood"
			reagent_state = LIQUID
			color = "#C80000" // rgb: 200, 0, 0

			reaction_mob(mob/M, method=TOUCH, volume)
				var/datum/reagent/blood/self = src
				src = null
				if(self.data && self.data["viruses"])
					for(var/datum/disease/D in self.data["viruses"])
						//var/datum/disease/virus = new D.type(0, D, 1)
						// We don't spread.
						if(D.spread_type == SPECIAL || D.spread_type == NON_CONTAGIOUS) continue

						if(method == TOUCH)
							M.contract_disease(D)
						else //injected
							M.contract_disease(D, 1, 0)
				if(self.data && self.data["virus2"] && istype(M, /mob/living/carbon))//infecting...
					var/list/vlist = self.data["virus2"]
					if (vlist.len)
						for (var/ID in vlist)
							var/datum/disease2/disease/V = vlist[ID]

							if(method == TOUCH)
								infect_virus2(M,V.getcopy())
							else
								infect_virus2(M,V.getcopy(),1) //injected, force infection!
				if(self.data && self.data["antibodies"] && istype(M, /mob/living/carbon))//... and curing
					var/mob/living/carbon/C = M
					C.antibodies |= self.data["antibodies"]




			reaction_turf(var/turf/simulated/T, var/volume)//splash the blood all over the place
				if(!istype(T)) return
				var/datum/reagent/blood/self = src
				src = null
				if(!(volume >= 3)) return
				//var/datum/disease/D = self.data["virus"]
				if(!self.data["donor"] || istype(self.data["donor"], /mob/living/carbon/human))
					var/obj/effect/decal/cleanable/blood/blood_prop = locate() in T //find some blood here
					if(!blood_prop) //first blood!
						blood_prop = new(T)
						blood_prop.blood_DNA[self.data["blood_DNA"]] = self.data["blood_type"]

					for(var/datum/disease/D in self.data["viruses"])
						var/datum/disease/newVirus = D.Copy(1)
						blood_prop.viruses += newVirus
						newVirus.holder = blood_prop

					if(self.data["virus2"])
						blood_prop.virus2 = virus_copylist(self.data["virus2"])


				else if(istype(self.data["donor"], /mob/living/carbon/monkey))
					var/obj/effect/decal/cleanable/blood/blood_prop = locate() in T
					if(!blood_prop)
						blood_prop = new(T)
						blood_prop.blood_DNA["Non-Human DNA"] = "A+"
					for(var/datum/disease/D in self.data["viruses"])
						var/datum/disease/newVirus = D.Copy(1)
						blood_prop.viruses += newVirus
						newVirus.holder = blood_prop

				else if(istype(self.data["donor"], /mob/living/carbon/alien))
					var/obj/effect/decal/cleanable/blood/xeno/blood_prop = locate() in T
					if(!blood_prop)
						blood_prop = new(T)
						blood_prop.blood_DNA["UNKNOWN DNA STRUCTURE"] = "X*"
					for(var/datum/disease/D in self.data["viruses"])
						var/datum/disease/newVirus = D.Copy(1)
						blood_prop.viruses += newVirus
						newVirus.holder = blood_prop
				return

/* Must check the transfering of reagents and their data first. They all can point to one disease datum.

			Destroy()
				if(src.data["virus"])
					var/datum/disease/D = src.data["virus"]
					D.cure(0)
				..()
*/
		vaccine
			//data must contain virus type
			name = "Vaccine"
			id = "vaccine"
			reagent_state = LIQUID
			color = "#C81040" // rgb: 200, 16, 64

			reaction_mob(mob/M, method=TOUCH, volume)
				var/datum/reagent/vaccine/self = src
				src = null
				if(self.data&&method == INGEST)
					for(var/datum/disease/D in M.viruses)
						if(istype(D, /datum/disease/advance))
							var/datum/disease/advance/A = D
							if(A.GetDiseaseID() == self.data)
								D.cure()
						else
							if(D.type == self.data)
								D.cure()

					M.resistances += self.data
				return


		water
			name = "Water"
			id = "water"
			description = "A ubiquitous chemical substance that is composed of hydrogen and oxygen."
			reagent_state = LIQUID
			color = "#0064C8" // rgb: 0, 100, 200
			custom_metabolism = 0.01

			reaction_turf(var/turf/simulated/T, var/volume)
				spawn_fluid(T, volume) // so if will spawn even in space, just for pure visuals
				if (!istype(T)) return
				src = null
				if(volume >= 3)
					T.make_wet_floor(WATER_FLOOR)

				for(var/mob/living/carbon/slime/M in T)
					M.adjustToxLoss(rand(15,20))

				var/hotspot = (locate(/obj/fire) in T)
				if(hotspot && !istype(T, /turf/space))
					var/datum/gas_mixture/lowertemp = T.remove_air( T:air:total_moles )
					lowertemp.temperature = max( min(lowertemp.temperature-2000,lowertemp.temperature / 2) ,0)
					lowertemp.react()
					T.assume_air(lowertemp)
					qdel(hotspot)
				return
			reaction_obj(var/obj/O, var/volume)
				src = null
				var/turf/T = get_turf(O)
				var/hotspot = (locate(/obj/fire) in T)
				if(hotspot && !istype(T, /turf/space))
					var/datum/gas_mixture/lowertemp = T.remove_air( T:air:total_moles )
					lowertemp.temperature = max( min(lowertemp.temperature-2000,lowertemp.temperature / 2) ,0)
					lowertemp.react()
					T.assume_air(lowertemp)
					qdel(hotspot)
				if(istype(O,/obj/item/weapon/reagent_containers/food/snacks/monkeycube))
					var/obj/item/weapon/reagent_containers/food/snacks/monkeycube/cube = O
					if(!cube.wrapped)
						cube.Expand()
				return

		water/holywater
			name = "Holy Water"
			id = "holywater"
			description = "An ashen-obsidian-water mix, this solution will alter certain sections of the brain's rationality."
			color = "#E0E8EF" // rgb: 224, 232, 239
			custom_metabolism = REAGENTS_METABOLISM * 10

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(ishuman(M))
					if((M.mind in ticker.mode.cult) && prob(10))
						to_chat(M, "<span class='notice'>A cooling sensation from inside you brings you an untold calmness.</span>")
						ticker.mode.remove_cultist(M.mind)
						M.visible_message("<span class='notice'>[M]'s eyes blink and become clearer.</span>")

		lube
			name = "Space Lube"
			id = "lube"
			description = "Lubricant is a substance introduced between two moving surfaces to reduce the friction and wear between them. giggity."
			reagent_state = LIQUID
			color = "#009CA8" // rgb: 0, 156, 168
			overdose = REAGENTS_OVERDOSE

			reaction_turf(var/turf/simulated/T, var/volume)
				if (!istype(T)) return
				src = null
				if(volume >= 1)
					T.make_wet_floor(LUBE_FLOOR)

		plasticide
			name = "Plasticide"
			id = "plasticide"
			description = "Liquid plastic, do not eat."
			reagent_state = LIQUID
			color = "#CF3600" // rgb: 207, 54, 0
			custom_metabolism = 0.01

			on_mob_life(mob/living/M)
				if(!..())
					return
				// Toxins are really weak, but without being treated, last very long.
				M.adjustToxLoss(0.2)

		slimetoxin
			name = "Mutation Toxin"
			id = "mutationtoxin"
			description = "A corruptive toxin produced by slimes."
			reagent_state = LIQUID
			color = "#13BC5E" // rgb: 19, 188, 94
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(ishuman(M))
					var/mob/living/carbon/human/H = M
					if(H.dna && !H.dna.mutantrace)
						to_chat(M, "<span class='warning'>Your flesh rapidly mutates!</span>")
						H.dna.mutantrace = "slime"
						H.update_mutantrace()

		aslimetoxin
			name = "Advanced Mutation Toxin"
			id = "amutationtoxin"
			description = "An advanced corruptive toxin produced by slimes."
			reagent_state = LIQUID
			color = "#13BC5E" // rgb: 19, 188, 94
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(istype(M, /mob/living/carbon) && M.stat != DEAD)
					to_chat(M, "<span class='warning'>Your flesh rapidly mutates!</span>")
					if(M.monkeyizing)
						return
					M.monkeyizing = 1
					M.canmove = 0
					M.icon = null
					M.overlays.Cut()
					M.invisibility = 101
					for(var/obj/item/W in M)
						if(istype(W, /obj/item/weapon/implant))	//TODO: Carn. give implants a dropped() or something
							qdel(W)
							continue
						W.layer = initial(W.layer)
						W.loc = M.loc
						W.dropped(M)
					var/mob/living/carbon/slime/new_mob = new /mob/living/carbon/slime(M.loc)
					new_mob.a_intent = "hurt"
					new_mob.universal_speak = 1
					if(M.mind)
						M.mind.transfer_to(new_mob)
					else
						new_mob.key = M.key
					qdel(M)

		srejuvenate
			name = "Soporific Rejuvenant"
			id = "stoxin2"
			description = "Put people to sleep, and heals them."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220
			custom_metabolism = REAGENTS_METABOLISM * 0.5
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(M.losebreath >= 10)
					M.losebreath = max(10, M.losebreath-10)
				if(!data)
					data = 1
				data++
				switch(data)
					if(1 to 15)
						M.eye_blurry = max(M.eye_blurry, 10)
					if(15 to 25)
						M.drowsyness  = max(M.drowsyness, 20)
					if(25 to INFINITY)
						M.sleeping += 1
						M.adjustOxyLoss(-M.getOxyLoss())
						M.SetWeakened(0)
						M.SetStunned(0)
						M.SetParalysis(0)
						M.dizziness = 0
						M.drowsyness = 0
						M.stuttering = 0
						M.confused = 0
						M.jitteriness = 0

		inaprovaline
			name = "Inaprovaline"
			id = "inaprovaline"
			description = "Inaprovaline is a synaptic stimulant and cardiostimulant. Commonly used to stabilize patients."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220
			custom_metabolism = REAGENTS_METABOLISM * 0.5
			overdose = REAGENTS_OVERDOSE * 2

			on_mob_life(mob/living/M, alien)
				if(!..())
					return
				if(alien && alien == IS_VOX)
					M.adjustToxLoss(REAGENTS_METABOLISM)
				else
					if(M.losebreath >= 10)
						M.losebreath = max(10, M.losebreath-5)

		space_drugs
			name = "Space drugs"
			id = "space_drugs"
			description = "An illegal chemical compound used as drug."
			reagent_state = LIQUID
			color = "#60A584" // rgb: 96, 165, 132
			custom_metabolism = REAGENTS_METABOLISM * 0.5
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.druggy = max(M.druggy, 15)
				if(isturf(M.loc) && !istype(M.loc, /turf/space))
					if(M.canmove && !M.restrained())
						if(prob(10))
							step(M, pick(cardinal))
				if(prob(7))
					M.emote(pick("twitch","drool","moan","giggle"))

		serotrotium
			name = "Serotrotium"
			id = "serotrotium"
			description = "A chemical compound that promotes concentrated production of the serotonin neurotransmitter in humans."
			reagent_state = LIQUID
			color = "#202040" // rgb: 20, 20, 40
			custom_metabolism = REAGENTS_METABOLISM * 0.25
			overdose = REAGENTS_OVERDOSE

			on_mob_life(var/mob/living/M as mob)
				if(!..())
					return
				if(ishuman(M))
					if(prob(7))
						M.emote(pick("twitch","drool","moan","gasp"))

/*		silicate
			name = "Silicate"
			id = "silicate"
			description = "A compound that can be used to reinforce glass."
			reagent_state = LIQUID
			color = "#C7FFFF" // rgb: 199, 255, 255

			reaction_obj(var/obj/O, var/volume)
				src = null
				if(istype(O,/obj/structure/window))
					if(O:silicate <= 200)

						O:silicate += volume
						O:health += volume * 3

						if(!O:silicateIcon)
							var/icon/I = icon(O.icon,O.icon_state,O.dir)

							var/r = (volume / 100) + 1
							var/g = (volume / 70) + 1
							var/b = (volume / 50) + 1
							I.SetIntensity(r,g,b)
							O.icon = I
							O:silicateIcon = I
						else
							var/icon/I = O:silicateIcon

							var/r = (volume / 100) + 1
							var/g = (volume / 70) + 1
							var/b = (volume / 50) + 1
							I.SetIntensity(r,g,b)
							O.icon = I
							O:silicateIcon = I

				return*/

		oxygen
			name = "Oxygen"
			id = "oxygen"
			description = "A colorless, odorless gas."
			reagent_state = GAS
			color = "#808080" // rgb: 128, 128, 128

			custom_metabolism = 0.01

			on_mob_life(mob/living/M, alien)
				if(!..())
					return
				if(M.stat == DEAD)
					return
				if(alien && alien == IS_VOX)
					M.adjustToxLoss(REAGENTS_METABOLISM)
					holder.remove_reagent(src.id, REAGENTS_METABOLISM) //By default it slowly disappears.

		copper
			name = "Copper"
			id = "copper"
			description = "A highly ductile metal."
			color = "#6E3B08" // rgb: 110, 59, 8

			custom_metabolism = 0.01

		nitrogen
			name = "Nitrogen"
			id = "nitrogen"
			description = "A colorless, odorless, tasteless gas."
			reagent_state = GAS
			color = "#808080" // rgb: 128, 128, 128

			custom_metabolism = 0.01

			on_mob_life(mob/living/M, alien)
				if(!..())
					return
				if(M.stat == DEAD)
					return
				if(alien && alien == IS_VOX)
					M.adjustOxyLoss(-2 * REM)
					holder.remove_reagent(src.id, REAGENTS_METABOLISM) //By default it slowly disappears.

		hydrogen
			name = "Hydrogen"
			id = "hydrogen"
			description = "A colorless, odorless, nonmetallic, tasteless, highly combustible diatomic gas."
			reagent_state = GAS
			color = "#808080" // rgb: 128, 128, 128

			custom_metabolism = 0.01

		potassium
			name = "Potassium"
			id = "potassium"
			description = "A soft, low-melting solid that can easily be cut with a knife. Reacts violently with water."
			reagent_state = SOLID
			color = "#A0A0A0" // rgb: 160, 160, 160

			custom_metabolism = 0.01

		mercury
			name = "Mercury"
			id = "mercury"
			description = "A chemical element."
			reagent_state = LIQUID
			color = "#484848" // rgb: 72, 72, 72
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(M.canmove && !M.restrained() && istype(M.loc, /turf/space))
					step(M, pick(cardinal))
				if(prob(5))
					M.emote(pick("twitch","drool","moan"))
				M.adjustBrainLoss(2)

		sulfur
			name = "Sulfur"
			id = "sulfur"
			description = "A chemical element with a pungent smell."
			reagent_state = SOLID
			color = "#BF8C00" // rgb: 191, 140, 0

			custom_metabolism = 0.01

		carbon
			name = "Carbon"
			id = "carbon"
			description = "A chemical element, the builing block of life."
			reagent_state = SOLID
			color = "#1C1300" // rgb: 30, 20, 0

			custom_metabolism = 0.01

			reaction_turf(var/turf/T, var/volume)
				src = null
				if(!istype(T, /turf/space))
					var/obj/effect/decal/cleanable/dirt/dirtoverlay = locate(/obj/effect/decal/cleanable/dirt, T)
					if (!dirtoverlay)
						dirtoverlay = new/obj/effect/decal/cleanable/dirt(T)
						dirtoverlay.alpha = volume * 30
					else
						dirtoverlay.alpha = min(dirtoverlay.alpha + volume * 30, 255)

		chlorine
			name = "Chlorine"
			id = "chlorine"
			description = "A chemical element with a characteristic odour."
			reagent_state = GAS
			color = "#808080" // rgb: 128, 128, 128
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.take_bodypart_damage(1 * REM, 0)

		fluorine
			name = "Fluorine"
			id = "fluorine"
			description = "A highly-reactive chemical element."
			reagent_state = GAS
			color = "#808080" // rgb: 128, 128, 128
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.adjustToxLoss(1 * REM)

		sodium
			name = "Sodium"
			id = "sodium"
			description = "A chemical element, readily reacts with water."
			reagent_state = SOLID
			color = "#808080" // rgb: 128, 128, 128

			custom_metabolism = 0.01

		phosphorus
			name = "Phosphorus"
			id = "phosphorus"
			description = "A chemical element, the backbone of biological energy carriers."
			reagent_state = SOLID
			color = "#832828" // rgb: 131, 40, 40

			custom_metabolism = 0.01

		lithium
			name = "Lithium"
			id = "lithium"
			description = "A chemical element, used as antidepressant."
			reagent_state = SOLID
			color = "#808080" // rgb: 128, 128, 128
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(M.canmove && !M.restrained() && istype(M.loc, /turf/space))
					step(M, pick(cardinal))
				if(prob(5))
					M.emote(pick("twitch","drool","moan"))

		sugar
			name = "Sugar"
			id = "sugar"
			description = "The organic compound commonly known as table sugar and sometimes called saccharose. This white, odorless, crystalline powder has a pleasing, sweet taste."
			reagent_state = SOLID
			color = "#FFFFFF" // rgb: 255, 255, 255

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.nutrition += 1 * REM

		glycerol
			name = "Glycerol"
			id = "glycerol"
			description = "Glycerol is a simple polyol compound. Glycerol is sweet-tasting and of low toxicity."
			reagent_state = LIQUID
			color = "#808080" // rgb: 128, 128, 128

			custom_metabolism = 0.01

		nitroglycerin
			name = "Nitroglycerin"
			id = "nitroglycerin"
			description = "Nitroglycerin is a heavy, colorless, oily, explosive liquid obtained by nitrating glycerol."
			reagent_state = LIQUID
			color = "#808080" // rgb: 128, 128, 128

			custom_metabolism = 0.01

		radium
			name = "Radium"
			id = "radium"
			description = "Radium is an alkaline earth metal. It is extremely radioactive."
			reagent_state = SOLID
			color = "#C7C7C7" // rgb: 199,199,199

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.apply_effect(2 * REM,IRRADIATE, 0)
				// radium may increase your chances to cure a disease
				if(istype(M,/mob/living/carbon)) // make sure to only use it on carbon mobs
					var/mob/living/carbon/C = M
					if(C.virus2.len)
						for(var/ID in C.virus2)
							var/datum/disease2/disease/V = C.virus2[ID]
							if(prob(5))
								if(prob(50))
									M.radiation += 50 // curing it that way may kill you instead
									var/mob/living/carbon/human/H
									if(istype(C,/mob/living/carbon/human))
										H = C
									if(!H || (H.species && !H.species.flags[RAD_ABSORB]))
										M.adjustToxLoss(100)
								M:antibodies |= V.antigen

			reaction_turf(var/turf/T, var/volume)
				src = null
				if(volume >= 3)
					if(!istype(T, /turf/space))
						var/obj/effect/decal/cleanable/greenglow/glow = locate(/obj/effect/decal/cleanable/greenglow, T)
						if(!glow)
							new /obj/effect/decal/cleanable/greenglow(T)
						return


		ryetalyn
			name = "Ryetalyn"
			id = "ryetalyn"
			description = "Ryetalyn can cure all genetic abnomalities via a catalytic process."
			reagent_state = SOLID
			color = "#C8A5DC" // rgb: 200, 165, 220
			overdose = REAGENTS_OVERDOSE
			custom_metabolism = 0

			on_mob_life(mob/living/M)
				if(!..())
					return

				M.remove_any_mutations()
				holder.del_reagent(id)

		thermite
			name = "Thermite"
			id = "thermite"
			description = "Thermite produces an aluminothermic reaction known as a thermite reaction. Can be used to melt walls."
			reagent_state = SOLID
			color = "#673910" // rgb: 103, 57, 16

			reaction_turf(var/turf/T, var/volume)
				src = null
				if(volume >= 5)
					if(istype(T, /turf/simulated/wall))
						var/turf/simulated/wall/W = T
						W.thermite = 1
						W.overlays += image('icons/effects/effects.dmi',icon_state = "#673910")
				return

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.adjustFireLoss(1)

		paracetamol
			name = "Paracetamol"
			id = "paracetamol"
			description = "Most probably know this as Tylenol, but this chemical is a mild, simple painkiller."
			reagent_state = LIQUID
			color = "#C855DC"
			overdose = 60

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(volume > overdose)
					M.hallucination = max(M.hallucination, 2)

		tramadol
			name = "Tramadol"
			id = "tramadol"
			description = "A simple, yet effective painkiller."
			reagent_state = LIQUID
			color = "#C8A5DC"
			overdose = 30
			custom_metabolism = 0.025

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(volume > overdose)
					M.hallucination = max(M.hallucination, 2)

		oxycodone
			name = "Oxycodone"
			id = "oxycodone"
			description = "An effective and very addictive painkiller."
			reagent_state = LIQUID
			color = "#C805DC"
			overdose = 20
			custom_metabolism = 0.025

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(volume > overdose)
					M.druggy = max(M.druggy, 10)
					M.hallucination = max(M.hallucination, 3)

		virus_food
			name = "Virus Food"
			id = "virusfood"
			description = "A mixture of water, milk, and oxygen. Virus cells can use this mixture to reproduce."
			reagent_state = LIQUID
			nutriment_factor = 2 * REAGENTS_METABOLISM
			color = "#899613" // rgb: 137, 150, 19

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.nutrition += nutriment_factor * REM

		sterilizine
			name = "Sterilizine"
			id = "sterilizine"
			description = "Sterilizes wounds in preparation for surgery."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220

			//makes you squeaky clean
			reaction_mob(mob/living/M, method=TOUCH, volume)
				if (method == TOUCH)
					M.germ_level -= min(volume*20, M.germ_level)

			reaction_obj(var/obj/O, var/volume)
				O.germ_level -= min(volume*20, O.germ_level)

			reaction_turf(var/turf/T, var/volume)
				T.germ_level -= min(volume*20, T.germ_level)

	/*		reaction_mob(mob/living/M, method=TOUCH, volume)
				src = null
				if (method==TOUCH)
					if(istype(M, /mob/living/carbon/human))
						if(M.health >= -100 && M.health <= 0)
							M.crit_op_stage = 0.0
				if (method==INGEST)
					to_chat(usr, "Well, that was stupid.")
					M.adjustToxLoss(3)
				return
			on_mob_life(var/mob/living/M as mob)
				if(!M) M = holder.my_atom
					M.radiation += 3
					..()
					return
	*/
		iron
			name = "Iron"
			id = "iron"
			description = "Pure iron is a metal."
			reagent_state = SOLID
			color = "#C8A5DC" // rgb: 200, 165, 220
			overdose = REAGENTS_OVERDOSE

		gold
			name = "Gold"
			id = "gold"
			description = "Gold is a dense, soft, shiny metal and the most malleable and ductile metal known."
			reagent_state = SOLID
			color = "#F7C430" // rgb: 247, 196, 48

		silver
			name = "Silver"
			id = "silver"
			description = "A soft, white, lustrous transition metal, it has the highest electrical conductivity of any element and the highest thermal conductivity of any metal."
			reagent_state = SOLID
			color = "#D0D0D0" // rgb: 208, 208, 208

		uranium
			name ="Uranium"
			id = "uranium"
			description = "A silvery-white metallic chemical element in the actinide series, weakly radioactive."
			reagent_state = SOLID
			color = "#B8B8C0" // rgb: 184, 184, 192

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.apply_effect(1, IRRADIATE, 0)

			reaction_turf(var/turf/T, var/volume)
				src = null
				if(volume >= 3)
					if(!istype(T, /turf/space))
						var/obj/effect/decal/cleanable/greenglow/glow = locate(/obj/effect/decal/cleanable/greenglow, T)
						if(!glow)
							new /obj/effect/decal/cleanable/greenglow(T)
						return

		aluminum
			name = "Aluminum"
			id = "aluminum"
			description = "A silvery white and ductile member of the boron group of chemical elements."
			reagent_state = SOLID
			color = "#A8A8A8" // rgb: 168, 168, 168

		silicon
			name = "Silicon"
			id = "silicon"
			description = "A tetravalent metalloid, silicon is less reactive than its chemical analog carbon."
			reagent_state = SOLID
			color = "#A8A8A8" // rgb: 168, 168, 168

		fuel
			name = "Welding fuel"
			id = "fuel"
			description = "Required for welders. Flamable."
			reagent_state = LIQUID
			color = "#660000" // rgb: 102, 0, 0
			overdose = REAGENTS_OVERDOSE

			reaction_obj(var/obj/O, var/volume)
				var/turf/the_turf = get_turf(O)
				if(!the_turf)
					return //No sense trying to start a fire if you don't have a turf to set on fire. --NEO
				new /obj/effect/decal/cleanable/liquid_fuel(the_turf, volume)

			reaction_turf(var/turf/T, var/volume)
				new /obj/effect/decal/cleanable/liquid_fuel(T, volume)
				return

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.adjustToxLoss(1)

			reaction_mob(mob/living/M, method=TOUCH, volume)//Splashing people with welding fuel to make them easy to ignite!
				if(!istype(M, /mob/living))
					return
				if(method == TOUCH)
					M.adjust_fire_stacks(volume / 10)
					return

		space_cleaner
			name = "Space cleaner"
			id = "cleaner"
			description = "A compound used to clean things. Now with 50% more sodium hypochlorite!"
			reagent_state = LIQUID
			color = "#A5F0EE" // rgb: 165, 240, 238
			overdose = REAGENTS_OVERDOSE

			reaction_obj(var/obj/O, var/volume)
				if(istype(O,/obj/effect/decal/cleanable))
					qdel(O)
				else
					if(O)
						O.clean_blood()

			reaction_turf(var/turf/T, var/volume)
				if(volume >= 1)
					if(istype(T, /turf/simulated))
						var/turf/simulated/S = T
						S.dirt = 0
					T.clean_blood()
					for(var/obj/effect/decal/cleanable/C in T.contents)
						src.reaction_obj(C, volume)
						qdel(C)

					for(var/mob/living/carbon/slime/M in T)
						M.adjustToxLoss(rand(5,10))

			reaction_mob(mob/M, method=TOUCH, volume)
				if(iscarbon(M))
					var/mob/living/carbon/C = M
					if(istype(M,/mob/living/carbon/human))
						var/mob/living/carbon/human/H = M
						if(H.lip_style)
							H.lip_style = null
							H.update_body()
					if(C.r_hand)
						C.r_hand.clean_blood()
					if(C.l_hand)
						C.l_hand.clean_blood()
					if(C.wear_mask)
						if(C.wear_mask.clean_blood())
							C.update_inv_wear_mask()
					if(ishuman(M))
						var/mob/living/carbon/human/H = C
						if(H.head)
							if(H.head.clean_blood())
								H.update_inv_head()
						if(H.wear_suit)
							if(H.wear_suit.clean_blood())
								H.update_inv_wear_suit()
						else if(H.w_uniform)
							if(H.w_uniform.clean_blood())
								H.update_inv_w_uniform()
						if(H.shoes)
							if(H.shoes.clean_blood())
								H.update_inv_shoes()
						else
							H.clean_blood(1)
							return
					M.clean_blood()

		leporazine
			name = "Leporazine"
			id = "leporazine"
			description = "Leporazine can be use to stabilize an individuals body temperature."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(M.bodytemperature > 310)
					M.bodytemperature = max(310, M.bodytemperature - (40 * TEMPERATURE_DAMAGE_COEFFICIENT))
				else if(M.bodytemperature < 311)
					M.bodytemperature = min(310, M.bodytemperature + (40 * TEMPERATURE_DAMAGE_COEFFICIENT))

		cryptobiolin
			name = "Cryptobiolin"
			id = "cryptobiolin"
			description = "Cryptobiolin causes confusion and dizzyness."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220
			overdose = REAGENTS_OVERDOSE
			custom_metabolism = REAGENTS_METABOLISM * 0.5

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.make_dizzy(1)
				if(!M.confused)
					M.confused = 1
				M.confused = max(M.confused, 20)

		kelotane
			name = "Kelotane"
			id = "kelotane"
			description = "Kelotane is a drug used to treat burns."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(M.stat == DEAD)
					return
				//This needs a diona check but if one is added they won't be able to heal burn damage at all.
				M.heal_bodypart_damage(0,2 * REM)

		dermaline
			name = "Dermaline"
			id = "dermaline"
			description = "Dermaline is the next step in burn medication. Works twice as good as kelotane and enables the body to restore even the direst heat-damaged tissue."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220
			overdose = REAGENTS_OVERDOSE * 0.5

			on_mob_life(mob/living/M, alien)
				if(!..())
					return
				if(M.stat == DEAD) //THE GUY IS **DEAD**! BEREFT OF ALL LIFE HE RESTS IN PEACE etc etc. He does NOT metabolise shit anymore, god DAMN
					return
				if(!alien || alien != IS_DIONA)
					M.heal_bodypart_damage(0,3 * REM)

		dexalin
			name = "Dexalin"
			id = "dexalin"
			description = "Dexalin is used in the treatment of oxygen deprivation."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M, alien)
				if(!..())
					return
				if(M.stat == DEAD)
					return  //See above, down and around. --Agouri

				if(alien && alien == IS_VOX)
					M.adjustToxLoss(2 * REM)
				else if(!alien || alien != IS_DIONA)
					M.adjustOxyLoss(-2 * REM)

				if(holder.has_reagent("lexorin"))
					holder.remove_reagent("lexorin", 2 * REM)

		dexalinp
			name = "Dexalin Plus"
			id = "dexalinp"
			description = "Dexalin Plus is used in the treatment of oxygen deprivation. It is highly effective."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220
			overdose = REAGENTS_OVERDOSE * 0.5

			on_mob_life(mob/living/M, alien)
				if(!..())
					return
				if(M.stat == DEAD)
					return
				if(alien && alien == IS_VOX)
					M.adjustOxyLoss()
				else if(!alien || alien != IS_DIONA)
					M.adjustOxyLoss(-M.getOxyLoss())

				if(holder.has_reagent("lexorin"))
					holder.remove_reagent("lexorin", 2 * REM)

		tricordrazine
			name = "Tricordrazine"
			id = "tricordrazine"
			description = "Tricordrazine is a highly potent stimulant, originally derived from cordrazine. Can be used to treat a wide range of injuries."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220

			on_mob_life(mob/living/M, alien)
				if(!..())
					return
				if(M.stat == DEAD)
					return
				if(!alien || alien != IS_DIONA)
					if(M.getOxyLoss())
						M.adjustOxyLoss(-1 * REM)
					if(M.getBruteLoss() && prob(80))
						M.heal_bodypart_damage(1 * REM, 0)
					if(M.getFireLoss() && prob(80))
						M.heal_bodypart_damage(0, 1 * REM)
					if(M.getToxLoss() && prob(80))
						M.adjustToxLoss(-1 * REM)

		anti_toxin
			name = "Anti-Toxin (Dylovene)"
			id = "anti_toxin"
			description = "Dylovene is a broad-spectrum antitoxin."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220

			on_mob_life(mob/living/M, alien)
				if(!..())
					return
				if(!alien || alien != IS_DIONA)
					M.reagents.remove_all_type(/datum/reagent/toxin, 1 * REM, 0, 1)
					M.drowsyness = max(M.drowsyness - 2 * REM, 0)
					M.hallucination = max(0, M.hallucination - 5 * REM)
					M.adjustToxLoss(-2 * REM)

		adminordrazine //An OP chemical for admins
			name = "Adminordrazine"
			id = "adminordrazine"
			description = "It's magic. We don't have to explain it."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.reagents.remove_all_type(/datum/reagent/toxin, 5 * REM, 0, 1)
				M.setCloneLoss(0)
				M.setOxyLoss(0)
				M.radiation = 0
				M.heal_bodypart_damage(5,5)
				M.adjustToxLoss(-5)
				M.hallucination = 0
				M.setBrainLoss(0)
				M.disabilities = 0
				M.sdisabilities = 0
				M.eye_blurry = 0
				M.eye_blind = 0
				M.SetWeakened(0)
				M.SetStunned(0)
				M.SetParalysis(0)
				M.silent = 0
				M.dizziness = 0
				M.drowsyness = 0
				M.stuttering = 0
				M.confused = 0
				M.sleeping = 0
				M.jitteriness = 0
				for(var/datum/disease/D in M.viruses)
					D.spread = "Remissive"
					D.stage--
					if(D.stage < 1)
						D.cure()

		synaptizine
			name = "Synaptizine"
			id = "synaptizine"
			description = "Synaptizine is used to treat various diseases."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220
			custom_metabolism = 0.01
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.drowsyness = max(M.drowsyness - 5, 0)
				M.AdjustParalysis(-1)
				M.AdjustStunned(-1)
				M.AdjustWeakened(-1)
				if(holder.has_reagent("mindbreaker"))
					holder.remove_reagent("mindbreaker", 5)
				M.hallucination = max(0, M.hallucination - 10)
				if(prob(60))
					M.adjustToxLoss(1)

		impedrezene
			name = "Impedrezene"
			id = "impedrezene"
			description = "Impedrezene is a narcotic that impedes one's ability by slowing down the higher brain cell functions."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.jitteriness = max(M.jitteriness - 5, 0)
				if(prob(80))
					M.adjustBrainLoss(1 * REM)
				if(prob(50))
					M.drowsyness = max(M.drowsyness, 3)
				if(prob(10))
					M.emote("drool")

		hyronalin
			name = "Hyronalin"
			id = "hyronalin"
			description = "Hyronalin is a medicinal drug used to counter the effect of radiation poisoning."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220
			custom_metabolism = 0.05
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.radiation = max(M.radiation - 3 * REM, 0)

		arithrazine
			name = "Arithrazine"
			id = "arithrazine"
			description = "Arithrazine is an unstable medication used for the most extreme cases of radiation poisoning."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220
			custom_metabolism = 0.05
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(M.stat == DEAD)
					return  //See above, down and around. --Agouri
				M.radiation = max(M.radiation - 7 * REM, 0)
				M.adjustToxLoss(-1 * REM)
				if(prob(15))
					M.take_bodypart_damage(1, 0)

		alkysine
			name = "Alkysine"
			id = "alkysine"
			description = "Alkysine is a drug used to lessen the damage to neurological tissue after a catastrophic injury. Can heal brain tissue."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220
			custom_metabolism = 0.05
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.adjustBrainLoss(-3 * REM)

		imidazoline
			name = "Imidazoline"
			id = "imidazoline"
			description = "Heals eye damage"
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.eye_blurry = max(M.eye_blurry - 5, 0)
				M.eye_blind = max(M.eye_blind - 5, 0)
				if(ishuman(M))
					var/mob/living/carbon/human/H = M
					var/obj/item/organ/internal/eyes/IO = H.organs_by_name[O_EYES]
					if(istype(IO))
						if(IO.damage > 0)
							IO.damage = max(IO.damage - 1, 0)

		peridaxon
			name = "Peridaxon"
			id = "peridaxon"
			description = "Used to encourage recovery of organs and nervous systems. Medicate cautiously."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220
			overdose = 10

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(ishuman(M))
					var/mob/living/carbon/human/H = M

					//Peridaxon is hard enough to get, it's probably fair to make this all organs
					for(var/obj/item/organ/internal/IO in H.organs)
						if(IO.damage > 0)
							IO.damage = max(IO.damage - 0.20, 0)

		kyphotorin
			name = "Kyphotorin"
			id = "kyphotorin"
			description = "Used nanites to encourage recovery of body parts and bones. Medicate cautiously."
			reagent_state = LIQUID
			color = "#551a8b" // rgb: 85, 26, 139
			overdose = 5.1
			custom_metabolism = 0.07
			var/heal_time = 0
			var/obj/item/organ/external/External

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(!ishuman(M) || volume > overdose)
					return
				var/mob/living/carbon/human/H = M
				if(H.nutrition < 200) // if nanites doesn't have enough resources, they're stops working and spends
					H.make_jittery(100)
					volume += 0.07
					return
				H.jitteriness = max(0,H.jitteriness - 100)
				if(!External)
					for(var/obj/item/organ/external/BP in H.bodyparts) // find a broken/destroyed limb
						if(BP.status & ORGAN_DESTROYED)
							if(BP.parent && (BP.parent.status & ORGAN_DESTROYED))
								continue
							else
								heal_time = 65
								External = BP
						else if(BP.status & (ORGAN_BROKEN | ORGAN_SPLINTED))
							heal_time = 30
							External = BP
						if(External)
							break
				else if(H.bodytemperature >= 170 && H.vessel) // start fixing broken/destroyed limb
					for(var/datum/reagent/blood/B in H.vessel.reagent_list)
						B.volume -= 4
					H.nutrition -= 3
					H.apply_effect(3, WEAKEN)
					H.apply_damages(0,0,1,4,0,5) // 1 toxic, 4 oxy and 5 halloss
					data++
					if(data == 1)
						H.visible_message("<span class='notice'>You see oddly moving in [H]'s [External.name]...</span>"
					 	,"<span class='notice'> You feel strange vibration on tips of your [External.name]... </span>")
					if(data == 10)
						H.visible_message("<span class='notice'>You hear sickening crunch In [H]'s [External.name]...</span>")
					if(data == 20)
						H.visible_message("<span class='notice'>[H]'s [External.name] shortly bends...</span>")
					if(data == 30)
						if(heal_time == 30)
							H.visible_message("<span class='notice'>[H] stirs his [External.name]...</span>","<span class='userdanger'>You feel freedom in moving your [External.name]</span>")
						else
							H.visible_message("<span class='notice'>From [H]'s [External.parent.name] grow small meaty sprout...</span>")
					if(data == 50)
						H.visible_message("<span class='notice'>You see something resembling [External.name] at [H]'s [External.parent.name]...</span>")
					if(data == 65)
						H.visible_message("<span class='userdanger'>A new [External.name] grown from [H]'s [External.parent.name]!</span>","<span class='userdanger'>You feel again your [External.name]!</span>")
					if(prob(50))
						H.emote("scream",1,null,1)
					if(data >= heal_time) // recover organ
						External.rejuvenate()
						data = 0
						External = null
						heal_time = 0

		bicaridine
			name = "Bicaridine"
			id = "bicaridine"
			description = "Bicaridine is an analgesic medication and can be used to treat blunt trauma."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M, alien)
				if(!..())
					return
				if(M.stat == DEAD)
					return
				if(!alien || alien != IS_DIONA)
					M.heal_bodypart_damage(2 * REM, 0)

		hyperzine
			name = "Hyperzine"
			id = "hyperzine"
			description = "Hyperzine is a highly effective, long lasting, muscle stimulant."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220
			custom_metabolism = 0.03
			overdose = REAGENTS_OVERDOSE * 0.5

			on_mob_life(mob/living/M, alien)
				if(!..())
					return
				if(!alien || alien != IS_DIONA)
					if(prob(5))
						M.emote(pick("twitch","blink_r","shiver"))

		cryoxadone
			name = "Cryoxadone"
			id = "cryoxadone"
			description = "A chemical mixture with almost magical healing powers. Its main limitation is that the targets body temperature must be under 170K for it to metabolise correctly."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(M.bodytemperature < 170)
					M.adjustCloneLoss(-1)
					M.adjustOxyLoss(-1)
					M.heal_bodypart_damage(1, 1)
					M.adjustToxLoss(-1)

		clonexadone
			name = "Clonexadone"
			id = "clonexadone"
			description = "A liquid compound similar to that used in the cloning process. Can be used to 'finish' the cloning process when used in conjunction with a cryo tube."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(M.bodytemperature < 170)
					M.adjustCloneLoss(-3)
					M.adjustOxyLoss(-3)
					M.heal_bodypart_damage(3, 3)
					M.adjustToxLoss(-3)

		rezadone
			name = "Rezadone"
			id = "rezadone"
			description = "A powder derived from fish toxin, this substance can effectively treat genetic damage in humanoids, though excessive consumption has side effects."
			reagent_state = SOLID
			color = "#669900" // rgb: 102, 153, 0
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(!data)
					data = 1
				data++
				switch(data)
					if(1 to 15)
						M.adjustCloneLoss(-1)
						M.heal_bodypart_damage(1, 1)
					if(15 to 35)
						M.adjustCloneLoss(-2)
						M.heal_bodypart_damage(2, 1)
						M.status_flags &= ~DISFIGURED
					if(35 to INFINITY)
						M.adjustToxLoss(1)
						M.make_dizzy(5)
						M.make_jittery(5)

		spaceacillin
			name = "Spaceacillin"
			id = "spaceacillin"
			description = "An all-purpose antiviral agent."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220
			custom_metabolism = 0.01
			overdose = REAGENTS_OVERDOSE

///////////////////////////////////////////////////////////////////////////////////////////////////////////////

		nanites
			name = "Nanomachines"
			id = "nanites"
			description = "Microscopic construction robots."
			reagent_state = LIQUID
			color = "#535E66" // rgb: 83, 94, 102

			reaction_mob(mob/M, method=TOUCH, volume)
				src = null
				if( (prob(10) && method==TOUCH) || method==INGEST)
					M.contract_disease(new /datum/disease/robotic_transformation(0),1)

		xenomicrobes
			name = "Xenomicrobes"
			id = "xenomicrobes"
			description = "Microbes with an entirely alien cellular structure."
			reagent_state = LIQUID
			color = "#535E66" // rgb: 83, 94, 102

			reaction_mob(mob/M, method=TOUCH, volume)
				src = null
				if( (prob(10) && method==TOUCH) || method==INGEST)
					M.contract_disease(new /datum/disease/xeno_transformation(0),1)

		fluorosurfactant//foam precursor
			name = "Fluorosurfactant"
			id = "fluorosurfactant"
			description = "A perfluoronated sulfonic acid that forms a foam when mixed with water."
			reagent_state = LIQUID
			color = "#9E6B38" // rgb: 158, 107, 56

		foaming_agent// Metal foaming agent. This is lithium hydride. Add other recipes (e.g. LiH + H2O -> LiOH + H2) eventually.
			name = "Foaming agent"
			id = "foaming_agent"
			description = "A agent that yields metallic foam when mixed with light metal and a strong acid."
			reagent_state = SOLID
			color = "#664B63" // rgb: 102, 75, 99

		nicotine
			name = "Nicotine"
			id = "nicotine"
			description = "A highly addictive stimulant extracted from the tobacco plant."
			reagent_state = LIQUID
			color = "#181818" // rgb: 24, 24, 24

		ammonia
			name = "Ammonia"
			id = "ammonia"
			description = "A caustic substance commonly used in fertilizer or household cleaners."
			reagent_state = GAS
			color = "#404030" // rgb: 64, 64, 48

		ultraglue
			name = "Ultra Glue"
			id = "glue"
			description = "An extremely powerful bonding agent."
			color = "#FFFFCC" // rgb: 255, 255, 204

		diethylamine
			name = "Diethylamine"
			id = "diethylamine"
			description = "A secondary amine, mildly corrosive."
			reagent_state = LIQUID
			color = "#604030" // rgb: 96, 64, 48

		ethylredoxrazine	// FUCK YOU, ALCOHOL
			name = "Ethylredoxrazine"
			id = "ethylredoxrazine"
			description = "A powerful oxidizer that reacts with ethanol."
			reagent_state = SOLID
			color = "#605048" // rgb: 96, 80, 72
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.dizziness = 0
				M.drowsyness = 0
				M.stuttering = 0
				M.confused = 0
				M.reagents.remove_all_type(/datum/reagent/ethanol, 1 * REM, 0, 1)

//////////////////////////Poison stuff///////////////////////

		toxin
			name = "Toxin"
			id = "toxin"
			description = "A toxic chemical."
			reagent_state = LIQUID
			color = "#CF3600" // rgb: 207, 54, 0
			var/toxpwr = 0.7 // Toxins are really weak, but without being treated, last very long.
			custom_metabolism = 0.1

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(toxpwr)
					M.adjustToxLoss(toxpwr * REM)
				return TRUE //toxin has many subclasses, so we need return TRUE for them.

		toxin/amatoxin
			name = "Amatoxin"
			id = "amatoxin"
			description = "A powerful poison derived from certain species of mushroom."
			reagent_state = LIQUID
			color = "#792300" // rgb: 121, 35, 0
			toxpwr = 1

		toxin/mutagen
			name = "Unstable mutagen"
			id = "mutagen"
			description = "Might cause unpredictable mutations. Keep away from children."
			reagent_state = LIQUID
			color = "#13BC5E" // rgb: 19, 188, 94
			toxpwr = 0

			reaction_mob(mob/living/carbon/M, method=TOUCH, volume)
				if(!..())	return
				if(!istype(M) || !M.dna)	return  //No robots, AIs, aliens, Ians or other mobs should be affected by this.
				src = null
				if((method==TOUCH && prob(33)) || method==INGEST)
					randmuti(M)
					if(prob(98))	randmutb(M)
					else			randmutg(M)
					domutcheck(M, null)
					M.UpdateAppearance()
				return
			on_mob_life(mob/living/M)
				if(!..())
					return
				M.apply_effect(10, IRRADIATE, 0)

		toxin/phoron
			name = "Phoron"
			id = "phoron"
			description = "Phoron in its liquid form."
			reagent_state = LIQUID
			color = "#E71B00" // rgb: 231, 27, 0
			toxpwr = 3

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(holder.has_reagent("inaprovaline"))
					holder.remove_reagent("inaprovaline", 2 * REM)

			reaction_obj(var/obj/O, var/volume)
				src = null
				/*if(istype(O,/obj/item/weapon/reagent_containers/food/snacks/egg/slime))
					var/obj/item/weapon/reagent_containers/food/snacks/egg/slime/egg = O
					if (egg.grown)
						egg.Hatch()*/
				if((!O) || (!volume))	return 0
				if(volume < 0) return 0
				if(volume > 300) return 0

				var/turf/simulated/T = get_turf(O)
				if(!istype(T))
					return
				T.assume_gas("phoron", volume, T20C)
			reaction_turf(var/turf/simulated/T, var/volume)
				if(volume < 0) return
				if(volume > 300) return

				if(!istype(T))
					return
				T.assume_gas("phoron", volume, T20C)
			reaction_mob(mob/living/M, method=TOUCH, volume)//Splashing people with plasma is stronger than fuel!
				if(!istype(M, /mob/living))
					return
				if(method == TOUCH)
					M.adjust_fire_stacks(volume / 5)
					return

		toxin/lexorin
			name = "Lexorin"
			id = "lexorin"
			description = "Lexorin temporarily stops respiration. Causes tissue damage."
			reagent_state = LIQUID
			color = "#C8A5DC" // rgb: 200, 165, 220
			toxpwr = 0
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(M.stat == DEAD)
					return
				if(prob(33))
					M.take_bodypart_damage(1 * REM, 0)
				M.adjustOxyLoss(3)
				if(prob(20))
					M.emote("gasp")

		toxin/slimejelly
			name = "Slime Jelly"
			id = "slimejelly"
			description = "A gooey semi-liquid produced from one of the deadliest lifeforms in existence. SO REAL."
			reagent_state = LIQUID
			color = "#801E28" // rgb: 128, 30, 40
			toxpwr = 0

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(prob(10))
					to_chat(M, "\red Your insides are burning!")
					M.adjustToxLoss(rand(20,60) * REM)
				else if(prob(40))
					M.heal_bodypart_damage(5 * REM, 0)

		toxin/cyanide //Fast and Lethal
			name = "Cyanide"
			id = "cyanide"
			description = "A highly toxic chemical."
			reagent_state = LIQUID
			color = "#CF3600" // rgb: 207, 54, 0
			toxpwr = 4
			custom_metabolism = 0.4

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.adjustOxyLoss(4 * REM)
				M.sleeping += 1

		toxin/minttoxin
			name = "Mint Toxin"
			id = "minttoxin"
			description = "Useful for dealing with undesirable customers."
			reagent_state = LIQUID
			color = "#CF3600" // rgb: 207, 54, 0
			toxpwr = 0

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(FAT in M.mutations)
					M.gib()

		toxin/carpotoxin
			name = "Carpotoxin"
			id = "carpotoxin"
			description = "A deadly neurotoxin produced by the dreaded space carp."
			reagent_state = LIQUID
			color = "#003333" // rgb: 0, 51, 51
			toxpwr = 2

		toxin/zombiepowder
			name = "Zombie Powder"
			id = "zombiepowder"
			description = "A strong neurotoxin that puts the subject into a death-like state."
			reagent_state = SOLID
			color = "#669900" // rgb: 102, 153, 0
			toxpwr = 0.5

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.status_flags |= FAKEDEATH
				M.adjustOxyLoss(0.5 * REM)
				M.Weaken(10)
				M.silent = max(M.silent, 10)
				M.tod = worldtime2text()

			Destroy()
				if(holder && ismob(holder.my_atom))
					var/mob/M = holder.my_atom
					M.status_flags &= ~FAKEDEATH
				return ..()

		toxin/mindbreaker
			name = "Mindbreaker Toxin"
			id = "mindbreaker"
			description = "A powerful hallucinogen, it can cause fatal effects in users."
			reagent_state = LIQUID
			color = "#B31008" // rgb: 139, 166, 233
			toxpwr = 0
			custom_metabolism = 0.05
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.hallucination += 10

		toxin/plantbgone
			name = "Plant-B-Gone"
			id = "plantbgone"
			description = "A harmful toxic mixture to kill plantlife. Do not ingest!"
			reagent_state = LIQUID
			color = "#49002E" // rgb: 73, 0, 46
			toxpwr = 1

			// Clear off wallrot fungi
			reaction_turf(var/turf/T, var/volume)
				if(istype(T, /turf/simulated/wall))
					var/turf/simulated/wall/W = T
					if(W.rotting)
						W.rotting = 0
						for(var/obj/effect/E in W) if(E.name == "Wallrot") qdel(E)

						for(var/mob/O in viewers(W, null))
							O.show_message(text("\blue The fungi are completely dissolved by the solution!"), 1)

			reaction_obj(var/obj/O, var/volume)
				if(istype(O,/obj/structure/alien/weeds))
					var/obj/structure/alien/weeds/alien_weeds = O
					alien_weeds.health -= rand(15,35) // Kills alien weeds pretty fast
					alien_weeds.healthcheck()
				else if(istype(O,/obj/effect/glowshroom)) //even a small amount is enough to kill it
					qdel(O)
				else if(istype(O,/obj/effect/spacevine))
					if(prob(50)) del(O) //Kills kudzu too.
				// Damage that is done to growing plants is separately at code/game/machinery/hydroponics at obj/item/hydroponics

			reaction_mob(mob/living/M, method=TOUCH, volume)
				src = null
				if(iscarbon(M))
					var/mob/living/carbon/C = M
					if(!C.wear_mask) // If not wearing a mask
						C.adjustToxLoss(2) // 4 toxic damage per application, doubled for some reason
					if(ishuman(M))
						var/mob/living/carbon/human/H = M
						if(H.dna)
							if(H.species.flags[IS_PLANT]) //plantmen take a LOT of damage
								H.adjustToxLoss(50)

		toxin/stoxin
			name = "Sleep Toxin"
			id = "stoxin"
			description = "An effective hypnotic used to treat insomnia."
			reagent_state = LIQUID
			color = "#E895CC" // rgb: 232, 149, 204
			toxpwr = 0
			custom_metabolism = 0.1
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(!data)
					data = 1
				switch(data)
					if(1 to 12)
						if(prob(5))
							M.emote("yawn")
					if(12 to 15)
						M.eye_blurry = max(M.eye_blurry, 10)
					if(15 to 49)
						if(prob(50))
							M.Weaken(2)
						M.drowsyness  = max(M.drowsyness, 20)
					if(50 to INFINITY)
						M.Weaken(20)
						M.drowsyness  = max(M.drowsyness, 30)
				data++

		toxin/chloralhydrate
			name = "Chloral Hydrate"
			id = "chloralhydrate"
			description = "A powerful sedative."
			reagent_state = SOLID
			color = "#000067" // rgb: 0, 0, 103
			toxpwr = 0
			custom_metabolism = 0.1 //Default 0.2
			overdose = 15
			overdose_dam = 6

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(!data)
					data = 1
				data++
				switch(data)
					if(1)
						M.confused += 2
						M.drowsyness += 2
					if(2 to 199)
						M.Weaken(30)
					if(200 to INFINITY)
						M.sleeping += 1

		toxin/potassium_chloride
			name = "Potassium Chloride"
			id = "potassium_chloride"
			description = "A delicious salt that stops the heart when injected into cardiac muscle."
			reagent_state = SOLID
			color = "#FFFFFF" // rgb: 255,255,255
			toxpwr = 0
			overdose = 30

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(M.stat != UNCONSCIOUS)
					if (volume >= overdose)
						if(M.losebreath >= 10)
							M.losebreath = max(10, M.losebreath - 10)
						M.adjustOxyLoss(2)
						M.Weaken(10)

		toxin/potassium_chlorophoride
			name = "Potassium Chlorophoride"
			id = "potassium_chlorophoride"
			description = "A specific chemical based on Potassium Chloride to stop the heart for surgery. Not safe to eat!"
			reagent_state = SOLID
			color = "#FFFFFF" // rgb: 255,255,255
			toxpwr = 2
			overdose = 20

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(ishuman(M))
					var/mob/living/carbon/human/H = M
					if(H.stat != UNCONSCIOUS)
						if(H.losebreath >= 10)
							H.losebreath = max(10, M.losebreath - 10)
						H.adjustOxyLoss(2)
						H.Weaken(10)

		toxin/beer2	//disguised as normal beer for use by emagged brobots
			name = "Beer"
			id = "beer2"
			description = "An alcoholic beverage made from malted grains, hops, yeast, and water. The fermentation appears to be incomplete." //If the players manage to analyze this, they deserve to know something is wrong.
			reagent_state = LIQUID
			color = "#FBBF0D" // rgb: 251, 191, 13
			custom_metabolism = 0.15 // Sleep toxins should always be consumed pretty fast
			overdose = REAGENTS_OVERDOSE * 0.5

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(!data)
					data = 1
				switch(data)
					if(1)
						M.confused += 2
						M.drowsyness += 2
					if(2 to 50)
						M.sleeping += 1
					if(51 to INFINITY)
						M.sleeping += 1
						M.adjustToxLoss((data - 50) * REM)
				data++

		toxin/mutetoxin //the new zombie powder. @ TG Port
			name = "Mute Toxin"
			id = "mutetoxin"
			description = "A toxin that temporarily paralyzes the vocal cords."
			color = "#F0F8FF" // rgb: 240, 248, 255
			custom_metabolism = 0.4
			toxpwr = 0

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.silent = max(M.silent, 3)

		toxin/acid
			name = "Sulphuric acid"
			id = "sacid"
			description = "A very corrosive mineral acid with the molecular formula H2SO4."
			reagent_state = LIQUID
			color = "#DB5008" // rgb: 219, 80, 8
			toxpwr = 1
			var/meltprob = 10

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.take_bodypart_damage(0, 1 * REM)

			reaction_mob(mob/living/M, method=TOUCH, volume)//magic numbers everywhere
				if(!istype(M, /mob/living))
					return
				if(method == TOUCH)
					if(ishuman(M))
						var/mob/living/carbon/human/H = M

						if(H.head)
							if(prob(meltprob) && !H.head.unacidable)
								to_chat(H, "<span class='danger'>Your headgear melts away but protects you from the acid!</span>")
								qdel(H.head)
								H.update_inv_head()
								H.update_hair()
							else
								to_chat(H, "<span class='warning'>Your headgear protects you from the acid.</span>")
							return

						if(H.wear_mask)
							if(prob(meltprob) && !H.wear_mask.unacidable)
								to_chat(H, "<span class='danger'>Your mask melts away but protects you from the acid!</span>")
								qdel(H.wear_mask)
								H.update_inv_wear_mask()
								H.update_hair()
							else
								to_chat(H, "<span class='warning'>Your mask protects you from the acid.</span>")
							return

						if(H.glasses) //Doesn't protect you from the acid but can melt anyways!
							if(prob(meltprob) && !H.glasses.unacidable)
								to_chat(H, "<span class='danger'>Your glasses melts away!</span>")
								qdel(H.glasses)
								H.update_inv_glasses()

					else if(ismonkey(M))
						var/mob/living/carbon/monkey/MK = M
						if(MK.wear_mask)
							if(!MK.wear_mask.unacidable)
								to_chat(MK, "<span class='danger'>Your mask melts away but protects you from the acid!</span>")
								qdel(MK.wear_mask)
								MK.update_inv_wear_mask()
							else
								to_chat(MK, "<span class='warning'>Your mask protects you from the acid.</span>")
							return

					if(!M.unacidable)
						if(istype(M, /mob/living/carbon/human) && volume >= 10)
							var/mob/living/carbon/human/H = M
							var/obj/item/organ/external/BP = H.bodyparts_by_name[BP_HEAD]
							if(BP)
								BP.take_damage(4 * toxpwr, 2 * toxpwr)
								if(prob(meltprob)) //Applies disfigurement
									H.emote("scream",,, 1)
									H.status_flags |= DISFIGURED
						else
							M.take_bodypart_damage(min(6 * toxpwr, volume * toxpwr)) // uses min() and volume to make sure they aren't being sprayed in trace amounts (1 unit != insta rape) -- Doohl
				else
					if(!M.unacidable)
						M.take_bodypart_damage(min(6 * toxpwr, volume * toxpwr))

			reaction_obj(var/obj/O, var/volume)
				if((istype(O,/obj/item) || istype(O,/obj/effect/glowshroom)) && prob(meltprob * 3))
					if(!O.unacidable)
						var/obj/effect/decal/cleanable/molten_item/I = new/obj/effect/decal/cleanable/molten_item(O.loc)
						I.desc = "Looks like this was \an [O] some time ago."
						for(var/mob/M in viewers(5, O))
							to_chat(M, "\red \the [O] melts.")
						qdel(O)

		toxin/acid/polyacid
			name = "Polytrinic acid"
			id = "pacid"
			description = "Polytrinic acid is a an extremely corrosive chemical substance."
			reagent_state = LIQUID
			color = "#8E18A9" // rgb: 142, 24, 169
			toxpwr = 2
			meltprob = 30

/////////////////////////Food Reagents////////////////////////////
// Part of the food code. Nutriment is used instead of the old "heal_amt" code. Also is where all the food
// 	condiments, additives, and such go.
		nutriment
			name = "Nutriment"
			id = "nutriment"
			description = "All the vitamins, minerals, and carbohydrates the body needs in pure form."
			reagent_state = SOLID
			nutriment_factor = 15 * REAGENTS_METABOLISM
			color = "#664330" // rgb: 102, 67, 48

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(prob(50))
					M.heal_bodypart_damage(1, 0)
				M.nutrition += nutriment_factor	// For hunger and fatness
/*
				// If overeaten - vomit and fall down
				// Makes you feel bad but removes reagents and some effect
				// from your body
				if (M.nutrition > 650)
					M.nutrition = rand (250, 400)
					M.weakened += rand(2, 10)
					M.jitteriness += rand(0, 5)
					M.dizziness = max (0, (M.dizziness - rand(0, 15)))
					M.druggy = max (0, (M.druggy - rand(0, 15)))
					M.adjustToxLoss(rand(-15, -5)))
					M.updatehealth()
*/

		lipozine
			name = "Lipozine" // The anti-nutriment.
			id = "lipozine"
			description = "A chemical compound that causes a powerful fat-burning reaction."
			reagent_state = LIQUID
			nutriment_factor = 10 * REAGENTS_METABOLISM
			color = "#BBEDA4" // rgb: 187, 237, 164
			overdose = REAGENTS_OVERDOSE

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.nutrition = max(M.nutrition - nutriment_factor, 0)
				M.overeatduration = 0
				if(M.nutrition < 0)//Prevent from going into negatives.
					M.nutrition = 0

		soysauce
			name = "Soysauce"
			id = "soysauce"
			description = "A salty sauce made from the soy plant."
			reagent_state = LIQUID
			nutriment_factor = 2 * REAGENTS_METABOLISM
			color = "#792300" // rgb: 121, 35, 0

		ketchup
			name = "Ketchup"
			id = "ketchup"
			description = "Ketchup, catsup, whatever. It's tomato paste."
			reagent_state = LIQUID
			nutriment_factor = 5 * REAGENTS_METABOLISM
			color = "#731008" // rgb: 115, 16, 8

		flour
			name = "Flour"
			id = "flour"
			description = "This is what you rub all over yourself to pretend to be a ghost."
			reagent_state = LIQUID
			nutriment_factor = 2 * REAGENTS_METABOLISM
			color = "#F5EAEA" // rgb: 245, 234, 234

		capsaicin
			name = "Capsaicin Oil"
			id = "capsaicin"
			description = "This is what makes chilis hot."
			reagent_state = LIQUID
			color = "#B31008" // rgb: 179, 16, 8
			custom_metabolism = FOOD_METABOLISM

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(!data)
					data = 1
				switch(data)
					if(1 to 15)
						M.bodytemperature += 5 * TEMPERATURE_DAMAGE_COEFFICIENT
						if(holder.has_reagent("frostoil"))
							holder.remove_reagent("frostoil", 5)
						if(istype(M, /mob/living/carbon/slime))
							M.bodytemperature += rand(5,20)
					if(15 to 25)
						M.bodytemperature += 10 * TEMPERATURE_DAMAGE_COEFFICIENT
						if(istype(M, /mob/living/carbon/slime))
							M.bodytemperature += rand(10,20)
					if(25 to INFINITY)
						M.bodytemperature += 15 * TEMPERATURE_DAMAGE_COEFFICIENT
						if(istype(M, /mob/living/carbon/slime))
							M.bodytemperature += rand(15,20)
				data++

		condensedcapsaicin
			name = "Condensed Capsaicin"
			id = "condensedcapsaicin"
			description = "A chemical agent used for self-defense and in police work."
			reagent_state = LIQUID
			color = "#B31008" // rgb: 179, 16, 8

			reaction_mob(mob/living/M, method=TOUCH, volume)
				if(!istype(M, /mob/living))
					return
				if(method == TOUCH)
					if(istype(M, /mob/living/carbon/human))
						var/mob/living/carbon/human/victim = M
						var/mouth_covered = 0
						var/eyes_covered = 0
						var/obj/item/safe_thing = null
						if( victim.wear_mask )
							if ( victim.wear_mask.flags & MASKCOVERSEYES )
								eyes_covered = 1
								safe_thing = victim.wear_mask
							if ( victim.wear_mask.flags & MASKCOVERSMOUTH )
								mouth_covered = 1
								safe_thing = victim.wear_mask
						if( victim.head )
							if ( victim.head.flags & MASKCOVERSEYES )
								eyes_covered = 1
								safe_thing = victim.head
							if ( victim.head.flags & MASKCOVERSMOUTH )
								mouth_covered = 1
								safe_thing = victim.head
						if(victim.glasses)
							eyes_covered = 1
							if ( !safe_thing )
								safe_thing = victim.glasses
						if ( eyes_covered && mouth_covered )
							to_chat(victim, "\red Your [safe_thing] protects you from the pepperspray!")
							return
						else if ( mouth_covered )	// Reduced effects if partially protected
							to_chat(victim, "\red Your [safe_thing] protect you from most of the pepperspray!")
							victim.eye_blurry = max(M.eye_blurry, 15)
							victim.eye_blind = max(M.eye_blind, 5)
							victim.Stun(5)
							victim.Weaken(5)
							//victim.Paralyse(10)
							//victim.drop_item()
							return
						else if ( eyes_covered ) // Eye cover is better than mouth cover
							to_chat(victim, "\red Your [safe_thing] protects your eyes from the pepperspray!")
							victim.emote("scream",,, 1)
							victim.eye_blurry = max(M.eye_blurry, 5)
							return
						else // Oh dear :D
							victim.emote("scream",,, 1)
							to_chat(victim, "\red You're sprayed directly in the eyes with pepperspray!")
							victim.eye_blurry = max(M.eye_blurry, 25)
							victim.eye_blind = max(M.eye_blind, 10)
							victim.Stun(5)
							victim.Weaken(5)
							//victim.Paralyse(10)
							//victim.drop_item()

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(prob(5))
					M.visible_message("<span class='warning'>[M] [pick("dry heaves!","coughs!","splutters!")]</span>")

		frostoil
			name = "Frost Oil"
			id = "frostoil"
			description = "A special oil that noticably chills the body. Extracted from Ice Peppers."
			reagent_state = LIQUID
			color = "#B31008" // rgb: 139, 166, 233
			custom_metabolism = FOOD_METABOLISM

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.bodytemperature = max(M.bodytemperature - 10 * TEMPERATURE_DAMAGE_COEFFICIENT, 0)
				if(prob(1))
					M.emote("shiver")
				if(istype(M, /mob/living/carbon/slime))
					M.bodytemperature = max(M.bodytemperature - rand(10,20), 0)
				holder.remove_reagent("capsaicin", 5)
				holder.remove_reagent(src.id, FOOD_METABOLISM)

			reaction_turf(var/turf/simulated/T, var/volume)
				for(var/mob/living/carbon/slime/M in T)
					M.adjustToxLoss(rand(15,30))

		sodiumchloride
			name = "Table Salt"
			id = "sodiumchloride"
			description = "A salt made of sodium chloride. Commonly used to season food."
			reagent_state = SOLID
			color = "#FFFFFF" // rgb: 255,255,255
			overdose = REAGENTS_OVERDOSE

		blackpepper
			name = "Black Pepper"
			id = "blackpepper"
			description = "A powder ground from peppercorns. *AAAACHOOO*"
			reagent_state = SOLID
			// no color (ie, black)

		coco
			name = "Coco Powder"
			id = "coco"
			description = "A fatty, bitter paste made from coco beans."
			reagent_state = SOLID
			nutriment_factor = 5 * REAGENTS_METABOLISM
			color = "#302000" // rgb: 48, 32, 0

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.nutrition += nutriment_factor

		hot_coco
			name = "Hot Chocolate"
			id = "hot_coco"
			description = "Made with love! And cocoa beans."
			reagent_state = LIQUID
			nutriment_factor = 2 * REAGENTS_METABOLISM
			color = "#403010" // rgb: 64, 48, 16

			on_mob_life(mob/living/M)
				if(!..())
					return
				if (M.bodytemperature < 310)//310 is the normal bodytemp. 310.055
					M.bodytemperature = min(310, M.bodytemperature + (5 * TEMPERATURE_DAMAGE_COEFFICIENT))
				M.nutrition += nutriment_factor

		psilocybin
			name = "Psilocybin"
			id = "psilocybin"
			description = "A strong psycotropic derived from certain species of mushroom."
			color = "#E700E7" // rgb: 231, 0, 231
			overdose = REAGENTS_OVERDOSE
			custom_metabolism = FOOD_METABOLISM * 0.5

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.druggy = max(M.druggy, 30)
				if(!data)
					data = 1
				switch(data)
					if(1 to 5)
						if(!M.stuttering)
							M.stuttering = 1
						M.make_dizzy(5)
						if(prob(10))
							M.emote(pick("twitch","giggle"))
					if(5 to 10)
						if(!M.stuttering)
							M.stuttering = 1
						M.make_jittery(10)
						M.make_dizzy(10)
						M.druggy = max(M.druggy, 35)
						if(prob(20))
							M.emote(pick("twitch","giggle"))
					if(10 to INFINITY)
						if(!M.stuttering)
							M.stuttering = 1
						M.make_jittery(20)
						M.make_dizzy(20)
						M.druggy = max(M.druggy, 40)
						if(prob(30))
							M.emote(pick("twitch","giggle"))
				data++

		sprinkles
			name = "Sprinkles"
			id = "sprinkles"
			description = "Multi-colored little bits of sugar, commonly found on donuts. Loved by cops."
			nutriment_factor = 1 * REAGENTS_METABOLISM
			color = "#FF00FF" // rgb: 255, 0, 255

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.nutrition += nutriment_factor
				/*if(istype(M, /mob/living/carbon/human) && M.job in list("Security Officer", "Head of Security", "Detective", "Warden"))
					if(!M) M = holder.my_atom
					M.heal_bodypart_damage(1, 1)
					M.nutrition += nutriment_factor
					..()
					return
				*/

/*	//removed because of meta bullshit. this is why we can't have nice things.
		syndicream
			name = "Cream filling"
			id = "syndicream"
			description = "Delicious cream filling of a mysterious origin. Tastes criminally good."
			nutriment_factor = 1 * REAGENTS_METABOLISM
			color = "#AB7878" // rgb: 171, 120, 120

			on_mob_life(var/mob/living/M as mob)
				M.nutrition += nutriment_factor
				if(istype(M, /mob/living/carbon/human) && M.mind)
					if(M.mind.special_role)
						if(!M) M = holder.my_atom
						M.heal_bodypart_damage(1, 1)
						M.nutrition += nutriment_factor
						..()
						return
				..()
*/
		cornoil
			name = "Corn Oil"
			id = "cornoil"
			description = "An oil derived from various types of corn."
			reagent_state = LIQUID
			nutriment_factor = 20 * REAGENTS_METABOLISM
			color = "#302000" // rgb: 48, 32, 0

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.nutrition += nutriment_factor

			reaction_turf(var/turf/simulated/T, var/volume)
				if (!istype(T)) return
				src = null
				if(volume >= 3)
					T.make_wet_floor(WATER_FLOOR)
				var/hotspot = (locate(/obj/fire) in T)
				if(hotspot)
					var/datum/gas_mixture/lowertemp = T.remove_air(T:air:total_moles)
					lowertemp.temperature = max( min(lowertemp.temperature-2000,lowertemp.temperature / 2) ,0)
					lowertemp.react()
					T.assume_air(lowertemp)
					qdel(hotspot)

		enzyme
			name = "Universal Enzyme"
			id = "enzyme"
			description = "A universal enzyme used in the preperation of certain chemicals and foods."
			reagent_state = LIQUID
			color = "#365E30" // rgb: 54, 94, 48
			overdose = REAGENTS_OVERDOSE

		dry_ramen
			name = "Dry Ramen"
			id = "dry_ramen"
			description = "Space age food, since August 25, 1958. Contains dried noodles, vegetables, and chemicals that boil in contact with water."
			reagent_state = SOLID
			nutriment_factor = 1 * REAGENTS_METABOLISM
			color = "#302000" // rgb: 48, 32, 0

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.nutrition += nutriment_factor

		hot_ramen
			name = "Hot Ramen"
			id = "hot_ramen"
			description = "The noodles are boiled, the flavors are artificial, just like being back in school."
			reagent_state = LIQUID
			nutriment_factor = 5 * REAGENTS_METABOLISM
			color = "#302000" // rgb: 48, 32, 0

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.nutrition += nutriment_factor
				if (M.bodytemperature < 310)//310 is the normal bodytemp. 310.055
					M.bodytemperature = min(310, M.bodytemperature + (10 * TEMPERATURE_DAMAGE_COEFFICIENT))

		hell_ramen
			name = "Hell Ramen"
			id = "hell_ramen"
			description = "The noodles are boiled, the flavors are artificial, just like being back in school."
			reagent_state = LIQUID
			nutriment_factor = 5 * REAGENTS_METABOLISM
			color = "#302000" // rgb: 48, 32, 0

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.nutrition += nutriment_factor
				M.bodytemperature += 10 * TEMPERATURE_DAMAGE_COEFFICIENT

/* We're back to flour bags
		flour
			name = "flour"
			id = "flour"
			description = "This is what you rub all over yourself to pretend to be a ghost."
			reagent_state = SOLID
			nutriment_factor = 1 * REAGENTS_METABOLISM
			color = "#FFFFFF" // rgb: 0, 0, 0

			on_mob_life(var/mob/living/M as mob)
				M.nutrition += nutriment_factor
				..()
				return

			reaction_turf(var/turf/T, var/volume)
				src = null
				if(!istype(T, /turf/space))
					new /obj/effect/decal/cleanable/flour(T)
*/

		rice
			name = "Rice"
			id = "rice"
			description = "Enjoy the great taste of nothing."
			reagent_state = SOLID
			nutriment_factor = 1 * REAGENTS_METABOLISM
			color = "#FFFFFF" // rgb: 0, 0, 0

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.nutrition += nutriment_factor

		cherryjelly
			name = "Cherry Jelly"
			id = "cherryjelly"
			description = "Totally the best. Only to be spread on foods with excellent lateral symmetry."
			reagent_state = LIQUID
			nutriment_factor = 1 * REAGENTS_METABOLISM
			color = "#801E28" // rgb: 128, 30, 40

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.nutrition += nutriment_factor

/////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////// DRINKS BELOW, Beer is up there though, along with cola. Cap'n Pete's Cuban Spiced Rum////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////

		drink
			name = "Drink"
			id = "drink"
			description = "Uh, some kind of drink."
			reagent_state = LIQUID
			nutriment_factor = 1 * REAGENTS_METABOLISM
			color = "#E78108" // rgb: 231, 129, 8
			custom_metabolism = DRINK_METABOLISM
			var/adj_dizzy = 0
			var/adj_drowsy = 0
			var/adj_sleepy = 0
			var/adj_temp = 0

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.nutrition += nutriment_factor
				if(adj_dizzy)
					M.dizziness = max(0,M.dizziness + adj_dizzy)
				if(adj_drowsy)
					M.drowsyness = max(0,M.drowsyness + adj_drowsy)
				if(adj_sleepy)
					M.sleeping = max(0,M.sleeping + adj_sleepy)
				if(adj_temp)
					if(M.bodytemperature < 310)//310 is the normal bodytemp. 310.055
						M.bodytemperature = min(310, M.bodytemperature + (25 * TEMPERATURE_DAMAGE_COEFFICIENT))
				return TRUE

		drink/orangejuice
			name = "Orange juice"
			id = "orangejuice"
			description = "Both delicious AND rich in Vitamin C, what more do you need?"
			color = "#E78108" // rgb: 231, 129, 8

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(M.getOxyLoss() && prob(30))
					M.adjustOxyLoss(-1)

		drink/tomatojuice
			name = "Tomato Juice"
			id = "tomatojuice"
			description = "Tomatoes made into juice. What a waste of big, juicy tomatoes, huh?"
			color = "#731008" // rgb: 115, 16, 8

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(M.getFireLoss() && prob(20))
					M.heal_bodypart_damage(0, 1)

		drink/limejuice
			name = "Lime Juice"
			id = "limejuice"
			description = "The sweet-sour juice of limes."
			color = "#365E30" // rgb: 54, 94, 48
			on_mob_life(mob/living/M)
				if(!..())
					return
				if(M.getToxLoss() && prob(20))
					M.adjustToxLoss(-1 * REM)

		drink/carrotjuice
			name = "Carrot juice"
			id = "carrotjuice"
			description = "It is just like a carrot but without crunching."
			color = "#973800" // rgb: 151, 56, 0

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.eye_blurry = max(M.eye_blurry - 1, 0)
				M.eye_blind = max(M.eye_blind - 1, 0)
				if(!data)
					data = 1
				switch(data)
					if(1 to 20)
						//nothing
					if(21 to INFINITY)
						if(prob(data - 10))
							M.disabilities &= ~NEARSIGHTED
				data++

		drink/berryjuice
			name = "Berry Juice"
			id = "berryjuice"
			description = "A delicious blend of several different kinds of berries."
			color = "#990066" // rgb: 153, 0, 102

		drink/grapejuice
			name = "Grape Juice"
			id = "grapejuice"
			description = "It's grrrrrape!"
			color = "#863333" // rgb: 134, 51, 51

		drink/grapesoda
			name = "Grape Soda"
			id = "grapesoda"
			description = "Grapes made into a fine drank."
			color = "#421C52" // rgb: 98, 57, 53
			adj_drowsy 	= 	-3

		drink/poisonberryjuice
			name = "Poison Berry Juice"
			id = "poisonberryjuice"
			description = "A tasty juice blended from various kinds of very deadly and toxic berries."
			color = "#863353" // rgb: 134, 51, 83

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.adjustToxLoss(1)

		drink/watermelonjuice
			name = "Watermelon Juice"
			id = "watermelonjuice"
			description = "Delicious juice made from watermelon."
			color = "#863333" // rgb: 134, 51, 51

		drink/lemonjuice
			name = "Lemon Juice"
			id = "lemonjuice"
			description = "This juice is VERY sour."
			color = "#863333" // rgb: 175, 175, 0

		drink/banana
			name = "Banana Juice"
			id = "banana"
			description = "The raw essence of a banana."
			color = "#863333" // rgb: 175, 175, 0

		drink/nothing
			name = "Nothing"
			id = "nothing"
			description = "Absolutely nothing."

		drink/potato_juice
			name = "Potato Juice"
			id = "potato"
			description = "Juice of the potato. Bleh."
			nutriment_factor = 2 * FOOD_METABOLISM
			color = "#302000" // rgb: 48, 32, 0

		drink/milk
			name = "Milk"
			id = "milk"
			description = "An opaque white liquid produced by the mammary glands of mammals."
			color = "#DFDFDF" // rgb: 223, 223, 223

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(M.getBruteLoss() && prob(20))
					M.heal_bodypart_damage(1, 0)
				if(holder.has_reagent("capsaicin"))
					holder.remove_reagent("capsaicin", 10 * REAGENTS_METABOLISM)

		drink/milk/soymilk
			name = "Soy Milk"
			id = "soymilk"
			description = "An opaque white liquid made from soybeans."
			color = "#DFDFC7" // rgb: 223, 223, 199

		drink/milk/cream
			name = "Cream"
			id = "cream"
			description = "The fatty, still liquid part of milk. Why don't you mix this with sum scotch, eh?"
			color = "#DFD7AF" // rgb: 223, 215, 175

		drink/grenadine
			name = "Grenadine Syrup"
			id = "grenadine"
			description = "Made in the modern day with proper pomegranate substitute. Who uses real fruit, anyways?"
			color = "#FF004F" // rgb: 255, 0, 79

		drink/hot_coco
			name = "Hot Chocolate"
			id = "hot_coco"
			description = "Made with love! And cocoa beans."
			nutriment_factor = 2 * FOOD_METABOLISM
			color = "#403010" // rgb: 64, 48, 16
			adj_temp = 5

		drink/coffee
			name = "Coffee"
			id = "coffee"
			description = "Coffee is a brewed drink prepared from roasted seeds, commonly called coffee beans, of the coffee plant."
			color = "#482000" // rgb: 72, 32, 0
			adj_dizzy = -5
			adj_drowsy = -3
			adj_sleepy = -2
			adj_temp = 25

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.make_jittery(5)
				if(adj_temp > 0 && holder.has_reagent("frostoil"))
					holder.remove_reagent("frostoil", 10 * REAGENTS_METABOLISM)
				return TRUE

		drink/coffee/icecoffee
			name = "Iced Coffee"
			id = "icecoffee"
			description = "Coffee and ice, refreshing and cool."
			color = "#102838" // rgb: 16, 40, 56
			adj_temp = -5

		drink/coffee/soy_latte
			name = "Soy Latte"
			id = "soy_latte"
			description = "A nice and tasty beverage while you are reading your hippie books."
			color = "#664300" // rgb: 102, 67, 0
			adj_sleepy = 0
			adj_temp = 5

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.sleeping = 0
				if(M.getBruteLoss() && prob(20))
					M.heal_bodypart_damage(1, 0)

		drink/coffee/cafe_latte
			name = "Cafe Latte"
			id = "cafe_latte"
			description = "A nice, strong and tasty beverage while you are reading."
			color = "#664300" // rgb: 102, 67, 0
			adj_sleepy = 0
			adj_temp = 5

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.sleeping = 0
				if(M.getBruteLoss() && prob(20))
					M.heal_bodypart_damage(1, 0)

		drink/tea
			name = "Tea"
			id = "tea"
			description = "Tasty black tea, it has antioxidants, it's good for you!"
			color = "#101000" // rgb: 16, 16, 0
			adj_dizzy = -2
			adj_drowsy = -1
			adj_sleepy = -3
			adj_temp = 20

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(M.getToxLoss() && prob(20))
					M.adjustToxLoss(-1)

		drink/tea/icetea
			name = "Iced Tea"
			id = "icetea"
			description = "No relation to a certain rap artist/ actor."
			color = "#104038" // rgb: 16, 64, 56
			adj_temp = -5

		drink/cold
			name = "Cold drink"
			adj_temp = -5

		drink/cold/tonic
			name = "Tonic Water"
			id = "tonic"
			description = "It tastes strange but at least the quinine keeps the Space Malaria at bay."
			color = "#664300" // rgb: 102, 67, 0
			adj_dizzy = -5
			adj_drowsy = -3
			adj_sleepy = -2

		drink/cold/sodawater
			name = "Soda Water"
			id = "sodawater"
			description = "A can of club soda. Why not make a scotch and soda?"
			color = "#619494" // rgb: 97, 148, 148
			adj_dizzy = -5
			adj_drowsy = -3

		drink/cold/ice
			name = "Ice"
			id = "ice"
			description = "Frozen water, your dentist wouldn't like you chewing this."
			reagent_state = SOLID
			color = "#619494" // rgb: 97, 148, 148

		drink/cold/space_cola
			name = "Space Cola"
			id = "cola"
			description = "A refreshing beverage."
			reagent_state = LIQUID
			color = "#100800" // rgb: 16, 8, 0
			adj_drowsy 	= 	-3

		drink/cold/nuka_cola
			name = "Nuka Cola"
			id = "nuka_cola"
			description = "Cola, cola never changes."
			color = "#100800" // rgb: 16, 8, 0
			adj_sleepy = -2

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.make_jittery(20)
				M.druggy = max(M.druggy, 30)
				M.dizziness += 5
				M.drowsyness = 0

		drink/cold/spacemountainwind
			name = "Mountain Wind"
			id = "spacemountainwind"
			description = "Blows right through you like a space wind."
			color = "#102000" // rgb: 16, 32, 0
			adj_drowsy = -7
			adj_sleepy = -1

		drink/cold/dr_gibb
			name = "Dr. Gibb"
			id = "dr_gibb"
			description = "A delicious blend of 42 different flavours"
			color = "#102000" // rgb: 16, 32, 0
			adj_drowsy = -6

		drink/cold/space_up
			name = "Space-Up"
			id = "space_up"
			description = "Tastes like a hull breach in your mouth."
			color = "#202800" // rgb: 32, 40, 0
			adj_temp = -8

		drink/cold/lemon_lime
			name = "Lemon Lime"
			description = "A tangy substance made of 0.5% natural citrus!"
			id = "lemon_lime"
			color = "#878F00" // rgb: 135, 40, 0
			adj_temp = -8

		drink/cold/lemonade
			name = "Lemonade"
			description = "Oh the nostalgia..."
			id = "lemonade"
			color = "#FFFF00" // rgb: 255, 255, 0

		drink/cold/kiraspecial
			name = "Kira Special"
			description = "Long live the guy who everyone had mistaken for a girl. Baka!"
			id = "kiraspecial"
			color = "#CCCC99" // rgb: 204, 204, 153

		drink/cold/brownstar
			name = "Brown Star"
			description = "It's not what it sounds like..."
			id = "brownstar"
			color = "#9F3400" // rgb: 159, 052, 000
			adj_temp = - 2

		drink/cold/milkshake
			name = "Milkshake"
			description = "Glorious brainfreezing mixture."
			id = "milkshake"
			color = "#AEE5E4" // rgb" 174, 229, 228
			adj_temp = -9

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(!data)
					data = 1
				switch(data)
					if(1 to 15)
						M.bodytemperature -= 5 * TEMPERATURE_DAMAGE_COEFFICIENT
						if(holder.has_reagent("capsaicin"))
							holder.remove_reagent("capsaicin", 5)
						if(istype(M, /mob/living/carbon/slime))
							M.bodytemperature -= rand(5,20)
					if(15 to 25)
						M.bodytemperature -= 10 * TEMPERATURE_DAMAGE_COEFFICIENT
						if(istype(M, /mob/living/carbon/slime))
							M.bodytemperature -= rand(10,20)
					if(25 to INFINITY)
						M.bodytemperature -= 15 * TEMPERATURE_DAMAGE_COEFFICIENT
						if(prob(1))
							M.emote("shiver")
						if(istype(M, /mob/living/carbon/slime))
							M.bodytemperature -= rand(15,20)
				data++

		drink/cold/rewriter
			name = "Rewriter"
			description = "The secret of the sanctuary of the Libarian..."
			id = "rewriter"
			color = "#485000" // rgb:72, 080, 0

			on_mob_life(var/mob/living/M as mob)
				if(!..())
					return
				M.make_jittery(5)

		doctor_delight
			name = "The Doctor's Delight"
			id = "doctorsdelight"
			description = "A gulp a day keeps the MediBot away. That's probably for the best."
			reagent_state = LIQUID
			color = "#FF8CFF" // rgb: 255, 140, 255
			custom_metabolism = FOOD_METABOLISM
			nutriment_factor = 1 * FOOD_METABOLISM

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.nutrition += nutriment_factor
				if(M.getOxyLoss() && prob(50))
					M.adjustOxyLoss(-2)
				if(M.getBruteLoss() && prob(60))
					M.heal_bodypart_damage(2, 0)
				if(M.getFireLoss() && prob(50))
					M.heal_bodypart_damage(0, 2)
				if(M.getToxLoss() && prob(50))
					M.adjustToxLoss(-2)
				if(M.dizziness !=0)
					M.dizziness = max(0, M.dizziness - 15)
				if(M.confused !=0)
					M.confused = max(0, M.confused - 5)

//////////////////////////////////////////////The ten friggen million reagents that get you drunk//////////////////////////////////////////////

		atomicbomb
			name = "Atomic Bomb"
			id = "atomicbomb"
			description = "Nuclear proliferation never tasted so good."
			reagent_state = LIQUID
			color = "#666300" // rgb: 102, 99, 0

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.druggy = max(M.druggy, 50)
				M.confused = max(M.confused + 2,0)
				M.make_dizzy(10)
				if(!M.stuttering)
					M.stuttering = 1
				M.stuttering += 3
				if(!data)
					data = 1
				data++
				switch(data)
					if(51 to 200)
						M.sleeping += 1
					if(201 to INFINITY)
						M.sleeping += 1
						M.adjustToxLoss(2)

		gargle_blaster
			name = "Pan-Galactic Gargle Blaster"
			id = "gargleblaster"
			description = "Whoah, this stuff looks volatile!"
			reagent_state = LIQUID
			color = "#664300" // rgb: 102, 67, 0

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(!data)
					data = 1
				data++
				M.dizziness += 6
				if(data >= 15 && data < 45)
					if(!M.stuttering)
						M.stuttering = 1
					M.stuttering += 3
				else if(data >= 45 && prob(50) && data < 55)
					M.confused = max(M.confused + 3,0)
				else if(data >=55)
					M.druggy = max(M.druggy, 55)
				else if(data >=200)
					M.adjustToxLoss(2)

		neurotoxin
			name = "Neurotoxin"
			id = "neurotoxin"
			description = "A strong neurotoxin that puts the subject into a death-like state."
			reagent_state = LIQUID
			color = "#2E2E61" // rgb: 46, 46, 97

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.weakened = max(M.weakened, 3)
				if(!data)
					data = 1
				data++
				M.dizziness += 6
				if(data >= 15 && data < 45)
					if (!M.stuttering)
						M.stuttering = 1
					M.stuttering += 3
				else if(data >= 45 && prob(50) && data <55)
					M.confused = max(M.confused + 3,0)
				else if(data >=55)
					M.druggy = max(M.druggy, 55)
				else if(data >=200)
					M.adjustToxLoss(2)

		hippies_delight
			name = "Hippies' Delight"
			id = "hippiesdelight"
			description = "You just don't get it maaaan."
			reagent_state = LIQUID
			color = "#664300" // rgb: 102, 67, 0
			custom_metabolism = FOOD_METABOLISM * 0.5

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.druggy = max(M.druggy, 50)
				if(!data)
					data = 1
				data++
				switch(data)
					if(1 to 5)
						if(!M.stuttering)
							M.stuttering = 1
						M.make_dizzy(10)
						if(prob(10))
							M.emote(pick("twitch","giggle"))
					if(5 to 10)
						if(!M.stuttering)
							M.stuttering = 1
						M.make_jittery(20)
						M.make_dizzy(20)
						M.druggy = max(M.druggy, 45)
						if(prob(20))
							M.emote(pick("twitch","giggle"))
					if(10 to 200)
						if(!M.stuttering)
							M.stuttering = 1
						M.make_jittery(40)
						M.make_dizzy(40)
						M.druggy = max(M.druggy, 60)
						if(prob(30))
							M.emote(pick("twitch","giggle"))
					if(200 to INFINITY)
						if(!M.stuttering)
							M.stuttering = 1
						M.make_jittery(60)
						M.make_dizzy(60)
						M.druggy = max(M.druggy, 75)
						if(prob(40))
							M.emote(pick("twitch","giggle"))
						if(prob(30))
							M.adjustToxLoss(2)

/*boozepwr chart
1-2 = non-toxic alcohol
3 = medium-toxic
4 = the hard stuff
5 = potent mixes
<6 = deadly toxic
*/

		ethanol
			name = "Ethanol" //Parent class for all alcoholic reagents.
			id = "ethanol"
			description = "A well-known alcohol with a variety of applications."
			reagent_state = LIQUID
			nutriment_factor = 0 //So alcohol can fill you up! If they want to.
			color = "#404030" // rgb: 64, 64, 48
			custom_metabolism = DRINK_METABOLISM * 0.4
			var/boozepwr = 5 //higher numbers mean the booze will have an effect faster.
			var/dizzy_adj = 3
			var/adj_drowsy = 0
			var/adj_sleepy = 0
			var/slurr_adj = 3
			var/confused_adj = 2
			var/slur_start = 90			//amount absorbed after which mob starts slurring
			var/confused_start = 150	//amount absorbed after which mob starts confusing directions
			var/blur_start = 300	//amount absorbed after which mob starts getting blurred vision
			var/pass_out = 400	//amount absorbed after which mob starts passing out

			on_mob_life(mob/living/M, alien)
				if(!..())
					return

				M.nutrition += nutriment_factor

				if(adj_drowsy)
					M.drowsyness = max(0,M.drowsyness + adj_drowsy)
				if(adj_sleepy)
					M.sleeping = max(0,M.sleeping + adj_sleepy)

				if(!src.data || (!isnum(src.data) && src.data.len))
					data = 1   //if it doesn't exist we set it.  if it's a list we're going to set it to 1 as well.  This is to
				src.data += boozepwr						//avoid a runtime error associated with drinking blood mixed in drinks (demon's blood).

				var/d = 0

				// make all the beverages work together
				for(var/datum/reagent/ethanol/A in holder.reagent_list)
					if(isnum(A.data))
						d += A.data

				if(alien && alien == IS_SKRELL) //Skrell get very drunk very quickly.
					d *= 5

				M.dizziness += dizzy_adj
				if(d >= slur_start && d < pass_out)
					if(!M.slurring)
						M.slurring = 1
					M.slurring += slurr_adj
				if(d >= confused_start && prob(33))
					if(!M.confused)
						M.confused = 1
					M.confused = max(M.confused + confused_adj, 0)
				if(d >= blur_start)
					M.eye_blurry = max(M.eye_blurry, 10)
					M.drowsyness = max(M.drowsyness, 0)
				if(d >= pass_out)
					M.paralysis = max(M.paralysis, 20)
					M.drowsyness = max(M.drowsyness, 30)
					if(ishuman(M))
						var/mob/living/carbon/human/H = M
						var/obj/item/organ/internal/liver/IO = H.organs_by_name[O_LIVER]
						if(istype(IO))
							IO.take_damage(0.1, 1)
						H.adjustToxLoss(0.1)
				return TRUE

			reaction_obj(var/obj/O, var/volume)
				if(istype(O,/obj/item/weapon/paper))
					var/obj/item/weapon/paper/paperaffected = O
					paperaffected.clearpaper()
					to_chat(usr, "The solution dissolves the ink on the paper.")
				if(istype(O,/obj/item/weapon/book))
					if(istype(O,/obj/item/weapon/book/tome))
						to_chat(usr, "The solution does nothing. Whatever this is, it isn't normal ink.")
						return
					if(volume >= 5)
						var/obj/item/weapon/book/affectedbook = O
						affectedbook.dat = null
						to_chat(usr, "The solution dissolves the ink on the book.")
					else
						to_chat(usr, "It wasn't enough...")
				return
			reaction_mob(mob/living/M, method=TOUCH, volume)//Splashing people with ethanol isn't quite as good as fuel.
				if(!istype(M, /mob/living))
					return
				if(method == TOUCH)
					M.adjust_fire_stacks(volume / 15)
					return


		ethanol/beer
			name = "Beer"
			id = "beer"
			description = "An alcoholic beverage made from malted grains, hops, yeast, and water."
			color = "#FBBF0D" // rgb: 251, 191, 13
			boozepwr = 1
			nutriment_factor = 1 * FOOD_METABOLISM

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.jitteriness = max(M.jitteriness - 3,0)

		ethanol/kahlua
			name = "Kahlua"
			id = "kahlua"
			description = "A widely known, Mexican coffee-flavoured liqueur. In production since 1936!"
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 1.5
			dizzy_adj = -5
			adj_drowsy = -3
			adj_sleepy = -2

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.make_jittery(5)

		ethanol/whiskey
			name = "Whiskey"
			id = "whiskey"
			description = "A superb and well-aged single-malt whiskey. Damn."
			color = "#EE7732" // rgb: 238, 119, 50
			boozepwr = 2
			dizzy_adj = 4

		ethanol/specialwhiskey
			name = "Special Blend Whiskey"
			id = "specialwhiskey"
			description = "Just when you thought regular station whiskey was good... This silky, amber goodness has to come along and ruin everything."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 2
			dizzy_adj = 4
			slur_start = 30		//amount absorbed after which mob starts slurring

		ethanol/thirteenloko
			name = "Thirteen Loko"
			id = "thirteenloko"
			description = "A potent mixture of caffeine and alcohol."
			color = "#102000" // rgb: 16, 32, 0
			boozepwr = 2
			nutriment_factor = 1 * FOOD_METABOLISM

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.drowsyness = max(0, M.drowsyness - 7)
				if(M.bodytemperature > 310)
					M.bodytemperature = max(310, M.bodytemperature - (5 * TEMPERATURE_DAMAGE_COEFFICIENT))
				M.make_jittery(5)

		ethanol/vodka
			name = "Vodka"
			id = "vodka"
			description = "Number one drink AND fueling choice for Russians worldwide."
			color = "#619494" // rgb: 97, 148, 148
			boozepwr = 2

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.radiation = max(M.radiation - 1,0)

		ethanol/bilk
			name = "Bilk"
			id = "bilk"
			description = "This appears to be beer mixed with milk. Disgusting."
			color = "#895C4C" // rgb: 137, 92, 76
			boozepwr = 1
			nutriment_factor = 2 * FOOD_METABOLISM

		ethanol/threemileisland
			name = "Three Mile Island Iced Tea"
			id = "threemileisland"
			description = "Made for a woman, strong enough for a man."
			color = "#666340" // rgb: 102, 99, 64
			boozepwr = 5

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.druggy = max(M.druggy, 50)

		ethanol/gin
			name = "Gin"
			id = "gin"
			description = "It's gin. In space. I say, good sir."
			color = "#CDD1DA" // rgb: 205, 209, 218
			boozepwr = 1
			dizzy_adj = 3

		ethanol/rum
			name = "Rum"
			id = "rum"
			description = "Yohoho and all that."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 1.5

		ethanol/tequilla
			name = "Tequila"
			id = "tequilla"
			description = "A strong and mildly flavoured, mexican produced spirit. Feeling thirsty hombre?"
			color = "#FFFF91" // rgb: 255, 255, 145
			boozepwr = 2

		ethanol/vermouth
			name = "Vermouth"
			id = "vermouth"
			description = "You suddenly feel a craving for a martini..."
			color = "#91FF91" // rgb: 145, 255, 145
			boozepwr = 1.5

		ethanol/wine
			name = "Wine"
			id = "wine"
			description = "An premium alchoholic beverage made from distilled grape juice."
			color = "#7E4043" // rgb: 126, 64, 67
			boozepwr = 1.5
			dizzy_adj = 2
			slur_start = 65			//amount absorbed after which mob starts slurring
			confused_start = 145	//amount absorbed after which mob starts confusing directions

		ethanol/cognac
			name = "Cognac"
			id = "cognac"
			description = "A sweet and strongly alchoholic drink, made after numerous distillations and years of maturing. Classy as fornication."
			color = "#AB3C05" // rgb: 171, 60, 5
			boozepwr = 1.5
			dizzy_adj = 4
			confused_start = 115	//amount absorbed after which mob starts confusing directions

		ethanol/hooch
			name = "Hooch"
			id = "hooch"
			description = "Either someone's failure at cocktail making or attempt in alchohol production. In any case, do you really want to drink that?"
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 2
			dizzy_adj = 6
			slurr_adj = 5
			slur_start = 35			//amount absorbed after which mob starts slurring
			confused_start = 90	//amount absorbed after which mob starts confusing directions

		ethanol/ale
			name = "Ale"
			id = "ale"
			description = "A dark alchoholic beverage made by malted barley and yeast."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 1

		ethanol/absinthe
			name = "Absinthe"
			id = "absinthe"
			description = "Watch out that the Green Fairy doesn't come for you!"
			color = "#33EE00" // rgb: 51, 238, 0
			boozepwr = 4
			dizzy_adj = 5
			slur_start = 15
			confused_start = 30


		ethanol/pwine
			name = "Poison Wine"
			id = "pwine"
			description = "Is this even wine? Toxic! Hallucinogenic! Probably consumed in boatloads by your superiors!"
			color = "#000000" // rgb: 0, 0, 0 SHOCKER
			boozepwr = 1
			dizzy_adj = 1
			slur_start = 1
			confused_start = 1

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.druggy = max(M.druggy, 50)
				if(!data)
					data = 1
				data++
				switch(data)
					if(1 to 25)
						if(!M.stuttering)
							M.stuttering = 1
						M.make_dizzy(1)
						M.hallucination = max(M.hallucination, 3)
						if(prob(1))
							M.emote(pick("twitch","giggle"))
					if(25 to 75)
						if(!M.stuttering)
							M.stuttering = 1
						M.hallucination = max(M.hallucination, 10)
						M.make_jittery(2)
						M.make_dizzy(2)
						M.druggy = max(M.druggy, 45)
						if(prob(5))
							M.emote(pick("twitch","giggle"))
					if(75 to 150)
						if(!M.stuttering)
							M.stuttering = 1
						M.hallucination = max(M.hallucination, 60)
						M.make_jittery(4)
						M.make_dizzy(4)
						M.druggy = max(M.druggy, 60)
						if(prob(10))
							M.emote(pick("twitch","giggle"))
						if(prob(30))
							M.adjustToxLoss(2)
					if(150 to 300)
						if(!M.stuttering)
							M.stuttering = 1
						M.hallucination = max(M.hallucination, 60)
						M.make_jittery(4)
						M.make_dizzy(4)
						M.druggy = max(M.druggy, 60)
						if(prob(10))
							M.emote(pick("twitch","giggle"))
						if(prob(30))
							M.adjustToxLoss(2)
						if(prob(5) && ishuman(M))
							var/mob/living/carbon/human/H = M
							var/obj/item/organ/internal/heart/IO = H.organs_by_name[O_HEART]
							if(istype(IO))
								IO.take_damage(5, 0)
					if(300 to INFINITY)
						if(ishuman(M))
							var/mob/living/carbon/human/H = M
							var/obj/item/organ/internal/heart/IO = H.organs_by_name[O_HEART]
							if(istype(IO))
								IO.take_damage(100, 0)

		ethanol/deadrum
			name = "Deadrum"
			id = "rum"
			description = "Popular with the sailors. Not very popular with everyone else."
			color = "#F09F42" // rgb: 240, 159, 66
			boozepwr = 1

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.dizziness += 5

		ethanol/sake
			name = "Sake"
			id = "sake"
			description = "Anime's favorite drink."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 2


/////////////////////////////////////////////////////////////////cocktail entities//////////////////////////////////////////////


		ethanol/goldschlager
			name = "Goldschlager"
			id = "goldschlager"
			description = "100 proof cinnamon schnapps, made for alcoholic teen girls on spring break."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 3

		ethanol/patron
			name = "Patron"
			id = "patron"
			description = "Tequila with silver in it, a favorite of alcoholic women in the club scene."
			color = "#585840" // rgb: 88, 88, 64
			boozepwr = 1.5

		ethanol/gintonic
			name = "Gin and Tonic"
			id = "gintonic"
			description = "An all time classic, mild cocktail."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 1

		ethanol/cuba_libre
			name = "Cuba Libre"
			id = "cubalibre"
			description = "Rum, mixed with cola. Viva la revolucion."
			color = "#3E1B00" // rgb: 62, 27, 0
			boozepwr = 1.5

		ethanol/whiskey_cola
			name = "Whiskey Cola"
			id = "whiskeycola"
			description = "Whiskey, mixed with cola. Surprisingly refreshing."
			color = "#3E1B00" // rgb: 62, 27, 0
			boozepwr = 2

		ethanol/martini
			name = "Classic Martini"
			id = "martini"
			description = "Vermouth with Gin. Not quite how 007 enjoyed it, but still delicious."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 2

		ethanol/vodkamartini
			name = "Vodka Martini"
			id = "vodkamartini"
			description = "Vodka with Gin. Not quite how 007 enjoyed it, but still delicious."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 4

		ethanol/white_russian
			name = "White Russian"
			id = "whiterussian"
			description = "That's just, like, your opinion, man..."
			color = "#A68340" // rgb: 166, 131, 64
			boozepwr = 3

		ethanol/screwdrivercocktail
			name = "Screwdriver"
			id = "screwdrivercocktail"
			description = "Vodka, mixed with plain ol' orange juice. The result is surprisingly delicious."
			color = "#A68310" // rgb: 166, 131, 16
			boozepwr = 3

		ethanol/booger
			name = "Booger"
			id = "booger"
			description = "Ewww..."
			color = "#8CFF8C" // rgb: 140, 255, 140
			boozepwr = 1.5

		ethanol/bloody_mary
			name = "Bloody Mary"
			id = "bloodymary"
			description = "A strange yet pleasurable mixture made of vodka, tomato and lime juice. Or at least you THINK the red stuff is tomato juice."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 3

		ethanol/brave_bull
			name = "Brave Bull"
			id = "bravebull"
			description = "It's just as effective as Dutch-Courage!."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 3

		ethanol/tequilla_sunrise
			name = "Tequila Sunrise"
			id = "tequillasunrise"
			description = "Tequila and orange juice. Much like a Screwdriver, only Mexican~"
			color = "#FFE48C" // rgb: 255, 228, 140
			boozepwr = 2

		ethanol/toxins_special
			name = "Toxins Special"
			id = "toxinsspecial"
			description = "This thing is ON FIRE! CALL THE DAMN SHUTTLE!"
			reagent_state = LIQUID
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 5

			on_mob_life(mob/living/M)
				if(!..())
					return
				if (M.bodytemperature < 330)
					M.bodytemperature = min(330, M.bodytemperature + (15 * TEMPERATURE_DAMAGE_COEFFICIENT)) //310 is the normal bodytemp. 310.055

		ethanol/beepsky_smash
			name = "Beepsky Smash"
			id = "beepskysmash"
			description = "Deny drinking this and prepare for THE LAW."
			reagent_state = LIQUID
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 4

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.Stun(2)

		ethanol/irish_cream
			name = "Irish Cream"
			id = "irishcream"
			description = "Whiskey-imbued cream, what else would you expect from the Irish."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 2

		ethanol/manly_dorf
			name = "The Manly Dorf"
			id = "manlydorf"
			description = "Beer and Ale, brought together in a delicious mix. Intended for true men only."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 2

		ethanol/longislandicedtea
			name = "Long Island Iced Tea"
			id = "longislandicedtea"
			description = "The liquor cabinet, brought together in a delicious mix. Intended for middle-aged alcoholic women only."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 4

		ethanol/moonshine
			name = "Moonshine"
			id = "moonshine"
			description = "You've really hit rock bottom now... your liver packed its bags and left last night."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 4

		ethanol/b52
			name = "B-52"
			id = "b52"
			description = "Coffee, Irish Cream, and cognac. You will get bombed."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 4

		ethanol/irishcoffee
			name = "Irish Coffee"
			id = "irishcoffee"
			description = "Coffee, and alcohol. More fun than a Mimosa to drink in the morning."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 3

		ethanol/margarita
			name = "Margarita"
			id = "margarita"
			description = "On the rocks with salt on the rim. Arriba~!"
			color = "#8CFF8C" // rgb: 140, 255, 140
			boozepwr = 3

		ethanol/black_russian
			name = "Black Russian"
			id = "blackrussian"
			description = "For the lactose-intolerant. Still as classy as a White Russian."
			color = "#360000" // rgb: 54, 0, 0
			boozepwr = 3

		ethanol/manhattan
			name = "Manhattan"
			id = "manhattan"
			description = "The Detective's undercover drink of choice. He never could stomach gin..."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 3

		ethanol/manhattan_proj
			name = "Manhattan Project"
			id = "manhattan_proj"
			description = "A scientist's drink of choice, for pondering ways to blow up the station."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 5

			on_mob_life(mob/living/M)
				if(!..())
					return
				M.druggy = max(M.druggy, 30)

		ethanol/whiskeysoda
			name = "Whiskey Soda"
			id = "whiskeysoda"
			description = "For the more refined griffon."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 3

		ethanol/antifreeze
			name = "Anti-freeze"
			id = "antifreeze"
			description = "Ultimate refreshment."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 4

			on_mob_life(mob/living/M)
				if(!..())
					return
				if (M.bodytemperature < 330)
					M.bodytemperature = min(330, M.bodytemperature + (20 * TEMPERATURE_DAMAGE_COEFFICIENT)) //310 is the normal bodytemp. 310.055

		ethanol/barefoot
			name = "Barefoot"
			id = "barefoot"
			description = "Barefoot and pregnant"
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 1.5

		ethanol/snowwhite
			name = "Snow White"
			id = "snowwhite"
			description = "A cold refreshment"
			color = "#FFFFFF" // rgb: 255, 255, 255
			boozepwr = 1.5

		ethanol/melonliquor
			name = "Melon Liquor"
			id = "melonliquor"
			description = "A relatively sweet and fruity 46 proof liquor."
			color = "#138808" // rgb: 19, 136, 8
			boozepwr = 1

		ethanol/bluecuracao
			name = "Blue Curacao"
			id = "bluecuracao"
			description = "Exotically blue, fruity drink, distilled from oranges."
			color = "#0000CD" // rgb: 0, 0, 205
			boozepwr = 1.5

		ethanol/suidream
			name = "Sui Dream"
			id = "suidream"
			description = "Comprised of: White soda, blue curacao, melon liquor."
			color = "#00A86B" // rgb: 0, 168, 107
			boozepwr = 0.5

		ethanol/demonsblood
			name = "Demons Blood"
			id = "demonsblood"
			description = "AHHHH!!!!"
			color = "#820000" // rgb: 130, 0, 0
			boozepwr = 3
		ethanol/vodkatonic
			name = "Vodka and Tonic"
			id = "vodkatonic"
			description = "For when a gin and tonic isn't russian enough."
			color = "#0064C8" // rgb: 0, 100, 200
			boozepwr = 3
			dizzy_adj = 4
			slurr_adj = 3

		ethanol/ginfizz
			name = "Gin Fizz"
			id = "ginfizz"
			description = "Refreshingly lemony, deliciously dry."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 1.5
			dizzy_adj = 4
			slurr_adj = 3

		ethanol/bahama_mama
			name = "Bahama mama"
			id = "bahama_mama"
			description = "Tropical cocktail."
			color = "#FF7F3B" // rgb: 255, 127, 59
			boozepwr = 2

		ethanol/singulo
			name = "Singulo"
			id = "singulo"
			description = "A blue-space beverage!"
			color = "#2E6671" // rgb: 46, 102, 113
			boozepwr = 5
			dizzy_adj = 15
			slurr_adj = 15

		ethanol/sbiten
			name = "Sbiten"
			id = "sbiten"
			description = "A spicy Vodka! Might be a little hot for the little guys!"
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 3

			on_mob_life(mob/living/M)
				if(!..())
					return
				if (M.bodytemperature < 360)
					M.bodytemperature = min(360, M.bodytemperature + (50 * TEMPERATURE_DAMAGE_COEFFICIENT)) //310 is the normal bodytemp. 310.055

		ethanol/devilskiss
			name = "Devils Kiss"
			id = "devilskiss"
			description = "Creepy time!"
			color = "#A68310" // rgb: 166, 131, 16
			boozepwr = 3

		ethanol/red_mead
			name = "Red Mead"
			id = "red_mead"
			description = "The true Viking's drink! Even though it has a strange red color."
			color = "#C73C00" // rgb: 199, 60, 0
			boozepwr = 1.5

		ethanol/mead
			name = "Mead"
			id = "mead"
			description = "A Viking's drink, though a cheap one."
			reagent_state = LIQUID
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 1.5
			nutriment_factor = 1 * FOOD_METABOLISM

		ethanol/iced_beer
			name = "Iced Beer"
			id = "iced_beer"
			description = "A beer which is so cold the air around it freezes."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 1

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(M.bodytemperature > 270)
					M.bodytemperature = max(270, M.bodytemperature - (20 * TEMPERATURE_DAMAGE_COEFFICIENT)) //310 is the normal bodytemp. 310.055

		ethanol/grog
			name = "Grog"
			id = "grog"
			description = "Watered down rum, NanoTrasen approves!"
			reagent_state = LIQUID
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 0.5

		ethanol/aloe
			name = "Aloe"
			id = "aloe"
			description = "So very, very, very good."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 3

		ethanol/andalusia
			name = "Andalusia"
			id = "andalusia"
			description = "A nice, strangely named drink."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 3

		ethanol/alliescocktail
			name = "Allies Cocktail"
			id = "alliescocktail"
			description = "A drink made from your allies, not as sweet as when made from your enemies."
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 2

		ethanol/acid_spit
			name = "Acid Spit"
			id = "acidspit"
			description = "A drink for the daring, can be deadly if incorrectly prepared!"
			reagent_state = LIQUID
			color = "#365000" // rgb: 54, 80, 0
			boozepwr = 1.5

		ethanol/amasec
			name = "Amasec"
			id = "amasec"
			description = "Official drink of the NanoTrasen Gun-Club!"
			reagent_state = LIQUID
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 2

		ethanol/changelingsting
			name = "Changeling Sting"
			id = "changelingsting"
			description = "You take a tiny sip and feel a burning sensation..."
			color = "#2E6671" // rgb: 46, 102, 113
			boozepwr = 5

		ethanol/irishcarbomb
			name = "Irish Car Bomb"
			id = "irishcarbomb"
			description = "Mmm, tastes like chocolate cake..."
			color = "#2E6671" // rgb: 46, 102, 113
			boozepwr = 3
			dizzy_adj = 5

		ethanol/syndicatebomb
			name = "Syndicate Bomb"
			id = "syndicatebomb"
			description = "Tastes like terrorism!"
			color = "#2E6671" // rgb: 46, 102, 113
			boozepwr = 5

		ethanol/erikasurprise
			name = "Erika Surprise"
			id = "erikasurprise"
			description = "The surprise is it's green!"
			color = "#2E6671" // rgb: 46, 102, 113
			boozepwr = 3

		ethanol/driestmartini
			name = "Driest Martini"
			id = "driestmartini"
			description = "Only for the experienced. You think you see sand floating in the glass."
			nutriment_factor = 1 * FOOD_METABOLISM
			color = "#2E6671" // rgb: 46, 102, 113
			boozepwr = 4

		ethanol/bananahonk
			name = "Banana Mama"
			id = "bananahonk"
			description = "A drink from Clown Heaven."
			nutriment_factor = 1 * REAGENTS_METABOLISM
			color = "#FFFF91" // rgb: 255, 255, 140
			boozepwr = 4

		ethanol/silencer
			name = "Silencer"
			id = "silencer"
			description = "A drink from Mime Heaven."
			nutriment_factor = 1 * FOOD_METABOLISM
			color = "#664300" // rgb: 102, 67, 0
			boozepwr = 4

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(!data)
					data = 1
				data++
				M.dizziness += 10
				if(data >= 55 && data < 115)
					if(!M.stuttering)
						M.stuttering = 1
					M.stuttering += 10
				else if(data >= 115 && prob(33))
					M.confused = max(M.confused + 15, 15)

/////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////// Chemlights ///////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////

		luminophore_temp //Temporary holder of vars used in mixing colors
			name = "Luminophore"
			id = "luminophore"
			description = "Uh, some kind of drink."
			reagent_state = LIQUID
			nutriment_factor = 0.2
			color = "#ffffff"
			custom_metabolism = 0.2

		luminophore
			name = "Luminophore"
			id = "luminophore"
			description = "Uh, some kind of drink."
			reagent_state = LIQUID
			color = "#ffffff"
			custom_metabolism = 0.2

			on_mob_life(mob/living/M)
				if(!..())
					return
				if(ishuman(M))
					var/mob/living/carbon/human/H = M
					H.vomit()
					H.apply_effect(1,IRRADIATE,0)

/////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////// Nanobots /////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/reagent/nanites2
	name = "Friendly Nanites"
	id = "nanites2"
	description = "Friendly microscopic construction robots."
	reagent_state = LIQUID
	color = "#535E66" //rgb: 83, 94, 102

/datum/reagent/nanobots
	name = "Nanobots"
	id = "nanobots"
	description = "Microscopic robots intended for use in humans. Must be loaded with further chemicals to be useful."
	reagent_state = LIQUID
	color = "#3E3959" //rgb: 62, 57, 89

//Great healing powers. Metabolizes extremely slowly, but gets used up when it heals damage.
//Dangerous in amounts over 5 units, healing that occurs while over 5 units adds to a counter. That counter affects gib chance. Guaranteed gib over 20 units.
/datum/reagent/mednanobots
	name = "Medical Nanobots"
	id = "mednanobots"
	description = "Microscopic robots intended for use in humans. Configured for rapid healing upon infiltration into the body."
	reagent_state = LIQUID
	color = "#593948" //rgb: 89, 57, 72
	custom_metabolism = 0.005
	var/spawning_horror = 0
	var/percent_machine = 0

/datum/reagent/mednanobots/on_mob_life(mob/living/M)
	if(!..())
		return
	if(ishuman(M))
		var/mob/living/carbon/human/H = M
		if(H.species.name != "Dionae")
			switch(volume)
				if(1 to 5)
					var/obj/item/organ/external/BP = H.bodyparts_by_name[BP_CHEST] // it was H.get_bodypart(????) with nothing as arg, so its always a chest?
					for(var/datum/wound/W in BP.wounds)
						BP.wounds -= W
						H.visible_message("<span class='warning'>[H]'s wounds close up in the blink of an eye!</span>")
					if(H.getOxyLoss() > 0 && prob(90))
						if(holder.has_reagent("mednanobots"))
							H.adjustOxyLoss(-4)
							holder.remove_reagent("mednanobots", 0.1)  //The number/40 means that every time it heals, it uses up number/40ths of a unit, meaning each unit heals 40 damage

					if(H.getBruteLoss() > 0 && prob(90))
						if(holder.has_reagent("mednanobots"))
							H.heal_bodypart_damage(5, 0)
							holder.remove_reagent("mednanobots", 0.125)

					if(H.getFireLoss() > 0 && prob(90))
						if(holder.has_reagent("mednanobots"))
							H.heal_bodypart_damage(0, 5)
							holder.remove_reagent("mednanobots", 0.125)

					if(H.getToxLoss() > 0 && prob(50))
						if(holder.has_reagent("mednanobots"))
							H.adjustToxLoss(-2)
							holder.remove_reagent("mednanobots", 0.05)

					if(H.getCloneLoss() > 0 && prob(60))
						if(holder.has_reagent("mednanobots"))
							H.adjustCloneLoss(-2)
							holder.remove_reagent("mednanobots", 0.05)

					if(percent_machine > 5)
						if(holder.has_reagent("mednanobots"))
							percent_machine -= 1
							if(prob(20))
								to_chat(M, pick("You feel more like yourself again."))
					if(H.dizziness != 0)
						H.dizziness = max(0, H.dizziness - 15)
					if(H.confused != 0)
						H.confused = max(0, H.confused - 5)
					for(var/datum/disease/D in M.viruses)
						D.spread = "Remissive"
						D.stage--
						if(D.stage < 1)
							D.cure()
				if(5 to 20)		//Danger zone healing. Adds to a human mob's "percent machine" var, which is directly translated into the chance that it will turn horror each tick that the reagent is above 5u.
					var/obj/item/organ/external/BP = H.bodyparts_by_name[BP_CHEST]
					for(var/datum/wound/W in BP.wounds)
						BP.wounds -= W
						H.visible_message("<span class='warning'>[H]'s wounds close up in the blink of an eye!</span>")
					if(H.getOxyLoss() > 0 && prob(90))
						if(holder.has_reagent("mednanobots"))
							H.adjustOxyLoss(-4)
							holder.remove_reagent("mednanobots", 0.1)  //The number/40 means that every time it heals, it uses up number/40ths of a unit, meaning each unit heals 40 damage
							percent_machine += 0.5
							if(prob(20))
								to_chat(M, pick("<span class='warning'>Something shifts inside you...</span>", "<span class='warning'>You feel different, somehow...</span>"))

					if(H.getBruteLoss() > 0 && prob(90))
						if(holder.has_reagent("mednanobots"))
							H.heal_bodypart_damage(5, 0)
							holder.remove_reagent("mednanobots", 0.125)
							percent_machine += 0.5
							if(prob(20))
								to_chat(M, pick("<span class='warning'> Something shifts inside you...</span>", "<span class='warning'>You feel different, somehow...</span>"))

					if(H.getFireLoss() > 0 && prob(90))
						if(holder.has_reagent("mednanobots"))
							H.heal_bodypart_damage(0, 5)
							holder.remove_reagent("mednanobots", 0.125)
							percent_machine += 0.5
							if(prob(20))
								to_chat(M, pick("<span class='warning'>Something shifts inside you...</span>", "<span class='warning'>You feel different, somehow...</span>"))

					if(H.getToxLoss() > 0 && prob(50))
						if(holder.has_reagent("mednanobots"))
							H.adjustToxLoss(-2)
							holder.remove_reagent("mednanobots", 0.05)
							percent_machine += 0.5
							if(prob(20))
								to_chat(M, pick("<span class='warning'>Something shifts inside you...</span>", "<span class='warning'>You feel different, somehow...</span>"))

					if(H.getCloneLoss() > 0 && prob(60))
						if(holder.has_reagent("mednanobots"))
							H.adjustCloneLoss(-2)
							holder.remove_reagent("mednanobots", 0.05)
							percent_machine += 0.5
							if(prob(20))
								to_chat(M, pick("<span class='warning'>Something shifts inside you...</span>", "<span class='warning'>You feel different, somehow...</span>"))

					if(H.dizziness != 0)
						H.dizziness = max(0, H.dizziness - 15)
					if(H.confused != 0)
						H.confused = max(0, H.confused - 5)
					for(var/datum/disease/D in M.viruses)
						D.spread = "Remissive"
						D.stage--
						if(D.stage < 1)
							D.cure()
					if(prob(percent_machine))
						holder.add_reagent("mednanobots", 20)
						to_chat(M, pick("<b><span class='warning'>Your body lurches!</b></span>"))
				if(20 to INFINITY)
					spawning_horror = 1
					to_chat(M, pick("<b><span class='warning'>Something doesn't feel right...</span></b>", "<b><span class='warning'>Something is growing inside you!</span></b>", "<b><span class='warning'>You feel your insides rearrange!</span></b>"))
					spawn(60)
						if(spawning_horror)
							to_chat(M, pick( "<b><span class='warning'>Something bursts out from inside you!</span></b>"))
							message_admins("[key_name(H)] has gibbed and spawned a new cyber horror due to nanobots. (<A HREF='?_src_=holder;adminmoreinfo=\ref[H]'>?</A>)")
							log_game("[key_name(H)] has gibbed and spawned a new cyber horror due to nanobots")
							new /mob/living/simple_animal/hostile/cyber_horror(H.loc)
							spawning_horror = 0
							H.gib()
	else
		holder.del_reagent("mednanobots")

//////////////////////////////////////////////
//////////////New poisons/////////////////////
//////////////////////////////////////////////

/datum/reagent/alphaamanitin
	name = "Alpha-amanitin"
	id = "alphaamanitin"
	description = "Deadly rapidly degrading toxin derived from certain species of mushrooms."
	color = "#792300" //rgb: 121, 35, 0
	custom_metabolism = 0.5

/datum/reagent/alphaamanitin/on_mob_life(mob/living/M, alien)
	if(!..() || (alien && alien == IS_DIONA))
		return

	M.adjustToxLoss(6)
	M.adjustOxyLoss(2)
	M.adjustBrainLoss(2)

/datum/reagent/aflatoxin
	name = "Aflatoxin"
	id = "aflatoxin"
	description = "Deadly toxin delayed action. Causes general poisoning and damage the structure of DNA."
	reagent_state = LIQUID
	color = "#792300" //rgb: 59, 8, 5
	custom_metabolism = 0.05

/datum/reagent/aflatoxin/on_mob_life(mob/living/M, alien)
	if(!..() || (alien && alien == IS_DIONA))
		return

	if(!data)
		data = 1

	if(data >= 165)
		M.adjustToxLoss(4)
		M.apply_effect(5*REM,IRRADIATE,0)
	data++

/datum/reagent/chefspecial	//From VG. Only for traitors
	name = "Chef's Special"
	id = "chefspecial"
	description = "An extremely toxic chemical that will surely end in death."
	reagent_state = LIQUID
	color = "#792300" //rgb: 207, 54, 0
	custom_metabolism = 0.01
	data = 1 //Used as a tally

/datum/reagent/chefspecial/on_mob_life(mob/living/M, alien)
	if(!..() || (alien && alien == IS_DIONA))
		return

	if(!data)
		data = 1

	if(data >= 165)
		M.death(0)
		M.attack_log += "\[[time_stamp()]\]<font color='red'>Died a quick and painless death by <font color='green'>Chef Excellence's Special Sauce</font>.</font>"
	data++

/datum/reagent/dioxin
	name = "Dioxin"
	id = "dioxin"
	description = "A powerful poison with a cumulative effect."
	reagent_state = LIQUID
	color = "#792300" //rgb: 207, 54, 0
	custom_metabolism = 0 //No metabolism

/datum/reagent/dioxin/on_mob_life(mob/living/M, alien)
	if(!..() || (alien && alien == IS_DIONA))
		return

	if(!data)
		data = 1

	if(data >= 130)
		M.make_jittery(2)
		M.make_dizzy(2)
		switch (volume)
			if(10 to 20)
				if(prob(5))
					M.emote(pick("twitch","giggle"))
				if(data >=180)
					M.adjustToxLoss(1)
			if(20 to 30)
				if(prob(10))
					M.emote(pick("twitch","giggle"))
				M.adjustToxLoss(3)
				M.adjustBrainLoss(2)
			if(30 to INFINITY)
				if(prob(20))
					M.emote(pick("twitch","giggle"))
				M.adjustToxLoss(3)
				M.adjustBrainLoss(2)
				if(ishuman(M) && prob(5))
					var/mob/living/carbon/human/H = M
					var/obj/item/organ/internal/heart/IO = H.organs_by_name[O_HEART]
					if(istype(IO))
						IO.take_damage(10, 0)
	data++

/datum/reagent/Destroy() // This should only be called by the holder, so it's already handled clearing its references
	. = ..()
	holder = null


/datum/reagent/mulligan
	name = "Mulligan Toxin"
	id = "mulligan"
	description = "This toxin will rapidly change the DNA of human beings. Commonly used by Syndicate spies and assassins in need of an emergency ID change."
	reagent_state = LIQUID
	color = "#5EFF3B" //RGB: 94, 255, 59
	custom_metabolism = 1000

/datum/reagent/mulligan/on_mob_life(mob/living/carbon/human/H)
	if(!..())
		return
	to_chat(H,"<span class='warning'><b>You grit your teeth in pain as your body rapidly mutates!</b></span>")
	H.visible_message("<b>[H]</b> suddenly transforms!")
	H.gender = pick(MALE, FEMALE)
	if(H.gender == MALE)
		H.name = pick(first_names_male)
	else
		H.name = pick(first_names_female)
	H.name += " [pick(last_names)]"
	H.real_name = H.name
	var/datum/preferences/A = new()	//Randomize appearance for the human
	A.randomize_appearance_for(H)

/proc/pretty_string_from_reagent_list(list/reagent_list)
	//Convert reagent list to a printable string for logging etc
	var/result = "| "
	for (var/datum/reagent/R in reagent_list)
		result += "[R.name], [R.volume] | "

	return result

// Undefine the alias for REAGENTS_EFFECT_MULTIPLER
#undef REM
