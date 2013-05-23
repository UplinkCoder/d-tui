/**
 * D Text User Interface library - TField class
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
 * TField implements an editable text field.
 */
public class TField : TWidget {

    /// Field text
    public dstring text = "";

    /// Remember mouse state
    private TInputEvent mouse;

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = visible text width.
     *    text = initial text, default is empty string
     */
    public this(TWidget parent, uint x, uint y, uint width, dstring text = "") {
	// Set parent and window
	super(parent);

	this.text = text;
	this.x = x;
	this.y = y;
	this.height = 2;
	this.width = width;
    }

    /// Returns true if the mouse is currently on the field
    private bool mouseOnField() {
	int rightEdge = width - 1;
	if ((mouse !is null) &&
	    (mouse.y == 0) &&
	    (mouse.x >= 0) &&
	    (mouse.x < rightEdge)
	) {
	    return true;
	}
	return false;
    }

    /// Draw a field with a shadow
    override public void draw() {
	CellAttributes fieldColor;

	if (active) {
	    fieldColor = window.application.theme.getColor("tfield.active");
	} else {
	    fieldColor = window.application.theme.getColor("tfield.inactive");
	}

	window.hLineXY(0, 0, width, GraphicsChars.HATCH, fieldColor);
	window.putStrXY(0, 0, text, fieldColor);
    }

    /**
     * Handle mouse field presses.
     *
     * Params:
     *    event = mouse field event
     */
    override protected void onMouseDown(TInputEvent event) {
	mouse = event;

	if ((mouseOnField()) && (mouse.mouse1)) {
	    // Move cursor
	    // TODO
	}
    }

    /**
     * Handle mouse field releases.
     *
     * Params:
     *    event = mouse field release event
     */
    override protected void onMouseUp(TInputEvent event) {
	mouse = event;

	if ((mouseOnField()) && (mouse.mouse1)) {
	    // TODO: drag and drop
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

	if ((mouseOnField()) && (mouse.mouse1)) {
	    // TODO: drag and drop
	}
    }

    /**
     * Handle keystrokes.
     *
     * Params:
     *    event = keystroke event
     */
    override protected void onKeypress(TInputEvent event) {
	// TODO: arrow keys, home/end, backspace


	// Pass to parent for the things we don't care about.
	super.onKeypress(event);
    }

}

// Functions -----------------------------------------------------------------
