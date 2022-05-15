# fulltardie

forecast transactions that have complex recurrence rules

4th & current edition
- significantly faster
- 64-bit
- runs on arm devices
- compact ui for phone
- expanded forecasting capabilities

# status
- work in progress (see todo below).
- usable for forecasting, saves and loads, but without any safety; you can crash it without too much effort, eg: deleting all items, blank names, etc..
- touch interaction for pinephone not implemented yet.

# TODO
- [ ] find cause of random startup graphics error on pinephone
- [ ] implement touch interaction with cairo drawingarea
- [ ] clearly differentiate touch events on cairo drawingarea (tap, drag, longpress, pinch)
- [ ] double-click/tap on empty space to re-fit drawingarea content
- [ ] try to get smoothly resizing fonts in cairo (investigate vulcan shader if this can't be done)
- [ ] fix paned separator touch area (its way too big compared to mouse area)
- [ ] lock second paned child width to user-specified width (via separator drag) while in vertical orientation
- [ ] double-tap calendar to frame this month
- [ ] prevent panning stuff completely off-screen
- [ ] maintain aspect for mousewheel zoom in graph & calendar
- [ ] fix zoom-focus location in calendar
- [ ] prevent inversion when zooming
- [ ] recalc mousewheel zoom incrament to maintain consistent velocity
- [ ] complete rule component renaming/re-arranging to make more sense in plain english
- [ ] drag-n-drop reorder of rules
- [ ] isolate category
- [ ] remove orphaned groups/categories from dropdown lists
- [ ] try to break the forecast with malicious usage and fix accordingly
- [ ] gnome notification integration for next week of transactions
- [ ] add done button to transaction notifications (notifications persist otherwise)
- [ ] add notification doubleclick to focus in fulltardie
- [ ] add layered circle graph tab (group, category)
- [ ] add highlight and info bubble to circle graph selection
- [ ] add export circle graph to png
- [ ] investigate dragging a tab into new panel (will need to replace paned)
- [ ] given the above, save layout with scenario
- [ ] given the above, consolidate layout when window size is reduced, restore layout when window size is increased again

# usage (testing, linux only)
- install gtk4-devel
- install valac
- mkdir ~/Desktop/fulltardie && cd ~/Desktop/fulltardie
- wget -O fulltardie_gtk4_cairo.vala https://raw.githubusercontent.com/snotbubble/fulltardie4/main/fulltardie_gtk4_cairo.vala
- valac fulltardie_gtk4_cairo.vala --pkg gtk4 -X -lm
- ./fulltardie_gtk4_cairo

# screenies
![screenie](./211203_fulltardie4_screenie.png)

# calendar (wip)
![calendar](./220325_fulltardie_screenie.png)
