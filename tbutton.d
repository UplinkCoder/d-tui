/**
 * D Text User Interface library - TButton class
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
 * TButton implements a simple button.
 */
public class TButton : TWidget {

    /// Button text
    private dstring text = "";

    /// Remember mouse state
    private TInputEvent mouse;

    /// True when the button is being pressed
    private bool inButtonPress = false;

    /// Public constructor.
    public this(TWidget parent, dstring text, uint x, uint y) {

	// Set parent and window
	this.parent = parent;
	this.window = parent.window;
	parent.children ~= this;

	this.text = text;
	this.x = x;
	this.y = y;
	this.height = 2;
	this.width = cast(uint)(codeLength!dchar(text) + 3);
    }

    /// Returns true if the mouse is currently on the button
    private bool mouseOnButton() {
	if ((mouse !is null) &&
	    (mouse.y == y) &&
	    (mouse.x >= x) &&
	    (mouse.x < x + width)
	) {
	    return true;
	}
	return false;
    }

    /// Draw a button with a shadow
    override public void draw() {
	CellAttributes buttonColor = window.application.theme.getColor("tbutton.inactive");
	CellAttributes shadowColor = window.application.theme.getColor("tbutton.shadow");

	if (inButtonPress) {
	    window.putCharXY(1, 0, ' ', buttonColor);
	    window.putStrXY(2, 0, text, buttonColor);
	    window.putCharXY(width - 1, 0, ' ', buttonColor);
	} else {
	    window.putCharXY(0, 0, ' ', buttonColor);
	    window.putStrXY(1, 0, text, buttonColor);
	    window.putCharXY(width - 2, 0, ' ', buttonColor);

	    window.putCharXY(width - 1, 0, cp437_chars[0xDC], shadowColor);
	    window.hLineXY(1, 1, width, cp437_chars[0xDF], shadowColor);
	}
    }

    /**
     * Handle mouse button presses.
     *
     * Params:
     *    event = mouse button event
     */
    override protected void onMouseDown(TInputEvent event) {
	mouse = event;

	if (mouseOnButton()) {
	    // Begin button press
	    inButtonPress = true;
	}
    }

    /**
     * Handle mouse button releases.
     *
     * Params:
     *    event = mouse button release event
     */
    override protected void onMouseUp(TInputEvent event) {
	mouse = event;

	if ((inButtonPress == true) && (mouse.mouse1)) {
	    inButtonPress = false;
	    // Dispatch the event
	    // TODO
	}

    }

    /**
     * Handle mouse movements.
     *
     * Params:
     *    event = mouse motion event
     */
    override protected void onMouseMotion(TInputEvent event) {
	mouse = event;

	if (!mouseOnButton()) {
	    inButtonPress = false;
	}
    }

}

// Functions -----------------------------------------------------------------
