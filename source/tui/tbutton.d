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

module tui.tbutton;

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
 * TButton implements a simple button.
 */
public class TButton : TWidget {

    /// The shortcut and button text
    public MnemonicString mnemonic;

    /// Remember mouse state
    private TMouseEvent mouse;

    /// True when the button is being pressed
    private bool inButtonPress = false;

    /// The action to perform on button press
    private void delegate() actionDelegate;
    private void function() actionFunction;

    /**
     * Private constructor
     *
     * Params:
     *    parent = parent widget
     *    text = label on the button
     *    x = column relative to parent
     *    y = row relative to parent
     */
    private this(TWidget parent, dstring text, uint x, uint y) {
	// Set parent and window
	super(parent);

	mnemonic = new MnemonicString(text);

	this.x = x;
	this.y = y;
	this.height = 2;
	this.width = cast(uint)(mnemonic.rawLabel.length) + 3;
    }

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    text = label on the button
     *    x = column relative to parent
     *    y = row relative to parent
     *    actionFn = function to call when button is pressed
     */
    public this(TWidget parent, dstring text, uint x, uint y,
	void delegate() actionFn) {

	this.actionFunction = null;
	this.actionDelegate = actionFn;
	this(parent, text, x, y);
    }

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    text = label on the button
     *    x = column relative to parent
     *    y = row relative to parent
     *    actionFn = function to call when button is pressed
     */
    public this(TWidget parent, dstring text, uint x, uint y,
	void function() actionFn) {

	this.actionFunction = actionFn;
	this.actionDelegate = null;
	this(parent, text, x, y);
    }

    /// Returns true if the mouse is currently on the button
    private bool mouseOnButton() {
	int rightEdge = width - 1;
	if (inButtonPress) {
	    rightEdge++;
	}
	if ((mouse !is null) &&
	    (mouse.y == 0) &&
	    (mouse.x >= 0) &&
	    (mouse.x < rightEdge)
	) {
	    return true;
	}
	return false;
    }

    /// Draw a button with a shadow
    override public void draw() {
	CellAttributes buttonColor;
	CellAttributes menuMnemonicColor;
	CellAttributes shadowColor = new CellAttributes();
	shadowColor.setTo(window.getBackground());
	shadowColor.foreColor = Color.BLACK;
	shadowColor.bold = false;

	if (!enabled) {
	    buttonColor = window.application.theme.getColor("tbutton.disabled");
	    menuMnemonicColor = window.application.theme.getColor("tbutton.disabled");
	} else if (getAbsoluteActive()) {
	    buttonColor = window.application.theme.getColor("tbutton.active");
	    menuMnemonicColor = window.application.theme.getColor("tbutton.mnemonic.highlighted");
	} else {
	    buttonColor = window.application.theme.getColor("tbutton.inactive");
	    menuMnemonicColor = window.application.theme.getColor("tbutton.mnemonic");
	}

	if (inButtonPress) {
	    window.putCharXY(1, 0, ' ', buttonColor);
	    window.putStrXY(2, 0, mnemonic.rawLabel, buttonColor);
	    window.putCharXY(width - 1, 0, ' ', buttonColor);
	} else {
	    window.putCharXY(0, 0, ' ', buttonColor);
	    window.putStrXY(1, 0, mnemonic.rawLabel, buttonColor);
	    window.putCharXY(width - 2, 0, ' ', buttonColor);

	    window.putCharXY(width - 1, 0, cp437_chars[0xDC], shadowColor);
	    window.hLineXY(1, 1, width - 1, cp437_chars[0xDF], shadowColor);
	}
	if (mnemonic.shortcutIdx >= 0) {
	    if (inButtonPress) {
		window.putCharXY(2 + mnemonic.shortcutIdx, 0,
		    mnemonic.shortcut, menuMnemonicColor);
	    } else {
		window.putCharXY(1 + mnemonic.shortcutIdx, 0,
		    mnemonic.shortcut, menuMnemonicColor);
	    }

	}
    }

    /// Dispatch to the action function/delegate.
    private void dispatch() {
	if (actionFunction !is null) {
	    actionFunction();
	}
	if (actionDelegate !is null) {
	    actionDelegate();
	}
    }

    /**
     * Handle mouse button presses.
     *
     * Params:
     *    event = mouse button event
     */
    override protected void onMouseDown(TMouseEvent event) {
	mouse = event;

	if ((mouseOnButton()) && (mouse.mouse1)) {
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
    override protected void onMouseUp(TMouseEvent event) {
	mouse = event;

	if ((inButtonPress == true) && (mouse.mouse1)) {
	    inButtonPress = false;
	    // Dispatch the event
	    dispatch();
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

	if (!mouseOnButton()) {
	    inButtonPress = false;
	}
    }

    /**
     * Handle keystrokes.
     *
     * Params:
     *    event = keystroke event
     */
    override protected void onKeypress(TKeypressEvent event) {
	if ((event.key == kbEnter) ||
	    (event.key == kbSpace)
	) {
	    // Dispatch
	    dispatch();
	    return;
	}

	// Pass to parent for the things we don't care about.
	super.onKeypress(event);
    }

}

// Functions -----------------------------------------------------------------
