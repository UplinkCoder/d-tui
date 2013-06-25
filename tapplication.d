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
import std.datetime;
import std.stdio;
import base;
import codepage;
import ecma;
import twidget;
import twindow;
import tmessagebox;
import tmenu;
import ttimer;
import tterminal;

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
    public static immutable uint desktopTop = 1;

    /// Y coordinate of the bottom edge of the desktop.
    public uint desktopBottom;

    /// Active keyboard accelerators
    private TCommand[TKeypress] accelerators;

    /// Public constructor.
    public this() {
	backend = new ECMABackend();
	theme = new ColorTheme();

	desktopBottom = backend.screen.getHeight() - 1;

	primaryEventFiber = new Fiber(&primaryEventHandler);
    }

    /// Invert the cell at the mouse pointer position
    private void flipMouse() {

	Color [] sgrToPCMap = [
	    Color.BLACK,
	    Color.BLUE,
	    Color.GREEN,
	    Color.CYAN,
	    Color.RED,
	    Color.MAGENTA,
	    Color.YELLOW,
	    Color.WHITE
	];

	CellAttributes attr = backend.screen.getAttrXY(mouseX, mouseY);
	attr.foreColor = cast(Color)(sgrToPCMap[attr.foreColor] ^ 0x7);
	attr.backColor = cast(Color)(sgrToPCMap[attr.backColor] ^ 0x7);
	backend.screen.putAttrXY(mouseX, mouseY, attr, false);
	// screen.putCharXY(mouseX, mouseY, 'X', attr);
	flush = true;
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
	    CellAttributes menuAcceleratorColor;
	    if (m.active) {
		menuColor = theme.getColor("tmenu.highlighted");
		menuAcceleratorColor = theme.getColor("tmenu.accelerator.highlighted");
	    } else {
		menuColor = theme.getColor("tmenu");
		menuAcceleratorColor = theme.getColor("tmenu.accelerator");
	    }
	    // Draw the menu title
	    backend.screen.hLineXY(x, 0, cast(uint)m.title.length + 2, ' ',
		menuColor);
	    backend.screen.putStrXY(x + 1, 0, m.title, menuColor);
	    // Draw the highlight character
	    backend.screen.putCharXY(x + 1 + m.accelerator.shortcutIdx, 0,
		m.accelerator.shortcut, menuAcceleratorColor);

	    if (m.active) {
		m.drawChildren();
		// Reset the screen clipping so we can draw the next title.
		backend.screen.resetClipping();
	    }
	    x += m.title.length + 2;
	}

	// Place the cursor if it is visible
	TWidget activeWidget = null;
	bool hasCursor = false;
	if (sorted.length > 0) {
	    activeWidget = sorted[$ - 1].getActiveChild();
	    if (activeWidget.hasCursor) {
		backend.putCursor(true, activeWidget.getCursorAbsoluteX(),
		    activeWidget.getCursorAbsoluteY());
		hasCursor = true;
	    }
	}
	// Kill the cursor
	if (!hasCursor) {
	    backend.putCursor(false, 0, 0);
	}

	// Place the mouse pointer
	flipMouse();

	// Flush the screen contents
	backend.flushScreen();

	repaint = false;
	flush = false;
    }

    /**
     * Add a keyboard accelerator to the global list
     *
     * Params:
     *    command = command to send to the active widget
     *    keypress = keypress that will activate the command
     */
    final public void addAccelerator(TCommand command, TKeypress keypress) {
	accelerators[keypress] = command;
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
    
    /// Switch to the next window
    final public void switchWindow() {
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
    final public void checkSwitchFocus(TMouseEvent mouse) {

	if ((mouse.type == TMouseEvent.Type.MOUSE_DOWN) &&
	    (activeMenu !is null) &&
	    (mouse.absoluteY != 0) &&
	    (!activeMenu.mouseWouldHit(mouse))
	) {
	    // They clicked outside the active menu, turn it off
	    activeMenu.active = false;
	    activeMenu = null;
	    // Continue checks
	}

	// See if they hit the menu bar
	if ((mouse.type == TMouseEvent.Type.MOUSE_DOWN) &&
	    (mouse.mouse1) &&
	    (activeMenu is null) &&
	    (!modalWindowActive())
	) {

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

	// See if they hit the menu bar
	if ((mouse.type == TMouseEvent.Type.MOUSE_MOTION) &&
	    (mouse.mouse1) &&
	    (activeMenu !is null)) {

	    TMenu oldMenu = activeMenu;

	    // See if we should switch menus
	    foreach (m; menus) {
		if ((mouse.absoluteY == 0) &&
		    (mouse.absoluteX >= m.x) &&
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
    final public void enableSecondaryEventReceiver(TWidget widget) {
	assert(secondaryEventReceiver is null);
	assert(secondaryEventFiber is null);
	assert(cast(TMessageBox)widget);
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
	assert(activeMenu !is null);
	activeMenu.active = false;
	activeMenu = null;
	repaint = true;
    }

    /**
     * Switch to the next menu
     */
    final public void switchMenu(bool forward = true) {
	assert(activeMenu !is null);
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

	    // stderr.writefln("metaHandleEvents event: %s", event);
	    
	    // Special application-wide events -------------------------------

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

	// stderr.writefln("Handle event: %s", event);

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
	    // See if this key matches an accelerator, and if so dispatch the
	    // command.
	    TKeypress keypressLowercase = toLower(keypress.key);
	    TCommand *cmd = (keypressLowercase in accelerators);
	    if (cmd !is null) {
		// Dispatch this command
		addEvent(new TCommandEvent(*cmd));
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
	    repaint = true;
	    return true;
	}
	if (cmd.cmd == cmShell) {
	    openTerminal(0, 0, TWindow.Flag.RESIZABLE);
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
	// Default: handle Alt-TAB and menu shortcuts

	// Alt-TAB
	if (keypress.key == kbAltTab) {
	    switchWindow();
	    return true;
	}

	// Process Alt-F, Alt-E, etc. menu shortcut keys
	if (!keypress.key.isKey &&
	    keypress.key.alt &&
	    !keypress.key.ctrl &&
	    (activeMenu is null)) {

	    foreach (m; menus) {
		if (toLowercase(m.accelerator.shortcut) == toLowercase(keypress.key.ch)) {
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
     *    timeout = initial timeout
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
	    // stderr.writefln("poll() timeout: %d", timeout);

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
