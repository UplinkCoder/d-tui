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

version(Windows) {

    // Description -----------------------------------------------------------

    // Imports ---------------------------------------------------------------
    import core.sys.windows.windows;
    import std.conv;
    import base;

    // Defines ---------------------------------------------------------------

    // Globals ---------------------------------------------------------------

    // Classes ---------------------------------------------------------------

    /**
     * This Screen class draws to a Win32 Console screen.
     */
    public class Win32ConsoleScreen : Screen {

	/// We call console.cursor() and console.gotoXY() so need the instance
	private Win32Console console;

	/**
	 * Public constructor
	 *
	 * Params:
	 *    console = Win32Console to use
	 */
	public this(Win32Console console) {
	    this.console = console;
	}

	/**
	 * Convert CellAttributes into a Win32 console Attributes value.
	 *
	 * Params:
	 *    attr = CellAttributes
	 *
	 * Returns:
	 *    a WORD to be passed into a CHAR_INFO structure
	 */
	private WORD win32Attr(CellAttributes attr) {
	    WORD win32attr = 0;
	    final switch (attr.foreColor) {
	    case Color.BLACK:
		win32attr += 0x00;
		break;
	    case Color.WHITE:
		win32attr += 0x07;
		break;
	    case Color.RED:
		win32attr += 0x04;
		break;
	    case Color.CYAN:
		win32attr += 0x03;
		break;
	    case Color.GREEN:
		win32attr += 0x02;
		break;
	    case Color.MAGENTA:
		win32attr += 0x05;
		break;
	    case Color.BLUE:
		win32attr += 0x01;
		break;
	    case Color.YELLOW:
		win32attr += 0x06;
		break;
	    }
	    final switch (attr.backColor) {
	    case Color.BLACK:
		win32attr += 0x00;
		break;
	    case Color.WHITE:
		win32attr += 0x70;
		break;
	    case Color.RED:
		win32attr += 0x40;
		break;
	    case Color.CYAN:
		win32attr += 0x30;
		break;
	    case Color.GREEN:
		win32attr += 0x20;
		break;
	    case Color.MAGENTA:
		win32attr += 0x50;
		break;
	    case Color.BLUE:
		win32attr += 0x10;
		break;
	    case Color.YELLOW:
		win32attr += 0x60;
		break;
	    }
	    if (attr.bold) {
		win32attr += 0x08;
	    }
	    if (attr.reverse) {
		win32attr += 0x4000;
	    }
	    if (attr.underline) {
		win32attr += 0x8000;
	    }
	    return win32attr;
	}

	/// Push the logical screen to the physical device.
	override public void flushPhysical() {
	    if (dirty == false) {
		assert(reallyCleared == false);
		return;
	    }

	    // Start at the visible top-left corner.
	    console.gotoXY(0, 0);

	    // Re-draw the entire screen onto a buffer.
	    CHAR_INFO [] charInfo = new CHAR_INFO[width * height];

	    for (auto x = 0; x < width; x++) {
		for (auto y = 0; y < height; y++) {
		    charInfo[y * width + x].UnicodeChar = logical[x][y].ch & 0xFFFF;
		    charInfo[y * width + x].Attributes = win32Attr(logical[x][y]);
		    physical[x][y].setTo(logical[x][y]);
		}
	    }

	    // Blast the entire buffer to screen with one call to
	    // WriteConsoleOutputW.
	    COORD bufferSize = { cast(short)width, cast(short)height };
	    COORD bufferCoord = { 0, 0 };
	    SMALL_RECT writeRegion = {
		cast(short)0,
		cast(short)0,
		cast(short)width,
		cast(short)height
	    };
	    WriteConsoleOutputW(GetStdHandle(STD_OUTPUT_HANDLE),
		charInfo.ptr, bufferSize, bufferCoord, &writeRegion);

	    // Now place the cursor.
	    if ((cursorVisible) &&
		(cursorY <= height - 1) &&
		(cursorX <= width - 1)
	    ) {
		console.cursor(true);
		console.gotoXY(cursorX, cursorY);
	    } else {
		console.cursor(false);
	    }

	    // All done.
	    dirty = false;
	    reallyCleared = false;
	}

    }

    /**
     * This class has convenience methods for emitting output to a Win32
     * Console.
     */
    public class Win32Console {

	/// The Win32 console input handle
	private HANDLE hConsoleInput;

	/// The Win32 console output handle
	private HANDLE hConsoleOutput;

	/// The original state of hConsoleInput
	private DWORD hConsoleInputMode;

	/// The original state of hConsoleOutput
	private DWORD hConsoleOutputMode;

	/// Cache the cursor value so we only change it when we need to
	private bool cursorOn = true;

	/**
	 * Get the width of the physical console.
	 *
	 * Returns:
	 *    width of console stdin is attached to
	 */
	public uint getPhysicalWidth() {
	    CONSOLE_SCREEN_BUFFER_INFO screenBufferInfo;
	    GetConsoleScreenBufferInfo(hConsoleOutput, &screenBufferInfo);
	    return (screenBufferInfo.srWindow.Right - screenBufferInfo.srWindow.Left + 1);
	}

	/**
	 * Get the height of the physical console.
	 *
	 * Returns:
	 *    height of console stdin is attached to
	 */
	public uint getPhysicalHeight() {
	    CONSOLE_SCREEN_BUFFER_INFO screenBufferInfo;
	    GetConsoleScreenBufferInfo(hConsoleOutput, &screenBufferInfo);
	    return (screenBufferInfo.srWindow.Bottom - screenBufferInfo.srWindow.Top + 1);
	}

	/**
	 * Destructor restores original console mode
	 */
	public ~this() {
	    SetConsoleMode(hConsoleInput, hConsoleInputMode);
	    SetConsoleMode(hConsoleOutput, hConsoleOutputMode);
	}

	/**
	 * Constructor sets up state for getEvent()
	 */
	public this() {
	    // Unicode only
	    SetConsoleCP(1200);

	    hConsoleInput = GetStdHandle(STD_INPUT_HANDLE);
	    hConsoleOutput = GetStdHandle(STD_OUTPUT_HANDLE);

	    GetConsoleMode(hConsoleInput, &hConsoleInputMode);
	    GetConsoleMode(hConsoleOutput, &hConsoleOutputMode);

	    DWORD newInputMode = 0;
	    newInputMode |= ENABLE_WINDOW_INPUT;
	    newInputMode |= ENABLE_MOUSE_INPUT;
	    SetConsoleMode(hConsoleInput, newInputMode);

	    DWORD newOutputMode = 0;
	    SetConsoleMode(hConsoleOutput, newOutputMode);
	}

	/**
	 * Show or hide the cursor.
	 *
	 * Params:
	 *    on = if true, turn on cursor
	 */
	public void cursor(bool on) {
	    CONSOLE_CURSOR_INFO cursorInfo;

	    if (on && (cursorOn == false)) {
		cursorOn = true;
		cursorInfo.dwSize = 1;
		cursorInfo.bVisible = TRUE;
		SetConsoleCursorInfo(hConsoleOutput, &cursorInfo);
	    }
	    if (!on && (cursorOn == true)) {
		cursorOn = false;
		cursorInfo.dwSize = 1;
		cursorInfo.bVisible = FALSE;
		SetConsoleCursorInfo(hConsoleOutput, &cursorInfo);
	    }
	}

	/**
	 * Move the cursor to (x, y).
	 *
	 * Params:
	 *    x = column coordinate.  0 is the left-most column.
	 *    y = row coordinate.  0 is the top-most row.
	 */
	public void gotoXY(uint x, uint y) {
	    COORD coord = { cast(short)x, cast(short)y };
	    SetConsoleCursorPosition(hConsoleOutput, coord);
	}

	/**
	 * Convert Win32 virtual key code into a TKeypress.  Note that
	 * shift/ctrl/alt processing still need to be done afterwards to
	 * distinguish 'A' from 'a'.
	 *
	 * Params:
	 *    virtualKeyCode = Win32 device independent key code
	 *
	 * Returns:
	 *    the equivalent TKeypress, or kbEscape if unknown
	 */
	private TKeypress win32Key(WORD virtualKeyCode) {
	    if ((virtualKeyCode >= '0') && (virtualKeyCode <= '9')) {
		return TKeypress(false, TKeypress.ESC, virtualKeyCode, false, false, false);
	    }
	    if ((virtualKeyCode >= 'A') && (virtualKeyCode <= 'Z')) {
		return TKeypress(false, TKeypress.ESC, virtualKeyCode, false, false, false);
	    }

	    switch (virtualKeyCode) {
	    case VK_BACK:
		return kbBackspace;
	    case VK_TAB:
		return kbTab;
	    case VK_RETURN:
		return kbEnter;
	    case VK_SPACE:
		return kbSpace;
	    case VK_PRIOR:
		return kbPgUp;
	    case VK_NEXT:
		return kbPgDn;
	    case VK_END:
		return kbEnd;
	    case VK_HOME:
		return kbHome;
	    case VK_UP:
		return kbUp;
	    case VK_DOWN:
		return kbDown;
	    case VK_LEFT:
		return kbLeft;
	    case VK_RIGHT:
		return kbRight;
	    case VK_INSERT:
		return kbIns;
	    case VK_DELETE:
		return kbDel;
	    case VK_ESCAPE:
		return kbEsc;
	    case VK_F1:
		return kbF1;
	    case VK_F2:
		return kbF2;
	    case VK_F3:
		return kbF3;
	    case VK_F4:
		return kbF4;
	    case VK_F5:
		return kbF5;
	    case VK_F6:
		return kbF6;
	    case VK_F7:
		return kbF7;
	    case VK_F8:
		return kbF8;
	    case VK_F9:
		return kbF9;
	    case VK_F10:
		return kbF10;
	    case VK_F11:
		return kbF11;
	    case VK_F12:
		return kbF12;
/+
	    case VK_F13:
		return kbF13;
	    case VK_F14:
		return kbF14;
	    case VK_F15:
		return kbF15;
	    case VK_F16:
		return kbF16;
	    case VK_F17:
		return kbF17;
	    case VK_F18:
		return kbF18;
	    case VK_F19:
		return kbF19;
	    case VK_F20:
		return kbF20;
	    case VK_F21:
		return kbF21;
	    case VK_F22:
		return kbF22;
	    case VK_F23:
		return kbF23;
	    case VK_F24:
		return kbF24;
+/
	    default:
		return kbEsc;
	    }
	}

	/**
	 * Grabs the next event from the console input queue.
	 *
	 * Returns:
	 *    list of new events (which may be empty)
	 */
	public TInputEvent [] getEvents() {
	    TInputEvent [] events;

	    INPUT_RECORD[32] buffer;
	    DWORD actuallyRead;
	    auto rc = ReadConsoleInputW(hConsoleInput, buffer.ptr, buffer.length, &actuallyRead);

	    if (rc == 0) {
		// Error reading input, bail out unhappily
		throw new Exception("ReadConsoleInputW failed");
	    }

	    foreach (event; buffer[0 .. actuallyRead]) {
		switch (event.EventType) {
		case KEY_EVENT:
		    auto winKeypress = event.KeyEvent;
		    if (winKeypress.bKeyDown == false) {
			// Ignore key up events
			break;
		    }
		    TKeypressEvent keypress;
		    keypress.key = win32Key(winKeypress.wVirtualKeyCode);
		    DWORD flags = winKeypress.dwControlKeyState;
		    if (flags & SHIFT_PRESSED) {
			keypress.key.shift = true;
		    } else {
			keypress.key = toLower(keypress.key);
		    }
		    if ((flags & LEFT_CTRL_PRESSED) || (flags & RIGHT_CTRL_PRESSED)) {
			keypress.key.ctrl = true;
		    }
		    if ((flags & LEFT_ALT_PRESSED) || (flags & RIGHT_ALT_PRESSED)) {
			keypress.key.alt = true;
		    }
		    events ~= keypress;
		    break;

		case MOUSE_EVENT:
		    auto winMouseEvent = event.MouseEvent;
		    // TODO

		    break;

		case WINDOW_BUFFER_SIZE_EVENT:
		    // TODO
		    // record.WindowBufferSizeEvent;
		    break;

		default:
		    // Ignore
		    break;
		}
	    }
	    return events;
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
	    screen = new Win32ConsoleScreen(console);

	    // Reset the screen size
	    screen.setDimensions(console.getPhysicalWidth(),
		console.getPhysicalHeight());
	}

	/**
	 * Sync the logical screen to the physical device.
	 */
	override public void flushScreen() {
	    screen.flushPhysical();
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
	    TInputEvent [] events;
	    auto rc = WaitForSingleObject(console.hConsoleInput, timeout);
	    if (rc == 0) {
		events ~= console.getEvents();
	    }
	    return events;
	}
    }

    // Functions -------------------------------------------------------------

}
