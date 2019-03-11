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

module tui.tapplication;

// Description ---------------------------------------------------------------

// Imports -------------------------------------------------------------------

import std.algorithm : sort;
import std.range : reverse = retro;

import core.thread;
import std.conv;
import std.datetime;
import std.math;
import std.socket;
import tui.base;
import tui.codepage;
version(Posix) {
    import tui.ecma;
    import tui.tterminal;
}
import tui.win32;
import tui.twidget;
import tui.twindow;
import tui.teditor;
import tui.tfileopen;
import tui.tmessagebox;
import tui.tmenu;
import tui.ttimer;

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * TApplication sets up a full Text User Interface application.
 */
public class TApplication {

    /// Access to the physical screen, keyboard, and mouse.
    public Backend backend;

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

    /// Stack of activated sub-menus in this application.
    private TMenu [] subMenus;

    /// Timers that are being ticked.
    private TTimer [] timers;

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
    public static immutable int desktopTop = 1;

    /// Y coordinate of the bottom edge of the desktop.
    public int desktopBottom;

    /// Active keyboard accelerators
    private TMenuItem[TKeypress] accelerators;

    /**
     * Public constructor.
     *
     * Params:
     *    socket = remote socket to the user, or null if using stdio
     */
    public this(Socket socket = null) {
	if (socket !is null) {
	    version(Posix) {
		backend = new ECMABackend(socket);
	    } else {
		assert(false);
	    }
	} else {
	    version(Posix) {
		backend = new ECMABackend();
	    }
	    version(Windows) {
		backend = new Win32ConsoleBackend();
	    }
	}
	theme = new ColorTheme();
	desktopBottom = backend.screen.getHeight() - 1;
	primaryEventFiber = new Fiber(&primaryEventHandler);
    }

    /// Invert the cell at the mouse pointer position
    private void drawMouse() {
	CellAttributes attr = backend.screen.getAttrXY(mouseX, mouseY);
	attr.foreColor = invertColor(attr.foreColor);
	attr.backColor = invertColor(attr.backColor);
	backend.screen.putAttrXY(mouseX, mouseY, attr, false);
	flush = true;
	if (windows.length == 0) {
	    repaint = true;
	}
    }

    /**
     * Draw everything.
     *
     * Returns:
     *    escape sequences string that provides the updates to the
     *    physical screen
     */
    final public void drawAll() {
	if ((flush) && (!repaint)) {
	    backend.flushScreen();
	    flush = false;
	    return;
	}

	if (!repaint) {
	    return;
	}

	// If true, the cursor is not visible
	bool cursor = false;

	// Start with a clean screen
	backend.screen.clear();

	// Draw the background
	CellAttributes background = theme.getColor("tapplication.background");
	backend.screen.putAll(GraphicsChars.HATCH, background);

	// Draw each window in reverse Z order
	TWindow [] sorted = windows.dup;
	sorted.sort.reverse;
	foreach (w; sorted) {
	    w.drawChildren();
	}

	// Draw the blank menubar line - reset the screen clipping first so
	// it won't trim it out.
	backend.screen.resetClipping();
	backend.screen.hLineXY(0, 0, backend.screen.getWidth(), ' ',
	    theme.getColor("tmenu"));
	// Now draw the menus.
	uint x = 1;
	foreach (m; menus) {
	    CellAttributes menuColor;
	    CellAttributes menuMnemonicColor;
	    if (m.active) {
		menuColor = theme.getColor("tmenu.highlighted");
		menuMnemonicColor = theme.getColor("tmenu.mnemonic.highlighted");
	    } else {
		menuColor = theme.getColor("tmenu");
		menuMnemonicColor = theme.getColor("tmenu.mnemonic");
	    }
	    // Draw the menu title
	    backend.screen.hLineXY(x, 0, cast(uint)m.title.length + 2, ' ',
		menuColor);
	    backend.screen.putStrXY(x + 1, 0, m.title, menuColor);
	    // Draw the highlight character
	    backend.screen.putCharXY(x + 1 + m.mnemonic.shortcutIdx, 0,
		m.mnemonic.shortcut, menuMnemonicColor);

	    if (m.active) {
		m.drawChildren();
		// Reset the screen clipping so we can draw the next title.
		backend.screen.resetClipping();
	    }
	    x += m.title.length + 2;
	}

	foreach (m; subMenus) {
	    // Reset the screen clipping so we can draw the next sub-menu.
	    backend.screen.resetClipping();
	    m.drawChildren();
	}

	// Draw the mouse pointer
	drawMouse();

	// Place the cursor if it is visible
	TWidget activeWidget = null;
	if (sorted.length > 0) {
	    activeWidget = sorted[$ - 1].getActiveChild();
	    if (activeWidget.hasCursor) {
		backend.screen.putCursor(true, activeWidget.getCursorAbsoluteX(),
		    activeWidget.getCursorAbsoluteY());
		cursor = true;
	    }
	}

	// Kill the cursor
	if (cursor == false) {
	    backend.screen.hideCursor();
	}

	// Flush the screen contents
	backend.flushScreen();

	repaint = false;
	flush = false;
    }

    /**
     * Add a keyboard accelerator to the global hash
     *
     * Params:
     *    item = menu item this accelerator relates to
     *    keypress = keypress that will dispatch a TMenuEvent
     */
    final public void addAccelerator(TMenuItem item, TKeypress keypress) {
	assert((keypress in accelerators) is null);
	accelerators[keypress] = item;
    }

    /**
     * Add a sub-menu to the list of open sub-menus
     *
     * Params:
     *    menu = sub-menu
     */
    final public void addSubMenu(TMenu menu) {
	subMenus ~= menu;
    }

    /**
     * Add a window to my window list and make it active
     *
     * Params:
     *    window = new window to add
     */
    final public void addWindow(TWindow window) {
	// Do not allow a modal window to spawn a non-modal window
	if ((windows.length > 0) && (windows[0].isModal())) {
	    assert(window.isModal());
	}
	foreach (w; windows) {
	    w.active = false;
	    w.z++;
	}
	windows ~= window;
	window.active = true;
	window.z = 0;
    }

    /**
     * Check if there is a system-modal window on top
     *
     * Returns:
     *    true if the active window is modal
     */
    private bool modalWindowActive() {
	if (windows.length == 0) {
	    return false;
	}
	return windows[$ - 1].isModal();
    }

    /**
     * Switch to the next window
     *
     * Params:
     *    forward = switch to the next window in the list
     */
    final public void switchWindow(bool forward) {
	// Only switch if there are multiple windows
	if (windows.length < 2) {
	    return;
	}

	// Swap z/active between active window and the next in the
	// list
	ptrdiff_t activeWindowI = -1;
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

	size_t nextWindowI;
	if (forward) {
	    nextWindowI = (activeWindowI + 1) % windows.length;
	} else {
	    if (activeWindowI == 0) {
		nextWindowI = windows.length - 1;
	    } else {
		nextWindowI = activeWindowI - 1;
	    }
	}
	windows[activeWindowI].active = false;
	windows[activeWindowI].z = windows[nextWindowI].z;
	windows[nextWindowI].z = 0;
	windows[nextWindowI].active = true;

	// Refresh
	repaint = true;
    }

    /**
     * Check if a mouse event would hit either the active menu or any
     * open sub-menus.
     *
     * Params:
     *    mouse = mouse event
     *
     * Returns:
     *    true if the mouse would hit
     */
    private bool mouseOnMenu(TMouseEvent mouse) {
	assert(activeMenu !is null);
	TMenu [] menus = subMenus.dup;
	menus.reverse;
	foreach (m; menus) {
	    if (m.mouseWouldHit(mouse)) {
		return true;
	    }
	}
	return activeMenu.mouseWouldHit(mouse);
    }

    /// See if we need to switch window or activate the menu based on
    /// a mouse click
    final public void checkSwitchFocus(TMouseEvent mouse) {

	if ((mouse.type == TMouseEvent.Type.MOUSE_DOWN) &&
	    (activeMenu !is null) &&
	    (mouse.absoluteY != 0) &&
	    (!mouseOnMenu(mouse))
	) {
	    // They clicked outside the active menu, turn it off
	    activeMenu.active = false;
	    activeMenu = null;
	    foreach (m; subMenus) {
		m.active = false;
	    }
	    subMenus.length = 0;
	    // Continue checks
	}

	// See if they hit the menu bar
	if ((mouse.type == TMouseEvent.Type.MOUSE_DOWN) &&
	    (mouse.mouse1) &&
	    (!modalWindowActive()) &&
	    (mouse.absoluteY == 0)
	) {

	    foreach (m; subMenus) {
		m.active = false;
	    }
	    subMenus.length = 0;

	    // They selected the menu, go activate it
	    foreach (m; menus) {
		if ((mouse.absoluteX >= m.x) &&
		    (mouse.absoluteX < m.x + m.title.length + 2)
		) {
		    m.active = true;
		    activeMenu = m;
		} else {
		    m.active = false;
		}
	    }
	    repaint = true;
	    return;
	}

	// See if they hit the menu bar
	if ((mouse.type == TMouseEvent.Type.MOUSE_MOTION) &&
	    (mouse.mouse1) &&
	    (activeMenu !is null) &&
	    (mouse.absoluteY == 0)
	) {

	    TMenu oldMenu = activeMenu;
	    foreach (m; subMenus) {
		m.active = false;
	    }
	    subMenus.length = 0;

	    // See if we should switch menus
	    foreach (m; menus) {
		if ((mouse.absoluteX >= m.x) &&
		    (mouse.absoluteX < m.x + m.title.length + 2)
		) {
		    m.active = true;
		    activeMenu = m;
		}
	    }
	    if (oldMenu !is activeMenu) {
		// They switched menus
		oldMenu.active = false;
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
    final public void closeWindow(TWindow window) {
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

	// Perform window cleanup
	window.onClose();

	// Refresh screen
	repaint = true;

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
	    secondaryEventFiber = null;

	    // Unfreeze the logic in handleEvent()
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
    final public void enableSecondaryEventReceiver(TWidget widget) {
	assert(secondaryEventReceiver is null);
	assert(secondaryEventFiber is null);
	assert(cast(TMessageBox)widget || cast(TFileOpenBox)widget);
	secondaryEventReceiver = widget;
	secondaryEventFiber = new Fiber(&widgetEventHandler);

	// Refresh
	repaint = true;
    }

    /**
     * Post an event to process
     *
     * Params:
     *    event = new event to add to the queue
     */
    final public void addEvent(TInputEvent event) {
	eventQueue ~= event;
    }

    /**
     * Post an event to process and turn off the menu
     *
     * Params:
     *    event = new event to add to the queue
     */
    final public void addMenuEvent(TInputEvent event) {
	eventQueue ~= event;
	closeMenu();
    }

    /**
     * Turn off the menu
     */
    final public void closeMenu() {
	if (activeMenu !is null) {
	    activeMenu.active = false;
	    activeMenu = null;
	    foreach (m; subMenus) {
		m.active = false;
	    }
	    subMenus.length = 0;
	}
	repaint = true;
    }

    /**
     * Turn off a menu
     */
    final public void closeSubMenu() {
	assert(activeMenu !is null);
	auto item = subMenus[$ - 1];
	assert(item);
	item.active = false;
	subMenus.length--;
	repaint = true;
    }

    /**
     * Switch to the next menu
     */
    final public void switchMenu(bool forward = true) {
	assert(activeMenu !is null);

	foreach (m; subMenus) {
	    m.active = false;
	}
	subMenus.length = 0;

	for (auto i = 0; i < menus.length; i++) {
	    if (activeMenu is menus[i]) {
		if (forward) {
		    if (i < menus.length - 1) {
			i++;
		    }
		} else {
		    if (i > 0) {
			i--;
		    }
		}
		activeMenu.active = false;
		activeMenu = menus[i];
		activeMenu.active = true;
		repaint = true;
		return;
	    }
	}
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

	    // std.stdio.stderr.writefln("metaHandleEvents event: %s primary %s",
	    //     event, primaryEventFiber.state);

	    if (quit == true) {
		// Do no more processing if the application is already trying to
		// exit.
		return;
	    }

	    // Special application-wide events -------------------------------

	    // Abort everything
	    if (auto command = cast(TCommandEvent)event) {
		if (command.cmd == cmAbort) {
		    quit = true;
		    return;
		}
	    }

	    // Screen resize
	    if (auto resize = cast(TResizeEvent)event) {
		backend.screen.setDimensions(resize.width, resize.height);
		desktopBottom = backend.screen.getHeight() - 1;
		repaint = true;
		mouseX = 0;
		mouseY = 0;
		continue;
	    }

	    // Peek at the mouse position
	    if (auto mouse = cast(TMouseEvent)event) {
		if ((mouseX != mouse.x) || (mouseY != mouse.y)) {
		    mouseX = mouse.x;
		    mouseY = mouse.y;
		    drawMouse();
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
	    // Yield if there is nothing to do.
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
	    // Yield if there is nothing to do.
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

	// std.stdio.stderr.writefln("Handle event: %s", event);

	// Special application-wide events -----------------------------------

	// Peek at the mouse position
	if (auto mouse = cast(TMouseEvent)event) {
	    // See if we need to switch focus to another window or the menu
	    checkSwitchFocus(mouse);
	}

	// Handle menu events
	if ((activeMenu !is null) && (!cast(TCommandEvent)event)) {
	    TMenu menu = activeMenu;
	    if (auto mouse = cast(TMouseEvent)event) {

		while (subMenus.length > 0) {
		    TMenu subMenu = subMenus[$ - 1];
		    if (subMenu.mouseWouldHit(mouse)) {
			break;
		    }
		    if ((mouse.type == TMouseEvent.Type.MOUSE_MOTION) &&
			(!mouse.mouse1) &&
			(!mouse.mouse2) &&
			(!mouse.mouse3) &&
			(!mouse.mouseWheelUp) &&
			(!mouse.mouseWheelDown)
		    ) {
			break;
		    }
		    // We navigated away from a sub-menu, so close it
		    closeSubMenu();
		}

		// Convert the mouse relative x/y to menu coordinates
		assert(mouse.x == mouse.absoluteX);
		assert(mouse.y == mouse.absoluteY);
		if (subMenus.length > 0) {
		    menu = subMenus[$ - 1];
		}
		mouse.x -= menu.x;
		mouse.y -= menu.y;
	    }
	    menu.handleEvent(event);
	    return;
	}

	if (auto keypress = cast(TKeypressEvent)event) {
	    // See if this key matches an accelerator, and if so dispatch the
	    // menu event.
	    TKeypress keypressLowercase = toLower(keypress.key);
	    TMenuItem *item = (keypressLowercase in accelerators);
	    if (item !is null) {
		// Let the menu item dispatch
		item.dispatch();
		return;
	    } else {
		// Handle the keypress
		if (onKeypress(keypress)) {
		    return;
		}
	    }
	}

	if (auto cmd = cast(TCommandEvent)event) {
	    if (onCommand(cmd)) {
		return;
	    }
	}

	if (auto menu = cast(TMenuEvent)event) {
	    if (onMenu(menu)) {
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
		// std.stdio.stderr.writefln("TApplication dispatch event: %s", event);
		w.handleEvent(event);
		break;
	    }
	}
    }

    /**
     * Close all open windows
     */
    private void closeAllWindows() {
	// Don't do anything if we are in the menu
	if (activeMenu !is null) {
	    return;
	}
	foreach (w; windows) {
	    closeWindow(w);
	}
    }

    /**
     * Re-layout the open windows as non-overlapping tiles.  This produces
     * almost the same results as Turbo Pascal 7.0's IDE.
     */
    private void tileWindows() {
	// Don't do anything if we are in the menu
	if (activeMenu !is null) {
	    return;
	}
	size_t z = windows.length;
	if (z == 0) {
	    return;
	}
	size_t a, b;
	a = to!size_t(sqrt(to!float(z)));
	size_t c = 0;
	while (c < a) {
	    b = (z - c) / a;
	    if (((a * b) + c) == z) {
		break;
	    }
	    c++;
	}
	assert(a > 0);
	assert(b > 0);
	assert(c < a);
	auto newWidth = (backend.screen.getWidth() / a);
	auto newHeight1 = ((backend.screen.getHeight() - 1) / b);
	auto newHeight2 = ((backend.screen.getHeight() - 1) / (b + c));
	// std.stdio.stderr.writefln("Z %s a %s b %s c %s newWidth %s newHeight1 %s newHeight2 %s",
	//     z, a, b, c, newWidth, newHeight1, newHeight2);

	TWindow [] sorted = windows.dup;
	sorted.sort.reverse;
	for (auto i = 0; i < sorted.length; i++) {
	    auto logicalX = i / b;
	    auto logicalY = i % b;
	    if (i >= ((a - 1) * b)) {
		logicalX = a - 1;
		logicalY = i - ((a - 1) * b);
	    }

	    TWindow w = sorted[i];
	    w.x = to!int(logicalX * newWidth);
	    w.width = to!uint(newWidth);
	    if (i >= ((a - 1) * b)) {
		w.y = to!int(logicalY * newHeight2) + 1;
		w.height = to!uint(newHeight2);
	    } else {
		w.y = to!int(logicalY * newHeight1) + 1;
		w.height = to!uint(newHeight1);
	    }
	}
    }

    /**
     * Re-layout the open windows as overlapping cascaded windows.
     */
    private void cascadeWindows() {
	// Don't do anything if we are in the menu
	if (activeMenu !is null) {
	    return;
	}
	uint x = 0;
	uint y = 1;
	TWindow [] sorted = windows.dup;
	sorted.sort.reverse;
	foreach (w; sorted) {
	    w.x = x;
	    w.y = y;
	    x++;
	    y++;
	    if (x > backend.screen.getWidth()) {
		x = 0;
	    }
	    if (y >= backend.screen.getHeight()) {
		y = 1;
	    }
	}
    }

    /**
     * Method that TApplication subclasses can override to handle menu or
     * posted command events.
     *
     * Params:
     *    cmd = command event
     *
     * Returns:
     *    if true, this event was consumed
     */
    protected bool onCommand(TCommandEvent cmd) {
	// Default: handle cmExit
	if (cmd.cmd == cmExit) {
	    if (messageBox("Confirmation", "Exit application?",
		    TMessageBox.Type.YESNO).result == TMessageBox.Result.YES) {
		quit = true;
	    }
	    // std.stdio.stderr.writefln("onCommand cmExit result: quit = %s", quit);
	    // std.stdio.stderr.flush();
	    repaint = true;
	    return true;
	}

	version(Posix) {
	    if (cmd.cmd == cmShell) {
		openTerminal(0, 0, TWindow.Flag.RESIZABLE);
		repaint = true;
		return true;
	    }
	}

	if (cmd.cmd == cmTile) {
	    tileWindows();
	    repaint = true;
	    return true;
	}
	if (cmd.cmd == cmCascade) {
	    cascadeWindows();
	    repaint = true;
	    return true;
	}
	if (cmd.cmd == cmCloseAll) {
	    closeAllWindows();
	    repaint = true;
	    return true;
	}
	return false;
    }

    /**
     * Method that TApplication subclasses can override to handle menu
     * events.
     *
     * Params:
     *    menu = menu event
     *
     * Returns:
     *    if true, this event was consumed
     */
    protected bool onMenu(TMenuEvent menu) {
	// Default: handle MID_EXIT
	if (menu.id == TMenu.MID_EXIT) {
	    if (messageBox("Confirmation", "Exit application?",
		    TMessageBox.Type.YESNO).result == TMessageBox.Result.YES) {
		quit = true;
	    }
	    // std.stdio.stderr.writefln("onMenu MID_EXIT result: quit = %s", quit);
	    // std.stdio.stderr.flush();
	    repaint = true;
	    return true;
	}

	version(Posix) {
	    if (menu.id == TMenu.MID_SHELL) {
		openTerminal(0, 0, TWindow.Flag.RESIZABLE);
		repaint = true;
		return true;
	    }
	}

	if (menu.id == TMenu.MID_TILE) {
	    tileWindows();
	    repaint = true;
	    return true;
	}
	if (menu.id == TMenu.MID_CASCADE) {
	    cascadeWindows();
	    repaint = true;
	    return true;
	}
	if (menu.id == TMenu.MID_CLOSE_ALL) {
	    closeAllWindows();
	    repaint = true;
	    return true;
	}
	return false;
    }

    /**
     * Method that TApplication subclasses can override to handle keystrokes.
     *
     * Params:
     *    keypress = keystroke event
     *
     * Returns:
     *    if true, this event was consumed
     */
    protected bool onKeypress(TKeypressEvent keypress) {
	// Default: only menu shortcuts

	// Process Alt-F, Alt-E, etc. menu shortcut keys
	if (!keypress.key.isKey &&
	    keypress.key.alt &&
	    !keypress.key.ctrl &&
	    (activeMenu is null)) {

	    assert(subMenus.length == 0);

	    foreach (m; menus) {
		if (toLowercase(m.mnemonic.shortcut) == toLowercase(keypress.key.ch)) {
		    activeMenu = m;
		    m.active = true;
		    repaint = true;
		    return true;
		}
	    }
	}

	return false;
    }

    /// Do stuff when there is no user input
    private void doIdle() {
	// Now run any timers that have timed out
	auto now = Clock.currTime;
	TTimer [] keepTimers;
	foreach (t; timers) {
	    if (t.nextTick < now) {
		t.tick();
		if (t.recurring == true) {
		    keepTimers ~= t;
		}
	    } else {
		keepTimers ~= t;
	    }
	}
	timers = keepTimers;

	// Call onIdle's
	foreach (w; windows) {
	    w.onIdle();
	}
    }

    /**
     * Get the amount of time I can sleep before missing a Timer tick.
     *
     * Params:
     *    timeout = initial (maximum) timeout
     *
     * Returns:
     *    number of milliseconds between now and the next timer event
     */
    protected uint getSleepTime(uint timeout) {
	auto now = Clock.currTime;
	auto sleepTime = dur!("msecs")(timeout);
	foreach (t; timers) {
	    if (t.nextTick < now) {
		return 0;
	    }
	    if ((t.nextTick > now) &&
		((t.nextTick - now) < sleepTime)
	    ) {
		sleepTime = t.nextTick - now;
	    }
	}
	assert(sleepTime.total!("msecs")() >= 0);
	return cast(uint)sleepTime.total!("msecs")();
    }

    /// Run this application until it exits, using stdin and stdout
    final public void run() {

	while (quit == false) {

	    // Timeout is in milliseconds, so default timeout after 1
	    // second of inactivity.
	    uint timeout = getSleepTime(1000);
	    // std.stdio.stderr.writefln("poll() timeout: %d", timeout);

	    if (eventQueue.length > 0) {
		// Do not wait if there are definitely events waiting to be
		// processed or a screen redraw to do.
		timeout = 0;
	    }

	    // Pull any pending input events
	    TInputEvent [] events = backend.getEvents(timeout);
	    metaHandleEvents(events);

	    // Process timers and call doIdle()'s
	    doIdle();

	    // Update the screen
	    drawAll();
	}

	// Shutdown the fibers
	eventQueue.length = 0;
	if (secondaryEventFiber !is null) {
	    assert(secondaryEventReceiver !is null);
	    secondaryEventReceiver = null;
	    if (secondaryEventFiber.state == Fiber.State.HOLD) {
		// Wake up the secondary handler so that it can exit.
		secondaryEventFiber.call();
	    }
	}

	if (primaryEventFiber.state == Fiber.State.HOLD) {
	    // Wake up the primary handler so that it can exit.
	    primaryEventFiber.call();
	}

	backend.shutdown();
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
    final public TWindow addWindow(dstring title, uint width, uint height,
	TWindow.Flag flags = TWindow.Flag.RESIZABLE) {

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
    final public TWindow addWindow(dstring title, uint x, uint y, uint width,
	uint height, TWindow.Flag flags = TWindow.Flag.RESIZABLE) {

	return new TWindow(this, title, x, y, width, height, flags);
    }

    version(Posix) {
	/**
	 * Convenience function to open a terminal window.
	 *
	 * Params:
	 *    x = column relative to parent
	 *    y = row relative to parent
	 *    flags = mask of CENTERED, MODAL, or RESIZABLE
	 *
	 * Returns:
	 *    the new window
	 */
	final public TTerminal openTerminal(uint x, uint y,
	    TWindow.Flag flags = TWindow.Flag.RESIZABLE | TWindow.Flag.CENTERED) {

	    return new TTerminal(this, x, y, flags);
	}
    }

    /**
     * Convenience function to load a text file in a new editor window.
     *
     * Params:
     *    filename = filename to open
     *
     * Returns:
     *    the new editor window
     */
    final public TEditor addEditor(dstring filename = "") {
	assert(filename !is null);
	TEditor editor = addEditor(0, 0, backend.screen.getWidth() / 2,
	    desktopBottom - desktopTop);
	if (filename.length > 0) {
	    editor.loadFile(filename);
	}
	return editor;
    }

    /**
     * Convenience function to spawn a text file editor window.
     *
     * Params:
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = width of window
     *    height = height of window
     *    flags = mask of CENTERED, MODAL, or RESIZABLE
     *
     * Returns:
     *    the new editor window
     */
    final public TEditor addEditor(int x, int y, uint width, uint height,
	TWindow.Flag flags = TWindow.Flag.CENTERED | TWindow.Flag.RESIZABLE) {

	return new TEditor(this, x, y, width, height, flags);
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
    final public TMessageBox messageBox(dstring title, dstring caption,
	TMessageBox.Type type = TMessageBox.Type.OK) {

	return new TMessageBox(this, title, caption, type);
    }

    /**
     * Convenience function to spawn an input box.
     *
     * Params:
     *    title = window title, will be centered along the top border
     *    caption = message to display.  Use embedded newlines to get a multi-line box.
     *    text = optional text to seed the field with
     *
     * Returns:
     *    the new input box
     */
    final public TInputBox inputBox(dstring title, dstring caption,
	dstring text) {

	return new TInputBox(this, title, caption, text);
    }

    /**
     * Convenience function to spawn an file open box.
     *
     * Params:
     *    path = path of selected file
     *    type = one of the Type constants.  Default is Type.OPEN.
     *
     * Returns:
     *    the result of the new file open box
     */
    final public dstring fileOpenBox(dstring path,
	TFileOpenBox.Type type = TFileOpenBox.Type.OPEN) {

	TFileOpenBox box = new TFileOpenBox(this, path, type);
	return box.filename;
    }

    /**
     * Recompute menu x positions based on their title length.
     */
    final public void recomputeMenuX() {
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
    final public TMenu addMenu(dstring title) {
	uint x = 0;
	uint y = 0;
	TMenu menu = new TMenu(this, x, y, title);
	menus ~= menu;
	recomputeMenuX();
	return menu;
    }

    /**
     * Convenience function to add a default "File" menu.
     *
     * Returns:
     *    the new menu
     */
    final public TMenu addFileMenu() {
	TMenu fileMenu = addMenu("&File");
	fileMenu.addDefaultItem(TMenu.MID_OPEN_FILE);
	fileMenu.addSeparator();
	version(Posix) {
	    fileMenu.addDefaultItem(TMenu.MID_SHELL);
	}
	fileMenu.addDefaultItem(TMenu.MID_EXIT);
	return fileMenu;
    }

    /**
     * Convenience function to add a default "Edit" menu.
     *
     * Returns:
     *    the new menu
     */
    final public TMenu addEditMenu() {
	TMenu editMenu = addMenu("&Edit");
	editMenu.addDefaultItem(TMenu.MID_CUT);
	editMenu.addDefaultItem(TMenu.MID_COPY);
	editMenu.addDefaultItem(TMenu.MID_PASTE);
	editMenu.addDefaultItem(TMenu.MID_CLEAR);
	return editMenu;
    }

    /**
     * Convenience function to add a default "Window" menu.
     *
     * Returns:
     *    the new menu
     */
    final public TMenu addWindowMenu() {
	TMenu windowMenu = addMenu("&Window");
	windowMenu.addDefaultItem(TMenu.MID_TILE);
	windowMenu.addDefaultItem(TMenu.MID_CASCADE);
	windowMenu.addDefaultItem(TMenu.MID_CLOSE_ALL);
	windowMenu.addSeparator();
	windowMenu.addDefaultItem(TMenu.MID_WINDOW_MOVE);
	windowMenu.addDefaultItem(TMenu.MID_WINDOW_ZOOM);
	windowMenu.addDefaultItem(TMenu.MID_WINDOW_NEXT);
	windowMenu.addDefaultItem(TMenu.MID_WINDOW_PREVIOUS);
	windowMenu.addDefaultItem(TMenu.MID_WINDOW_CLOSE);
	return windowMenu;
    }

    /**
     * Convenience function to add a timer.
     *
     * Params:
     *    duration = number of milliseconds to wait between ticks
     *    actionFn = function to call when button is pressed
     *    recurring = if true, re-schedule this timer after every tick
     */
    final public TTimer addTimer(uint duration, void function() actionFn, bool recurring = false) {
	TTimer timer = new TTimer(duration, actionFn, recurring);
	timers ~= timer;
	return timer;
    }

    /**
     * Convenience function to add a timer.
     *
     * Params:
     *    duration = number of milliseconds to wait between ticks
     *    actionFn = function to call when button is pressed
     *    recurring = if true, re-schedule this timer after every tick
     */
    final public TTimer addTimer(uint duration, void delegate() actionFn, bool recurring = false) {
	TTimer timer = new TTimer(duration, actionFn, recurring);
	timers ~= timer;
	return timer;
    }

    /**
     * Convenience function to remove a timer.
     *
     * Params:
     *    timer = timer to remove
     */
    final public void removeTimer(TTimer timer) {
	TTimer [] newTimers;
	foreach (t; timers) {
	    if (t !is timer) {
		newTimers ~= t;
	    }
	}
	timers = newTimers;
    }

}

// Functions -----------------------------------------------------------------
