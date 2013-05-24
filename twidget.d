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

// Convenience constructors
import tbutton;
import tlabel;
import tfield;

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
    public TWidget parent = null;

    /// Child widgets that this widget contains.
    public TWidget [] children;

    /// The currently active child widget that will receive keypress events.
    private TWidget activeChild = null;

    /// If true, this widget will receive events.
    public bool active = false;

    /// The window that this widget draws to.
    public TWindow window = null;

    /// Absolute X position of the top-left corner.
    public int x = 0;

    /// Absolute Y position of the top-left corner.
    public int y = 0;

    /// Width
    public uint width = 0;

    /// Height
    public uint height = 0;

    /// My tab order inside a window or containing widget
    private int tabOrder = 0;

    /// If true, this widget can be tabbed to or receive events
    protected bool enabled = true;

    /// If true, this widget has a cursor
    public bool hasCursor = false;

    /// Cursor column position in relative coordinates
    protected uint cursorX = 0;

    /// Cursor row position in relative coordinates
    protected uint cursorY = 0;

    /// Comparison operator sorts on tabOrder
    public override int opCmp(Object rhs) {
	auto that = cast(TWidget)rhs;
	if (!that) {
	    return 0;
	}
	return tabOrder - that.tabOrder;
    }

    /**
     * Returns the cursor X position.
     *
     * Returns:
     *    absolute screen column number for the cursor's X position
     */
    public uint getCursorAbsoluteX() {
	assert(hasCursor == true);
	return getAbsoluteX() + cursorX;
    }

    /**
     * Returns the cursor Y position.
     *
     * Returns:
     *    absolute screen row number for the cursor's Y position
     */
    public uint getCursorAbsoluteY() {
	assert(hasCursor == true);
	return getAbsoluteY() + cursorY;
    }

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
	    return parent.getAbsoluteX() + x + 1;
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
	    return parent.getAbsoluteY() + y + 1;
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

	int absoluteRightEdge = window.getAbsoluteX() + window.width;
	int absoluteBottomEdge = window.getAbsoluteY() + window.height;
	if (!cast(TWindow)this) {
	    absoluteRightEdge -= 1;
	    absoluteBottomEdge -= 1;
	}
	int myRightEdge = getAbsoluteX() + width;
	int myBottomEdge = getAbsoluteY() + height;
	if (getAbsoluteX() > absoluteRightEdge) {
	    // I am offscreen
	    window.screen.clipX = 0;
	} else if (myRightEdge > absoluteRightEdge) {
	    window.screen.clipX -= myRightEdge - absoluteRightEdge;
	}
	if (getAbsoluteY() > absoluteBottomEdge) {
	    // I am offscreen
	    window.screen.clipY = 0;
	} else if (myBottomEdge > absoluteBottomEdge) {
	    window.screen.clipY -= myBottomEdge - absoluteBottomEdge;
	}

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

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     */
    public this(TWidget parent) {
	this.parent = parent;
	this.window = parent.window;

	parent.addChild(this);
    }

    /**
     * Add a child widget to my list of children.  We set its tabOrder
     * to 0 and increment the tabOrder of all other children.
     *
     * Params:
     *    child = TWidget to add
     */
    private void addChild(TWidget child) {
	children ~= child;

	if (child.enabled) {
	    foreach (w; children) {
		w.active = false;
	    }
	    child.active = true;
	    activeChild = child;
	}
	for (auto i = 0; i < children.length; i++) {
	    children[i].tabOrder = i;
	}
    }

    /**
     * Switch the active child
     *
     * Params:
     *    child = TWidget to add
     */
    public void activate(TWidget child) {
	if (child !is activeChild) {
	    activeChild.active = false;
	    child.active = true;
	    activeChild = child;
	}
    }

    /**
     * Switch the active widget with the next in the tab order.
     *
     * Param:
     *    forward = switch to the next enabled widget in the list
     */
    private void switchWidget(bool forward) {
	// Only switch if there are multiple enabled widgets
	if ((children.length < 2) || (activeChild is null)) {
	    return;
	}

	int tabOrder = activeChild.tabOrder;
	activeChild.active = false;
	do {
	    if (forward) {
		tabOrder++;
	    } else {
		tabOrder--;
	    }
	    if (tabOrder < 0) {
		tabOrder = cast(int)children.length - 1;
	    } else if (tabOrder == children.length) {
		tabOrder = 0;
	    }
	    if (activeChild.tabOrder == tabOrder) {
		// We wrapped around
		break;
	    }
	} while (children[tabOrder].enabled == false);

	assert(children[tabOrder].enabled == true);

	children[tabOrder].active = true;
	activeChild = children[tabOrder];

	// Refresh
	window.application.repaint = true;
    }

    /**
     * Returns my active widget.
     *
     * Returns:
     *    widget that is active, or this if no children
     */
    public TWidget getActiveChild() {
	foreach (w; children) {
	    if (w.active) {
		return w.getActiveChild();
	    }
	}
	// No active children, return me
	return this;
    }

    /**
     * Method that subclasses can override to handle keystrokes.
     *
     * Params:
     *    event = keystroke event
     */
    protected void onKeypress(TInputEvent event) {
	// Defaults:
	//   tab / shift-tab - switch to next/previous widget
	//   right-arrow or down-arrow: same as tab
	//   left-arrow or up-arrow: same as shift-tab
	if ((event.key == kbTab) ||
	    (event.key == kbRight) ||
	    (event.key == kbDown)
	) {
	    parent.switchWidget(true);
	} else if ((event.key == kbShiftTab) ||
	    (event.key == kbLeft) ||
	    (event.key == kbUp)
	) {
	    parent.switchWidget(false);
	}
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
     * Method that subclasses can override to handle window/screen
     * resize events.
     *
     * Params:
     *    event = resize event
     */
    protected void onResize(TInputEvent event) {
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
	if (!enabled) {
	    // Discard event
	    return;
	}

	final switch (event.type) {

	case TInputEvent.Type.KEYPRESS:
	    onKeypress(event);
	    break;

	case TInputEvent.Type.MOUSE_DOWN:
	    onMouseDown(event);
	    break;

	case TInputEvent.Type.MOUSE_UP:
	    onMouseUp(event);
	    break;

	case TInputEvent.Type.MOUSE_MOTION:
	    onMouseMotion(event);
	    break;

	case TInputEvent.Type.RESIZE:
	    onResize(event);
	    break;
	}

	// Do nothing else
	return;
    }

    /**
     * Check if a mouse press/release event coordinate is contained in
     * this widget.
     *
     * Params:
     *    mouse = a mouse-based event
     */
    public bool mouseWouldHit(TInputEvent mouse) {
	assert(mouse.type != TInputEvent.Type.KEYPRESS);

	if (!enabled) {
	    return false;
	}

	if ((mouse.absoluteX >= getAbsoluteX()) &&
	    (mouse.absoluteX <  getAbsoluteX() + width) &&
	    (mouse.absoluteY >= getAbsoluteY()) &&
	    (mouse.absoluteY <  getAbsoluteY() + height)
	) {
	    return true;
	}
	return false;
    }

    /**
     * Convenience function to add a button to this container/window.
     *
     * Params:
     *    text = label on the button
     *    x = column relative to parent
     *    y = row relative to parent
     *    actionFn = function to call when button is pressed
     */
    public TButton addButton(dstring text, uint x, uint y,
	void function() actionFn) {
	return new TButton(this, text, x, y, actionFn);
    }

    /**
     * Convenience function to add a button to this container/window.
     *
     * Params:
     *    text = label on the button
     *    x = column relative to parent
     *    y = row relative to parent
     *    actionFn = function to call when button is pressed
     */
    public TButton addButton(dstring text, uint x, uint y,
	void delegate() actionFn) {
	return new TButton(this, text, x, y, actionFn);
    }

    /**
     * Convenience function to add a label to this container/window.
     *
     * Params:
     *    text = label
     *    x = column relative to parent
     *    y = row relative to parent
     *    colorKey = ColorTheme key color to use for foreground text.  Default is "tlabel"
     */
    public TLabel addLabel(dstring text, uint x, uint y,
	string colorKey = "tlabel") {
	return new TLabel(this, text, x, y, colorKey);
    }

    /**
     * Convenience function to add a field to this container/window.
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = visible text width.
     *    fixed = if true, the text cannot exceed the display width
     *    text = initial text, default is empty string
     */
    public TField addField(uint x, uint y, uint width, bool fixed,
	dstring text = "") {

	return new TField(this, x, y, width, fixed, text);
    }

}

// Functions -----------------------------------------------------------------
