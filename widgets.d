/**
 * D Text User Interface library - widget classes
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

import std.array;
import std.format;
import std.stdio;
import std.utf;
import base;
import codepage;

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

	// Special application-wide events -----------------------------------

	// Alt-TAB
	if ((event.type == TInputEvent.KEYPRESS) &&
	    (event.key.isKey == true) &&
	    (event.key.fnKey == TKeypress.TAB) &&
	    (event.key.alt == true)
	) {
	    switchWindow();
	    return;
	}

	// F6 - behave like Alt-TAB
	if ((event.type == TInputEvent.KEYPRESS) &&
	    (event.key.isKey == true) &&
	    (event.key.fnKey == TKeypress.F6)
	) {
	    switchWindow();
	    return;
	}

	// Ctrl-W - close window
	if ((event.type == TInputEvent.KEYPRESS) &&
	    (event.key.isKey == false) &&
	    (event.key.ch == 'W') &&
	    (event.key.ctrl)
	) {
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
	    (event.key.isKey == false) &&
	    (event.key.ch == 'Q') &&
	    (event.key.ctrl)
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

/**
 * TWidget is the base class of all objects that can be drawn on
 * screen or handle user input events.
 */
public class TWidget {

    /// Every widget has a parent widget that it may be "contained"
    /// in.  For example, a TWindow might contain several TTextFields,
    /// or a TComboBox may contain a TScrollBar.
    protected TWidget parent = null;

    /// Child widgets that this widget contains.
    protected TWidget [] children;

    /// The window that this widget draws to.
    protected TWindow window = null;

    /// Absolute X position of the top-left corner.
    private int x = 0;

    /// Absolute Y position of the top-left corner.
    private int y = 0;

    /// Width
    private uint width = 0;

    /// Height
    private uint height = 0;

    /**
     * Compute my absolute X position as the sum of my X plus all my
     * parent's X's.
     *
     * Returns:
     *    absolute screen column number for my X position
     */
    public uint getAbsoluteX() {
	assert (parent !is null);
	if (parent is this) {
	    return x;
	}
	if (cast(TWindow)parent) {
	    // Widgets on a TWindow have (0,0) as their top-left, but
	    // this is actually the TWindow's (1,1).
	    return parent.getAbsoluteX() + 1;
	}
	return parent.getAbsoluteX() + x;
    }

    /**
     * Compute my absolute Y position as the sum of my Y plus all my
     * parent's Y's.
     *
     * Returns:
     *    absolute screen row number for my Y position
     */
    public uint getAbsoluteY() {
	assert (parent !is null);
	if (parent is this) {
	    return y;
	}
	if (cast(TWindow)parent) {
	    // Widgets on a TWindow have (0,0) as their top-left, but
	    // this is actually the TWindow's (1,1).
	    return parent.getAbsoluteY() + 1;
	}
	return parent.getAbsoluteY() + y;
    }

    /// Draw my specific widget.  When called, the screen rectangle I
    /// draw into is already setup (offset and clipping).
    protected void draw() {
	// Default widget draws nothing.
    }

    /// Called by parent to render to TWindow.
    public final void drawChildren() {
	// Set my clipping rectangle
	assert (window !is null);
	assert (window.screen !is null);

	window.screen.clipX = width;
	window.screen.clipY = height;

	// Set my offset
	window.screen.offsetX = getAbsoluteX();
	window.screen.offsetY = getAbsoluteY();

	// Draw me
	draw();

	// Continue down the chain
	foreach (w; children) {
	    w.drawChildren();
	}
    }

    /// TWindow needs this constructor.
    protected this() {}

    /// Public constructor.
    public this(TWidget parent) {
	this.parent = parent;
	this.window = parent.window;
    }

    /**
     * Method that subclasses can override to handle keystrokes.
     *
     * Params:
     *    event = keystroke event
     */
    protected void onKeypress(TInputEvent event) {
	// Default: do nothing
    }

    /**
     * Method that subclasses can override to handle mouse button
     * presses.
     *
     * Params:
     *    event = mouse button event
     */
    protected void onMouseDown(TInputEvent event) {
	// Default: do nothing
    }

    /**
     * Method that subclasses can override to handle mouse button
     * releases.
     *
     * Params:
     *    event = mouse button release event
     */
    protected void onMouseUp(TInputEvent event) {
	// Default: do nothing
    }

    /**
     * Method that subclasses can override to handle mouse movements.
     *
     * Params:
     *    event = mouse motion event
     */
    protected void onMouseMotion(TInputEvent event) {
	// Default: do nothing
    }

    /**
     * Consume event.  Subclasses that want to intercept all events
     * in one go can override this method.
     *
     * Params:
     *    event = keyboard or mouse event
     */
    public void handleEvent(TInputEvent event) {
	if (event.type == TInputEvent.KEYPRESS) {
	    onKeypress(event);
	}

	if (event.type == TInputEvent.MOUSE_DOWN) {
	    onMouseDown(event);
	}

	if (event.type == TInputEvent.MOUSE_UP) {
	    onMouseUp(event);
	}

	if (event.type == TInputEvent.MOUSE_MOTION) {
	    onMouseMotion(event);
	}
	// Do nothing
	return;
    }

}

/**
 * TWindow is the top-level container and drawing surface for other
 * widgets.
 */
public class TWindow : TWidget {

    /// Window's parent application.
    private TApplication application;

    /// application's screen
    public Screen screen;

    /// Use the screen drawing primitives like they are ours.  width
    /// and height are INCLUSIVE of the border.
    alias screen this;

    /// Window title
    dstring title = "";

    /// Window is resizable (default yes)
    public immutable ubyte RESIZABLE	= 0x01;

    /// Window is modal (default no)
    public immutable ubyte MODAL	= 0x02;

    /// Window is centered
    public immutable ubyte CENTERED	= 0x04;

    /// Window flags
    private ubyte flags = RESIZABLE;

    /// If true, then the user clicked on the title bar and is moving
    /// the window
    private bool inWindowMove = false;

    /// If true, then the user clicked on the bottom right corner and
    /// is resizing the window
    private bool inWindowResize = false;

    // For moving the window.  resizing also uses moveWindowMouseX/Y
    private uint moveWindowMouseX;
    private uint moveWindowMouseY;
    private int oldWindowX;
    private int oldWindowY;

    // Resizing
    private uint resizeWindowWidth;
    private uint resizeWindowHeight;

    // For maximize/restore
    private uint restoreWindowWidth;
    private uint restoreWindowHeight;
    private int restoreWindowX;
    private int restoreWindowY;

    /// Public constructor
    public this(TApplication application, dstring title,
	uint width, uint height, ubyte flags = RESIZABLE) {

	this(application, title, 0, 0, width, height, flags);
    }

    /// Public constructor.
    public this(TApplication application, dstring title, uint x, uint y,
	uint width, uint height, ubyte flags = RESIZABLE) {

	// I am my own window and parent
	this.parent = this;
	this.window = this;

	// Add me to the application
	application.addWindow(this);

	this.title = title;
	this.application = application;
	this.screen = application.screen;
	this.x = x;
	this.y = y + application.desktopTop;
	this.width = width;
	this.height = height;
	this.flags = flags;

	// Minimum width/height are 10 and 2
	assert(width >= 10);
	assert(height >= 2);

	// MODAL implies CENTERED
	if (isModal()) {
	    this.flags |= CENTERED;
	}

	// Center window if specified
	if ((this.flags & CENTERED) != 0) {
	    this.x = (screen.getWidth() - width) / 2;
	    this.y = (application.desktopBottom - application.desktopTop);
	    this.y -= height;
	    this.y /= 2;
	    this.y += application.desktopTop;
	}
    }

    /// If true, this is the active window that will receive events
    public bool active = false;

    /// Returns true if this window is modal
    public bool isModal() {
	if ((flags & MODAL) == 0) {
	    return false;
	}
	return true;
    }

    /// Z order.  Lower number means more in-front.
    public uint z = false;

    /// Comparison operator sorts on z
    public override int opCmp(Object rhs) {
	auto that = cast(TWindow)rhs;
	if (!that) {
	    return 0;
	}
	return z - that.z;
    }

    /// If true, this window is maximized
    public bool maximized = false;

    /// Returns true if the mouse is currently on the close button
    private bool mouseOnClose() {
	if ((mouse !is null) &&
	    (mouse.absoluteY == y) &&
	    (mouse.absoluteX == x + 3)
	) {
	    return true;
	}
	return false;
    }    

    /// Returns true if the mouse is currently on the maximize/restore
    /// button
    private bool mouseOnMaximize() {
	if ((mouse !is null) &&
	    !isModal() &&
	    (mouse.absoluteY == y) &&
	    (mouse.absoluteX == x + width - 4)
	) {
	    return true;
	}
	return false;
    }    

    /// Returns true if the mouse is currently on the resizable lower
    /// right corner
    private bool mouseOnResize() {
	if (((flags & RESIZABLE) != 0) &&
	    !isModal() &&
	    (mouse !is null) &&
	    (mouse.absoluteY == y + height - 1) &&
	    (	(mouse.absoluteX == x + width - 1) ||
		(mouse.absoluteX == x + width - 2))
	) {
	    return true;
	}
	return false;
    }    

    /// Called by TApplication.drawChildren() to render on screen.
    override public void draw() {
	// Draw the box and background first.
	CellAttributes border;
	CellAttributes background;
	uint borderType = 1;

	if (!isModal() && (inWindowMove || inWindowResize)) {
	    assert(active == 1);
	    border = application.theme.getColor("twindow.border.windowmove");
	    background = application.theme.getColor("twindow.background.windowmove");
	} else if (isModal() && inWindowMove) {
	    assert(active == 1);
	    border = application.theme.getColor("twindow.border.modal.windowmove");
	    background = application.theme.getColor("twindow.background.modal");
	} else if (isModal()) {
	    assert(active == 1);
	    border = application.theme.getColor("twindow.border.modal");
	    background = application.theme.getColor("twindow.background.modal");
	    borderType = 2;
	} else if (active) {
	    assert(!isModal());
	    border = application.theme.getColor("twindow.border");
	    background = application.theme.getColor("twindow.background");
	    borderType = 2;
	} else {
	    assert(!isModal());
	    border = application.theme.getColor("twindow.border.inactive");
	    background = application.theme.getColor("twindow.background.inactive");
	}
	drawBox(0, 0, width, height, border, background, borderType, true);

	if (!inWindowMove) {
	    // Draw the title
	    uint titleLeft = (width - cast(uint)title.length - 2)/2;
	    putCharXY(titleLeft, 0, ' ', border);
	    putStrXY(titleLeft + 1, 0, title);
	    putCharXY(titleLeft + cast(uint)title.length + 1, 0, ' ', border);
	}

	if (active && !inWindowMove) {

	    // Draw the close button
	    putCharXY(2, 0, '[', border);
	    putCharXY(4, 0, ']', border);
	    if (mouseOnClose() && mouse.mouse1) {
		putCharXY(3, 0, cp437_chars[0x0F],
		    !isModal() ?
		    application.theme.getColor("twindow.border.windowmove") :
		    application.theme.getColor("twindow.border.modal.windowmove"));
	    } else {
		putCharXY(3, 0, cp437_chars[0xFE],
		    !isModal() ?
		    application.theme.getColor("twindow.border.windowmove") :
		    application.theme.getColor("twindow.border.modal.windowmove"));
	    }

	    // Draw the maximize button
	    if (!isModal()) {
		
		putCharXY(width - 5, 0, '[', border);
		putCharXY(width - 3, 0, ']', border);
		if (mouseOnMaximize() && mouse.mouse1) {
		    putCharXY(width - 4, 0, cp437_chars[0x0F],
			application.theme.getColor("twindow.border.windowmove"));
		} else {
		    if (maximized) {
			putCharXY(width - 4, 0, cp437_chars[0x12],
			    application.theme.getColor("twindow.border.windowmove"));
		    } else {
			putCharXY(width - 4, 0, GraphicsChars.UPARROW,
			    application.theme.getColor("twindow.border.windowmove"));
		    }
		}

		// Draw the resize corner
		if (!inWindowResize && ((flags & RESIZABLE) != 0)) {
		    putCharXY(width - 2, height - 1, GraphicsChars.SINGLE_BAR,
			application.theme.getColor("twindow.border.windowmove"));
		    putCharXY(width - 1, height - 1, GraphicsChars.LRCORNER,
			application.theme.getColor("twindow.border.windowmove"));
		}
	    }
	}

	// DEBUG: print mouse coordinates
	if (mouse !is null) {
	    auto writer = appender!string();
	    formattedWrite(writer, "Mouse relative %u %u", mouse.x, mouse.y);
	    putStrXY(1, 1, toUTF32(writer.data));
	    writer = appender!string();
	    formattedWrite(writer, "Mouse absolute %u %u", mouse.absoluteX,
		mouse.absoluteY);
	    putStrXY(1, 2, toUTF32(writer.data));
	}
    }

    /// Remember mouse state
    private TInputEvent mouse;    

    /**
     * Handle mouse button presses.
     *
     * Params:
     *    event = mouse button event
     */
    override protected void onMouseDown(TInputEvent event) {
	mouse = event;
	application.repaint = true;

	if ((mouse.absoluteY == y) && mouse.mouse1 &&
	    !mouseOnClose() &&
	    !mouseOnMaximize()
	) {
	    // Begin moving window
	    inWindowMove = true;
	    moveWindowMouseX = mouse.absoluteX;
	    moveWindowMouseY = mouse.absoluteY;
	    oldWindowX = x;
	    oldWindowY = y;
	    if (maximized) {
		maximized = false;
	    }
	}
	if (mouseOnResize()) {
	    // Begin window resize
	    inWindowResize = true;
	    moveWindowMouseX = mouse.absoluteX;
	    moveWindowMouseY = mouse.absoluteY;
	    resizeWindowWidth = width;
	    resizeWindowHeight = height;
	    if (maximized) {
		maximized = false;
	    }
	}
    }

    /**
     * Handle mouse button releases.
     *
     * Params:
     *    event = mouse button release event
     */
    override protected void onMouseUp(TInputEvent event) {
	mouse = event;
	application.repaint = true;

	if ((inWindowMove == true) && (mouse.mouse1)) {
	    // Stop moving window
	    inWindowMove = false;
	}

	if ((inWindowResize == true) && (mouse.mouse1)) {
	    // Stop resizing window
	    inWindowResize = false;
	}

	if (mouse.mouse1 && mouseOnClose()) {
	    // Close window
	    application.closeWindow(this);
	}

	if ((mouse.absoluteY == y) && mouse.mouse1 &&
	    mouseOnMaximize()) {

	    if (maximized) {
		// Restore
		width = restoreWindowWidth;
		height = restoreWindowHeight;
		x = restoreWindowX;
		y = restoreWindowY;
		maximized = false;
	    } else {
		// Maximize
		restoreWindowWidth = width;
		restoreWindowHeight = height;
		restoreWindowX = x;
		restoreWindowY = y;
		width = screen.getWidth();
		height = application.desktopBottom - 1;
		x = 0;
		y = 1;
		maximized = true;
	    }
	}
    }

    /**
     * Handle mouse movements.
     *
     * Params:
     *    event = mouse motion event
     */
    override protected void onMouseMotion(TInputEvent event) {
	mouse = event;
	application.repaint = true;

	if (inWindowMove == true) {
	    // Move window over
	    x = oldWindowX + (mouse.absoluteX - moveWindowMouseX);
	    y = oldWindowY + (mouse.absoluteY - moveWindowMouseY);
	    // Don't cover up the menu bar
	    if (y < 1) {
		y = 1;
	    }
	}

	if (inWindowResize == true) {
	    // Move window over
	    width = resizeWindowWidth + (mouse.absoluteX - moveWindowMouseX);
	    height = resizeWindowHeight + (mouse.absoluteY - moveWindowMouseY);
	    if (x + width > screen.getWidth()) {
		width = screen.getWidth() - x;
	    }
	    if (y + height > application.desktopBottom) {
		y = height - application.desktopBottom;
	    }
	    if (width < 10) {
		width = 10;
	    }
	    if (height < 2) {
		height = 2;
	    }
	}
    }

}

// Functions -----------------------------------------------------------------
