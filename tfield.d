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
    private TMouseEvent mouse;

    /// If true, only allow enough characters that will fit in the
    /// width.  If false, allow the field to scroll to the right.
    private bool fixed = false;

    /// Current editing position within text
    private uint position = 0;

    /// Beginning of visible portion
    private int windowStart = 0;

    /// If true, new characters are inserted at position
    private bool insertMode = true;

    /// The action to perform when the user presses Enter
    private void delegate(bool) actionDelegate;
    private void function(bool) actionFunction;

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = visible text width
     *    fixed = if true, the text cannot exceed the display width
     *    text = initial text, default is empty string
     */
    public this(TWidget parent, uint x, uint y, uint width, bool fixed,
	dstring text = "") {

	// Set parent and window
	super(parent);

	this.text = text;
	this.x = x;
	this.y = y;
	this.height = 1;
	this.width = width;
	this.fixed = fixed;

	this.hasCursor = true;
    }

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = visible text width
     *    fixed = if true, the text cannot exceed the display width
     *    text = initial text
     *    actionFn = function to call when button is pressed
     */
    public this(TWidget parent, uint x, uint y, uint width, bool fixed,
	dstring text, void delegate(bool) actionFn) {

	this.actionFunction = null;
	this.actionDelegate = actionFn;
	this(parent, x, y, width, fixed, text);
    }

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = visible text width
     *    fixed = if true, the text cannot exceed the display width
     *    text = initial text
     *    actionFn = function to call when button is pressed
     */
    public this(TWidget parent, uint x, uint y, uint width, bool fixed,
	dstring text, void function(bool) actionFn) {

	this.actionDelegate = null;
	this.actionFunction = actionFn;
	this(parent, x, y, width, fixed, text);
    }

    /// Returns true if the mouse is currently on the field
    private bool mouseOnField() {
	int rightEdge = width - 1;
	if ((mouse !is null) &&
	    (mouse.y == 0) &&
	    (mouse.x >= 0) &&
	    (mouse.x <= rightEdge)
	) {
	    return true;
	}
	return false;
    }

    /**
     * Dispatch to the action function/delegate.
     *
     * Params:
     *    enter = if true, the user pressed Enter, else this was an update to the text
     */
    private void dispatch(bool enter) {
	if (actionFunction !is null) {
	    actionFunction(enter);
	}
	if (actionDelegate !is null) {
	    actionDelegate(enter);
	}
    }

    /**
     * Append char to the end of the field
     *
     * Params:
     *    ch = char to append
     */
    private void appendChar(dchar ch) {
	// Append the LAST character
	text ~= ch;
	position++;

	assert(position == text.length);

	if (fixed == true) {
	    if (position == width) {
		position--;
	    }
	} else {
	    if ((position - windowStart) == width) {
		windowStart++;
	    }
	}
    }

    /**
     * Insert char somewhere in the middle of the field
     *
     * Params:
     *    ch = char to append
     */
    private void insertChar(dchar ch) {
	text = text[0 .. position] ~ ch ~ text[position .. $];
	position++;
	if ((position - windowStart) == width) {
	    assert(fixed == false);
	    windowStart++;
	}
    }

    /// Update the cursor position
    private void updateCursor() {
	if ((position > width) && (fixed == true)) {
	    cursorX = width;
	} else if ((position - windowStart == width) && (fixed == false)) {
		cursorX = width - 1;
	} else {
		cursorX = position - windowStart;
	}
    }

    /// Draw the field text and background
    override public void draw() {
	CellAttributes fieldColor;

	if (getAbsoluteActive()) {
	    fieldColor = window.application.theme.getColor("tfield.active");
	} else {
	    fieldColor = window.application.theme.getColor("tfield.inactive");
	}

	uint end = windowStart + width;
	if (end > text.length) {
	    end = cast(uint)text.length;
	}
	window.hLineXY(0, 0, width, GraphicsChars.HATCH, fieldColor);
	window.putStrXY(0, 0, text[windowStart .. end], fieldColor);

	// Fix the cursor, it will be rendered by TApplication.drawAll().
	updateCursor();
    }

    /**
     * Handle mouse button presses.
     *
     * Params:
     *    event = mouse button event
     */
    override protected void onMouseDown(TMouseEvent event) {
	mouse = event;

	if ((mouseOnField()) && (mouse.mouse1)) {
	    // Move cursor
	    uint deltaX = mouse.x - cursorX;
	    position += deltaX;
	    if (position > text.length) {
		position = cast(uint)text.length;
	    }
	    updateCursor();
	    return;
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
    override protected void onMouseMotion(TMouseEvent event) {
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
    override protected void onKeypress(TKeypressEvent event) {
	TKeypress key = event.key;

	if (key == kbLeft) {
	    if (position > 0) {
		position--;
	    }
	    if (fixed == false) {
		if ((position == windowStart) && (windowStart > 0)) {
		    windowStart--;
		}
	    }
	    return;
	}

	if (key == kbRight) {
	    if (position < text.length) {
		position++;
		if (fixed == true) {
		    if (position == width) {
			position--;
		    }
		} else {
		    if ((position - windowStart) == width) {
			windowStart++;
		    }
		}
	    }
	    return;
	}

	if (key == kbEnter) {
	    dispatch(true);
	    return;
	}

	if (key == kbIns) {
	    insertMode = !insertMode;
	    return;
	}
	if (key == kbHome) {
	    position = 0;
	    windowStart = 0;
	    return;
	}

	if (key == kbEnd) {
	    position = cast(uint)text.length;
	    if (fixed == true) {
		if (position >= width) {
		    position = cast(uint)text.length - 1;
		}
	    } else {
		windowStart = cast(uint)text.length - width + 1;
		if (windowStart < 0) {
		    windowStart = 0;
		}
	    }
	    return;
	}

	if (key == kbDel) {
	    if ((text.length > 0) && (position < text.length)) {
		text = text[0 .. position] ~ text[position + 1 .. $];
	    }
	    return;
	}

	if ((key == kbBackspace) || (key == kbBackspaceDel)) {
	    if (position > 0) {
		position--;
		text = text[0 .. position] ~ text[position + 1 .. $];
	    }
	    if (fixed == false) {
		if ((position == windowStart) &&
		    (windowStart > 0)
		) {
		    windowStart--;
		}
	    }
	    dispatch(false);
	    return;
	}

	if ((key.isKey == false) &&
	    (key.alt == false) &&
	    (key.ctrl == false)
	) {
	    // Plain old keystroke, process it
	    // stderr.writefln("position %d text.length %s width %d windowStart %d text %s", position, text.length, width, windowStart, text);

	    if ((position == text.length) && (text.length < width)) {
		// Append case
		appendChar(key.ch);
	    } else if ((position < text.length) && (text.length < width)) {
		// Overwrite or insert a character
		if (insertMode == false) {
		    // Replace character
		    text = text[0 .. position] ~ key.ch ~ text[position + 1 .. $];
		    position++;
		} else {
		    // Insert character
		    insertChar(key.ch);
		}
	    } else if ((position < text.length) && (text.length >= width)) {
		// Multiple cases here
		if ((fixed == true) && (insertMode == true)) {
		    // Buffer is full, do nothing
		} else if ((fixed == true) && (insertMode == false)) {
		    // Overwrite the last character, maybe move position
		    text = text[0 .. position] ~ key.ch ~ text[position + 1 .. $];
		    if (position < width - 1) {
			position++;
		    }
		} else if ((fixed == false) && (insertMode == false)) {
		    // Overwrite the last character, definitely move
		    // position
		    text = text[0 .. position] ~ key.ch ~ text[position + 1 .. $];
		    position++;
		} else {
		    if (position == text.length) {
			// Append this character
			appendChar(key.ch);
		    } else {
			// Insert this character
			insertChar(key.ch);
		    }
		}
	    } else {
		assert(fixed == false);

		// Append this character
		appendChar(key.ch);
	    }
	    dispatch(false);
	    return;
	}

	// Pass to parent for the things we don't care about.
	super.onKeypress(event);
    }

}

// Functions -----------------------------------------------------------------
