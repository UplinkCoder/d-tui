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
import twidget;

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * TMenu is a top-level collection of TMenuItems
 */
public class TMenu : TWidget {

    /// Label for this menu
    private dstring label;

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    label = label to display on the group box
     */
    public this(TWidget parent, uint x, uint y, dstring label) {

	// Set parent and window
	super(parent);

	this.x = x;
	this.y = y;
	this.height = 2;
	this.label = label;
	this.width = cast(uint)label.length + 4;
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

	// Fill in the interior background
	for (auto i = 0; i < height; i++) {
	    window.hLineXY(0, i, width, ' ', background);
	}
    }

    /**
     * Convenience function to add a menu item to this group.
     *
     * Params:
     *    label = label to display next to (right of) the radiobutton
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
     *    label = label to display next to (right of) the radiobutton
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
    private bool mouseOnMenuItem(TInputEvent mouse) {
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
    override protected void onMouseDown(TInputEvent event) {
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
    override protected void onKeypress(TInputEvent event) {
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
