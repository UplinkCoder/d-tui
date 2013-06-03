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
 * TMenu is a top-level collection of TMenuItems
 */
public class TMenu : TWindow {

    /// Keyboard shortcut to activate this menu
    public dchar shortcut;

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
	super(parent, label, x, y, parent.screen.getWidth(), parent.screen.getHeight(), 0);

	// My parent constructor added me as a window, get rid of that
	parent.closeWindow(this);

	// Setup the menu shortcut
	dstring newTitle = "";
	bool foundAmp = false;
	bool foundShortcut = false;
	foreach (c; title) {
	    if (c == '&') {
		if (foundAmp == true) {
		    newTitle ~= '&';
		} else {
		    foundAmp = true;
		}
	    } else {
		newTitle ~= c;
		if (foundAmp == true) {
		    assert(foundShortcut == false);
		    shortcut = toLowercase(c);
		    foundAmp = false;
		    foundShortcut = true;
		}
	    }
	}
	this.title = newTitle;

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
    }

    /**
     * Handle keystrokes.
     *
     * Params:
     *    event = keystroke event
     */
    override protected void onKeypress(TKeypressEvent event) {

	if (event.key == kbEsc) {
	    application.closeMenu();
	    return;
	}
	if (event.key == kbDown) {
	    switchWidget(true);
	    return;
	}
	if (event.key == kbUp) {
	    switchWidget(false);
	    return;
	}
	if (event.key == kbRight) {
	    application.switchMenu(true);
	    return;
	}
	if (event.key == kbLeft) {
	    application.switchMenu(false);
	    return;
	}

	// Dispatch the keypress to an active widget
	foreach (w; children) {
	    if (w.active) {
		window.application.repaint = true;
		w.handleEvent(event);
		return;
	    }
	}
    }

    /**
     * Convenience function to add a menu item.
     *
     * Params:
     *    label = menu item label
     *    cmd = command to dispatch when this item is selected
     *    key = global keyboard accelerator
     *
     * Returns:
     *    the new menu item
     */
    public TMenuItem addItem(dstring label, TCommand cmd, TKeypress key) {
	uint y = cast(uint)children.length + 1;
	
	assert(y < height);
	TMenuItem menuItem = new TMenuItem(this, 1, y, label);
	menuItem.setCommand(cmd, key);
	height++;
	if (menuItem.width + 2 > width) {
	    width = menuItem.width + 2;
	    foreach (i; children) {
		i.width = width - 2;
	    }
	}
	application.addAccelerator(cmd, toLower(key));
	application.recomputeMenuX();
	return menuItem;
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

    /// Optional command this item executes
    private TCommand cmd;
    private TKeypress key;
    private bool hasCommand = false;

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
	this.key = key;

	uint newWidth = cast(uint)(label.length + 4 + key.toString().length + 2);
	if (newWidth > width) {
	    width = newWidth;
	}
    }

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    label = menu item title
     */
    public this(TMenu parent, uint x, uint y, dstring label) {

	// Set parent and window
	super(parent);

	this.x = x;
	this.y = y;
	this.height = 1;
	this.label = label;
	this.width = cast(uint)label.length + 4;
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
	CellAttributes menuColor;
	CellAttributes background = window.application.theme.getColor("tmenu");

	if (getAbsoluteActive()) {
	    menuColor = window.application.theme.getColor("tmenu.highlighted");
	} else {
	    menuColor = window.application.theme.getColor("tmenu");
	}

	dchar cVSide = GraphicsChars.WINDOW_SIDE;
	window.vLineXY(0, 0, 1, cVSide, background);
	window.vLineXY(width - 1, 0, 1, cVSide, background);

	window.hLineXY(1, 0, width - 2, ' ', menuColor);
	window.putStrXY(2, 0, label, menuColor);
	if (hasCommand) {
	    dstring keyLabel = key.toString();
	    window.putStrXY(cast(uint)(width - keyLabel.length - 2), 0, keyLabel, menuColor);
	}
    }

    /**
     * Handle mouse button presses.
     *
     * Params:
     *    event = mouse button press event
     */
    override protected void onMouseDown(TMouseEvent event) {
	if ((mouseOnMenuItem(event)) && (event.mouse1)) {
	    if (hasCommand) {
		window.application.addMenuEvent(new TCommandEvent(cmd));
	    }
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
	    // Dispatch
	    if (hasCommand) {
		window.application.addMenuEvent(new TCommandEvent(cmd));
	    }
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
    public this(TMenu parent, uint x, uint y) {
	super(parent, x, y, "");
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
