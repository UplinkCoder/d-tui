/**
 * D Text User Interface library - TRadioButton and TRadioGroup classes
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

module tui.tradio;

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
 * TRadioGroup is a collection of TRadioButtons with a box and label.
 */
public class TRadioGroup : TWidget {

    /// Label for this radio button group
    private dstring label;

    /// Only one of my children can be selected
    private TRadioButton selectedButton = null;

    /**
     * Get the radio button ID that was selected.
     *
     * Returns:
     *    ID of the selected button, or 0 if no button is selected
     */
    public uint getSelected() {
	if (selectedButton is null) {
	    return 0;
	}
	return selectedButton.id;
    }

    /**
     * Set the new selected radio button.
     *
     * Params:
     *    button = new button that became selected
     */
    private void setSelected(TRadioButton button) {
	assert(button.selected == true);
	if (selectedButton !is null) {
	    selectedButton.selected = false;
	}
	selectedButton = button;
    }

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    label = label to display on the group box
     */
    public this(TWidget parent, uint x, uint y, dstring label) {

	// Set parent and window
	super(parent);

	this.x = x;
	this.y = y;
	this.height = 2;
	this.label = label;
	this.width = cast(uint)label.length + 4;
    }

    /// Draw a radio button with label
    override public void draw() {
	CellAttributes radioGroupColor;

	if (getAbsoluteActive()) {
	    radioGroupColor = window.application.theme.getColor("tradiogroup.active");
	} else {
	    radioGroupColor = window.application.theme.getColor("tradiogroup.inactive");
	}

	window.drawBox(0, 0, width, height, radioGroupColor, radioGroupColor, 3, false);

	window.hLineXY(1, 0, cast(uint)label.length + 2, ' ', radioGroupColor);
	window.putStrXY(2, 0, label, radioGroupColor);
    }

    /**
     * Convenience function to add a radio button to this group.
     *
     * Params:
     *    label = label to display next to (right of) the radiobutton
     *
     * Returns:
     *    the new radio button
     */
    public TRadioButton addRadioButton(dstring label) {
	uint buttonX = 1;
	uint buttonY = cast(uint)children.length + 1;
	if (label.length + 4 > width) {
	    width = cast(uint)label.length + 7;
	}
	height = cast(uint)children.length + 3;
	return new TRadioButton(this, buttonX, buttonY, label,
	    cast(uint)children.length + 1);
    }

}

/**
 * TRadioButton implements a selectable radio button.
 */
public class TRadioButton : TWidget {

    /// RadioButton state, true means selected
    public bool selected = false;

    /// Label for this radio button
    private dstring label;

    /// ID for this radio button.  Buttons start counting at 1 in the
    /// RadioGroup.
    private uint id;

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    label = label to display next to (right of) the radiobutton
     *    id = ID for this radio button
     */
    public this(TRadioGroup parent, uint x, uint y, dstring label, uint id) {

	// Set parent and window
	super(parent);

	this.x = x;
	this.y = y;
	this.height = 1;
	this.label = label;
	this.width = cast(uint)label.length + 4;
	this.id = id;

	this.hasCursor = true;
	this.cursorX = 1;
    }

    /**
     * Returns true if the mouse is currently on the radio button
     *
     * Params:
     *    mouse = mouse event
     */
    private bool mouseOnRadioButton(TMouseEvent mouse) {
	if ((mouse !is null) &&
	    (mouse.y == 0) &&
	    (mouse.x >= 0) &&
	    (mouse.x <= 2)
	) {
	    return true;
	}
	return false;
    }

    /// Draw a radio button with label
    override public void draw() {
	CellAttributes radioButtonColor;

	if (getAbsoluteActive()) {
	    radioButtonColor = window.application.theme.getColor("tradiobutton.active");
	} else {
	    radioButtonColor = window.application.theme.getColor("tradiobutton.inactive");
	}

	window.putCharXY(0, 0, '(', radioButtonColor);
	if (selected) {
	    window.putCharXY(1, 0, cp437_chars[0x07], radioButtonColor);
	} else {
	    window.putCharXY(1, 0, ' ', radioButtonColor);
	}
	window.putCharXY(2, 0, ')', radioButtonColor);
	window.putStrXY(4, 0, label, radioButtonColor);
    }

    /**
     * Handle mouse button presses.
     *
     * Params:
     *    event = mouse button press event
     */
    override protected void onMouseDown(TMouseEvent event) {
	if ((mouseOnRadioButton(event)) && (event.mouse1)) {
	    // Switch state
	    selected = !selected;
	    if (selected) {
		(cast(TRadioGroup)parent).setSelected(this);
	    }
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

	if (key == kbSpace) {
	    selected = !selected;
	    if (selected) {
		(cast(TRadioGroup)parent).setSelected(this);
	    }
	    return;
	}

	// Pass to parent for the things we don't care about.
	super.onKeypress(event);
    }

}

// Functions -----------------------------------------------------------------
