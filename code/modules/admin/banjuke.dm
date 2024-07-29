//Ban people from submitting the crew to their horrendous tastes in music.

var/jukeban_keylist[0]	//to store the keys

/proc/juke_fullban(mob/M, reason)
	if (!M || !M.key)
		return
	jukeban_keylist.Add(text("[M.ckey] ## [reason]"))
	juke_savebanfile()

/proc/juke_client_fullban(ckey)
	if (!ckey)
		return
	jukeban_keylist.Add(text("[ckey]"))
	juke_savebanfile()

//returns a reason if M is banned, returns 0 otherwise
/proc/juke_isbanned(mob/M)
	if(M)
		for(var/s in jukeban_keylist)
			if( findtext(s,M.ckey) == 1 )
				var/startpos = findtext(s, "## ") + 3
				if(startpos && startpos < length(s))
					var/text = copytext(s, startpos, 0)
					if(text)
						return text
				return "Reason Unspecified"
	return 0

/proc/juke_loadbanfile()
	if(config.ban_legacy_system)
		var/savefile/S=new("data/juke_full.ban")
		S["keys[0]"] >> jukeban_keylist
		world.log << S["keys[0]"]
		log_admin("Loading juke_rank")

		if (!length(jukeban_keylist))
			jukeban_keylist=list()
			log_admin("jukeban_keylist was empty")
	else
		if(!SSdbcore.Connect())
			diary << "Database connection failed. Reverting to the legacy ban system."
			config.ban_legacy_system = 1
			juke_loadbanfile()
			return

		//juke bans
		var/datum/DBQuery/query = SSdbcore.NewQuery("SELECT ckey FROM erro_ban WHERE bantype = :bantype AND isnull(unbanned)",
			list(
				"bantype" = "JUKE_PERMABAN",
			))
		if(!query.Execute())
			log_sql("Error: [query.ErrorMsg()]")
			qdel(query)
			return

		while(query.NextRow())
			var/ckey = query.item[1]
			jukeban_keylist.Add("[ckey]")
		qdel(query)

/proc/juke_savebanfile()
	var/savefile/S=new("data/juke_full.ban")
	S["keys[0]"] << jukeban_keylist

/proc/juke_unban(mob/M)
	juke_remove("[M.ckey]")
	juke_savebanfile()

/proc/juke_remove(X)
	for (var/i = 1; i <= length(jukeban_keylist); i++)
		if( findtext(jukeban_keylist[i], "[X]") )
			jukeban_keylist.Remove(jukeban_keylist[i])
			juke_savebanfile()
			return 1
	return 0
