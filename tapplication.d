/**
 * D Text User Interface library - TApplication class
 *
 * Version: $Id$
 *
 * Author: Kevin Lamonte, <a href="mailto:kevin.lamonte@gmail.com">kevin.lamonte@gmail.com</a>
 *
 * License: LGPLv3 or later
 *
 * Copyright: This module is licensed under the GNU Lesser General
 * Public License Version 3.  Please see the file "COPYING" in this
 * directory for more information about the GNU Lesser General Public
 * License Version 3.
 *
 *     Copyright (C) 2013  Kevin Lamonte
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * as published by the Free Software Foundation; either version 3 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this program; if not, see
 * http://www.gnu.org/licenses/, or write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301 USA
 */

// Description ---------------------------------------------------------------

// Imports -------------------------------------------------------------------

import core.thread;
import std.stdio;
import base;
import codepage;
import twidget;
import twindow;
import tmessagebox;

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * TApplication sets up a full Text User Interface application.
 */
public class TApplication {

    /// All drawing for the application renders to this Screen.
    public Screen screen;

    /// Input events are processed by this Terminal.
    private Terminal terminal;

    /// Actual mouse coordinate X
    private uint mouseX;

    /// Actual mouse coordinate Y
    private uint mouseY;

    /// Fiber for main handleEvent loop
    private Fiber primaryEventFiber;
    
    /// Fiber for scondary handleEvent loop - used by TMessageBox
    private Fiber secondaryEventFiber;

    /// Public constructor.
    public this() {
	screen = new Screen();
	theme = new ColorTheme();

	desktopBottom = screen.getHeight() - 1;
    }

    /// Windows in this application.
    private TWindow [] windows;

    /// Windows and widgets pull colors from this ColorTheme.
    public ColorTheme theme;

    /// When true, exit the application.
    public bool quit = false;

    /// When true, repaint the entire screen
    public bool repaint = true;

    /// When true, just flush updates from the screen.
    public bool flush = false;

    /// Y coordinate of the top edge of the desktop.
    public immutable uint desktopTop = 1;

    /// Y coordinate of the bottom edge of the desktop.
    public uint desktopBottom;

    /// Invert the cell at the mouse pointer position
    private void flipMouse() {

	ubyte [] sgrToPCMap = [
	    COLOR_BLACK,
	    COLOR_BLUE,
	    COLOR_GREEN,
	    COLOR_CYAN,
	    COLOR_RED,
	    COLOR_MAGENTA,
	    COLOR_YELLOW,
	    COLOR_WHITE
	];

	CellAttributes attr = screen.getAttrXY(mouseX, mouseY);
	attr.foreColor = sgrToPCMap[attr.foreColor] ^ 0x7;
	attr.backColor = sgrToPCMap[attr.backColor] ^ 0x7;
	screen.putAttrXY(mouseX, mouseY, attr, false);
	flush = true;
    }

    /**
     * Draw everything.
     *
     * Returns:
     *    escape sequences string that provides the updates to the
     *    physical screen
     */
    public string drawAll() {
	if ((flush) && (!repaint)) {
	    string result = screen.flushString();
	    flush = false;
	    return result;
	}
	
	if (!repaint) {
	    return "";
	}

	// Start with a clean screen
	screen.clear();

	// Kill the cursor
	string result = terminal.cursor(false);

	// Draw the background
	CellAttributes background = theme.getColor("tapplication.background");
	screen.putAll(GraphicsChars.HATCH, background);

	// Draw each window in reverse Z order
	TWindow [] sorted = windows.dup;
	sorted.sort.reverse;
	foreach (w; sorted) {
	    w.drawChildren();
	}

	// Place the mouse pointer
	flipMouse();

	// Get the screen contents
	result ~= screen.flushString();

	// TODO: place the cursor if it is visible

	repaint = false;
	flush = false;
	return result;
    }

    /**
     * Add a window to my window list and make it active
     *
     * Params:
     *    window = new window to add
     */
    public void addWindow(TWindow window) {
	foreach (w; windows) {
	    // Only one modal window at a time
	    assert(!w.isModal());
	    w.active = false;
	    w.z++;
	}
	windows ~= window;
	window.active = true;
	window.z = 0;
    }

    /// Switch to the next window
    public void switchWindow() {
	// Only switch if there are multiple windows
	if (windows.length < 2) {
	    return;
	}

	// Swap z/active between active window and the next in the
	// list
	int activeWindowI = -1;
	for (auto i = 0; i < windows.length; i++) {
	    if (windows[i].active) {
		activeWindowI = i;
		break;
	    }
	}
	assert(activeWindowI >= 0);

	// Do not switch if a window is modal
	if (windows[activeWindowI].isModal()) {
	    return;
	}

	ulong nextWindowI = (activeWindowI + 1) % windows.length;
	windows[activeWindowI].active = false;
	windows[activeWindowI].z = windows[nextWindowI].z;
	windows[nextWindowI].z = 0;
	windows[nextWindowI].active = true;

	// Refresh
	repaint = true;
    }

    /// See if we need to switch window based on a mouse click
    public void checkSwitchFocus(TInputEvent mouse) {
	// Only switch if there are multiple windows
	if (windows.length < 2) {
	    return;
	}

	// Switch on the upclick
	if (mouse.type != TInputEvent.MOUSE_UP) {
	    return;
	}

	windows.sort;
	if (windows[0].isModal()) {
	    // Modal windows don't switch
	    return;
	}

	foreach (w; windows) {
	    assert(!w.isModal());
	    if ((mouse.absoluteX >= w.x) &&
		(mouse.absoluteX <= w.x + w.width - 1) &&
		(mouse.absoluteY >= w.y) &&
		(mouse.absoluteY <= w.y + w.height - 1)
	    ) {
		if (w is windows[0]) {
		    // Clicked on the same window, nothing to do
		    return;
		}

		// We will be switching to another window
		assert(windows[0].active);
		assert(!w.active);
		windows[0].active = false;
		windows[0].z = w.z;
		w.z = 0;
		w.active = true;
		repaint = true;
		return;
	    }
	}

	// Clicked on the background, nothing to do
	return;
    }

    /**
     * Close window.  Note that the window's destructor is NOT called
     * by this method, instead the GC is assumed to do the cleanup.
     *
     * Params:
     *    window = the window to remove
     */
    public void closeWindow(TWindow window) {
	uint z = window.z;
	window.z = -1;
	windows.sort;
	windows = windows[1 .. $];
	TWindow activeWindow = null;
	foreach (w; windows) {
	    if (w.z > z) {
		w.z--;
		if (w.z == 0) {
		    w.active = true;
		    assert(activeWindow is null);
		    activeWindow = w;
		} else {
		    w.active = false;
		}
	    }
	}
    }

    /**
     * Dispatch one event to the appropriate widget or
     * application-level event handler.
     *
     * Params:
     *    event the input event to consume
     */
    private void handleEvent(TInputEvent event) {

	// TODO: use primaryEventFiber and secondaryEventFiber


	// Special application-wide events -----------------------------------

	// Alt-TAB
	if ((event.type == TInputEvent.KEYPRESS) &&
	    (event.key == kbAltTab)) {

	    switchWindow();
	    return;
	}

	// F6 - behave like Alt-TAB
	if ((event.type == TInputEvent.KEYPRESS) &&
	    (event.key == kbF6)) {

	    switchWindow();
	    return;
	}

	// Ctrl-W - close window
	if ((event.type == TInputEvent.KEYPRESS) &&
	    (event.key == kbCtrlW)) {

	    // Resort windows and nix the first one (it is active)
	    if (windows.length > 0) {
		windows.sort;
		closeWindow(windows[0]);
	    }

	    // Refresh
	    repaint = true;
	}

	// Ctrl-Q - quit app
	if ((event.type == TInputEvent.KEYPRESS) &&
	    ((event.key == kbAltX) || (event.key == kbAltShiftX))
	) {

	    quit = true;
	    return;
	}

	// Peek at the mouse position
	if (event.type != TInputEvent.KEYPRESS) {
	    if ((mouseX != event.x) || (mouseY != event.y)) {
		flipMouse();
		mouseX = event.x;
		mouseY = event.y;
		flipMouse();
	    }

	    // See if we need to switch focus
	    checkSwitchFocus(event);
	}

	// Dispatch events to the right window --------------------------------

	foreach (w; windows) {
	    if (w.active) {
		if (event.type != TInputEvent.KEYPRESS) {
		    // Convert the mouse relative x/y to window coordinates
		    if (event.x > w.x) {
			event.x -= w.x;
		    } else {
			event.x = 0;
		    }
		    if (event.y > w.y) {
			event.y -= w.y;
		    } else {
			event.y = 0;
		    }
		    if (event.x > w.width - 1) {
			event.x = w.width - 1;
		    }
		    if (event.y > w.height - 1) {
			event.y = w.height - 1;
		    }
		}
		w.handleEvent(event);
		break;
	    }
	}
    }

    /**
     * Pass this raw input char into the event loop.  This will be
     * processed by Terminal.getEvent().
     *
     * Params:
     *    ch = Unicode code point
     */
    public void processChar(dchar ch) {
	if (terminal is null) {
	    terminal = new Terminal(false);
	}
	TInputEvent [] events = terminal.getEvents(ch);
	foreach (event; events) {
	    handleEvent(event);
	}
    }

    // TODO: Timer

    // TODO: Status bar

    // TODO: Menu bar

    version(Posix) {
	// Used in run() to poll stdin
	import core.sys.posix.poll;
    }

    /// Do stuff when there is no user input
    private void doIdle() {
	// Pull any pending input events
	TInputEvent [] events = terminal.getEvents(0, true);
	foreach (event; events) {
	    handleEvent(event);
	}

	// TODO: now run any timers that have timed out

    }

    /// Obtain a TMessageBox
    public TMessageBox MessageBox(string title, string text) {
	// TODO
	return null;
    }

    /// Run this application until it exits, using stdin and stdout
    public void run() {
	// Create a terminal and explicitly set stdin into raw mode
	assert(terminal is null);
	terminal = new Terminal(true);

	// Reset the screen size
	screen.setDimensions(terminal.getPhysicalWidth(),
	    terminal.getPhysicalHeight());
	desktopBottom = screen.getHeight() - 1;

	// Clear the screen
	stdout.writef(Terminal.clearAll());
	stdout.flush();

	// Use poll() on stdin
	pollfd pfd;

	while (quit == false) {

	    // Poll on stdin.  Last parameter is milliseconds, so timeout
	    // after 0.1 seconds of inactivity.
	    // TODO: change timeout to work with Timers
	    pfd.fd = stdin.fileno();
	    pfd.events = POLLIN;
	    pfd.revents = 0;

	    auto poll_rc = poll(&pfd, 1, 100);

	    // stderr.writef("poll() %d\r\n", poll_rc);

	    if (poll_rc < 0) {
		// Interrupt
		continue;
	    }

	    if (poll_rc > 0) {
		// We have something to read
		dchar ch = terminal.getCharStdin();
		processChar(ch);
	    }

	    if (poll_rc == 0) {
		// Timeout
		doIdle();
	    }

	    // Update the screen
	    string output = drawAll();
	    stdout.writef(output);
	    stdout.flush();
	}
    }

}

// Functions -----------------------------------------------------------------
