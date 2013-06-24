/**
 * D Text User Interface library - TEditor class
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

import std.string;
import std.utf;
import base;
import codepage;
import twidget;
import tscroll;

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * TEditor implements an editable text area.
 */
public class TEditor : TWidget {

    /// Lines of text being edited
    private dstring [] lines;

    /// Vertical scrollbar
    private TVScroller vScroller;

    /// Horizontal scrollbar
    private THScroller hScroller;

    /**
     * Get the maximum width of the lines with text
     *
     * Returns:
     *    the maximum width
     */
    private uint getLineWidth() {
	uint maxLineWidth = 0;
	foreach (line; lines) {
	    if (line.length > maxLineWidth) {
		maxLineWidth = cast(uint)line.length;
	    }
	}
	return maxLineWidth;
    }

    /**
     * Resize text and scrollbars for a new width/height
     */
    public void reflow() {
	// Start at the top
	if (vScroller is null) {
	    vScroller = new TVScroller(this, width - 1, 0, height - 1);
	} else {
	    vScroller.x = width - 1;
	    vScroller.height = height - 1;
	}
	vScroller.bottomValue = cast(int)lines.length - height - 1;
	vScroller.topValue = 0;
	vScroller.value = 0;
	if (vScroller.bottomValue < 0) {
	    vScroller.bottomValue = 0;
	}
	vScroller.bigChange = height - 1;

	// Start at the left
	if (hScroller is null) {
	    hScroller = new THScroller(this, 0, height - 1, width - 1);
	} else {
	    hScroller.y = height - 1;
	    hScroller.width = width - 1;
	}
	hScroller.rightValue = getLineWidth() - width + 1;
	hScroller.leftValue = 0;
	hScroller.value = 0;
	if (hScroller.rightValue < 0) {
	    hScroller.rightValue = 0;
	}
	hScroller.bigChange = width - 1;
    }

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = width of text area
     *    height = height of text area
     *    colorKey = ColorTheme key color to use for foreground text.  Default is "ttext"
     */
    public this(TWidget parent, uint x, uint y, uint width,
	uint height) {

	// Set parent and window
	super(parent);

	this.x = x;
	this.y = y;
	this.width = width;
	this.height = height;
	reflow();
    }

    /// Draw a static text
    override public void draw() {
	CellAttributes color = window.application.theme.getColor("teditor");
	uint begin = vScroller.value;
	uint topY = 0;
	for (auto i = begin; i < lines.length; i++) {
	    dstring line = lines[i];
	    if (hScroller.value < line.length) {
		line = line[hScroller.value .. $];
	    } else {
		line = "";
	    }
	    window.putStrXY(0, topY,
		leftJustify!(dstring)(line, this.width - 1), color);
	    topY++;
	    if (topY == height - 1) {
		break;
	    }
	}
    }

    /**
     * Handle mouse press events.
     *
     * Params:
     *    mouse = mouse button press event
     */
    override protected void onMouseDown(TMouseEvent mouse) {
	if (mouse.mouseWheelUp) {
	    vScroller.decrement();
	    return;
	}
	if (mouse.mouseWheelDown) {
	    vScroller.increment();
	    return;
	}

	// Pass to children
	super.onMouseDown(mouse);
    }

    /**
     * Handle mouse release events.
     *
     * Params:
     *    mouse = mouse button release event
     */
    override protected void onMouseUp(TMouseEvent mouse) {
	// TODO: reposition cursor

    }

    /**
     * Handle keystrokes.
     *
     * Params:
     *    event = keystroke event
     */
    override protected void onKeypress(TKeypressEvent keypress) {
	TKeypress key = keypress.key;
	if (key == kbLeft) {

	} else if (key == kbRight) {

	} else if (key == kbUp) {

	} else if (key == kbDown) {

	} else if (key == kbPgUp) {
	    vScroller.bigDecrement();
	} else if (key == kbPgDn) {
	    vScroller.bigIncrement();
	} else if (key == kbHome) {
	    vScroller.toTop();
	} else if (key == kbEnd) {
	    vScroller.toBottom();
	} else {
	    // Pass other keys (tab etc.) on
	    super.onKeypress(keypress);
	}
    }

}

// Functions -----------------------------------------------------------------
