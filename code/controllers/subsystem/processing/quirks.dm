//Used to process and handle roundstart quirks
// - Quirk strings are used for faster checking in code
// - Quirk datums are stored and hold different effects, as well as being a vector for applying trait string
PROCESSING_SUBSYSTEM_DEF(quirks)
	name = "Quirks"
	init_order = INIT_ORDER_QUIRKS
	flags = SS_BACKGROUND
	wait = 10
	runlevels = RUNLEVEL_GAME

	var/list/quirks = list()		//Assoc. list of all roundstart quirk datum types; "name" = /path/
	var/list/quirk_names_by_path = list()
	var/list/quirk_categories = list()	//Hyper edit: Quirks are sorted by different categories
	var/list/quirks_sorted = list()		//Hyper edit: Sort quirks by category then cost
	var/list/quirk_points = list()	//Assoc. list of quirk names and their "point cost"; positive numbers are good traits, and negative ones are bad
	var/list/quirk_objects = list()	//A list of all quirk objects in the game, since some may process
	var/list/quirk_blacklist = list() //A list a list of quirks that can not be used with each other. Format: list(quirk1,quirk2),list(quirk3,quirk4)

/datum/controller/subsystem/processing/quirks/Initialize(timeofday)
	if(!quirks.len)
		SetupQuirks()
		quirk_blacklist = list(
			list("Blind","Nearsighted"),
			list("Jolly","Depression","Hypersensitive"),
			list("Ageusia","Vegetarian","Deviant Tastes"),
			list("Ananas Affinity","Ananas Aversion"),
			list("Alcohol Tolerance","Light Drinker"),
			list("Social Anxiety","Mute"),
			list("Prosthetic Limb (Left Arm)","Prosthetic Limb (Right Arm)","Prosthetic Limb (Left Leg)","Prosthetic Limb (Right Leg)","Prosthetic Limb")
			)
	return ..()

/datum/controller/subsystem/processing/quirks/proc/SetupQuirks()
// Sort by Positive, Negative, Neutral; and then by name
	var/list/quirk_list = sortList(subtypesof(/datum/quirk), /proc/cmp_quirk_asc)

	for(var/V in quirk_list)
		var/datum/quirk/T = V
		quirks[initial(T.name)] = T
		quirk_points[initial(T.name)] = initial(T.value)
		quirk_names_by_path[T] = initial(T.name)
		if(initial(T.category))	//Hyperstation Edit: Categorized quirks
			quirk_categories[initial(T.category)] = 1
	SortQuirks()

/datum/controller/subsystem/processing/quirks/proc/SortQuirks()	//Hyperstation edit: Categorized quirks
	quirks_sorted = list()
	quirk_categories = sortList(quirk_categories)
	for(var/C in quirk_categories)
		quirks_sorted[C] = list()
		for(var/V in quirks)	//These are already sorted by name and cost
			var/datum/quirk/Q = quirks[V]
			if(initial(Q.category) == C)
				quirks_sorted[C] += initial(Q.name)

/datum/controller/subsystem/processing/quirks/proc/AssignQuirks(mob/living/user, client/cli, spawn_effects, roundstart = FALSE, datum/job/job, silent = FALSE, mob/to_chat_target)
	var/badquirk = FALSE
	var/list/my_quirks = cli.prefs.all_quirks.Copy()
	var/list/cut
	if(job?.blacklisted_quirks)
		cut = filter_quirks(my_quirks, job)
	for(var/V in my_quirks)
		if(V in quirks)
			var/datum/quirk/Q = quirks[V]
			user.add_quirk(Q, spawn_effects)
		else
			log_admin("Invalid quirk \"[V]\" in client [cli.ckey] preferences")
			cli.prefs.all_quirks -= V
			badquirk = TRUE
	if(badquirk)
		cli.prefs.save_character()
	if(!silent && LAZYLEN(cut))
		to_chat(to_chat_target || user, "<span class='boldwarning'>All of your non-neutral character quirks have been cut due to these quirks conflicting with your job assignment: [english_list(cut)].</span>")

/datum/controller/subsystem/processing/quirks/proc/quirk_path_by_name(name)
	return quirks[name]

/datum/controller/subsystem/processing/quirks/proc/quirk_points_by_name(name)
	return quirk_points[name]

/datum/controller/subsystem/processing/quirks/proc/quirk_name_by_path(path)
	return quirk_names_by_path[path]

/datum/controller/subsystem/processing/quirks/proc/total_points(list/quirk_names)
	. = 0
	for(var/i in quirk_names)
		. += quirk_points_by_name(i)

/datum/controller/subsystem/processing/quirks/proc/filter_quirks(list/our_quirks, datum/job/job)
	var/list/cut = list()
	var/list/banned_names = list()
	for(var/i in job.blacklisted_quirks)
		var/name = quirk_name_by_path(i)
		if(name)
			banned_names += name
	var/list/blacklisted = our_quirks & banned_names
	if(length(blacklisted))
		for(var/i in blacklisted)
			our_quirks -= i
			cut += i

	/*	//Code to automatically reduce positive quirks until balance is even.
	var/points_used = total_points(our_quirks)
	if(points_used > 0)
		//they owe us points, let's collect.
		for(var/i in our_quirks)
			var/points = quirk_points_by_name(i)
			if(points > 0)
				cut += i
				our_quirks -= i
				points_used -= points
			if(points_used <= 0)
				break
	*/

	//Nah, let's null all non-neutrals out.
	if(cut.len)
		for(var/i in our_quirks)
			if(quirk_points_by_name(i) != 0)
				//cut += i		-- Commented out: Only show the ones that triggered the quirk purge.
				our_quirks -= i

	return cut
