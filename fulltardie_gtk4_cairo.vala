// gtk4 translation
// by c.p.brown 2021
//
// replacing listboxes with cairo draw-areas
// css roundtripping was lagging, producing incorrect results, and generally retarded
//
// status: broken parameter ui.
// - compiles, runs, renders lists and graph.
// - comboboxes are busted atm: won't scroll, no columns.
// - other features not checked yet.
// - not checked on pinephone yet (probably busted due to gtk4 rendering issues).
//
// TODO
// - [X] function ui input as globals instead of args
// - [X] clean up names
// - [X] clean up events
// - [X] replace listboxes with drawareas
// - [X] make setuplist pre-render function
// - [X] make forecastlist pre-render function
// - [X] convert listrenderers to preprocessors
// - [X] stop touchtap and touchdrag from fighting each other
// - [X] fix: forecast scroll-wheel-triggered draw randomly quitting
// - [X] fix comboboxes: add adaptive colums and scrolling
// - [X] allow x panning in lists where text is cut-off
// - [ ] improve fitting of isolated forecast in lists and graph
// - [ ] double-tap graph bg to fit
// - [ ] always forecast if iso is checked
// - [ ] find a way to do touch-drag without selecting stuff
// - [ ] find new ways to break the damned info bubble and fix them
// - [ ] fatten the divider for touch, or replace it
// - [ ] double-click/tap divider to toggle vertical if window.w > window.h
// - [ ] add checkssrr; minmax it
// - [ ] find new ways to segfault and fix (let wife use it for 5sec)
// - [ ] clean out test code & comments

using Gtk;

// vars used everywhere:

bool				doup;	// toggle ui events
bool				spew;	// toggle diagnostics
bool				hard;	// toggle draw diagnostics
string				txtc;	// text color "#55BDFF"
string				rowc;	// row color "#1A3B4F"
string				tltc;	// tooltip color "#112633"
string[,]			sdat;	// source rule input, user defined sorting
string[,]			fdat;	// forecasted output, always sorted by date
string[,]			ldat;	// formatted setup list for drawing
string[,]			idat;	// formatted forecast list for drawing
Gdk.RGBA			rgba;	// misc. color
int					ssrr;	// current rule

// ui

Gtk.Paned			hdiv;	// top level container(s) 
Gtk.Notebook		tabp;	//   viewer toplever container			checked by selectrule and forecast
Gtk.Label			lsls;	//     label
Gtk.Label			lfcl;	//     label
Gtk.Label			limg;	//     label
Gtk.DrawingArea		slst;	//     setup list						redrawn by various
Gtk.DrawingArea		flst;	//     forecast list					redrawn by various
Gtk.DrawingArea		gimg;	//     graph							redrawn by various
Gtk.ScrolledWindow  xscr;	//   parameter toplevel container
Gtk.Grid			pgrd;	//     parameter layout container
Gtk.Box				ptop;	//       parameter sub container
Gtk.Entry			edsc;	//         rule name					changed by selectrule
Gtk.Box				pctr;	//       parameter sub container
Gtk.Button			badd;	//         add rule
Gtk.Button			brem;	//         rem rule
Gtk.ToggleButton	tiso;	//         isolate toggle				checked by forecast
Gtk.ToggleButton	tcol;	//         color toggle					changed by selectrule
Gtk.Box				xcol;	//       parameter sub container		checked by selectrule, toggled by tcol
Gtk.Scale			rrrr;	//         red							changed by selectrule
Gtk.Scale			gggg;	//         green						changed by selectrule
Gtk.Scale			bbbb;	//         blue							changed by selectrule
Gtk.Entry			hhhh;	//         hex							changed by selectrule
Gtk.FlowBox			pmid;	//       parameter sub container		changed by selectrule
//Gtk.ComboBoxText	cevr;	//         every						changed by selectrule
Gtk.DropDown		cevr;	//         every						changed by selectrule
//Gtk.ComboBoxText	cnth;	//         nth							changed by selectrule
Gtk.DropDown		cnth;	//         nth							changed by selectrule
//Gtk.ComboBoxText	cwkd;	//         weekday						changed by selectrule
Gtk.DropDown		cwkd;	//         weekday						changed by selectrule
//Gtk.ComboBoxText	cfdy;	//         fromday						changed by selectrule
Gtk.DropDown		cfdy;	//         fromday						changed by selectrule
//Gtk.ComboBoxText	cmth;	//         ofmonth						changed by selectrule
Gtk.DropDown		cmth;	//         ofmonth						changed by selectrule
//Gtk.ComboBoxText	cfmo;	//         frommonth					changed by selectrule
Gtk.DropDown		cfmo;	//         frommonth					changed by selectrule
Gtk.SpinButton		sfye;	//         from year					changed by selectrule
Gtk.Adjustment		yadj;	//           value range
Gtk.FlowBox			plow;	//       parameter sub container
Gtk.Box				xgrp;	//         parameter sub container
Gtk.Label			lgrp;	//           label
Gtk.ComboBoxText	cgrp;	//           groups						changed by selectrule
Gtk.Entry			egrp;	//             group text
Gtk.Box				xcat;	//         parameter sub container
Gtk.Label			lcat;	//           label
Gtk.ComboBoxText	ccat;	//           categories					changed by selectrule
Gtk.Entry			ecat;	//             category text
Gtk.Box				xamt;	//         parameter sub container
Gtk.Label			lamt;	//           label
Gtk.SpinButton		samt;	//           amount						changed by selectrule
Gtk.Adjustment		aadj;	//             value range

// utility lists

string[] 			ofmo;	// of month
string[]			frmo;	// from month
string[]			shmo;	// short month list
int[]				ldom;	// last day of each month

// css providers for ui that doesn't need to be draw-area

Gtk.CssProvider 	tcsp;	// color toggle css
Gtk.CssProvider 	icsp;	// iso toggle css

// needed to clear graph info bubble under certain circumstances

int					gi_trns;

// fucking containers within containers within containers within containers...

Gtk.StringList		sfmo;	// used by selectrule
Gtk.StringList		sofm;	// used by selectrule

Gtk.MenuButton		mlod;	// testing

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

int imod (int l, int r) {
	if (l >= 0) { return (l % r); }
	if (l >= -r) { return (l + r); }
	return ((l % r) + r) % r;
}

double dmod (double l, double r) {
	if (l >= 0) { return (l % r); }
	if (l >= -r) { return (l + r); }
	return ((l % r) + r) % r;
}

// check leapyear
// technique is from Rosetta Code, most languages. 

bool lymd(int y) {
	if ((y % 100) == 0 ) { return ((y % 400) == 0); }
	return ((y % 4) == 0);
}

// get weekday index

int iwkd (DateWeekday wd) {
	if (wd == MONDAY) 		{ return 1; }
	if (wd == TUESDAY) 		{ return 2; }
	if (wd == WEDNESDAY) 	{ return 3; }
	if (wd == THURSDAY) 	{ return 4; }
	if (wd == FRIDAY) 		{ return 5; }
	if (wd == SATURDAY) 	{ return 6; }
	if (wd == SUNDAY) 		{ return 7; }
	if (wd == BAD_WEEKDAY) 	{ return 0; }
	return 0;
}

// forecast per item, dat supplied so it can be pre-culled by isolate toggle

nextdate[] findnextdate (string[] dat, int own, int ind) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	if (spew) { print("%sfindnextdate started...\n", tabi); }
	var nind  = ind + 4;
	var nt = new DateTime.now_local();
	var ntd = nt.get_day_of_month();
	var ntm = nt.get_month();
	var nty = nt.get_year();
	var n = Date();
	n.set_dmy((DateDay) ntd, ntm, (DateYear) nty);
	if (spew) { if (n.valid() == false) { print("invalid now date: %d %d %d\n", nty, ntm, ntd); } }
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
	oo.frm = own;
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

	var t = lymd(fye);
	var md = ldom[fmo - 1];
	if (fmo == 2) { if (t) { md = 29; } }

// clamp search-start-day to last day of the month if greater

	if (md < ntd) { ntd = md; }
	var a = Date();
	a.set_dmy((DateDay) ntd, fmo, (DateYear) fye);
	if (spew) { if (a.valid() == false) { print("invalid initial start date: %d %d %d\n", fye, fmo, ntd); } }
	var j =  Date();
	j.set_dmy((DateDay) ntd, fmo, (DateYear) fye);
	var dif = (int) (((a.days_between(n) / 7.0) / 52.0) * 12.0) + 13;
	if (ofm > 0) {
		for (int x = 0; x < dif; x++) {
			var dmo = (a.get_month() == fmo);
			if (ofm > 0) { dmo = (imod((a.get_month() - fmo), ofm) == 0); }
			var ofmcalc = imod((a.get_month() - fmo), ofm);
			if (dmo) {
				var c = 0;
				var mth = md;
				t = lymd(a.get_year());
				md = ldom[a.get_month() - 1];
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
					if (iwkd(j.get_weekday()) == wkd) { wdc = wdc + 1; }
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
						if (iwkd(a.get_weekday()) == wkd) {
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
						if (iwkd(a.get_weekday()) > 5) {

// get weekday before, after or closest to a weekend day

							switch (wkd) {
								case 8: avd = (int) (d + (((( (iwkd(a.get_weekday()) - 5) - 1) / 1.0) * 2.0) - 1.0)); break;
								case 9: avd = d - (iwkd(a.get_weekday()) - 5); break;
								case 10: avd = d + (3 - (iwkd(a.get_weekday()) - 5)); break;
								default: avd = d; break;
							}

// get nearest weekday if avd is out of bounds

							if (avd < 1 || avd > md) { avd = d + (3 - (iwkd(a.get_weekday()) - 5)); }

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
				if (spew) { if (a.valid() == false) { print("invalid monthday reset date\n"); } }
			}

// add a year if required

			if ((a.get_month() + 1) > 12) {
				a.set_year(a.get_year() + 1);
				j.set_year(j.get_year() + 1);
				if (spew) { if (a.valid() == false) { print("invalid year incrament date\n"); } }
			}

// incrament the month

			j.set_month((j.get_month() % 12) + 1);
			a.set_month((a.get_month() % 12) + 1);
			if (spew) { if (a.valid() == false) { print("invalid month incrament date\n"); } }
		}

// we're day-counting... this is more expensive so its handled as a special case

	} else {
		if (fdy > 0) { 
			a.set_dmy((DateDay) fdy, fmo, (DateYear) fye);
			if (spew) { if (a.valid() == false) { print("invalid day-count initialized fdy date\n"); } }
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
								if (avd < 1 ) { 
									a.subtract_months(1);
									avd = ldom[a.get_month() - 1] + avd; 
								} else {
									var lmd = ldom[a.get_month() - 1];
									if (avd > lmd) {
										a.add_months(1);
										avd = avd - lmd;
									}
								}
								a.set_day((DateDay) avd);
								if (spew) { if (a.valid() == false) { print("invalid day-count avd date\n"); } }
							}
							oo.nxd = a; 
							o += oo;
						}

// get nth weekday

					} else {
						if (iwkd(a.get_weekday()) == wkd) {
							c = c + 1;
							if (((c - fdy) % (cnth * cofs)) == 0) {
								oo.nxd = a;
								o += oo;
							}
						}
					}
				}
				a.add_days(1);
				if (spew) { if (a.valid() == false) { print("invalid day-count incrament date\n"); } }
			}
		} else {
			if (nth > 0) {
				a.set_dmy((DateDay) nth, fmo, (DateYear) fye);
				if (spew) { if (a.valid() == false) { print("invalid day-count initialized date\n"); } }
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
	if (spew) { print("%sfindnextdate completed.\n",tabi); }
	return o;
}

// update idat separate to isolate cosmetic changes to list

void updateidat (int ind) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	if (spew) { print("%supdateidat started...\n", tabi); }
	var tabni = ("%-" + (ind + 4).to_string() + "s").printf("");

// idat = { "list row text", "#fgcolor", "creating-rule index" }

	idat = new string[fdat.length[0],3];

	// fdat=
	// 0 = date
	// 1 = description
	// 2 = amount
	// 3 = cat
	// 4 = group
	// 5 = runningtotal
	// 6 = catcolor
	// 7 = groupcolor
	// 8 = owner
	// 9 = month
	
	if (spew) { 
		print("%supdateidat:\tcheck fdat.length[0]: %d\n", tabni, fdat.length[0]); 
		print("%supdateidat:\tcheck fdat.length[1]: %d\n", tabni, fdat.length[1]); 
	}

	if (fdat.length[0] > 0) {
		if (fdat.length[1] == 10) {
			int[] sls = {8,0,0,0,0};
			idat = new string[fdat.length[0],3];

// get string lengths

			for (var r = 0; r < fdat.length[0]; r++) {
				if (sls[4] < fdat[r,4].length) { sls[4] = fdat[r,4].length; } // group
				if (sls[3] < fdat[r,3].length) { sls[3] = fdat[r,3].length; } // cat
				if (sls[2] < fdat[r,2].length) { sls[2] = fdat[r,2].length; } // amount
				if (sls[1] < fdat[r,1].length) { sls[1] = fdat[r,1].length; } // description
			}

// collect text, color and owner for draw

			for (var r = 0; r < fdat.length[0]; r++) {
				string clr = fdat[r,7];
				string rfg = "%s%s".printf(fdat[r,7],"FF");
				rgba = Gdk.RGBA();
				if (rgba.parse(rfg) == false) { 
					rfg = "%s%s".printf(txtc,"FF");
				}
				
				idat[r,0] = "".concat(
					fdat[r,0], " | ", 
					("%" + sls[2].to_string() + "s").printf(fdat[r,2]), " | ",
					("%-" + sls[3].to_string() + "s").printf(fdat[r,3]), " | ",
					("%-" + sls[1].to_string() + "s").printf(fdat[r,1]), " | ",
					fdat[r,5]
				);
				idat[r,1] = rfg; 
				idat[r,2] = fdat[r,8];
				idat[r,3] = fdat[r,9];
				if (spew && hard) { 
					print("%s\tupdateidat:\tidat[%d,0]: %s\n", tabni, r, idat[r,0]); 
					print("%s\tupdateidat:\tidat[%d,1]: %s\n", tabni, r, idat[r,1]);
					print("%s\tupdateidat:\tidat[%d,2]: %s\n", tabni, r, idat[r,2]); 
				}
			}
		}
	}
	if (spew) { print("%supdateidat completed.\n",tabi); }
}

void forecast (int ind) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	if (spew) { print("%sforecast started...\n",tabi); }
	var nind = ind + 4;

// close the graph info bubble since we;re reforecasting

	gi_trns = 99999;

// get forecasts

	nextdate?[] ttt = {};

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

// sorting

	GLib.qsort_with_data<nextdate?> (ttt, sizeof(nextdate?), (a, b) => a.nxd.compare(b.nxd));

// store in fdat, with running total

	fdat = new string[ttt.length,10];
	var ch = new char[10];
	double rut = 0.0;


	for (var r = 0; r < ttt.length; r++) {
		ttt[r].nxd.strftime(ch,"%d %b %y");
		rut = rut + ttt[r].amt;
		fdat[r,0] = ((string) ch);				// date
		fdat[r,1] = ttt[r].dsc;					// description
		fdat[r,2] = "%.2lf".printf(ttt[r].amt);	// amount
		fdat[r,3] = ttt[r].cat;					// cat
		fdat[r,4] = ttt[r].grp;					// group
		fdat[r,5] = ("%.2lf").printf(rut);		// runningtotal
		fdat[r,6] = ttt[r].cco;					// catcolor
		fdat[r,7] = ttt[r].gco;					// groupcolor
		fdat[r,8] = "%d".printf(ttt[r].frm);	// owner
		ttt[r].nxd.strftime(ch,"%m");
		fdat[r,9] = ((string) ch);				// month only
	}

// prep for drawing

	updateidat(nind);

	if (spew) { print("%sforecast done\n",tabi); }
}

// update ldat separate to isolate cosmetic changes to list

void updateldat (int ind) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	var tabni = ("%-" + (ind + 4).to_string() + "s").printf("");
	if (spew) { print("%supdateldat started...\n",tabi); }
	ldat = new string[sdat.length[0],3];
	if (spew) { print("%supdateldat:\tsdat.length[0] : %d\n",tabni,sdat.length[0]); }
	int mxl = 0;
	int midx = 0;
	for (var s = 0; s < sdat.length[0]; s++) {
		if (sdat[s,10].length > mxl) { mxl = sdat[s,10].length; midx = s; }
	}
	for (var s = 0; s < sdat.length[0]; s++) {
		string rfg = "%s%s".printf(sdat[s,12],"FF");
		rgba = Gdk.RGBA();
		if (rgba.parse(rfg) == false) { 
			rfg = "%s%s".printf(txtc,"FF"); 
		}
		ldat[s,0] = sdat[s,10];
		ldat[s,1] = rfg;
		ldat[s,2] = midx.to_string();
		if (spew && hard) { 
			print("%s\tsupdateldat:\tldat[%d,0] : %s\n", tabni, s, ldat[s,0]);
			print("%s\tsupdateldat:\tldat[%d,1] : %s\n", tabni, s, ldat[s,1]);
			print("%s\tsupdateldat:\tldat[%d,2] : %s\n", tabni, s, ldat[s,2]); 
		}
	}
	if (spew) { print("%supdateldat:\tldat.length[0] : %d\n",tabni,ldat.length[0]); }
	if (spew) { print("%supdateldat completed.\n", tabi); }
}

string[] getchoicelist(int idx, int ind) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	if (spew) { print("%sgetchoicelist started\n", tabi);}
	var whatupdate = doup;
	doup = false;
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
		int cidx = idx + 3;
		rgba = Gdk.RGBA;
		if (rgba.parse(sdat[r,cidx]) == false) {
			if (cidx == 11) { sdat[r,cidx] = txtc; }
			if (cidx == 12) { sdat[r,cidx] = txtc; }
		}
	}
	if (ooo.length == 0) { ooo += "none"; }
	doup = whatupdate;
	if (spew) { print("%sgetchoicelist completed.\n", tabi); }
	return ooo;
}

void adjustgroupcolor ( double rrr, double ggg, double bbb, string hhh, bool x, int ind ) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	if (spew) { print("%sadjustgroupcolor started...\n",tabi); }
	var nind = ind + 4;

// data, setuplist, hex-entry, red slider val, green slider val, blue slider val, do hex-entry

	string hx = "#%02X%02X%02X".printf(((int) rrr), ((int) ggg), ((int) bbb));
	if (x) { hx = hhh; }
	rgba = Gdk.RGBA();
	if (rgba.parse(hx) == false) { hx = txtc; rgba.parse(hx); }
	if (x == false) { doup = false; hhhh.text = hx; doup = true; }
	sdat[ssrr,12] = hx;

// update sdat, matching group only

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

// update rgb sliders if hex field was changed,
// otherwise update hex field

	if (tcol.get_active()) {
		if (x) {
			rrrr.adjustment.value = ((double) ((int) (rgba.red * 255.0)));
			gggg.adjustment.value = ((double) ((int) (rgba.green * 255.0)));
			bbbb.adjustment.value = ((double) ((int) (rgba.blue * 255.0)));
		} else {
			hhhh.text = hx;
		}
	}

// update color swatch

	string ccc = ".col { background: %s%s; }".printf(hx,"FF");
	if (tcol.get_active() == false) { 
		ccc = ".col { background: %s%s; }".printf(hx,"55");
	}
	tcsp.load_from_data(ccc.data);
}

void selectrow (int ind) {
	var tabi = ("%-" + ind.to_string() + "s").printf("");
	var nind = ind + 8;
	var tabni = ("%-" + (ind + 4).to_string() + "s").printf("");
	if (spew) { 
		print("%sselectrow started...\n",tabi); 
		print("%sselectrow:\tselecting rule: %d\n",tabni,ssrr);
		print("%sselectrow:\tsdat.length[0] = %d\n",tabni,sdat.length[0]);
	}

// block any accidental event triggering
	doup = false;

// shuffle date params to improve plain-english translation of data

	var ffs = int.parse(sdat[ssrr,2]);

	if (spew) { 
		print("%sselectrow:\tchecking weekday rule: %s\n",tabni,sdat[ssrr,2]);
	}

	if (ffs > 7) {
		if (pmid.get_child_at_index(1).get_child() == cnth) {
			pmid.remove(pmid.get_child_at_index(1));
			pmid.remove(pmid.get_child_at_index(1));
			pmid.insert(cwkd,1);
			pmid.insert(cnth,2);
		}
	} else {
		if (pmid.get_child_at_index(1).get_child() == cwkd) {
			pmid.remove(pmid.get_child_at_index(1));
			pmid.remove(pmid.get_child_at_index(1));
			pmid.insert(cnth,1);
			pmid.insert(cwkd,2);
		}
	}

	if (spew) { 
		print("%sselectrow:\tupdating date combos...\n",tabni);
	}

	ffs = int.parse(sdat[ssrr,0]);
	//cevr.set_active(ffs);
	cevr.set_selected(ffs);
	ffs = int.parse(sdat[ssrr,1]);
	//cnth.set_active(ffs);
	cnth.set_selected(ffs);
	ffs = int.parse(sdat[ssrr,2]);
	//cwkd.set_active(ffs);
	cwkd.set_selected(ffs);
	ffs = int.parse(sdat[ssrr,3]);
	//cfdy.set_active(ffs);
	cfdy.set_selected(ffs);
	ffs = int.parse(sdat[ssrr,4]);
	//cmth.set_active(ffs);
	cmth.set_selected(ffs);
	//cfmo.remove_all();

// swap "to month" & "from month" as required for better english translation
	
	if (int.parse(sdat[ssrr,4]) == 0) {
		cfmo.set_model(sofm);
		//for (var j = 0; j < ofmo.length; j++) { cfmo.append_text(ofmo[j]); }
	} else {
		cfmo.set_model(sfmo);
		//for (var j = 0; j < frmo.length; j++) { cfmo.append_text(frmo[j]); }
	}
	ffs = int.parse(sdat[ssrr,5]);
	cfmo.set_selected(ffs);

// name field = description

	if (spew) { 
		print("%sselectrow:\tsetting rule name: %s\n",tabni,sdat[ssrr,10]);
	}

	edsc.text = sdat[ssrr,10];

// year value

	if (sdat[ssrr,6] == "0") {
		sfye.set_value(((int) (GLib.get_real_time() / 31557600000000) + 1970));
	} else {
		sfye.set_value(int.parse(sdat[ssrr,6]));
	}

// categories and category selection

	if (spew) { print("%sselectrow:\tupdating category list...\n",tabni);}
	string[] ccl = getchoicelist(8, nind);
	ccat.remove_all();
	for (var j = 0; j < ccl.length; j++) {
		ccat.append_text(ccl[j]);
	}
	for (var j = 0; j < ccl.length; j++) {
		if (ccl[j] == sdat[ssrr,8]) { ccat.set_active(j); break; }
	}

// groups and group selection

	if (spew) { print("%sselectrow:\tupdating group list...\n",tabni);}
	string[] gg = getchoicelist(9, nind);
	cgrp.remove_all();
	for (var k = 0; k < gg.length; k++) {
		cgrp.append_text(gg[k]);
	}
	for (var k = 0; k < gg.length; k++) {
		if (gg[k] == sdat[ssrr,9]) { cgrp.set_active(k); break; }
	}

// amount

	if (spew) { print("%sselectrow:\tsetting amount: %s\n",tabni,sdat[ssrr,7]);}
	samt.set_value( double.parse(sdat[ssrr,7]) );

// group color to tcol

	if (spew) { print("%sselectrow:\tfetching group color: %s\n",tabni,sdat[ssrr,12]);}
	var clr = sdat[ssrr,12];
	rgba = Gdk.RGBA();
	if (rgba.parse(clr) == false) { clr = txtc; rgba.parse(clr); } 
	if (spew) { print("%sselectrow:\tapplying color to params: %s\n",tabni,clr);}
	string ccc = ".col { background: %s%s; }".printf(clr,"FF");
	if (tcol.get_active()) {	
		hhhh.text = clr;
		rrrr.adjustment.value = ((double) ((int) (rgba.red * 255.0)));
		gggg.adjustment.value = ((double) ((int) (rgba.green * 255.0)));
		bbbb.adjustment.value = ((double) ((int) (rgba.blue * 255.0)));
		if (spew) { print("%sselectrow:\tset sliders to: (%f,%f,%f)\n",tabni,rrrr.adjustment.value,gggg.adjustment.value,bbbb.adjustment.value);}
		//xcol.visible = true;
	} else {
		ccc = ".col { background: %s%s; }".printf(clr,"55");
		if (spew) { print("%sselectrow:\ttcol is OFF\n",tabni);}
		//xcol.visible = false;
	}
	tcsp.load_from_data(ccc.data);

// ldat = {"label", "#foreground"}

	//updateldat(nind);

	doup = true;
	if (spew) { print("%sselectrow completed.\n", tabi); }
}

string moi (int i) {
	// this gets pounded by graph draw, disabling diagnostics
	i = int.min(int.max(i,0),11);
	return shmo[i];
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





public class fulltardie : Gtk.Application {

	construct {
		application_id = "com.snotbubble.fulltardie";
		flags = ApplicationFlags.FLAGS_NONE;
	}
}


public class ftwin : Gtk.ApplicationWindow {
	public ftwin (Gtk.Application fulltardie) {Object (application: fulltardie);}
	construct {

		spew = true;
		doup = false;

		txtc = "#55BDFF";
		rowc = "#1A3B4F";
		tltc = "#112633";

		Gdk.ScrollDirection scrolldir;
		tcsp = new Gtk.CssProvider();	// color toggle css
		icsp = new Gtk.CssProvider();	// iso toggle css

// shared memory for draw-areas, these come from user input

		bool	izom = false;	// zoom mode
		bool	ipan = false;	// pan mode
		bool	iscr = false;	// scroll mode
		bool	ipik = false;	// pick mode
		int		drwm = 0;		// what to draw: 0 = setuplist, 1 = forecastlist, 2 = graph

// setuplist memory

		double[] 	sl_moom = {0.0,0.0};		// setuplist live mousemove xy
		double[] 	sl_mdwn = {0.0,0.0};		// setuplist live mousedown xy
		double[] 	sl_olsz = {300.0,300.0};	// setuplist pre-draw size xy
		double[] 	sl_olof = {0.0,0.0};		// setuplist pre-draw offset xy
		double[] 	sl_olmd = {0.0,0.0};		// setuplist pre-draw mousedown xy
		double		sl_olbh = 30.0;				// setuplist pre-draw bar height
		double 		sl_posx = 0.0;				// setuplist post-draw offset x
		double 		sl_posy = 0.0;				// setuplist post_draw offset y
		double		sl_sizx	= 0.0;				// setuplist post-draw size x
		double		sl_sizy = 0.0;				// setuplist post-draw size y 
		double 		sl_trgx	= 0.0;				// setuplist post-draw mousedown x
		double 		sl_trgy = 0.0;				// setuplist post-draw moudedown y
		double 		sl_barh = 30.0;				// setuplist row height
		int 		sl_rule = 0;				// setuplist selected rule


// forecastlist memory

		double[] 	fl_moom = {0.0,0.0};		// forecastlist live mousemove xy
		double[] 	fl_mdwn = {0.0,0.0};		// forecastlist live mousedown xy
		double[] 	fl_olsz = {300.0,300.0};	// forecastlist pre-draw size xy
		double[] 	fl_olof = {0.0,0.0};		// forecastlist pre-draw offset xy
		double[] 	fl_olmd = {0.0,0.0};		// forecastlist pre-draw mousedown xy
		double		fl_olbh	= 20.0;				// forecastlist post-draw bar height
		double 		fl_posx = 0.0;				// forecastlist post-draw offset x
		double 		fl_posy = 0.0;				// forecastlist post_draw offset y
		double		fl_sizx	= 0.0;				// forecastlist post-draw size x
		double		fl_sizy = 0.0;				// forecastlist post-draw size y 
		double 		fl_trgx	= 0.0;				// forecastlist post-draw mousedown x
		double 		fl_trgy = 0.0;				// forecastlist post-draw moudedown y
		double 		fl_barh = 30.0;				// forecastlist row height
		int 		fl_rule = 0;				// forecastlist selected rule
		double[]	fl_rssz = {300.0,300.0};	// forecastlist pre-draw size memory for isolate

// graph memory

		double[] 	gi_moom = {0.0,0.0};		// graph live mousemove xy
		double[] 	gi_mdwn = {0.0,0.0};		// graph live mousedown xy
		double[] 	gi_olsz = {300.0,300.0};	// graph pre-draw size xy
		double[] 	gi_olof = {0.0,0.0};		// graph pre-draw offset xy
		double[] 	gi_olmd = {0.0,0.0};		// graph pre-draw mousedown xy
		double		gi_olbh = 10.0;				// graph pre-draw bar height
		double 		gi_posx = 0.0;				// graph post-draw offset x
		double 		gi_posy = 0.0;				// graph post_draw offset y
		double		gi_sizx	= 0.0;				// graph post-draw size x
		double		gi_sizy = 0.0;				// graph post-draw size y 
		double 		gi_trgx	= 0.0;				// graph post-draw mousedown x
		double 		gi_trgy = 0.0;				// graph post-draw moudedown y
		double 		gi_barh = 30.0;				// graph row height
		int 		gi_rule = 0;				// graph selected rule
		double[]	gi_rssz = {300.0,300.0};	// graph pre-draw size memory for isolate
		double[]	gi_rsof = {40.0,20.0};		// graph pre-draw offset memory for isolate
		gi_trns = 0;							// graph selecte transaction

// common draw output

		bool		dosel = false;				// select a rule on mouse-up

// sample data
		
		sdat = {
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
		
// utility lists used by functions
		string[] evr = {
			"the",
			"every",
			"every 2nd", 
			"every 3rd", 
			"every 4th", 
			"every 5th", 
			"every 6th", 
			"every 7th", 
			"every 8th", 
			"every 9th", 
			"every 10th", 
			"every 11th",
			"every 12th", 
			"every 13th", 
			"every 14th", 
			"every 15th", 
			"every 16th", 
			"every 17th", 
			"every 18th", 
			"every 19th", 
			"every 20th", 
			"every 21st",
			"every 22nd", 
			"every 23rd", 
			"every 24th", 
			"every 25th", 
			"every 26th", 
			"every 27th", 
			"every 28th", 
			"every 29th", 
			"every 30th", 
			"every 31st", 
			"every last"
		};
		string[] nth = {
			"",
			"1st",
			"2nd",
			"3rd",
			"4th",
			"5th",
			"6th",
			"7th",
			"8th",
			"9th",
			"10th",
			"11th",
			"12th",
			"13th",
			"14th",
			"15th",
			"16th",
			"17th",
			"18th",
			"19th",
			"20th",
			"21st",
			"22nd",
			"23rd",
			"24th",
			"25th",
			"26th",
			"27th",
			"28th",
			"29th",
			"30th",
			"31st",
			"last"
		};
		string[] wkd = {
			"day", 
			"monday", 
			"tuesday", 
			"wednesday", 
			"thursday", 
			"friday", 
			"saturday", 
			"sunday", 
			"weekday closest to the", 
			"weekday on or before the", 
			"weekday on or after the"
		};
		string[] fdy = {
			"",
			"from the 1st",
			"from the 2nd",
			"from the 3rd",
			"from the 4th",
			"from the 5th",
			"from the 6th",
			"from the 7th",
			"from the 8th",
			"from the 9th",
			"from the 10th",
			"from the 11th",
			"from the 12th",
			"from the 13th",
			"from the 14th",
			"from the 15th",
			"from the 16th",
			"from the 17th",
			"from the 18th",
			"from the 19th",
			"from the 20th",
			"from the 21st",
			"from the 22nd",
			"from the 23rd",
			"from the 24th",
			"from the 25th",
			"from the 26th",
			"from the 27th",
			"from the 28th",
			"from the 29th",
			"from the 30th",
			"from the 31st"
		};
		string[] mth = {
			"",
			"of every month",
			"of every 2nd month",
			"of every 3rd month",
			"of every 4th month",
			"of every 5th month",
			"of every 6th month",
			"of every 7th month",
			"of every 8th month",
			"of every 9th month",
			"of every 10th month",
			"of every 11th month",
			"of every 12th month"
		};
// these are read by functions
		frmo = {
			"from this month", 
			"from january", 
			"from february", 
			"from march", 
			"from april", 
			"from may", 
			"from june", 
			"from july", 
			"from august", 
			"from september", 
			"from october", 
			"from november", 
			"from december"
		};
		ofmo = {
			"of this month", 
			"of january", 
			"of february", 
			"of march", 
			"of april", 
			"of may", 
			"of june", 
			"of july", 
			"of august", 
			"of september", 
			"of october", 
			"of november", 
			"of december"
		};
		shmo = {
			"JAN", 
			"FEB", 
			"MAR", 
			"APR", 
			"MAY", 
			"JUN", 
			"JUL", 
			"AUG", 
			"SEP", 
			"OCT", 
			"NOV", 
			"DEC"
		};
		ldom = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};

// *sigh... turning lists into a different flavour of list, 
// for a container of a list,
// that goes into a container of containers... 
// because: what-ifs
// I miss doing stuff like:  drop-list 10x10 300x30 with [ color: red ] data: list

		sfmo = new Gtk.StringList(frmo);
		sofm = new Gtk.StringList(ofmo);

// window

		this.title = "fulltardie";
		this.close_request.connect((e) => { 
			if (spew) { print("yeh bye\n"); } 
			return false; 
		});
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
		this.set_default_size(360, (720 - 46));  // magic number for headerbar, since we can't read it yet

// load/save menus

		mlod = new Gtk.MenuButton();
		Gtk.MenuButton msav = new Gtk.MenuButton();
		mlod.icon_name = "document-open-symbolic";
		msav.icon_name = "document-save-symbolic";
		Gtk.Button bsav = new Button.with_label("save");
		Gtk.Popover lpop = new Gtk.Popover();
		Gtk.Popover spop = new Gtk.Popover();
		Gtk.Box sbox = new Gtk.Box(VERTICAL,5);
		Gtk.Box lbox = new Gtk.Box(VERTICAL,5);
		sbox.margin_start = 5;
		sbox.margin_end = 5;
		sbox.margin_top = 5;
		sbox.margin_bottom = 5;
		lbox.margin_start = 5;
		lbox.margin_end = 5;
		lbox.margin_top = 5;
		lbox.margin_bottom = 5;
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

		edsc = new Gtk.Entry();
		edsc.text = sdat[0,10];
		edsc.hexpand = true;
		Gtk.Box ptop = new Gtk.Box(HORIZONTAL,10);
		ptop.append(edsc);

// controls

		badd = new Gtk.Button.with_label("+");
		brem = new Gtk.Button.with_label("-");
		tiso = new Gtk.ToggleButton.with_label("ISO");

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
		hhhh.text = "#1A3B4F";
		hhhh.set_width_chars(8);
		xcol.append(rrrr);
		xcol.append(gggg);
		xcol.append(bbbb);
		xcol.append(hhhh);

// group color button

		string hxxx = "";
		if (sdat.length[0] > 0) { hxxx = sdat[0,12]; }
		rgba = Gdk.RGBA();
		if (rgba.parse(hxxx) == false) {
			rgba.parse(txtc);
			hxxx = txtc;
		}

// color swatch, retains css for now, replace with a suitable alternative

		//tcol = new Gtk.ToggleButton.with_label("▼");
		tcol = new Gtk.ToggleButton();
		tcol.set_label("▼");
		string cssx = ".col { background: %s%s; }".printf(hxxx,"55");
		tcsp.load_from_data(cssx.data);
		tcol.get_style_context().add_provider(tcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		tcol.get_style_context().add_class("col");

// assemble controls

		pctr = new Gtk.Box(HORIZONTAL,10);
		pctr.append(badd);
		pctr.append(brem);
		pctr.append(tiso);
		pctr.append(tcol);

// rule component combos
// gtk4 doesn't support scrolling in combos, 
// so these have to be dropdowns with super awkward 'listmodels'
// luckily they can be built from arrays...

		cevr = new Gtk.DropDown(null,null);
		cevr.set_model(new Gtk.StringList(evr));
		cnth = new Gtk.DropDown(null,null);
		cnth.set_model(new Gtk.StringList(nth));
		cwkd = new Gtk.DropDown(null,null);
		cwkd.set_model(new Gtk.StringList(wkd));
		cfdy = new Gtk.DropDown(null,null);
		cfdy.set_model(new Gtk.StringList(fdy));
		cmth = new Gtk.DropDown(null,null);
		cmth.set_model(new Gtk.StringList(mth));
		cfmo = new Gtk.DropDown(null,null);
		cfmo.set_model(new Gtk.StringList(frmo));
		cevr.set_selected(0);
		cnth.set_selected(0);
		cwkd.set_selected(0);
		cfdy.set_selected(0);
		cmth.set_selected(0);
		cfmo.set_selected(0);
		//cevr = new ComboBoxText();
		//cnth = new ComboBoxText();
		//cwkd = new ComboBoxText();
		//cfdy = new ComboBoxText();
		//cmth = new ComboBoxText();
		//cfmo = new ComboBoxText();
		//for (var j = 0; j < evr.length; j++) {cevr.append_text(evr[j]);}
		//for (var j = 0; j < nth.length; j++) {cnth.append_text(nth[j]);}
		//for (var j = 0; j < wkd.length; j++) {cwkd.append_text(wkd[j]);}
		//for (var j = 0; j < fdy.length; j++) {cfdy.append_text(fdy[j]);}
		//for (var j = 0; j < mth.length; j++) {cmth.append_text(mth[j]);}
		//for (var j = 0; j < frmo.length; j++) {cfmo.append_text(frmo[j]);}
		//cevr.set_active(0);
		//cnth.set_active(0);
		//cwkd.set_active(0);
		//cfdy.set_active(0);
		//cmth.set_active(0);
		//cfmo.set_active(0);

/* 
// not supported in gtk4:
		cevr.set_wrap_width(4);
		cnth.set_wrap_width(4);
		cwkd.set_wrap_width(2);
		cfdy.set_wrap_width(2);
		cmth.set_wrap_width(2);
		cfmo.set_wrap_width(2); 
*/

		yadj = new Gtk.Adjustment(2021,1990,2100,1,5,1);
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
		pmid.set_selection_mode(NONE);


// group 

		lgrp = new Label("grp");
		lgrp.set_halign(START);
		lgrp.set_max_width_chars(8);
		lgrp.set_hexpand(false);
		lgrp.set_size_request(10,10);
		lgrp.margin_end = 10;
		cgrp = new ComboBoxText.with_entry();
		cgrp.set_halign(START);
		egrp = (Entry) cgrp.get_child();
		egrp.set_halign(START);
		egrp.set_width_chars(8);
		egrp.set_hexpand(false);

// category

		lcat = new Label("cat");
		lcat.set_halign(START);
		lcat.set_max_width_chars(8);
		lcat.set_hexpand(false);
		lcat.set_size_request(10,10);
		lcat.margin_end = 10;
		ccat = new ComboBoxText.with_entry();
		ecat = (Entry) ccat.get_child();
		ecat.set_halign(START);
		ecat.set_width_chars(8);
		ecat.set_hexpand(false);

// amount

		lamt = new Label("amt");
		lamt.set_halign(START);
		lamt.set_max_width_chars(8);
		lamt.set_hexpand(false);
		lamt.set_size_request(10,10);
		lamt.margin_end = 10;
		aadj = new Gtk.Adjustment(0.0,-100000,100000.0,10.0,100.0,1.0);
		samt = new Gtk.SpinButton(aadj,1.0,2);

// group container

		xgrp = new Gtk.Box(HORIZONTAL,0);
		xgrp.append(lgrp);
		xgrp.append(cgrp);
		xgrp.set_halign(START);
		xgrp.set_size_request(10,10);
		xgrp.set_hexpand(false);

// category container

		xcat = new Gtk.Box(HORIZONTAL,0);
		xcat.append(lcat);
		xcat.append(ccat);
		xcat.set_halign(START);
		xcat.set_size_request(10,10);
		xcat.set_hexpand(false);

// group container

		xamt = new Gtk.Box(HORIZONTAL,0);
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
		plow.set_selection_mode(NONE);

// assemble params

		pgrd = new Gtk.Grid();
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

		xscr = new Gtk.ScrolledWindow();
		xscr.set_child(pgrd);
		xscr.margin_top = 10;

// foecast list

		lfcl = new Label(null);
		lfcl.set_markup("<b><big>forecast</big></b>");
		flst = new Gtk.DrawingArea();
		flst.margin_top = 10;
		flst.margin_bottom = 10;
		flst.margin_start = 10;
		flst.margin_end = 10;

// graph page

		limg = new Label(null);
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

		hdiv = new Gtk.Paned(VERTICAL);
		hdiv.start_child = tabp;
		hdiv.end_child = xscr;
		hdiv.resize_end_child = true;
		hdiv.position = 450;
		hdiv.wide_handle = true;

// add ui to window

		this.set_child(hdiv);
		xcol.visible = false;
		doup = true;
		hard = false;

// initialize

		sl_olsz = {320,(20.0 * sdat.length[0])};
		selectrow(4);
		updateldat(4);
		forecast(4);
		fl_olsz = {360,(20.0 * fdat.length[0])};
		gi_olsz = {260,370.0};
		gi_olof = {40.0,20.0};
		//slst.queue_draw();


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
				drwm = ((int) page_num);
				if (spew) {
					print("tabp.switch_page.connect:\tswitching to tab: %d\n", drwm);
					print("tabp.switch_page.connect:\tselected rule is: %d\n", ssrr);
				}
				if (drwm == 0) { slst.queue_draw(); }
				if (drwm == 1) { flst.queue_draw(); }
				if (drwm == 2) { gimg.queue_draw(); }
			}
		});

/////////////////////////////////////////////////
//                                             //
//    re-forcasting and re-rendering params    //
//                                             //
/////////////////////////////////////////////////

		cevr.notify["selected"].connect(() => {
			if (doup) { 
				var n = cevr.get_selected();
				if (spew) { print("cevr.changed.connect:\tselecting item: %d\n", ((int) n)); }
				//sdat[ssrr,0] = n.to_string();
				sdat[ssrr,0] = "%d".printf(((int) n));
				if (spew) { print("cevr.changed.connect:\tsdat[%d,0] = %s\n", ssrr, "%d".printf(((int) n)) ); }
				forecast(4);
				if (drwm == 1) { flst.queue_draw(); }
				if (drwm == 2) { gimg.queue_draw(); }
			}
		});
		/*
		cevr.changed.connect(() => {
			if (doup) { 
				var n = cevr.get_active();
				if (spew) { print("cevr.changed.connect:\tselecting item: %d\n", n); }
				sdat[ssrr,0] = n.to_string();
				forecast(4); updateidat(4);
				if (drwm == 1) { flst.queue_draw(); }
				if (drwm == 2) { gimg.queue_draw(); }
			}
		});
		*/
		cnth.notify["selected"].connect(() => {
			if (doup) {
				var n = cnth.get_selected();
				if (spew) { print("cnth.changed.connect:\tselecting item: %d\n", ((int) n)); }
				//sdat[ssrr,1] = n.to_string();
				sdat[ssrr,1] = "%d".printf(((int) n));
				forecast(4);
				if (drwm == 1) { flst.queue_draw(); }
				if (drwm == 2) { gimg.queue_draw(); }
			}
		});
		cwkd.notify["selected"].connect(() => {
			if (doup) {
				var n = cwkd.get_selected();
				if (spew) { print("cwkd.changed.connect:\tselecting item: %d\n", ((int) n)); }
				//sdat[ssrr,2] = n.to_string();
				sdat[ssrr,2] = "%d".printf(((int) n));
				var ffs = int.parse(sdat[ssrr,2]);
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
				forecast(4);
				if (drwm == 1) { flst.queue_draw(); }
				if (drwm == 2) { gimg.queue_draw(); }
			}
		});
		cfdy.notify["selected"].connect(() => {
			if (doup) {
				var n = cfdy.get_selected();
				if (spew) { print("cfdy.changed.connect:\tselecting item: %d\n", ((int) n)); }
				sdat[ssrr,3] = "%d".printf(((int) n));
				//sdat[ssrr,3] = n.to_string();
				forecast(4);
				if (drwm == 1) { flst.queue_draw(); }
				if (drwm == 2) { gimg.queue_draw(); }
			}
		});
		cmth.notify["selected"].connect(() => {
			if (doup) {
				var n = cmth.get_selected();
				if (spew) { print("cmth.changed.connect:\tselecting item: %d\n", ((int) n)); }
				//sdat[ssrr,4] = n.to_string();
				sdat[ssrr,4] = "%d".printf(((int) n));
				int ffs = int.parse(sdat[ssrr,5]);
// change from-month to of-month if this combo is zeroed - so the rule makes mroe sense in english
				doup = false;
				if (int.parse(sdat[ssrr,4]) == 0) {
					cfmo.set_model(sofm);
					//for (var j = 0; j < ofmo.length; j++) { cfmo.append_text(ofmo[j]); }
				} else {
					cfmo.set_model(sfmo);
					//for (var j = 0; j < frmo.length; j++) { cfmo.append_text(frmo[j]); }
				}
				cfmo.set_selected(ffs);
				doup = true;
				forecast(4);
				if (drwm == 1) { flst.queue_draw(); }
				if (drwm == 2) { gimg.queue_draw(); }
			}
		});
		cfmo.notify["selected"].connect(() => {
			if (doup) {
				var n = cfmo.get_selected();
				if (spew) { print("cfmo.changed.connect:\tselecting item: %d\n", ((int) n)); }
				//sdat[ssrr,5] = n.to_string();
				sdat[ssrr,5] = "%d".printf(((int) n));
				forecast(4);
				if (drwm == 1) { flst.queue_draw(); }
				if (drwm == 2) { gimg.queue_draw(); }
			}
		});
		sfye.changed.connect(() => {
			if (doup) {
				var v = sfye.get_value();
				if (spew) { print("sfye.changed.connect:\tchanging value to: %f\n", v); }
				if (v == ((int) (GLib.get_real_time() / 31557600000000) + 1970)) {
					sdat[ssrr,6] = "0";
				} else {
					sdat[ssrr,6] = ((string) ("%lf").printf(v));
				}
				forecast(4);
				if (drwm == 1) { flst.queue_draw(); }
				if (drwm == 2) { gimg.queue_draw(); }
			}
		});
		samt.value_changed.connect(() => {
			if (doup) {
				if (spew) { print("samt.value_changed.connect:\tchanging value to: %f\n", samt.get_value()); }
				sdat[ssrr,7] =((string) ("%.2lf").printf(samt.get_value()));;
				forecast(4);
				if (drwm == 1) { flst.queue_draw(); }
				if (drwm == 2) { gimg.queue_draw(); }
			}
		});
		tiso.toggled.connect(() => {
			if (doup) {
				if (spew) { print("iso.toggled.connect:\ttoggling isolate...\n"); }
				forecast(4); updateidat(4);
				print("flst.get_allocated_height() : %f\n", flst.get_allocated_height());
// capture and restore forecastlist size regardless of visibility, width irrelevant
				if (tiso.get_active()) {
					fl_rssz = fl_olsz;
					fl_olsz = {flst.get_allocated_width(), double.max(flst.get_allocated_height(), (20.0 * fdat.length[0]))};
					gi_rssz = gi_olsz;
					gi_rsof = gi_olof;
					gi_olsz = {(gimg.get_allocated_width() - 80.0), (gimg.get_allocated_height() - 40.0)};
					gi_olof = {40.0,20.0};
				} else { 
					fl_olsz = fl_rssz;
					gi_olsz = gi_rssz; 
					gi_olof = gi_rsof;
				}
				if (drwm == 1) { flst.queue_draw(); }
				if (drwm == 2) { gimg.queue_draw(); }
			}
		});

//////////////////////////////////
//                              //
//   non-reforcasting params    //
//                              //
//////////////////////////////////

		cgrp.changed.connect(() => {
			if (doup) {
				var n = cgrp.get_active_text().strip();
				if (spew) { print("cgrp.changed.connect:\tselecting item: %s\n", n); }
				sdat[ssrr,9] = n;

// grab group color from another rule with the same group, if one exists
// move this to a function as its duplicated in the field event

				rgba = Gdk.RGBA();
				var uc = "";
				for  (int i = 0; i < sdat.length[0]; i++) {
					uc = "";
					if (i != ssrr) { 
						if (sdat[i,9] == n) {
							uc = sdat[i,12];
							if (rgba.parse(uc)) { break; } else { uc = ""; }
						}
					}
				}

// update color params

				if (rgba.parse(uc) == false) { uc = txtc; rgba.parse(uc); }
				string ccc = ".col { background: %s%s; }".printf(uc,"55");
				if (tcol.get_active()) {
					ccc = ".col { background: %s%s; }".printf(uc,"FF");
					doup = false;
					hhhh.text = uc;
					rrrr.adjustment.value = ((double) ((int) (rgba.red * 255.0)));
					gggg.adjustment.value = ((double) ((int) (rgba.green * 255.0)));
					bbbb.adjustment.value = ((double) ((int) (rgba.blue * 255.0)));
					doup = true;
				}
				tcsp.load_from_data(ccc.data);

// save group color

				sdat[ssrr,12] = uc;

// also update forecasted data, without reforecasting
// group membership is purely cosmetic

				for  (int i = 0; i < fdat.length[0]; i++) {
					if (int.parse(fdat[i,8]) == ssrr) {
						fdat[i,4] = n;
						fdat[i,7] = uc;
					}
				}

// re-render views

				if (drwm == 0) { updateldat(4); slst.queue_draw(); }
				if (drwm == 1) { updateidat(4); flst.queue_draw(); }
				if (drwm == 2) { updateidat(4); gimg.queue_draw(); }
			}
		});
		Gtk.Entry vvvv = (Entry) cgrp.get_child();
		vvvv.activate.connect(() => {
			if (doup) {
				if (vvvv.text != null) {
					var n = vvvv.text.strip();
					if (n != "") {
						doup = false;
						if (spew) { print("vvvv.activate.connect:\tselecting item: %s\n", n); }
						int r = cgrp.get_active();
						sdat[ssrr,9] = n;
						string[] cc = getchoicelist(9, 4);
						cgrp.remove_all();
						for (var j = 0; j < cc.length; j++) {
							cgrp.append_text(cc[j]);
							if (cc[j] == n) { r = j; }
						}
						cgrp.set_active(r);

// grab group color from another item with the same group, if one exists
// move this to a function

						rgba = Gdk.RGBA();
						var uc = "";
						for  (int i = 0; i < sdat.length[0]; i++) {
							uc = "";
							if (i != ssrr) { 
								if (sdat[i,9] == n) {
									uc = sdat[i,12];
									if (rgba.parse(uc)) { break; } else { uc = ""; }
								}
							}
						}

// update color params

						if (rgba.parse(uc) == false) { uc = txtc; rgba.parse(uc); }
						string ccc = ".col { background: %s%s; }".printf(uc,"55");
						if (tcol.get_active()) {
							ccc = ".col { background: %s%s; }".printf(uc,"FF");
							doup = false;
							hhhh.text = uc;
							rrrr.adjustment.value = ((double) ((int) (rgba.red * 255.0)));
							gggg.adjustment.value = ((double) ((int) (rgba.green * 255.0)));
							bbbb.adjustment.value = ((double) ((int) (rgba.blue * 255.0)));
							doup = true;
						}
						tcsp.load_from_data(ccc.data);

// save group color

						sdat[ssrr,12] = uc;

// also update forecasted data, without reforecasting
// group membership is purely cosmetic

						for  (int i = 0; i < fdat.length[0]; i++) {
							if (int.parse(fdat[i,8]) == ssrr) {
								fdat[i,4] = n;
								fdat[i,7] = uc;
							}
						}

// re-render views

						if (drwm == 0) { updateldat(4); slst.queue_draw(); }
						if (drwm == 1) { updateidat(4); flst.queue_draw(); }
						if (drwm == 2) { updateidat(4); gimg.queue_draw(); }
					}
				}
			}
		});
		ccat.changed.connect(() => {
			if (doup) {
				var n = ccat.get_active_text().strip();
				if (spew) { print("ccat.changed.connect:\tselecting item: %s\n", n); }
				sdat[ssrr,8] = n;
				var rgba = Gdk.RGBA();
				var uc = "";
				for  (int i = 0; i < sdat.length[0]; i++) {
					uc = "";
					if (i != ssrr) { 
						if (sdat[i,8] == n) {
							uc = sdat[i,11];
							if (rgba.parse(uc)) { break; } else { uc = ""; }
						}
					}
				}
				if (rgba.parse(uc) == false) { uc = txtc; }
				sdat[ssrr,11] = uc;
			}
		});
		Gtk.Entry eeee = (Entry) ccat.get_child();
		eeee.activate.connect(() => {
			if (doup) {
				if (eeee.text != null) {
					var n = eeee.text.strip();
					if (n != "") {
						if (spew) { print("eeee.activate.connect:\ttext changed to: %s\n", n); }
						sdat[ssrr,8] = n;
						int r = ccat.get_active();
						string[] cc = getchoicelist(8, 4);
						ccat.remove_all();
						for (var j = 0; j < cc.length; j++) {
							ccat.append_text(cc[j]);
							if (cc[j] == n) { r = j; }
						}
						ccat.set_active(r);

// grab color from other matching categories

						var rgba = Gdk.RGBA();
						var uc = "";
						for  (int i = 0; i < sdat.length[0]; i++) {
							uc = "";
							if (i != ssrr) { 
								if (sdat[i,8] == n) {
									uc = sdat[i,11];
									if (rgba.parse(uc)) { break; } else { uc = ""; }
								}
							}
						}
						if (rgba.parse(uc) == false) { uc = txtc; }
						sdat[ssrr,11] = uc;
					}
				}
			}
		});
		edsc.changed.connect(() => {
			if (doup) {
				if (edsc.text != null) {
					string d = edsc.text.strip();
					if (d != "") {
						doup = false;
						if (spew) { print("dsc.changed.connect:\tchanging text to: %s\n", d); }
						sdat[ssrr,10] = d;
						if (drwm == 0) {
							updateldat(4); slst.queue_draw();
						}
						if (drwm >= 1) {
							for (int f = 0; f < fdat.length[0]; f++) {
								if ( int.parse(fdat[f,8]) == ssrr ) {
					 				fdat[f,1] = d;
								}
							}
							updateidat(4);
							if (drwm == 1) { flst.queue_draw(); }
							if (drwm == 2) { gimg.queue_draw(); }
						}
						doup = true;
					}
				}
			}
		});

// colors

		tcol.toggled.connect(() => {
			string hxgc = sdat[ssrr,12];
			rgba = Gdk.RGBA();
			if (rgba.parse(hxgc) == false) { rgba.parse(txtc); hxgc = txtc; }
			string ccc = ".col { background: %s%s; }".printf(hxgc,"FF");
			if (tcol.get_active()) { 
				tcol.set_label("");
				if (spew) { print("col.toggled.connect:\ttrue\n"); }
				doup = false;
				hhhh.text = hxgc;
				rrrr.adjustment.value = ((double) ((int) (rgba.red * 255.0)));
				gggg.adjustment.value = ((double) ((int) (rgba.green * 255.0)));
				bbbb.adjustment.value = ((double) ((int) (rgba.blue * 255.0)));
				xcol.visible = true;
				doup = true;
			} else { 
				tcol.set_label("▼");
				ccc = ".col { background: %s%s; }".printf(hxgc,"55");
				xcol.visible = false;
				if (spew) { print("col.toggled.connect:\tfalse\n"); }
			}
			tcsp.load_from_data(ccc.data);
		});
		rrrr.adjustment.value_changed.connect(() => {
			if (doup) {
				doup = false;
				if (spew) { print("rrrr.adjustment.value_changed.connect:\tchanging value to: %f\n", rrrr.adjustment.value); }
				adjustgroupcolor(rrrr.adjustment.value, gggg.adjustment.value, bbbb.adjustment.value, hhhh.text, false, 4);
				doup = true;
				updateldat(4); updateidat(4);
				if (drwm == 0) { slst.queue_draw(); }
				if (drwm == 1) { flst.queue_draw(); }
				if (drwm == 2) { gimg.queue_draw(); }
			}
		});
		gggg.adjustment.value_changed.connect(() => {
			if (doup) {
				doup = false;
				if (spew) { print("gggg.adjustment.value_changed.connect:\tchanging value to: %f\n", gggg.adjustment.value); }
				adjustgroupcolor(rrrr.adjustment.value, gggg.adjustment.value, bbbb.adjustment.value, hhhh.text, false, 4);
				doup = true;
				updateldat(4); updateidat(4);
				if (drwm == 0) { slst.queue_draw(); }
				if (drwm == 1) { flst.queue_draw(); }
				if (drwm == 2) { gimg.queue_draw(); }
			}
		});
		bbbb.adjustment.value_changed.connect(() => {
			if (doup) {
				doup = false;
				if (spew) { print("bbbb.adjustment.value_changed.connect:\tchanging value to: %f\n", bbbb.adjustment.value); }
				adjustgroupcolor(rrrr.adjustment.value, gggg.adjustment.value, bbbb.adjustment.value, hhhh.text, false, 4);
				doup = true;
				updateldat(4); updateidat(4);
				if (drwm == 0) { slst.queue_draw(); }
				if (drwm == 1) { flst.queue_draw(); }
				if (drwm == 2) { gimg.queue_draw(); }
			}
		});
		hhhh.changed.connect (() => {
			if (doup) {
				if (hhhh.text != null) {
					string hx = hhhh.text.strip();
					rgba = Gdk.RGBA();
					if (rgba.parse(hx)) {
						doup = false;
						if (spew) { print("hhhh.changed.connect:\tchanging value to: %s\n", hhhh.text); }
						adjustgroupcolor(rrrr.adjustment.value, gggg.adjustment.value, bbbb.adjustment.value, hx, true, 4);
						doup = true;
						updateldat(4); updateidat(4);
						if (drwm == 0) { slst.queue_draw(); }
						if (drwm == 1) { flst.queue_draw(); }
						if (drwm == 2) { gimg.queue_draw(); }
					}
				}
			}
		});

//////////////////////
//                  //
//    i/o params    //
//                  //
//////////////////////

		bsav.clicked.connect (() =>  {
			if (escn.text != null) {
				if (escn.text.strip() != "") {
					bool allgood = false;
					if (spew) { print("savebtn.clicked.connect:\tsaving scenario: %s\n", escn.text); }
					var dd = GLib.Environment.get_current_dir();
					string nn = (escn.text.strip() + ".scenario");
					string ff = Path.build_filename (dd, nn);
					File fff = File.new_for_path (ff);
					FileOutputStream oo = null;
					try {
						oo = fff.replace (null, false, FileCreateFlags.PRIVATE);
						allgood = true;
					} catch (Error e) {
						if (spew) { print ("Error: couldn't make outputstream.\n\t%s\n", e.message); }
					}
					if (allgood) {
						for (var u = 0; u < sdat.length[0]; u++) {
							for (var j = 0; j < 13; j++) {
								string rr = sdat[u,j];
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

////////////////////////////
//                        //
//    menubutton events   //
//                        //
////////////////////////////


		Gtk.GestureClick mlod_click = new Gtk.GestureClick();
		mlod.add_controller(mlod_click);

		mlod_click.pressed.connect (() =>  {
			print("mlod clicked...\n");
			if (spew) { print("mlod.clicked.connect:\tfetching saved scenarios...\n"); }
			while (lbox.get_first_child() != null) {
				if (spew) { print("mlod:\tremoving old popmenu item...\n"); }
  				lbox.remove(lbox.get_first_child());
			}
			var pth = GLib.Environment.get_current_dir();
			GLib.Dir dcr = Dir.open (pth, 0);
			string? name = null;
			while ((name = dcr.read_name ()) != null) {
				var exts = name.split(".");
				if (exts.length == 2) {
					if (exts[1] == "scenario") {
						Gtk.Button muh = new Gtk.Button.with_label (name);
						lbox.append(muh);
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
								if (spew) { print ("Error: couldn't load file.\n\t%s\n", e.message); }
							}
							if (allgood) {
								string tt = ss.read_line();
								if (tt != null) {
									if (spew) { print("    muh.clicked.connect:\tloading scenario: %s\n",nn); }
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
										sdat = tdat;
										escn.text = exts[0];
										ssrr = 0;
										doup = true;
										sl_trgx = 0.0;
										sl_trgy = 0.0;
										sl_moom = {0.0,0.0};
										sl_olsz = {slst.get_allocated_width(), (20.0 * sdat.length[0])};
										sl_olof = {0.0,0.0};
										sl_olmd = {0.0,0.0};
										sl_olbh = 30.0;
										selectrow (8);
										updateldat(8);
										forecast(8);
										if (drwm == 0) { slst.queue_draw(); }
										if (drwm == 1) { slst.queue_draw(); }
										if (drwm == 2) { gimg.queue_draw(); }
									}
								}
							}
							lpop.popdown();
						});
					}
				}
			}
			//lbox.show();
			//lpop.show();
		});

//////////////////////////////////
//                              //
//    add/remove data params    //
//                              //
//////////////////////////////////

		badd.clicked.connect (() =>  {
			var n = sdat.length[0];
			if (spew) { print("badd.clicked.connect:\tadding new rule...\n"); }
			string[,] tdat = new string[(n+1),13];
			for (var y = 0; y < sdat.length[0]; y++) {
				for (var c = 0; c < 13; c++) {
					tdat[y,c] = sdat[y,c];
				}
			}
			tdat[n,0] = "0";						//every nth
			tdat[n,1] = "1";						//day of month
			tdat[n,2] = "0";						//weekday
			tdat[n,3] = "0";						//from day
			tdat[n,4] = "1";						//of nth month
			tdat[n,5] = "0";						//from month
			tdat[n,6] = "0";						//from year
			tdat[n,7] = "10.0";						//amount
			tdat[n,8] = "cat1";						//category
			tdat[n,9] = "grp1";						//group
			tdat[n,10] = "new recurrence rule";		//description
			tdat[n,11] = txtc;						//categorycolor
			tdat[n,12] = txtc;						//groupcolor
			sdat = tdat;
			ssrr = (sdat.length[0] - 1);
			selectrow (4);
			updateldat(4);
			forecast(4);
			if (drwm == 0) { slst.queue_draw(); }
			if (drwm == 1) { slst.queue_draw(); }
			if (drwm == 2) { gimg.queue_draw(); }
		});
		brem.clicked.connect (() =>  {
			var n = sdat.length[0];
			if (spew) { print("brem.clicked.connect:\tremoving rule: %s\n",sdat[ssrr,9]); }
			string[,] tdat = new string[(n-1),13];
			var i = 0;
			for (var y = 0; y < sdat.length[0]; y++) {
				if (y != ssrr) {
					for (var c = 0; c < 13; c++) {
						tdat[i,c] = sdat[y,c];
					}
					i++;
				}
			}
			sdat = tdat;
			ssrr = (sdat.length[0] - 1);
			selectrow (4);
			updateldat(4);
			forecast(4);
			if (drwm == 0) { slst.queue_draw(); }
			if (drwm == 1) { slst.queue_draw(); }
			if (drwm == 2) { gimg.queue_draw(); }
		});


///////////////////////////////
//                           //
//    setup-list rendering   //
//                           //
///////////////////////////////


		slst.set_draw_func((da, ctx, daw, dah) => {
			if (spew && hard) { print("slst.set_draw_func:\tdraw started...\n"); }
			if (spew && hard) { print("slst.set_draw_func:\tchecking ldat.length[0] : %d\n", ldat.length[0]); }
			if (ldat.length[0] > 0) {
				var presel = ssrr;
				var csx = slst.get_allocated_width();
				var csy = slst.get_allocated_height();
				if (spew && hard) { print("slst.set_draw_func:\tdrawarea width : %d\n", daw); }
				if (spew && hard) { print("slst.set_draw_func:\tcanvas size x : %d\n", csx); }

// graph coords

				sl_sizx = sl_olsz[0];
				sl_sizy = sl_olsz[1];


				if (izom) {
					sl_sizx = (sl_olsz[0] + sl_moom[0]);
					sl_sizy = (sl_olsz[1] + sl_moom[1]);
				}

				sl_posy = sl_olof[1];
				sl_posx = sl_olof[0];
				
				if (izom) {
					sl_posx = sl_olof[0] + ( (sl_mdwn[0] - sl_olof[0]) - ( (sl_mdwn[0] - sl_olof[0]) * (sl_sizx / sl_olsz[0]) ) ) ;
					sl_posy = sl_olof[1] + ( (sl_mdwn[1] - sl_olof[1]) - ( (sl_mdwn[1] - sl_olof[1]) * (sl_sizy / sl_olsz[1]) ) ) ;
					sl_trgx = sl_olmd[0] + ( (sl_mdwn[0] - sl_olmd[0]) - ( (sl_mdwn[0] - sl_olmd[0]) * (sl_sizx / sl_olsz[0]) ) ) ;
					sl_trgy = sl_olmd[1] + ( (sl_mdwn[1] - sl_olmd[1]) - ( (sl_mdwn[1] - sl_olmd[1]) * (sl_sizy / sl_olsz[1]) ) ) ;
				}

				if(ipan || iscr) {
					sl_posx = sl_olof[0] + sl_moom[0];
					sl_posy = sl_olof[1] + sl_moom[1];
					sl_trgx = sl_olmd[0] + sl_moom[0];
					sl_trgy = sl_olmd[1] + sl_moom[1];
				}
				//if (izom) {
				//	sl_barh = double.max(20.0,double.min((sl_olbh + (sl_moom[1] * 0.1)),60.0));
				//}
				sl_barh = sl_sizy / sdat.length[0];
	
				if (ipik) {
					sl_trgx = sl_mdwn[0];
					sl_trgy = sl_mdwn[1];
				}

				if (spew && hard) { 
					print("slst.set_draw_func:\tsizx : %f\n", sl_sizx); 
					print("slst.set_draw_func:\tsizy : %f\n", sl_sizy); 
					print("slst.set_draw_func:\tposx : %f\n", sl_posx); 
					print("slst.set_draw_func:\tposy : %f\n", sl_posy);
					print("slst.set_draw_func:\ttrgx : %f\n", sl_trgx); 
					print("slst.set_draw_func:\ttrgy : %f\n", sl_trgy);
				}

// bar height

				ctx.select_font_face("Monospace",Cairo.FontSlant.NORMAL,Cairo.FontWeight.BOLD);
				ctx.set_font_size(sl_barh * 0.8); 
				Cairo.TextExtents extents;
				int midx = int.parse(ldat[0,2]);
				ctx.text_extents (ldat[midx,0], out extents);
				//sl_barh = sl_barh;
				var xx = extents.width + 40.0;
				if (spew && hard) { 
					print("slst.set_draw_func:\tbarh : %f\n", sl_barh); 
				}

// clamp pos y

				sl_posy = double.min(double.max(sl_posy, (0 - ((sl_barh * ldat.length[0])-dah))), 0.0);
				sl_posx = double.min(double.max(sl_posx, (daw - xx)), 0.0);

// paint bg

				var bc = Gdk.RGBA();
				bc.parse(rowc);
				ctx.set_source_rgba(bc.red,bc.green,bc.blue,1);
				ctx.paint();

// check selection hit

				var px = 0.0;
				var py = 0.0;

				if (ipik && sl_mdwn[0] > 0 && izom == false && ipan == false && iscr == false) {
					if (spew && hard) { print("slst.set_draw_func:\tchecking for selection at : %f x %f\n", sl_mdwn[0], sl_mdwn[1]); }
					sl_rule = 99999;
					for (int i = 0; i < ldat.length[0]; i++) {
						px = 0.0;
						py = 0.0;
						px = px + sl_posx;
						py = i * sl_barh;
						py = py + sl_posy;
						if (sl_mdwn[1] > py && sl_mdwn[1] < (py + (sl_barh - 1))) {
							ssrr = i;
							sl_rule = i;
							if (spew && hard) { print("slst.set_draw_func:\tselected row : %d\n", i); }
							sl_trgx = sl_mdwn[0]; sl_trgy = sl_mdwn[1];
							break;
						}
					}
				}

// rows

				if (spew && hard) { print("slst.set_draw_func:\tdrawing %d rows...\n", ldat.length[0]); }

				for (int i = 0; i < ldat.length[0]; i++) {
					px = 0.0;
					py = 0.0;
					px += sl_posx;
					py = i * sl_barh;
					py = py + sl_posy;
					string xinf = ldat[i,0];
					if (ssrr != i) { 
						if (bc.parse(ldat[i,1]) == false) { bc.parse(txtc); }
						if (spew && hard) { print("slst.set_draw_func:\tgroup color : %s\n", ldat[i,1]); }
						ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 0.1));
						ctx.rectangle(0.0, py, daw, (sl_barh - 1));
						ctx.fill ();
						ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 1.0));
						ctx.move_to((px + 10.0), (py + (sl_barh * 0.75)));
						ctx.show_text(xinf);
					} else {
						bc.parse(txtc);
						ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 1.0));
						ctx.rectangle(0.0, py, daw, (sl_barh - 1));
						ctx.fill();
						bc.parse(rowc);
						ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 1.0));
						ctx.move_to((px + 10), (py + (sl_barh * 0.75)));
						ctx.show_text(xinf);
					}
				}

// new rule selection detected, update the rest of the ui
// this should only trigger when ssrr changes

				if (spew && hard) { print("slst.set_draw_func:\tcomparing %d with %d...\n", ssrr, presel); }
				if (ssrr >= 0 && ssrr != presel) {
					dosel = true;
				}

// reset mouseown if not doing anythting with it

				if (izom == false && ipan == false && iscr == false) {
					sl_mdwn[0] = 0;
					sl_mdwn[1] = 0;
					ipik = false;
				}
				if (iscr) {
					iscr = false;
					sl_olsz = {sl_sizx, sl_sizy};
					sl_olof = {sl_posx, sl_posy};
					sl_olmd = {sl_trgx, sl_trgy};
				}
				if (spew && hard) { print("slst.set_draw_func:\tdraw complete\n"); }
			}
		});

///////////////////////////////////
//                               //
//    forecast-list rendering    //
//                               //
///////////////////////////////////


		flst.set_draw_func((da, ctx, daw, dah) => {
			if (spew && hard) { print("flst.set_draw_func:\tdraw started...\n"); }
			if (spew && hard) { print("flst.set_draw_func:\tchecking idat.length[0] : %d\n", idat.length[0]); }
			if (idat.length[0] > 0) {
				var presel = ssrr;
				var csx = flst.get_allocated_width();
				var csy = flst.get_allocated_height();
				if (spew && hard) { print("flst.set_draw_func:\tdrawarea width : %d\n", daw); }
				if (spew && hard) { print("flst.set_draw_func:\tcanvas size x : %d\n", csx); }

// graph coords

				fl_sizx = fl_olsz[0];
				fl_sizy = fl_olsz[1];


				if (izom) {
					fl_sizx = (fl_olsz[0] + (fl_moom[0] * 2.0));
					fl_sizy = (fl_olsz[1] + (fl_moom[1] * 2.0));
				}

				fl_posy = fl_olof[1];
				fl_posx = fl_olof[0];
				
				if (izom) {
					fl_posx = fl_olof[0] + ( (fl_mdwn[0] - fl_olof[0]) - ( (fl_mdwn[0] - fl_olof[0]) * (fl_sizx / fl_olsz[0]) ) ) ;
					fl_posy = fl_olof[1] + ( (fl_mdwn[1] - fl_olof[1]) - ( (fl_mdwn[1] - fl_olof[1]) * (fl_sizy / fl_olsz[1]) ) ) ;
					fl_trgx = fl_olmd[0] + ( (fl_mdwn[0] - fl_olmd[0]) - ( (fl_mdwn[0] - fl_olmd[0]) * (fl_sizx / fl_olsz[0]) ) ) ;
					fl_trgy = fl_olmd[1] + ( (fl_mdwn[1] - fl_olmd[1]) - ( (fl_mdwn[1] - fl_olmd[1]) * (fl_sizy / fl_olsz[1]) ) ) ;
				}

				if(ipan || iscr) {
					fl_posx = fl_olof[0] + fl_moom[0];
					fl_posy = fl_olof[1] + fl_moom[1];
					fl_trgx = fl_olmd[0] + fl_moom[0];
					fl_trgy = fl_olmd[1] + fl_moom[1];
				}
				//if (izom) {
				//	fl_barh = double.max(10.0,double.min((fl_olbh + (fl_moom[1] * 0.1)),60.0));
				//	//print("bar height = %f\n", fl_barh);
				//}

				if (ipik) {
					fl_trgx = fl_mdwn[0];
					fl_trgy = fl_mdwn[1];
				}

				fl_barh = fl_sizy / fdat.length[0];				

				if (spew && hard) { 
					print("flst.set_draw_func:\tsizx : %f\n", fl_sizx); 
					print("flst.set_draw_func:\tsizy : %f\n", fl_sizy); 
					print("flst.set_draw_func:\tposx : %f\n", fl_posx); 
					print("flst.set_draw_func:\tposy : %f\n", fl_posy);
					print("flst.set_draw_func:\ttrgx : %f\n", fl_trgx); 
					print("flst.set_draw_func:\ttrgy : %f\n", fl_trgy);
				}

// bar height

				ctx.select_font_face("Monospace",Cairo.FontSlant.NORMAL,Cairo.FontWeight.BOLD);
				ctx.set_font_size(fl_barh * 0.8); 
				Cairo.TextExtents extents;
				ctx.text_extents (idat[0,0], out extents);
				//fl_barh = fl_barh;
				var xx = extents.width + 40.0;

				if (spew && hard) { 
					print("slst.set_draw_func:\tbarh : %f\n", fl_barh); 
				}

// clamp pos y

				fl_posy = double.min(double.max(fl_posy, (0 - ((fl_barh * idat.length[0])-dah))), 0.0);
				fl_posx = double.min(double.max(fl_posx, (daw - xx)), 0.0);

// paint bg

				var bc = Gdk.RGBA();
				bc.parse(rowc);
				ctx.set_source_rgba(bc.red,bc.green,bc.blue,1);
				ctx.paint();

// check selection hit

				var px = 0.0;
				var py = 0.0;

				if (ipik && fl_mdwn[0] > 0 && izom == false && ipan == false && iscr == false) {
					if (spew && hard) { print("slst.set_draw_func:\tchecking for selection at : %f x %f\n", fl_mdwn[0], fl_mdwn[1]); }
					fl_rule = 99999;
					for (int i = 0; i < idat.length[0]; i++) {
						var onr = int.parse(idat[i,2]);
						px = 0.0;
						py = 0.0;
						px = px + fl_posx;
						py = i * fl_barh;
						py = py + fl_posy;
						if (fl_mdwn[1] > py && fl_mdwn[1] < (py + (fl_barh - 1))) {
							ssrr = onr;
							fl_rule = onr;
							if (spew) { print("slst.set_draw_func:\tselected row : %d\n", onr); }
							fl_trgx = fl_mdwn[0]; fl_trgy = fl_mdwn[1];
							break;
						}
					}
				}

// rows

				if (spew && hard) { print("slst.set_draw_func:\tdrawing %d rows...\n", idat.length[0]); }

				for (int i = 0; i < idat.length[0]; i++) {
					px = 0.0;
					py = 0.0;
					px += fl_posx;
					py = i * fl_barh;
					py = py + fl_posy;
					string xinf = idat[i,0];
					if (ssrr != int.parse(idat[i,2])) { 
						if (bc.parse(idat[i,1]) == false) { bc.parse(txtc); }
						if (spew && hard) { print("slst.set_draw_func:\tgroup %s color : %s\n", idat[i,2], idat[i,1]); }
						ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 0.1));
						ctx.rectangle(0.0, py, daw, (fl_barh - 1));
						ctx.fill ();
						ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 1.0));
						ctx.move_to((px + 10.0), (py + (fl_barh * 0.75)));
						ctx.show_text(xinf);
					} else {
						bc.parse(txtc);
						ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 1.0));
						ctx.rectangle(0.0, py, daw, (fl_barh - 1));
						ctx.fill();
						bc.parse(rowc);
						ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 1.0));
						ctx.move_to((px + 10), (py + (fl_barh * 0.75)));
						ctx.show_text(xinf);
					}
				}

// new rule selection detected, update the rest of the ui
// this should only trigger when ssrr changes

				if (spew && hard) { print("slst.set_draw_func:\tcomparing %d with %d...\n", ssrr, presel); }
				if (ssrr >= 0 && ssrr != presel) {
					dosel = true;
				}

// reset mouseown if not doing anythting with it

				if (izom == false && ipan == false && iscr == false) {
					fl_mdwn[0] = 0;
					fl_mdwn[1] = 0;
					ipik = false;
				}
				if (iscr) {
					iscr = false;
					fl_olsz = {fl_sizx, fl_sizy};
					fl_olof = {fl_posx, fl_posy};
					fl_olmd = {fl_trgx, fl_trgy};
				}
				if (spew && hard) { print("slst.set_draw_func:\tdraw complete\n"); }
			}
		});

//////////////////////////
//                      //
//    graph rendering   //
//                      //
//////////////////////////

		gimg.set_draw_func((da, ctx, daw, dah) => {
			//print("\ngimg.draw: started...\n");
				var presel = ssrr;
				var csx = gimg.get_allocated_width();
				var csy = gimg.get_allocated_height();

// graph coords

				gi_sizx = gi_olsz[0];
				gi_sizy = gi_olsz[1];
				if (izom || iscr) {
					gi_sizx = (gi_olsz[0] + gi_moom[0]);
					gi_sizy = (gi_olsz[1] + gi_moom[1]);
				}
				gi_posx = gi_olof[0];
				gi_posy = gi_olof[1];
				if (izom || iscr) {
					gi_posx = gi_olof[0] + ( (gi_mdwn[0] - gi_olof[0]) - ( (gi_mdwn[0] - gi_olof[0]) * (gi_sizx / gi_olsz[0]) ) ) ;
					gi_posy = gi_olof[1] + ( (gi_mdwn[1] - gi_olof[1]) - ( (gi_mdwn[1] - gi_olof[1]) * (gi_sizy / gi_olsz[1]) ) ) ;
					gi_trgx = gi_olmd[0] + ( (gi_mdwn[0] - gi_olmd[0]) - ( (gi_mdwn[0] - gi_olmd[0]) * (gi_sizx / gi_olsz[0]) ) ) ;
					gi_trgy = gi_olmd[1] + ( (gi_mdwn[1] - gi_olmd[1]) - ( (gi_mdwn[1] - gi_olmd[1]) * (gi_sizy / gi_olsz[1]) ) ) ;
				}
				if(ipan) {
					gi_posx = gi_olof[0] + gi_moom[0];
					gi_posy = gi_olof[1] + gi_moom[1];
					gi_trgx = gi_olmd[0] + gi_moom[0];
					gi_trgy = gi_olmd[1] + gi_moom[1];
				}
				if (ipik) {
					gi_trgx = gi_mdwn[0];
					gi_trgy = gi_mdwn[1];
				}

// graph margins, not used for now

				//var margx = 40.0;
				//var margy = 40.0;

// bar height

				gi_barh = gi_sizy / fdat.length[0];

// get min/max vals from running total

				var minrt = 999999999.0;
				var maxrt = -999999999.0;
				for (int i = 0; i < fdat.length[0]; i++) {
					if (fdat[i,5] != "") {
						maxrt = double.max(maxrt, double.parse(fdat[i,5]));
						minrt = double.min(minrt, double.parse(fdat[i,5]));
					}
				}

// get x scale & zero, scale both to container

				var zro = minrt.abs();
				var xmx = zro + maxrt;
				var sfc = gi_sizx / xmx;
				zro = zro * sfc;
				zro = Math.floor(zro);

// paint bg

				var bc = Gdk.RGBA();
				bc.parse(rowc);
				ctx.set_source_rgba(bc.red,bc.green,bc.blue,1);
				ctx.paint();

// vars for runningtotal and month sizes in bars
// fdat = date, description, amount, cat, group, runningtotal, catcolor, groupcolor, owner, month
// mol = # trans per month
// mox = month number
// eg: mol[2] = 8 tansactions, mox[2] = october

				var xx = 0.0;
				double[] mol = {};
				int[] mox = {};
				int mmy = -1;
				int mrk = -1;
				for (int i = 0; i < fdat.length[0]; i++) {
					if (fdat[i,0] != "") {
						if (fdat[i,9] != "") {
							//print("fdat[i,9] = %s\n", fdat[i,9]);
							var midx = (int.parse(fdat[i,9]) - 1);
// the incoming data is sorted, so grow the month arrays when a change is detected
							if (midx != mmy) { mmy = midx; mrk += 1; mol += 0; mox += 0; }
							mol[mrk] += gi_barh;
							mox[mrk] = mmy;
						}
					}
				}

// draw alternating month backgrounds

				var stackmo = 0.0;
				stackmo = stackmo + gi_posy;
				for (int i = 0; i < mol.length; i++) {
					bc.parse(rowc);
					if (((i + 1) % 2) == 0) {
						bc.parse(txtc);
					}
					ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 0.05));
					ctx.rectangle(0, stackmo, csx, mol[i]);
					ctx.fill();
					bc.parse(txtc);
					ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 0.3));
					ctx.select_font_face("Monospace",Cairo.FontSlant.NORMAL,Cairo.FontWeight.BOLD);
					ctx.set_font_size (14);
					ctx.move_to (5, (stackmo+18));
					var motx = moi(mox[i]);
					ctx.show_text(motx);
					stackmo += mol[i];
				}

// check selection hit

				var px = 0.0;
				var py = 0.0;
				if (ipik && gi_mdwn[0] > 0 && izom == false && ipan == false && iscr == false) {
					gi_trns = 99999;
					for (int i = 0; i < fdat.length[0]; i++) {
						px = 0.0;
						py = 0.0;
						xx = 0.0;
						if (fdat[i,5] != "") { 
							xx = double.parse(fdat[i,5]);
							xx = xx * sfc;
							xx = Math.floor(xx);
							px = double.min((zro + xx),zro);
							px = Math.floor(px);
							px = px + gi_posx;
							py = i * gi_barh;
							py = py + gi_posy;
							if (gi_mdwn[0] > px && gi_mdwn[0] < (px + xx.abs())) {
								if (gi_mdwn[1] > py && gi_mdwn[1] < (py + (gi_barh - 1))) {
									ssrr = int.parse(fdat[i,8]);
									gi_trns = i;
									gi_trgx = gi_mdwn[0]; gi_trgy = gi_mdwn[1];
									break;
								}
							}
						}
					}
				}

// draw bars for running total

				for (int i = 0; i < fdat.length[0]; i++) {
					xx = 0.0;
					px = 0.0;
					py = 0.0;
					if (fdat[i,5] != "") {
						xx = double.parse(fdat[i,5]);
					}
					if (fdat[i,7] != "") {
						if(bc.parse(fdat[i,7])) {
						} else {
							bc.parse(txtc);
						}
					}
					xx = xx * sfc;
					xx = Math.floor(xx);
					px = double.min((zro + xx),zro);
					px = Math.floor(px);
					px = px + gi_posx;
					py = i * gi_barh;
					py = py + gi_posy;
					ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 0.9));
					ctx.rectangle(px, py, xx.abs(), (gi_barh - 1));
					ctx.fill ();
					if (ssrr == int.parse(fdat[i,8])) { 
						bc.red = ((float) 1.0); bc.green = ((float) 1.0); bc.blue = ((float) 1.0);
						ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 0.5));
						ctx.rectangle(px, py, xx.abs(), (gi_barh - 1));
						ctx.fill();
						ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 0.9));
						ctx.rectangle(px+1, py+1, xx.abs()-2, (gi_barh - 3));
						ctx.set_line_width(2);
						ctx.stroke();
					}
				}

// draw selected transaction overlay

				if (gi_trns != 99999) {
					// now.format ("%d/%m/%Y")
					string[] jj = (fdat[gi_trns,0]).split(" ");
					string xinf = "".concat(fdat[gi_trns,0], " : ", fdat[gi_trns,5]);
					Cairo.TextExtents extents;
					ctx.text_extents (xinf, out extents);
					var ibx = extents.width + 40;
					var ixx = double.min(double.max(20,(gi_trgx - (ibx * 0.5))),(gimg.get_allocated_width() - (ibx + 20)));
					var ixy = double.min(double.max(20,(gi_trgy + 20)),(gimg.get_allocated_height() - 50));
					var ltx = double.min(double.max((ixx + 10), gi_trgx),(ixx + ibx - 10));
					var lty = double.min(double.max((ixy + 10), gi_trgy),(ixy + 20));
					bc.parse(tltc);
					ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 1.0));
					ctx.rectangle(ixx, ixy, ibx, 30);
					ctx.fill();

// draw pointer

					ctx.set_line_cap (Cairo.LineCap.ROUND);
					ctx.move_to(gi_trgx, gi_trgy);
					double[] ab = { (gi_trgx - ltx), (gi_trgy - lty), 0.0 };
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
					bc.parse(txtc);
					ctx.set_source_rgba(bc.red,bc.green,bc.blue,0.9);
					ctx.show_text(xinf);
				}

// new rule selection detected, update the rest of the ui

				if (ssrr >= 0 && ssrr != presel) {
					dosel = true;
				}

// reset mouseown if not doing anythting with it

				if (izom == false && ipan == false && iscr == false) {
					gi_mdwn[0] = 0;
					gi_mdwn[1] = 0;
					ipik = false;
				}

// there's no wheel_end event so these go here... its a pulse event so works ok

				if (iscr) { 
					iscr = false;
					gi_olsz = {gi_sizx, gi_sizy};
					gi_olof = {gi_posx, gi_posy};
					gi_olmd = {gi_trgx, gi_trgy};
				}
			//print("gimg.draw: complete\n\n");
			//return true;
		});

////////////////////////////
//                        //
//    graph interaction   //
//                        //
////////////////////////////

		Gtk.GestureDrag sl_touchpan = new Gtk.GestureDrag();
		Gtk.EventControllerScroll sl_wheeler = new Gtk.EventControllerScroll(VERTICAL);
		Gtk.EventControllerMotion sl_hover = new Gtk.EventControllerMotion();

		Gtk.GestureDrag fl_touchpan = new Gtk.GestureDrag();
		Gtk.EventControllerScroll fl_wheeler = new Gtk.EventControllerScroll(VERTICAL);
		Gtk.EventControllerMotion fl_hover = new Gtk.EventControllerMotion();

		Gtk.GestureDrag gi_touchpan = new Gtk.GestureDrag();
		Gtk.EventControllerScroll gi_wheeler = new Gtk.EventControllerScroll(VERTICAL);
		Gtk.EventControllerMotion gi_hover = new Gtk.EventControllerMotion();

		sl_touchpan.set_button(0);
		fl_touchpan.set_button(0);
		gi_touchpan.set_button(0);

		slst.add_controller(sl_touchpan);
		slst.add_controller(sl_wheeler);
		slst.add_controller(sl_hover);
		flst.add_controller(fl_touchpan);
		flst.add_controller(fl_wheeler);
		flst.add_controller(fl_hover);
		gimg.add_controller(gi_touchpan);
		gimg.add_controller(gi_wheeler);
		gimg.add_controller(gi_hover);

		sl_touchpan.drag_begin.connect ((event, x, y) => {
			if (drwm == 0) { 
				if (spew && hard) { print("touchpan_drag_begin\n"); }
				ipik = (event.get_current_button() == 1);
				izom = (event.get_current_button() == 3);
				ipan = (event.get_current_button() == 2);
				sl_mdwn = {x, y};
				if (ipik) { 
					sl_olmd = {sl_mdwn[0], sl_mdwn[1]};
					sl_trgx = sl_mdwn[0]; 
					sl_trgy = sl_mdwn[1]; 
					slst.queue_draw(); 
				}
			}
		});
		sl_touchpan.drag_update.connect((event, x, y) => {
			if (drwm == 0) { 
				if (izom == false && ipan == false && ipik == false) { sl_mdwn = {x, y}; }
				sl_moom = {x, y};
				if (izom || ipan) { slst.queue_draw(); }
			}
		});
		sl_touchpan.drag_end.connect(() => {
			if (spew && hard) { print("touchpan_drag_end\n"); }
			ipan = false;
			izom = false;
			iscr = false;
			if (drwm == 0) { 
				if (ipik) { slst.queue_draw(); }
				sl_olsz = {sl_sizx, sl_sizy};
				sl_olof = {sl_posx, sl_posy};
				sl_olmd = {sl_trgx, sl_trgy};
				sl_olbh = sl_barh;
			}
			if (dosel) { gi_trns = 99999; selectrow(8); dosel = false; }
		});
		sl_hover.motion.connect ((event, x, y) => {
			if (drwm == 0) {
				if (izom == false && ipan == false && ipik == false) { sl_mdwn = {x, y}; }
			}
		});
		sl_wheeler.scroll.connect ((x,y) => {
			if (spew && hard) { print("wheel y = %f\n", y); }
			iscr = true;
			if (drwm == 0) {
				//sl_moom = {(sl_mdwn[0] - (y * 20.0)), (sl_mdwn[1] - (y * 20.0))};
				sl_moom = {0.0, (-y * 20.0)};
				slst.queue_draw();
			}
		});
		fl_touchpan.drag_begin.connect ((event, x, y) => {
			if (drwm == 1) { 
				if (spew && hard) { print("touchpan_drag_begin\n"); }
				ipik = (event.get_current_button() == 1);
				izom = (event.get_current_button() == 3);
				ipan = (event.get_current_button() == 2);
				fl_mdwn = {x, y};
				if (ipik) { 
					fl_olmd = {fl_mdwn[0], fl_mdwn[1]};
					fl_trgx = fl_mdwn[0]; 
					fl_trgy = fl_mdwn[1]; 
					flst.queue_draw(); 
				}
			}
		});
		fl_touchpan.drag_update.connect((event, x, y) => {
			if (drwm == 1) { 
				if (izom == false && ipan == false && ipik == false) { fl_mdwn = {x, y}; }
				fl_moom = {x, y};
				if (izom || ipan) { flst.queue_draw(); }
			}
		});
		fl_touchpan.drag_end.connect(() => {
			if (spew && hard) { print("touchpan_drag_end\n"); }
			ipan = false;
			izom = false;
			iscr = false;
			if (drwm == 1) { 
				if (ipik) { flst.queue_draw(); }
				fl_olsz = {fl_sizx, fl_sizy};
				fl_olof = {fl_posx, fl_posy};
				fl_olmd = {fl_trgx, fl_trgy};
				fl_olbh = fl_barh;
			}
			if (dosel) { gi_trns = 99999; selectrow(8); dosel = false; }
		});
		fl_hover.motion.connect ((event, x, y) => {
			if (drwm == 1) {
				if (izom == false && ipan == false && ipik == false) { fl_mdwn = {x, y}; }
			}
		});
		fl_wheeler.scroll.connect ((x,y) => {
			if (drwm == 1) {
				//if (spew) { print("wheel y = %f\n", y); }
				iscr = true;
				//fl_moom = {(fl_mdwn[0] - (y * 20.0)), (fl_mdwn[1] - (y * 20.0))};
				fl_moom = {0.0, (-y * 20.0)};
				//if (spew) { print("moom.x = %f, moom.y = %f\n", fl_moom[0], fl_moom[1]); }
				flst.queue_draw();
			}
		});
		gi_touchpan.drag_begin.connect ((event, x, y) => {
			if (drwm == 2) {
				if (spew && hard) { print("touchpan_drag_begin\n"); }
				ipik = (event.get_current_button() == 1);
				izom = (event.get_current_button() == 3);
				ipan = (event.get_current_button() == 2);
				gi_mdwn = {x, y};
				if (ipik) {
					gi_olmd = {gi_mdwn[0], gi_mdwn[1]};
					gi_trgx = gi_mdwn[0];
					gi_trgy = gi_mdwn[1];
					gimg.queue_draw();
				}
			}
		});
		gi_touchpan.drag_update.connect((event, x, y) => {
			if (drwm == 2) {
				if (izom == false && ipan == false && ipik == false) { gi_mdwn = {x, y}; }
				gi_moom = {x, y};
				if (izom || ipan) { gimg.queue_draw(); }
			}
		});
		gi_hover.motion.connect ((event, x, y) => {
			if (drwm == 2) {
				if (izom == false && ipan == false && ipik == false) { gi_mdwn = {x, y}; }
				//gi_moom = {x, y};
				//if (izom || ipan) {
					//gimg.queue_draw();
				//}
			}
		});
		gi_touchpan.drag_end.connect(() => {
			if (drwm == 2) { 
				if (spew && hard) { print("touchpan_drag_end\n"); }
				ipan = false;
				izom = false;
				iscr = false;
				if (ipik) { gimg.queue_draw(); }
				gi_olsz = {gi_sizx, gi_sizy};
				gi_olof = {gi_posx, gi_posy};
				gi_olmd = {gi_trgx, gi_trgy};
				gi_olbh = gi_barh;
			}
			if (dosel) { selectrow(8); dosel = false; }
		});
		gi_wheeler.scroll.connect ((x,y) => {
			if (drwm == 2) {
				if (spew && hard) { print("wheel y = %f\n", y); }
				iscr = true;
				gi_moom = {(-y * 50.0), (-y * 50.0)};
				//print("gi_moom[0] = %f, gi_moom[1] = %f\n", gi_moom[0], gi_moom[1]);
				gimg.queue_draw();
			}
		});
		/*
		wheeler.scroll_end.connect (() => {
			//iscr = false;
			sl_olsz = {sl_sizx, sl_sizy};
			sl_olof = {sl_posx, sl_posy};
			sl_olmd = {sl_trgx, sl_trgy};
		});
		gimg.button_press_event.connect ((event) => {
			print("gimg.button_press_event.connect\n");
			gi_mdwn = {event.x, event.y};
			ipik = (event.button == 1);
			izom = (event.button == 3);
			ipan = (event.button == 2);
			if (ipik) { 
				gi_olmd = {gi_mdwn[0], gi_mdwn[1]};
				targx = gi_mdwn[0]; targy = gi_mdwn[1]; 
			}
			return true;
		});
		gimg.motion_notify_event.connect ((event) => {
			if (izom == false && ipan == false && ipik == false) { gi_mdwn = {event.x, event.y}; }
			gi_moom = {event.x, event.y};
			if (izom || ipan) {
				gimg.queue_draw();
			}
			return true;
		});
		gimg.scroll_event.connect ((event) => {
			scrolldir = UP;
			if (event.scroll.direction == scrolldir) {
				iscr = true;
				gi_moom = {(gi_mdwn[0] + 50.0), (gi_mdwn[1] + 50.0)};
				gimg.queue_draw();
			}
			scrolldir = DOWN;
			if (event.scroll.direction == scrolldir)  {
				iscr = true;
				gi_moom = {(gi_mdwn[0] - 50.0), (gi_mdwn[1] - 50.0)};
				gimg.queue_draw();
			}
			return true;
		});

// reset/update stuff on mouse release

		gimg.button_release_event.connect ((event) => {
			print("gimg.button_release_event.connect\n");
			izom = false;
			ipan = false;
			iscr = false;
			if (ipik) { 
				gimg.queue_draw(); 
			}
			gi_olsz = {sizx, sizy};
			gi_olof = {posx, posy};
			gi_olmd = {targx, targy};
			return true;
		});
		*/
}
//public static int main() { 
//	var app = new fulltardie();
//	return app.run();
//}

}


int main (string[] args) {
  var app = new fulltardie();
  app.activate.connect (() => {
    var win = new ftwin(app);
    win.present ();
  });
  return app.run (args);
}

