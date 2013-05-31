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

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent application
     *    x = column relative to parent
     *    y = row relative to parent
     *    title = menu title
     */
    public this(TApplication parent, uint x, uint y, dstring label) {
	super(parent, label, x, y, parent.screen.getWidth(), parent.screen.getHeight(), 0);

	// Recompute width and height to reflect an empty menu
	width = cast(uint)title.length + 2;
	height = 3;

	// My parent constructor added me as a window, get rid of that
	parent.closeWindow(this);

	// My parent constructor set my y to y + desktopTop, fix that
	this.y = y;

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

	// Fill in the interior background
	if (getAbsoluteActive()) {
	    for (auto i = 1; i < height; i++) {
		screen.hLineXY(0, i, width, ' ', background);
	    }
	}
	screen.putCharXY(0, 0, ' ', menuColor);
	screen.putStrXY(1, 0, title, menuColor);
	screen.putCharXY(width - 1, 0, ' ', menuColor);
    }

    /**
     * Convenience function to add a menu item to this group.
     *
     * Params:
     *    label = menu item title
     */
    public TMenuItem addMenuItem(dstring label) {
	uint buttonX = 1;
	uint buttonY = cast(uint)children.length + 1;
	if (label.length + 4 > width) {
	    width = cast(uint)label.length + 7;
	}
	height = cast(uint)children.length + 3;
	return new TMenuItem(this, buttonX, buttonY, label);
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

	// I didn't take it, pass it on to my children
	super.onMouseDown(event);
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

	// I didn't take it, pass it on to my children
	super.onMouseMotion(event);
    }

}

/**
 * TMenuItem implements a menu item
 */
public class TMenuItem : TWidget {

    /// Label for this menu item
    private dstring label;

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
	this.width = cast(uint)label.length;
    }

    /**
     * Returns true if the mouse is currently on the menu item
     *
     * Params:
     *    mouse = mouse event
     */
    private bool mouseOnMenuItem(TMouseEvent mouse) {
	if ((mouse !is null) &&
	    (mouse.y == 0) &&
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

	if (getAbsoluteActive()) {
	    menuColor = window.application.theme.getColor("tmenu.highlighted");
	} else {
	    menuColor = window.application.theme.getColor("tmenu");
	}
	window.putStrXY(0, 0, label, menuColor);
    }

    /**
     * Handle mouse button presses.
     *
     * Params:
     *    event = mouse button press event
     */
    override protected void onMouseDown(TMouseEvent event) {
	if ((mouseOnMenuItem(event)) && (event.mouse1)) {
	    // TODO
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

	    // TODO

	    return;
	}

	// Pass to parent for the things we don't care about.
	super.onKeypress(event);
    }

}

// Functions -----------------------------------------------------------------
