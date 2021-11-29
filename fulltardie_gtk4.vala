// gtk4 translation
// by c.p.brown 2021
//
// translation status:
// found a new (?) segfault while testing date params
// currently can't get-at window size to adapt parameter pane height
// css selection background color in the setup-list is misbehaving
// graph interaction using new event system is incomplete
// group selection doesn't update color params
// haven't yet found a way to set date combo list column count
// save is working, load is busted
// probably some variable re-use issues now that events can see them
// changing color sliders is laggy while viewing forecast view (probably the stupid css round-tripping)
// slider widths needs to be capped
// ...
// the insane cssprovider shitfuckery WILL be hosed once I figure out how to bypass it
// presently every row may require its own:
//    cssprovider
//    csstext
//    load_data
//    add_provider
//    add_class 
//    add_class :selected
// and there can potentially be thousands of rows, all being re-rendered interactively
// last resort will be to make the lists with cairo... might even be faster
//
// compiles and runs OK on x86_64 linux
// compiles and runs on arm_64 (pinephone) but the display colors are busted atm

using Gtk;

bool doupdate = false;

// vala is super fussy about where variables are written, so these have to be functions...
string textcolor () { return "#55BDFF"; }
string rowcolor () { return "#1A3B4F"; }
string ttcolor () { return "#112633"; }

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

// modulo from 'cdeerinck'
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
	var n = Date();
	n.set_dmy((DateDay) ntd, ntm, (DateYear) nty);
	if (n.valid() == false) { print("invalid now date: %d %d %d\n", nty, ntm, ntd); }
	nextdate[] o = {};
	var oo = nextdate();
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
	var a = Date();
	a.set_dmy((DateDay) ntd, fmo, (DateYear) fye);
	if (a.valid() == false) { print("invalid initial start date: %d %d %d\n", fye, fmo, ntd); }
	var j =  Date();
	j.set_dmy((DateDay) ntd, fmo, (DateYear) fye);
	var dif = (int) (((a.days_between(n) / 7.0) / 52.0) * 12.0) + 13;
	if (ofm > 0) {
		for (int x = 0; x < dif; x++) {
			var dmo = (a.get_month() == fmo);
			if (ofm > 0) { dmo = (dmod((a.get_month() - fmo), ofm, nind) == 0); }
			var ofmcalc = dmod((a.get_month() - fmo), ofm, nind);
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

// get nearest weekday if avd is out of bounds

							if (avd < 1 || avd > md) { avd = d + (3 - (iwkd(a.get_weekday(),nind) - 5)); }

// clamp it anyway, just in case...

							avd = int.min(md,int.max(1,avd));
						}

// is the matching date on or after today?

						a.set_day((DateDay) avd);
						if (a.valid() == false) { print("invalid avd date generated by rule [%d] (%s):\nevery: %s\nnth: %s\nweekday: %s\nfromday: %s\nofmonth: %s\nfrommonth: %s\nfromyear: %s\n\n", ownr, dt[10], dt[0], dt[1], dt[2], dt[3], dt[4], dt[5], dt[6]); }
						if (a.compare(n) >= 0) {
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
			if (a.valid() == false) { print("invalid month incrament date\n"); }
		}

// we're day-counting... this is more expensive so its handled as a special case

	} else {
		if (fdy > 0) { 
			a.set_dmy((DateDay) fdy, fmo, (DateYear) fye);
			if (a.valid() == false) { print("invalid day-count initialized fdy date\n"); }
		}
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
								if (a.valid() == false) { print("invalid day-count avd date\n"); }
							}
							oo.nxd = a; 
							o += oo;
						}

// get nth weekday

					} else {
						if (iwkd(a.get_weekday(),nind) == wkd) {
							c = c + 1;
							if (((c - fdy) % (cnth * cofs)) == 0) {
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
				if (a.compare(n) >= 0) {
					oo.nxd = a;
					o += oo;
				} else {

// the date has passed, add a year

					a.set_dmy((DateDay) nth, fmo, (DateYear) (fye + 1));
					oo.nxd = a;
					o += oo;
				}
			} else {

// this should only appear with zeroed rules, like initial balances. returns today

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
			//print("%srenderforecast:\tforecasted.length[0] = %d\n", tabni, f.length[0]);
			//print("%srenderforecast:\tforecasted.length[1] = %d\n", tabni, f.length[1]);

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
					rl.set_markup(mqq);
					var g = Gdk.RGBA();
					if (g.parse(clr)) {

// OOP shitfuckery time
// this replaces row.override_background from gtk3...

						var forecastrowcssprovider = new Gtk.CssProvider();
						string forecastrownormalcsstxt = ".likewut { color: %s; background: rgba(%d,%d,%d,0.1); }".printf(clr,((int) (g.red*255.0)), ((int) (g.green*255.0)), ((int) (g.blue*255.0)));
						forecastrownormalcsstxt = forecastrownormalcsstxt.concat("\n.likewut:selected { color:", clr, "; background: ", textcolor(), "; }");
						forecastrowcssprovider.load_from_data (forecastrownormalcsstxt.data);
						row.get_style_context().add_provider(forecastrowcssprovider, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
						row.get_style_context().add_class("likewut");
						row.get_style_context().add_class("likewut:selected");
						string tabx = ("%-" + (ind + 8).to_string() + "s").printf("");
						//print("%srenderforecast:\tlist row style is:\n%s%s\n", tabni, tabx, (row.get_style_context().to_string(NONE)));
					}
				} else {
					print("%srenderforecast:\tforecast list is out of sync with forecasted data at row: %d\n", tabni, r);
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
	}

// sorting

	GLib.qsort_with_data<string> (rendered, sizeof(string), (a, b) => GLib.strcmp (a, b));
	double rut = 0.0;

// fcdat = date, description, amount, cat, group, runningtotal, catcolor, groupcolor, owner

	string[,] fcdat = new string[rendered.length,9];

// clearing the list (gtk3)
//	w.foreach ((element) => w.remove (element));

// clearing the list (gtk4)
	while (w.get_first_child() != null) {
		print("%sforecast:\tremoving old list item...\n", tabi);
  		w.remove(w.get_first_child());
	}

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
			w.insert(lbl,r);
		}
	}
	w.show();
	renderforecast(fcdat,w, nind);
	print("%sforecast done\n",tabi);
	return fcdat;
}

void rendersetuplist(string[,] d, int sr, Gtk.ListBox b, int ind) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	print("%srendersetuplist started...\n",tabi);
	var tabni = ("%-" + (ind + 4).to_string() + "s").printf("");
	var bsr = b.get_selected_row();
	var bsi = bsr.get_index();
	print("%srendersetuplist:\tselected rule is %d\n",tabni, sr);
	print("%srendersetuplist:\tselected row is %d\n",tabni, bsi);
	for (var s = 0; s < d.length[0]; s++) {
		var row = b.get_row_at_index(s);
		string clr = d[s,12];
		if (clr.strip() == "") { clr = textcolor(); }
		if (sr == s) { clr = rowcolor(); }
		var mqq = "".concat("<span color='", clr, "' font='monospace 16px'><b>", d[s,10], "</b></span>");
		var rl = (Label) row.get_child();
		rl.set_markup(mqq);
		var g = Gdk.RGBA();
		if (g.parse(clr)) {

// brace yourselves for the modern (Placement p = new Placement; p = OVER; Position o = new position; o.placement = p; thinking.set_position(o)) programming style...	

			var rowcssprovider = new Gtk.CssProvider();
			string rownormalcsstxt = ".wut { color: %s; background: rgba(%d,%d,%d,0.1); }".printf(clr,((int) (g.red*255.0)), ((int) (g.green*255.0)), ((int) (g.blue*255.0)));
			rownormalcsstxt = rownormalcsstxt.concat("\n.wut:selected { color:", clr, "; background: ", textcolor(), "; }");
			rowcssprovider.load_from_data (rownormalcsstxt.data);
			row.get_style_context().add_provider(rowcssprovider, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
			row.get_style_context().add_class("wut");
			row.get_style_context().add_class("wut:selected");
			//string tabx = ("%-" + (ind + 8).to_string() + "s").printf("");
			//print("%srendersetuplist:\tlist row style is:\n%s%s\n", tabni, tabx, (row.get_style_context().to_string(NONE)));

// the avove slab of shitfuckery used to be : row.override_background_color(NORMAL, g);
		}
	}
	print("%srendersetuplist completed.\n", tabi);
}

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
		if (d[r,cidx].strip() == "") {
			if (cidx == 11) { d[r,cidx] = textcolor(); }
			if (cidx == 12) { d[r,cidx] = textcolor(); }
		}
	}
	if (o.length == 0) { o += "none"; }
	doupdate = whatupdate;
	print("%sgetchoicelist completed.\n", tabi);
	return o;
}

void adjustgroupcolor (string[,] d, string[,] f, Gtk.ToggleButton t, Gtk.CssProvider csp, int e, Entry h, double r, double g, double b, bool x, int ind) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	print("%sadjustgroupcolor started...\n",tabi);
	var nind = ind + 4;

// data, setuplist, hex-entry, red slider val, green slider val, blue slider val, do hex-entry

	string hx = htmlcol (((int) r), ((int) g), ((int) b), nind);
	if (x) { hx = h.text; }
	var c = Gdk.RGBA();
	if (c.parse(hx) == false) { hx = textcolor(); c.parse(hx); }
	if (x == false) { doupdate = false; h.text = hx; doupdate = true; }
	string colcsstxt = ".col { background: %s%s; }".printf(hx,"11");
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
		if (t.get_active()) {	
			colcsstxt = ".col { background: %s%s; }".printf(hx,"FF");
		}
	}
	csp.load_from_data (colcsstxt.data);
}

void selectarow (string[,] dat, int i, Gtk.ListBox b, Gtk.FlowBox fb, Gtk.ComboBoxText evrc, Gtk.ComboBoxText nthc, Gtk.ComboBoxText wkdc, Gtk.ComboBoxText fdyc, Gtk.ComboBoxText mthc, Gtk.ComboBoxText fmoc, Gtk.Entry dsct, Gtk.SpinButton fyes, Gtk.SpinButton amts, Gtk.ComboBoxText grpc, Gtk.ComboBoxText catc, Gtk.ToggleButton gcb, Gtk.CssProvider csp, Gtk.Scale rrr, Gtk.Scale ggg, Gtk.Scale bbb, Gtk.Entry hhh, Gtk.Box gcx, int ind) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	print("%sselectarow started...\n",tabi);
	var nind = ind + 4;
	var tabni = ("%-" + nind.to_string() + "s").printf("");
	print("%sselectarow:\tselected rule is %d\n",tabni,i);
	var bsr = b.get_selected_row();
	var bsi = bsr.get_index();
	print("%sselectarow:\tcurrent selected row is %d\n",tabni,bsi);
	doupdate = false;
	string[] fmo = {"from this month", "from january", "from february", "from march", "from april", "from may", "from june", "from july", "from august", "from september", "from october", "from november", "from december"};
	string[] omo = {"of this month", "of january", "of february", "of march", "of april", "of may", "of june", "of july", "of august", "of september", "of october", "of november", "of december"};
	var ffs = int.parse(dat[i,2]);
// note: remove shrinks the child count instead of clearing it, so remove 1 & remove 1 is the same as remove 1 & remove 2 in gtk3
	if (ffs > 7) {
		if (fb.get_child_at_index(1).get_child() == nthc) {
			fb.remove(fb.get_child_at_index(1));
			fb.remove(fb.get_child_at_index(1));
			fb.insert(wkdc,1);
			fb.insert(nthc,2);
		}
	} else {
		if (fb.get_child_at_index(1).get_child() == wkdc) {
			fb.remove(fb.get_child_at_index(1));
			fb.remove(fb.get_child_at_index(1));
			fb.insert(nthc,1);
			fb.insert(wkdc,2);
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
	string[] cc = getchoicelist(dat, 8, nind);
	catc.remove_all();
	for (var j = 0; j < cc.length; j++) {
		catc.append_text(cc[j]);
		if (cc[j] == dat[i,8]) { catc.set_active(j); }
	}
	string[] gg = getchoicelist(dat, 9, nind);
	grpc.remove_all();
	for (var k = 0; k < gg.length; k++) {
		grpc.append_text(gg[k]);
	}
	for (var k = 0; k < gg.length; k++) {
		if (gg[k] == dat[i,9]) { grpc.set_active(k); break; }
	}
	amts.set_value( double.parse(dat[i,7]) );
	var clr = dat[i,12];
	var g = Gdk.RGBA();
	if (g.parse(clr) == false) { clr = textcolor(); g.parse(clr); }
	string colcsstxt = ".col { background: %s%s; }".printf(clr,"FF");
	if (gcb.get_active()) {	
		hhh.text = clr;
		rrr.adjustment.value = ((double) ((int) (g.red * 255.0)));
		ggg.adjustment.value = ((double) ((int) (g.green * 255.0)));
		bbb.adjustment.value = ((double) ((int) (g.blue * 255.0)));
		gcx.visible = true;
	} else {
		colcsstxt = ".col { background: %s%s; }".printf(clr,"55");
		gcx.visible = false;
	}
	csp.load_from_data (colcsstxt.data);
	rendersetuplist(dat, i, b, nind);
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

////////////////////////////////////////////////////////////////////////
//                                                                    //
//    GGGGGGGGGGGGGGGGGG    UUUUUU        UUUU    IIIIIIIIIIIIIIII    //
//    GGGGGG                UUUUUU        UUUU         IIIIII         //
//    GGGGGG    GGGGGGGG    UUUUUU        UUUU         IIIIII         //
//    GGGGGG        GGGG    UUUUUU        UUUU         IIIIII         //
//    GGGGGGGGGGGGGGGGGG    UUUUUUUUUUUUUUUUUU    IIIIIIIIIIIIIIII    //
//                                                                    //
////////////////////////////////////////////////////////////////////////

//public class FTW : Window {
public class fulltardie : Gtk.Application {

}

public class FTW : Gtk.ApplicationWindow {

	string[,] dat = {
		{"1","0","7","0","1","7","0","-5.00","cat1","group1","every sunday of every month starting from this september","",""},
		{"1","14","0","21","0","5","2021","200.0","cat2","group2","every 14th day from the 21st of May 2021","",""},
		{"1","3","2","0","0","12","2021","5.0","cat2","group2","every 3 Tuesdays starting December 2021","",""},
		{"1","2","1","0","1","0","0","-5.0","cat2","group2","every 2nd monday of every month","",""},
		{"1","6","4","0","3","2","0","-10.0","cat3","group2","every last thursday of every 3rd month from february","",""},
		{"1","26","8","0","1","0","0","-10.0","cat4","group1","every weekday closest to the 26th of the month","",""},
		{"1","32","0","0","12","2","0","-60.0","cat5","group1","every last day of february","",""},
		{"0","8","0","0","0","8","0","-300.0","cat6","group3","next august 8th","",""},
		{"0","9","9","0","1","0","0","5.0","cat7","group4","every weekday before the 9th of every month","",""},
		{"1","14","10","0","1","0","0","-15.0","cat4","group1","weekday on or after the 14th and 28th of every month","",""}
	};
	string[] evr = {"the","every","every 2nd", "every 3rd", "every 4th", "every 5th", "every 6th", "every 7th", "every 8th", "every 9th", "every 10th", "every 11th","every 12th", "every 13th", "every 14th", "every 15th", "every 16th", "every 17th", "every 18th", "every 19th", "every 20th", "every 21st","every 22nd", "every 23rd", "every 24th", "every 25th", "every 26th", "every 27th", "every 28th", "every 29th", "every 30th", "every 31st", "every last"};
	string[] nth = {"", "1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th", "10th", "11th", "12th", "13th", "14th", "15th", "16th", "17th", "18th", "19th", "20th", "21st", "22nd", "23rd", "24th", "25th", "26th", "27th", "28th", "29th", "30th", "31st", "last"};
	string[] wkd = {"day", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "weekday closest to the", "weekday on or before the", "weekday on or after the"};
	string[] fdy = {"", "from the 1st", "from the 2nd", "from the 3rd", "from the 4th", "from the 5th", "from the 6th", "from the 7th", "from the 8th", "from the 9th", "from the 10th", "from the 11th", "from the 12th", "from the 13th", "from the 14th", "from the 15th", "from the 16th", "from the 17th", "from the 18th", "from the 19th", "from the 20th", "from the 21st", "from the 22nd", "from the 23rd", "from the 24th", "from the 25th", "from the 26th", "from the 27th", "from the 28th", "from the 29th", "from the 30th"};
	string[] mth = {"", "of every month", "of every 2nd month", "of every 3rd month", "of every 4th month", "of every 5th month", "of every 6th month", "of every 7th month", "of every 8th month", "of every 9th month", "of every 10th month", "of every 11th month", "of every 12th month"};
	string[] fmo = {"from this month", "from january", "from february", "from march", "from april", "from may", "from june", "from july", "from august", "from september", "from october", "from november", "from december"};
	string[] omo = {"of this month", "of january", "of february", "of march", "of april", "of may", "of june", "of july", "of august", "of september", "of october", "of november", "of december"};

	private string[,] forecasted;	// array of forecasted items, used by forecast list and graph
	private int selectedrule = 0;	// used by the graph

// FTW is already defined as a window, so dunno why it has to be redefined here as a function that returns its parent... very odd.

// gtk3 =
//
//        [ main ]
//           |
//    [ application ]
//           |
//       [ window ]
//           |
//  [ widgets & events ]

// gtk4 =
// 
//        [ main ]
//           |
//    [ application ]
//           |
//       [ window ]
//           |
// [ window(application) => object(application) ] <----- what in the actual ass...
//           |
//  [ widgets & events ]


	public FTW (Gtk.Application fulltardie) {
		Object (application: fulltardie);
	}

// anyway, the ui:

	construct {
		Gdk.ScrollDirection scrolldir;
		int selectedtrns = 99999;
		double sizx = 0.0;
		double sizy = 0.0;
		double posx = 0.0;
		double posy = 0.0;
		double targx = 0.0;
		double targy = 0.0;
		double barh = 10.0;
		bool graphzoom = false;
		bool graphpan = false;
		bool graphscroll = false;
		bool graphpick = false;
		int ind = 4;
		double[] oldgraphoffset = {0.0,0.0};
		double[] oldgraphsize = {690.0,690.0};
		double[] mousedown = {0.0,0.0};
		double[] mousemove = {0.0,0.0};
		double[] oldmousedown = {0.0,0.0};
		bool drawit = true;

		this.title = "fulltardie";
		this.set_default_size(360, 720);
		this.close_request.connect((e) => { print("yeh bye\n"); return false; });
		this.set_margin_top(10);
		this.set_margin_bottom(10);
		this.set_margin_start(10);
		this.set_margin_end(10);
		Gdk.Rectangle winbox = Gdk.Rectangle(); 

// window size in gtk4 is wrong, 
// or its now squirreled-away in some new branch of gtk theology...

		print("window size is: %dx%d\n",this.get_size(HORIZONTAL),this.get_size(VERTICAL));
		print("window width is: %d\n", this.get_width());
		this.get_allocation(out winbox);
		print("window size is: %d x %d\n", winbox.width, winbox.height);

// add widgets

		Gtk.Label titlelabel = new Gtk.Label("fulltardie");
		Gtk.HeaderBar bar = new Gtk.HeaderBar();
		bar.show_title_buttons  = true;
		bar.set_title_widget(titlelabel);
		this.set_titlebar (bar);

// load/save menus

		//var save_icon = new Gtk.Image.from_icon_name ("document-save");
		//var load_icon = new Gtk.Image.from_icon_name ("document-open");
		Gtk.MenuButton loadit = new Gtk.MenuButton();
		Gtk.MenuButton saveit = new Gtk.MenuButton();
		loadit.icon_name = "document-save";
		saveit.icon_name = "document-open";
		Gtk.Button savebtn = new Button.with_label("save");

		Gtk.Popover lpop = new Gtk.Popover();
		Gtk.Popover spop = new Gtk.Popover();

		Gtk.Box spopbox = new Gtk.Box(VERTICAL,10);
		Gtk.Box lpopbox = new Gtk.Box(VERTICAL,5);
		spopbox.margin_start = 10;
		spopbox.margin_end = 10;
		spopbox.margin_top = 10;
		spopbox.margin_bottom = 10;
		lpopbox.margin_start = 10;
		lpopbox.margin_end = 10;
		lpopbox.margin_top = 10;
		lpopbox.margin_bottom = 10;

		Gtk.Entry scene = new Entry();
		scene.text = "default";

		spopbox.append(scene);
		spopbox.append(savebtn);

		spop.set_child(spopbox);
		lpop.set_child(lpopbox);

		loadit.popover = lpop;
		saveit.popover = spop;

		bar.pack_start(loadit);
		bar.pack_end(saveit);


// setup-list view for rules

		Gtk.ListBox setuplist = new Gtk.ListBox();
		setuplist.set_selection_mode(SINGLE);
		setuplist.margin_top = 10;
		setuplist.margin_bottom = 10;
		setuplist.margin_start = 10;
		setuplist.margin_end = 10;
		setuplist.vexpand = true;
		setuplist.set_size_request(10,10);

// populate setuplist with sample data

		for (var e = 0; e < dat.length[0]; e++) {
			var ll = new Gtk.Label("");
			ll.xalign = ((float) 0.0);
			var mqq = "".concat("<span font='monospace 16px'><b>", dat[e,10], "</b></span>");
			ll.set_markup(mqq);
			setuplist.insert(ll,-1);
		}
		var s = setuplist.get_row_at_index(0);
		var r = 0;
		setuplist.select_row(s);

// setup-page container

		Gtk.ScrolledWindow setuppage = new Gtk.ScrolledWindow();
		setuppage.set_child(setuplist);

// name

		Gtk.Entry dsc = new Gtk.Entry();
		dsc.text = dat[0,10];
		dsc.hexpand = true;

		Gtk.Box paramtop = new Gtk.Box(HORIZONTAL,10);
		paramtop.append(dsc);

// controls

		Gtk.ToggleButton iso = new Gtk.ToggleButton.with_label("ISO");

// button.color shitfuckery...

		var isocssprovider = new Gtk.CssProvider();
		string isocsstxt = ".GtkToggleButton { background: %s; }".printf("#FF000005");
		isocssprovider.load_from_data (isocsstxt.data);
		iso.get_style_context().add_provider(isocssprovider, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		iso.get_style_context().add_class("GtkToggleButton");
		iso.toggled.connect(() => {
			if (iso.get_active()) { 
				print("iso.toggled.connect:\ttrue\n");
				isocsstxt = ".GtkToggleButton { background: %s; }".printf("#FF000088");
			} else { 
				isocsstxt = ".GtkToggleButton { background: %s; }".printf("#FF000005");
				print("iso.toggled.connect:\tfalse\n"); 
			}
			isocssprovider.load_from_data (isocsstxt.data);
		});



		Gtk.Button ads = new Gtk.Button.with_label("+");
		ads.set_size_request(10,10);
		Gtk.Button rms = new Gtk.Button.with_label("-");

// group color controls

		Gtk.Box groupcolorbox = new Gtk.Box (VERTICAL,10);
		groupcolorbox.set_size_request (200,10);
		Gtk.Scale rrr = new Gtk.Scale.with_range(HORIZONTAL, 0, 255, 100);
		rrr.set_value(26);
		Gtk.Scale ggg = new Gtk.Scale.with_range(HORIZONTAL, 0, 255, 100);
		ggg.set_value(59);
		Gtk.Scale bbb = new Gtk.Scale.with_range(HORIZONTAL, 0, 255, 100);
		bbb.set_value(79);
		var hhh = new Entry();
		hhh.text = "#1A3B4F";
		hhh.set_width_chars(8);
		groupcolorbox.append(rrr);
		groupcolorbox.append(ggg);
		groupcolorbox.append(bbb);
		groupcolorbox.append(hhh);

// group color button

		string h = "";
		if (dat.length[0] > 0) { h = dat[0,12]; }
		var g = Gdk.RGBA();
		if (g.parse(h) == false) {
			g.parse(textcolor());
			h = textcolor();
		}

		Gtk.ToggleButton col = new Gtk.ToggleButton.with_label("▼");
		var colcssprovider = new Gtk.CssProvider();
		string colcsstxt = ".col { background: %s%s; }".printf(h,"55");
		colcssprovider.load_from_data (colcsstxt.data);
		col.get_style_context().add_provider(colcssprovider, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		col.get_style_context().add_class("col");

// assemble controls

		Gtk.Box paramctrl = new Gtk.Box(HORIZONTAL,10);
		paramctrl.append(ads);
		paramctrl.append(rms);
		paramctrl.append(iso);
		paramctrl.append(col);

// rule component combos

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

/* 
// not supported in gtk4:
		evrcombo.set_wrap_width(4);
		nthcombo.set_wrap_width(4);
		wkdcombo.set_wrap_width(2);
		fdycombo.set_wrap_width(2);
		mthcombo.set_wrap_width(2);
		fmocombo.set_wrap_width(2); 
*/

		Gtk.Adjustment yadj = new Gtk.Adjustment(2021,1990,2100,1,5,1);
		yadj.set_value((int) (GLib.get_real_time() / 31557600000000) + 1970);
		Gtk.SpinButton fye = new Gtk.SpinButton(yadj,1,0);

// rule component flowbox

		Gtk.FlowBox parammid = new Gtk.FlowBox();
		parammid.set_orientation(Orientation.HORIZONTAL);
		parammid.min_children_per_line = 1;
		parammid.max_children_per_line = 7;
		parammid.insert(fye,0);
		parammid.insert(fmocombo,0);
		parammid.insert(mthcombo,0);
		parammid.insert(fdycombo,0);
		parammid.insert(wkdcombo,0);
		parammid.insert(nthcombo,0);
		parammid.insert(evrcombo,0);


// group 

		Gtk.Label glb = new Label("grp");
		glb.set_halign(START);
		glb.set_max_width_chars(8);
		glb.set_hexpand(false);
		glb.set_size_request(10,10);
		glb.margin_end = 10;
		var groupcombo = new ComboBoxText.with_entry();
		groupcombo.set_halign(START);
		var vv = (Entry) groupcombo.get_child();
		vv.set_halign(START);
		vv.set_width_chars(8);
		vv.set_hexpand(false);

// category

		Gtk.Label clb = new Label("cat");
		clb.set_halign(START);
		clb.set_max_width_chars(8);
		clb.set_hexpand(false);
		clb.set_size_request(10,10);
		clb.margin_end = 10;
		var catcombo = new ComboBoxText.with_entry();
		var ee = (Entry) catcombo.get_child();
		ee.set_halign(START);
		ee.set_width_chars(8);
		ee.set_hexpand(false);

// amount

		Gtk.Label alb = new Label("amt");
		alb.set_halign(START);
		alb.set_max_width_chars(8);
		alb.set_hexpand(false);
		alb.set_size_request(10,10);
		alb.margin_end = 10;
		Gtk.Adjustment adj = new Gtk.Adjustment(0.0,-100000,100000.0,10.0,100.0,1.0);
		Gtk.SpinButton amountspinner = new Gtk.SpinButton(adj,1.0,2);

// group container

		Gtk.Box groupcontainer = new Gtk.Box(HORIZONTAL,0);
		groupcontainer.append(glb);
		groupcontainer.append(groupcombo);
		groupcontainer.set_halign(START);
		groupcontainer.set_size_request(10,10);
		groupcontainer.set_hexpand(false);			// this doesn't work

// category container

		Gtk.Box catcontainer = new Gtk.Box(HORIZONTAL,0);
		catcontainer.append(clb);
		catcontainer.append(catcombo);
		catcontainer.set_halign(START);
		catcontainer.set_size_request(10,10);
		catcontainer.set_hexpand(false);

// group container

		Gtk.Box amtcontainer = new Gtk.Box(HORIZONTAL,0);
		amtcontainer.append(alb);
		amtcontainer.append(amountspinner);
		amtcontainer.set_halign(START);
		amtcontainer.set_size_request(10,10);
		amtcontainer.set_hexpand(false);

// lower flowbox
// replace this with a non-stretching flowbox, once window.resize is deciphered...

		//Gtk.Label filler = new Gtk.Label("filler");
		//filler.set_hexpand(true);

		Gtk.FlowBox parambottom = new Gtk.FlowBox();
		parambottom.set_orientation(Orientation.HORIZONTAL);
		parambottom.min_children_per_line = 1;
		parambottom.max_children_per_line = 10;
		parambottom.insert(groupcontainer,0);
		parambottom.insert(catcontainer,1);
		parambottom.insert(amtcontainer,2);
		//parambottom.insert(filler,3);
		parambottom.homogeneous = true;
		//parambottom.set_selection_mode(NONE);
		parambottom.column_spacing = 10;
		//parambottom.set_size_request(300,10);
		//parambottom.set_halign(START);
		//parambottom.set_hexpand(true);

// assemble params

		Gtk.Grid paramgrid = new Gtk.Grid();
		paramgrid.margin_top = 10;
		paramgrid.margin_bottom = 10;
		paramgrid.margin_start = 10;
		paramgrid.margin_end = 80;
		paramgrid.row_spacing = 10;
		paramgrid.attach(paramtop,0,0,1,1);
		paramgrid.attach(paramctrl,0,1,1,1);
		paramgrid.attach(groupcolorbox,0,2,1,1);
		paramgrid.attach(parammid,0,3,1,1);
		paramgrid.attach(parambottom,0,4,1,1);
		//paramgrid.attach(parambottomcontainer,0,4,1,1);

		Gtk.ScrolledWindow params = new Gtk.ScrolledWindow();
		params.set_child(paramgrid);
		params.margin_top = 10;

// foecast page

		var forecastpage = new ScrolledWindow();
		var forecastlistbox = new ListBox();
		//forecastlistbox.override_background_color(NORMAL, slc);
		var forecastlistboxcssprovider = new Gtk.CssProvider();
		string forecastlistboxcss = ".fff { background: %s; }".printf(rowcolor());
		forecastlistboxcssprovider.load_from_data(forecastlistboxcss.data);
		forecastlistbox.get_style_context().add_provider(forecastlistboxcssprovider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		forecastlistbox.get_style_context().add_class("fff");
		for (var i = 1; i < 10; i++) {
			string text = @"Label $i";
			var labele = new Label(text);
			forecastlistbox.insert(labele,-1);
		}
		forecastlistbox.margin_start = 0;
		forecastlistbox.margin_end = 0;
		forecastlistbox.margin_top = 0;
		forecastlistbox.margin_bottom = 0;
		forecastpage.set_child(forecastlistbox);
		var label3 = new Label(null);
		label3.set_markup("<b><big>forecast</big></b>");

// graph page

		var label4 = new Label(null);
		label4.set_markup("<b><big>graph</big></b>");
		var graphimg = new Gtk.DrawingArea();

// notebook

		var label2 = new Gtk.Label(null);
		label2.set_markup("<b><big>setup</big></b>");

		Gtk.Notebook notebook = new Gtk.Notebook();
		notebook.set_show_border(false);
		notebook.set_tab_pos(BOTTOM);
		notebook.append_page(setuppage, label2);
		notebook.append_page(forecastpage, label3);
		notebook.append_page(graphimg, label4);
		notebook.margin_bottom = 10;

// separator

		Gtk.Paned hdiv = new Gtk.Paned(VERTICAL);
		hdiv.start_child = notebook;
		hdiv.end_child = params;
		hdiv.resize_end_child = true;
		hdiv.position = 450;
		hdiv.wide_handle = true;

// add ui to window
		if (doupdate) { print("doupdate has been swiched on too early, check functions...\n"); }
		this.set_child(hdiv);
		doupdate = true;

// select 1st row to initialize the ui

		selectarow (dat, selectedrule, setuplist, parammid, evrcombo, nthcombo, wkdcombo, fdycombo, mthcombo, fmocombo, dsc, fye, amountspinner, groupcombo, catcombo, col, colcssprovider, rrr, ggg, bbb, hhh, groupcolorbox, ind);

// run an initial forecast

		forecasted = forecast(dat, forecastlistbox, iso.get_active(), selectedrule, ind);


///////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                       //
//    EEEEEEEEEEEEEEE  VVVVVV    VVVV  EEEEEEEEEEEEEE  NNNNNNNNNNNNNN  TTTTTTTTTTTTTT  SSSSSSSSSSSSSS    //
//    EEEEEE           VVVVVV    VVVV  EEEEEE          NNNNNN    NNNN      TTTTTT      SSSSSS            //
//    EEEEEEEEEEEEEE   VVVVVV    VVVV  EEEEEEEEEEEEE   NNNNNN    NNNN      TTTTTT      SSSSSSSSSSSSSS    //
//    EEEEEE           VVVVVV    VVVV  EEEEEE          NNNNNN    NNNN      TTTTTT                SSSS    //
//    EEEEEEEEEEEEEE   VVVVVVVVVV      EEEEEEEEEEEEEE  NNNNNN    NNNN      TTTTTT      SSSSSSSSSSSSSS    //
//                                                                                                       //
///////////////////////////////////////////////////////////////////////////////////////////////////////////

//tab panel selection action

		notebook.switch_page.connect ((page, page_num) => {
			if (doupdate) {
				var pix = ((int) page_num);
				print("notebook.switch_page.connect:\tswitching to tab: %d\n", pix);
				print("notebook.switch_page.connect:\tselected rule is: %d\n", selectedrule);
				ind = 4; 
				if (pix == 0) {
					var bsr = setuplist.get_selected_row();
					var bsi = bsr.get_index();
					print("notebook.switch_page.connect:\tselected row is: %d\n", bsi);
					if (bsi != selectedrule) {
						print("notebook.switch_page.connect:\tsetuplist has dropped its selection, fixing...\n");
						// try to resync listbox selection with its selection :/
						selectarow (dat, selectedrule, setuplist, parammid, evrcombo, nthcombo, wkdcombo, fdycombo, mthcombo, fmocombo, dsc, fye, amountspinner, groupcombo, catcombo, col, colcssprovider, rrr, ggg, bbb, hhh, groupcolorbox, ind);
					}
				}
				if (pix == 1) {
					renderforecast(forecasted, forecastlistbox, ind);
				}
				if (pix == 2) {
					renderforecast(forecasted, forecastlistbox, ind);
					graphimg.queue_draw ();
				}
			}
		});

// setup-list user selection event

		setuplist.row_activated.connect ((srow) => {
			if (doupdate) {
				print("setuplist.row_selected.connect:\tselecting row: %d\n", srow.get_index());
				ind = 4;
				if (srow != null) {
					selectedrule = srow.get_index();
					selectedtrns = 99999;
					if (iso.get_active()) {
						forecasted = forecast(dat, forecastlistbox, iso.get_active(), selectedrule, ind); 
					}
					h = dat[selectedrule,12];
					g = Gdk.RGBA();
					if (g.parse(h) == false) { h = textcolor(); g.parse(h); }
					selectarow (dat, selectedrule, setuplist, parammid, evrcombo, nthcombo, wkdcombo, fdycombo, mthcombo, fmocombo, dsc, fye, amountspinner, groupcombo, catcombo, col, colcssprovider, rrr, ggg, bbb, hhh, groupcolorbox, ind);
				}
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
						if (ll.tooltip_text != "") {
							var own = int.parse(ll.tooltip_text);
							selectedrule = own;
							s = setuplist.get_row_at_index(own);
							doupdate = false; setuplist.select_row(s); doupdate = true;
							print("forecastlistbox.row_activated.connect:\tselected rule changed to: %d\n", own);
							selectarow (dat, selectedrule, setuplist, parammid, evrcombo, nthcombo, wkdcombo, fdycombo, mthcombo, fmocombo, dsc, fye, amountspinner, groupcombo, catcombo, col, colcssprovider, rrr, ggg, bbb, hhh, groupcolorbox, ind);
						}
					}
				}
			}
		});

/////////////////////////////////////////////////
//                                             //
//    re-forcasting and re-rendering params    //
//                                             //
/////////////////////////////////////////////////

		evrcombo.changed.connect(() => {
			if (doupdate) {
				ind = 4;
				var n = evrcombo.get_active();
				s = setuplist.get_selected_row();
				r = 0;
				if (s != null) { 
					print("evrcombo.changed.connect:\tselecting item: %d\n", n);
					r = s.get_index(); 
					dat[r,0] = n.to_string();
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), selectedrule, ind);
				}
			}
		});
		nthcombo.changed.connect(() => {
			if (doupdate) {
				ind = 4;
				var n = nthcombo.get_active();
				s = setuplist.get_selected_row();
				r = 0;
				if (s != null) { 
					print("nthcombo.changed.connect:\tselecting item: %d\n", n);
					r = s.get_index();
					dat[r,1] = n.to_string();
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), selectedrule, ind);
				}
			}
		});
		wkdcombo.changed.connect(() => {
			if (doupdate) {
				ind = 4;
				var n = wkdcombo.get_active();
				s = setuplist.get_selected_row();
				r = 0;
				if (s != null) { 
					print("wkdcombo.changed.connect:\tselecting item: %d\n", n);
					r = s.get_index();
					dat[r,2] = n.to_string();
					var ffs = int.parse(dat[r,2]);
					if (ffs > 7) {
						if (parambottom.get_child_at_index(1).get_child() == nthcombo) {
							parambottom.remove(parambottom.get_child_at_index(1));
							parambottom.remove(parambottom.get_child_at_index(1));
							parambottom.insert(wkdcombo,1);
							parambottom.insert(nthcombo,2);
						}
					} else {
						if (parambottom.get_child_at_index(1).get_child() == wkdcombo) {
							parambottom.remove(parambottom.get_child_at_index(1));
							parambottom.remove(parambottom.get_child_at_index(1));
							parambottom.insert(nthcombo,1);
							parambottom.insert(wkdcombo,2);
						}
					}
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), selectedrule, ind);
				}
			}
		});
		fdycombo.changed.connect(() => {
			if (doupdate) {
				ind = 4;
				var n = fdycombo.get_active();
				s = setuplist.get_selected_row();
				r = 0;
				if (s != null) { 
					print("fdycombo.changed.connect:\tselecting item: %d\n", n);
					r = s.get_index();
					dat[r,3] = n.to_string();
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), selectedrule, ind);
				}
			}
		});
		mthcombo.changed.connect(() => {
			if (doupdate) {
				ind = 4;
				var n = mthcombo.get_active();
				s = setuplist.get_selected_row();
				r = 0;
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
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), selectedrule, ind);
				}
			}
		});
		fmocombo.changed.connect(() => {
			if (doupdate) {
				ind = 4;
				var n = fmocombo.get_active();
				s = setuplist.get_selected_row();
				r = 0;
				if (s != null) {
					print("fmocombo.changed.connect:\tselecting item: %d\n", n);
					r = s.get_index();
					dat[r,5] = n.to_string();
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), selectedrule, ind);
				}
			}
		});
		fye.changed.connect(() => {
			if (doupdate) {
				ind = 4;
				s = setuplist.get_selected_row();
				r = 0;
				if (s != null) { 
					var v = fye.get_value();
					print("fye.changed.connect:\tchanging value to: %f\n", v);
					r = s.get_index();
					if (v == ((int) (GLib.get_real_time() / 31557600000000) + 1970)) {
						dat[r,6] = "0";
					} else {
						dat[r,6] = ((string) ("%lf").printf(v));
					}
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), selectedrule, ind);
				}
			}
		});
		amountspinner.value_changed.connect(() => {
			if (doupdate) {
				ind = 4;
				s = setuplist.get_selected_row();
				r = 0;
				if (s != null) { r = s.get_index(); }
				print("amountspinner.value_changed.connect:\tchanging value to: %f\n", amountspinner.get_value());
				dat[r,7] =((string) ("%.2lf").printf(amountspinner.get_value()));;
				forecasted = forecast(dat, forecastlistbox, iso.get_active(), selectedrule, ind);
			}
		});
		iso.toggled.connect(() => {
			if (doupdate) {
				ind = 4;
				s = setuplist.get_selected_row();
				r = 0;
				if (s != null) {
					print("iso.toggled.connect:\ttoggling isolate...\n");
					r = s.get_index();
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), r, ind);
					print("iso.toggled.connect is redrawing the graph...\n");
					graphimg.queue_draw ();
				}
			}
		});

//////////////////////////////////
//                              //
//   non-reforcasting params    //
//                              //
//////////////////////////////////

		groupcombo.changed.connect(() => {
			if (doupdate) {
				ind = 4;
				var n = groupcombo.get_active_text().strip();
				s = setuplist.get_selected_row();
				r = 0;
				if (s != null) {
					print("groupcombo.changed.connect:\tselecting item: %s\n", n);
					r = s.get_index();
					dat[r,9] = n;

// grab group color from another item with the same group, if one exists

					var gc = Gdk.RGBA();
					var uc = "";
					for  (int i = 0; i < dat.length[0]; i++) {
						uc = "";
						if (i != r) { 
							if (dat[i,9] == n) {
								uc = dat[i,12];
								//print("groupcombo.changed.connect:\tdat[%d,9] = %s\n", i, dat[i,12]);
								if (gc.parse(uc)) { break; } else { uc = ""; }
							}
						}
					}
					if (gc.parse(uc) == false) { uc = textcolor(); gc.parse(uc); }
					//col.override_background_color(NORMAL, gc);
					colcsstxt = ".col { background: %s%s; }".printf(h,"55");
					if (col.get_active()) {
						colcsstxt = ".col { background: %s%s; }".printf(h,"FF");
						doupdate = false;
						hhh.text = uc;
						rrr.adjustment.value = ((double) ((int) (gc.red * 255.0)));
						ggg.adjustment.value = ((double) ((int) (gc.green * 255.0)));
						bbb.adjustment.value = ((double) ((int) (gc.blue * 255.0)));
						//groupcolorbox.visible = true;
						doupdate = true;
					}
					colcssprovider.load_from_data (colcsstxt.data);

// save group color, re-render the setup list

					dat[r,12] = uc;
					if (notebook.get_current_page() == 0) { rendersetuplist(dat, selectedrule, setuplist, ind); }
					for  (int i = 0; i < forecasted.length[0]; i++) {
						if (int.parse(forecasted[i,8]) == r) {
							forecasted[i,4] = n;
							forecasted[i,7] = uc;
						}
					}
					if (notebook.get_current_page() == 1) {
						renderforecast(forecasted, forecastlistbox, ind);
					}
					if (notebook.get_current_page() == 2) {
						renderforecast(forecasted, forecastlistbox, ind);
						graphimg.queue_draw ();
					}
				}
			}
		});
		catcombo.changed.connect(() => {
			if (doupdate) {
				ind = 4;
				var n = catcombo.get_active_text();
				s = setuplist.get_selected_row();
				r = 0;
				if (s != null) {
					print("catcombo.changed.connect:\tselecting item: %s\n", n);
					r = s.get_index();
					dat[r,8] = n;
					var gc = Gdk.RGBA();
					var uc = "";
					for  (int i = 0; i < dat.length[0]; i++) {
						uc = "";
						if (i != r) { 
							if (dat[i,8] == n) {
								uc = dat[i,11];
								//print("catcombo.changed.connect:\tdat[%d,8] = %s\n", i, dat[i,11]);
								if (gc.parse(uc)) { break; } else { uc = ""; }
							}
						}
					}
					if (uc == "") { uc = textcolor(); }
					dat[r,11] = uc;
				}
			}
		});
		ee = (Entry) catcombo.get_child();
		ee.activate.connect(() => {
			if (doupdate) {
				ind = 4;
				var n = ee.text;
				s = setuplist.get_selected_row();
				r = 0;
				if (s != null) {
					doupdate = false;
					print("ee.activate.connect:\ttext changed to: %s\n", n);
					r = s.get_index();
					dat[r,8] = n;
					string[] cc = getchoicelist(dat,8, ind);
					catcombo.remove_all();
					for (var j = 0; j < cc.length; j++) {
						catcombo.append_text(cc[j]);
						if (cc[j] == n) { r = j; }
					}
					catcombo.set_active(r);

// grab color from other matching categories

					print("ee.activate.connect:\ttext changed to: %s\n", n);
					var gc = Gdk.RGBA();
					var uc = "";
					for  (int i = 0; i < dat.length[0]; i++) {
						uc = "";
						if (i != r) { 
							if (dat[i,8] == n) {
								uc = dat[i,11];
								//print("catcombo.changed.connect:\tdat[%d,8] = %s\n", i, dat[i,11]);
								if (gc.parse(uc)) { break; } else { uc = ""; }
							}
						}
					}
					if (uc == "") { uc = textcolor(); }
					dat[r,11] = uc;
					doupdate = true;
				}
			}
		});
		vv = (Entry) groupcombo.get_child();
		vv.activate.connect(() => {
			if (doupdate) {
				ind = 4;
				var n = vv.text;
				s = setuplist.get_selected_row();
				r = 0;
				if (s != null) {
					doupdate = false;
					print("vv.activate.connect:\tselecting item: %s\n", n);
					r = s.get_index();
					dat[r,9] = n;
					string[] cc = getchoicelist(dat,9, ind);
					groupcombo.remove_all();
					for (var j = 0; j < cc.length; j++) {
						groupcombo.append_text(cc[j]);
						if (cc[j] == n) { r = j; }
					}
					groupcombo.set_active(r);

// grab group color from another item with the same group, if one exists

					var gc = Gdk.RGBA();
					var uc = "";
					for  (int i = 0; i < dat.length[0]; i++) {
						uc = "";
						if (i != r) { 
							if (dat[i,9] == n) {
								uc = dat[i,12];
								//print("groupcombo.changed.connect:\tdat[%d,9] = %s\n", i, dat[i,12]);
								if (gc.parse(uc)) { break; } else { uc = ""; }
							}
						}
					}
					if (gc.parse(uc) == false) { uc = textcolor(); gc.parse(uc); }
					//col.override_background_color(NORMAL, gc);
					colcsstxt = ".col { background: %s%s; }".printf(h,"55");
					if (col.get_active()) {
						colcsstxt = ".col { background: %s%s; }".printf(h,"FF");
						doupdate = false;
						hhh.text = uc;
						rrr.adjustment.value = ((double) ((int) (gc.red * 255.0)));
						ggg.adjustment.value = ((double) ((int) (gc.green * 255.0)));
						bbb.adjustment.value = ((double) ((int) (gc.blue * 255.0)));
						//groupcolorbox.visible = true;
						doupdate = true;
					}
					colcssprovider.load_from_data (colcsstxt.data);

// save group color, re-render the setup list

					dat[r,12] = uc;
					if (notebook.get_current_page() == 0) { rendersetuplist(dat, selectedrule, setuplist, ind); }
					for  (int i = 0; i < forecasted.length[0]; i++) {
						if (int.parse(forecasted[i,8]) == r) {
							forecasted[i,4] = n;
							forecasted[i,7] = uc;
						}
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
		dsc.changed.connect(() => {
			if (doupdate) {
				ind = 4;
				string d = dsc.text.strip();
				if (dsc.text != null) {
					if (d != "") {
						doupdate = false;
						print("dsc.changed.connect:\tchanging text to: %s\n", d);
						dat[selectedrule,10] = d;
						if (notebook.get_current_page() == 0) {
							rendersetuplist(dat, selectedrule, setuplist, ind);
						}
						if (notebook.get_current_page() == 1) {
							for (int f = 0; f < forecasted.length[0]; f++) {
								if ( int.parse(forecasted[f,8]) == selectedrule ) {
					 				forecasted[f,1] = d;
								}
							}
							renderforecast(forecasted, forecastlistbox, ind);
						}
						doupdate = true;
					}
				}
			}
		});

// colors

		col.toggled.connect(() => {
			h = "";
			h = dat[selectedrule,12];
			g = Gdk.RGBA();
			if (g.parse(h) == false) {
				g.parse(textcolor());
				h = textcolor();
			}
			if (col.get_active()) { 
				col.set_label("");
				print("col.toggled.connect:\ttrue\n");
				colcsstxt = ".col { background: %s%s; }".printf(h,"FF");
				doupdate = false;
				hhh.text = h;
				rrr.adjustment.value = ((double) ((int) (g.red * 255.0)));
				ggg.adjustment.value = ((double) ((int) (g.green * 255.0)));
				bbb.adjustment.value = ((double) ((int) (g.blue * 255.0)));
				groupcolorbox.visible = true;
				doupdate = true;
			} else { 
				col.set_label("▼");
				colcsstxt = ".col { background: %s%s; }".printf(h,"55");
				groupcolorbox.visible = false;
				print("col.toggled.connect:\tfalse\n"); 
			}
			colcssprovider.load_from_data (colcsstxt.data);
		});
		rrr.adjustment.value_changed.connect(() => {
			if (doupdate) {
				ind = 4;
				doupdate = false;
				print("rrr.adjustment.value_changed.connect:\tchanging value to: %f\n", rrr.adjustment.value);
				adjustgroupcolor(dat, forecasted, col, colcssprovider, selectedrule, hhh, rrr.adjustment.value, ggg.adjustment.value, bbb.adjustment.value, false, ind);
				if (notebook.get_current_page() == 0) {
					rendersetuplist(dat, selectedrule, setuplist, ind);
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
		});
		ggg.adjustment.value_changed.connect(() => {
			if (doupdate) {
				ind = 4;
				doupdate = false;
				print("ggg.adjustment.value_changed.connect:\tchanging value to: %f\n", bbb.adjustment.value);
				adjustgroupcolor(dat, forecasted, col, colcssprovider, selectedrule, hhh, rrr.adjustment.value, ggg.adjustment.value, bbb.adjustment.value, false, ind);
				if (notebook.get_current_page() == 0) {
					rendersetuplist(dat, selectedrule, setuplist, ind);
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
		});
		bbb.adjustment.value_changed.connect(() => {
			if (doupdate) {
				ind = 4;
				doupdate = false;
				print("bbb.adjustment.value_changed.connect:\tchanging value to: %f\n", bbb.adjustment.value);
				adjustgroupcolor(dat, forecasted, col, colcssprovider, selectedrule, hhh, rrr.adjustment.value, ggg.adjustment.value, bbb.adjustment.value, false, ind);
				if (notebook.get_current_page() == 0) {
					rendersetuplist(dat, selectedrule, setuplist, ind);
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
		});
		hhh.changed.connect (() => {
			if (doupdate) {
				ind = 4;
				if (hhh.text.strip() != "") {
					g = Gdk.RGBA();
					if (g.parse(hhh.text)) {
						doupdate = false;
						print("hhh.changed.connect:\tchanging value to: %s\n", hhh.text);
						adjustgroupcolor(dat, forecasted, col, colcssprovider, selectedrule, hhh, rrr.adjustment.value, ggg.adjustment.value, bbb.adjustment.value, true, ind);
						if (notebook.get_current_page() == 0) {
							rendersetuplist(dat, selectedrule, setuplist, ind);
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
		});

//////////////////////
//                  //
//    i/o params    //
//                  //
//////////////////////

		savebtn.clicked.connect (() =>  {
			if (scene.text != null) {
				if (scene.text.strip() != "") {
					bool allgood = false;
					print("savebtn.clicked.connect:\tsaving scenario: %s\n", scene.text);
					ind = 4;
					var dd = GLib.Environment.get_current_dir();
					string nn = (scene.text + ".scenario");
					string ff = Path.build_filename (dd, nn);
					File fff = File.new_for_path (ff);
					FileOutputStream oo = null;
					try {
						oo = fff.replace (null, false, FileCreateFlags.PRIVATE);
						allgood = true;
					} catch (Error e) {
						print ("Error: couldn't make outputstream.\n\t%s\n", e.message);
					}
					if (allgood) {
						for (var u = 0; u < dat.length[0]; u++) {
							for (var j = 0; j < 13; j++) {
								string rr = dat[u,j];
								if (j < 12) { rr = ( rr + ";"); } 
								oo.write (rr.data);
							}
							oo.write("\n".data);
						}
					}
					spop.popdown();
				}
			}
		});
		//saveit.clicked.connect(() => {
			//spopbox.show_all();
			//spop.popup();
		//});
		loadit.activate.connect (() =>  {
			print("loadit.clicked.connect:\tfetching saved scenarios...\n");
			ind = 4;
			//lpopbox.foreach ((element) => lpopbox.remove (element));
			while (lpopbox.get_first_child() != null) {
				print("loadit:\tremoving old popmenu item...\n");
  				lpopbox.remove(lpopbox.get_first_child());
			}
			var pth = GLib.Environment.get_current_dir();
			GLib.Dir dcr = Dir.open (pth, 0);
			string? name = null;
			while ((name = dcr.read_name ()) != null) {
				var exts = name.split(".");
				if (exts.length == 2) {
					if (exts[1] == "scenario") {
						Gtk.Button muh = new Gtk.Button.with_label (name);
						lpopbox.append(muh);
						muh.clicked.connect ((buh) => {
							bool allgood = false;
							var dd = GLib.Environment.get_current_dir();
							var nn = buh.label;
							string ff = Path.build_filename (dd, nn);
							GLib.FileStream ss = null;
							try {
								ss = FileStream.open(ff, "r");
								allgood = true;
							} catch (Error e) {
								print ("Error: couldn't load file.\n\t%s\n", e.message);
							}
							if (allgood) {
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
									for (var y = 0; y < oo.length; y++) {
										string[] rr = oo[y].split(";");
										while (rr.length < 13) { rr += ""; }
										if (rr.length == 13) {
											for (var c = 0; c < 13; c++) {
												tdat[y,c] = rr[c];
											}
										}
									}
									if (tdat.length[0] > 0) {
										doupdate = false; 
										dat = tdat;
										//setuplist.foreach ((element) => setuplist.remove (element));
										while (setuplist.get_first_child() != null) {
											print("loadit:\tremoving old list item...\n");
  											setuplist.remove(setuplist.get_first_child());
										}
										for (var e = 0; e < dat.length[0]; e++) {
											var ll = new Label("");
											ll.set_hexpand(true);
											ll.xalign = ((float) 0.0);
											var mqq = "".concat("<span color='#FFFFFF' font='monospace 16px'><b>", dat[e,10], "</b></span>");
											ll.set_markup(mqq);
											setuplist.insert(ll,-1);
										}
										setuplist.show();
										scene.text = exts[0];
										selectedrule = 0;
										var row = setuplist.get_row_at_index(0);
										doupdate = true;
										selectarow (dat, selectedrule, setuplist, parammid, evrcombo, nthcombo, wkdcombo, fdycombo, mthcombo, fmocombo, dsc, fye, amountspinner, groupcombo, catcombo, col, colcssprovider, rrr, ggg, bbb, hhh, groupcolorbox, ind);
										forecasted = forecast(dat,forecastlistbox, iso.get_active(), 0, ind);
										graphimg.queue_draw ();
									}
								}
							}
							lpop.popdown();
						});
					}
				}
			}
			//lpopbox.show();
			//lpop.show();
		});

//////////////////////////////////
//                              //
//    add/remove data params    //
//                              //
//////////////////////////////////

		ads.clicked.connect (() =>  {
			s = setuplist.get_selected_row();
			var w = 0;
			var n = dat.length[0];
			if (s != null) {
				ind = 4;
				w = s.get_index();
				print("addrule.clicked.connect:\tadding new rule...\n");
				//print("selected row is %d\n", w);
				string[,] tdat = new string[(n+1),13];
				for (var y = 0; y < dat.length[0]; y++) {
					for (var c = 0; c < 13; c++) {
						tdat[y,c] = dat[y,c];
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
				//setuplist.foreach ((element) => setuplist.remove (element));
				while (setuplist.get_first_child() != null) {
					print("loadit:\tremoving old list item...\n");
  					setuplist.remove(setuplist.get_first_child());
				}
				for (var e = 0; e < dat.length[0]; e++) {
					//var ll = new Label(dat[e,10]);
					var ll = new Label("");
					ll.xalign = ((float) 0.0);
					var mqq = "".concat("<span font='monospace 16px'><b>", dat[e,10], "</b></span>");
					ll.set_markup(mqq);
					setuplist.insert(ll,-1);
				}
				setuplist.show();
				selectedrule = (dat.length[0] - 1);
				var row = setuplist.get_row_at_index((dat.length[0] - 1));
				selectarow (dat, selectedrule, setuplist, parammid, evrcombo, nthcombo, wkdcombo, fdycombo, mthcombo, fmocombo, dsc, fye, amountspinner, groupcombo, catcombo, col, colcssprovider, rrr, ggg, bbb, hhh, groupcolorbox, ind);
				forecasted = forecast(dat,forecastlistbox, iso.get_active(), (dat.length[0] - 1), ind);
				graphimg.queue_draw ();
			}
		});
		rms.clicked.connect (() =>  {
			s = setuplist.get_selected_row();
			var w = 0;
			var n = dat.length[0];
			if (s != null) {
				ind = 4;
				w = s.get_index();
				print("remrule.clicked.connect:\tremoving rule: %s\n",dat[w,9]);
				//print("selected row is %d\n", w);
				string[,] tdat = new string[(n-1),13];
				var i = 0;
				for (var y = 0; y < dat.length[0]; y++) {
					//print("y = %d, i = %d\n", y, i);
					if (y != w) {
						for (var c = 0; c < 13; c++) {
							tdat[i,c] = dat[y,c];
							//print("%s, ", tdat[y,c]);
						}
						i++;
						//print("\n");
					}
				}
				dat = tdat;
				//setuplist.foreach ((element) => setuplist.remove (element));
				while (setuplist.get_first_child() != null) {
					print("loadit:\tremoving old list item...\n");
  					setuplist.remove(setuplist.get_first_child());
				}
				for (var e = 0; e < dat.length[0]; e++) {
					var ll = new Label(dat[e,10]);
					ll.xalign = ((float) 0.0);
					setuplist.insert(ll,-1);
				}
				setuplist.show();
				selectedrule = (dat.length[0] - 1);
				var row = setuplist.get_row_at_index((dat.length[0] - 1));
				selectarow (dat, selectedrule, setuplist, parammid, evrcombo, nthcombo, wkdcombo, fdycombo, mthcombo, fmocombo, dsc, fye, amountspinner, groupcombo, catcombo, col, colcssprovider, rrr, ggg, bbb, hhh, groupcolorbox, ind);
				forecasted = forecast(dat,forecastlistbox, iso.get_active(), (dat.length[0] - 1), ind);
				graphimg.queue_draw ();
			}
		});

//////////////////////////
//                      //
//    graph rendering   //
//                      //
//////////////////////////

		graphimg.set_draw_func((da, ctx, daw, dah) => {
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

				barh = sizy / forecasted.length[0];

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

				var bc = Gdk.RGBA();
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
					ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 0.05));
					ctx.rectangle(0, stackmo, csx, mol[i]);
					ctx.fill();
					bc.parse(textcolor());
					ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 0.3));
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
					ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 0.9));
					ctx.rectangle(px, py, xx.abs(), (barh - 1));
					ctx.fill ();
					if (selectedrule == int.parse(forecasted[i,8])) { 
						bc.red = ((float) 1.0); bc.green = ((float) 1.0); bc.blue = ((float) 1.0);
						ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 0.5));
						ctx.rectangle(px, py, xx.abs(), (barh - 1));
						ctx.fill();
						ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 0.9));
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
					ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 1.0));
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
						selectarow (dat, selectedrule, setuplist, parammid, evrcombo, nthcombo, wkdcombo, fdycombo, mthcombo, fmocombo, dsc, fye, amountspinner, groupcombo, catcombo, col, colcssprovider, rrr, ggg, bbb, hhh, groupcolorbox, ind);
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
			//return true;
		});

////////////////////////////
//                        //
//    graph interaction   //
//                        //
////////////////////////////

		/*
		graphimg.add_events (Gdk.EventMask.TOUCH_MASK);
		graphimg.add_events (Gdk.EventMask.BUTTON_PRESS_MASK);
		graphimg.add_events (Gdk.EventMask.BUTTON2_MOTION_MASK);
		graphimg.add_events (Gdk.EventMask.BUTTON3_MOTION_MASK);
		graphimg.add_events (Gdk.EventMask.BUTTON_RELEASE_MASK);
		graphimg.add_events (Gdk.EventMask.POINTER_MOTION_MASK);
		graphimg.add_events (Gdk.EventMask.SCROLL_MASK);
		*/

		Gtk.GestureClick touchtap = new Gtk.GestureClick();
		Gtk.GestureDrag touchpan = new Gtk.GestureDrag();

		touchtap.set_button(Gdk.BUTTON_PRIMARY);
		touchpan.set_button(Gdk.BUTTON_PRIMARY);

		graphimg.add_controller (touchtap);
		graphimg.add_controller (touchpan);

		touchtap.pressed.connect((event, n, x, y) => {
			ind = 4;
			print("touchtap.pressed.connect\n");
			mousedown = {x, y};
			graphpick = (event.button == 1);
			graphzoom = (event.button == 3);
			graphpan = (event.button == 2);
			if (graphpick) { 
				oldmousedown = {mousedown[0], mousedown[1]};
				targx = mousedown[0]; targy = mousedown[1]; 
			}
		});
		touchtap.released.connect((event, n, x, y) => {
			ind = 4;
			print("touchtap.released.connect\n");
			graphzoom = false;
			graphpan = false;
			graphscroll = false;
			if (graphpick) { 
				graphimg.queue_draw(); 
			}
			oldgraphsize = {sizx, sizy};
			oldgraphoffset = {posx, posy};
			oldmousedown = {targx, targy};
		});
		touchpan.drag_begin.connect ((event, x, y) => {
				print("touchpan_drag_begin\n");
				mousedown = {x, y};
				graphpick = true;
				graphpan = false;
				graphzoom = false;
		});
		touchpan.drag_update.connect((event, x, y) => {
			graphpan = true;
			graphzoom = false;
			graphpick = false;
			mousemove = { x, y };
			graphimg.queue_draw();
		});
		touchpan.drag_end.connect(() => {
			print("touchpan_drag_end\n");
			graphpick = false;
			graphpan = false;
			graphzoom = false;
			oldgraphsize = {sizx, sizy};
			oldgraphoffset = {posx, posy};
			oldmousedown = {targx, targy};
		});
		/*
		graphimg.button_press_event.connect ((event) => {
			ind = 4;
			print("graphimg.button_press_event.connect\n");
			mousedown = {event.x, event.y};
			graphpick = (event.button == 1);
			graphzoom = (event.button == 3);
			graphpan = (event.button == 2);
			if (graphpick) { 
				oldmousedown = {mousedown[0], mousedown[1]};
				targx = mousedown[0]; targy = mousedown[1]; 
			}
			return true;
		});
		graphimg.motion_notify_event.connect ((event) => {
			ind = 4;
			if (graphzoom == false && graphpan == false && graphpick == false) { mousedown = {event.x, event.y}; }
			mousemove = {event.x, event.y};
			if (graphzoom || graphpan) {
				graphimg.queue_draw();
			}
			return true;
		});
		graphimg.scroll_event.connect ((event) => {
			ind = 4;
			scrolldir = UP;
			if (event.scroll.direction == scrolldir) {
				graphscroll = true;
				mousemove = {(mousedown[0] + 50.0), (mousedown[1] + 50.0)};
				graphimg.queue_draw();
			}
			scrolldir = DOWN;
			if (event.scroll.direction == scrolldir)  {
				graphscroll = true;
				mousemove = {(mousedown[0] - 50.0), (mousedown[1] - 50.0)};
				graphimg.queue_draw();
			}
			return true;
		});

// reset/update stuff on mouse release

		graphimg.button_release_event.connect ((event) => {
			ind = 4;
			print("graphimg.button_release_event.connect\n");
			graphzoom = false;
			graphpan = false;
			graphscroll = false;
			if (graphpick) { 
				graphimg.queue_draw(); 
			}
			oldgraphsize = {sizx, sizy};
			oldgraphoffset = {posx, posy};
			oldmousedown = {targx, targy};
			return true;
		});
		*/
	}
}

int main (string[] args) {
  var app = new fulltardie();
  app.activate.connect (() => {
    var win = new FTW(app);
    win.present ();
  });
  return app.run (args);
}
