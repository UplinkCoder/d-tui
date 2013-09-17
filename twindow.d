/**
 * D Text User Interface library - TWindow class
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
import std.utf;
import base;
import codepage;
import tapplication;
import tmenu;
import twidget;

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * TWindow is the top-level container and drawing surface for other
 * widgets.
 */
public class TWindow : TWidget {

    /// Window's parent application.
    public TApplication application;

    /// application's screen
    public Screen screen;

    /// Use the screen drawing primitives like they are ours.  width
    /// and height are INCLUSIVE of the border.
    alias screen this;

    /// Window title
    dstring title = "";

    enum Flag {

	/// Window is resizable (default yes)
	RESIZABLE = 0x01,

	/// Window is modal (default no)
	MODAL = 0x02,

	/// Window is centered
	CENTERED = 0x04,

	};

    /// Window flags
    private Flag flags = Flag.RESIZABLE;

    /// Z order.  Lower number means more in-front.
    public uint z = false;

    /// If true, then the user clicked on the title bar and is moving
    /// the window
    private bool inWindowMove = false;

    /// If true, then the user clicked on the bottom right corner and
    /// is resizing the window
    private bool inWindowResize = false;

    /// If true, then the user selected "Size/Move" (or hit Ctrl-F5) and is
    /// resizing/moving the window via the keyboard
    private bool inKeyboardResize = false;

    /// If true, this window is maximized
    public bool maximized = false;

    /// Remember mouse state
    protected TMouseEvent mouse;

    // For moving the window.  resizing also uses moveWindowMouseX/Y
    private uint moveWindowMouseX;
    private uint moveWindowMouseY;
    private int oldWindowX;
    private int oldWindowY;

    // Resizing
    private uint resizeWindowWidth;
    private uint resizeWindowHeight;
    public uint minimumWindowWidth = 10;
    public uint minimumWindowHeight = 2;
    public int maximumWindowWidth = -1;
    public int maximumWindowHeight = -1;

    // For maximize/restore
    private uint restoreWindowWidth;
    private uint restoreWindowHeight;
    private int restoreWindowX;
    private int restoreWindowY;

    /**
     * Public constructor.  Window will be located at (0, 0).
     *
     * Params:
     *    application = TApplication that manages this window
     *    title = window title, will be centered along the top border
     *    width = width of window
     *    height = height of window
     *    flags = mask of RESIZABLE, CENTERED, or MODAL
     */
    public this(TApplication application, dstring title,
	uint width, uint height, Flag flags = Flag.RESIZABLE) {

	this(application, title, 0, 0, width, height, flags);
    }

    /**
     * Public constructor
     *
     * Params:
     *    application = TApplication that manages this window
     *    title = window title, will be centered along the top border
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = width of window
     *    height = height of window
     *    flags = mask of RESIZABLE, CENTERED, or MODAL
     */
    public this(TApplication application, dstring title, int x, int y,
	uint width, uint height, Flag flags = Flag.RESIZABLE) {

	// I am my own window and parent
	this.parent = this;
	this.window = this;

	this.title = title;
	this.application = application;
	this.screen = application.backend.screen;
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
	    this.flags |= Flag.CENTERED;
	}

	// Center window if specified
	center();

	// Add me to the application
	application.addWindow(this);
    }

    /// Recenter the window on-screen
    public void center() {
	if ((flags & Flag.CENTERED) != 0) {
	    if (width < screen.getWidth()) {
		x = (screen.getWidth() - width) / 2;
	    } else {
		x = 0;
	    }
	    y = (application.desktopBottom - application.desktopTop);
	    y -= height;
	    y /= 2;
	    if (y < 0) {
		y = 0;
	    }
	    y += application.desktopTop;
	}
    }

    /// Returns true if this window is modal
    public bool isModal() {
	if ((flags & Flag.MODAL) == 0) {
	    return false;
	}
	return true;
    }

    /// Comparison operator sorts on z
    public override int opCmp(Object rhs) {
	auto that = cast(TWindow)rhs;
	if (!that) {
	    return 0;
	}
	return z - that.z;
    }

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
	if (((flags & Flag.RESIZABLE) != 0) &&
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

    /// Retrieve the background color
    public CellAttributes getBackground() {
	if (!isModal() && (inWindowMove || inWindowResize || inKeyboardResize)) {
	    assert(active == 1);
	    return application.theme.getColor("twindow.background.windowmove");
	} else if (isModal() && inWindowMove) {
	    assert(active == 1);
	    return application.theme.getColor("twindow.background.modal");
	} else if (isModal()) {
	    if (active) {
		return application.theme.getColor("twindow.background.modal");
	    }
	    return application.theme.getColor("twindow.background.modal.inactive");
	} else if (active) {
	    assert(!isModal());
	    return application.theme.getColor("twindow.background");
	} else {
	    assert(!isModal());
	    return application.theme.getColor("twindow.background.inactive");
	}
    }

    /// Retrieve the border color
    public CellAttributes getBorder() {
	if (!isModal() && (inWindowMove || inWindowResize || inKeyboardResize)) {
	    assert(active == 1);
	    return application.theme.getColor("twindow.border.windowmove");
	} else if (isModal() && inWindowMove) {
	    assert(active == 1);
	    return application.theme.getColor("twindow.border.modal.windowmove");
	} else if (isModal()) {
	    if (active) {
		return application.theme.getColor("twindow.border.modal");
	    } else {
		return application.theme.getColor("twindow.border.modal.inactive");
	    }
	} else if (active) {
	    assert(!isModal());
	    return application.theme.getColor("twindow.border");
	} else {
	    assert(!isModal());
	    return application.theme.getColor("twindow.border.inactive");
	}
    }

    /// Retrieve the border line type
    public uint getBorderType() {
	if (!isModal() && (inWindowMove || inWindowResize || inKeyboardResize)) {
	    assert(active == 1);
	    return 1;
	} else if (isModal() && inWindowMove) {
	    assert(active == 1);
	    return 1;
	} else if (isModal()) {
	    if (active) {
		return 2;
	    } else {
		return 1;
	    }
	} else if (active) {
	    return 2;
	} else {
	    return 1;
	}
    }

    /**
     * Subclasses should override this method to cleanup resources.  This is
     * called by application.closeWindow().
     */
    public void onClose() {
	// Default: do nothing
    }

    /// Called by TApplication.drawChildren() to render on screen.
    override public void draw() {
	// Draw the box and background first.
	CellAttributes border = getBorder();
	CellAttributes background = getBackground();
	uint borderType = getBorderType();

	drawBox(0, 0, width, height, border, background, borderType, true);

	// Draw the title
	uint titleLeft = (width - cast(uint)title.length - 2)/2;
	putCharXY(titleLeft, 0, ' ', border);
	putStrXY(titleLeft + 1, 0, title);
	putCharXY(titleLeft + cast(uint)title.length + 1, 0, ' ', border);

	if (active) {

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
		if ((flags & Flag.RESIZABLE) != 0) {
		    putCharXY(width - 2, height - 1, GraphicsChars.SINGLE_BAR,
			application.theme.getColor("twindow.border.windowmove"));
		    putCharXY(width - 1, height - 1, GraphicsChars.LRCORNER,
			application.theme.getColor("twindow.border.windowmove"));
		}
	    }
	}
    }

    /**
     * Handle mouse button presses.
     *
     * Params:
     *    event = mouse button event
     */
    override protected void onMouseDown(TMouseEvent event) {
	mouse = event;
	application.repaint = true;

	inKeyboardResize = false;

	if ((mouse.absoluteY == y) &&
	    mouse.mouse1 &&
	    (x <= mouse.absoluteX) &&
	    (mouse.absoluteX < x + width) &&
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
	    return;
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
	    return;
	}

	// I didn't take it, pass it on to my children
	super.onMouseDown(event);
    }

    /**
     * Maximize window
     */
    private void maximize() {
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

    /**
     * Restote (unmaximize) window
     */
    private void restore() {
	width = restoreWindowWidth;
	height = restoreWindowHeight;
	x = restoreWindowX;
	y = restoreWindowY;
	maximized = false;
    }

    /**
     * Handle mouse button releases.
     *
     * Params:
     *    event = mouse button release event
     */
    override protected void onMouseUp(TMouseEvent event) {
	mouse = event;
	application.repaint = true;

	if ((inWindowMove == true) && (mouse.mouse1)) {
	    // Stop moving window
	    inWindowMove = false;
	    return;
	}

	if ((inWindowResize == true) && (mouse.mouse1)) {
	    // Stop resizing window
	    inWindowResize = false;
	    return;
	}

	if (mouse.mouse1 && mouseOnClose()) {
	    // Close window
	    application.closeWindow(this);
	    return;
	}

	if ((mouse.absoluteY == y) && mouse.mouse1 &&
	    mouseOnMaximize()) {
	    if (maximized) {
		// Restore
		restore();
	    } else {
		// Maximize
		maximize();
	    }
	    // Pass a resize event to my children
	    onResize(new TResizeEvent(TResizeEvent.Type.Widget, width, height));
	    return;
	}

	// I didn't take it, pass it on to my children
	super.onMouseUp(event);
    }

    /**
     * Handle mouse movements.
     *
     * Params:
     *    event = mouse motion event
     */
    override protected void onMouseMotion(TMouseEvent event) {
	mouse = event;
	application.repaint = true;

	if (inWindowMove == true) {
	    // Move window over
	    x = oldWindowX + (mouse.absoluteX - moveWindowMouseX);
	    y = oldWindowY + (mouse.absoluteY - moveWindowMouseY);
	    // Don't cover up the menu bar
	    if (y < application.desktopTop) {
		y = application.desktopTop;
	    }
	    return;
	}

	if (inWindowResize == true) {
	    // Move window over
	    width = resizeWindowWidth + (mouse.absoluteX - moveWindowMouseX);
	    height = resizeWindowHeight + (mouse.absoluteY - moveWindowMouseY);
	    if (x + width > screen.getWidth()) {
		width = screen.getWidth() - x;
	    }
	    if (y + height > application.desktopBottom) {
		y = application.desktopBottom - height + 1;
	    }
	    // Don't cover up the menu bar
	    if (y < application.desktopTop) {
		y = application.desktopTop;
	    }

	    // Keep within min/max bounds
	    if (width < minimumWindowWidth) {
		width = minimumWindowWidth;
		inWindowResize = false;
	    }
	    if (height < minimumWindowHeight) {
		height = minimumWindowHeight;
		inWindowResize = false;
	    }
	    if ((maximumWindowWidth > 0) && (width > maximumWindowWidth)) {
		width = maximumWindowWidth;
		inWindowResize = false;
	    }
	    if ((maximumWindowHeight > 0) && (height > maximumWindowHeight)) {
		height = maximumWindowHeight;
		inWindowResize = false;
	    }

	    // Pass a resize event to my children
	    onResize(new TResizeEvent(TResizeEvent.Type.Widget, width, height));
	    return;
	}

	// I didn't take it, pass it on to my children
	super.onMouseMotion(event);
    }

    /**
     * Handle keystrokes.
     *
     * Params:
     *    keypress = keystroke event
     */
    override protected void onKeypress(TKeypressEvent keypress) {

	if (inKeyboardResize) {

	    // ESC - Exit size/move
	    if (keypress.key == kbEsc) {
		inKeyboardResize = false;
	    }

	    if (keypress.key == kbLeft) {
		if (x > 0) {
		    x--;
		}
	    }
	    if (keypress.key == kbRight) {
		if (x < screen.getWidth() - 1) {
		    x++;
		}
	    }
	    if (keypress.key == kbDown) {
		if (y < application.desktopBottom - 1) {
		    y++;
		}
	    }
	    if (keypress.key == kbUp) {
		if (y > 1) {
		    y--;
		}
	    }
	    if (keypress.key == kbShiftLeft) {
		if (width > minimumWindowWidth) {
		    width--;
		}
	    }
	    if (keypress.key == kbShiftRight) {
		if (width < maximumWindowWidth) {
		    width++;
		}
	    }
	    if (keypress.key == kbShiftUp) {
		if (height > minimumWindowHeight) {
		    height--;
		}
	    }
	    if (keypress.key == kbShiftDown) {
		if (height < maximumWindowHeight) {
		    height++;
		}
	    }

	    return;
	}

	// These keystrokes will typically not be seen unless a
	// subclass overrides onMenu() due to how TApplication
	// dispatches accelerators.

	// Ctrl-W - close window
	if (keypress.key == kbCtrlW) {
	    application.closeWindow(this);
	    return;
	}

	// F6 - behave like Alt-TAB
	if (keypress.key == kbF6) {
	    application.switchWindow(true);
	    return;
	}

	// Shift-F6 - behave like Shift-Alt-TAB
	if (keypress.key == kbShiftF6) {
	    application.switchWindow(false);
	    return;
	}

	// F5 - zoom
	if (keypress.key == kbF5) {
	    if (maximized) {
		restore();
	    } else {
		maximize();
	    }
	}

	// Ctrl-F5 - size/move
	if (keypress.key == kbCtrlF5) {
	    inKeyboardResize = !inKeyboardResize;
	}

	// I didn't take it, pass it on to my children
	super.onKeypress(keypress);
    }

    /**
     * Handle posted command events.
     *
     * Params:
     *    cmd = command event
     */
    override public void onCommand(TCommandEvent cmd) {

	// These commands will typically not be seen unless a subclass
	// overrides onMenu() due to how TApplication dispatches
	// accelerators.

	if (cmd.cmd == cmWindowClose) {
	    application.closeWindow(this);
	    return;
	}

	if (cmd.cmd == cmWindowNext) {
	    application.switchWindow(true);
	    return;
	}

	if (cmd.cmd == cmWindowPrevious) {
	    application.switchWindow(false);
	    return;
	}

	if (cmd.cmd == cmWindowMove) {
	    inKeyboardResize = true;
	    return;
	}

	if (cmd.cmd == cmWindowZoom) {
	    if (maximized) {
		restore();
	    } else {
		maximize();
	    }
	}

	// I didn't take it, pass it on to my children
	super.onCommand(cmd);
    }

    /**
     * Handle posted menu events.
     *
     * Params:
     *    menu = menu event
     */
    override public void onMenu(TMenuEvent menu) {
	if (menu.id == TMenu.MID_WINDOW_CLOSE) {
	    application.closeWindow(this);
	    return;
	}

	if (menu.id == TMenu.MID_WINDOW_NEXT) {
	    application.switchWindow(true);
	    return;
	}

	if (menu.id == TMenu.MID_WINDOW_PREVIOUS) {
	    application.switchWindow(false);
	    return;
	}

	if (menu.id == TMenu.MID_WINDOW_MOVE) {
	    inKeyboardResize = true;
	    return;
	}

	if (menu.id == TMenu.MID_WINDOW_ZOOM) {
	    if (maximized) {
		restore();
	    } else {
		maximize();
	    }
	    return;
	}

	// I didn't take it, pass it on to my children
	super.onMenu(menu);
    }

}

// Functions -----------------------------------------------------------------
