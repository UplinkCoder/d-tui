/**
 * D Text User Interface library - TWidget class
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

import base;
import twindow;

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * TWidget is the base class of all objects that can be drawn on
 * screen or handle user input events.
 */
public class TWidget {

    /// Every widget has a parent widget that it may be "contained"
    /// in.  For example, a TWindow might contain several TTextFields,
    /// or a TComboBox may contain a TScrollBar.
    protected TWidget parent = null;

    /// Child widgets that this widget contains.
    protected TWidget [] children;

    /// The window that this widget draws to.
    protected TWindow window = null;

    /// Absolute X position of the top-left corner.
    public int x = 0;

    /// Absolute Y position of the top-left corner.
    public int y = 0;

    /// Width
    public uint width = 0;

    /// Height
    public uint height = 0;

    /**
     * Compute my absolute X position as the sum of my X plus all my
     * parent's X's.
     *
     * Returns:
     *    absolute screen column number for my X position
     */
    public uint getAbsoluteX() {
	assert (parent !is null);
	if (parent is this) {
	    return x;
	}
	if (cast(TWindow)parent) {
	    // Widgets on a TWindow have (0,0) as their top-left, but
	    // this is actually the TWindow's (1,1).
	    return parent.getAbsoluteX() + 1;
	}
	return parent.getAbsoluteX() + x;
    }

    /**
     * Compute my absolute Y position as the sum of my Y plus all my
     * parent's Y's.
     *
     * Returns:
     *    absolute screen row number for my Y position
     */
    public uint getAbsoluteY() {
	assert (parent !is null);
	if (parent is this) {
	    return y;
	}
	if (cast(TWindow)parent) {
	    // Widgets on a TWindow have (0,0) as their top-left, but
	    // this is actually the TWindow's (1,1).
	    return parent.getAbsoluteY() + 1;
	}
	return parent.getAbsoluteY() + y;
    }

    /// Draw my specific widget.  When called, the screen rectangle I
    /// draw into is already setup (offset and clipping).
    protected void draw() {
	// Default widget draws nothing.
    }

    /// Called by parent to render to TWindow.
    public final void drawChildren() {
	// Set my clipping rectangle
	assert (window !is null);
	assert (window.screen !is null);

	window.screen.clipX = width;
	window.screen.clipY = height;

	// Set my offset
	window.screen.offsetX = getAbsoluteX();
	window.screen.offsetY = getAbsoluteY();

	// Draw me
	draw();

	// Continue down the chain
	foreach (w; children) {
	    w.drawChildren();
	}
    }

    /// TWindow needs this constructor.
    protected this() {}

    /// Public constructor.
    public this(TWidget parent) {
	this.parent = parent;
	this.window = parent.window;
    }

    /**
     * Method that subclasses can override to handle keystrokes.
     *
     * Params:
     *    event = keystroke event
     */
    protected void onKeypress(TInputEvent event) {
	// Default: do nothing
    }

    /**
     * Method that subclasses can override to handle mouse button
     * presses.
     *
     * Params:
     *    event = mouse button event
     */
    protected void onMouseDown(TInputEvent event) {
	// Default: do nothing
    }

    /**
     * Method that subclasses can override to handle mouse button
     * releases.
     *
     * Params:
     *    event = mouse button release event
     */
    protected void onMouseUp(TInputEvent event) {
	// Default: do nothing
    }

    /**
     * Method that subclasses can override to handle mouse movements.
     *
     * Params:
     *    event = mouse motion event
     */
    protected void onMouseMotion(TInputEvent event) {
	// Default: do nothing
    }

    /**
     * Consume event.  Subclasses that want to intercept all events
     * in one go can override this method.
     *
     * Params:
     *    event = keyboard or mouse event
     */
    public void handleEvent(TInputEvent event) {
	if (event.type == TInputEvent.KEYPRESS) {
	    onKeypress(event);
	}

	if (event.type == TInputEvent.MOUSE_DOWN) {
	    onMouseDown(event);
	}

	if (event.type == TInputEvent.MOUSE_UP) {
	    onMouseUp(event);
	}

	if (event.type == TInputEvent.MOUSE_MOTION) {
	    onMouseMotion(event);
	}
	// Do nothing
	return;
    }

}

// Functions -----------------------------------------------------------------
