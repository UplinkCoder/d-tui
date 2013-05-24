/**
 * D Text User Interface library - TCheckbox class
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
 * TCheckbox implements an on/off checkbox.
 */
public class TCheckbox : TWidget {

    /// Checkbox state, true means checked
    public bool checked = false;

    /// Label for this checkbox
    private dstring label;

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    label = label to display next to (right of) the checkbox
     *    checked = initial check state
     */
    public this(TWidget parent, uint x, uint y, dstring label,
	bool checked = false) {

	// Set parent and window
	super(parent);

	this.x = x;
	this.y = y;
	this.height = 1;
	this.label = label;
	this.width = cast(uint)label.length + 4;
	this.checked = checked;
    }

    /**
     * Returns true if the mouse is currently on the checkbox
     *
     * Params:
     *    mouse = mouse event
     */
    private bool mouseOnCheckbox(TInputEvent mouse) {
	if ((mouse !is null) &&
	    (mouse.y == 0) &&
	    (mouse.x >= 0) &&
	    (mouse.x <= 2)
	) {
	    return true;
	}
	return false;
    }

    /// Draw a checkbox with label
    override public void draw() {
	CellAttributes checkboxColor;

	if (getAbsoluteActive()) {
	    checkboxColor = window.application.theme.getColor("tcheckbox.active");
	} else {
	    checkboxColor = window.application.theme.getColor("tcheckbox.inactive");
	}

	window.putCharXY(0, 0, '[', checkboxColor);
	if (checked) {
	    window.putCharXY(1, 0, GraphicsChars.CHECK, checkboxColor);
	} else {
	    window.putCharXY(1, 0, ' ', checkboxColor);
	}
	window.putCharXY(2, 0, ']', checkboxColor);
	window.putStrXY(4, 0, label, checkboxColor);

    }

    /**
     * Handle mouse checkbox presses.
     *
     * Params:
     *    event = mouse button down event
     */
    override protected void onMouseDown(TInputEvent event) {
	if ((mouseOnCheckbox(event)) && (event.mouse1)) {
	    // Switch state
	    checked = !checked;
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

	if (key == kbSpace) {
	    checked = !checked;
	    return;
	}

	// Pass to parent for the things we don't care about.
	super.onKeypress(event);
    }

}

// Functions -----------------------------------------------------------------
