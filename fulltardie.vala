// fulltardie
// forecast transactions that have complex recurrence rules
// by c.p.brown 2016~2021

using Gtk;

// cat before group

// use to prevent event-loops
bool doupdate = true;

// use to inhibit graph redraw
bool drawit = true;

// vala is super fussy about where variables live, so these have to be functions...
string textcolor () { return "#55BDFF"; }
string rowcolor () { return "#1A3B4F"; }
string ttcolor () { return "#112633"; }

// true modulo from 'cdeerinck'
// https://stackoverflow.com/questions/41180292/negative-number-modulo-in-swift#41180619
int dmod (int l, int r, int ind) {
	// this gets pounded by findnextdate, disabled diagnostics
	//var tabi = ("%-" + ind.to_string() + "s").printf("");
	//print("%sdmod: %d, %d\n", tabi, l, r);
	if (l >= 0) { return (l % r); }
	if (l >= -r) { return (l + r); }
	return ((l % r) + r) % r;
}

// check leapyear
bool lymd(int y, int ind) {
	// this gets pounded by findnextdate, disabled diagnostics
	//var tabi = ("%-" + ind.to_string() + "s").printf("");
	//print("%slymd: %d\n", tabi, y);
// technique is from Rosetta Code, most languages. 
	if ((y % 100) == 0 ) { 
		return ((y % 400) == 0);
	}
	return ((y % 4) == 0);
}

// get weekday index
int iwkd (DateWeekday wd, int ind) {
	// this gets pounded by findnextdate, disabled diagnostics
	//var tabi = ("%-" + ind.to_string() + "s").printf("");
	//print("%siwkd...\n", tabi);
	if (wd == MONDAY) { return 1; }
	if (wd == TUESDAY) { return 2; }
	if (wd == WEDNESDAY) { return 3; }
	if (wd == THURSDAY) { return 4; }
	if (wd == FRIDAY) { return 5; }
	if (wd == SATURDAY) { return 6; }
	if (wd == SUNDAY) { return 7; }
	if (wd == BAD_WEEKDAY) { return 0; }
	return 0;
}

// 
string htmlcol (int r, int g, int b, int ind) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	print("%shtmlcol: (%d, %d, %d)\n", tabi, r, g, b);
	return ("#%02X%02X%02X".printf(r, g, b));
}


// forecast per item
nextdate[] findnextdate (string[] dt, int ownr, int ind) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	print("%sfindnextdate started...\n", tabi);
	var nind  = ind + 4;
	int[] lastdayofmonth = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
	var nt = new DateTime.now_local();
	var ntd = nt.get_day_of_month();
	var ntm = nt.get_month();
	var nty = nt.get_year();
	var n = new Date();
	n.set_dmy((DateDay) ntd, ntm, (DateYear) nty);
	if (n.valid() == false) { print("invalid now date: %d %d %d\n", nty, ntm, ntd); }
	nextdate[] o = {};
	var oo = new nextdate();
	oo.nxd = n;
	oo.amt = double.parse(dt[7]);
	oo.grp = dt[9];
	oo.cat = dt[8];
	oo.dsc = dt[10];
	oo.cco = dt[11];
	oo.gco = dt[12];
	if (dt[11].strip() == "") { oo.cco = textcolor(); }
	if (dt[12].strip() == "") { oo.gco = textcolor(); }
	oo.frm = ownr;
	//print("findnextdate: nextdate.own is: %d\n", oo.frm);
	var ofs = int.parse(dt[0]);
	var nth = int.parse(dt[1]);
	var ofm = int.parse(dt[4]);
	var fmo = int.parse(dt[5]);
	var fye = int.parse(dt[6]);
	var wkd = int.parse(dt[2]);
	var fdy = int.parse(dt[3]);
	if (fmo == 0) { fmo = n.get_month(); }
	if (fye == 0) { fye = n.get_year(); }

// get last day of the month

	var t = lymd(fye,nind);
	var md = lastdayofmonth[fmo - 1];
	if (fmo == 2) { if (t) { md = 29; } }

// clamp search-start-day to last day of the month if greater

	if (md < ntd) { ntd = md; }
	var a = new Date();
	a.set_dmy((DateDay) ntd, fmo, (DateYear) fye);
	if (a.valid() == false) { print("invalid initial start date: %d %d %d\n", fye, fmo, ntd); }
	var j = new Date();
	j.set_dmy((DateDay) ntd, fmo, (DateYear) fye);
	var dif = (int) (((a.days_between(n) / 7.0) / 52.0) * 12.0) + 13;
	if (ofm > 0) {
		for (int x = 0; x < dif; x++) {
			var dmo = (a.get_month() == fmo);
			//if (ofm > 0) { dmo = ((a.get_month() - fmo) % ofm == 0); }
			if (ofm > 0) { dmo = (dmod((a.get_month() - fmo), ofm, nind) == 0); }
			var ofmcalc = dmod((a.get_month() - fmo), ofm, nind);
			//print("dmo calc: (%d - %d) = %d\n", a.get_month(), fmo, (a.get_month() - fmo));
			//print("dmo calc: ((%d - %d) mod %d) = %d\n", a.get_month(), fmo, ofm, ofmcalc);
			if (dmo) {
				var c = 0;
				var mth = md;
				t = lymd(a.get_year(),nind);
				md = lastdayofmonth[a.get_month() - 1];
				if (a.get_month() == 2) { if (t) { md = 29; } }
				var wdc = 0; // number of matching weekdays
				var cdc = 0; // number of matching per-month calendar days
// set day of the month to check: clamp nth to last day of month, set to today's day of month if invalid
				if (wkd == 0 || wkd > 7) {
					mth = int.min(nth, md);
					if (mth == 0) { mth = n.get_day(); }
				}
// count matching days and weekdays in the month, used later for every-nth calc
				for (int e = 1; e <= md; e++) {
					j.set_day((DateDay) e);
					if (j.valid() == false) { print("invalid j date generated in weekday loop [%d] (%s):\nevery: %s\nnth: %s\nweekday: %s\nfromday: %s\nofmonth: %s\nfrommonth: %s\nfromyear: %s\n\n", ownr, dt[10], dt[0], dt[1], dt[2], dt[3], dt[4], dt[5], dt[6]); }
					if (iwkd(j.get_weekday(),nind) == wkd) { wdc = wdc + 1; }
					if (e == mth) { cdc = cdc + 1; }
				}
				var cnth = int.max(int.min(nth,wdc),1);
				var cfdy = int.min(fdy,1);
				var cofs = int.max(ofs,1);
// step through the days of the month
				for (int d = 1; d <= md; d++) {
					a.set_day((DateDay) d);
					if (a.valid() == false) { print("invalid date generated in month loop [%d] (%s):\nevery: %s\nnth: %s\nweekday: %s\nfromday: %s\nofmonth: %s\nfrommonth: %s\nfromyear: %s\n\n", ownr, dt[10], dt[0], dt[1], dt[2], dt[3], dt[4], dt[5], dt[6]); }
					var chk = -1;
					var cwi = -2;
// is it looking for a weekday?
					if (wkd > 0 && wkd < 8) {
						if (iwkd(a.get_weekday(),nind) == wkd) {
							c = c + 1;  // current weekday match count
							var rem = (md - d); // get remaining days of month
// get the weekday
							//if (c >= fdy || rem < 8) {
							if (c >= fdy) {
// the actual math
								chk = (c - fdy) % (cnth * cofs);
								cwi = 0;
							}
						}
					}
// its not looking for a weekday
					if (wkd == 0 || wkd > 7) {
						if (d >= fdy) {
// the math for calendar days
							chk = 0;
							cwi = (d % (mth * cofs));
						}
					}
// we have a match
					if (chk == cwi) {
						var avd = d;
						if (iwkd(a.get_weekday(),nind) > 5) {
// get weekday before, after or closest to a weekend day
							switch (wkd) {
								case 8: avd = (int) (d + (((( (iwkd(a.get_weekday(),nind) - 5) - 1) / 1.0) * 2.0) - 1.0)); break;
								case 9: avd = d - (iwkd(a.get_weekday(),nind) - 5); break;
								case 10: avd = d + (3 - (iwkd(a.get_weekday(),nind) - 5)); break;
								default: avd = d; break;
							}
							//print("\t\t\tfindnextdate d = %d\n",avd);
// get nearest weekday if avd is out of bounds
							if (avd < 1 || avd > md) { avd = d + (3 - (iwkd(a.get_weekday(),nind) - 5)); }
// clamp it anyway, just in case...
							avd = int.min(md,int.max(1,avd));
						}
// is the matching date on or after today?
						a.set_day((DateDay) avd);
						//print("\t\ta.day: %d, a.month: %d, a.year: %d\n", ((int) a.get_day()), ((int) a.get_month()), ((int) a.get_year()));
						if (a.valid() == false) { print("invalid avd date generated by rule [%d] (%s):\nevery: %s\nnth: %s\nweekday: %s\nfromday: %s\nofmonth: %s\nfrommonth: %s\nfromyear: %s\n\n", ownr, dt[10], dt[0], dt[1], dt[2], dt[3], dt[4], dt[5], dt[6]); }
						if (a.compare(n) >= 0) {
							//print("a.day: %d, a.month: %d, a.year: %d\n", ((int) a.get_day()), ((int) a.get_month()), ((int) a.get_year()));
							oo.nxd = a; 
							o += oo;
						}
// break if just getting one day
						if (ofs == 0) { break; }
					}
				}
// reset day
				a.set_day((DateDay) 1);
				j.set_day((DateDay) 1);
				if (a.valid() == false) { print("invalid monthday reset date\n"); }
			}
// add a year if required
			if ((a.get_month() + 1) > 12) {
				a.set_year(a.get_year() + 1);
				j.set_year(j.get_year() + 1);
				if (a.valid() == false) { print("invalid year incrament date\n"); }
			}
// incrament the month
			j.set_month((j.get_month() % 12) + 1);
			a.set_month((a.get_month() % 12) + 1);
			//print("reset: a.day: %d, a.month: %d, a.year: %d\n", ((int) a.get_day()), ((int) a.get_month()), ((int) a.get_year()));
			if (a.valid() == false) { print("invalid month incrament date\n"); }
		}

// we're day-counting... this is more expensive so its handled as a special case

	} else {
		//a.set_dmy((DateDay) nth, fmo, (DateYear) fye);
		//if (a.valid() == false) { print("invalid day-count initialized date\n"); }
// use from-day if its supplied, otherwise go with today (every nth day from today)
		if (fdy > 0) { 
			a.set_dmy((DateDay) fdy, fmo, (DateYear) fye);
			if (a.valid() == false) { print("invalid day-count initialized fdy date\n"); }
		}
// we need some kind of nth-day to count
		if (ofs > 0) {
// make sure nth or ofs are not zero
			var cnth = int.max(nth,1);
			var cofs = int.max(ofs,1);
			dif = 365 + a.days_between(n);
			var qq = a;
			qq.add_days(dif);
			var c = 0;
			for (int x = 0; x < dif; x++) {
				if (a.compare(n) >= 0 && a.compare(qq) <= 0) {
					if (wkd == 0 || wkd > 7) {
						if ((x % (cnth * cofs)) == 0) {
							if (iwkd(a.get_weekday(),nind) > 5) {
								var d = (int) a.get_day();
								var avd = d;
// get weekday before, after or closest to a weekend as required
								switch (wkd) {
									case 8: avd = (int) (d + (((( (iwkd(a.get_weekday(),nind) - 5) - 1) / 1.0) * 2.0) - 1.0)); break;
									case 9: avd = d - (iwkd(a.get_weekday(),nind) - 5); break;
									case 10: avd = d + (3 - (iwkd(a.get_weekday(),nind) - 5)); break;
									default: avd = d; break;
								}
								//print("\t\t\tavd after nearest weekday check is: %d\n",avd);
								if (avd < 1 ) { 
									a.subtract_months(1);
									avd = lastdayofmonth[a.get_month() - 1] + avd; 
								} else {
									var lmd = lastdayofmonth[a.get_month() - 1];
									if (avd > lmd) {
										a.add_months(1);
										avd = avd - lmd;
									}
								}
								a.set_day((DateDay) avd);
								//print("\t\ta.day: %d, a.month: %d, a.year: %d\n", ((int) a.get_day()), ((int) a.get_month()), ((int) a.get_year()));
								if (a.valid() == false) { print("invalid day-count avd date\n"); }
							}
							//print("a.day: %d, a.month: %d, a.year: %d\n", ((int) a.get_day()), ((int) a.get_month()), ((int) a.get_year()));
							oo.nxd = a; 
							o += oo;
						}
// get nth weekday
					} else {
						if (iwkd(a.get_weekday(),nind) == wkd) {
							c = c + 1;
							if (((c - fdy) % (cnth * cofs)) == 0) {
								//print("a.day: %d, a.month: %d, a.year: %d\n", ((int) a.get_day()), ((int) a.get_month()), ((int) a.get_year()));
								oo.nxd = a;
								o += oo;
							}
						}
					}
				}
				a.add_days(1);
				if (a.valid() == false) { print("invalid day-count incrament date\n"); }
			}
		} else {
			if (nth > 0) {
				a.set_dmy((DateDay) nth, fmo, (DateYear) fye);
				if (a.valid() == false) { print("invalid day-count initialized date\n"); }
				//print("singe day rule [%d] (%s):\nevery: %s\nnth: %s\nweekday: %s\nfromday: %s\nofmonth: %s\nfrommonth: %s\nfromyear: %s\n\n", ownr, dt[10], dt[0], dt[1], dt[2], dt[3], dt[4], dt[5], dt[6]);
				if (a.compare(n) >= 0) {
					//print("a.day: %d, a.month: %d, a.year: %d\n", ((int) a.get_day()), ((int) a.get_month()), ((int) a.get_year()));
					oo.nxd = a;
					o += oo;
				} else {
// the date has passed, add a year
					a.set_dmy((DateDay) nth, fmo, (DateYear) (fye + 1));
					//print("a.day: %d, a.month: %d, a.year: %d\n", ((int) a.get_day()), ((int) a.get_month()), ((int) a.get_year()));
					oo.nxd = a;
					o += oo;
				}
			} else {
// this should only appear with zeroed rules, like initial balances. returns today
				//print("zeroed rule [%d] (%s):\nevery: %s\nnth: %s\nweekday: %s\nfromday: %s\nofmonth: %s\nfrommonth: %s\nfromyear: %s\n\n", ownr, dt[10], dt[0], dt[1], dt[2], dt[3], dt[4], dt[5], dt[6]);
				oo.nxd = n;
				o += oo;
			}
		}
	}
	print("%sfindnextdate completed.\n",tabi);
	return o;
}

void renderforecast (string[,] f, Gtk.ListBox w, int ind) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	print("%srenderforecast started...\n", tabi);
	var nind = ind + 4;
	var tabni = ("%-" + nind.to_string() + "s").printf("");

	// 0 = date
	// 1 = description
	// 2 = amount
	// 3 = cat
	// 4 = group
	// 5 = runningtotal
	// 6 = catcolor
	// 7 = groupcolor
	// 8 = owner

	if (f.length[0] > 0) {
		if (f.length[1] == 9) {
			int[] sls = {8,0,0,0,0};

			print("%srenderforecast:\tforecasted.length[0] = %d\n", tabni, f.length[0]);
			print("%srenderforecast:\tforecasted.length[1] = %d\n", tabni, f.length[1]);

// get string lengths

			for (var r = 0; r < f.length[0]; r++) {
				if (sls[4] < f[r,4].length) { sls[4] = f[r,4].length; } // group
				if (sls[3] < f[r,3].length) { sls[3] = f[r,3].length; } // cat
				if (sls[2] < f[r,2].length) { sls[2] = f[r,2].length; } // amount
				if (sls[1] < f[r,1].length) { sls[1] = f[r,1].length; } // description
			}

// render list

			for (var r = 0; r < f.length[0]; r++) {
				var row = w.get_row_at_index(r);
				if (row != null) {
					var rl = (Label) row.get_child();
					string clr = f[r,7];
					if (clr.strip() == "") { clr = textcolor(); }
					rl.set_tooltip_text(f[r,8]);
					var mqq = "".concat(
						"<span color='", clr, "' font='monospace 12px'><b>",
						f[r,0], " : ", 
						("%-" + sls[3].to_string() + "s").printf(f[r,3]), " ",
						("%-" + sls[2].to_string() + "s").printf(f[r,2]), " ",
						("%-" + sls[1].to_string() + "s").printf(f[r,1]), " ",
						" : ", f[r,5], "</b></span>"
					);
					//print("renderforecast:\tnew markup is is: %s\n", mqq);
					rl.set_markup(mqq);
					var g = new Gdk.RGBA();
					g.parse(clr);
					g.alpha = 0.1;
					row.override_background_color(NORMAL, g);
					g.parse(textcolor());
					g.alpha = 0.25;
					row.override_background_color(PRELIGHT, g);
					g.alpha = 0.5;
					row.override_background_color(SELECTED, g);
				} else {
					print("%srenderforecast: forecast list is out of sync with forecasted data at row: %d\n", tabni, r);
				}
			}
		}
	}
	print("%srenderforecast completed.\n",tabi);
}

// forecast everything in dat and render it
string[,] forecast (string[,] d, Gtk.ListBox w, bool iso, int srow, int ind) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	print("%sforecast started...\n",tabi);
	var nind = ind + 4;

	string[] rendered = {};

// pad lengths: date, group, category, amount, description

	int[] sls = {8,0,0,0,0};

// get forecasts

	nextdate[] fdat = {};
	if (iso) {
		string[] datrow = {};
		for (var g = 0; g < 13; g++) { datrow += d[srow,g]; }
		var rfc = findnextdate (datrow, srow, nind);
		for (var f = 0; f < rfc.length; f++ ) { fdat += rfc[f]; }
	} else {
		for (var u = 0; u < d.length[0]; u++) {
			string[] datrow = {};
			for (var g = 0; g < 13; g++) { datrow += d[u,g]; }
			var rfc = findnextdate (datrow, u, nind);
			for (var f = 0; f < rfc.length; f++ ) { fdat += rfc[f]; }
		}
	}

// putting data into string rows of a 1d array for sorting... this is a dumb workaround to vala's limited array handling

	for (var u = 0; u < fdat.length; u++) {
		var rfd = fdat[u];
		var ch = new char[9];
		rfd.nxd.strftime(ch,"%y %m %d");
		string txt = "";
		txt = ((string) ch) + " : " + rfd.cat + " : " + ("%.2lf").printf(rfd.amt) + " : " + rfd.dsc + ";" + (("%d").printf(rfd.frm)) + ";" + rfd.cco + ";" + rfd.gco + ";" + rfd.grp;
		rendered += txt;
		//print("assembling raw forecast row: %s\n", txt);
	}

// sorting

	GLib.qsort_with_data<string> (rendered, sizeof(string), (a, b) => GLib.strcmp (a, b));
	double rut = 0.0;
// fcdat = date, description, amount, cat, group, runningtotal, catcolor, groupcolor, owner
	string[,] fcdat = new string[rendered.length,9];

// clearing the list

	w.foreach ((element) => w.remove (element));

	for (var r = 0; r < rendered.length; r++) {
		if (rendered[r] != null || rendered[r].length > 0) {
			string[] fsb = rendered[r].split(";");
			string[] subs = fsb[0].split(":");
			var amtnum = subs[2].strip();
			if (amtnum != null || amtnum.length > 0) {
				rut = rut + double.parse(amtnum);
			}
			fcdat[r,0] = subs[0].strip();		// date
			fcdat[r,1] = subs[3].strip();		// description
			fcdat[r,2] = subs[2].strip();		// amount
			fcdat[r,3] = subs[1].strip();		// cat
			fcdat[r,4] = fsb[4];				// group
			fcdat[r,5] = ("%.2lf").printf(rut);	// runningtotal
			fcdat[r,6] = fsb[2];				// catcolor
			fcdat[r,7] = fsb[3];				// groupcolor
			fcdat[r,8] = fsb[1];				// owner
			var lbl = new Label("");
			lbl.xalign = ((float) 0.0);
			lbl.set_tooltip_text(fsb[1]);
			var mqq = "".concat("<span color='", fsb[3], "' font='monospace 12px'><b>", fsb[0].concat(" : ", ("%.2lf").printf(rut)), "</b></span>");
			lbl.set_markup(mqq);
			w.add(lbl);
		}
	}
	w.show_all();
	renderforecast(fcdat,w, nind);
	print("%sforecast done\n",tabi);
	return fcdat;
}

//paint setup list
void rendersetuplist(string[,] d, Gtk.ListBox b, int ind) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	print("%srendersetuplist started...\n",tabi);
	//var nind = ind + 4;

	var bs = b.get_selected_row();
	var bsi = 0;
	if (bs != null) { bsi = bs.get_index(); }
	for (var s = 0; s < d.length[0]; s++) {
		var row = b.get_row_at_index(s);
		string clr = d[s,12];
		//print("\t\tchecking group color: %s\n", clr);
		if (clr.strip() == "") { clr = textcolor(); }
		if (bsi == s) { clr = rowcolor(); }
		var mqq = "".concat("<span color='", clr, "' font='monospace 16px'><b>", d[s,10], "</b></span>");
		var rl = (Label) row.get_child();
		rl.set_markup(mqq);
		var g = new Gdk.RGBA();
		g.parse(clr);
		g.alpha = 0.1;
		row.override_background_color(NORMAL, g);
		g.parse(textcolor());
		g.alpha = 0.5;
		row.override_background_color(PRELIGHT, g);
		g.alpha = 1.0;
		row.override_background_color(SELECTED, g);
	}
	print("%srendersetuplist completed.\n", tabi);
}

// gather unique group/category names
string[] getchoicelist(string[,] d, int idx, int ind) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	print("%sgetchoicelist started\n", tabi);
	var whatupdate = doupdate;
	doupdate = false;
	var doit = true;
	string[] o = {};
	int[] q = {};
	int k = 0;
	for (var r = 0; r < d.length[0]; r++) {
// can't find an equavalent of: if not x in y: y.append(x)
// doing it manually:
		doit = true;
		if (o.length > 0) {
			for (var i = 0; i < o.length; i++) {
				if (o[i] == d[r,idx]) {
					q += i;
					doit = false; break;
				}
			}
		}
		if (doit) {
			//print("collecting unique list item: %s\n", d[r,idx]);
			q += o.length;
			o += d[r,idx];
		}
	}
// set colors per found gtoup/category if they're blank
// BG= RGBA(0.103486,0.229469,0.310458,1.000000) #1A3B4F (26, 59, 79)
// FG= RGBA(0.333333,0.739130,1.000000,1.000000) #55BDFF (85, 189, 255)
	for (var r = 0; r < d.length[0]; r++) {
		Random.set_seed(q[r]);
		int cidx = idx + 3;
		//print("\t\t\tchecking data: %s\n",d[r,cidx]);
		if (d[r,cidx].strip() == "") {
// random test, keep for reference
			/*
			print("\t\t\t\tdata is blank, setting %d / %d =  %f\n",(q[r] + 1),o.length,(((double) (q[r] + 1)) / ((double) o.length)));
			double[] hh = { ((((double) (q[r] + 1)) / ((double) o.length)) * ((double) 255.0)), ((double) 0.7), ((double) 0.4) };
			if (cidx == 11) {
				hh = { ((((double) (q[r] + 1)) / ((double) o.length)) * ((double) 255.0)), ((double) 0.3), ((double) 0.9) };
			}
			int[] clr = hsvtorgb(hh);
			string gg = htmlcol(clr[0], clr[1], clr[2]);
			*/
			if (cidx == 11) { d[r,cidx] = textcolor(); }
			if (cidx == 12) { d[r,cidx] = textcolor(); }
		}
	}
	if (o.length == 0) { o += "none"; }
	//doupdate = true;
	//print("\n");
	doupdate = whatupdate;
	print("%sgetchoicelist completed.\n", tabi);
	return o;
}

void adjustgroupcolor (string[,] d, string[,] f, int e, Entry h, double r, double g, double b, bool x, int ind) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	print("%sadjustgroupcolor started...\n",tabi);
	var nind = ind + 4;
// data, setuplist, hex-entry, red slider val, green slider val, blue slider val, do hex-entry
	string hx = htmlcol (((int) r), ((int) g), ((int) b), nind);
	if (x) { hx = h.text; }
// prevent overwriting hex field if editing hex field
	if (x == false) { doupdate = false; h.text = hx; doupdate = true; }
	var c = new Gdk.RGBA();
	if (c.parse(hx)) {
		d[e,12] = hx;
// update dat, matching group only
		for (var w = 0; w < d.length[0]; w++) {
			if (d[w,9] == d[e,9]) {
				d[w,12] = hx;
			}
		}
// also update forecasted, matching group only
		for (var w = 0; w < f.length[0]; w++) {
			if (f[w,4] == d[e,9]) {
				f[w,7] = hx;
			}
		}
	}
}

// select a row, update params accordingly
void selectarow (string[,] dat, Gtk.ListBox b, Gtk.FlowBox fb, Gtk.ComboBoxText evrc, Gtk.ComboBoxText nthc, Gtk.ComboBoxText wkdc, Gtk.ComboBoxText fdyc, Gtk.ComboBoxText mthc, Gtk.ComboBoxText fmoc, Gtk.Entry dsct, Gtk.SpinButton fyes, Gtk.SpinButton amts, Gtk.ComboBoxText grpc, Gtk.ComboBoxText catc, Gtk.Button gcb, int ind) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	print("%sselectarow started...\n",tabi);
	var nind = ind + 4;
	doupdate = false;
	var row = b.get_selected_row();
	var i = 0;
	if (row != null) { i = row.get_index(); }
	string[] fmo = {"from this month", "from january", "from february", "from march", "from april", "from may", "from june", "from july", "from august", "from september", "from october", "from november", "from december"};
	string[] omo = {"of this month", "of january", "of february", "of march", "of april", "of may", "of june", "of july", "of august", "of september", "of october", "of november", "of december"};
	//print("\tselected row index: %d\n", i);
	//print("\tselected row data is: %s %s %s\n", dat[i,8], dat[i,9], dat[i,10]);
	var ffs = int.parse(dat[i,2]);
	if (ffs > 7) {
		if (fb.get_child_at_index(1).get_child() == nthc) {
			fb.get_child_at_index(1).remove(nthc);
			fb.get_child_at_index(2).remove(wkdc);
			fb.get_child_at_index(1).add(wkdc);
			fb.get_child_at_index(2).add(nthc);
		}
	} else {
		if (fb.get_child_at_index(1).get_child() == wkdc) {
			fb.get_child_at_index(1).remove(wkdc);
			fb.get_child_at_index(2).remove(nthc);
			fb.get_child_at_index(1).add(nthc);
			fb.get_child_at_index(2).add(wkdc);
		}
	}
	ffs = int.parse(dat[i,0]);
	evrc.set_active(ffs);
	ffs = int.parse(dat[i,1]);
	nthc.set_active(ffs);
	ffs = int.parse(dat[i,2]);
	wkdc.set_active(ffs);
	ffs = int.parse(dat[i,3]);
	fdyc.set_active(ffs);
	ffs = int.parse(dat[i,4]);
	mthc.set_active(ffs);
	fmoc.remove_all();
	if (int.parse(dat[i,4]) == 0) {
		for (var j = 0; j < omo.length; j++) { fmoc.append_text(omo[j]); }
	} else {
		for (var j = 0; j < fmo.length; j++) { fmoc.append_text(fmo[j]); }
	}
	ffs = int.parse(dat[i,5]);
	fmoc.set_active(ffs);
	dsct.text = dat[i,10];
	if (dat[i,6] == "0") {
		fyes.set_value(((int) (GLib.get_real_time() / 31557600000000) + 1970));
	} else {
		fyes.set_value(int.parse(dat[i,6]));
	}
// there is no comboboxtext.itmes array, so hosing & rebuilding it
// comboboxtext.get_model()[x][0] doesn't work, something about void call in an expression...
	string[] cc = getchoicelist(dat, 8, nind);
	//print("\tselected row data is: %s %s %s\n", dat[i,8], dat[i,9], dat[i,10]);
	catc.remove_all();
	for (var j = 0; j < cc.length; j++) {
		catc.append_text(cc[j]);
		if (cc[j] == dat[i,8]) { catc.set_active(j); }
	}
// there is no comboboxtext.itmes array, so hosing & rebuilding it
	string[] gg = getchoicelist(dat, 9, nind);
	//print("\tselected row data is: %s %s %s\n", dat[i,8], dat[i,9], dat[i,10]);
	grpc.remove_all();
	for (var k = 0; k < gg.length; k++) {
		grpc.append_text(gg[k]);
	}
	for (var k = 0; k < gg.length; k++) {
		//print("\tdoes %s == %s?\n", gg[k], dat[i,9]);
		//if (doupdate == true) { print("selectrow: doupdate is: true\n"); }
		//if (doupdate == false) { print("selectrow: doupdate is: false\n"); }
		if (gg[k] == dat[i,9]) { grpc.set_active(k); break; }
	}
	amts.set_value( double.parse(dat[i,7]) );
	var clr = dat[i,12];
	if (clr.strip() == "") { clr = textcolor(); }
	var g = new Gdk.RGBA();
	g.parse(clr);
	gcb.override_background_color(NORMAL, g);
// set foreground text
	rendersetuplist(dat,b, nind);
	doupdate = true;
	print("%sselectarow completed.\n", tabi);
}

string moi (int i, int ind) {
	// this gets pounded by graph draw, disabling diagnostics
	//var tabi = ("%-" + ind.to_string() + "s").printf("");
	//print("%smoi: %d\n",tabi, i);
	i = int.min(int.max(i,0),11);
	string[] mo = {"JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"};
	return mo[i];
}

//    GGGGGGG  UUUU   UU  IIIIIIII
//  GGGG       UUUU   UU    IIII
//  GGGG   GG  UUUU   UU    IIII
//  GGGG   GG  UUUU   UU    IIII
//    GGGGGG     UUUUUUU  IIIIIIII

public class FTW : Window {
	private Notebook notebook;
	private ListBox setuplist;
	private Popover spop;
	private Popover lpop;
	private Popover gpop;
	private Gdk.ScrollDirection scrolldir;
	private int selectedtrns;
	private double barh;
	private double sizx;
	private double sizy;
	private double posx;
	private double posy;
	private double targx;
	private double targy;
	private double[] oldgraphsize;
	private double[] oldgraphoffset;
	private double[] mousedown;
	private double[] mousemove;
	private double[] oldmousedown;
	private bool graphzoom;
	private bool graphpan;
	private bool graphscroll;
	private bool graphpick;
	private int ind;
	string[,] dat = {
		{"1","1","7","0","1","7","0","-5.00","grocery","home","every sunday of every month starting from this september","",""},
		{"2","2","1","0","1","0","0","-10.0","train","work","every 2nd and 4th monday of every month starting this month","",""},
		{"1","6","4","0","3","2","0","150.0","pay","work","every last thursday of every 3rd month starting february","",""},
		{"1","26","8","0","1","0","0","-10.0","utility","home","every weekday closest to the 26th of the month starting this month","",""},
		{"1","32","0","0","12","2","0","-60.0","insurance","home","every last day of february","",""},
		{"0","8","0","0","0","8","0","-300.0","holiday","recreation","next august 8th","",""},
		{"0","9","9","0","1","11","0","5.0","interest","investment","every weekday before the 9th of every month starting november","",""},
		{"1","14","10","0","1","0","0","-15.0","utility","home","every 14th and 28th day of every month or the following weekday if on a weekend","",""}
	};
	string[] evr = {"the","every","every 2nd", "every 3rd", "every 4th", "every 5th", "every 6th", "every 7th", "every 8th", "every 9th", "every 10th", "every 11th","every 12th", "every 13th", "every 14th", "every 15th", "every 16th", "every 17th", "every 18th", "every 19th", "every 20th", "every 21st","every 22nd", "every 23rd", "every 24th", "every 25th", "every 26th", "every 27th", "every 28th", "every 29th", "every 30th", "every 31st", "every last"};
	string[] nth = {"", "1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th", "10th", "11th", "12th", "13th", "14th", "15th", "16th", "17th", "18th", "19th", "20th", "21st", "22nd", "23rd", "24th", "25th", "26th", "27th", "28th", "29th", "30th", "31st", "last"};
	string[] wkd = {"day", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "weekday closest to the", "weekday on or before the", "weekday on or after the"};
	string[] fdy = {"", "from the 1st", "from the 2nd", "from the 3rd", "from the 4th", "from the 5th", "from the 6th", "from the 7th", "from the 8th", "from the 9th", "from the 10th", "from the 11th", "from the 12th", "from the 13th", "from the 14th", "from the 15th", "from the 16th", "from the 17th", "from the 18th", "from the 19th", "from the 20th", "from the 21st", "from the 22nd", "from the 23rd", "from the 24th", "from the 25th", "from the 26th", "from the 27th", "from the 28th", "from the 29th", "from the 30th"};
	string[] mth = {"", "of every month", "of every 2nd month", "of every 3rd month", "of every 4th month", "of every 5th month", "of every 6th month", "of every 7th month", "of every 8th month", "of every 9th month", "of every 10th month", "of every 11th month", "of every 12th month"};
	string[] fmo = {"from this month", "from january", "from february", "from march", "from april", "from may", "from june", "from july", "from august", "from september", "from october", "from november", "from december"};
	string[] omo = {"of this month", "of january", "of february", "of march", "of april", "of may", "of june", "of july", "of august", "of september", "of october", "of november", "of december"};
	private string[,] forecasted;
	private int selectedrule;

	public FTW() {
		ind = 4;
		barh = 10;
		oldgraphoffset = {0.0,0.0};
		oldgraphsize = {690.0,690.0};
		mousedown = {0.0,0.0};
		mousemove = {0.0,0.0};
		oldmousedown = {0.0,0.0};
		graphzoom = false;
		doupdate = false;
		selectedtrns = 99999;
		this.title = "fulltardie";
		this.set_default_size(720, 500);
		this.destroy.connect(Gtk.main_quit);
		this.border_width = 10;
		
		int wx = 100;
		int wy = 100;
		this.get_size(out wx, out wy);
		print("window size is: %dx%d\n",wx,wy);

// add widgets

		Gtk.HeaderBar bar = new HeaderBar();
		bar.show_close_button  = true;
		bar.title = "fulltardie";
		this.set_titlebar (bar);
		Gtk.Grid uig = new Grid();
		uig.row_spacing = 10;
		notebook = new Notebook();
		setuplist = new ListBox();
		notebook.set_tab_pos(BOTTOM);
		notebook.set_show_border(false);

// load menu
//
// [load/save-it] <- btn
//       |
//     [pop] <------ popmenu
//       |
//    [popbox] <---- menu container
//

		var save_icon = new Gtk.Image.from_icon_name ("document-save", IconSize.SMALL_TOOLBAR);
		var load_icon = new Gtk.Image.from_icon_name ("document-open", IconSize.SMALL_TOOLBAR);
		//Gtk.Button loadit = new Button.with_label("load");
		//Gtk.Button saveit = new Button.with_label("save");
		Gtk.ToolButton loadit = new Gtk.ToolButton (load_icon, "");
		Gtk.ToolButton saveit = new Gtk.ToolButton (save_icon, "");
		Gtk.Button savebtn = new Button.with_label("save");

		lpop = new Gtk.Popover (loadit);
		spop = new Gtk.Popover (saveit);

		Gtk.Box spopbox = new Gtk.Box(VERTICAL,10);
		Gtk.Box lpopbox = new Gtk.Box(VERTICAL,5);
		spopbox.margin = 10;
		lpopbox.margin = 10;

		Gtk.Entry scene = new Entry();
		scene.text = "default";

		spopbox.add(scene);
		spopbox.add(savebtn);

		spop.add(spopbox);
		lpop.add(lpopbox);

		bar.pack_start(loadit);
		bar.pack_end(saveit);

// setup page

		var setuppage = new ScrolledWindow(null, null);
		for (var e = 0; e < dat.length[0]; e++) {
			//var ll = new Label(dat[e,10]);
			var ll = new Label("");
			ll.xalign = ((float) 0.0);
// apply markup to label
			var mqq = "".concat("<span font='monospace 16px'><b>", dat[e,10], "</b></span>");
			ll.set_markup(mqq);
			setuplist.insert(ll,-1);
		}
		setuplist.set_selection_mode(SINGLE);
		setuplist.margin = 0;
		var slc = new Gdk.RGBA();
		slc.parse(rowcolor());
		setuplist.override_background_color(NORMAL, slc);
		//setuppage.override_background_color(NORMAL, slc); // does nothing
		var flowbox = new FlowBox();
		flowbox.set_orientation(Orientation.HORIZONTAL);
		flowbox.min_children_per_line = 1;
		flowbox.max_children_per_line = 7;
		var evrcombo = new ComboBoxText();
		for (var j = 0; j < evr.length; j++) {evrcombo.append_text(evr[j]);}
		evrcombo.set_active(0);
		var nthcombo = new ComboBoxText();
		for (var j = 0; j < nth.length; j++) {nthcombo.append_text(nth[j]);}
		nthcombo.set_active(0);
		var wkdcombo = new ComboBoxText();
		for (var j = 0; j < wkd.length; j++) {wkdcombo.append_text(wkd[j]);}
		wkdcombo.set_active(0);
		var fdycombo = new ComboBoxText();
		for (var j = 0; j < fdy.length; j++) {fdycombo.append_text(fdy[j]);}
		fdycombo.set_active(0);
		var mthcombo = new ComboBoxText();
		for (var j = 0; j < mth.length; j++) {mthcombo.append_text(mth[j]);}
		mthcombo.set_active(0);
		var fmocombo = new ComboBoxText();
		for (var j = 0; j < fmo.length; j++) {fmocombo.append_text(fmo[j]);}
		fmocombo.set_active(0);
		Gtk.Button addrule = new Button.with_label("+");
		Gtk.Button remrule = new Button.with_label("-");
		fmocombo.set_active(0);
		evrcombo.set_wrap_width(4);
		nthcombo.set_wrap_width(4);
		wkdcombo.set_wrap_width(2);
		fdycombo.set_wrap_width(2);
		mthcombo.set_wrap_width(2);
		fmocombo.set_wrap_width(2); 
		Gtk.Adjustment yadj = new Adjustment(2021,1990,2100,1,5,1);
		yadj.set_value((int) (GLib.get_real_time() / 31557600000000) + 1970);
		Gtk.SpinButton fye = new SpinButton(yadj,1,0);
		flowbox.add(evrcombo);
		flowbox.add(nthcombo);
		flowbox.add(wkdcombo);
		flowbox.add(fdycombo);
		flowbox.add(mthcombo);
		flowbox.add(fmocombo);
		flowbox.add(fye);

// non date params

		var dsc = new Entry();
		dsc.text = dat[0,10];
		dsc.hexpand = true;
		Gtk.Adjustment adj = new Adjustment(0.0,-100000,100000.0,10.0,100.0,1.0);
		Gtk.SpinButton amtf = new SpinButton(adj,1.0,2);
		var grpcombo = new ComboBoxText.with_entry();
		var vv = (Entry) grpcombo.get_child();
		vv.set_width_chars(8);
		var catcombo = new ComboBoxText.with_entry();
		var ee = (Entry) catcombo.get_child();
		ee.set_width_chars(8);
		var grp = new Box(VERTICAL,10);
		//grp.margin = 10;
		var hgrp = new Box(HORIZONTAL,10);
		hgrp.add(dsc);
		var hbgrp = new FlowBox();
		hbgrp.set_orientation(Orientation.HORIZONTAL);
		hbgrp.min_children_per_line = 1;
		hbgrp.max_children_per_line = 5;
		Gtk.Label glb = new Label("grp");
		glb.set_max_width_chars(8);

// color swatch
		Gtk.Button grpcolb = new Button();
		grpcolb.set_size_request (20,10);
		var www = new Gdk.RGBA();
		www.parse(textcolor());

// swatch background color (26, 59, 79)
		grpcolb.override_background_color(NORMAL, www); // this doesn't work for buttons

		gpop = new Gtk.Popover (grpcolb);
		Gtk.Box cpbox = new Gtk.Box (VERTICAL,2);
		cpbox.set_size_request (200,10);
		gpop.add(cpbox);
		Gtk.Scale rrr = new Scale.with_range(HORIZONTAL, 0, 255, 100);
		rrr.set_value(26);
		Gtk.Scale ggg = new Scale.with_range(HORIZONTAL, 0, 255, 100);
		ggg.set_value(59);
		Gtk.Scale bbb = new Scale.with_range(HORIZONTAL, 0, 255, 100);
		bbb.set_value(79);
		var hhh = new Entry();
		hhh.text = "#1A3B4F";
		hhh.set_width_chars(8);
		cpbox.add(hhh);
		cpbox.add(rrr);
		cpbox.add(ggg);
		cpbox.add(bbb);

		Gtk.Label clb = new Label("cat");
		clb.set_max_width_chars(8);
		Gtk.Label alb = new Label("amt");
		alb.set_max_width_chars(8);
		Gtk.ToggleButton iso = new ToggleButton.with_label("isolate");
		var grpbox = new Box(HORIZONTAL,10);
		var catbox = new Box(HORIZONTAL,10);
		var amtbox = new Box(HORIZONTAL,10);
		iso.set_halign(END);
		hbgrp.set_column_spacing(10);
		grpbox.add(glb);
		glb.set_halign(START);
		grpbox.add(grpcombo);
		grpcombo.set_halign(START);
		grpbox.add(grpcolb);
		grpcolb.set_halign(START);
		catbox.add(clb);
		clb.set_halign(START);
		catbox.add(catcombo);
		catcombo.set_halign(START);
		amtbox.add(alb);
		amtbox.add(amtf);
		hbgrp.add(grpbox);
		hbgrp.add(catbox);
		hbgrp.add(amtbox);
		hbgrp.add(iso);
		hgrp.add(addrule);
		hgrp.add(remrule);

// assemble params

		grp.add(hgrp);
		grp.add(flowbox);
		grp.add(hbgrp);

// more containers

		var setuplistcontainer = new ScrolledWindow(null,null);
		setuplistcontainer.set_vexpand(true);
		setuplistcontainer.add(setuplist);
		setuppage.add(setuplistcontainer);
		var grid = new Grid();
		grid.set_row_spacing(5);
		grid.set_column_spacing(5);
		//grid.attach(setuplistcontainer,0,0,1,1);
		grid.attach(grp,0,1,1,1);
		grid.set_baseline_row(1);
		//setuppage.add(grid);

// add everything to the main grid

		uig.attach(notebook, 0, 0, 1, 1);
		uig.attach(grid, 0, 1, 1, 1);
		this.add(uig);

// foecast page

		var forecastpage = new ScrolledWindow(null, null);
		var forecastlistbox = new ListBox();
		forecastlistbox.override_background_color(NORMAL, slc);
		for (var i = 1; i < 10; i++) {
			string text = @"Label $i";
			var labele = new Label(text);
			forecastlistbox.add(labele);
		}
		forecastlistbox.margin = 0;
		forecastpage.add(forecastlistbox);
		var label2 = new Label(null);
		label2.set_markup("<b><big>setup</big></b>");
		var label3 = new Label(null);
		label3.set_markup("<b><big>forecast</big></b>");

// graph page

		var label4 = new Label(null);
		label4.set_markup("<b><big>graph</big></b>");
		var graphimg = new Gtk.DrawingArea();

// graph draw -- move to events below once its allgood

		graphimg.draw.connect((ctx) => {
			//print("\ngraphimg.draw: started...\n");
			if (drawit) {
				var presel = selectedrule;
				var csx = graphimg.get_allocated_width();
				var csy = graphimg.get_allocated_height();

// graph coords

				sizx = oldgraphsize[0];
				sizy = oldgraphsize[1];
				if (graphzoom || graphscroll) {
					sizx = (oldgraphsize[0] + (mousemove[0] - mousedown[0]));
					sizy = (oldgraphsize[1] + (mousemove[1] - mousedown[1]));
				}
				//print("graphimg.draw: \tsizx = %f\n", sizx);
				//print("graphimg.draw: \tmousedown[0] = %f\n", mousedown[0]);
				//print("graphimg.draw: \tmousemove[0] = %f\n", mousemove[0]);
				//print("graphimg.draw: \toldgraphsize[0] = %f\n", oldgraphsize[0]);
				//print("graphimg.draw: \toldgraphoffset[0] = %f\n", oldgraphoffset[0]);
				//print("graphimg.draw: \toldmousedown[0] = %f\n", oldmousedown[0]);
				//print("graphimg.draw: \ttargx = %f\n", targx);
				posx = oldgraphoffset[0];
				posy = oldgraphoffset[1];
				if (graphzoom || graphscroll) {
					posx = oldgraphoffset[0] + ( (mousedown[0] - oldgraphoffset[0]) - ( (mousedown[0] - oldgraphoffset[0]) * (sizx / oldgraphsize[0]) ) ) ;
					posy = oldgraphoffset[1] + ( (mousedown[1] - oldgraphoffset[1]) - ( (mousedown[1] - oldgraphoffset[1]) * (sizy / oldgraphsize[1]) ) ) ;
					targx = oldmousedown[0] + ( (mousedown[0] - oldmousedown[0]) - ( (mousedown[0] - oldmousedown[0]) * (sizx / oldgraphsize[0]) ) ) ;
					targy = oldmousedown[1] + ( (mousedown[1] - oldmousedown[1]) - ( (mousedown[1] - oldmousedown[1]) * (sizy / oldgraphsize[1]) ) ) ;
				}
				if(graphpan) {
					posx = oldgraphoffset[0] + (mousemove[0] - mousedown[0]);
					posy = oldgraphoffset[1] + (mousemove[1] - mousedown[1]);
					targx = oldmousedown[0] + (mousemove[0] - mousedown[0]);
					targy = oldmousedown[1] + (mousemove[1] - mousedown[1]);
				}
				if (graphpick) {
					targx = mousedown[0];
					targy = mousedown[1];
				}

// graph margins, not used for now

				//var margx = 40.0;
				//var margy = 40.0;

// bar height

				var barh = sizy / forecasted.length[0];

// get min/max vals from running total

				var minrt = 999999999.0;
				var maxrt = -999999999.0;
				for (int i = 0; i < forecasted.length[0]; i++) {
					if (forecasted[i,5] != "") {
						maxrt = double.max(maxrt, double.parse(forecasted[i,5]));
						minrt = double.min(minrt, double.parse(forecasted[i,5]));
					}
				}

// get x scale & zero, scale both to container

				var zro = minrt.abs();
				var xmx = zro + maxrt;
				var sfc = sizx / xmx;
				zro = zro * sfc;
				zro = Math.floor(zro);

// paint bg

				var bc = new Gdk.RGBA();
				bc.parse(rowcolor());
				ctx.set_source_rgba(bc.red,bc.green,bc.blue,1);
				ctx.paint();

// vars for runningtotal and month sizes in bars
// forecasted = date, description, amount, cat, group, runningtotal, catcolor, groupcolor, owner
// mol = # trans per month
// mox = month number
// eg: mol[2] = 8 tansactions, mox[2] = october

				var xx = 0.0;
				double[] mol = {};
				int[] mox = {};
				int mmy = -1;
				int mrk = -1;
				for (int i = 0; i < forecasted.length[0]; i++) {
					if (forecasted[i,0] != "") {
						var dseg = forecasted[i,0].split(" ");
						if (dseg[1].strip() != "") {
							var midx = (int.parse(dseg[1]) - 1);
// the incoming data is sorted, so grow the month arrays when a change is detected
							if (midx != mmy) { mmy = midx; mrk += 1; mol += 0; mox += 0; }
							mol[mrk] += barh;
							mox[mrk] = mmy;
						}
					}
				}

// draw alternating month backgrounds

				var stackmo = 0.0;
				stackmo = stackmo + posy;
				for (int i = 0; i < mol.length; i++) {
					bc.parse(rowcolor());
					if (((i + 1) % 2) == 0) {
						bc.parse(textcolor());
					}
					ctx.set_source_rgba(bc.red,bc.green,bc.blue,0.05);
					ctx.rectangle(0, stackmo, csx, mol[i]);
					ctx.fill();
					bc.parse(textcolor());
					ctx.set_source_rgba(bc.red,bc.green,bc.blue,0.3);
					ctx.select_font_face("Monospace",Cairo.FontSlant.NORMAL,Cairo.FontWeight.BOLD);
					ctx.set_font_size (14);
					ctx.move_to (5, (stackmo+18));
					var motx = moi(mox[i], ind);
					ctx.show_text(motx);
					stackmo += mol[i];
				}

// check selection hit

				var px = 0.0;
				var py = 0.0;
				if (graphpick && mousedown[0] > 0 && graphzoom == false && graphpan == false && graphscroll == false) {
					selectedtrns = 99999;
					for (int i = 0; i < forecasted.length[0]; i++) {
						px = 0.0;
						py = 0.0;
						xx = 0.0;
						if (forecasted[i,5] != "") { 
							xx = double.parse(forecasted[i,5]);
							xx = xx * sfc;
							xx = Math.floor(xx);
							px = double.min((zro + xx),zro);
							px = Math.floor(px);
							px = px + posx;
							py = i * barh;
							py = py + posy;
							if (mousedown[0] > px && mousedown[0] < (px + xx.abs())) {
								if (mousedown[1] > py && mousedown[1] < (py + (barh - 1))) {
									selectedrule = int.parse(forecasted[i,8]);
									selectedtrns = i;
									targx = mousedown[0]; targy = mousedown[1];
									break;
								}
							}
						}
					}
				}

// draw bars for running total

				for (int i = 0; i < forecasted.length[0]; i++) {
					xx = 0.0;
					px = 0.0;
					py = 0.0;
					if (forecasted[i,5] != "") {
						xx = double.parse(forecasted[i,5]);
					}
					if (forecasted[i,7] != "") {
						if(bc.parse(forecasted[i,7])) {
						} else {
							bc.parse(textcolor());
						}
					}
					xx = xx * sfc;
					xx = Math.floor(xx);
					px = double.min((zro + xx),zro);
					px = Math.floor(px);
					px = px + posx;
					py = i * barh;
					py = py + posy;
					ctx.set_source_rgba(bc.red,bc.green,bc.blue,0.9);
					ctx.rectangle(px, py, xx.abs(), (barh - 1));
					ctx.fill ();
					if (selectedrule == int.parse(forecasted[i,8])) { 
						bc.red = 1.0; bc.green = 1.0; bc.blue = 1.0;
						ctx.set_source_rgba(bc.red,bc.green,bc.blue,0.5);
						ctx.rectangle(px, py, xx.abs(), (barh - 1));
						ctx.fill();
						ctx.set_source_rgba(bc.red,bc.green,bc.blue,0.9);
						ctx.rectangle(px+1, py+1, xx.abs()-2, (barh - 3));
						ctx.set_line_width(2);
						ctx.stroke();
					}
				}

// draw selected transaction overlay

				if (selectedtrns != 99999) {
					// now.format ("%d/%m/%Y")
					string[] jj = (forecasted[selectedtrns,0]).split(" ");
					string xinf = "".concat(jj[2], " ", moi((int.parse(jj[1]) - 1), ind), " 20", jj[0], " : ", forecasted[selectedtrns,5]);
					Cairo.TextExtents extents;
					ctx.text_extents (xinf, out extents);
					var ibx = extents.width + 40;
					var ixx = double.min(double.max(20,(targx - (ibx * 0.5))),(graphimg.get_allocated_width() - (ibx + 20)));
					var ixy = double.min(double.max(20,(targy + 20)),(graphimg.get_allocated_height() - 50));
					var ltx = double.min(double.max((ixx + 10), targx),(ixx + ibx - 10));
					var lty = double.min(double.max((ixy + 10), targy),(ixy + 20));
					bc.parse(ttcolor());
					ctx.set_source_rgba(bc.red,bc.green,bc.blue,1.0);
					ctx.rectangle(ixx, ixy, ibx, 30);
					ctx.fill();

// draw pointer
// cairo doesn't seem to do variable width lines, unless there's a hacky way to scale it
// doing it as a triangle for now...

					ctx.set_line_cap (Cairo.LineCap.ROUND);
					ctx.move_to(targx, targy);
					double[] ab = { (targx - ltx), (targy - lty), 0.0 };
					double[] cx = { ((ab[1] * 1.0) - (ab[2] * 0.0)), ((ab[2] * 0.0) - (ab[0] * 1.0)), ((ab[0] * 0.0) - (ab[1] * 0.0)) };
					double cxl = Math.sqrt( (cx[0] * cx[0]) + (cx[1] * cx[1]) + (cx[2] * cx[2]) );
					if (cxl > 0) {
						cx[0] = ((cx[0] / cxl) * 5.0);
						cx[1] = ((cx[1] / cxl) * 5.0);
						ctx.line_to((ltx + cx[0]),(lty + cx[1]));
						ctx.line_to((ltx - cx[0]),(lty - cx[1]));
						ctx.close_path();
						ctx.fill();
					}
					ctx.move_to((ixx + 20), (ixy + 20));
					bc.parse(textcolor());
					ctx.set_source_rgba(bc.red,bc.green,bc.blue,0.9);
					ctx.show_text(xinf);
				}

// new rule selection detected, update the rest of the ui
// this is triggering a double draw for some reason...

				if (selectedrule >= 0 && selectedrule != presel) {
					var row = setuplist.get_row_at_index(selectedrule);
					if (row != null) {
						doupdate = false; setuplist.select_row(row); doupdate = true;
						selectarow (dat, setuplist, flowbox, evrcombo, nthcombo, wkdcombo, fdycombo, mthcombo, fmocombo, dsc, fye, amtf, grpcombo, catcombo, grpcolb, ind);
					}
				}

// reset mouseown if not doing anythting with it

				if (graphzoom == false && graphpan == false && graphscroll == false) {
					mousedown[0] = 0;
					mousedown[1] = 0;
					graphpick = false;
				}

// there's no wheel_end event so these go here... its a pulse event so works ok

				if (graphscroll) { 
					graphscroll = false;
					oldgraphsize = {sizx, sizy};
					oldgraphoffset = {posx, posy};
					oldmousedown = {targx, targy};
				}
			}
			//print("graphimg.draw: complete\n\n");
			return true;
		});

// graph interaction

		graphimg.add_events (Gdk.EventMask.BUTTON_PRESS_MASK);
		graphimg.add_events (Gdk.EventMask.BUTTON2_MOTION_MASK);
		graphimg.add_events (Gdk.EventMask.BUTTON3_MOTION_MASK);
		graphimg.add_events (Gdk.EventMask.BUTTON_RELEASE_MASK);
		graphimg.add_events (Gdk.EventMask.POINTER_MOTION_MASK);
		graphimg.add_events (Gdk.EventMask.SCROLL_MASK);
		graphimg.button_press_event.connect ((event) => {
			ind = 4;
			//print("graphimg.button_press_event\n");
			mousedown = {event.x, event.y};
			graphpick = (event.button == 1);
			graphzoom = (event.button == 3);
			graphpan = (event.button == 2);
			if (graphpick) { 
				oldmousedown = {mousedown[0], mousedown[1]};
				targx = mousedown[0]; targy = mousedown[1]; 
			}
// this doesn't work
//			graphscroll = (event.button == 4 || event.button == 5);
			//print("graphimg.button_press_event.connect: event.button = %u\n", event.button);
			//print("graphimg.button_press_event is redrawing the graph...\n");
			//if (graphpick) { graphimg.queue_draw(); }
			return true;
		});
		graphimg.motion_notify_event.connect ((event) => {
			ind = 4;
			if (graphzoom == false && graphpan == false && graphpick == false) { mousedown = {event.x, event.y}; }
			//print("we're hoverin @ %f x %f\n", mousemove[0], mousemove[1]);
			mousemove = {event.x, event.y};
			if (graphzoom || graphpan) {
				//mousemove = {event.x, event.y};
				//print("graphimg.motion_notify_event is redrawing the graph...\n");
				graphimg.queue_draw();
			}
			return true;
		});
		graphimg.scroll_event.connect ((event) => {
				ind = 4;
			//if (graphscroll) {
				scrolldir = UP;
				if (event.scroll.direction == scrolldir) {
					graphscroll = true;
					//mousedown = {targx, targy};
					//mousedown = {event.x, event.y};
					mousemove = {(mousedown[0] + 50.0), (mousedown[1] + 50.0)};
					//print("graphimg.scroll_event.scroll.direction UP is redrawing the graph...\n");
					graphimg.queue_draw();
				}
				scrolldir = DOWN;
				if (event.scroll.direction == scrolldir)  {
					graphscroll = true;
					//mousedown = {targx, targy};
					//mousedown = {event.x, event.y};
					mousemove = {(mousedown[0] - 50.0), (mousedown[1] - 50.0)};
					//print("graphimg.scroll_event.scroll.direction DOWN is redrawing the graph...\n");
					graphimg.queue_draw();
				}
			//}
			return true;
		});

// reset/update stuff on mouse release

		graphimg.button_release_event.connect ((event) => {
			ind = 4;
			print("graphimg.button_release_event\n");
			graphzoom = false;
			graphpan = false;
			graphscroll = false;
			if (graphpick) { 
				print("graphimg.button_release_event is redrawing the graph...\n");
				graphimg.queue_draw(); 
			}
			oldgraphsize = {sizx, sizy};
			oldgraphoffset = {posx, posy};
			oldmousedown = {targx, targy};
			print("graphimg.button_release_event: \toldmousedown[0] = %f\n", oldmousedown[0]);
			return true;
		});

// add pages to notebook

		notebook.append_page(setuppage, label2);
		notebook.append_page(forecastpage, label3);
		//notebook.append_page(graphpage, label4);
		notebook.append_page(graphimg, label4); 

// select row

		mousedown[0] = 0;
		mousedown[1] = 0;
		var row = setuplist.get_row_at_index(0);
		selectedrule = 0;
		selectarow (dat, setuplist, flowbox, evrcombo, nthcombo, wkdcombo, fdycombo, mthcombo, fmocombo, dsc, fye, amtf, grpcombo, catcombo, grpcolb, ind);
		doupdate = true;

//  EEEEEEEE VVVV  VV EEEEEEEE NNNNNN   TTTTTTTT   SSSSSS
//  EEEE     VVVV  VV EEEE     NNNN  NN   TTTT   SSSS
//  EEEEEE   VVVV  VV EEEEEE   NNNN  NN   TTTT     SSSS
//  EEEE     VVVV  VV EEEE     NNNN  NN   TTTT       SSSS
//  EEEEEEEE   VVVV   EEEEEEEE NNNN  NN   TTTT   SSSSSS

//tab panel selection action

		notebook.switch_page.connect ((page, page_num) => {
			var s = setuplist.get_selected_row();
			var r = 0;
			if (s != null) {
				var pix = ((int) page_num);
				print("notebook.switch_page.connect:\tswitching to tab: %d\n", pix);
				ind = 4; 
				r = s.get_index();
				if (pix == 0) {
					rendersetuplist(dat, setuplist, ind);
				}
				if (pix == 1) {
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), r, ind);
				}
				if (pix == 2) {
					renderforecast(forecasted, forecastlistbox, ind);
					graphimg.queue_draw ();
				}
			}
		});

// setup list item select action

		setuplist.row_selected.connect ((row) => {
			if (doupdate) {
				print("setuplist.row_selected.connect:\tselecting row: %d\n", row.get_index());
				ind = 4;
				selectedrule = row.get_index();
				selectarow (dat, setuplist, flowbox, evrcombo, nthcombo, wkdcombo, fdycombo, mthcombo, fmocombo, dsc, fye, amtf, grpcombo, catcombo, grpcolb, ind);
			}
		});

// forecast list item double-click to get creating rule

		forecastlistbox.row_activated.connect ((row) => {
			if (doupdate) {
				ind = 4;
				var fs = forecastlistbox.get_selected_row();
				var fr = 0;
				if (fs != null) {
					print("forecastlistbox.row_activated.connect:\tselecting row: %d\n", row.get_index());
					fr = fs.get_index();
					var ll = (Label) row.get_child();
					//print("selected forecast row label tooltip: %s\n", ll.tooltip_text);
					if (ll.tooltip_text != null) {
						var own = int.parse(ll.tooltip_text);
						selectedrule = own;
						row = setuplist.get_row_at_index(own);
						doupdate = false; setuplist.select_row(row); doupdate = true;
						selectarow (dat, setuplist, flowbox, evrcombo, nthcombo, wkdcombo, fdycombo, mthcombo, fmocombo, dsc, fye, amtf, grpcombo, catcombo, grpcolb, ind);
					}
				}
			}
		});

// setup data lists changed

		evrcombo.changed.connect(() => {
			if (doupdate) {
				ind = 4;
				var n = evrcombo.get_active();
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) { 
					print("evrcombo.changed.connect:\tselecting item: %d\n", n);
					r = s.get_index(); 
					dat[r,0] = n.to_string();
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), r, ind);
					graphimg.queue_draw ();
					//print ( "evrcombo.changed: dat[%d,%d] = %s\n", r, 0, dat[r,0]);
				}
			}
		});
		nthcombo.changed.connect(() => {
			if (doupdate) {
				ind = 4;
				var n = nthcombo.get_active();
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) { 
					print("nthcombo.changed.connect:\tselecting item: %d\n", n);
					r = s.get_index();
					dat[r,1] = n.to_string();
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), r, ind);
					graphimg.queue_draw ();
					//print ( "dat[%d,%d] = %s\n", r, 0, dat[r,1]);
				}
			}
		});
		wkdcombo.changed.connect(() => {
			if (doupdate) {
				ind = 4;
				var n = wkdcombo.get_active();
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) { 
					print("wkdcombo.changed.connect:\tselecting item: %d\n", n);
					r = s.get_index();
					dat[r,2] = n.to_string();
					var ffs = int.parse(dat[r,2]);
					if (ffs > 7) {
						if (flowbox.get_child_at_index(1).get_child() == nthcombo) {
							flowbox.get_child_at_index(1).remove(nthcombo);
							flowbox.get_child_at_index(2).remove(wkdcombo);
							flowbox.get_child_at_index(1).add(wkdcombo);
							flowbox.get_child_at_index(2).add(nthcombo);
						}
					} else {
						if (flowbox.get_child_at_index(1).get_child() == wkdcombo) {
							flowbox.get_child_at_index(1).remove(wkdcombo);
							flowbox.get_child_at_index(2).remove(nthcombo);
							flowbox.get_child_at_index(1).add(nthcombo);
							flowbox.get_child_at_index(2).add(wkdcombo);
						}
					}
					forecasted = forecast(dat,forecastlistbox, iso.get_active(), r, ind);
					graphimg.queue_draw ();
				}
			}
		});
		fdycombo.changed.connect(() => {
			if (doupdate) {
				ind = 4;
				var n = fdycombo.get_active();
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) { 
					print("fdycombo.changed.connect:\tselecting item: %d\n", n);
					r = s.get_index();
					dat[r,3] = n.to_string();
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), r, ind);
					graphimg.queue_draw ();
					//print ( "dat[%d,%d] = %s\n", r, 0, dat[r,3]);
				}
			}
		});
		mthcombo.changed.connect(() => {
			if (doupdate) {
				ind = 4;
				var n = mthcombo.get_active();
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) { 
					print("mthcombo.changed.connect:\tselecting item: %d\n", n);
					r = s.get_index();
					dat[r,4] = n.to_string();
					int ffs = int.parse(dat[r,5]);
// change from-month to of-month if this combo is zeroed - so the rule makes mroe sense in english
					doupdate = false;
					fmocombo.remove_all();
					if (int.parse(dat[r,4]) == 0) {
						for (var j = 0; j < omo.length; j++) { fmocombo.append_text(omo[j]); }
					} else {
						for (var j = 0; j < fmo.length; j++) { fmocombo.append_text(fmo[j]); }
					}
					fmocombo.set_active(ffs);
					doupdate = true;
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), r, ind);
					graphimg.queue_draw ();
					//print ( "dat[%d,%d] = %s\n", r, 0, dat[r,4]);
				}
			}
		});
		fmocombo.changed.connect(() => {
			if (doupdate) {
				ind = 4;
				var n = fmocombo.get_active();
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) {
					print("fmocombo.changed.connect:\tselecting item: %d\n", n);
					r = s.get_index();
					dat[r,5] = n.to_string();
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), r, ind);
					graphimg.queue_draw ();
					//print ( "dat[%d,%d] = %s\n", r, 0, dat[r,5]);
				}
			}
		});
		fye.changed.connect(() => {
			if (doupdate) {
				ind = 4;
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) { 
					var v = fye.get_value();
					print("fye.changed.connect:\tchanging value to: %f\n", v);
					r = s.get_index();
					if (v == ((int) (GLib.get_real_time() / 31557600000000) + 1970)) {
						dat[r,6] = "0";
					} else {
						dat[r,6] = ((string) ("%lf").printf(v));
					}
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), r, ind);
					graphimg.queue_draw ();
				}
			}
		});
		grpcombo.changed.connect(() => {
			if (doupdate) {
				ind = 4;
				var n = grpcombo.get_active_text();
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) {
					print("grpcombo.changed.connect:\tselecting item: %s\n", n);
					r = s.get_index();
					dat[r,9] = n;
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), r, ind);
				}
			}
		});
		catcombo.changed.connect(() => {
			if (doupdate) {
				ind = 4;
				var n = catcombo.get_active_text();
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) {
					print("catcombo.changed.connect:\tselecting item: %s\n", n);
					r = s.get_index();
					dat[r,8] = n;
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), r, ind);
				}
			}
		});
		ee = (Entry) catcombo.get_child();
		ee.activate.connect(() => {
			if (doupdate) {
				ind = 4;
				var n = ee.text;
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) {
					print("ee.activate.connect:\tselecting item: %s\n", n);
					r = s.get_index();
					dat[r,8] = n;
					string[] cc = getchoicelist(dat,8, ind);
					catcombo.remove_all();
					for (var j = 0; j < cc.length; j++) {
						catcombo.append_text(cc[j]);
						if (cc[j] == n) { r = j; }
					}
					catcombo.set_active(r);
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), r, ind);
					//print("category text entered: %s\n", ee.text );
					doupdate = true;
				}
			}
		});
		vv = (Entry) grpcombo.get_child();
		vv.activate.connect(() => {
			if (doupdate) {
				ind = 4;
				var n = vv.text;
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) {
					print("vv.activate.connect:\tselecting item: %s\n", n);
					r = s.get_index();
					dat[r,9] = n;
					string[] cc = getchoicelist(dat,9, ind);
					grpcombo.remove_all();
					for (var j = 0; j < cc.length; j++) {
						grpcombo.append_text(cc[j]);
						if (cc[j] == n) { r = j; }
					}
					grpcombo.set_active(r);
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), r, ind);
					doupdate = true;
				}
			}
		});
		amtf.value_changed.connect(() => {
			if (doupdate) {
				ind = 4;
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) { r = s.get_index(); }
				print("amtf.value_changed.connect:\tchanging value to: %f\n", amtf.get_value());
				dat[r,7] =((string) ("%.2lf").printf(amtf.get_value()));;
				forecasted = forecast(dat, forecastlistbox, iso.get_active(), r, ind);
				print("amtf.changed.connect is redrawing the graph...\n");
				graphimg.queue_draw ();
			}
		});
		iso.toggled.connect(() => {
			if (doupdate) {
				ind = 4;
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) {
					print("iso.toggled.connect:\ttoggling isolate...\n");
					r = s.get_index();
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), r, ind);
					print("iso.toggled.connect is redrawing the graph...\n");
					graphimg.queue_draw ();
				}
			}
		});
		dsc.changed.connect(() => {
			if (doupdate) {
				ind = 4;
				if (dsc.text != null) {
					if (dsc.text.strip() != "") {
						var s = setuplist.get_selected_row();
						var r = 0;
						if (s != null) {
							print("dsc.changed.connect:\tchanging text to: %s\n", dsc.text);
							r = s.get_index();
							dat[r,10] = dsc.text;
							var l = (Label) s.get_child();
							var mq = "".concat("<span color='", rowcolor(), "' font='monospace 16px'><b>", dat[r,10], "</b></span>");
							doupdate = false;
							l.set_markup(mq);
							forecasted = forecast(dat, forecastlistbox, iso.get_active(), r, ind);
							doupdate = true;
						}
					}
				}
			}
		});
		grpcolb.button_press_event.connect(() =>  {
			var s = setuplist.get_selected_row();
			var r = 0;
			if (s != null) {
				ind = 4;
				r = s.get_index();
				string h = dat[r,12];
				if (h.strip() == "") { h = textcolor(); print("group color data not found: %s", dat[r,12]); }
				var g = new Gdk.RGBA();
				if (g.parse(h)) {
					doupdate = false;
					hhh.text = h;
					rrr.adjustment.value = ((double) ((int) (g.red * 255.0)));
					ggg.adjustment.value = ((double) ((int) (g.green * 255.0)));
					bbb.adjustment.value = ((double) ((int) (g.blue * 255.0)));
					gpop.show_all();
					hhh.visible = false;
					doupdate = true;
				}
			}
			return true;
		});
		rrr.adjustment.value_changed.connect(() => {
			if (doupdate) {
				ind = 4;
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) {
					doupdate = false;
					print("rrr.adjustment.value_changed.connect:\tchanging value to: %f\n", rrr.adjustment.value);
					r = s.get_index();
					adjustgroupcolor(dat, forecasted, r, hhh, rrr.adjustment.value, ggg.adjustment.value, bbb.adjustment.value, false, ind);
					if (notebook.get_current_page() == 0) {
						rendersetuplist(dat, setuplist, ind);
					}
					if (notebook.get_current_page() == 1) {
						renderforecast(forecasted, forecastlistbox, ind);
					}
					if (notebook.get_current_page() == 2) {
						renderforecast(forecasted, forecastlistbox, ind);
						graphimg.queue_draw ();
					}
					doupdate = true;
				}
			}
		});
		ggg.adjustment.value_changed.connect(() => {
			if (doupdate) {
				ind = 4;
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) {
					doupdate = false;
					r = s.get_index();
					print("ggg.adjustment.value_changed.connect:\tchanging value to: %f\n", ggg.adjustment.value);
					adjustgroupcolor(dat, forecasted, r, hhh, rrr.adjustment.value, ggg.adjustment.value, bbb.adjustment.value, false, ind);
					if (notebook.get_current_page() == 0) {
						rendersetuplist(dat, setuplist, ind);
					}
					if (notebook.get_current_page() == 1) {
						renderforecast(forecasted, forecastlistbox, ind);
					}
					if (notebook.get_current_page() == 2) {
						renderforecast(forecasted, forecastlistbox, ind);
						graphimg.queue_draw ();
					}
					doupdate = true;
				}
			}
		});
		bbb.adjustment.value_changed.connect(() => {
			if (doupdate) {
				ind = 4;
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) {
					doupdate = false;
					print("bbb.adjustment.value_changed.connect:\tchanging value to: %f\n", bbb.adjustment.value);
					r = s.get_index();
					adjustgroupcolor(dat, forecasted, r, hhh, rrr.adjustment.value, ggg.adjustment.value, bbb.adjustment.value, false, ind);
					if (notebook.get_current_page() == 0) {
						rendersetuplist(dat, setuplist, ind);
					}
					if (notebook.get_current_page() == 1) {
						renderforecast(forecasted, forecastlistbox, ind);
					}
					if (notebook.get_current_page() == 2) {
						renderforecast(forecasted, forecastlistbox, ind);
						graphimg.queue_draw ();
					}
					doupdate = true;
				}
			}
		});
		hhh.changed.connect (() => {
			if (doupdate) {
				ind = 4;
				if (hhh.text.strip() != "") {
					var g = new Gdk.RGBA();
					if (g.parse(hhh.text)) {
						var s = setuplist.get_selected_row();
						var r = 0;
						if (s != null) {
							doupdate = false;
							print("hhh.changed.connect:\tchanging value to: %s\n", hhh.text);
							r = s.get_index();
							adjustgroupcolor(dat, forecasted, r, hhh, rrr.adjustment.value, ggg.adjustment.value, bbb.adjustment.value, false, ind);
							if (notebook.get_current_page() == 0) {
								rendersetuplist(dat, setuplist, ind);
							}
							if (notebook.get_current_page() == 1) {
								renderforecast(forecasted, forecastlistbox, ind);
							}
							if (notebook.get_current_page() == 2) {
								renderforecast(forecasted, forecastlistbox, ind);
								graphimg.queue_draw ();
							}
							rrr.adjustment.value = ((double) ((int) (g.red * 255.0)));
							ggg.adjustment.value = ((double) ((int) (g.green * 255.0)));
							bbb.adjustment.value = ((double) ((int) (g.blue * 255.0)));
							doupdate = true;
						}
					}
				}
			}
		});
		savebtn.clicked.connect (() =>  {
			if (scene.text != null) {
				if (scene.text.strip() != "") {
					print("savebtn.clicked.connect:\tsaving scenario: %s\n", scene.text);
					ind = 4;
					var dd = GLib.Environment.get_current_dir();
					string nn = (scene.text + ".scenario");
					string ff = Path.build_filename (dd, nn);
					File fff = File.new_for_path (ff);
					FileOutputStream oo = fff.replace (null, false, FileCreateFlags.PRIVATE);
					for (var u = 0; u < dat.length[0]; u++) {
						for (var g = 0; g < 13; g++) {
							string rr = dat[u,g];
							if (g < 12) { rr = ( rr + ";"); } 
							oo.write (rr.data);
						}
						oo.write("\n".data);
					}
					spop.popdown();
				}
			}
		});
		saveit.clicked.connect(() => {
			//spopbox.show_all();
			spop.show_all();
		});
		loadit.clicked.connect (() =>  {
			print("loadit.clicked.connect:\tfetching saved scenarios...\n");
			ind = 4;
			lpopbox.foreach ((element) => lpopbox.remove (element));
			var pth = GLib.Environment.get_current_dir();
			//print("current path is: %s\n", pth);
			GLib.Dir dcr = Dir.open (pth, 0);
			string? name = null;
			while ((name = dcr.read_name ()) != null) {
				//print("\tfound file: %s\n", name);
				var exts = name.split(".");
				if (exts.length == 2) {
					//print("\t\text[0]: %s\n", exts[0]);
					//print("\t\text[1]: %s\n", exts[1]);
					if (exts[1] == "scenario") {
						print("loadit.clicked: found scenario file: %s\n", name);
						Gtk.Button muh = new Gtk.Button.with_label (name);
						lpopbox.add(muh);
						muh.clicked.connect ((buh) => {
							var dd = GLib.Environment.get_current_dir();
							var nn = buh.label;
							string ff = Path.build_filename (dd, nn);
							//print("clicked %s\n", ff);
							var ss = FileStream.open(ff, "r");
							string tt = ss.read_line();
							if (tt != null) {
								print("    muh.clicked.connect:\tloading scenario: %s\n",nn);
								ind = 8;
								string[] oo = {};
								while (tt != null){
									oo += tt;
									tt = ss.read_line();
								}
								string[,] tdat = new string[oo.length,13];
								for (var r = 0; r < oo.length; r++) {
									//print("\treading line: %s\n", oo[r]);
									string[] rr = oo[r].split(";");
									//print("\t\tcsv column count is: %d\n", rr.length);
									while (rr.length < 13) { rr += ""; }
									if (rr.length == 13) {
										for (var c = 0; c < 13; c++) {
											tdat[r,c] = rr[c];
										}
									}
								}
								if (tdat.length[0] > 0) {
									dat = tdat;
									setuplist.foreach ((element) => setuplist.remove (element));
									for (var e = 0; e < dat.length[0]; e++) {
										//var ll = new Label(dat[e,10]);
										var ll = new Label("");
										ll.set_hexpand(true);
										ll.xalign = ((float) 0.0);
										var mqq = "".concat("<span color='#FFFFFF' font='monospace 16px'><b>", dat[e,10], "</b></span>");
										ll.set_markup(mqq);
										setuplist.insert(ll,-1);
									}
									setuplist.show_all();
									scene.text = exts[0];
									selectedrule = 0;
									row = setuplist.get_row_at_index(0);
									doupdate = false; setuplist.select_row(row); doupdate = true;
									selectarow (dat, setuplist, flowbox, evrcombo, nthcombo, wkdcombo, fdycombo, mthcombo, fmocombo, dsc, fye, amtf, grpcombo, catcombo, grpcolb, ind);
									forecasted = forecast(dat,forecastlistbox, iso.get_active(), 0, ind);
									graphimg.queue_draw ();
								}
							}
							lpop.popdown();
						});
					}
				}
			}
			lpopbox.show_all();
			lpop.show_all();
		});
		addrule.clicked.connect (() =>  {
			var s = setuplist.get_selected_row();
			var w = 0;
			var n = dat.length[0];
			if (s != null) {
				ind = 4;
				w = s.get_index();
				print("addrule.clicked.connect:\tadding new rule...\n");
				//print("selected row is %d\n", w);
				string[,] tdat = new string[(n+1),13];
				for (var r = 0; r < dat.length[0]; r++) {
					for (var c = 0; c < 13; c++) {
						tdat[r,c] = dat[r,c];
						//print("%s, ", tdat[r,c]);
					}
					//print("\n");
				}
				tdat[n,0] = "0";					//every nth
				tdat[n,1] = "1";					//day of month
				tdat[n,2] = "0";					//weekday
				tdat[n,3] = "0";					//from day
				tdat[n,4] = "1";					//of nth month
				tdat[n,5] = "0";					//from month
				tdat[n,6] = "0";					//from year
				tdat[n,7] = "10.0";					//amount
				tdat[n,8] = "cat1";					//category
				tdat[n,9] = "grp1";					//group
				tdat[n,10] = "new recurrence rule";	//description
				tdat[n,11] = textcolor();				//categorycolor
				tdat[n,12] = textcolor();				//groupcolor
				//print("new row populated: %s\n", tdat[n,10]);
				//for (var r = 0; r < tdat.length[0]; r++) {
				//	for (var c = 0; c < 11; c++) {
				//		print("%s, ", tdat[r,c]);
				//	}
				//	print("\n");
				//}
				dat = tdat;
				setuplist.foreach ((element) => setuplist.remove (element));
				for (var e = 0; e < dat.length[0]; e++) {
					//var ll = new Label(dat[e,10]);
					var ll = new Label("");
					ll.xalign = ((float) 0.0);
					var mqq = "".concat("<span font='monospace 16px'><b>", dat[e,10], "</b></span>");
					ll.set_markup(mqq);
					setuplist.insert(ll,-1);
				}
				setuplist.show_all();
				selectedrule = (dat.length[0] - 1);
				row = setuplist.get_row_at_index((dat.length[0] - 1));
				doupdate = false; setuplist.select_row(row); doupdate = true;
				selectarow (dat, setuplist, flowbox, evrcombo, nthcombo, wkdcombo, fdycombo, mthcombo, fmocombo, dsc, fye, amtf, grpcombo, catcombo, grpcolb, ind);
				forecasted = forecast(dat,forecastlistbox, iso.get_active(), (dat.length[0] - 1), ind);
				graphimg.queue_draw ();
			}
		});
		remrule.clicked.connect (() =>  {
			var s = setuplist.get_selected_row();
			var w = 0;
			var n = dat.length[0];
			if (s != null) {
				ind = 4;
				w = s.get_index();
				print("remrule.clicked.connect:\tremoving rule: %s\n",dat[w,9]);
				//print("selected row is %d\n", w);
				string[,] tdat = new string[(n-1),13];
				var i = 0;
				for (var r = 0; r < dat.length[0]; r++) {
					//print("r = %d, i = %d\n", r, i);
					if (r != w) {
						for (var c = 0; c < 13; c++) {
							tdat[i,c] = dat[r,c];
							//print("%s, ", tdat[r,c]);
						}
						i++;
						//print("\n");
					}
				}
				dat = tdat;
				setuplist.foreach ((element) => setuplist.remove (element));
				for (var e = 0; e < dat.length[0]; e++) {
					var ll = new Label(dat[e,10]);
					ll.xalign = ((float) 0.0);
					setuplist.insert(ll,-1);
				}
				setuplist.show_all();
				selectedrule = (dat.length[0] - 1);
				row = setuplist.get_row_at_index((dat.length[0] - 1));
				doupdate = false; setuplist.select_row(row); doupdate = true;
				selectarow (dat, setuplist, flowbox, evrcombo, nthcombo, wkdcombo, fdycombo, mthcombo, fmocombo, dsc, fye, amtf, grpcombo, catcombo, grpcolb, ind);
				forecasted = forecast(dat,forecastlistbox, iso.get_active(), (dat.length[0] - 1), ind);
				graphimg.queue_draw ();
			}
		});
	}
}
public void main(string[] args) {
	Gtk.init (ref args);
	var window = new FTW();
	window.show_all();
	Gtk.main();
}
