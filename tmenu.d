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

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * TMenu is a top-level collection of TMenuItems
 */
public class TMenu : TWindow {

    /// If true, this is a sub-menu
    private bool isSubMenu = false;

    /// The shortcut and title
    public MnemonicString mnemonic;

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
	mnemonic = new MnemonicString(title);
	this.title = mnemonic.rawLabel;
	assert(mnemonic.shortcutIdx >= 0);

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
	if (activeChild !is null) {
	    if (auto item = cast(TSubMenu)activeChild) {
		item.onKeypress(keypress);
		return;
	    }
	}

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
	    if (!isSubMenu) {
		application.switchMenu(true);
	    }
	    return;
	}
	if (keypress.key == kbLeft) {
	    if (isSubMenu) {
		application.closeSubMenu();
	    } else {
		application.switchMenu(false);
	    }
	    return;
	}

	// Switch to a menuItem if it has an mnemonic
	if (!keypress.key.isKey &&
	    !keypress.key.alt &&
	    !keypress.key.ctrl) {
	    foreach (w; cast(TMenuItem [])children) {
		if ((w.mnemonic !is null) &&
		    (toLowercase(w.mnemonic.shortcut) == toLowercase(keypress.key.ch))
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
     *    key = global keyboard accelerator
     *
     * Returns:
     *    the new menu item
     */
    public TMenuItem addItem(short id, dstring label, TKeypress key) {
	assert(id >= 1024);
	return addItemInternal(id, label, key);
    }

    /**
     * Convenience function to add a custom menu item.
     *
     * Params:
     *    id = menu item ID.  Must be greater than 1024.
     *    label = menu item label
     *    key = global keyboard accelerator
     *
     * Returns:
     *    the new menu item
     */
    private TMenuItem addItemInternal(short id, dstring label, TKeypress key) {
	uint y = cast(uint)children.length + 1;

	assert(y < height);
	TMenuItem menuItem = new TMenuItem(this, id, 1, y, label);
	menuItem.setKey(key);
	height++;
	if (menuItem.width + 2 > width) {
	    width = menuItem.width + 2;
	}
	foreach (i; children) {
	    i.width = width - 2;
	}
	application.addAccelerator(menuItem, toLower(key));
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
	TKeypress key;
	bool hasKey = true;

	final switch (id) {

	case MID_EXIT:
	    label = "E&xit";
	    key = kbAltX;
	    break;

	case MID_SHELL:
	    label = "O&S Shell";
	    hasKey = false;
	    break;

	case MID_OPEN_FILE:
	    label = "&Open";
	    key = kbAltO;
	    break;

	case MID_CUT:
	    label = "Cu&t";
	    key = kbCtrlX;
	    break;
	case MID_COPY:
	    label = "&Copy";
	    key = kbCtrlC;
	    break;
	case MID_PASTE:
	    label = "&Paste";
	    key = kbCtrlV;
	    break;
	case MID_CLEAR:
	    label = "C&lear";
	    key = kbDel;
	    break;

	case MID_TILE:
	    label = "&Tile";
	    hasKey = false;
	    break;
	case MID_CASCADE:
	    label = "C&ascade";
	    hasKey = false;
	    break;
	case MID_CLOSE_ALL:
	    label = "Cl&ose All";
	    hasKey = false;
	    break;
	case MID_WINDOW_MOVE:
	    label = "&Size/Move";
	    key = kbCtrlF5;
	    break;
	case MID_WINDOW_ZOOM:
	    label = "&Zoom";
	    key = kbF5;
	    break;
	case MID_WINDOW_NEXT:
	    label = "&Next";
	    key = kbF6;
	    break;
	case MID_WINDOW_PREVIOUS:
	    label = "&Previous";
	    key = kbShiftF6;
	    break;
	case MID_WINDOW_CLOSE:
	    label = "&Close";
	    key = kbCtrlW;
	    break;

	}

	if (hasKey) {
	    return addItemInternal(id, label, key);
	}
	return addItemInternal(id, label);
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

    /**
     * Convenience function to add a submenu.
     *
     * Params:
     *    title = menu title.  Title must contain a keyboard shortcut, denoted by prefixing a letter with "&", e.g. "&File"
     */
    public TSubMenu addSubMenu(dstring title) {
	uint y = cast(uint)children.length + 1;

	assert(y < height);
	TSubMenu subMenu = new TSubMenu(this, title, 1, y);
	height++;
	if (subMenu.width + 2 > width) {
	    width = subMenu.width + 2;
	}
	foreach (i; children) {
	    i.width = width - 2;
	}
	application.recomputeMenuX();
	activate(0);
	subMenu.menu.x = x + width - 2;

	return subMenu;
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

    /// Global shortcut key
    private TKeypress key;

    /// When true, a global accelerator can be used to select this item
    private bool hasKey = false;

    /// The title string.  Use '&' to specify a mnemonic, i.e. "&File" will
    /// highlight the 'F' and allow 'f' or 'F' to select it.
    public MnemonicString mnemonic;

    /**
     * Set a global accelerator key for this menu item
     *
     * Params:
     *    key = global keyboard accelerator
     */
    public void setKey(TKeypress key) {
	hasKey = true;
	this.key = key;

	uint newWidth = cast(uint)(label.length + 4 + key.toString().length + 2);
	if (newWidth > width) {
	    width = newWidth;
	}
    }

    /**
     * Private constructor
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

	mnemonic = new MnemonicString(label);

	this.x = x;
	this.y = y;
	this.height = 1;
	this.label = mnemonic.rawLabel;
	this.width = cast(uint)label.length + 4;
	this.id = id;

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
	CellAttributes menuMnemonicColor;
	if (getAbsoluteActive()) {
	    menuColor = window.application.theme.getColor("tmenu.highlighted");
	    menuMnemonicColor = window.application.theme.getColor("tmenu.mnemonic.highlighted");
	} else {
	    if (enabled) {
		menuColor = window.application.theme.getColor("tmenu");
		menuMnemonicColor = window.application.theme.getColor("tmenu.mnemonic");
	    } else {
		menuColor = window.application.theme.getColor("tmenu.disabled");
		menuMnemonicColor = window.application.theme.getColor("tmenu.disabled");
	    }
	}

	dchar cVSide = GraphicsChars.WINDOW_SIDE;
	window.vLineXY(0, 0, 1, cVSide, background);
	window.vLineXY(width - 1, 0, 1, cVSide, background);

	window.hLineXY(1, 0, width - 2, ' ', menuColor);
	window.putStrXY(2, 0, mnemonic.rawLabel, menuColor);
	if (hasKey) {
	    dstring keyLabel = key.toString();
	    window.putStrXY(cast(uint)(width - keyLabel.length - 2), 0, keyLabel, menuColor);
	}
	if (mnemonic.shortcutIdx >= 0) {
	    window.putCharXY(2 + mnemonic.shortcutIdx, 0,
		mnemonic.shortcut, menuMnemonicColor);
	}
	if (checked) {
	    assert(checkable);
	    window.putCharXY(1, 0, GraphicsChars.CHECK, menuColor);
	}

    }

    /// Dispatch event(s) due to selection or click
    public void dispatch() {
	assert(enabled == true);

	window.application.addMenuEvent(new TMenuEvent(id));
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
     * Private constructor
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

/**
 * TSubMenu is a special case menu item that wraps another TMenu.
 */
public class TSubMenu : TMenuItem {

    /// The menu window
    public TMenu menu;

    /// Allow access to addX() functions
    alias menu this;

    /**
     * Private constructor
     *
     * Params:
     *    parent = parent widget
     *    title = menu title.  Title must contain a keyboard shortcut, denoted by prefixing a letter with "&", e.g. "&File"
     *    x = column relative to parent
     *    y = row relative to parent
     */
    private this(TMenu parent, dstring title, uint x, uint y) {
	super(parent, TMenu.MID_UNUSED, x, y, title);

	active = false;
	enabled = true;

	this.menu = new TMenu(parent.application, x, getAbsoluteY(), title);
	width = menu.width + 2;

	this.menu.isSubMenu = true;
    }

    /// Draw the menu title
    override public void draw() {
	super.draw();

	CellAttributes background = window.application.theme.getColor("tmenu");
	CellAttributes menuColor;
	CellAttributes menuMnemonicColor;
	if (getAbsoluteActive()) {
	    menuColor = window.application.theme.getColor("tmenu.highlighted");
	    menuMnemonicColor = window.application.theme.getColor("tmenu.mnemonic.highlighted");
	} else {
	    if (enabled) {
		menuColor = window.application.theme.getColor("tmenu");
		menuMnemonicColor = window.application.theme.getColor("tmenu.mnemonic");
	    } else {
		menuColor = window.application.theme.getColor("tmenu.disabled");
		menuMnemonicColor = window.application.theme.getColor("tmenu.disabled");
	    }
	}

	// Add the arrow
	window.putCharXY(width - 2, 0, cp437_chars[0x10], menuColor);
    }

    /**
     * Handle keystrokes.
     *
     * Params:
     *    event = keystroke event
     */
    override protected void onKeypress(TKeypressEvent event) {

	if (menu.active) {
	    menu.onKeypress(event);
	    return;
	}

	TKeypress key = event.key;

	if (key == kbEnter) {
	    dispatch();
	    return;
	}

	if (key == kbRight) {
	    dispatch();
	    return;
	}

	if (key == kbDown) {
	    parent.switchWidget(true);
	    return;
	}

	if (key == kbUp) {
	    parent.switchWidget(false);
	    return;
	}

	if (key == kbLeft) {
	    auto parentMenu = cast(TMenu)parent;
	    if (parentMenu.isSubMenu) {
		application.closeSubMenu();
	    } else {
		application.switchMenu(false);
	    }
	    return;
	}

	if (key == kbEsc) {
	    application.closeMenu();
	    return;
	}
    }

    /// Override dispatch() to do nothing
    override public void dispatch() {
	assert(enabled == true);
	if (getAbsoluteActive()) {
	    if (menu.active == false) {
		application.addSubMenu(menu);
		menu.active = true;
	    }
	}
    }

    /**
     * Returns my active widget.
     *
     * Returns:
     *    widget that is active, or this if no children
     */
    override public TWidget getActiveChild() {
	if (menu.active) {
	    return menu;
	}
	// Menu not active, return me
	return this;
    }

}

// Functions -----------------------------------------------------------------
