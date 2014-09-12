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

module tui.win32;

version(Windows) {

    // Description -----------------------------------------------------------

    // Imports ---------------------------------------------------------------
    import core.sys.windows.windows;
    import std.algorithm;
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

	/// The actual physical screen as seen by the last flushPhysical()
	/// call
	private CHAR_INFO [] charInfo;

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
	    bool changed = false;

	    // Re-draw the entire screen onto a buffer.
	    if (charInfo.length != width * height) {
		charInfo = new CHAR_INFO[width * height];
		changed = true;
	    }

	    // Place the cursor.
	    if ((cursorVisible) &&
		(cursorY <= height - 1) &&
		(cursorX <= width - 1)
	    ) {
		console.cursor(true);
		console.gotoXY(cursorX, cursorY);
	    } else {
		console.cursor(false);
	    }

	    for (auto x = 0; x < width; x++) {
		for (auto y = 0; y < height; y++) {
		    if (physical[x][y] != logical[x][y]) {
			physical[x][y].setTo(logical[x][y]);
			charInfo[y * width + x].UnicodeChar = physical[x][y].ch & 0xFFFF;
			charInfo[y * width + x].Attributes = win32Attr(physical[x][y]);
			changed = true;
		    }
		}
	    }

	    // For EITHER a cursor change or text change, blast the whole
	    // thing down again.  Otherwise the cursor update leaves screen
	    // artifacts.
	    if ((changed == true) || (console.cursorChanged == true)) {

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
		WriteConsoleOutputW(console.getBuffer(),
		    charInfo.ptr, bufferSize, bufferCoord, &writeRegion);
	    }

	    // All done.
	    console.cursorChanged = false;
	    dirty = false;
	    reallyCleared = false;
	}

    }

    /**
     * This class has convenience methods for emitting output to a Win32
     * Console.
     */
    public class Win32Console {

	/// The session information
	public SessionInfo session;

	/// The Win32 console input handle
	private HANDLE hConsoleInput;

	/// The Win32 console output handle
	private HANDLE hConsoleOutput;

	/// The original state of hConsoleInput
	private DWORD hConsoleInputMode;

	/// The original state of hConsoleOutput
	private DWORD hConsoleOutputMode;

	/// The original state of hConsoleOutput's cursor
	private CONSOLE_CURSOR_INFO consoleOutputCursorInfo;

	/// true if mouse1 was down.  Used to report mouse1 on the release
	/// event.
	private bool mouse1 = false;

	/// true if mouse2 was down.  Used to report mouse2 on the release
	/// event.
	private bool mouse2 = false;

	/// true if mouse3 was down.  Used to report mouse3 on the release
	/// event.
	private bool mouse3 = false;

	/// Cache the cursor value so we only change it when we need to
	private bool cursorOn = true;

	/// Win32 console never posts window resize events, so cache them so
	/// we can poll for resizes instead.
	private TResizeEvent windowResize = null;

	/// If true, the cursor visibility changed
	private bool cursorChanged = false;

	/// The last cursor X position.  Initialized to 1 so that gotoXY(0,
	/// 0) will do something.
	private uint cursorX = 1;

	/// The last cursor Y position.  Initialized to 1 so that gotoXY(0,
	/// 0) will do something.
	private uint cursorY = 1;

	/**
	 * Restore original console mode
	 */
	public void shutdown() {
	    // Reset input
	    SetConsoleMode(hConsoleInput, hConsoleInputMode);

	    // Reset output
	    SetConsoleActiveScreenBuffer(hConsoleOutput);
	    SetConsoleMode(hConsoleOutput, hConsoleOutputMode);
	    SetConsoleCursorInfo(hConsoleOutput, &consoleOutputCursorInfo);
	}

	/**
	 * Destructor restores original console mode
	 */
	public ~this() {
	    shutdown();
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
	    GetConsoleCursorInfo(hConsoleOutput, &consoleOutputCursorInfo);

	    DWORD newInputMode = 0;
	    newInputMode |= ENABLE_WINDOW_INPUT;
	    newInputMode |= ENABLE_MOUSE_INPUT;
	    SetConsoleMode(hConsoleInput, newInputMode);

	    DWORD newOutputMode = 0;

	    // DEBUG
	    // newOutputMode |= ENABLE_PROCESSED_OUTPUT;
	    SetConsoleMode(hConsoleOutput, newOutputMode);

	    // Hang onto the window size
	    // TODO: use SessionInfo
	    windowResize = new TResizeEvent(TResizeEvent.Type.Screen, getPhysicalWidth(),
		getPhysicalHeight());

	    // Setup each drawing surface
	    CONSOLE_SCREEN_BUFFER_INFO screenBufferInfo;
	    GetConsoleScreenBufferInfo(hConsoleOutput, &screenBufferInfo);
	    screenBufferInfo.dwSize.X = cast(short)getPhysicalWidth();
	    screenBufferInfo.dwSize.Y = cast(short)getPhysicalHeight();
	    SetConsoleScreenBufferSize(hConsoleOutput, screenBufferInfo.dwSize);
	    gotoXY(0, 0);
	    cursor(false);
	}

	/**
	 * Get the active drawing screen.
	 *
	 * Returns:
	 *    current drawing screen
	 */
	public HANDLE getBuffer() {
	    return hConsoleOutput;
	}

	/**
	 * Get the width of the physical console.
	 *
	 * Returns:
	 *    width of console stdin is attached to
	 */
	public uint getPhysicalWidth() {
	    CONSOLE_SCREEN_BUFFER_INFO screenBufferInfo;
	    GetConsoleScreenBufferInfo(getBuffer(), &screenBufferInfo);
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
	    GetConsoleScreenBufferInfo(getBuffer(), &screenBufferInfo);
	    return (screenBufferInfo.srWindow.Bottom - screenBufferInfo.srWindow.Top + 1);
	}

	/**
	 * Show or hide the cursor.
	 *
	 * Params:
	 *    on = if true, turn on cursor
	 */
	public void cursor(bool on) {
	    CONSOLE_CURSOR_INFO cursorInfo;

	    if ((on) && (cursorOn == false)) {
		cursorOn = true;
		cursorInfo.dwSize = 100;
		cursorInfo.bVisible = TRUE;
		SetConsoleCursorInfo(hConsoleOutput, &cursorInfo);
		cursorChanged = true;
	    }
	    if ((!on) && (cursorOn == true)) {
		cursorOn = false;
		// dwSize has to be within 1 and 100 even if you are making
		// the cursor invisible.
		cursorInfo.dwSize = 1;
		cursorInfo.bVisible = FALSE;
		SetConsoleCursorInfo(hConsoleOutput, &cursorInfo);
		cursorChanged = true;
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
	    if ((x != cursorX) || (y != cursorY)) {
		COORD coord = { cast(short)x, cast(short)y };
		cursorX = x;
		cursorY = y;
		SetConsoleCursorPosition(hConsoleOutput, coord);
		cursorChanged = true;
	    }
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
	 *    the equivalent TKeypress, or kbNoKey if unknown
	 */
	private TKeypress win32Key(WORD virtualKeyCode) {
	    if ((virtualKeyCode >= '0') && (virtualKeyCode <= '9')) {
		return TKeypress(false, 0, virtualKeyCode, false, false, false);
	    }
	    if ((virtualKeyCode >= 'A') && (virtualKeyCode <= 'Z')) {
		return TKeypress(false, 0, virtualKeyCode, false, false, false);
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
		return kbNoKey;
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

	    auto newWidth = getPhysicalWidth();
	    auto newHeight = getPhysicalHeight();
	    if ((newWidth != windowResize.width) ||
		(newHeight != windowResize.height)) {
		TResizeEvent resize = new TResizeEvent(TResizeEvent.Type.Screen,
		    newWidth, newHeight);
		windowResize.width = newWidth;
		windowResize.height = newHeight;
		events ~= resize;
	    }

	    INPUT_RECORD [] buffer = new INPUT_RECORD[10];
	    DWORD actuallyRead;
	    auto rc = ReadConsoleInputW(hConsoleInput, buffer.ptr, buffer.length, &actuallyRead);

	    // std.stdio.stderr.writefln("rc %d actuallyRead %d", rc, actuallyRead);

	    if (rc == 0) {
		// Error reading input, bail out unhappily
		throw new Exception("ReadConsoleInputW failed");
	    }

	    for (auto i = 0; i < actuallyRead; i++) {
		auto event = buffer[i];

		// std.stdio.stderr.writefln("EventType %d 0x%x", event.EventType, event.EventType);

		switch (event.EventType) {

		case KEY_EVENT:
		    auto winKeypress = event.KeyEvent;
		    if (winKeypress.bKeyDown == false) {
			// Ignore key up events
			break;
		    }

		    DWORD flags = winKeypress.dwControlKeyState;
/+
		    std.stdio.stderr.writefln("shift %s ctrl %s alt %s vkey %%x%02x %d uChar %d '%c'",
			(flags & SHIFT_PRESSED ? "true" : "false"),
			(((flags & LEFT_CTRL_PRESSED) || (flags & RIGHT_CTRL_PRESSED)) ? "true" : "false"),
			(((flags & LEFT_ALT_PRESSED) || (flags & RIGHT_ALT_PRESSED)) ? "true" : "false"),
			winKeypress.wVirtualKeyCode,
			winKeypress.wVirtualKeyCode,
			winKeypress.UnicodeChar,
			winKeypress.UnicodeChar);
+/

		    TKeypress key = win32Key(winKeypress.wVirtualKeyCode);
		    if (key == kbNoKey) {
			if (winKeypress.UnicodeChar > 0) {
			    // Use uChar
			    key = TKeypress(false, 0, winKeypress.UnicodeChar, false, false, false);
			} else {
			    // Ignore this keystroke
			    break;
			}
		    }

		    TKeypressEvent keypress = new TKeypressEvent(key);
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

		    // My convention is that:
		    //    - Bare Alt- keys are lowercase
		    //    - Shift+Alt- keys are uppercase
		    //    - Bare Ctrl- keys are uppercase (already done)
		    //    - Shifted keys are uppercase
		    if (keypress.key.alt &&
			!keypress.key.ctrl &&
			!keypress.key.shift) {

			keypress.key = toLower(keypress.key);
		    } else if (keypress.key.alt &&
			!keypress.key.ctrl &&
			keypress.key.shift) {

			keypress.key = toUpper(keypress.key);
		    } else if (keypress.key.shift) {
			keypress.key = toUpper(keypress.key);
		    }

		    // std.stdio.stderr.writefln("TKeypress %s", keypress.key);
		    events ~= keypress;
		    break;

		case MOUSE_EVENT:
		    auto winMouseEvent = event.MouseEvent;

		    TMouseEvent mouse = new TMouseEvent(TMouseEvent.Type.MOUSE_MOTION);
		    mouse.x = winMouseEvent.dwMousePosition.X;
		    mouse.y = winMouseEvent.dwMousePosition.Y;
		    // Clamp to the window coordinates
		    if (mouse.x >= windowResize.width) {
			mouse.x = windowResize.width - 1;
		    }
		    if (mouse.y >= windowResize.height) {
			mouse.y = windowResize.height - 1;
		    }
		    mouse.absoluteX = mouse.x;
		    mouse.absoluteY = mouse.y;
		    if (winMouseEvent.dwButtonState & FROM_LEFT_1ST_BUTTON_PRESSED) {
			mouse.mouse1 = true;
		    }
		    if (winMouseEvent.dwButtonState & RIGHTMOST_BUTTON_PRESSED) {
			mouse.mouse2 = true;
		    }
		    if (winMouseEvent.dwButtonState & FROM_LEFT_2ND_BUTTON_PRESSED) {
			mouse.mouse3 = true;
		    }

		    switch (winMouseEvent.dwEventFlags) {
		    case 0:
			// Button press OR release.  Check each mouse button
			// and drop UP/DOWN messages.
			if (mouse1 && !mouse.mouse1) {
			    // Button 1 release
			    mouse.type = TMouseEvent.Type.MOUSE_UP;
			    mouse.mouse1 = true;
			} else if (mouse2 && !mouse.mouse2) {
			    // Button 2 release
			    mouse.type = TMouseEvent.Type.MOUSE_UP;
			    mouse.mouse2 = true;
			} else if (mouse3 && !mouse.mouse3) {
			    // Button 3 release
			    mouse.type = TMouseEvent.Type.MOUSE_UP;
			    mouse.mouse3 = true;
			} else {
			    // Button press
			    mouse.type = TMouseEvent.Type.MOUSE_DOWN;
			}
			break;

		    case MOUSE_MOVED:
			// Mouse motion - nothing to do
			break;

		    // case MOUSE_WHEELED:
		    case 0x0004:
			// Wheel up/down - doesn't seem to be working in
			// Windows XP, oh well.
			if (HIWORD(winMouseEvent.dwButtonState) > 0) {
			    mouse.mouseWheelUp = true;
			} else {
			    mouse.mouseWheelDown = true;
			}
			break;

		    default:
			// Unknown - disregard mouse
			mouse = null;
			break;
		    }

		    if (mouse !is null) {
			// Hang onto button states
			mouse1 = mouse.mouse1;
			mouse2 = mouse.mouse2;
			mouse3 = mouse.mouse3;
			events ~= mouse;
		    }
		    break;

		case WINDOW_BUFFER_SIZE_EVENT:
		    COORD newSize = event.WindowBufferSizeEvent.dwSize;
		    TResizeEvent resize = new TResizeEvent(TResizeEvent.Type.Screen,
			newSize.X, newSize.Y);

		    // Make the screen buffer match the window size
		    SetConsoleScreenBufferSize(hConsoleOutput, event.WindowBufferSizeEvent.dwSize);

		    // Reset the cursor
		    cursor(true);
		    gotoXY(0, 0);

		    events ~= resize;
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

	/**
	 * Subclasses must provide an implementation that closes sockets,
	 * restores console, etc.
	 */
	override public void shutdown() {
	    console.shutdown();
	}

    }

    // Functions -------------------------------------------------------------

}
