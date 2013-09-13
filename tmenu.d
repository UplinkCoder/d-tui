/**
 * D Text User Interface library - TMenu and TMenuItem classes
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

import std.utf;
import base;
import codepage;
import tapplication;
import twidget;
import twindow;

// DEBUG
import std.stdio;

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * AcceleratorString is used to render a string like "&File" into a
 * highlighted 'F' and the rest of 'ile'.
 */
private class AcceleratorString {

    /// Keyboard shortcut to activate this menu
    public dchar shortcut;

    /// Location of the highlighted character
    public int shortcutIdx = -1;

    /// The raw (uncolored) string
    public dstring rawTitle;

    /**
     * Public constructor
     *
     * Params:
     *    title = menu or menuitem title.  Title must contain a keyboard shortcut, denoted by prefixing a letter with "&", e.g. "&File"
     */
    public this(dstring label) {

	// Setup the menu shortcut
	dstring newTitle = "";
	bool foundAmp = false;
	bool foundShortcut = false;
	uint shortcutIdx = 0;
	foreach (c; label) {
	    if (c == '&') {
		if (foundAmp == true) {
		    newTitle ~= '&';
		    shortcutIdx++;
		} else {
		    foundAmp = true;
		}
	    } else {
		newTitle ~= c;
		if (foundAmp == true) {
		    assert(foundShortcut == false);
		    shortcut = c;
		    foundAmp = false;
		    foundShortcut = true;
		    this.shortcutIdx = shortcutIdx;
		} else {
		    shortcutIdx++;
		}
	    }
	}
	this.rawTitle = newTitle;
    }

}

/**
 * TMenu is a top-level collection of TMenuItems
 */
public class TMenu : TWindow {

    /// The shortcut and title
    public AcceleratorString accelerator;

    /// Reserved menu item IDs
    public static immutable short MID_UNUSED		= -1;

    // File menu
    public static immutable short MID_EXIT		= 1;
    public static immutable short MID_QUIT		= MID_EXIT;
    public static immutable short MID_OPEN_FILE		= 2;
    public static immutable short MID_SHELL		= 3;

    // Edit menu
    public static immutable short MID_CUT		= 10;
    public static immutable short MID_COPY		= 11;
    public static immutable short MID_PASTE		= 12;
    public static immutable short MID_CLEAR		= 13;

    // Window menu
    public static immutable short MID_TILE		= 20;
    public static immutable short MID_CASCADE		= 21;
    public static immutable short MID_CLOSE_ALL		= 22;
    public static immutable short MID_WINDOW_MOVE	= 23;
    public static immutable short MID_WINDOW_ZOOM	= 24;
    public static immutable short MID_WINDOW_NEXT	= 25;
    public static immutable short MID_WINDOW_PREVIOUS	= 26;
    public static immutable short MID_WINDOW_CLOSE	= 27;

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent application
     *    x = column relative to parent
     *    y = row relative to parent
     *    title = menu title.  Title must contain a keyboard shortcut, denoted by prefixing a letter with "&", e.g. "&File"
     */
    public this(TApplication parent, uint x, uint y, dstring label) {
	super(parent, label, x, y, parent.backend.screen.getWidth(),
	    parent.backend.screen.getHeight());

	// My parent constructor added me as a window, get rid of that
	parent.closeWindow(this);

	// Setup the menu shortcut
	accelerator = new AcceleratorString(title);
	this.title = accelerator.rawTitle;
	assert(accelerator.shortcutIdx >= 0);

	// Recompute width and height to reflect an empty menu
	width = cast(uint)this.title.length + 4;
	height = 2;

	this.active = false;
    }

    /// Draw a top-level menu with title and menu items
    override public void draw() {
	CellAttributes menuColor;
	CellAttributes background = window.application.theme.getColor("tmenu");

	if (getAbsoluteActive()) {
	    menuColor = window.application.theme.getColor("tmenu.highlighted");
	} else {
	    menuColor = window.application.theme.getColor("tmenu");
	}

	assert(getAbsoluteActive());

	// Fill in the interior background
	for (auto i = 0; i < height; i++) {
	    screen.hLineXY(0, i, width, ' ', background);
	}

	// Draw the box
	dchar cTopLeft;
	dchar cTopRight;
	dchar cBottomLeft;
	dchar cBottomRight;
	dchar cHSide;

	cTopLeft = GraphicsChars.ULCORNER;
	cTopRight = GraphicsChars.URCORNER;
	cBottomLeft = GraphicsChars.LLCORNER;
	cBottomRight = GraphicsChars.LRCORNER;
	cHSide = GraphicsChars.SINGLE_BAR;

	// Place the corner characters
	screen.putCharXY(1, 0, cTopLeft, background);
	screen.putCharXY(width - 2, 0, cTopRight, background);
	screen.putCharXY(1, height - 1, cBottomLeft, background);
	screen.putCharXY(width - 2, height - 1, cBottomRight, background);

	// Draw the box lines
	screen.hLineXY(1 + 1, 0, width - 4, cHSide, background);
	screen.hLineXY(1 + 1, height - 1, width - 4, cHSide, background);

	// Draw a shadow
	screen.drawBoxShadow(0, 0, width, height);
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

	// Pass to children
	foreach (w; children) {
	    if (w.mouseWouldHit(event)) {
		// Dispatch to this child, also activate it
		activate(w);

		// Set x and y relative to the child's coordinates
		event.x = event.absoluteX - w.getAbsoluteX();
		event.y = event.absoluteY - w.getAbsoluteY();
		w.handleEvent(event);
		return;
	    }
	}
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

	// Pass to children
	foreach (w; children) {
	    if (w.mouseWouldHit(event)) {
		// Dispatch to this child, also activate it
		activate(w);

		// Set x and y relative to the child's coordinates
		event.x = event.absoluteX - w.getAbsoluteX();
		event.y = event.absoluteY - w.getAbsoluteY();
		w.handleEvent(event);
		return;
	    }
	}
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

	// See if we should activate a different menu item
	foreach (w; children) {
	    if ((event.mouse1) &&
		(w.mouseWouldHit(event))
	    ) {
		// Activate this menu item
		activate(w);
		return;
	    }
	}
    }

    /**
     * Handle keystrokes.
     *
     * Params:
     *    event = keystroke event
     */
    override protected void onKeypress(TKeypressEvent keypress) {

	if (keypress.key == kbEsc) {
	    application.closeMenu();
	    return;
	}
	if (keypress.key == kbDown) {
	    switchWidget(true);
	    return;
	}
	if (keypress.key == kbUp) {
	    switchWidget(false);
	    return;
	}
	if (keypress.key == kbRight) {
	    application.switchMenu(true);
	    return;
	}
	if (keypress.key == kbLeft) {
	    application.switchMenu(false);
	    return;
	}

	// Switch to a menuItem if it has an accelerator
	if (!keypress.key.isKey &&
	    !keypress.key.alt &&
	    !keypress.key.ctrl) {
	    foreach (w; cast(TMenuItem [])children) {
		if ((w.accelerator !is null) &&
		    (toLowercase(w.accelerator.shortcut) == toLowercase(keypress.key.ch))
		) {
		    // Send an enter keystroke to it
		    activate(w);
		    w.handleEvent(new TKeypressEvent(kbEnter));
		    return;
		}
	    }
	}

	// Dispatch the keypress to an active widget
	foreach (w; children) {
	    if (w.active) {
		window.application.repaint = true;
		w.handleEvent(keypress);
		return;
	    }
	}
    }

    /**
     * Convenience function to add a custom menu item.
     *
     * Params:
     *    id = menu item ID.  Must be greater than 1024.
     *    label = menu item label
     *    cmd = command to dispatch when this item is selected
     *    key = global keyboard accelerator
     *
     * Returns:
     *    the new menu item
     */
    public TMenuItem addItem(short id, dstring label, TCommand cmd, TKeypress key) {
	assert(id >= 1024);
	return addItemInternal(id, label, cmd, key);
    }

    /**
     * Convenience function to add a custom menu item.
     *
     * Params:
     *    id = menu item ID.  Must be greater than 1024.
     *    label = menu item label
     *    cmd = command to dispatch when this item is selected
     *    key = global keyboard accelerator
     *
     * Returns:
     *    the new menu item
     */
    private TMenuItem addItemInternal(short id, dstring label, TCommand cmd, TKeypress key) {
	uint y = cast(uint)children.length + 1;

	assert(y < height);
	TMenuItem menuItem = new TMenuItem(this, id, 1, y, label);
	menuItem.setCommand(cmd, key);
	height++;
	if (menuItem.width + 2 > width) {
	    width = menuItem.width + 2;
	}
	foreach (i; children) {
	    i.width = width - 2;
	}
	application.addAccelerator(cmd, toLower(key));
	application.recomputeMenuX();
	activate(0);
	return menuItem;
    }

    /**
     * Convenience function to add a menu item.
     *
     * Params:
     *    id = menu item ID.  Must be greater than 1024.
     *    label = menu item label
     *    cmd = command to dispatch when this item is selected
     *
     * Returns:
     *    the new menu item
     */
    public TMenuItem addItem(short id, dstring label, TCommand cmd) {
	assert(id >= 1024);
	return addItemInternal(id, label, cmd);
    }

    /**
     * Convenience function to add a menu item.
     *
     * Params:
     *    id = menu item ID
     *    label = menu item label
     *    cmd = command to dispatch when this item is selected
     *
     * Returns:
     *    the new menu item
     */
    private TMenuItem addItemInternal(short id, dstring label, TCommand cmd) {
	uint y = cast(uint)children.length + 1;

	assert(y < height);
	TMenuItem menuItem = new TMenuItem(this, id, 1, y, label);
	menuItem.setCommand(cmd);
	height++;
	if (menuItem.width + 2 > width) {
	    width = menuItem.width + 2;
	}
	foreach (i; children) {
	    i.width = width - 2;
	}
	application.recomputeMenuX();
	activate(0);
	return menuItem;
    }

    /**
     * Convenience function to add a menu item.
     *
     * Params:
     *    id = menu item ID.  Must be greater than 1024.
     *    label = menu item label
     *
     * Returns:
     *    the new menu item
     */
    public TMenuItem addItem(short id, dstring label) {
	assert(id >= 1024);
	return addItemInternal(id, label);
    }

    /**
     * Convenience function to add a menu item.
     *
     * Params:
     *    id = menu item ID
     *    label = menu item label
     *
     * Returns:
     *    the new menu item
     */
    private TMenuItem addItemInternal(short id, dstring label) {
	uint y = cast(uint)children.length + 1;

	assert(y < height);
	TMenuItem menuItem = new TMenuItem(this, id, 1, y, label);
	height++;
	if (menuItem.width + 2 > width) {
	    width = menuItem.width + 2;
	}
	foreach (i; children) {
	    i.width = width - 2;
	}
	application.recomputeMenuX();
	activate(0);
	return menuItem;
    }

    /**
     * Convenience function to add one of the default menu items.
     *
     * Params:
     *    id = menu item ID.  Must be between 0 (inclusive) and 1023 (inclusive).
     *
     * Returns:
     *    the new menu item
     */
    public TMenuItem addDefaultItem(short id) {
	assert(id >= 0);
	assert(id < 1024);

	dstring label;
	TCommand cmd;
	TKeypress key;
	bool hasKey = true;

	final switch (id) {

	case MID_EXIT:
	    label = "E&xit";
	    cmd = cmExit;
	    key = kbAltX;
	    break;

	case MID_SHELL:
	    label = "O&S Shell";
	    cmd = cmShell;
	    hasKey = false;
	    break;

	case MID_OPEN_FILE:
	    label = "&Open";
	    cmd = cmOpen;
	    key = kbAltO;
	    break;

	case MID_CUT:
	    label = "Cu&t";
	    cmd = cmCut;
	    key = kbCtrlX;
	    break;
	case MID_COPY:
	    label = "&Copy";
	    cmd = cmCopy;
	    key = kbCtrlC;
	    break;
	case MID_PASTE:
	    label = "&Paste";
	    cmd = cmPaste;
	    key = kbCtrlV;
	    break;
	case MID_CLEAR:
	    label = "C&lear";
	    cmd = cmClear;
	    key = kbDel;
	    break;

	case MID_TILE:
	    break;
	case MID_CASCADE:
	    break;
	case MID_CLOSE_ALL:
	    break;
	case MID_WINDOW_MOVE:
	    break;
	case MID_WINDOW_ZOOM:
	    break;
	case MID_WINDOW_NEXT:
	    break;
	case MID_WINDOW_PREVIOUS:
	    break;
	case MID_WINDOW_CLOSE:
	    break;

	}

	if (hasKey) {
	    return addItemInternal(id, label, cmd, key);
	}
	return addItemInternal(id, label, cmd);
    }

    /**
     * Convenience function to add a menu separator.
     */
    public void addSeparator() {
	uint y = cast(uint)children.length + 1;
	assert(y < height);
	TMenuItem menuItem = new TMenuSeparator(this, 1, y);
	height++;
    }

}

/**
 * TMenuItem implements a menu item
 */
public class TMenuItem : TWidget {

    /// Label for this menu item
    private dstring label;

    /// Menu ID.  IDs less than 1024 are reserved for common system
    /// functions.  Existing ones are defined in TMenu, i.e. TMenu.MID_EXIT.
    public short id = TMenu.MID_UNUSED;

    /// When true, this item can be checked or unchecked
    public bool checkable = false;

    /// When true, this item is checked
    public bool checked = false;

    /// Optional command this item executes
    private TCommand cmd;

    /// When true, selecting this menu item causes a TCommandEvent to be
    /// fired IN ADDITION TO the TMenuEvent.
    private bool hasCommand = false;

    /// Highlighted shortcut key (also called a menu mnenomic)
    private TKeypress key;

    /// When true, accelerator (mnenomic) can be used to select this item
    private bool hasKey = false;

    /// The title string.  Use '&' to specify a mnemonic, i.e. "&File" will
    /// highlight the 'F' and allow 'f' or 'F' to select it.
    public AcceleratorString accelerator;

    /**
     * Set a command for this menu to execute
     *
     * Params:
     *    cmd = command to execute on Enter
     *    key = global keyboard accelerator
     */
    public void setCommand(TCommand cmd, TKeypress key) {
	hasCommand = true;
	this.cmd = cmd;
	hasKey = true;
	this.key = key;

	uint newWidth = cast(uint)(label.length + 4 + key.toString().length + 2);
	if (newWidth > width) {
	    width = newWidth;
	}
    }

    /**
     * Set a command for this menu to execute
     *
     * Params:
     *    cmd = command to execute on Enter
     */
    public void setCommand(TCommand cmd) {
	hasCommand = true;
	this.cmd = cmd;
	hasKey = false;
    }

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    id = menu id
     *    x = column relative to parent
     *    y = row relative to parent
     *    label = menu item title
     */
    private this(TMenu parent, short id, uint x, uint y, dstring label) {
	// Set parent and window
	super(parent);

	accelerator = new AcceleratorString(label);

	this.x = x;
	this.y = y;
	this.height = 1;
	this.label = accelerator.rawTitle;
	this.width = cast(uint)label.length + 4;
	this.id = id;

	// Save for the application
	if (id != TMenu.MID_UNUSED) {
	    window.application.addMenuItem(this);
	}

	// Default state for some known menu items
	switch (id) {

	case TMenu.MID_CUT:
	    enabled = false;
	    break;
	case TMenu.MID_COPY:
	    enabled = false;
	    break;
	case TMenu.MID_PASTE:
	    enabled = false;
	    break;
	case TMenu.MID_CLEAR:
	    enabled = false;
	    break;

	case TMenu.MID_TILE:
	    break;
	case TMenu.MID_CASCADE:
	    break;
	case TMenu.MID_CLOSE_ALL:
	    break;
	case TMenu.MID_WINDOW_MOVE:
	    break;
	case TMenu.MID_WINDOW_ZOOM:
	    break;
	case TMenu.MID_WINDOW_NEXT:
	    break;
	case TMenu.MID_WINDOW_PREVIOUS:
	    break;
	case TMenu.MID_WINDOW_CLOSE:
	    break;
	default:
	    break;
	}

    }

    /**
     * Returns true if the mouse is currently on the menu item
     *
     * Params:
     *    mouse = mouse event
     */
    private bool mouseOnMenuItem(TMouseEvent mouse) {
	if ((mouse.y == 0) &&
	    (mouse.x >= 0) &&
	    (mouse.x < width)
	) {
	    return true;
	}
	return false;
    }

    /// Draw a menu item with label
    override public void draw() {
	CellAttributes background = window.application.theme.getColor("tmenu");
	CellAttributes menuColor;
	CellAttributes menuAcceleratorColor;
	if (getAbsoluteActive()) {
	    menuColor = window.application.theme.getColor("tmenu.highlighted");
	    menuAcceleratorColor = window.application.theme.getColor("tmenu.accelerator.highlighted");
	} else {
	    if (enabled) {
		menuColor = window.application.theme.getColor("tmenu");
		menuAcceleratorColor = window.application.theme.getColor("tmenu.accelerator");
	    } else {
		menuColor = window.application.theme.getColor("tmenu.disabled");
		menuAcceleratorColor = window.application.theme.getColor("tmenu.disabled");
	    }
	}

	dchar cVSide = GraphicsChars.WINDOW_SIDE;
	window.vLineXY(0, 0, 1, cVSide, background);
	window.vLineXY(width - 1, 0, 1, cVSide, background);

	window.hLineXY(1, 0, width - 2, ' ', menuColor);
	window.putStrXY(2, 0, accelerator.rawTitle, menuColor);
	if (hasKey) {
	    dstring keyLabel = key.toString();
	    window.putStrXY(cast(uint)(width - keyLabel.length - 2), 0, keyLabel, menuColor);
	}
	if (accelerator.shortcutIdx >= 0) {
	    window.putCharXY(2 + accelerator.shortcutIdx, 0,
		accelerator.shortcut, menuAcceleratorColor);
	}
	if (checked) {
	    assert(checkable);
	    window.putCharXY(1, 0, GraphicsChars.CHECK, menuColor);
	}

    }

    /// Dispatch event(s) due to selection or click
    private void dispatch() {
	assert(enabled == true);

	window.application.addMenuEvent(new TMenuEvent(id));
	if (hasCommand) {
	    window.application.addMenuEvent(new TCommandEvent(cmd));
	}
	if (checkable) {
	    checked = !checked;
	}
    }

    /+
    /**
     * Handle mouse button presses.
     *
     * Params:
     *    event = mouse button press event
     */
    override protected void onMouseDown(TMouseEvent event) {
	if ((mouseOnMenuItem(event)) && (event.mouse1)) {
	    dispatch();
	    return;
	}
    }
     +/

    /**
     * Handle mouse button releases.
     *
     * Params:
     *    event = mouse button release event
     */
    override protected void onMouseUp(TMouseEvent event) {
	if ((mouseOnMenuItem(event)) && (event.mouse1)) {
	    dispatch();
	    return;
	}
    }

    /**
     * Handle keystrokes.
     *
     * Params:
     *    event = keystroke event
     */
    override protected void onKeypress(TKeypressEvent event) {
	TKeypress key = event.key;

	if (key == kbEnter) {
	    dispatch();
	    return;
	}

	// Pass to parent for the things we don't care about.
	super.onKeypress(event);
    }
}

/**
 * TMenuSeparator is a special case menu item.
 */
public class TMenuSeparator : TMenuItem {

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     */
    private this(TMenu parent, uint x, uint y) {
	super(parent, TMenu.MID_UNUSED, x, y, "");
	enabled = false;
	active = false;
	width = parent.width - 2;
    }

    /// Draw a menu separator
    override public void draw() {
	CellAttributes background = window.application.theme.getColor("tmenu");

	window.putCharXY(0, 0, cp437_chars[0xC3], background);
	window.putCharXY(width - 1, 0, cp437_chars[0xB4], background);
	window.hLineXY(1, 0, width - 2, GraphicsChars.SINGLE_BAR, background);
    }

}

// Functions -----------------------------------------------------------------
