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

module tui.tscroll;

// Description ---------------------------------------------------------------

// Imports -------------------------------------------------------------------

import std.utf;
import tui.base;
import tui.codepage;
import tui.twidget;

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

    /// When true, the user is dragging the scroll box
    private bool inScroll = false;

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
	CellAttributes arrowColor = window.application.theme.getColor("tscroller.arrows");
	CellAttributes barColor = window.application.theme.getColor("tscroller.bar");
	window.putCharXY(0, 0, cp437_chars[0x1E], arrowColor);
	window.putCharXY(0, height - 1, cp437_chars[0x1F], arrowColor);

	// Place the box
	if (bottomValue > topValue) {
	    window.vLineXY(0, 1, height - 2, cp437_chars[0xB1], barColor);
	    window.putCharXY(0, boxPosition(), GraphicsChars.BOX, arrowColor);
	} else {
	    window.vLineXY(0, 1, height - 2, GraphicsChars.HATCH, barColor);
	}

    }

    /**
     * Perform a small step change up.
     */
    public void decrement() {
	if (bottomValue == topValue) {
	    return;
	}
	value -= smallChange;
	if (value < topValue) {
	    value = topValue;
	}
    }

    /**
     * Perform a small step change down.
     */
    public void increment() {
	if (bottomValue == topValue) {
	    return;
	}
	value += smallChange;
	if (value > bottomValue) {
	    value = bottomValue;
	}
    }

    /**
     * Perform a big step change up.
     */
    public void bigDecrement() {
	if (bottomValue == topValue) {
	    return;
	}
	value -= bigChange;
	if (value < topValue) {
	    value = topValue;
	}
    }

    /**
     * Perform a big step change down.
     */
    public void bigIncrement() {
	if (bottomValue == topValue) {
	    return;
	}
	value += bigChange;
	if (value > bottomValue) {
	    value = bottomValue;
	}
    }

    /**
     * Go to the top edge of the scroller.
     */
    public void toTop() {
	value = topValue;
    }

    /**
     * Go to the bottom edge of the scroller.
     */
    public void toBottom() {
	value = bottomValue;
    }

    /**
     * Handle mouse button releases.
     *
     * Params:
     *    mouse = mouse button release event
     */
    override protected void onMouseUp(TMouseEvent mouse) {
	if (bottomValue == topValue) {
	    return;
	}

	if (inScroll) {
	    inScroll = false;
	    return;
	}

	if ((mouse.x == 0) &&
	    (mouse.y == 0)) {
	    // Clicked on the top arrow
	    decrement();
	    return;
	}

	if ((mouse.x == 0) &&
	    (mouse.y == height - 1)) {
	    // Clicked on the bottom arrow
	    increment();
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

    /**
     * Handle mouse button presses.
     *
     * Params:
     *    mouse = mouse button release event
     */
    override protected void onMouseMotion(TMouseEvent mouse) {
	if (bottomValue == topValue) {
	    return;
	}

	if ((mouse.mouse1) &&
	    (inScroll) &&
	    (mouse.y > 0) &&
	    (mouse.y < height - 1)
	) {
	    // Recompute value based on new box position
	    value = (bottomValue - topValue) * (mouse.y) / (height - 3) + topValue;
	    return;
	}

	inScroll = false;
    }

    /**
     * Handle mouse press events.
     *
     * Params:
     *    mouse = mouse button press event
     */
    override protected void onMouseDown(TMouseEvent mouse) {
	if (bottomValue == topValue) {
	    return;
	}

	if ((mouse.x == 0) &&
	    (mouse.y == boxPosition())) {
	    inScroll = true;
	    return;
	}
    }

}

/**
 * TVScroller implements a simple horizontal scroll bar.
 */
public class THScroller : TWidget {

    /// Value that corresponds to being on the left edge of the scroll bar
    public int leftValue = 0;

    /// Value that corresponds to being on the right edge of the scroll bar
    public int rightValue = 100;

    /// Current value of the scroll
    public int value = 0;

    /// The increment for clicking on an arrow
    public int smallChange = 1;

    /// The increment for clicking in the bar between the box and an arrow
    public int bigChange = 20;

    /// When true, the user is dragging the scroll box
    private bool inScroll = false;

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = height of scroll bar
     */
    public this(TWidget parent, uint x, uint y, uint width) {

	// Set parent and window
	super(parent);

	this.x = x;
	this.y = y;
	this.height = 1;
	this.width = width;
    }

    /**
     * Compute the position of the scroll box (a.k.a. grip, thumb)
     *
     * Returns:
     *    Y position of the box, between 1 and width - 2
     */
    private uint boxPosition() {
	return (width - 3) * (value - leftValue) / (rightValue - leftValue) + 1;
    }

    /// Draw a static scroll bar
    override public void draw() {
	CellAttributes arrowColor = window.application.theme.getColor("tscroller.arrows");
	CellAttributes barColor = window.application.theme.getColor("tscroller.bar");
	window.putCharXY(0, 0, cp437_chars[0x11], arrowColor);
	window.putCharXY(width - 1, 0, cp437_chars[0x10], arrowColor);

	// Place the box
	if (rightValue > leftValue) {
	    window.hLineXY(1, 0, width - 2, cp437_chars[0xB1], barColor);
	    window.putCharXY(boxPosition(), 0, GraphicsChars.BOX, arrowColor);
	} else {
	    window.hLineXY(1, 0, width - 2, GraphicsChars.HATCH, barColor);
	}

    }

    /**
     * Perform a small step change left.
     */
    public void decrement() {
	if (leftValue == rightValue) {
	    return;
	}
	value -= smallChange;
	if (value < leftValue) {
	    value = leftValue;
	}
    }

    /**
     * Perform a small step change right.
     */
    public void increment() {
	if (leftValue == rightValue) {
	    return;
	}
	value += smallChange;
	if (value > rightValue) {
	    value = rightValue;
	}
    }

    /**
     * Handle mouse button releases.
     *
     * Params:
     *    mouse = mouse button release event
     */
    override protected void onMouseUp(TMouseEvent mouse) {

	if (inScroll) {
	    inScroll = false;
	    return;
	}

	if (rightValue == leftValue) {
	    return;
	}

	if ((mouse.x == 0) &&
	    (mouse.y == 0)) {
	    // Clicked on the left arrow
	    decrement();
	    return;
	}

	if ((mouse.y == 0) &&
	    (mouse.x == width - 1)) {
	    // Clicked on the right arrow
	    increment();
	    return;
	}

	if ((mouse.y == 0) &&
	    (mouse.x > 0) &&
	    (mouse.x < boxPosition())) {
	    // Clicked between the left arrow and the box
	    value -= bigChange;
	    if (value < leftValue) {
		value = leftValue;
	    }
	    return;
	}

	if ((mouse.y == 0) &&
	    (mouse.x > boxPosition()) &&
	    (mouse.x < width - 1)) {
	    // Clicked between the box and the right arrow
	    value += bigChange;
	    if (value > rightValue) {
		value = rightValue;
	    }
	    return;
	}
    }

    /**
     * Handle mouse button presses.
     *
     * Params:
     *    mouse = mouse button release event
     */
    override protected void onMouseMotion(TMouseEvent mouse) {

	if (rightValue == leftValue) {
	    inScroll = false;
	    return;
	}

	if ((mouse.mouse1) &&
	    (inScroll) &&
	    (mouse.x > 0) &&
	    (mouse.x < width - 1)
	) {
	    // Recompute value based on new box position
	    value = (rightValue - leftValue) * (mouse.x) / (width - 3) + leftValue;
	    return;
	}
	inScroll = false;
    }

    /**
     * Handle mouse press events.
     *
     * Params:
     *    mouse = mouse button press event
     */
    override protected void onMouseDown(TMouseEvent mouse) {
	if (rightValue == leftValue) {
	    inScroll = false;
	    return;
	}

	if ((mouse.y == 0) &&
	    (mouse.x == boxPosition())) {
	    inScroll = true;
	    return;
	}

    }

}

// Functions -----------------------------------------------------------------
