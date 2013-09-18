/**
 * D Text User Interface library - base IO classes
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

/*
 * TODO:
 *	Win32 support:
 *	    SetConsoleTextAttribute
 *	    SetConsoleCursorPosition
 *	    SetConsoleTitleA
 *	    GetConsoleScreenBufferInfo
 *	    WriteConsoleA / WriteConsoleW
 *	    ReadConsoleInputA / ReadConsoleInputW
 *	    http://support.microsoft.com/kb/99261 for clear()
 *	    
 */

// Description ---------------------------------------------------------------

// Imports -------------------------------------------------------------------

import std.array;
import std.conv;
import std.datetime;
import std.file;
import std.format;
import std.stdio;
import std.utf;
import base;
import codepage;

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * This Screen class draws to a Win32 Console screen.
 */
public class Win32ConsoleScreen : Screen {

    /// Push the logical screen to the physical device.
    override public void flushPhysical() {
	// TODO
    }

}

/**
 * This class has convenience methods for emitting output to a Win32
 * Console.
 */
public class Win32Console {

    /**
     * Get the width of the physical console.
     *
     * Returns:
     *    width of console stdin is attached to
     */
    public uint getPhysicalWidth() {
	// TODO
	return 25;
    }

    /**
     * Get the height of the physical console.
     *
     * Returns:
     *    height of console stdin is attached to
     */
    public uint getPhysicalHeight() {
	// TODO
	return 80;
    }

    /**
     * Constructor sets up state for getEvent()
     */
    public this() {

    }

}

/**
 * This class uses a Win32 Console to provide a screen, keyboard, and
 * mouse to TApplication.
 */
public class Win32ConsoleBackend : Backend {

    /// Input events are processed by this Terminal.
    private Win32Console console;

    /// Public constructor
    public this() {
	// Create a console
	console = new Win32Console();

	// Create a screen
	screen = new Win32ConsoleScreen();

	// Reset the screen size
	screen.setDimensions(console.getPhysicalWidth(),
	    console.getPhysicalHeight());

	// Clear the screen
	// TODO
    }

    /**
     * Sync the logical screen to the physical device.
     */
    override public void flushScreen() {
	// TODO
    }

    /**
     * Get keyboard, mouse, and screen resize events.
     *
     * Params:
     *    timeout = maximum amount of time in milliseconds to wait for an event.  0 means return immediately.
     *
     * Returns:
     *    events received, or an empty list if the timeout was reached
     */
    override public TInputEvent [] getEvents(uint timeout) {
	// TODO
	TInputEvent [] events;
	return events;
    }
}

// Functions -----------------------------------------------------------------
