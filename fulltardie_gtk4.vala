// gtk4 test: container within container within container within container within container...
// just to supply args to something, instead of just supplying it directly, eg:
// in a normal healthy language: button/color: (0.1,0.8,0.1,1.0)
// in gtk4 its:

using Gtk;

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

	string textcolor = "#55BDFF";
	string rowcolor ="#1A3B4F";
	string ttcolor = "#112633";

// FTW is already defined as a window, so dunno why it has to be redefined here as a function that returns its parent... very odd.

// gtk3 =
//
//        [ main ]
//           |
//    [ application ]
//           |
//       [ window ]
//           |
// [ widgets & events ]


// gtk4 =
// 
//        [ main ]
//           |
//    [ application ]
//           |
//       [ window ]
//           |
// [ window(application) = object(application) ] <----- what in the actual ass...
//           |
//  [ widgets & events ]


	public FTW (Gtk.Application fulltardie) {
		Object (application: fulltardie);
	}

// anyway, the ui:

	construct {
		this.title = "fulltardie";
		this.set_default_size(360, 720);
		this.close_request.connect((e) => { print("yeh bye\n"); return false; });
		this.set_margin_top(10);
		this.set_margin_bottom(10);
		this.set_margin_start(10);
		this.set_margin_end(10);

// get_size in gtk4 is wrong

		print("window size is: %dx%d\n",this.get_size(HORIZONTAL),this.get_size(VERTICAL));

// add widgets

		Gtk.Label titlelabel = new Gtk.Label("fulltardie");
		Gtk.HeaderBar bar = new Gtk.HeaderBar();
		bar.show_title_buttons  = true;
		bar.set_title_widget(titlelabel);
		this.set_titlebar (bar);

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

// setup-page container

		Gtk.ScrolledWindow setuppage = new Gtk.ScrolledWindow();
		setuppage.set_child(setuplist);

// params

		Gtk.Entry dsc = new Gtk.Entry();
		dsc.text = dat[0,10];
		dsc.hexpand = true;

		Gtk.ToggleButton iso = new Gtk.ToggleButton.with_label("ISO");

		Gtk.Button ads = new Gtk.Button.with_label("+");
		ads.set_size_request(10,10);
		Gtk.Button rms = new Gtk.Button.with_label("-");

		Gtk.Box paramtop = new Gtk.Box(HORIZONTAL,10);
		paramtop.append(dsc);
		paramtop.append(iso);
		paramtop.append(ads);
		paramtop.append(rms);

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

// group category and amount params

		Gtk.Label glb = new Label("grp");
		glb.set_max_width_chars(8);
		glb.set_halign(START);
		glb.set_hexpand(false);
		var groupcombo = new ComboBoxText.with_entry();
		groupcombo.set_halign(START);
		var vv = (Entry) groupcombo.get_child();
		vv.set_width_chars(8);
		Gtk.Button groupcolorbutton = new Gtk.Button();
		groupcolorbutton.set_size_request (20,10);
		var www = Gdk.RGBA();
		www.parse(textcolor);

// swatch background color (26, 59, 79)
// setting background color directly is busted/disabled in gtk4 for political reasons,
// investigating the current prescribed method...

		//groupcolorbutton.override_background_color(NORMAL, www); 
		Gtk.Popover groupcolorpopover = new Gtk.Popover();
		Gtk.Box groupcolorpopoverbox = new Gtk.Box (VERTICAL,2);
		groupcolorpopoverbox.set_size_request (200,10);
		groupcolorpopover.set_child(groupcolorpopoverbox);
		Gtk.Scale rrr = new Gtk.Scale.with_range(HORIZONTAL, 0, 255, 100);
		rrr.set_value(26);
		Gtk.Scale ggg = new Gtk.Scale.with_range(HORIZONTAL, 0, 255, 100);
		ggg.set_value(59);
		Gtk.Scale bbb = new Gtk.Scale.with_range(HORIZONTAL, 0, 255, 100);
		bbb.set_value(79);
		var hhh = new Entry();
		hhh.text = "#1A3B4F";
		hhh.set_width_chars(8);
		groupcolorpopoverbox.append(hhh);
		groupcolorpopoverbox.append(rrr);
		groupcolorpopoverbox.append(ggg);
		groupcolorpopoverbox.append(bbb);

// category

		Gtk.Label clb = new Label("cat");
		clb.set_max_width_chars(8);
		clb.set_halign(START);
		var catcombo = new ComboBoxText.with_entry();
		var ee = (Entry) catcombo.get_child();
		ee.set_width_chars(8);

// amount

		Gtk.Label alb = new Label("amt");
		alb.set_max_width_chars(8);
		alb.set_halign(START);
		Gtk.Adjustment adj = new Gtk.Adjustment(0.0,-100000,100000.0,10.0,100.0,1.0);
		Gtk.SpinButton amountspinner = new Gtk.SpinButton(adj,1.0,2);

// lower flowbox

		Gtk.FlowBox parambottom = new Gtk.FlowBox();
		parambottom.set_orientation(Orientation.HORIZONTAL);
		parambottom.min_children_per_line = 1;
		parambottom.max_children_per_line = 7;
		parambottom.insert(amountspinner,0);
		parambottom.insert(alb,0);
		parambottom.insert(catcombo,0);
		parambottom.insert(clb,0);
		parambottom.insert(groupcolorbutton,0);
		parambottom.insert(groupcombo,0);
		parambottom.insert(glb,0);

// assemble params

		Gtk.Grid paramgrid = new Gtk.Grid();
		paramgrid.margin_top = 10;
		paramgrid.margin_bottom = 10;
		paramgrid.margin_start = 10;
		paramgrid.margin_end = 80;
		paramgrid.row_spacing = 10;
		paramgrid.attach(paramtop,0,0,1,1);
		paramgrid.attach(parammid,0,1,1,1);
		paramgrid.attach(parambottom,0,2,1,1);

		Gtk.ScrolledWindow params = new Gtk.ScrolledWindow();
		params.set_child(paramgrid);
		params.margin_top = 10;

// notebook

		var label2 = new Gtk.Label(null);
		label2.set_markup("<b><big>setup</big></b>");

		Gtk.Notebook notebook = new Gtk.Notebook();
		notebook.set_show_border(false);
		notebook.set_tab_pos(BOTTOM);
		notebook.append_page(setuppage, label2);
		notebook.margin_bottom = 10;

// separator

		Gtk.Paned hdiv = new Gtk.Paned(VERTICAL);
		hdiv.start_child = notebook;
		hdiv.end_child = params;
		hdiv.resize_end_child = true;
		hdiv.position = 580;
		hdiv.wide_handle = true;

// add ui to window

		this.set_child(hdiv);
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
