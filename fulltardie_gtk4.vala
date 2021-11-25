// gtk4 test

//using Gtk;

//public class FTW : Window {
public class fulltardie : Gtk.Application {

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


	public FTW (Gtk.Application fulltardie) {
		Object (application: fulltardie);
	}
	construct {
		this.title = "fulltardie";
		this.set_default_size(720, 500);
		this.close_request.connect((e) => { print("yeh bye"); return true; });
		this.set_margin_top(10);
		this.set_margin_bottom(10);
		this.set_margin_start(10);
		this.set_margin_end(10);
		
		//this.get_size(HORIZONTAL);
		print("window size is: %dx%d\n",this.get_size(HORIZONTAL),this.get_size(VERTICAL));

// add widgets

		Gtk.Label titlelabel = new Gtk.Label("fulltardie");
		//titlelabel.label = "fulltardie";

		Gtk.HeaderBar bar = new Gtk.HeaderBar();
		bar.show_title_buttons  = true;
		bar.set_title_widget(titlelabel);
		this.set_titlebar (bar);

		Gtk.ListBox setuplist = new Gtk.ListBox();
		setuplist.set_selection_mode(SINGLE);
		setuplist.margin_top = 0;
		setuplist.margin_bottom = 0;
		setuplist.margin_start = 0;
		setuplist.margin_end = 0;

		//var setuplistcontainer = new ScrolledWindow(null,null);
		//setuplistcontainer.set_vexpand(true);
		//setuplistcontainer.add(setuplist);

		for (var e = 0; e < dat.length[0]; e++) {
			var ll = new Gtk.Label("");
			ll.xalign = ((float) 0.0);
			var mqq = "".concat("<span font='monospace 16px'><b>", dat[e,10], "</b></span>");
			ll.set_markup(mqq);
			setuplist.insert(ll,-1);
		}

		Gtk.ScrolledWindow setuppage = new Gtk.ScrolledWindow();
		setuppage.set_child(setuplist);

		var label2 = new Gtk.Label(null);
		label2.set_markup("<b><big>setup</big></b>");

		Gtk.Notebook notebook = new Gtk.Notebook();
		notebook.set_show_border(false);
		notebook.set_tab_pos(BOTTOM);
		notebook.append_page(setuppage, label2);

		Gtk.Grid uig = new Gtk.Grid();
		uig.row_spacing = 10;
		uig.attach(notebook,0,0,1,1);
		this.set_child(uig);
	}
	}
}

int main (string[] argv) {
	var app = new fulltardie();
	return app.run(argv);
}
