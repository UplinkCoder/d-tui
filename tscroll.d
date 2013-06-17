/**
 * D Text User Interface library - THScroller and TVScroller classes
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
 * TVScroller implements a simple vertical scroll bar.
 */
public class TVScroller : TWidget {

    /// Value that corresponds to being on the top edge of the scroll bar
    public int topValue = 0;

    /// Value that corresponds to being on the bottom edge of the scroll bar
    public int bottomValue = 100;

    /// Current value of the scroll
    public int value = 0;

    /// The increment for clicking on an arrow
    public int smallChange = 1;

    /// The increment for clicking in the bar between the box and an arrow
    public int bigChange = 20;

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    height = height of scroll bar
     */
    public this(TWidget parent, uint x, uint y, uint height) {

	// Set parent and window
	super(parent);

	this.x = x;
	this.y = y;
	this.height = height;
	this.width = 1;
    }

    /**
     * Compute the position of the scroll box (a.k.a. grip, thumb)
     *
     * Returns:
     *    Y position of the box, between 1 and height - 2
     */
    private uint boxPosition() {
	return (height - 3) * (value - topValue) / (bottomValue - topValue) + 1;
    }

    /// Draw a static scroll bar
    override public void draw() {
	CellAttributes color = window.application.theme.getColor("tscroller");
	window.putCharXY(0, 0, cp437_chars[0x1E], color);
	window.putCharXY(0, height - 1, cp437_chars[0x1F], color);

	// Place the box
	if (bottomValue > topValue) {
	    window.vLineXY(0, 1, height - 2, cp437_chars[0xB1], color);
	    window.putCharXY(0, boxPosition(), GraphicsChars.BOX, color);
	} else {
	    window.vLineXY(0, 1, height - 2, GraphicsChars.HATCH, color);
	}
	
    }

    /**
     * Handle mouse button releases.
     *
     * Params:
     *    mouse = mouse button release event
     */
    override protected void onMouseUp(TMouseEvent mouse) {
	if ((mouse.x == 0) &&
	    (mouse.y == 0)) {
	    // Clicked on the top arrow
	    value -= smallChange;
	    if (value < topValue) {
		value = topValue;
	    }
	    return;
	}

	if ((mouse.x == 0) &&
	    (mouse.y == height - 1)) {
	    // Clicked on the bottom arrow
	    value += smallChange;
	    if (value > bottomValue) {
		value = bottomValue;
	    }
	    return;
	}

	if ((mouse.x == 0) &&
	    (mouse.y > 0) &&
	    (mouse.y < boxPosition())) {
	    // Clicked between the top arrow and the box
	    value -= bigChange;
	    if (value < topValue) {
		value = topValue;
	    }
	    return;
	}

	if ((mouse.x == 0) &&
	    (mouse.y > boxPosition()) &&
	    (mouse.y < height - 1)) {
	    // Clicked between the box and the bottom arrow
	    value += bigChange;
	    if (value > bottomValue) {
		value = bottomValue;
	    }
	    return;
	}
    }

}

// Functions -----------------------------------------------------------------
