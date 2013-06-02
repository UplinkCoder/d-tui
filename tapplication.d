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
import tmenu;

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
    
    /// Fiber for scondary handleEvent loop
    private Fiber secondaryEventFiber;

    /// Widget to receive events if secondaryEventFiber is called
    private TWidget secondaryEventReceiver;

    /// Event queue that will be drained by either primary or secondary Fiber
    private TInputEvent [] eventQueue;

    /// Windows in this application.
    private TWindow [] windows;

    /// Top-level menus in this application.
    private TMenu [] menus;

    /// The currently acive menu
    private TMenu activeMenu = null;

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

    /// Active keyboard accelerators
    private TCommand[TKeypress] accelerators;

    /// Public constructor.
    public this() {
	screen = new Screen();
	theme = new ColorTheme();

	desktopBottom = screen.getHeight() - 1;

	primaryEventFiber = new Fiber(&primaryEventHandler);
    }

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

	// Draw the blank menubar line - reset the screen clipping first so
	// it won't trim it out.
	screen.resetClipping();
	screen.hLineXY(0, 0, screen.getWidth(), ' ', theme.getColor("tmenu"));
	// Now draw the menus.
	uint x = 1;
	foreach (m; menus) {
	    CellAttributes menuColor;
	    if (m.active) {
		menuColor = theme.getColor("tmenu.highlighted");
	    } else {
		menuColor = theme.getColor("tmenu");
	    }
	    // Draw the menu title
	    screen.hLineXY(x, 0, cast(uint)m.title.length + 2, ' ', menuColor);
	    screen.putStrXY(x + 1, 0, m.title, menuColor);

	    if (m.active) {
		m.drawChildren();
		// Reset the screen clipping so we can draw the next title.
		screen.resetClipping();
	    }
	    x += m.title.length + 2;
	}

	// Place the mouse pointer
	flipMouse();

	// Get the screen contents
	result ~= screen.flushString();

	// Place the cursor if it is visible
	TWidget activeWidget = null;
	if (sorted.length > 0) {
	    activeWidget = sorted[$ - 1].getActiveChild();
	    if (activeWidget.hasCursor) {
		result ~= terminal.cursor(true);
		result ~= terminal.gotoXY(activeWidget.getCursorAbsoluteX(),
		    activeWidget.getCursorAbsoluteY());
	    }
	}

	repaint = false;
	flush = false;
	return result;
    }

    /**
     * Add a keyboard accelerator to the global list
     *
     * Params:
     *    command = command to send to the active widget
     *    keypress = keypress that will activate the command
     */
    public void addAccelerator(TCommand command, TKeypress keypress) {
	accelerators[keypress] = command;
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

    /// See if we need to switch window or activate the menu based on
    /// a mouse click
    public void checkSwitchFocus(TMouseEvent mouse) {

	if ((mouse.type == TMouseEvent.Type.MOUSE_DOWN) &&
	    (activeMenu !is null) &&
	    (!activeMenu.mouseWouldHit(mouse))
	) {
	    // They clicked outside the active menu, turn it off
	    activeMenu.active = false;
	    activeMenu = null;
	    // Continue checks
	}

	// See if they hit the menu bar
	if ((mouse.type == TMouseEvent.Type.MOUSE_DOWN) &&
	    (activeMenu is null)) {

	    // They selected the menu, go activate it
	    foreach (m; menus) {
		if ((mouse.absoluteY == 0) &&
		    (mouse.absoluteX >= m.x) &&
		    (mouse.absoluteX < m.x + m.title.length + 2)
		) {
		    m.active = true;
		    activeMenu = m;
		}
	    }
	    repaint = true;
	    return;
	}

	// Only switch if there are multiple windows
	if (windows.length < 2) {
	    return;
	}

	// Switch on the upclick
	if (mouse.type != TMouseEvent.Type.MOUSE_UP) {
	    return;
	}

	windows.sort;
	if (windows[0].isModal()) {
	    // Modal windows don't switch
	    return;
	}

	foreach (w; windows) {
	    assert(!w.isModal());
	    if (w.mouseWouldHit(mouse)) {
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

	// Check if we are closing a TMessageBox or similar
	if (secondaryEventReceiver !is null) {
	    assert(secondaryEventFiber !is null);

	    // Do not send events to the secondaryEventReceiver anymore, the
	    // window is closed.
	    secondaryEventReceiver = null;

	    // Special case: if this is called while executing on a
	    // secondaryEventFiber, call it so that widgetEventHandler() can
	    // terminate.
	    if (secondaryEventFiber.state == Fiber.State.HOLD) {
		secondaryEventFiber.call();
	    }

	    // Kill the fiber reference so we don't call it again in
	    // processChar().
	    secondaryEventFiber = null;

	    // Wake up the primary handler if it is waiting
	    if (primaryEventFiber.state == Fiber.State.HOLD) {
		primaryEventFiber.call();
	    }
	}
    }

    /**
     * Enable a widget to override the event queue
     *
     * Params:
     *    widget = widget that will receive events
     */
    public void enableSecondaryEventReceiver(TWidget widget) {
	assert(secondaryEventReceiver is null);
	assert(secondaryEventFiber is null);
	assert(cast(TMessageBox)widget);
	secondaryEventReceiver = widget;
	secondaryEventFiber = new Fiber(&widgetEventHandler);
    }

    /**
     * Post an event to process
     *
     * Params:
     *    event = new event to add to the queue
     */
    public void addEvent(TInputEvent event) {
	eventQueue ~= event;
    }

    /**
     * Post an event to process and turn off the menu
     *
     * Params:
     *    event = new event to add to the queue
     */
    public void addMenuEvent(TInputEvent event) {
	eventQueue ~= event;
	assert(activeMenu !is null);
	activeMenu.active = false;
	activeMenu = null;
    }

    /**
     * Peek at certain application-level events, add to eventQueue,
     * and wake up the consuming Fiber.
     *
     * Params:
     *    events the input events to consume
     */
    private void metaHandleEvents(TInputEvent [] events) {

	foreach (event; events) {
	    
	    // Special application-wide events -------------------------------

	    // Screen resize
	    if (auto resize = cast(TResizeEvent)event) {
		screen.setDimensions(resize.width, resize.height);
		desktopBottom = screen.getHeight() - 1;
		repaint = true;
		mouseX = 0;
		mouseY = 0;
		continue;
	    }

	    if (auto keypress = cast(TKeypressEvent)event) {
		// Ctrl-W - close window
		if ((keypress.key == kbCtrlW) && (activeMenu is null)) {

		    // Resort windows and nix the first one (it is active)
		    if (windows.length > 0) {
			windows.sort;
			closeWindow(windows[0]);
		    }

		    // Refresh
		    repaint = true;
		    continue;
		}
	    }

	    // Peek at the mouse position
	    if (auto mouse = cast(TMouseEvent)event) {
		if ((mouseX != mouse.x) || (mouseY != mouse.y)) {
		    // flipMouse();
		    mouseX = mouse.x;
		    mouseY = mouse.y;
		    // flipMouse();
		    repaint = true;
		}
	    }

	    // Put into the main queue
	    addEvent(event);

	    // Have one of the two consumer Fibers peel the events off
	    // the queue.
	    if (secondaryEventFiber !is null) {
		assert(secondaryEventFiber.state == Fiber.State.HOLD);

		// Wake up the secondary handler for these events
		secondaryEventFiber.call();
	    } else {
		assert(primaryEventFiber.state == Fiber.State.HOLD);

		// Wake up the primary handler for these events
		primaryEventFiber.call();
	    }

	} // foreach (event; events)

    }

    /**
     * The default event queue function called by primaryFiber
     */
    private void primaryEventHandler() {
	while (quit == false) {
	    // Yield if there is nothing to do.  We will be called again in
	    // processChar().
	    if (eventQueue.length == 0) {
		Fiber.yield();
	    }

	    // It is possible that eventQueue will shrink to 0 between calls
	    // to handleEvent, so we must explicitly check every time.  We
	    // cannot use a foreach here.
	    if (eventQueue.length > 0) {
		TInputEvent event = eventQueue[0];
		eventQueue = eventQueue[1 .. $];
		handleEvent(event);
	    }
	}
    }

    /**
     * The event queue function called by application.secondaryFiber
     */
    private void widgetEventHandler() {
	// For some reason this assert fires even when I wake inside the
	// while().  Not sure if this is a bug in Fibers or a flaw in my
	// understanding of them.
	// assert(secondaryEventReceiver !is null);

	while (secondaryEventReceiver !is null) {
	    // Yield if there is nothing to do.  We will be called again
	    // EITHER in processChar() or in closeWindow().
	    if (eventQueue.length == 0) {
		Fiber.yield();
	    }

	    // It is possible that eventQueue will shrink to 0 between calls
	    // to handleEvent, so we must explicitly check every time.  We
	    // cannot use a foreach here.
	    if (eventQueue.length > 0) {
		TInputEvent event = eventQueue[0];
		eventQueue = eventQueue[1 .. $];
		secondaryEventReceiver.handleEvent(event);
	    }
	}
    }

    /**
     * Dispatch one event to the appropriate widget or application-level
     * event handler.
     *
     * Params:
     *    event the input event to consume
     */
    private void handleEvent(TInputEvent event) {

	// Special application-wide events -----------------------------------

	// Peek at the mouse position
	if (auto mouse = cast(TMouseEvent)event) {
	    // See if we need to switch focus to another window or the menu
	    checkSwitchFocus(mouse);
	}

	// Handle menu events
	if ((activeMenu !is null) && (!cast(TCommandEvent)event)) {
	    if (auto mouse = cast(TMouseEvent)event) {
		// Convert the mouse relative x/y to menu coordinates
		assert(mouse.x == mouse.absoluteX);
		assert(mouse.y == mouse.absoluteY);
		mouse.x -= activeMenu.x;
		mouse.y -= activeMenu.y;
	    }
	    activeMenu.handleEvent(event);
	    return;
	}

	if (auto keypress = cast(TKeypressEvent)event) {
	    // Alt-TAB
	    if (keypress.key == kbAltTab) {
		switchWindow();
		return;
	    }

	    // F6 - behave like Alt-TAB
	    if (keypress.key == kbF6) {
		switchWindow();
		return;
	    }

	    // See if this key matches an accelerator, and if so dispatch the
	    // command.
	    TKeypress keypressLowercase = toLower(keypress.key);
	    foreach (key, cmd; accelerators) {
		if (keypressLowercase == key) {
		    // Dispatch this command
		    addEvent(new TCommandEvent(cmd));
		}
	    }
	}

	if (auto cmd = cast(TCommandEvent)event) {
	    // Check for special case commands
	    if (cmd.cmd == cmExit) {
		if (messageBox("Confirmation", "Exit application?",
			TMessageBox.Type.YESNO).result == TMessageBox.Result.YES) {	
		    quit = true;
		}
		repaint = true;
		return;
	    }
	}

	// Dispatch events to the active window -------------------------------
	foreach (w; windows) {
	    if (w.active) {
		if (auto mouse = cast(TMouseEvent)event) {
		    // Convert the mouse relative x/y to window coordinates
		    assert(mouse.x == mouse.absoluteX);
		    assert(mouse.y == mouse.absoluteY);
		    mouse.x -= w.x;
		    mouse.y -= w.y;
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
	metaHandleEvents(events);
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
	if (terminal is null) {
	    terminal = new Terminal(false);
	}
	// Pull any pending input events
	TInputEvent [] events = terminal.getEvents(0, true);
	metaHandleEvents(events);

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

    /**
     * Convenience function to add a window to this container/window.  Window
     * will be located at (0, 0) if flags is not MODAL or CENTERED.
     *
     * Params:
     *    title = window title, will be centered along the top border
     *    width = width of window
     *    height = height of window
     *    flags = mask of RESIZABLE, CENTERED, or MODAL
     *
     * Returns:
     *    the new window
     */
    public TWindow addWindow(dstring title, uint width, uint height,
	ubyte flags = TWindow.RESIZABLE) {

	return new TWindow(this, title, width, height, flags);
    }

    /**
     * Convenience function to add a window to this container/window.
     *
     * Params:
     *    title = window title, will be centered along the top border
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = width of window
     *    height = height of window
     *    flags = mask of RESIZABLE, CENTERED, or MODAL
     *
     * Returns:
     *    the new window
     */
    public TWindow addWindow(dstring title, uint x, uint y, uint width, uint height,
	ubyte flags = TWindow.RESIZABLE) {

	return new TWindow(this, title, x, y, width, height, flags);
    }

    /**
     * Convenience function to spawn a message box.
     *
     * Params:
     *    title = window title, will be centered along the top border
     *    caption = message to display.  Use embedded newlines to get a multi-line box.
     *    type = one of the TMessageBox.Type constants.  Default is Type.OK.
     *
     * Returns:
     *    the new message box
     */
    public TMessageBox messageBox(dstring title, dstring caption,
	TMessageBox.Type type = TMessageBox.Type.OK) {

	return new TMessageBox(this, title, caption, type);
    }

    /**
     * Recompute menu x positions based on their title length.
     */
    public void recomputeMenuX() {
	uint x = 0;
	foreach (m; menus) {
	    m.x = x;
	    x += m.title.length + 2;
	}
    }

    /**
     * Convenience function to add a top-level menu.
     *
     * Params:
     *    title = menu title
     *
     * Returns:
     *    the new menu
     */
    public TMenu addMenu(dstring title) {
	uint x = 0;
	uint y = 0;
	TMenu menu = new TMenu(this, x, y, title);
	menus ~= menu;
	recomputeMenuX();
	return menu;
    }
}

// Functions -----------------------------------------------------------------
