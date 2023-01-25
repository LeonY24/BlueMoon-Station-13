/// Attempts to open the tgui menu
/mob/living/verb/genital_menu()
	set name = "Genitals Menu"
	set desc = "Manage your genital, or someone else's."
	set category = "IC"
	set src in view(usr.client)

	if(!iscarbon(usr))
		return
	if(!usr.mind) //Mindless boys, honestly just don't, it's better this way
		return
	if(!usr.mind.genitals_menu_holder)
		usr.mind.genitals_menu_holder= new(usr.mind)

	usr.mind.genitals_menu_holder.target = src
	usr.mind.genitals_menu_holder.ui_interact(usr)

/datum/mind
	var/datum/genitals_menu/genitals_menu_holder

/datum/mind/New(key)
	. = ..()
	genitals_menu_holder = new(src)

/datum/genitals_menu
	var/mob/living/carbon/target

/datum/genitals_menu/ui_state(mob/user)
	return GLOB.conscious_state

/datum/genitals_menu/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "GenitalConfig", "Genitals")
		ui.open()


/datum/genitals_menu/ui_data(mob/user)
	. = ..()
	var/mob/living/carbon/genital_holder = target || user
	var/user_is_target = genital_holder == user
	.["istargetself"] = user_is_target
	var/list/genitals = list()
	for(var/obj/item/organ/genital/genital in genital_holder.internal_organs)	//Only get the genitals
		if(CHECK_BITFIELD(genital.genital_flags, GENITAL_INTERNAL))			//Not those though
			continue

		var/list/genital_entry = list()
		genital_entry["name"] = "[capitalize(genital.name)]" //Prevents code from adding a prefix
		genital_entry["key"] = REF(genital) //The key is the reference to the object

		genital_entry["description"] = genital.desc + "\n [genital.linked_organ ? "Linked organ: [genital.linked_organ.name]" : ""]"

		if(user_is_target)
			var/visibility = "Invalid"
			if(CHECK_BITFIELD(genital.genital_flags, GENITAL_THROUGH_CLOTHES))
				visibility = "Always visible"
			else if(CHECK_BITFIELD(genital.genital_flags, GENITAL_UNDIES_HIDDEN))
				visibility = "Hidden by underwear"
			else if(CHECK_BITFIELD(genital.genital_flags, GENITAL_HIDDEN))
				visibility = "Always hidden"
			else
				visibility = "Hidden by clothes"

			var/extras = "None"
			if(CHECK_BITFIELD(genital.genital_flags, GENITAL_CAN_STUFF))
				extras = "Allows egg stuffing"

			genital_entry["extras"] = extras
			genital_entry["visibility"] = visibility
			genital_entry["possible_choices"] = GLOB.genitals_visibility_toggles
			genital_entry["extra_choices"] = list(GEN_ALLOW_EGG_STUFFING)
			genital_entry["can_arouse"] = (
				!!CHECK_BITFIELD(genital.genital_flags, GENITAL_CAN_AROUSE) \
				&& !(HAS_TRAIT(genital_holder, TRAIT_PERMABONER) \
				|| HAS_TRAIT(genital_holder, TRAIT_NEVERBONER)))
			genital_entry["arousal_state"] = genital.aroused_state
			if(istype(genital, /obj/item/organ/genital/penis))
				var/obj/item/organ/genital/penis/peepee = genital
				genital_entry["max_size"] = peepee.max_length
			else
				genital_entry["max_size"] = genital.max_size

		//fluids
		if(CHECK_BITFIELD(genital.genital_flags, GENITAL_FUID_PRODUCTION))
			var/fluids = (clamp(genital.fluid_rate * ((world.time - genital.last_orgasmed) / (10 SECONDS)) * genital.fluid_mult, 0, genital.fluid_max_volume) / genital.fluid_max_volume)
			genital_entry["fluid"] = fluids

		//equipments
		if(genital.is_exposed())
			var/list/equipments = list()
			for(var/obj/equipment in genital.contents)
				var/list/equipment_entry = list()
				equipment_entry["name"] = equipment.name
				equipment_entry["key"] = REF(equipment)
				equipments += list(equipment_entry)
			genital_entry["possible_equipment_choices"] = GLOB.genitals_interactions
			genital_entry["equipments"] = equipments

		genitals += list(genital_entry)

	if(!genital_holder.getorganslot(ORGAN_SLOT_ANUS) && user_is_target)
		var/simulated_ass = list()
		simulated_ass["name"] = "Anus"
		simulated_ass["key"] = "anus"
		var/visibility = "Invalid"
		switch(genital_holder.anus_exposed)
			if(1)
				visibility = "Always visible"
			if(0)
				visibility = "Hidden by underwear"
			else
				visibility = "Always hidden"
		simulated_ass["visibility"] = visibility
		simulated_ass["possible_choices"] = GLOB.genitals_visibility_toggles - GEN_VISIBLE_NO_CLOTHES
		genitals += list(simulated_ass)
	.["genitals"] = genitals

/datum/genitals_menu/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return
	switch(action)
		if("genital")
			var/mob/living/carbon/self = usr
			if(self != target)
				return FALSE
			if("visibility" in params)
				if(params["genital"] == "anus")
					self.anus_toggle_visibility(params["visibility"])
					return TRUE
				var/obj/item/organ/genital/genital = locate(params["genital"], self.internal_organs)
				if(genital && (genital in self.internal_organs))
					genital.toggle_visibility(params["visibility"])
					return TRUE
			if("set_arousal" in params)
				var/obj/item/organ/genital/genital = locate(params["genital"], self.internal_organs)
				if(!genital || (genital \
					&& (!CHECK_BITFIELD(genital.genital_flags, GENITAL_CAN_AROUSE) \
					|| HAS_TRAIT(self, TRAIT_PERMABONER) \
					|| HAS_TRAIT(self, TRAIT_NEVERBONER))))
					return FALSE
				var/original_state = genital.aroused_state
				genital.set_aroused_state(params["set_arousal"])// i'm not making it just `!aroused_state` because
				if(original_state != genital.aroused_state)		// someone just might port skyrat's new genitals
					to_chat(self, "<span class='userlove'>[genital.aroused_state ? genital.arousal_verb : genital.unarousal_verb].</span>")
					. = TRUE
				else
					to_chat(self, "<span class='userlove'>You can't make that genital [genital.aroused_state ? "unaroused" : "aroused"]!</span>")
					. = FALSE
				genital.update_appearance()
				if(ishuman(self))
					var/mob/living/carbon/human/human = self
					human.update_genitals()
				return
			if("max_size" in params)
				var/obj/item/organ/genital/genital = locate(params["genital"], self.internal_organs)
				if(!genital)
					return FALSE
				var/new_max_size = params["max_size"]
				if(istype(genital, /obj/item/organ/genital/penis))
					var/obj/item/organ/genital/penis/peepee = genital
					peepee.max_length = new_max_size
				else
					genital.max_size = new_max_size
				genital.modify_size(0)
			else
				return FALSE
		if("equipment")
			var/mob/living/carbon/actual_target = target || usr
			var/mob/living/carbon/self = usr
			if(get_dist(actual_target, self) > 1)
				to_chat(self, span_warning("You're too far away!"))
				return FALSE
			var/obj/item/organ/genital/genital = locate(params["genital"], actual_target.internal_organs)
			if(!(genital && (genital in actual_target.internal_organs)))
				return FALSE
			switch(params["equipment_action"])
				if("remove")
					var/obj/item/selected_item = locate(params["equipment"], genital.contents)
					if(selected_item)
						if(!do_mob(self, actual_target, 5 SECONDS))
							return FALSE
						if(!self.put_in_hands(selected_item))
							self.transferItemToLoc(get_turf(self))
						return TRUE
					return FALSE
				if("insert")
					var/obj/item/stuff = self.get_active_held_item()
					if(!istype(stuff))
						to_chat(self, span_warning("You need to hold an item to insert it!"))
						return FALSE
					stuff.insert_item_organ(self, self, genital)



