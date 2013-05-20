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

import std.utf;
import tapplication;
import twindow;

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * TMessageBox is a system-modal dialog with OK and/or Cancel buttons.
 */
public class TMessageBox : TWindow {

    /// Display the OK button
    public static immutable uint BUTTON_OK	= 0x01;

    /// Bitmask of buttons to display
    private uint buttons = 0;

    /// Response will be set to which button the user selected
    private uint response = 0;

    /// When true, kill this message box
    private bool quit = false;

    /**
     * Public constructor.  Window will be located at (0, 0).
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
    }



}

// Functions -----------------------------------------------------------------
