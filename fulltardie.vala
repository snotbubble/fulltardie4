// fulltardie
// forecast transactions that have heinously complex recurrence rules
// by c.p.brown 2016~2021
//
// 4th edition 2021
// using Vala for compatibility with mainline Linux on 64-bit Arm devices (futureproofing)
// added compactable ui for phones, expanded forecasting function capabilities
// tested OK on Linux 4.19.0-17-amd64, Xfce 4.14
// tested OK on Linux 5.10-sunxi64, Gnome 40.5
//
// minimal safety atm; can segfault under certain conditions
//
// TODO - oct 2021
// [X] = done, [!] = doing it, [~] = should do it but probably wont, [?] = stuck
// - [X] add amount field
// - [X] add group field
// - [X] add category field
// - [X] add year field
// - [X] do simple day counting when of-the-nth-month is 0
// - [X] move param pane to main grid
// - [X] fix group/category combobox behavior
// - [X] allow overwriting of existing scenarios
// - [X] add isolate toggle to parameters
// - [X] add padding to group and category in forecast list
// - [X] select forecast item selects creating rule
// - [X] replace activated (enter) events with change events - the program is fast enough to handle it :)
// - [X] replace scenario name on load
// - [X] fix date format
// - [X] block day counting if every-nth is zero; its picking up and counting single-date rules
// - [X] trigger list selection events when using keyboard
// - [X] find workaround to incorrect modulo (%) with negative numbers *** this is breaking long nth-month intervals ***
// - [!] change nth weekday counting to use 1st and nth
// - [ ] check screen size/dpi, move params to a popup if screen is above 150% scaling. phosh on pinephone is 200% by default!
//     - [ ] plain-english improvements (depends on dpi fix above):
//         - [ ] [every] [weekday closest to *every*] [nth *day*] [] [of nth month] []
//         - [ ] [every] [weekday closest to *every*] [nth *day*] [] [] [*from* month]
//         - [ ] [every] [weekday closest to *every*] [nth *day*] [*from the* fdy] [] [*from* month]
//         - [ ] [the] [weekday closest to *the*] [nth] [] [of nth month] []
//         - [ ] [every] [nth] [day] [] [] [*from* month]
//         - [ ] [the] [nth] [day] [] [] [*of* month]
//         - [ ] [every] [nth] [weekday] [*from the* fdy *occurence*] [of nth month] []
//         - [ ] [every] [nth] [weekday] [*from the* fdy *occurence*] [] [*from* nth month]
// - [ ] add changed asterisk to header bar title
// - [ ] find a way to make binaries truly standalone (they won't run when double-clicked in Ubuntu).
// - [!] automatic group/category color coding - I want a cvd.py style interface to the lists, with subtle color hints
//     - [!] conform group and category colors where they exist (one color per group/category), get 1st & propagate
//     - [X] generate group and categroy colors where they don't exist
//     - [ ] add a color swatch next to group & category params
//     - [ ] random regenerate colors on swatch event
//         - [ ] investigate double-tap and long-press events for swatch
//     - [ ] find a way to set listbox bg color
//     - [ ] find a way to set listbox row bg color that works with most gtk themes, or how to expand row label
// - [?] compact-left bottom row of params (hbgrp) while keeping the reflow behavior - might have to do it manually
// - [?] hunt down source of invalid-date warnings... checked date.valid() after every change and its all good, dunno where this is coming from
// - [?] find an elegant way to switch between pre-filtering and post-filtering when isolating - need a tri-state toggle
// - [?] fix the black-margin issue when scrollbars appear - only appears in certain gtk themes
// - [~] find an elegant way to handle every 90th and 91st day in alternating cycles (actual from a sydney utility company).
// - [~] remember forecast list selection
// moved to next month
// - [ ] drag'n'drop reorder setup rule list
// - [ ] move save/load to headerbar
// - [ ] add overwrite confirmation dialog
// - [ ] check for corrupt data in scenario files, in case they're manually edited
// - [ ] check for out-of range data when setting list/combo selections
// - [ ] add stacked bar graph
// - [ ] color code bar graph using group colors
// - [ ] add pan/zoom/reset to bar graph
// - [ ] adapt bar graph vertical/horizontal to container aspect-ratio
// - [ ] select bar to select rule
// - [ ] application icons

using Gtk;

// use to prevent event-loops
bool doupdate = true;

// true modulo from 'cdeerinck'
// https://stackoverflow.com/questions/41180292/negative-number-modulo-in-swift#41180619
int dmod (int l, int r) {
	if (l >= 0) { return (l % r); }
	if (l >= -r) { return (l + r); }
	return ((l % r) + r) % r;
}

// hsv to rgb function based on hsv-lab.r by Christopher Ross-Gill: http://www.rebol.org/view-script.r?script=hsv-lab.r
int[] hsvtorgb (float[] c) {
// hue = float 0.0 255.0
// val = float 0.0 1.0
// sat = float 0.0 1.0
	float r = 0;
	float g = 0;
	float b = 0;
	float h = c[0];
	float s = c[1];
	float v = c[2];
    if (s == 0.0) {
		r = v;
		g = v;
		b = v;
	} else {
		h = h / ((float) 60.0);
		int i = ((int) h);
		float f = h - ((float) i);
		float p = v * (1 - s);
		float q = v * (1 - (s * f));
		float t = v * (1 - (s * (1 - f)));
		switch (i) {
			case 0: r = v; g = t; b = p; break;
			case 1: r = q; g = v; b = p; break;
			case 2: r = p; g = v; b = t; break;
			case 3: r = p; g = q; b = v; break;
			case 4: r = t; g = p; b = v; break;
			default: r = v; g = p; b = q; break;
		}
	}
	int[] o = { ((int) (r * 255.0)), ((int) (g * 255.0)), ((int) (b * 255.0)) };
	return o;
}

struct nextdate {
	public Date nxd;
	public double amt;
	public string grp;
	public string cat;
	public string dsc;
	public int frm;
	public string cco;
	public string gco;
}

// check leapyear
bool lymd(int y) {
// technique is from Rosetta Code, most languages. 
	if ((y % 100) == 0 ) { 
		return ((y % 400) == 0);
	}
	return ((y % 4) == 0);
}

// get weekday index
int iwkd (DateWeekday wd) {
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
string htmlcol (int r, int g, int b) {
	 return ("#%02X%02X%02X".printf(r, g, b));
}


// forecast per item
nextdate[] findnextdate (string[] dt, int ownr) {
	print("\tfindnextdate started\n");
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
	if (dt[11].strip() == "") { oo.cco = "#FF0000"; }
	if (dt[12].strip() == "") { oo.gco = "#FF0000"; }
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

	var t = lymd(fye);
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
			if (ofm > 0) { dmo = (dmod((a.get_month() - fmo), ofm) == 0); }
			var ofmcalc = dmod((a.get_month() - fmo), ofm);
			//print("dmo calc: (%d - %d) = %d\n", a.get_month(), fmo, (a.get_month() - fmo));
			//print("dmo calc: ((%d - %d) mod %d) = %d\n", a.get_month(), fmo, ofm, ofmcalc);
			if (dmo) {
				var c = 0;
				var mth = md;
				t = lymd(a.get_year());
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
					if (iwkd(j.get_weekday()) == wkd) { wdc = wdc + 1; }
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
						if (iwkd(a.get_weekday()) == wkd) {
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
						if (iwkd(a.get_weekday()) > 5) {
// get weekday before, after or closest to a weekend day
							switch (wkd) {
								case 8: avd = (int) (d + (((( (iwkd(a.get_weekday()) - 5) - 1) / 1.0) * 2.0) - 1.0)); break;
								case 9: avd = d - (iwkd(a.get_weekday()) - 5); break;
								case 10: avd = d + (3 - (iwkd(a.get_weekday()) - 5)); break;
								default: avd = d; break;
							}
						}
// is the matching date on or after today?
						a.set_day((DateDay) avd);
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
			var c = 0;
			for (int x = 0; x < dif; x++) {
				if (a.compare(n) >= 0) {
// simple day count
					if (wkd == 0 || wkd > 7) {
						if ((x % (cnth * cofs)) == 0) {
							if (iwkd(a.get_weekday()) > 5) {
								var d = (int) a.get_day();
								var avd = d;
// get weekday before, after or closest to a weekend as required
								switch (wkd) {
									case 8: avd = (int) (d + (((( (iwkd(a.get_weekday()) - 5) - 1) / 1.0) * 2.0) - 1.0)); break;
									case 9: avd = d - (iwkd(a.get_weekday()) - 5); break;
									case 10: avd = d + (3 - (iwkd(a.get_weekday()) - 5)); break;
									default: avd = d; break;
								}
								a.set_day((DateDay) avd);
								if (a.valid() == false) { print("invalid day-count avd date\n"); }
							}
							//print("a.day: %d, a.month: %d, a.year: %d\n", ((int) a.get_day()), ((int) a.get_month()), ((int) a.get_year()));
							oo.nxd = a; 
							o += oo;
						}
// get nth weekday
					} else {
						if (iwkd(a.get_weekday()) == wkd) {
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
	print("\tfindnextdate completed\n");
	return o;
}

// forecast everything in dat and render it
void forecast (string[,] d, Gtk.ListBox w, bool iso, int srow) {
	print("forecast started\n");
// gtk widget clearing one-liner posted by Evan Nemerson: https://stackoverflow.com/questions/36215425/vala-how-do-you-delete-all-the-children-of-a-gtk-container
	w.foreach ((element) => w.remove (element));
	string[] forecasted = {};

// pad lengths: date, group, category, amount, description

	int[] sls = {8,0,0,0,0};

// get forecasts

	nextdate[] fdat = {};
	if (iso) {
		string[] datrow = {};
		for (var g = 0; g < 13; g++) { datrow += d[srow,g]; }
		var rfc = findnextdate (datrow, srow);
		for (var f = 0; f < rfc.length; f++ ) { fdat += rfc[f]; }
	} else {
		for (var u = 0; u < d.length[0]; u++) {
			string[] datrow = {};
			for (var g = 0; g < 13; g++) { datrow += d[u,g]; }
			var rfc = findnextdate (datrow, u);
			for (var f = 0; f < rfc.length; f++ ) { fdat += rfc[f]; }
		}
	}

// get pad lengths

	for (var u = 0; u < fdat.length; u++) {
		var aml = ("%.2lf").printf(fdat[u].amt);
		if (sls[1] < fdat[u].grp.length) { sls[1] = fdat[u].grp.length; }
		if (sls[2] < fdat[u].cat.length) { sls[2] = fdat[u].cat.length; }
		if (sls[3] < aml.length) { sls[3] = aml.length; }
		if (sls[4] < fdat[u].dsc.length) { sls[4] = fdat[u].dsc.length; }
	}

// padding strings, appending the owner int to post-process after

	for (var u = 0; u < fdat.length; u++) {
		var rfd = fdat[u];
		var ch = new char[9];
		rfd.nxd.strftime(ch,"%y %m %d");
		string txt = "";
		string amt = ("%" + sls[3].to_string() + ".2lf").printf(rfd.amt);
		//string sgp = ("%-" + sls[1].to_string() + "s").printf(rfd.grp);
		string sct = ("%-" + sls[2].to_string() + "s").printf(rfd.cat);
		string sds = ("%-" + sls[4].to_string() + "s").printf(rfd.dsc);
		txt = ((string) ch) + " : " + sct + " : " + amt + " : " + sds + ";" + (("%d").printf(rfd.frm)) + ";" + rfd.cco + ";" + rfd.gco;
		forecasted += txt;
		//print("assembling raw forecast row: %s\n", txt);
	}

// sorting a string before post-processing
// this is a stupid workaround to vala's basic array handling

	GLib.qsort_with_data<string> (forecasted, sizeof(string), (a, b) => GLib.strcmp (a, b));
	double rut = 0.0;
	for (var r = 0; r < forecasted.length; r++) {
		if (forecasted[r] != null || forecasted[r].length > 0) {
			string[] subs = forecasted[r].split(":");
			var amtnum = subs[2].strip();
			if (amtnum != null || amtnum.length > 0) {
				rut = rut + double.parse(amtnum);
			}
			var lbl = new Label("");
			lbl.xalign = ((float) 0.0);
			string[] fsb = forecasted[r].split(";");
			lbl.set_tooltip_text(fsb[1]);
			var mqq = "".concat("<span color='", fsb[3], "' font='monospace 12px'><b>", fsb[0].concat(" : ", ("%.2lf").printf(rut)), "</b></span>");
			lbl.set_markup(mqq);
			w.add(lbl);
		}
	}
	w.show_all();
	print("forecast completed\n");
}

// gather unique group/category names
string[] getchoicelist(string[,] d, int idx) {
	doupdate = false;
	var doit = true;
	string[] o = {};
	string[] c = {};
	int[] q = {};
	for (var r = 0; r < d.length[0]; r++) {
// can't find an equavalent of: if not x in y: y.append(x)
// doing it manually:
		doit = true;
		if (o.length > 0) {
			for (var i = 0; i < o.length; i++) {
				if (o[i] == d[r,idx]) {
					doit = false; break;
				}
			}
		}
		if (doit) {
			//print("collecting unique list item: %s\n", d[r,idx]);
			o += d[r,idx];
			q += r;
		}
	}
// get/set colors per found gtoup/category
	for (var r = 0; r < o.length; r++) {
		Random.set_seed(r);
		int cidx = idx + 3;
		if (d[q[r],cidx].strip() == "") {
			float[] hh = { ((((float) r) / ((float) o.length)) * ((float) 255.0)), ((float) 0.8), ((float) 0.8) };
			int[] clr = hsvtorgb(hh);
			string gg = htmlcol(clr[0], clr[1], clr[2]);
			d[q[r],cidx] = gg;
			c += gg;
		} else {
			c += d[q[r],cidx];
		}
	}
	if (o.length == 0) { o += "none"; }
	//doupdate = true;
	//print("\n");
	return o;
}

// select a row, update params accordingly
void selectarow (string[,] dat, Gtk.ListBoxRow row, Gtk.FlowBox fb, Gtk.ComboBoxText evrc, Gtk.ComboBoxText nthc, Gtk.ComboBoxText wkdc, Gtk.ComboBoxText fdyc, Gtk.ComboBoxText mthc, Gtk.ComboBoxText fmoc, Gtk.Entry dsct, Gtk.SpinButton fyes, Gtk.SpinButton amts, Gtk.ComboBoxText grpc, Gtk.ComboBoxText catc) {
	doupdate = false;
	var i = row.get_index();
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
	string[] cc = getchoicelist(dat, 8);
	//print("\tselected row data is: %s %s %s\n", dat[i,8], dat[i,9], dat[i,10]);
	catc.remove_all();
	for (var j = 0; j < cc.length; j++) {
		catc.append_text(cc[j]);
		if (cc[j] == dat[i,8]) { catc.set_active(j); }
	}
// there is no comboboxtext.itmes array, so hosing & rebuilding it
	string[] gg = getchoicelist(dat, 9);
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
// refresh colors
	string clr = dat[i,12];
	if (dat[i,12].strip() == "") { clr = "#FF0000"; }
// apply markup to label
	var mqq = "".concat("<span color='", clr, "' font='monospace 16px'><b>", dat[i,10], "</b></span>");
	var rl = (Label) row.get_child();
	rl.set_markup(mqq);
	doupdate = true;
}

//    gggg uu  uu iiiiii
//  gg     uu  uu   ii
//  gg  gg uu  uu   ii
//  gg  gg uu  uu   ii
//    gggg   uuuu iiiiii

public class FTW : Window {
	private Notebook notebook;
	private ListBox setuplist;
	//private ListBox forecastlistbox;
	private Popover spop;
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

	public FTW() {

// add widgets

		doupdate = false;
		this.title = "fulltardie";
		this.set_default_size(720, 500);
		this.destroy.connect(Gtk.main_quit);
		this.border_width = 10;
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
		Gtk.ActionBar abar = new ActionBar();

// load menu

		Gtk.Button loadit = new Button();
		loadit.set_label("load");
		spop = new Gtk.Popover (loadit);
		Gtk.Box spopbox = new Gtk.Box (VERTICAL,2);
		spop.add(spopbox);

// scenario name

		Gtk.Entry scene = new Entry();
		scene.text = "default";

// save scenario

		Gtk.Button saveit = new Button.with_label("save");
// button needs a container to set its size :(
		//saveit.width = 200;

// populate action bar

// hexpand & fill seem to be busted for actionbar, was fixed for headerbar though
// leaving scene field on the left side for now

		abar.pack_end(loadit);
		abar.pack_start(saveit);
		abar.pack_start(scene);

// setup page

		var setuppage = new ScrolledWindow(null, null);
		for (var e = 0; e < dat.length[0]; e++) {
			//var ll = new Label(dat[e,10]);
			var ll = new Label("");
			ll.xalign = ((float) 0.0);
// color test
			string clr = dat[e,12];
			if (dat[e,12].strip() == "") { clr = "#FF0000"; }
// apply markup to label
			var mqq = "".concat("<span color='", clr, "' font='monospace 16px'><b>", dat[e,10], "</b></span>");
			//var mqq = "".concat("<span font='monospace 16px'><b>", dat[e,10], "</b></span>");
			ll.set_markup(mqq);
			setuplist.insert(ll,-1);
		}
		setuplist.set_selection_mode(SINGLE);
		setuplist.margin = 10;
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
		uig.attach(abar, 0, 2, 1, 1);
		this.add(uig);

// foecast page

		var forecastpage = new ScrolledWindow(null, null);
		var forecastlistbox = new ListBox();
		for (var i = 1; i < 10; i++) {
			string text = @"Label $i";
			var labele = new Label(text);
			forecastlistbox.add(labele);
		}
		forecastlistbox.margin = 10;
		forecastpage.add(forecastlistbox);
		var label2 = new Label(null);
		label2.set_markup("<b><big>setup</big></b>");
		var label3 = new Label(null);
		label3.set_markup("<b><big>forecast</big></b>");
		notebook.append_page(setuppage, label2);
		notebook.append_page(forecastpage, label3);

// select row
		var row = setuplist.get_row_at_index(0);
		selectarow (dat, row, flowbox, evrcombo, nthcombo, wkdcombo, fdycombo, mthcombo, fmocombo, dsc, fye, amtf, grpcombo, catcombo);
		doupdate = true;

//  eeeeee vv  vv eeeeee nnnn   tttttt   ssss
//  ee     vv  vv ee     nn  nn   tt   ss
//  eeee   vv  vv eeee   nn  nn   tt     ss
//  ee     vv  vv ee     nn  nn   tt       ss
//  eeeeee   vv   eeeeee nn  nn   tt   ssss

//tab panel selection action

		notebook.switch_page.connect ((page, page_num) => {
			var s = setuplist.get_selected_row();
			var r = 0;
			if (s != null) { r = s.get_index(); }
			forecast(dat,forecastlistbox, iso.get_active(), r);
		});

// setup list item select action

		setuplist.row_selected.connect ((row) => {
			if (doupdate) {
				selectarow (dat, row, flowbox, evrcombo, nthcombo, wkdcombo, fdycombo, mthcombo, fmocombo, dsc, fye, amtf, grpcombo, catcombo);
			}
		});

// forecast list item double-click to get creating rule

		forecastlistbox.row_activated.connect ((row) => {
			if (doupdate) {
				var fs = forecastlistbox.get_selected_row();
				var fr = 0;
				if (fs != null) {
					fr = fs.get_index();
					var ll = (Label) row.get_child();
					//print("selected forecast row label tooltip: %s\n", ll.tooltip_text);
					if (ll.tooltip_text != null) {
						var own = int.parse(ll.tooltip_text);
						row = setuplist.get_row_at_index(own);
						doupdate = false; setuplist.select_row(row); doupdate = true;
						selectarow (dat, row, flowbox, evrcombo, nthcombo, wkdcombo, fdycombo, mthcombo, fmocombo, dsc, fye, amtf, grpcombo, catcombo);
					}
				}
			}
		});

// setup data lists changed

		evrcombo.changed.connect(() => {
			if (doupdate) {
				var n = evrcombo.get_active();
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) { 
					r = s.get_index(); 
					dat[r,0] = n.to_string();
					forecast(dat,forecastlistbox, iso.get_active(), r);
					//print ( "evrcombo.changed: dat[%d,%d] = %s\n", r, 0, dat[r,0]);
				}
			}
		});
		nthcombo.changed.connect(() => {
			if (doupdate) {
				var n = nthcombo.get_active();
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) { 
					r = s.get_index();
					dat[r,1] = n.to_string();
					forecast(dat,forecastlistbox, iso.get_active(), r);
					//print ( "dat[%d,%d] = %s\n", r, 0, dat[r,1]);
				}
			}
		});
		wkdcombo.changed.connect(() => {
			if (doupdate) {
				var n = wkdcombo.get_active();
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) { 
					r = s.get_index();
					dat[r,2] = n.to_string();
					//print ( "wkdcombo.changed: dat[%d,%d] = %s\n", r, 0, dat[r,2]);
					var ffs = int.parse(dat[r,2]);
					if (ffs > 7) {
						//print("weekday rule selected, re-arrainging flowbox...\n");
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
					forecast(dat,forecastlistbox, iso.get_active(), r);
				}
			}
		});
		fdycombo.changed.connect(() => {
			if (doupdate) {
				var n = fdycombo.get_active();
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) { 
					r = s.get_index();
					dat[r,3] = n.to_string();
					forecast(dat,forecastlistbox, iso.get_active(), r);
					//print ( "dat[%d,%d] = %s\n", r, 0, dat[r,3]);
				}
			}
		});
		mthcombo.changed.connect(() => {
			if (doupdate) {
				var n = mthcombo.get_active();
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) { 
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
					forecast(dat,forecastlistbox, iso.get_active(), r);
					//print ( "dat[%d,%d] = %s\n", r, 0, dat[r,4]);
				}
			}
		});
		fmocombo.changed.connect(() => {
			if (doupdate) {
				var n = fmocombo.get_active();
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) {
					r = s.get_index();
					dat[r,5] = n.to_string();
					forecast(dat,forecastlistbox, iso.get_active(), r);
					//print ( "dat[%d,%d] = %s\n", r, 0, dat[r,5]);
				}
			}
		});
		fye.changed.connect(() => {
			if (doupdate) {
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) { 
					r = s.get_index();
					if (fye.get_value() == ((int) (GLib.get_real_time() / 31557600000000) + 1970)) {
						dat[r,6] = "0";
					} else {
						dat[r,6] = ((string) ("%lf").printf(fye.get_value()));
					}
					forecast(dat,forecastlistbox, iso.get_active(), r);
				}
			}
		});
		grpcombo.changed.connect(() => {
			if (doupdate) {
				var n = grpcombo.get_active_text();
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) { 
					r = s.get_index();
					dat[r,9] = n;
					forecast(dat,forecastlistbox, iso.get_active(), r);
				}
			}
		});
		catcombo.changed.connect(() => {
			if (doupdate) {
				var n = catcombo.get_active_text();
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) { 
					r = s.get_index();
					dat[r,8] = n;
					forecast(dat,forecastlistbox, iso.get_active(), r);
				}
			}
		});
		ee = (Entry) catcombo.get_child();
		ee.activate.connect(() => {
			if (doupdate) {
				var n = ee.text;
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) { 
					r = s.get_index();
					dat[r,8] = n;
					string[] cc = getchoicelist(dat,8);
					catcombo.remove_all();
					for (var j = 0; j < cc.length; j++) {
						catcombo.append_text(cc[j]);
						if (cc[j] == n) { r = j; }
					}
					catcombo.set_active(r);
					forecast(dat,forecastlistbox, iso.get_active(), r);
					//print("category text entered: %s\n", ee.text );
					doupdate = true;
				}
			}
		});
		vv = (Entry) grpcombo.get_child();
		vv.activate.connect(() => {
			if (doupdate) {
				var n = vv.text;
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) { 
					r = s.get_index();
					dat[r,9] = n;
					string[] cc = getchoicelist(dat,9);
					grpcombo.remove_all();
					for (var j = 0; j < cc.length; j++) {
						grpcombo.append_text(cc[j]);
						if (cc[j] == n) { r = j; }
					}
					grpcombo.set_active(r);
					forecast(dat,forecastlistbox, iso.get_active(), r);
					doupdate = true;
				}
			}
		});
		amtf.value_changed.connect(() => {
			if (doupdate) {
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) { r = s.get_index(); }
				dat[r,7] =((string) ("%.2lf").printf(amtf.get_value()));;
				forecast(dat,forecastlistbox, iso.get_active(), r);
			}
		});
		iso.toggled.connect(() => {
			if (doupdate) {
				var s = setuplist.get_selected_row();
				var r = 0;
				if (s != null) { 
					r = s.get_index();
					forecast(dat,forecastlistbox, iso.get_active(), r);
				}
			}
		});

// rename rule is just rebulding the list, since getting at listboxname/row[x]/labelname/text is a fucking nightmare of OOP shitfuckery

		dsc.changed.connect(() => {
			if (doupdate) {
				if (dsc.text != null) {
					if (dsc.text.strip() != "") {
						var s = setuplist.get_selected_row();
						var r = 0;
						if (s != null) {
							r = s.get_index();
							dat[r,10] = dsc.text;
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
							row = setuplist.get_row_at_index(r);
							//print("attempting to select row at index %d...\n", r);
							doupdate = false; setuplist.select_row(row); doupdate = true;
							forecast(dat,forecastlistbox, iso.get_active(), r);
						}
					}
				}
			}
		});
		loadit.clicked.connect (() =>  {
			spop.show_all ();
		});
		saveit.clicked.connect (() =>  {
			if (scene.text != null) {
				if (scene.text.strip() != "") {
					var dd = GLib.Environment.get_current_dir();
					string nn = (scene.text + ".scenario");
					string ff = Path.build_filename (dd, nn);
					File fff = File.new_for_path (ff);
					FileOutputStream oo = fff.replace (null, false, FileCreateFlags.PRIVATE);
					for (var u = 0; u < dat.length[0]; u++) {
						for (var g = 0; g < 11; g++) {
							string rr = dat[u,g];
							if (g < 12) { rr = ( rr + ";"); } 
							oo.write (rr.data);
						}
						oo.write("\n".data);
					}
				}
			}
		});
		loadit.clicked.connect (() =>  {
			spopbox.foreach ((element) => spopbox.remove (element));
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
						//print("\t\tfound scenario file: %s\n", name);
						Gtk.Button muh = new Gtk.Button.with_label (name);
						spopbox.add(muh);
						muh.clicked.connect ((buh) => {
							var dd = GLib.Environment.get_current_dir();
							var nn = buh.label;
							string ff = Path.build_filename (dd, nn);
							//print("clicked %s\n", ff);
							var ss = FileStream.open(ff, "r");
							string tt = ss.read_line();
							if (tt != null) {
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
										string clr = dat[e,12];
										if (dat[e,12].strip() == "") { clr = "#FF0000"; }
										var mqq = "".concat("<span background='", clr, "' font='monospace 16px'><b>", dat[e,10], "</b></span>");
										ll.set_markup(mqq);
										setuplist.insert(ll,-1);
									}
									setuplist.show_all();
									scene.text = exts[0];
									row = setuplist.get_row_at_index(0);
									doupdate = false; setuplist.select_row(row); doupdate = true;
									selectarow (dat, row, flowbox, evrcombo, nthcombo, wkdcombo, fdycombo, mthcombo, fmocombo, dsc, fye, amtf, grpcombo, catcombo);
									forecast(dat,forecastlistbox, iso.get_active(), 0);
								}
							}
							spop.popdown();
						});
					}
				}
			}
			spopbox.show_all();
		});
		addrule.clicked.connect (() =>  {
			var s = setuplist.get_selected_row();
			var w = 0;
			var n = dat.length[0];
			if (s != null) {
				w = s.get_index();
				//print("selected row is %d\n", w);
				string[,] tdat = new string[(n+1),11];
				for (var r = 0; r < dat.length[0]; r++) {
					for (var c = 0; c < 11; c++) {
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
				tdat[n,11] = "#FFFFFF";				//categorycolor
				tdat[n,12] = "#FFFFFF";				//groupcolor
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
				row = setuplist.get_row_at_index((dat.length[0] - 1));
				doupdate = false; setuplist.select_row(row); doupdate = true;
				selectarow (dat, row, flowbox, evrcombo, nthcombo, wkdcombo, fdycombo, mthcombo, fmocombo, dsc, fye, amtf, grpcombo, catcombo);
				forecast(dat,forecastlistbox, iso.get_active(), (dat.length[0] - 1));
			}
		});
		remrule.clicked.connect (() =>  {
			var s = setuplist.get_selected_row();
			var w = 0;
			var n = dat.length[0];
			if (s != null) {
				w = s.get_index();
				//print("selected row is %d\n", w);
				string[,] tdat = new string[(n-1),11];
				var i = 0;
				for (var r = 0; r < dat.length[0]; r++) {
					//print("r = %d, i = %d\n", r, i);
					if (r != w) {
						for (var c = 0; c < 11; c++) {
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
				row = setuplist.get_row_at_index((dat.length[0] - 1));
				doupdate = false; setuplist.select_row(row); doupdate = true;
				selectarow (dat, row, flowbox, evrcombo, nthcombo, wkdcombo, fdycombo, mthcombo, fmocombo, dsc, fye, amtf, grpcombo, catcombo);
				forecast(dat,forecastlistbox, iso.get_active(), (dat.length[0] - 1));
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
