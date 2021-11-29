// gtk4 translation
// by c.p.brown 2021
//
// replacing listboxes with cairo drawareas
// css roundtripping was lagging, producing incorrect results, and generally retarded

// TODO
// - [!] function ui input as globals to reduce cruft
// - [!] clean up names
// - [ ] clean up events
// - [ ] replace listboxes with drawareas
// - [ ] make setuplistdraw function
// - [ ] make forecastlistdraw function
// - [ ] convert listrenderers to text preprocessors
// - [!] append color preprocessed text with a delimiter, slice it off in draw events

using Gtk;

// use 4char vars outside
// use 3char vars in functions
// use 1char vars in events

// vars used everywhere:

bool				doup;		// toggle ui events
bool				spew;		// toggle diagnostics
string				txtc;		// "#55BDFF"
string				rowc;		// "#1A3B4F"
string				tltc;		// "#112633"
string[,]			sdat;		// source rule input
string[,]			fdat;		// forecasted output
Gdk.RGBA			rgba;		// misc. color
int					ssrr;		// current rule

// ui often changed by functions

Gtk.Box				ptop;		// top parameter box
Gtk.Box				pctr;		// contol parameter box
Gtk.FlowBox			pmid;		// mid parameter box
Gtk.Box				pcol;		// color slider box
Gtk.FlowBox			plow;		// lower parameter box

Gtk.Notebook		tabp;		// tab panel
Gtk.DrawingArea		slst;		// setup list
Gtk.DrawingArea		flst;		// forecast list
Gtk.DrawingArea		gimg;		// graph

Gtk.ToggleButton	tiso;		// isolate toggle
Gtk.ToggleButton	tcol;		// color toggle

Gtk.ComboBoxText	cevr;		// every
Gtk.ComboBoxText	cnth;		// nth
Gtk.ComboBoxText	cwkd;		// weekday
Gtk.ComboBoxText	cfdy;		// fromday
Gtk.ComboBoxText	cmth;		// ofmonth
Gtk.ComboBoxText	cfmo;		// frommonth
Gtk.SpinButton		sfye;		// from year

Gtk.ComboBoxText	cgrp;		// groups
Gtk.ComboBoxText	ccat;		// categories
Gtk.SpinButton		samt;		// amount

Gtk.Box				xcol;		// group color expander
Gtk.Scale			rrrr;		// red slider
Gtk.Scale			gggg;		// green slider
Gtk.Scale			bbbb;		// blue slider
Gtk.Entry			hhhh;		// hex field

// data returned from findnextdate

struct nextdate {
	public Date		nxd;
	public double	amt;
	public string	grp;
	public string	cat;
	public string	dsc;
	public int		frm;
	public string	cco;
	public string	gco;
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
	if (spewin) {
		var tabi = ("%-" + ind.to_string() + "s").printf("");
		print("%shtmlcol: (%d, %d, %d)\n", tabi, r, g, b);
	}
	return ("#%02X%02X%02X".printf(r, g, b));
}

// forecast per item, dat supplied so it can be pre-culled by isolate toggle

nextdate[] findnextdate (string[,] dat, int own, int ind) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	if (spewin) {
		print("%sfindnextdate started...\n", tabi);
	}
	var nind  = ind + 4;
	int[] lastdayofmonth = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
	var nt = new DateTime.now_local();
	var ntd = nt.get_day_of_month();
	var ntm = nt.get_month();
	var nty = nt.get_year();
	var n = Date();
	n.set_dmy((DateDay) ntd, ntm, (DateYear) nty);
	if (spewin) { if (n.valid() == false) { print("invalid now date: %d %d %d\n", nty, ntm, ntd); } }
	nextdate[] o = {};
	var oo = nextdate();
	oo.nxd = n;
	oo.amt = double.parse(dat[7]);
	oo.grp = dat[9];
	oo.cat = dat[8];
	oo.dsc = dat[10];
	oo.cco = dat[11];
	oo.gco = dat[12];
	if (dat[11].strip() == "") { oo.cco = txtc; }
	if (dat[12].strip() == "") { oo.gco = txtc; }
	oo.frm = ownr;
	var ofs = int.parse(dat[0]);
	var nth = int.parse(dat[1]);
	var ofm = int.parse(dat[4]);
	var fmo = int.parse(dat[5]);
	var fye = int.parse(dat[6]);
	var wkd = int.parse(dat[2]);
	var fdy = int.parse(dat[3]);
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
	if (spewin) { if (a.valid() == false) { print("invalid initial start date: %d %d %d\n", fye, fmo, ntd); } }
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
					if (iwkd(j.get_weekday(),nind) == wkd) { wdc = wdc + 1; }
					if (e == mth) { cdc = cdc + 1; }
				}
				var cnth = int.max(int.min(nth,wdc),1);
				var cfdy = int.min(fdy,1);
				var cofs = int.max(ofs,1);

// step through the days of the month

				for (int d = 1; d <= md; d++) {
					a.set_day((DateDay) d);
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
				if (spewin) { if (a.valid() == false) { print("invalid monthday reset date\n"); } }
			}

// add a year if required

			if ((a.get_month() + 1) > 12) {
				a.set_year(a.get_year() + 1);
				j.set_year(j.get_year() + 1);
				if (spewin) { if (a.valid() == false) { print("invalid year incrament date\n"); } }
			}

// incrament the month

			j.set_month((j.get_month() % 12) + 1);
			a.set_month((a.get_month() % 12) + 1);
			if (spewin) { if (a.valid() == false) { print("invalid month incrament date\n"); } }
		}

// we're day-counting... this is more expensive so its handled as a special case

	} else {
		if (fdy > 0) { 
			a.set_dmy((DateDay) fdy, fmo, (DateYear) fye);
			if (spewin) { if (a.valid() == false) { print("invalid day-count initialized fdy date\n"); } }
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
								if (spewin) { if (a.valid() == false) { print("invalid day-count avd date\n"); } }
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
				if (spewin) { if (a.valid() == false) { print("invalid day-count incrament date\n"); } }
			}
		} else {
			if (nth > 0) {
				a.set_dmy((DateDay) nth, fmo, (DateYear) fye);
				if (spewin) { if (a.valid() == false) { print("invalid day-count initialized date\n"); } }
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
	if (spewin) { print("%sfindnextdate completed.\n",tabi); }
	return o;
}

// pre-processing text for flst.draw()

string[] renderforecasttext (int ind) {

	var ttt = ("%-" + ind.to_string() + "s").printf("");
	if (spewin) { print("%srenderforecast started...\n", ttt); }
	var ttn = ("%-" + (ind + 4).to_string() + "s").printf("");

	string[] ooo = {};

	// 0 = date
	// 1 = description
	// 2 = amount
	// 3 = cat
	// 4 = group
	// 5 = runningtotal
	// 6 = catcolor
	// 7 = groupcolor
	// 8 = owner

	if (fdat.length[0] > 0) {
		if (fdat.length[1] == 9) {
			int[] sls = {8,0,0,0,0};

// get string lengths

			for (var r = 0; r < fdat.length[0]; r++) {
				if (sls[4] < fdat[r,4].length) { sls[4] = fdat[r,4].length; } // group
				if (sls[3] < fdat[r,3].length) { sls[3] = fdat[r,3].length; } // cat
				if (sls[2] < fdat[r,2].length) { sls[2] = fdat[r,2].length; } // amount
				if (sls[1] < fdat[r,1].length) { sls[1] = fdat[r,1].length; } // description
			}

// render text

			for (var r = 0; r < fdat.length[0]; r++) {
				string clr = fdat[r,7];
				rgba = Gdk.RGBA;
				if (rgba.parse(clr) == false) { clr = txtc; rgba.parse(clr); }
				ooo += "".concat(
					fdat[r,0], " : ", 
					("%-" + sls[3].to_string() + "s").printf(fdat[r,3]), " ",
					("%-" + sls[2].to_string() + "s").printf(fdat[r,2]), " ",
					("%-" + sls[1].to_string() + "s").printf(fdat[r,1]), " ",
					" : ", fdat[r,5], ";", clr
				);
			}
		}
	}
	if (spewin) { print("%srenderforecast completed.\n",tabi); }
	return ooo;
}

forecast (int ind) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	if (spewin) { print("%sforecast started...\n",tabi); }
	var nind = ind + 4;

	string[] rrr = {};

// get forecasts

	nextdate[] ttt = {};

	if (tiso.get_active()) {
		string[] aaa = {};
		for (var g = 0; g < 13; g++) { aaa += sdat[ssrr,g]; }
		var rfc = findnextdate (aaa, ssrr, nind);
		for (var f = 0; f < rfc.length; f++ ) { ttt += rfc[f]; }
	} else {
		for (var u = 0; u < sdat.length[0]; u++) {
			string[] aaa = {};
			for (var g = 0; g < 13; g++) { aaa += sdat[u,g]; }
			var rfc = findnextdate (aaa, u, nind);
			for (var f = 0; f < rfc.length; f++ ) { ttt += rfc[f]; }
		}
	}

// putting data into string rows of a 1d array for sorting... 
// this is a dumb workaround to vala's limited array handling

	for (var u = 0; u < ttt.length; u++) {
		var rfd = ttt[u];
		var ch = new char[9];
		rfd.nxd.strftime(ch,"%y %m %d");
		rrr += "".concat(
			((string) ch),
			" : ",
			rfd.cat,
			" : ",
			("%.2lf").printf(rfd.amt),
			" : ",
			rfd.dsc,
			";",
			(("%d").printf(rfd.frm)),
			";",
			rfd.cco,
			";",
			rfd.gco,
			";",
			rfd.grp
		);
	}

// sorting

	GLib.qsort_with_data<string> (rrr, sizeof(string), (a, b) => GLib.strcmp (a, b));
	fdat = new string[rrr.length,9];
	double rut = 0.0;

	for (var r = 0; r < rrr.length; r++) {
		if (rrr[r] != null || rrr[r].length > 0) {
			string[] fsb = rrr[r].split(";");
			string[] sbs = fsb[0].split(":");
			var atn = sbs[2].strip();
			if (atn != null || atn.length > 0) {
				rut = rut + double.parse(atn);
			}
			fdat[r,0] = sbs[0].strip();			// date
			fdat[r,1] = sbs[3].strip();			// description
			fdat[r,2] = sbs[2].strip();			// amount
			fdat[r,3] = sbs[1].strip();			// cat
			fdat[r,4] = fsb[4];					// group
			fdat[r,5] = ("%.2lf").printf(rut);	// runningtotal
			fdat[r,6] = fsb[2];					// catcolor
			fdat[r,7] = fsb[3];					// groupcolor
			fdat[r,8] = fsb[1];					// owner
		}
	}
	if (spewin) { print("%sforecast done\n",tabi); }
}

string[] rendersetuplisttext (int ind) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	var tabni = ("%-" + (ind + 4).to_string() + "s").printf("");
	if (spewin) {
		print("%srendersetuplist started...\n",tabi);
	}

	string[] ooo = {};

	for (var s = 0; s < sdat.length[0]; s++) {
		string clr = sdat[s,12];
		rgba = Gdk.RGBA();
		if (rgba.parse(clr) == false) { clr = txtc; rgba.parse(clr); }
		if (ssrr == s) { clr = rowc; rgba.parse(clr); }
		ooo += "".concat(d[s,10], ";", clr);
	}
	if (spewin) { print("%srendersetuplist completed.\n", tabi); }
	return ooo;
}

string[] getchoicelist(int idx, int ind) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	if (spewin) {
		print("%sgetchoicelist started\n", tabi);
	}
	var whatupdate = doupdate;
	doupdate = false;
	var doit = true;
	string[] ooo = {};
	int[] qqq = {};
	for (var r = 0; r < sdat.length[0]; r++) {
		doit = true;
		if (ooo.length > 0) {
			for (var i = 0; i < ooo.length; i++) {
				if (ooo[i] == sdat[r,idx]) {
					qqq += i;
					doit = false; break;
				}
			}
		}
		if (doit) {
			qqq += ooo.length;
			ooo += sdat[r,idx];
		}
	}

// set colors per found gtoup/category if they're blank
// BG= RGBA(0.103486,0.229469,0.310458,1.000000) #1A3B4F (26, 59, 79)
// FG= RGBA(0.333333,0.739130,1.000000,1.000000) #55BDFF (85, 189, 255)

	for (var r = 0; r < sdat.length[0]; r++) {
		//Random.set_seed(q[r]);
		int cidx = idx + 3;
		if (sdat[r,cidx].strip() == "") {
			if (cidx == 11) { sdat[r,cidx] = txtc; }
			if (cidx == 12) { sdat[r,cidx] = txtc; }
		}
	}
	if (ooo.length == 0) { ooo += "none"; }
	doupdate = whatupdate;
	if (spewin) { print("%sgetchoicelist completed.\n", tabi); }
	return ooo;
}

void adjustgroupcolor ( double rrr, double ggg, double bbb, string hhh, bool x, int ind ) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	if (spewin) {
		print("%sadjustgroupcolor started...\n",tabi);
	}
	var nind = ind + 4;

// data, setuplist, hex-entry, red slider val, green slider val, blue slider val, do hex-entry

	string hx = htmlcol (((int) rrr), ((int) ggg), ((int) bbb), nind);
	if (x) { hx = hhh; }
	rgba = Gdk.RGBA();
	if (rgba.parse(hx) == false) { hx = txtc); rgba.parse(hx); }
	if (x == false) { doup = false; hhhh.text = hx; doup = true; }
	sdat[ssrr,12] = hx;

// update dat, matching group only

	for (var w = 0; w < sdat.length[0]; w++) {
		if (sdat[w,9] == sdat[ssrr,9]) {
			sdat[w,12] = hx;
		}
	}

// also update forecasted, matching group only

	for (var w = 0; w < fdat.length[0]; w++) {
		if (fdat[w,4] == sdat[ssrr,9]) {
			fdat[w,7] = hx;
		}
	}
	if (tcol.get_active()) {
		// add ui updates here...
	}
}

void selectarow (int ind) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	var nind = ind + 4;
	var tabni = ("%-" + nind.to_string() + "s").printf("");
	if (spewin) {
		print("%sselectarow started...\n",tabi);
		print("%sselectarow:\tselected rule is %d\n",tabni,i);
		var bsr = b.get_selected_row();
		var bsi = bsr.get_index();
		print("%sselectarow:\tcurrent selected row is %d\n",tabni,bsi);
	}

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
	string[] ccl = getchoicelist(dat, 8, nind);
	catc.remove_all();
	for (var j = 0; j < ccl.length; j++) {
		catc.append_text(ccl[j]);
		if (ccl[j] == dat[i,8]) { catc.set_active(j); }
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
	rendersetuplist(dat, i, b, cc, nind);
	doupdate = true;
	if (spewin) { print("%sselectarow completed.\n", tabi); }
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

	public FTW (Gtk.Application fulltardie) {
		Object (application: fulltardie);
	}

// anyway, the ui:

	construct {
		textcolor = "#55BDFF";
		rowcolor = "#1A3B4F";
		ttcolor = "#112633";

		Gdk.ScrollDirection scrolldir;
		Gtk.CssProvider tcsp = new Gtk.CssProvider();	// color toggle css
		Gtk.CssProvider icsp = new Gtk.CssProvider();	// iso toggle css

// vars used inside of window

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

// window

		this.title = "fulltardie";
		this.set_default_size(360, 720);
		this.close_request.connect((e) => { print("yeh bye\n"); return false; });
		this.set_margin_top(10);
		this.set_margin_bottom(10);
		this.set_margin_start(10);
		this.set_margin_end(10);

// header

		Gtk.Label titl = new Gtk.Label("fulltardie");
		Gtk.HeaderBar tbar = new Gtk.HeaderBar();
		tbar.show_title_buttons  = true;
		tbar.set_title_widget(titl);
		this.set_titlebar (tbar);

// load/save menus

		Gtk.MenuButton mlod = new Gtk.MenuButton();
		Gtk.MenuButton msav = new Gtk.MenuButton();
		mlod.icon_name = "document-save";
		msav.icon_name = "document-open-symbolic";
		Gtk.Button bsav = new Button.with_label("save");
		Gtk.Popover lpop = new Gtk.Popover();
		Gtk.Popover spop = new Gtk.Popover();
		Gtk.Box sbox = new Gtk.Box(VERTICAL,10);
		Gtk.Box lbox = new Gtk.Box(VERTICAL,5);
		sbox.margin_start = 10;
		sbox.margin_end = 10;
		sbox.margin_top = 10;
		sbox.margin_bottom = 10;
		lbox.margin_start = 10;
		lbox.margin_end = 10;
		lbox.margin_top = 10;
		lbox.margin_bottom = 10;
		Gtk.Entry escn = new Entry();
		escn.text = "default";
		sbox.append(escn);
		sbox.append(bsav);
		spop.set_child(sbox);
		lpop.set_child(lbox);
		mlod.popover = lpop;
		msav.popover = spop;
		tbar.pack_start(mlod);
		tbar.pack_end(msav);


// setup-list view for rules

		var lsls = new Label(null);
		lsls.set_markup("<b><big>setup</big></b>");
		slst = new Gtk.DrawingArea();
		slst.margin_top = 10;
		slst.margin_bottom = 10;
		slst.margin_start = 10;
		slst.margin_end = 10;

// name

		Gtk.edsc = new Gtk.Entry();
		edsc.text = dat[0,10];
		edsc.hexpand = true;

		ptop = new Gtk.Box(HORIZONTAL,10);
		ptop.append(edsc);

// controls

		tiso = new Gtk.ToggleButton.with_label("ISO");
		Gtk.Button badd = new Gtk.Button.with_label("+");
		Gtk.Button brem = new Gtk.Button.with_label("-");

// group color controls

		xcol = new Gtk.Box (VERTICAL,10);
		xcol.set_size_request (200,10);
		rrrr = new Gtk.Scale.with_range(HORIZONTAL, 0, 255, 100);
		rrrr.set_value(26);
		gggg = new Gtk.Scale.with_range(HORIZONTAL, 0, 255, 100);
		gggg.set_value(59);
		bbbb = new Gtk.Scale.with_range(HORIZONTAL, 0, 255, 100);
		bbbb.set_value(79);
		hhhh = new Entry();
		hhhb.text = "#1A3B4F";
		hhhb.set_width_chars(8);
		xcol.append(rrrr);
		xcol.append(gggg);
		xcol.append(bbbb);
		xcol.append(hhhh);

// group color button

		string hxxx = "";
		if (sdat.length[0] > 0) { hxxx = sdat[0,12]; }
		rgba = Gdk.RGBA();
		if (rgba.parse(h) == false) {
			rgba.parse(textcolor);
			hxxx = textcolor();
		}

// color swatch, retains css for now, replace with a suitable alternative

		tcol = new Gtk.ToggleButton.with_label("▼");
		string cssx = ".col { background: %s%s; }".printf(h,"55");
		tcsp.load_from_data (cssx.data);
		tcol.get_style_context().add_provider(tcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		tcol.get_style_context().add_class("col");

// assemble controls

		pctr = new Gtk.Box(HORIZONTAL,10);
		pctr.append(badd);
		pctr.append(brem);
		pctr.append(tiso);
		pctr.append(tcol);

// rule component combos

		cevr = new ComboBoxText();
		for (var j = 0; j < evr.length; j++) {cevr.append_text(evr[j]);}
		cevr.set_active(0);
		var cnth = new ComboBoxText();
		for (var j = 0; j < nth.length; j++) {cnth.append_text(nth[j]);}
		cnth.set_active(0);
		var cwkd = new ComboBoxText();
		for (var j = 0; j < wkd.length; j++) {cwkd.append_text(wkd[j]);}
		cwkd.set_active(0);
		var cfdy = new ComboBoxText();
		for (var j = 0; j < fdy.length; j++) {cfdy.append_text(fdy[j]);}
		cfdy.set_active(0);
		var cmth = new ComboBoxText();
		for (var j = 0; j < mth.length; j++) {cmth.append_text(mth[j]);}
		cmth.set_active(0);
		var cfmo = new ComboBoxText();
		for (var j = 0; j < fmo.length; j++) {cfmo.append_text(fmo[j]);}
		cfmo.set_active(0);

/* 
// not supported in gtk4:
		cevr.set_wrap_width(4);
		cnth.set_wrap_width(4);
		cwkd.set_wrap_width(2);
		cfdy.set_wrap_width(2);
		cmth.set_wrap_width(2);
		cfmo.set_wrap_width(2); 
*/

		Gtk.Adjustment yadj = new Gtk.Adjustment(2021,1990,2100,1,5,1);
		yadj.set_value((int) (GLib.get_real_time() / 31557600000000) + 1970);
		sfye = new Gtk.SpinButton(yadj,1,0);

// rule component flowbox

		pmid = new Gtk.FlowBox();
		pmid.set_orientation(Orientation.HORIZONTAL);
		pmid.min_children_per_line = 1;
		pmid.max_children_per_line = 7;
		pmid.insert(sfye,0);
		pmid.insert(cfmo,0);
		pmid.insert(cmth,0);
		pmid.insert(cfdy,0);
		pmid.insert(cwkd,0);
		pmid.insert(cnth,0);
		pmid.insert(cevr,0);


// group 

		Gtk.Label lgrp = new Label("grp");
		lgrp.set_halign(START);
		lgrp.set_max_width_chars(8);
		lgrp.set_hexpand(false);
		lgrp.set_size_request(10,10);
		lgrp.margin_end = 10;
		cgrp = new ComboBoxText.with_entry();
		cgrp.set_halign(START);
		var egrp = (Entry) cgrp.get_child();
		egrp.set_halign(START);
		egrp.set_width_chars(8);
		egrp.set_hexpand(false);

// category

		Gtk.Label lcat = new Label("cat");
		lcat.set_halign(START);
		lcat.set_max_width_chars(8);
		lcat.set_hexpand(false);
		lcat.set_size_request(10,10);
		lcat.margin_end = 10;
		ccat = new ComboBoxText.with_entry();
		var ecat = (Entry) ccat.get_child();
		ecat.set_halign(START);
		ecat.set_width_chars(8);
		ecat.set_hexpand(false);

// amount

		Gtk.Label lamt = new Label("amt");
		lamt.set_halign(START);
		lamt.set_max_width_chars(8);
		lamt.set_hexpand(false);
		lamt.set_size_request(10,10);
		lamt.margin_end = 10;
		Gtk.Adjustment aadj = new Gtk.Adjustment(0.0,-100000,100000.0,10.0,100.0,1.0);
		samt = new Gtk.SpinButton(aadj,1.0,2);

// group container

		Gtk.Box xgrp = new Gtk.Box(HORIZONTAL,0);
		xgrp.append(lgrp);
		xgrp.append(cgrp);
		xgrp.set_halign(START);
		xgrp.set_size_request(10,10);
		xgrp.set_hexpand(false);

// category container

		Gtk.Box xcat = new Gtk.Box(HORIZONTAL,0);
		xcat.append(lcat);
		xcat.append(ccat);
		xcat.set_halign(START);
		xcat.set_size_request(10,10);
		xcat.set_hexpand(false);

// group container

		Gtk.Box xamt = new Gtk.Box(HORIZONTAL,0);
		xamt.append(lamt);
		xamt.append(samt);
		xamt.set_halign(START);
		xamt.set_size_request(10,10);
		xamt.set_hexpand(false);

// lower flowbox

		plow = new Gtk.FlowBox();
		plow.set_orientation(Orientation.HORIZONTAL);
		plow.min_children_per_line = 1;
		plow.max_children_per_line = 10;
		plow.insert(xgrp,0);
		plow.insert(xcat,1);
		plow.insert(xamt,2);
		plow.homogeneous = true;
		plow.column_spacing = 10;

// assemble params

		Gtk.Grid pgrd = new Gtk.Grid();
		pgrd.margin_top = 10;
		pgrd.margin_bottom = 10;
		pgrd.margin_start = 10;
		pgrd.margin_end = 80;
		pgrd.row_spacing = 10;
		pgrd.attach(ptop,0,0,1,1);
		pgrd.attach(pctr,0,1,1,1);
		pgrd.attach(xcol,0,2,1,1);
		pgrd.attach(pmid,0,3,1,1);
		pgrd.attach(plow,0,4,1,1);

		Gtk.ScrolledWindow xscr = new Gtk.ScrolledWindow();
		xscr.set_child(pgrd);
		xscr.margin_top = 10;

// foecast list

		var lfcl = new Label(null);
		lfcl.set_markup("<b><big>graph</big></b>");
		flst = new Gtk.DrawingArea();
		flst.margin_top = 10;
		flst.margin_bottom = 10;
		flst.margin_start = 10;
		flst.margin_end = 10;

// graph page

		var limg = new Label(null);
		limg.set_markup("<b><big>graph</big></b>");
		gimg = new Gtk.DrawingArea();

// notebook

		tabp = new Gtk.Notebook();
		tabp.set_show_border(false);
		tabp.set_tab_pos(BOTTOM);
		tabp.append_page(slst, lsls);
		tabp.append_page(flst, lfcl);
		tabp.append_page(gimg, limg);
		tabp.margin_bottom = 10;

// separator

		Gtk.Paned hdiv = new Gtk.Paned(VERTICAL);
		hdiv.start_child = tabp;
		hdiv.end_child = pgrd;
		hdiv.resize_end_child = true;
		hdiv.position = 450;
		hdiv.wide_handle = true;

// add ui to window

		this.set_child(hdiv);
		doup = true;

// initialize

		selectarow(0,4);
		forecasted = forecast(4);


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

		tabp.switch_page.connect ((page, page_num) => {
			if (doup) {
				var pix = ((int) page_num);
				if (spewin) {
					print("tabp.switch_page.connect:\tswitching to tab: %d\n", pix);
					print("tabp.switch_page.connect:\tselected rule is: %d\n", ssrr);
				}
				if (pix == 0) { slst.queue_draw(); }
				if (pix == 1) { flst.queue_draw(); }
				if (pix == 2) { gimg.queue_draw(); }
			}
		});

/////////////////////////////////////////////////
//                                             //
//    re-forcasting and re-rendering params    //
//                                             //
/////////////////////////////////////////////////

		cevr.changed.connect(() => {
			if (doup) { 
				var n = cevr.get_active();
				if (spewin) { print("cevr.changed.connect:\tselecting item: %d\n", n); }
				dat[ssrr,0] = n.to_string();
				forecasted = forecast(4);
				if (pix == 1) { flst.queue_draw(); }
				if (pix == 2) { gimg.queue_draw(); }
			}
		});
		cnth.changed.connect(() => {
			if (doup) {
				var n = cnth.get_active();
				if (spewin) { print("cnth.changed.connect:\tselecting item: %d\n", n); }
				dat[ssrr,1] = n.to_string();
				forecasted = forecast(4);
				if (pix == 1) { flst.queue_draw(); }
				if (pix == 2) { gimg.queue_draw(); }
			}
		});
		cwkd.changed.connect(() => {
			if (doup) {
				var n = cwkd.get_active();
				if (spewin) { print("cwkd.changed.connect:\tselecting item: %d\n", n); }
				dat[ssrr,2] = n.to_string();
				var ffs = int.parse(dat[ssrr,2]);
				if (ffs > 7) {
					if (plow.get_child_at_index(1).get_child() == cnth) {
						plow.remove(plow.get_child_at_index(1));
						plow.remove(plow.get_child_at_index(1));
						plow.insert(cwkd,1);
						plow.insert(cnth,2);
					}
				} else {
					if (plow.get_child_at_index(1).get_child() == cwkd) {
						plow.remove(plow.get_child_at_index(1));
						plow.remove(plow.get_child_at_index(1));
						plow.insert(cnth,1);
						plow.insert(cwkd,2);
					}
				}
				forecasted = forecast(4);
				if (pix == 1) { flst.queue_draw(); }
				if (pix == 2) { gimg.queue_draw(); }
			}
		});
		cfdy.changed.connect(() => {
			if (doup) {
				ind = 4;
				var n = cfdy.get_active();
				s = setuplist.get_selected_row();
				r = 0;
				if (s != null) { 
					if (spewin) { print("cfdy.changed.connect:\tselecting item: %d\n", n); }
					r = s.get_index();
					dat[r,3] = n.to_string();
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), ssrr, forecastrowcssprovider, ind);
				}
			}
		});
		cmth.changed.connect(() => {
			if (doup) {
				ind = 4;
				var n = cmth.get_active();
				s = setuplist.get_selected_row();
				r = 0;
				if (s != null) { 
					if (spewin) { print("cmth.changed.connect:\tselecting item: %d\n", n); }
					r = s.get_index();
					dat[r,4] = n.to_string();
					int ffs = int.parse(dat[r,5]);
// change from-month to of-month if this combo is zeroed - so the rule makes mroe sense in english
					doup = false;
					cfmo.remove_all();
					if (int.parse(dat[r,4]) == 0) {
						for (var j = 0; j < omo.length; j++) { cfmo.append_text(omo[j]); }
					} else {
						for (var j = 0; j < fmo.length; j++) { cfmo.append_text(fmo[j]); }
					}
					cfmo.set_active(ffs);
					doup = true;
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), ssrr, forecastrowcssprovider, ind);
				}
			}
		});
		cfmo.changed.connect(() => {
			if (doup) {
				ind = 4;
				var n = cfmo.get_active();
				s = setuplist.get_selected_row();
				r = 0;
				if (s != null) {
					if (spewin) { print("cfmo.changed.connect:\tselecting item: %d\n", n); }
					r = s.get_index();
					dat[r,5] = n.to_string();
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), ssrr, forecastrowcssprovider, ind);
				}
			}
		});
		fye.changed.connect(() => {
			if (doup) {
				ind = 4;
				s = setuplist.get_selected_row();
				r = 0;
				if (s != null) { 
					var v = fye.get_value();
					if (spewin) { print("fye.changed.connect:\tchanging value to: %f\n", v); }
					r = s.get_index();
					if (v == ((int) (GLib.get_real_time() / 31557600000000) + 1970)) {
						dat[r,6] = "0";
					} else {
						dat[r,6] = ((string) ("%lf").printf(v));
					}
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), ssrr, forecastrowcssprovider, ind);
				}
			}
		});
		amountspinner.value_changed.connect(() => {
			if (doup) {
				ind = 4;
				s = setuplist.get_selected_row();
				r = 0;
				if (s != null) { r = s.get_index(); }
				if (spewin) { print("amountspinner.value_changed.connect:\tchanging value to: %f\n", amountspinner.get_value()); }
				dat[r,7] =((string) ("%.2lf").printf(amountspinner.get_value()));;
				forecasted = forecast(dat, forecastlistbox, iso.get_active(), ssrr, forecastrowcssprovider, ind);
			}
		});
		iso.toggled.connect(() => {
			if (doup) {
				ind = 4;
				s = setuplist.get_selected_row();
				r = 0;
				if (s != null) {
					if (spewin) { print("iso.toggled.connect:\ttoggling isolate...\n"); }
					r = s.get_index();
					forecasted = forecast(dat, forecastlistbox, iso.get_active(), ssrr, forecastrowcssprovider, ind);
					if (spewin) { print("iso.toggled.connect is redrawing the graph...\n"); }
					gimg.queue_draw ();
				}
			}
		});

//////////////////////////////////
//                              //
//   non-reforcasting params    //
//                              //
//////////////////////////////////

		groupcombo.changed.connect(() => {
			if (doup) {
				ind = 4;
				var n = groupcombo.get_active_text().strip();
				s = setuplist.get_selected_row();
				r = 0;
				if (s != null) {
					if (spewin) { print("groupcombo.changed.connect:\tselecting item: %s\n", n); }
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
						doup = false;
						hhh.text = uc;
						rrr.adjustment.value = ((double) ((int) (gc.red * 255.0)));
						ggg.adjustment.value = ((double) ((int) (gc.green * 255.0)));
						bbb.adjustment.value = ((double) ((int) (gc.blue * 255.0)));
						//groupcolorbox.visible = true;
						doup = true;
					}
					colcssprovider.load_from_data (colcsstxt.data);

// save group color, re-render the setup list

					dat[r,12] = uc;
					if (tabp.get_current_page() == 0) { rendersetuplist(dat, ssrr, setuplist, setuprowcssprovider, ind); }
					for  (int i = 0; i < forecasted.length[0]; i++) {
						if (int.parse(forecasted[i,8]) == r) {
							forecasted[i,4] = n;
							forecasted[i,7] = uc;
						}
					}
					if (tabp.get_current_page() == 1) {
						renderforecast(forecasted, forecastlistbox, ind);
					}
					if (tabp.get_current_page() == 2) {
						renderforecast(forecasted, forecastlistbox, ind);
						gimg.queue_draw ();
					}
				}
			}
		});
		catcombo.changed.connect(() => {
			if (doup) {
				ind = 4;
				var n = catcombo.get_active_text();
				s = setuplist.get_selected_row();
				r = 0;
				if (s != null) {
					if (spewin) { print("catcombo.changed.connect:\tselecting item: %s\n", n); }
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
			if (doup) {
				ind = 4;
				var n = ee.text;
				s = setuplist.get_selected_row();
				r = 0;
				if (s != null) {
					doup = false;
					if (spewin) { print("ee.activate.connect:\ttext changed to: %s\n", n); }
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

					if (spewin) { print("ee.activate.connect:\ttext changed to: %s\n", n); }
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
					doup = true;
				}
			}
		});
		vv = (Entry) groupcombo.get_child();
		vv.activate.connect(() => {
			if (doup) {
				ind = 4;
				var n = vv.text;
				s = setuplist.get_selected_row();
				r = 0;
				if (s != null) {
					doup = false;
					if (spewin) { print("vv.activate.connect:\tselecting item: %s\n", n); }
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
						doup = false;
						hhh.text = uc;
						rrr.adjustment.value = ((double) ((int) (gc.red * 255.0)));
						ggg.adjustment.value = ((double) ((int) (gc.green * 255.0)));
						bbb.adjustment.value = ((double) ((int) (gc.blue * 255.0)));
						//groupcolorbox.visible = true;
						doup = true;
					}
					colcssprovider.load_from_data (colcsstxt.data);

// save group color, re-render the setup list

					dat[r,12] = uc;
					if (tabp.get_current_page() == 0) { rendersetuplist(dat, ssrr, setuplist, setuprowcssprovider, ind); }
					for  (int i = 0; i < forecasted.length[0]; i++) {
						if (int.parse(forecasted[i,8]) == r) {
							forecasted[i,4] = n;
							forecasted[i,7] = uc;
						}
					}
					if (tabp.get_current_page() == 1) {
						renderforecast(forecasted, forecastlistbox, ind);
					}
					if (tabp.get_current_page() == 2) {
						renderforecast(forecasted, forecastlistbox, ind);
						gimg.queue_draw ();
					}
					doup = true;
				}
			}
		});
		dsc.changed.connect(() => {
			if (doup) {
				ind = 4;
				string d = dsc.text.strip();
				if (dsc.text != null) {
					if (d != "") {
						doup = false;
						if (spewin) { print("dsc.changed.connect:\tchanging text to: %s\n", d); }
						dat[ssrr,10] = d;
						if (tabp.get_current_page() == 0) {
							rendersetuplist(dat, ssrr, setuplist, setuprowcssprovider, ind);
						}
						if (tabp.get_current_page() == 1) {
							for (int f = 0; f < forecasted.length[0]; f++) {
								if ( int.parse(forecasted[f,8]) == ssrr ) {
					 				forecasted[f,1] = d;
								}
							}
							renderforecast(forecasted, forecastlistbox, ind);
						}
						doup = true;
					}
				}
			}
		});

// colors

		col.toggled.connect(() => {
			string hxgc = dat[ssrr,12];
			rgba = Gdk.RGBA();
			if (rgba.parse(hxgc) == false) { rgba.parse(txtc); hxgc = txtc; }
			if (tcol.get_active()) { 
				tcol.set_label("");
				if (spewin) { print("col.toggled.connect:\ttrue\n"); }
				cssx = ".col { background: %s%s; }".printf(hxgc,"FF");
				doup = false;
				hhh.text = hxgc;
				rrr.adjustment.value = ((double) ((int) (rgba.red * 255.0)));
				ggg.adjustment.value = ((double) ((int) (rgba.green * 255.0)));
				bbb.adjustment.value = ((double) ((int) (rgba.blue * 255.0)));
				xcol.visible = true;
				doup = true;
			} else { 
				tcol.set_label("▼");
				cssx = ".col { background: %s%s; }".printf(hxgc,"55");
				xcol.visible = false;
				if (spewin) { print("col.toggled.connect:\tfalse\n"); }
			}
			tcsp.load_from_data (cssx.data);
		});
		rrr.adjustment.value_changed.connect(() => {
			if (doup) {
				doup = false;
				if (spewin) { print("rrr.adjustment.value_changed.connect:\tchanging value to: %f\n", rrr.adjustment.value); }
				adjustgroupcolor(rrr.adjustment.value, ggg.adjustment.value, bbb.adjustment.value, hhh.text; false, 4);
				doup = true;
				if (pix == 0) { slst.queue_draw(); }
				if (pix == 1) { flst.queue_draw(); }
				if (pix == 2) { gimg.queue_draw(); }
			}
		});
		ggg.adjustment.value_changed.connect(() => {
			if (doup) {
				ind = 4;
				doup = false;
				if (spewin) { print("ggg.adjustment.value_changed.connect:\tchanging value to: %f\n", bbb.adjustment.value); }
				adjustgroupcolor(dat, forecasted, col, colcssprovider, ssrr, hhh, rrr.adjustment.value, ggg.adjustment.value, bbb.adjustment.value, false, ind);
				if (tabp.get_current_page() == 0) {
					rendersetuplist(dat, ssrr, setuplist, setuprowcssprovider, ind);
				}
				if (tabp.get_current_page() == 1) {
					renderforecast(forecasted, forecastlistbox, ind);
				}
				if (tabp.get_current_page() == 2) {
					renderforecast(forecasted, forecastlistbox, ind);
					gimg.queue_draw ();
				}
				doup = true;
			}
		});
		bbb.adjustment.value_changed.connect(() => {
			if (doup) {
				ind = 4;
				doup = false;
				if (spewin) { print("bbb.adjustment.value_changed.connect:\tchanging value to: %f\n", bbb.adjustment.value); }
				adjustgroupcolor(dat, forecasted, col, colcssprovider, ssrr, hhh, rrr.adjustment.value, ggg.adjustment.value, bbb.adjustment.value, false, ind);
				if (tabp.get_current_page() == 0) {
					rendersetuplist(dat, ssrr, setuplist, setuprowcssprovider, ind);
				}
				if (tabp.get_current_page() == 1) {
					renderforecast(forecasted, forecastlistbox, ind);
				}
				if (tabp.get_current_page() == 2) {
					renderforecast(forecasted, forecastlistbox, ind);
					gimg.queue_draw ();
				}
				doup = true;
			}
		});
		hhh.changed.connect (() => {
			if (doup) {
				ind = 4;
				if (hhh.text.strip() != "") {
					g = Gdk.RGBA();
					if (g.parse(hhh.text)) {
						doup = false;
						if (spewin) { print("hhh.changed.connect:\tchanging value to: %s\n", hhh.text); }
						adjustgroupcolor(dat, forecasted, col, colcssprovider, ssrr, hhh, rrr.adjustment.value, ggg.adjustment.value, bbb.adjustment.value, true, ind);
						if (tabp.get_current_page() == 0) {
							rendersetuplist(dat, ssrr, setuplist, setuprowcssprovider, ind);
						}
						if (tabp.get_current_page() == 1) {
							renderforecast(forecasted, forecastlistbox, ind);
						}
						if (tabp.get_current_page() == 2) {
							renderforecast(forecasted, forecastlistbox, ind);
							gimg.queue_draw ();
						}
						rrr.adjustment.value = ((double) ((int) (g.red * 255.0)));
						ggg.adjustment.value = ((double) ((int) (g.green * 255.0)));
						bbb.adjustment.value = ((double) ((int) (g.blue * 255.0)));
						doup = true;
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
					if (spewin) { print("savebtn.clicked.connect:\tsaving scenario: %s\n", scene.text); }
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
						if (spewin) { print ("Error: couldn't make outputstream.\n\t%s\n", e.message); }
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
			if (spewin) { print("loadit.clicked.connect:\tfetching saved scenarios...\n"); }
			ind = 4;
			//lpopbox.foreach ((element) => lpopbox.remove (element));
			while (lpopbox.get_first_child() != null) {
				if (spewin) { print("loadit:\tremoving old popmenu item...\n"); }
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
								if (spewin) { print ("Error: couldn't load file.\n\t%s\n", e.message); }
							}
							if (allgood) {
								string tt = ss.read_line();
								if (tt != null) {
									if (spewin) { print("    muh.clicked.connect:\tloading scenario: %s\n",nn); }
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
										doup = false; 
										dat = tdat;
										//setuplist.foreach ((element) => setuplist.remove (element));
										while (setuplist.get_first_child() != null) {
											if (spewin) { print("loadit:\tremoving old list item...\n"); }
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
										ssrr = 0;
										var row = setuplist.get_row_at_index(0);
										doup = true;
										selectarow (dat, ssrr, setuplist, pmid, cevr, cnth, cwkd, cfdy, cmth, cfmo, dsc, fye, amountspinner, groupcombo, catcombo, col, colcssprovider, rrr, ggg, bbb, hhh, groupcolorbox, setuprowcssprovider, ind);
										forecasted = forecast(dat,forecastlistbox, iso.get_active(), 0, forecastrowcssprovider, ind);
										gimg.queue_draw ();
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
				if (spewin) { print("addrule.clicked.connect:\tadding new rule...\n"); }
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
					if (spewin) { print("loadit:\tremoving old list item...\n"); }
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
				ssrr = (dat.length[0] - 1);
				var row = setuplist.get_row_at_index((dat.length[0] - 1));
				selectarow (dat, ssrr, setuplist, pmid, cevr, cnth, cwkd, cfdy, cmth, cfmo, dsc, fye, amountspinner, groupcombo, catcombo, col, colcssprovider, rrr, ggg, bbb, hhh, groupcolorbox, setuprowcssprovider, ind);
				forecasted = forecast(dat,forecastlistbox, iso.get_active(), (dat.length[0] - 1), forecastrowcssprovider, ind);
				gimg.queue_draw ();
			}
		});
		rms.clicked.connect (() =>  {
			s = setuplist.get_selected_row();
			var w = 0;
			var n = dat.length[0];
			if (s != null) {
				ind = 4;
				w = s.get_index();
				if (spewin) { print("remrule.clicked.connect:\tremoving rule: %s\n",dat[w,9]); }
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
					if (spewin) { print("loadit:\tremoving old list item...\n"); }
  					setuplist.remove(setuplist.get_first_child());
				}
				for (var e = 0; e < dat.length[0]; e++) {
					var ll = new Label(dat[e,10]);
					ll.xalign = ((float) 0.0);
					setuplist.insert(ll,-1);
				}
				setuplist.show();
				ssrr = (dat.length[0] - 1);
				var row = setuplist.get_row_at_index((dat.length[0] - 1));
				selectarow (dat, ssrr, setuplist, pmid, cevr, cnth, cwkd, cfdy, cmth, cfmo, dsc, fye, amountspinner, groupcombo, catcombo, col, colcssprovider, rrr, ggg, bbb, hhh, groupcolorbox, setuprowcssprovider, ind);
				forecasted = forecast(dat,forecastlistbox, iso.get_active(), (dat.length[0] - 1), forecastrowcssprovider, ind);
				gimg.queue_draw ();
			}
		});

//////////////////////////
//                      //
//    graph rendering   //
//                      //
//////////////////////////

		gimg.set_draw_func((da, ctx, daw, dah) => {
			//print("\ngimg.draw: started...\n");
			if (drawit) {
				var presel = ssrr;
				var csx = gimg.get_allocated_width();
				var csy = gimg.get_allocated_height();

// graph coords

				sizx = oldgraphsize[0];
				sizy = oldgraphsize[1];
				if (graphzoom || graphscroll) {
					sizx = (oldgraphsize[0] + (mousemove[0] - mousedown[0]));
					sizy = (oldgraphsize[1] + (mousemove[1] - mousedown[1]));
				}
				//print("gimg.draw: \tsizx = %f\n", sizx);
				//print("gimg.draw: \tmousedown[0] = %f\n", mousedown[0]);
				//print("gimg.draw: \tmousemove[0] = %f\n", mousemove[0]);
				//print("gimg.draw: \toldgraphsize[0] = %f\n", oldgraphsize[0]);
				//print("gimg.draw: \toldgraphoffset[0] = %f\n", oldgraphoffset[0]);
				//print("gimg.draw: \toldmousedown[0] = %f\n", oldmousedown[0]);
				//print("gimg.draw: \ttargx = %f\n", targx);
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
									ssrr = int.parse(forecasted[i,8]);
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
					if (ssrr == int.parse(forecasted[i,8])) { 
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
					var ixx = double.min(double.max(20,(targx - (ibx * 0.5))),(gimg.get_allocated_width() - (ibx + 20)));
					var ixy = double.min(double.max(20,(targy + 20)),(gimg.get_allocated_height() - 50));
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

				if (ssrr >= 0 && ssrr != presel) {
					var row = setuplist.get_row_at_index(ssrr);
					if (row != null) {
						selectarow (dat, ssrr, setuplist, pmid, cevr, cnth, cwkd, cfdy, cmth, cfmo, dsc, fye, amountspinner, groupcombo, catcombo, col, colcssprovider, rrr, ggg, bbb, hhh, groupcolorbox, setuprowcssprovider, ind);
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
			//print("gimg.draw: complete\n\n");
			//return true;
		});

////////////////////////////
//                        //
//    graph interaction   //
//                        //
////////////////////////////

		/*
		gimg.add_events (Gdk.EventMask.TOUCH_MASK);
		gimg.add_events (Gdk.EventMask.BUTTON_PRESS_MASK);
		gimg.add_events (Gdk.EventMask.BUTTON2_MOTION_MASK);
		gimg.add_events (Gdk.EventMask.BUTTON3_MOTION_MASK);
		gimg.add_events (Gdk.EventMask.BUTTON_RELEASE_MASK);
		gimg.add_events (Gdk.EventMask.POINTER_MOTION_MASK);
		gimg.add_events (Gdk.EventMask.SCROLL_MASK);
		*/

		Gtk.GestureClick touchtap = new Gtk.GestureClick();
		Gtk.GestureDrag touchpan = new Gtk.GestureDrag();

		touchtap.set_button(Gdk.BUTTON_PRIMARY);
		touchpan.set_button(Gdk.BUTTON_PRIMARY);

		gimg.add_controller (touchtap);
		gimg.add_controller (touchpan);

		touchtap.pressed.connect((event, n, x, y) => {
			ind = 4;
			if (spewin) { print("touchtap.pressed.connect\n"); }
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
			if (spewin) { print("touchtap.released.connect\n"); }
			graphzoom = false;
			graphpan = false;
			graphscroll = false;
			if (graphpick) { 
				gimg.queue_draw(); 
			}
			oldgraphsize = {sizx, sizy};
			oldgraphoffset = {posx, posy};
			oldmousedown = {targx, targy};
		});
		touchpan.drag_begin.connect ((event, x, y) => {
				if (spewin) { print("touchpan_drag_begin\n"); }
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
			gimg.queue_draw();
		});
		touchpan.drag_end.connect(() => {
			if (spewin) { print("touchpan_drag_end\n"); }
			graphpick = false;
			graphpan = false;
			graphzoom = false;
			oldgraphsize = {sizx, sizy};
			oldgraphoffset = {posx, posy};
			oldmousedown = {targx, targy};
		});
		/*
		gimg.button_press_event.connect ((event) => {
			ind = 4;
			print("gimg.button_press_event.connect\n");
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
		gimg.motion_notify_event.connect ((event) => {
			ind = 4;
			if (graphzoom == false && graphpan == false && graphpick == false) { mousedown = {event.x, event.y}; }
			mousemove = {event.x, event.y};
			if (graphzoom || graphpan) {
				gimg.queue_draw();
			}
			return true;
		});
		gimg.scroll_event.connect ((event) => {
			ind = 4;
			scrolldir = UP;
			if (event.scroll.direction == scrolldir) {
				graphscroll = true;
				mousemove = {(mousedown[0] + 50.0), (mousedown[1] + 50.0)};
				gimg.queue_draw();
			}
			scrolldir = DOWN;
			if (event.scroll.direction == scrolldir)  {
				graphscroll = true;
				mousemove = {(mousedown[0] - 50.0), (mousedown[1] - 50.0)};
				gimg.queue_draw();
			}
			return true;
		});

// reset/update stuff on mouse release

		gimg.button_release_event.connect ((event) => {
			ind = 4;
			print("gimg.button_release_event.connect\n");
			graphzoom = false;
			graphpan = false;
			graphscroll = false;
			if (graphpick) { 
				gimg.queue_draw(); 
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
