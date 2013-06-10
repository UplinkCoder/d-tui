/**
 * D Text User Interface library - TMessageBox class
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

import core.thread;
import std.string;
import std.utf;
import tapplication;
import twindow;
import tbutton;
import tfield;

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * TMessageBox is a system-modal dialog with buttons for OK, Cancel,
 * Yes, or No.  Call it like:
 *
 *     box = application.messageBox(title, caption, TMessageBox.OK | TMessageBox.CANCEL);
 *     if (box.result == TMessageBox.OK) {
 *        ... the user pressed OK, do stuff ...
 *     }
 *
 */
public class TMessageBox : TWindow {

    public enum Type {
	OK,
	OKCANCEL,
	YESNO,
	YESNOCANCEL };

    public enum Result {
	OK,
	CANCEL,
	YES,
	NO };

    /// Which button was clicked: OK, CANCEL, YES, or NO.
    public Result result = Result.OK;

    /**
     * Public constructor.  The message box will be centered on
     * screen.
     *
     * Params:
     *    application = TApplication that manages this window
     *    title = window title, will be centered along the top border
     *    caption = message to display.  Use embedded newlines to get a multi-line box.
     *    type = one of the Type constants.  Default is Type.OK.
     */
    public this(TApplication application, dstring title, dstring caption,
	Type type = Type.OK) {

	this(application, title, caption, type, true);
    }
    
    /**
     * Public constructor.  The message box will be centered on
     * screen.
     *
     * Params:
     *    application = TApplication that manages this window
     *    title = window title, will be centered along the top border
     *    caption = message to display.  Use embedded newlines to get a multi-line box.
     *    type = one of the Type constants.  Default is Type.OK.
     *    yield = if true, yield this Fiber.  Subclasses need to set this to false.
     */
    protected this(TApplication application, dstring title, dstring caption,
	Type type = Type.OK, bool yield = true) {

	// Determine width and height
	dstring [] lines = splitLines!(dstring)(caption);
	auto width = title.length + 12;
	this.height = 6 + cast(uint)(lines.length);
	foreach (line; lines) {
	    if (line.length + 4 > width) {
		width = line.length + 4;
	    }
	}
	this.width = cast(uint)width;
	if (this.width > application.screen.getWidth()) {
	    this.width = application.screen.getWidth();
	}

	// Register with the TApplication
	super(application, title, 0, 0, this.width, this.height, Flag.MODAL);

	// Now add my elements
	uint lineI = 1;
	foreach (line; lines) {
	    // Centered line
	    // addLabel(center!(dstring)(line, width, ' '), 0, lineI);
	    addLabel(line, 1, lineI, "twindow.background.modal");
	    lineI++;
	}

	// The button line
	lineI++;
	TButton [] buttons;

	// Setup button actions
	final switch (type) {

	case Type.OK:
	    result = Result.OK;
	    buttons.length = 1;
	    if (this.width < 15) {
		this.width = 15;
	    }
	    uint buttonX = (this.width - 11)/2;
	    buttons[0] = addButton("  OK  ", buttonX, lineI,
		delegate void() {
		    result = Result.OK;
		    application.closeWindow(this);
		}
	    );
	    break;

	case Type.OKCANCEL:
	    result = Result.CANCEL;
	    buttons.length = 2;
	    if (this.width < 26) {
		this.width = 26;
	    }
	    uint buttonX = (this.width - 22)/2;
	    buttons[0] = addButton("  OK  ", buttonX, lineI,
		delegate void() {
		    result = Result.OK;
		    application.closeWindow(this);
		}
	    );
	    buttonX += 8 + 4;
	    buttons[1] = addButton("Cancel", buttonX, lineI,
		delegate void() {
		    result = Result.CANCEL;
		    application.closeWindow(this);
		}
	    );
	    break;

	case Type.YESNO:
	    result = Result.NO;
	    buttons.length = 2;
	    if (this.width < 20) {
		this.width = 20;
	    }
	    uint buttonX = (this.width - 16)/2;
	    buttons[0] = addButton("Yes", buttonX, lineI,
		delegate void() {
		    result = Result.YES;
		    application.closeWindow(this);
		}
	    );
	    buttonX += 5 + 4;
	    buttons[1] = addButton("No", buttonX, lineI,
		delegate void() {
		    result = Result.NO;
		    application.closeWindow(this);
		}
	    );
	    break;

	case Type.YESNOCANCEL:
	    result = Result.CANCEL;
	    buttons.length = 3;
	    if (this.width < 31) {
		this.width = 31;
	    }
	    uint buttonX = (this.width - 27)/2;
	    buttons[0] = addButton("Yes", buttonX, lineI,
		delegate void() {
		    result = Result.YES;
		    application.closeWindow(this);
		}
	    );
	    buttonX += 5 + 4;
	    buttons[1] = addButton("No", buttonX, lineI,
		delegate void() {
		    result = Result.NO;
		    application.closeWindow(this);
		}
	    );
	    buttonX += 4 + 4;
	    buttons[2] = addButton("Cancel", buttonX, lineI,
		delegate void() {
		    result = Result.CANCEL;
		    application.closeWindow(this);
		}
	    );
	    break;
	}

	// Set the secondaryFiber to run me
	application.enableSecondaryEventReceiver(this);

	if (yield) {
	    // Yield my fiber.  When I come back from the constructor
	    // response will already be set.
	    Fiber.yield();
	}
    }

}

/**
 * TInputBox is a system-modal dialog with an OK button and a text
 * input field.
 *
 * Call it like:
 *
 *     box = application.inputBox(title, caption);
 *     if (box.text == "yes") {
 *        ... the user entered "yes", do stuff ...
 *     }
 *
 */
public class TInputBox : TMessageBox {

    /// The input field.
    public TField field;

    /// Convenience alias so that callers can just access this.text
    alias field this;

    /**
     * Public constructor.  The input box will be centered on screen.
     *
     * Params:
     *    application = TApplication that manages this window
     *    title = window title, will be centered along the top border
     *    caption = message to display.  Use embedded newlines to get a multi-line box.
     *    text = optional text to seed the field with
     */
    public this(TApplication application, dstring title, dstring caption,
	dstring text = "") {

	super(application, title, caption, Type.OK, false);

	foreach (w; children) {
	    if (auto button = cast(TButton)w) {
		button.y += 2;
	    }
	}

	height += 2;
	field = addField(1, height - 6, width - 4, false, text);
	field.text = text;

	// Yield my fiber.  When I come back from the constructor
	// response will already be set.
	Fiber.yield();
    }

}


// Functions -----------------------------------------------------------------
