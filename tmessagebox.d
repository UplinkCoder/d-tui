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
import std.utf;
import tapplication;
import twindow;

// DEBUG
import std.stdio;

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

    /// Display the OK button
    public static immutable uint BUTTON_OK	= 0x01;

    /// Display the Cancel button
    public static immutable uint BUTTON_CANCEL	= 0x02;

    /// Display the Yes button
    public static immutable uint BUTTON_YES	= 0x04;

    /// Display the No button
    public static immutable uint BUTTON_NO	= 0x08;

    /// Bitmask of buttons to display
    private uint buttons = 0;

    /// Response will be set to which button the user selected
    private uint response = 0;

    /// When true, kill this message box
    private bool quit = false;

    /**
     * Public constructor.  The message box will be centered on
     * screen.
     *
     * Params:
     *    application = TApplication that manages this window
     *    title = window title, will be centered along the top border
     *    caption = message to display.  Use embedded newlines to get a multi-line box.
     *    buttons = one of the TMessageBox.BUTTON_* flags.  Default is BUTTON_OK.
     */
    public this(TApplication application, dstring title, dstring caption,
	uint buttons = BUTTON_OK) {

	this.buttons = buttons;

	// Determine width and height
	// TODO
	uint width = cast(uint)(codeLength!(dchar)(title)) + 10;
	uint height = 7;

	// Register with the TApplication
	super(application, title, 0, 0, width, height, MODAL);

	// Setup button actions
	// TODO

	// Set the secondaryFiber to run me
	application.enableSecondaryEventReceiver(this);

	// Yield my fiber.  When I come back from the constructor response
	// will already be set.
	Fiber.yield();
    }


}

// Functions -----------------------------------------------------------------
