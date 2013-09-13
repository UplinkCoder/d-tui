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
import tmenu;
import tscroll;
import twindow;

// Convenience constructors
import tbutton;
import tcheckbox;
import tdirlist;
import tfield;
import tlabel;
import tprogress;
import tradio;
import ttext;
import ttreeview;

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
    private bool _enabled = true;

    /// If true, this widget can be tabbed to or receive events
    @property public bool enabled() {
	return _enabled;
    }
    /// If true, this widget can be tabbed to or receive events
    @property public bool enabled(bool value) {
	_enabled = value;
	if (value == false) {
	    active = false;
	    // See if there are any active siblings to switch to
	    bool foundSibling = false;
	    if (parent !is null) {
		foreach (w; parent.children) {
		    if (w.enabled) {
			parent.activate(w);
			foundSibling = true;
			break;
		    }
		}
		if (!foundSibling) {
		    parent.activeChild = null;
		}
	    }
	}
	return _enabled;
    }

    /// If true, this widget has a cursor
    public bool hasCursor = false;

    /// Cursor column position in relative coordinates
    public uint cursorX = 0;

    /// Cursor row position in relative coordinates
    public uint cursorY = 0;

    /// Comparison operator sorts on tabOrder
    public override int opCmp(Object rhs) {
	auto that = cast(TWidget)rhs;
	if (!that) {
	    return 0;
	}
	return tabOrder - that.tabOrder;
    }

    /**
     * See if this widget should render with the active color.
     *
     * Returns:
     *    true if this widget is active and all of its parents are active.
     */
    public bool getAbsoluteActive() {
	if (parent is this) {
	    return active;
	}
	return (active && parent.getAbsoluteActive());
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
    public int getAbsoluteX() {
	assert (parent !is null);
	if (parent is this) {
	    return x;
	}
	if ((cast(TWindow)parent) && (!cast(TMenu)parent)) {
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
    public int getAbsoluteY() {
	assert (parent !is null);
	if (parent is this) {
	    return y;
	}
	if ((cast(TWindow)parent) && (!cast(TMenu)parent)) {
	    // Widgets on a TWindow have (0,0) as their top-left, but
	    // this is actually the TWindow's (1,1).
	    return parent.getAbsoluteY() + y + 1;
	}
	return parent.getAbsoluteY() + y;
    }

    /// Draw my specific widget.  When called, the screen rectangle I
    /// draw into is already setup (offset and clipping).
    public void draw() {
	// Default widget draws nothing.
    }

    /// Called by parent to render to TWindow.
    public final void drawChildren() {
	// Set my clipping rectangle
	assert (window !is null);
	assert (window.screen !is null);

	window.screen.clipRight = width;
	window.screen.clipBottom = height;

	int absoluteRightEdge = window.getAbsoluteX() + window.width;
	int absoluteBottomEdge = window.getAbsoluteY() + window.height;
	if ((!cast(TWindow)this) && (!cast(TVScroller)this)) {
	    absoluteRightEdge -= 1;
	}
	if ((!cast(TWindow)this) && (!cast(THScroller)this)) {
	    absoluteBottomEdge -= 1;
	}
	int myRightEdge = getAbsoluteX() + width;
	int myBottomEdge = getAbsoluteY() + height;
	if (getAbsoluteX() > absoluteRightEdge) {
	    // I am offscreen
	    window.screen.clipRight = 0;
	} else if (myRightEdge > absoluteRightEdge) {
	    window.screen.clipRight -= myRightEdge - absoluteRightEdge;
	}
	if (getAbsoluteY() > absoluteBottomEdge) {
	    // I am offscreen
	    window.screen.clipBottom = 0;
	} else if (myBottomEdge > absoluteBottomEdge) {
	    window.screen.clipBottom -= myBottomEdge - absoluteBottomEdge;
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
     *    child = TWidget to activate
     */
    public void activate(TWidget child) {
	assert(child.enabled);
	if (child !is activeChild) {
	    activeChild.active = false;
	    child.active = true;
	    activeChild = child;
	}
    }

    /**
     * Switch the active child
     *
     * Params:
     *    tabOrder = tabOrder of the child to activate.  If that child
     *    isn't enabled, then the next enabled child will be
     *    activated.
     */
    public void activate(ulong tabOrder) {
	if (activeChild is null) {
	    return;
	}
	TWidget child = null;
	foreach (w; children) {
	    if ((w.enabled == true) && (w.tabOrder >= tabOrder)) {
		child = w;
		break;
	    }
	}
	if ((child !is null) && (child !is activeChild)) {
	    activeChild.active = false;
	    assert(child.enabled);
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
    final public void switchWidget(bool forward) {

	// Only switch if there are multiple enabled widgets
	if ((children.length < 2) || (activeChild is null)) {
	    return;
	}

	int tabOrder = activeChild.tabOrder;
	do {
	    if (forward) {
		tabOrder++;
	    } else {
		tabOrder--;
	    }
	    if (tabOrder < 0) {

		// If at the end, pass the switch to my parent.
		if ((!forward) && (parent !is this)) {
		    parent.switchWidget(forward);
		    return;
		}

		tabOrder = cast(int)children.length - 1;
	    } else if (tabOrder == children.length) {
		// If at the end, pass the switch to my parent.
		if ((forward) && (parent !is this)) {
		    parent.switchWidget(forward);
		    return;
		}

		tabOrder = 0;
	    }
	    if (activeChild.tabOrder == tabOrder) {
		// We wrapped around
		break;
	    }
	} while (children[tabOrder].enabled == false);

	assert(children[tabOrder].enabled == true);

	activeChild.active = false;
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
    public void onKeypress(TKeypressEvent event) {

	if ((children.length == 0) ||
	    (cast(TTreeView)this) ||
	    (cast(TText)this)
	) {

	    // Defaults:
	    //   tab / shift-tab - switch to next/previous widget
	    //   right-arrow or down-arrow: same as tab
	    //   left-arrow or up-arrow: same as shift-tab
	    if ((event.key == kbTab) ||
		(event.key == kbRight) ||
		(event.key == kbDown)
	    ) {
		parent.switchWidget(true);
		return;
	    } else if ((event.key == kbShiftTab) ||
		(event.key == kbBackTab) ||
		(event.key == kbLeft) ||
		(event.key == kbUp)
	    ) {
		parent.switchWidget(false);
		return;
	    }
	}

	// Dispatch the keypress to an active widget
	foreach (w; children) {
	    if (w.active) {
		window.application.repaint = true;
		w.handleEvent(event);
		return;
	    }
	}
    }

    /**
     * Method that subclasses can override to handle mouse button
     * presses.
     *
     * Params:
     *    event = mouse button event
     */
    public void onMouseDown(TMouseEvent event) {
	// Default: do nothing, pass to children instead
	foreach (w; children) {
	    if (w.mouseWouldHit(event)) {
		// Dispatch to this child, also activate it
		activate(w);

		// Set x and y relative to the child's coordinates
		event.x = event.absoluteX - w.getAbsoluteX();
		event.y = event.absoluteY - w.getAbsoluteY();
		w.handleEvent(event);
		return;
	    }
	}
    }

    /**
     * Method that subclasses can override to handle mouse button
     * releases.
     *
     * Params:
     *    event = mouse button release event
     */
    public void onMouseUp(TMouseEvent event) {
	// Default: do nothing, pass to children instead
	foreach (w; children) {
	    if (w.mouseWouldHit(event)) {
		// Dispatch to this child, also activate it
		activate(w);

		// Set x and y relative to the child's coordinates
		event.x = event.absoluteX - w.getAbsoluteX();
		event.y = event.absoluteY - w.getAbsoluteY();
		w.handleEvent(event);
		return;
	    }
	}
    }

    /**
     * Method that subclasses can override to handle mouse movements.
     *
     * Params:
     *    event = mouse motion event
     */
    public void onMouseMotion(TMouseEvent event) {
	// Default: do nothing, pass it on to ALL of my children.  This way
	// the children can see the mouse "leaving" their area.
	foreach (w; children) {
	    // Set x and y relative to the child's coordinates
	    event.x = event.absoluteX - w.getAbsoluteX();
	    event.y = event.absoluteY - w.getAbsoluteY();
	    w.handleEvent(event);
	}
    }

    /**
     * Method that subclasses can override to handle window/screen
     * resize events.
     *
     * Params:
     *    event = resize event
     */
    public void onResize(TResizeEvent event) {
	// Default: do nothing, pass to children instead
	foreach (w; children) {
	    w.onResize(event);
	}
    }

    /**
     * Method that subclasses can override to handle menu or posted command
     * events.
     *
     * Params:
     *    event = command event
     */
    public void onCommand(TCommandEvent event) {
	// Default: do nothing, pass to children instead
	foreach (w; children) {
	    w.onCommand(event);
	}
    }

    /**
     * Method that subclasses can override to handle menu or posted menu
     * events.
     *
     * Params:
     *    menu = menu event
     */
    public void onMenu(TMenuEvent menu) {
	// Default: do nothing, pass to children instead
	foreach (w; children) {
	    w.onMenu(menu);
	}
    }

    /**
     * Method that subclasses can override to do processing when the UI is
     * idle.
     */
    public void onIdle() {
	// Default: do nothing, pass to children instead
	foreach (w; children) {
	    w.onIdle();
	}
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
	if (auto keypress = cast(TKeypressEvent)event) {
	    onKeypress(keypress);
	} else if (auto mouse = cast(TMouseEvent)event) {
	    final switch (mouse.type) {

	    case TMouseEvent.Type.MOUSE_DOWN:
		onMouseDown(mouse);
		break;

	    case TMouseEvent.Type.MOUSE_UP:
		onMouseUp(mouse);
		break;

	    case TMouseEvent.Type.MOUSE_MOTION:
		onMouseMotion(mouse);
		break;
	    }
	} else if (auto resize = cast(TResizeEvent)event) {
	    onResize(resize);
	} else if (auto cmd = cast(TCommandEvent)event) {
	    onCommand(cmd);
	} else if (auto cmd = cast(TMenuEvent)event) {
	    onMenu(cmd);
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
     *
     * Returns:
     *    whether or not a mouse click would be sent to this widget
     */
    public bool mouseWouldHit(TMouseEvent mouse) {

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
     *
     * Returns:
     *    the new button
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
     *
     * Returns:
     *    the new button
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
     *
     * Returns:
     *    the new label
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
     *    width = visible text width
     *    fixed = if true, the text cannot exceed the display width
     *    text = initial text, default is empty string
     *
     * Returns:
     *    the new field
     */
    public TField addField(uint x, uint y, uint width, bool fixed,
	dstring text = "") {

	return new TField(this, x, y, width, fixed, text);
    }

    /**
     * Convenience function to add a field to this container/window.
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = visible text width
     *    fixed = if true, the text cannot exceed the display width
     *    text = initial text
     *    actionFn = function to call when button is pressed
     *
     * Returns:
     *    the new field
     */
    public TField addField(uint x, uint y, uint width, bool fixed,
	dstring text, void delegate(bool) actionFn) {

	return new TField(this, x, y, width, fixed, text, actionFn);
    }

    /**
     * Convenience function to add a field to this container/window.
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = visible text width
     *    fixed = if true, the text cannot exceed the display width
     *    text = initial text
     *    actionFn = function to call when button is pressed
     *
     * Returns:
     *    the new field
     */
    public TField addField(uint x, uint y, uint width, bool fixed,
	dstring text, void function(bool) actionFn) {

	return new TField(this, x, y, width, fixed, text, actionFn);
    }

    /**
     * Convenience function to add a checkbox to this container/window.
     *
     * Params:
     *    x = column relative to parent
     *    y = row relative to parent
     *    label = label to display next to (right of) the checkbox
     *    checked = initial check state
     *
     * Returns:
     *    the new checkbox
     */
    public TCheckbox addCheckbox(uint x, uint y, dstring label,
	bool checked = false) {

	return new TCheckbox(this, x, y, label, checked);
    }

    /**
     * Convenience function to add a radio group to this container/window.
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    label = label to display on the group box
     *
     * Returns:
     *    the new radio group
     */
    public TRadioGroup addRadioGroup(uint x, uint y, dstring label) {
	return new TRadioGroup(this, x, y, label);
    }

    /**
     * Convenience function to add a resizable text area to this
     * container/window.
     *
     * Params:
     *    text = text on the screen
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = width of text area
     *    height = height of text area
     *    colorKey = ColorTheme key color to use for foreground text.  Default is "ttext"
     */
    public TText addText(dstring text, uint x, uint y, uint width, uint height,
	string colorKey = "ttext") {

	return new TText(this, text, x, y, width, height, colorKey);
    }

    /**
     * Convenience function to add a progress bar to this container/window.
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = width of progress bar
     *    value = initial value of percent complete
     */
    public TProgressBar addProgressBar(uint x, uint y, uint width, int value = 0) {
	return new TProgressBar(this, x, y, width, value = 0);
    }

    /**
     * Convenience function to add a tree view to this container/window.
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = width of tree view
     *    height = height of tree view
     */
    public TTreeView addTreeView(uint x, uint y, uint width, uint height) {
	return new TTreeView(this, x, y, width, height);
    }

    /**
     * Convenience function to add a tree view to this container/window.
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = width of tree view
     *    height = height of tree view
     *    actionFn = function to call when an item is selected
     */
    public TTreeView addTreeView(uint x, uint y, uint width, uint height,
	void delegate(TTreeItem) actionFn) {

	return new TTreeView(this, x, y, width, height, actionFn);
    }

    /**
     * Convenience function to add a tree view to this container/window.
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = width of tree view
     *    height = height of tree view
     *    actionFn = function to call when an item is selected
     */
    public TTreeView addTreeView(uint x, uint y, uint width, uint height,
	void function(TTreeItem) actionFn) {

	return new TTreeView(this, x, y, width, height, actionFn);
    }

    /**
     * Convenience function to add a directory list view to this
     * container/window.
     *
     * Params:
     *    path = directory path, must be a directory
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = width of text area
     *    height = height of text area
     */
    public TDirectoryList addDirectoryList(dstring path, uint x, uint y, uint width, uint height) {

	return new TDirectoryList(this, path, x, y, width, height);
    }

    /**
     * Convenience function to add a directory list view to this
     * container/window.
     *
     * Params:
     *    path = directory path, must be a directory
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = width of text area
     *    height = height of text area
     *    actionFn = function to call when an item is selected
     */
    public TDirectoryList addDirectoryList(dstring path, uint x, uint y, uint width, uint height,
	void function() actionFn) {

	return new TDirectoryList(this, path, x, y, width, height, actionFn);
    }

    /**
     * Convenience function to add a directory list view to this
     * container/window.
     *
     * Params:
     *    path = directory path, must be a directory
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = width of text area
     *    height = height of text area
     *    actionFn = function to call when an item is selected
     */
    public TDirectoryList addDirectoryList(dstring path, uint x, uint y, uint width, uint height,
	void delegate() actionFn) {

	return new TDirectoryList(this, path, x, y, width, height, actionFn);
    }

}

// Functions -----------------------------------------------------------------
