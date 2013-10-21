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

// Description ---------------------------------------------------------------

// Imports -------------------------------------------------------------------

import std.array;
import std.conv;
import std.datetime;
import std.file;
import std.format;
import std.socket;
import std.utf;
import base;
import codepage;

version(Posix) {
    import core.stdc.errno;
    import core.stdc.string;
    import core.sys.posix.poll;
    import core.sys.posix.sys.ioctl;
    import core.sys.posix.termios;
    import core.sys.posix.unistd;
}

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * This Screen class draws to an xterm/ANSI/ECMA-type terminal.
 */
public class ECMAScreen : Screen {

    /// We call terminal.cursor() so need the instance
    private ECMATerminal terminal;

    /**
     * Public constructor
     *
     * Params:
     *    terminal = ECMATerminal to use
     */
    public this(ECMATerminal terminal) {
	this.terminal = terminal;
    }

    /**
     * Perform a somewhat-optimal rendering of a line
     *
     * Params:
     *    y = row coordinate.  0 is the top-most row.
     *    writer = appender to write escape sequences to
     *    lastAttr = cell attributes from the last call to flushLine
     */
    private void flushLine(int y, Appender!(string) writer, CellAttributes lastAttr) {
	int lastX = -1;
	int textEnd = 0;
	for (int x = 0; x < width; x++) {
	    auto lCell = logical[x][y];
	    if (!lCell.isBlank()) {
		textEnd = x;
	    }
	}
	// Push textEnd to first column beyond the text area
	textEnd++;

	// DEBUG
	// reallyCleared = true;

	for (int x = 0; x < width; x++) {
	    auto lCell = logical[x][y];
	    auto pCell = physical[x][y];

	    if ((lCell != pCell) || (reallyCleared == true)) {

		if (debugToStderr) {
		    std.stdio.stderr.writefln("\n--");
		    std.stdio.stderr.writefln(" Y: %d X: %d", y, x);
		    std.stdio.stderr.writefln("   lCell: %s", lCell);
		    std.stdio.stderr.writefln("   pCell: %s", pCell);
		    std.stdio.stderr.writefln("    ====    ");
		}

		if (lastAttr is null) {
		    lastAttr = new CellAttributes();
		    writer.put(terminal.normal());
		}

		// Place the cell
		if ((lastX != (x - 1)) || (lastX == -1)) {
		    // Advancing at least one cell, or the first gotoXY
		    writer.put(terminal.gotoXY(x, y));
		}

		assert(lastAttr !is null);

		if ((x == textEnd) && (textEnd < width - 1)) {
		    assert(lCell.isBlank());

		    for (auto i = x; i < width; i++) {
			assert(logical[i][y].isBlank());
			// Physical is always updatesd
			physical[i][y].reset();
		    }

		    // Clear remaining line
		    writer.put(terminal.clearRemainingLine());
		    lastAttr.reset();
		    return;
		}

		// Now emit only the modified attributes
		if ((lCell.foreColor != lastAttr.foreColor) &&
		    (lCell.backColor != lastAttr.backColor) &&
		    (lCell.bold == lastAttr.bold) &&
		    (lCell.reverse == lastAttr.reverse) &&
		    (lCell.underline == lastAttr.underline) &&
		    (lCell.blink == lastAttr.blink)) {

		    // Both colors changed, attributes the same
		    writer.put(terminal.color(lCell.foreColor,
			    lCell.backColor));

		    if (debugToStderr) {
			std.stdio.stderr.writefln("1 Change only fore/back colors");
		    }
		} else if ((lCell.foreColor != lastAttr.foreColor) &&
		    (lCell.backColor != lastAttr.backColor) &&
		    (lCell.bold != lastAttr.bold) &&
		    (lCell.reverse != lastAttr.reverse) &&
		    (lCell.underline != lastAttr.underline) &&
		    (lCell.blink != lastAttr.blink)) {

		    if (debugToStderr) {
			std.stdio.stderr.writefln("2 Set all attributes");
		    }

		    // Everything is different
		    writer.put(terminal.color(lCell.foreColor,
			    lCell.backColor,
			    lCell.bold, lCell.reverse, lCell.blink,
			    lCell.underline));

		} else if ((lCell.foreColor != lastAttr.foreColor) &&
		    (lCell.backColor == lastAttr.backColor) &&
		    (lCell.bold == lastAttr.bold) &&
		    (lCell.reverse == lastAttr.reverse) &&
		    (lCell.underline == lastAttr.underline) &&
		    (lCell.blink == lastAttr.blink)) {

		    // Attributes same, foreColor different
		    writer.put(terminal.color(lCell.foreColor, true));

		    if (debugToStderr) {
			std.stdio.stderr.writefln("3 Change foreColor");
		    }

		} else if ((lCell.foreColor == lastAttr.foreColor) &&
		    (lCell.backColor != lastAttr.backColor) &&
		    (lCell.bold == lastAttr.bold) &&
		    (lCell.reverse == lastAttr.reverse) &&
		    (lCell.underline == lastAttr.underline) &&
		    (lCell.blink == lastAttr.blink)) {

		    // Attributes same, backColor different
		    writer.put(terminal.color(lCell.backColor, false));

		    if (debugToStderr) {
			std.stdio.stderr.writefln("4 Change backColor");
		    }

		} else if ((lCell.foreColor == lastAttr.foreColor) &&
		    (lCell.backColor == lastAttr.backColor) &&
		    (lCell.bold == lastAttr.bold) &&
		    (lCell.reverse == lastAttr.reverse) &&
		    (lCell.underline == lastAttr.underline) &&
		    (lCell.blink == lastAttr.blink)) {

		    // All attributes the same, just print the char
		    // NOP

		    if (debugToStderr) {
			std.stdio.stderr.writefln("5 Only emit character");
		    }
		} else {
		    // Just reset everything again
		    writer.put(terminal.color(lCell.foreColor, lCell.backColor,
			    lCell.bold, lCell.reverse, lCell.blink,
			    lCell.underline));

		    if (debugToStderr) {
			std.stdio.stderr.writefln("6 Change all attributes");
		    }
		}
		// Emit the character
		writer.put(dcharToString(lCell.ch));

		// Save the last rendered cell
		lastX = x;
		lastAttr.setTo(lCell);

		// Physical is always updatesd
		physical[x][y].setTo(lCell);

	    } // if ((lCell != pCell) || (reallyCleared == true))

	} // for (auto x = 0; x < width; x++)
    }

    /**
     * Render the screen to a string that can be emitted to something
     * that knows how to process ANSI/ECMA escape sequences.
     *
     * Returns:
     *    escape sequences string that provides the updates to the
     *    physical screen
     */
    public string flushString() {
	if (dirty == false) {
	    assert(reallyCleared == false);
	    return "";
	}

	CellAttributes attr;

	auto writer = appender!string();
	if (reallyCleared == true) {
	    attr = new CellAttributes();
	    writer.put(terminal.clearAll());
	}

	for (auto y = 0; y < height; y++) {
	    flushLine(y, writer, attr);
	}

	dirty = false;
	reallyCleared = false;

	string result = writer.data;
	if (debugToStderr) {
	    std.stdio.stderr.writefln("flushString(): %s", result);
	}
	return result;
    }

    /// Push the logical screen to the physical device.
    override public void flushPhysical() {
	string result = flushString();
	if ((cursorVisible) &&
	    (cursorY <= height - 1) &&
	    (cursorX <= width - 1)
	) {
	    result ~= terminal.cursor(true);
	    result ~= terminal.gotoXY(cursorX, cursorY);
	} else {
	    result ~= terminal.cursor(false);
	}
	terminal.writef(result);
	terminal.flush();
    }
}

/**
 * This class has convenience methods for emitting output to ANSI
 * X3.64 / ECMA-48 type terminals e.g. xterm, linux, vt100, ansi.sys,
 * etc.
 */
public class ECMATerminal {

    /// Parameters being collected.  E.g. if the string is \033[1;3m,
    /// then params[0] will be 1 and params[1] will be 3.
    private dstring [] params;

    /// params[paramI] is being appended to.
    private uint paramI;

    /// States in the input parser
    private enum STATE {
	GROUND,
	ESCAPE,
	ESCAPE_INTERMEDIATE,
	CSI_ENTRY,
	CSI_PARAM,
	// CSI_INTERMEDIATE,
	MOUSE
    }

    /// Current parsing state
    private STATE state;

    /// The time we entered STATE.ESCAPE.  If we get a bare escape
    /// without a code following it, this is used to return that bare
    /// escape.
    private long escapeTime;

    /// true if mouse1 was down.  Used to report mouse1 on the release
    /// event.
    private bool mouse1;

    /// true if mouse2 was down.  Used to report mouse2 on the release
    /// event.
    private bool mouse2;

    /// true if mouse3 was down.  Used to report mouse3 on the release
    /// event.
    private bool mouse3;

    /// Cache the cursor value so we only emit the sequence when we need to
    private bool cursorOn = true;

    /// Set by the SIGWINCH handler to expose window resize events
    private TResizeEvent windowResize = null;

    /// If true, then we changed stdin and need to change it back
    private bool setRawMode;

    /// The socket to read/write from
    private Socket socket = null;

    /// If true, the socket is assumed to be alive.
    private bool socketAlive = false;

    /// When true, the terminal is sending non-UTF8 bytes when
    /// reporting mouse events.
    private bool brokenTerminalUTFMouse = false;

    // Cache these variables between calls to getCharSocket()
    private dchar[] socketChars;
    private char[1024] socketReadBuffer;
    private size_t socketReadBufferN = 0;

    /**
     * Constructor sets up state for getEvent()
     *
     * Params:
     *    socket = socket to the remote user, or null for stdin.  If stdin is used, it will be put in raw mode; the destructor will restore stdin to whatever it was.  Note that the socket must be in blocking mode.  Also, stdin is not supported on Windows, use Win32ConsoleBackend() instead.
     */
    public this(Socket socket = null) {
	reset();
	mouse1 = false;
	mouse2 = false;
	mouse3 = false;
	this.socket = socket;
	socketChars.length = 0;

	if (socket is null) {
	    version(Windows) {
		throw new Exception("stdin is not supported on Windows, either use Win32ConsoleBackend() instead or pass in a socket");
	    }
	    version(Posix) {
		termios newTermios;
		tcgetattr(std.stdio.stdin.fileno(), &oldTermios);
		newTermios = oldTermios;
		cfmakeraw(&newTermios);
		tcsetattr(std.stdio.stdin.fileno(), TCSANOW, &newTermios);
	    }
	    setRawMode = true;
	} else {
	    assert(socket.blocking == true);
	    socketAlive = socket.isAlive();
	}

	// Enable mouse reporting and metaSendsEscape
	writef("%s%s", mouse(true), xtermMetaSendsEscape(true));

	// Hang onto the window size
	windowResize = new TResizeEvent(TResizeEvent.Type.Screen, getPhysicalWidth(),
	    getPhysicalHeight());
    }

    /// Restore terminal to normal state
    public void shutdown() {
	if (setRawMode) {
	    version(Posix) {
		tcsetattr(std.stdio.stdin.fileno(), TCSANOW, &oldTermios);
	    }
	    setRawMode = false;
	}
	// Disable mouse reporting and show cursor
	writef("%s%s%s", mouse(false), cursor(true), normal());
	if ((socket !is null) && (socketAlive)) {
	    socket.shutdown(SocketShutdown.BOTH);
	    socketAlive = false;
	}
    }

    /// Destructor restores terminal to normal state
    public ~this() {
	shutdown();
    }

    /**
     * Emit something to output, either stdout or socket
     *
     * Params:
     *    args... = arguments to writef
     */
    public void writef(T...)(T args) {
	if (socket is null) {
	    if (args.length > 1) {
		std.stdio.stdout.writef(args);
	    } else {
		std.stdio.stdout.write(args);
	    }
	} else {
	    if (socketAlive) {
		if (args.length > 1) {
		    auto writer = appender!string();
		    formattedWrite(writer, args);
		    socket.send(writer.data);
		} else {
		    socket.send(args[0]);
		}
	    }
	}
    }

    /**
     * Flush output, either stdout or socket
     */
    public void flush() {
	if (socket is null) {
	    std.stdio.stdout.flush();
	} else {
	    // Nothing to do, the socket is in blocking mode so everything
	    // was already "flushed" by the writef() call.
	}
    }

    /// Reset keyboard/mouse input parser
    private void reset() {
	state = STATE.GROUND;
	paramI = 0;
	params.length = 1;
	params[0] = "";
    }

    // Used for raw mode
    version(Posix) {

	/// The definitions for the flags are taken from the Linux man page
	public static void cfmakeraw(termios * termios_p) {
	    termios_p.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON);
	    termios_p.c_oflag &= ~OPOST;
	    termios_p.c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
	    termios_p.c_cflag &= ~(CSIZE | PARENB);
	    termios_p.c_cflag |= CS8;
	}

	/// The original state of stdin
	private termios oldTermios;

	/**
	 * Read one unsigned byte from stdin and upcast to dchar.
	 *
	 * Params:
	 *    fileno = file number to read from
	 *
	 * Returns:
	 *    one 8-bit byte upcast to a Unicode code point
	 */
	static public dchar getByteFileno(int fileno) {
	    char[1] buffer;

	    auto rc = read(fileno, buffer.ptr, 1);
	    if (rc == 0) {
		// This is EOF
		throw new FileException("EOF");
	    }
	    if (rc < 0) {
		if (errno == EIO) {
		    // This is also EOF
		    throw new FileException("EIO");
		}
		throw new FileException(to!string(strerror(errno)));
	    }
	    return buffer[0];
	}

	/**
	 * Read one Unicode code point from a file descriptor.
	 *
	 * Params:
	 *    fileno = file number to read from
	 *
	 * Returns:
	 *    one Unicode code point
	 */
	static public dchar getCharFileno(int fileno) {
	    char[4] buffer;

	    auto rc = read(fileno, buffer.ptr, 1);
	    if (rc == 0) {
		// This is EOF
		throw new FileException("EOF");
	    }
	    if (rc < 0) {
		if (errno == EIO) {
		    // This is also EOF
		    throw new FileException("EIO");
		}
		throw new FileException(to!string(strerror(errno)));
	    }
	    assert(rc > 0);

	    size_t len = 0;
	    if ((buffer[0] & 0xF0) == 0xF0) {
		// 3 more bytes coming
		len = 3;
	    } else if ((buffer[0] & 0xE0) == 0xE0) {
		// 2 more bytes coming
		len = 2;
	    } else if ((buffer[0] & 0xC0) == 0xC0) {
		// 1 more byte coming
		len = 1;
	    }
	    rc = read(fileno, cast(void *)(buffer.ptr) + 1, len);

	    size_t i;
	    return decode(buffer, i);
	}

	/**
	 * Read one Unicode code point from stdin.
	 *
	 * Returns:
	 *    one Unicode code point
	 */
	public dchar getCharStdin() {
	    try {
		char[4] buffer;
		read(std.stdio.stdin.fileno(), buffer.ptr, 1);
		if ((brokenTerminalUTFMouse == true) && (state == STATE.MOUSE)) {
		    // This terminal is sending non-UTF8 characters in its
		    // mouse reporting.  Do not decode stuff, just return
		    // buffer[0].
		    return buffer[0];
		}

		size_t len = 0;
		if ((buffer[0] & 0xF0) == 0xF0) {
		    // 3 more bytes coming
		    len = 3;
		} else if ((buffer[0] & 0xE0) == 0xE0) {
		    // 2 more bytes coming
		    len = 2;
		} else if ((buffer[0] & 0xC0) == 0xC0) {
		    // 1 more byte coming
		    len = 1;
		}
		read(std.stdio.stdin.fileno(), cast(void *)(buffer.ptr) + 1, len);
		size_t i;
		return decode(buffer, i);
	    } catch (UTFException e) {
		if (state == STATE.MOUSE) {
		    // The terminal we are using (e.g. gnome-terminal,
		    // xfce4-terminal, or others) is sending non-UTF8
		    // characters for the mouse reporting.
		    brokenTerminalUTFMouse = true;
		}

		// Trash this code.
		reset();
		return 0;
	    }
	}
    }

    // private import core.stdc.errno;
    // private import core.stdc.string;

    /**
     * See if getCharSocket() will return something.
     *
     * Returns:
     *    true if there is a backlog of characters waiting to be read
     */
    public bool backlog() {
	return (socketChars.length > 0);
    }

    /**
     * Read one Unicode code point from socket.
     *
     * Returns:
     *    one Unicode code point
     */
    public dchar getCharSocket() {
	assert(socket !is null);

    getCharSocketReturn:
	// Return any dchars already read
	if (socketChars.length > 0) {
	    dchar ch = socketChars[0];
	    socketChars = socketChars[1 .. $];
	    // std.stdio.stderr.writefln("---> return ch: %x %c", ch, ch);
	    return ch;
	}
	assert(socketChars.length == 0);

	// Process any bytes in socketReadBuffer
	while (socketReadBufferN > 0) {
	    // std.stdio.stderr.writefln("socketReadBufferN: %d", socketReadBufferN);

	    char[4] buffer;
	    buffer[0] = socketReadBuffer[0];

	    if ((brokenTerminalUTFMouse == true) && (state == STATE.MOUSE)) {
		// This terminal is sending non-UTF8 characters in its mouse
		// reporting.  Do not decode stuff, just return buffer[0].
		socketChars ~= buffer[0];
		// Manually perform the array copy
		for (auto i = 0; i < socketReadBufferN - 1; i++) {
		    socketReadBuffer[i] = socketReadBuffer[i + 1];
		}
		socketReadBufferN -= 1;
		goto getCharSocketReturn;
	    }

	    size_t len = 1;
	    if ((buffer[0] & 0xF0) == 0xF0) {
		// 3 more bytes coming
		len += 3;
	    } else if ((buffer[0] & 0xE0) == 0xE0) {
		// 2 more bytes coming
		len += 2;
	    } else if ((buffer[0] & 0xC0) == 0xC0) {
		// 1 more byte coming
		len += 1;
	    }
	    if (socketReadBufferN < len) {
		// Still waiting on more data, bail out
		break;
	    }
	    buffer[0 .. len] = socketReadBuffer[0 .. len];
	    try {
		size_t i;
		socketChars ~= decode(buffer, i);
		// std.stdio.stderr.writefln("appended: %02x %c", socketChars[$ - 1], socketChars[$ - 1]);
	    } catch (UTFException e) {
		if (state == STATE.MOUSE) {
		    // The terminal we are using (e.g. gnome-terminal,
		    // xfce4-terminal, or others) is sending non-UTF8
		    // characters for the mouse reporting.
		    brokenTerminalUTFMouse = true;
		    socketChars.length = 0;
		}

		// Trash this code.
		reset();
		break;
	    }
	    // Manually perform the array copy
	    for (auto i = 0; i < socketReadBufferN - len; i++) {
		socketReadBuffer[i] = socketReadBuffer[i + len];
	    }
	    socketReadBufferN -= len;
	}

	if (socketChars.length > 0) {
	    // Found a character, return it
	    goto getCharSocketReturn;
	}

	if (socketReadBufferN > 0) {
	    // Still waiting on more data, bail out
	    return 0;
	}

	// Read more data
	auto rc = socket.receive(socketReadBuffer);
	// std.stdio.stderr.writefln("rc = %d", rc);
	if (rc == 0) {
	    // Remote side closed connection.  Let ECMABackend report
	    // that the socket is closed.
	    socket.shutdown(SocketShutdown.BOTH);
	    socketAlive = false;
	    socketReadBufferN = 0;
	    return 0;
	}
	if (rc < 0) {
	    if (errno == EAGAIN) {
		return 0;
	    }

	    // Some other error.  Let ECMABackend report that the socket
	    // is closed.
	    // std.stdio.stderr.writefln("SHUTDOWN socket: %d %s", errno, to!string(strerror(errno)));
	    socket.shutdown(SocketShutdown.BOTH);
	    socketAlive = false;
	    socketReadBufferN = 0;
	    return 0;
	}
	socketReadBufferN += rc;
	goto getCharSocketReturn;
    }

    /**
     * Get the width of the physical console.
     *
     * Returns:
     *    width of console stdin is attached to
     */
    public uint getPhysicalWidth() {
	if (socket is null) {
	    version(Posix) {
		// We use TIOCGWINSZ
		winsize consoleSize;
		if (ioctl(std.stdio.stdin.fileno(), TIOCGWINSZ, &consoleSize) < 0) {
		    // Error.  So assume 80
		    return 80;
		}
		if (consoleSize.ws_col == 0) {
		    // Error.  So assume 80
		    return 80;
		}
		return consoleSize.ws_col;
	    }
	}
	// TODO: let TelnetSocket et al. set the window size
	return 80;
    }

    /**
     * Get the height of the physical console.
     *
     * Returns:
     *    height of console stdin is attached to
     */
    public uint getPhysicalHeight() {
	if (socket is null) {
	    version(Posix) {
		// We use TIOCGWINSZ
		winsize consoleSize;
		if (ioctl(std.stdio.stdin.fileno(), TIOCGWINSZ, &consoleSize) < 0) {
		    // Error.  So assume 24
		    return 24;
		}
		if (consoleSize.ws_row == 0) {
		    // Error.  So assume 24
		    return 24;
		}
		return consoleSize.ws_row;
	    }
	}
	// TODO: let TelnetSocket et al. set the window size
	return 24;
    }

    /**
     * Produce a control character or one of the special ones (ENTER,
     * TAB, etc.)
     *
     * Params:
     *    ch = Unicode code point
     *
     * Returns:
     *
     *    one KEYPRESS event, either a control character (e.g. isKey == false, ch == 'A', ctrl == true), or a special key (e.g. isKey == true, fnKey == ESC)
     */
    private TKeypressEvent controlChar(dchar ch) {
	TKeypressEvent event = new TKeypressEvent();

	// std.stdio.stderr.writef("controlChar: %02x\n", ch);

	switch (ch) {
	case '\r':
	    // ENTER
	    event.key = kbEnter;
	    break;
	case C_ESC:
	    // ESC
	    event.key = kbEsc;
	    break;
	case '\t':
	    // TAB
	    event.key = kbTab;
	    break;
	default:
	    // Make all other control characters come back as the
	    // alphabetic character with the ctrl field set.  So SOH
	    // would be 'A' + ctrl.
	    event.key = TKeypress(false, 0, ch + 0x40, false, true, false);
	    break;
	}
	return event;
    }

    /**
     * Produce special key from CSI Pn ; Pm ; ... ~
     *
     * Returns:
     *    one KEYPRESS event representing a special key
     */
    private TInputEvent csiFnKey() {
	int key = 0;
	int modifier = 0;
	if (params.length > 0) {
	    key = to!(int)(params[0]);
	}
	if (params.length > 1) {
	    modifier = to!(int)(params[1]);
	}
	TKeypressEvent event = new TKeypressEvent();

	switch (modifier) {
	case 0:
	    // No modifier
	    switch (key) {
	    case 1:
		event.key = kbHome;
		break;
	    case 2:
		event.key = kbIns;
		break;
	    case 3:
		event.key = kbDel;
		break;
	    case 4:
		event.key = kbEnd;
		break;
	    case 5:
		event.key = kbPgUp;
		break;
	    case 6:
		event.key = kbPgDn;
		break;
	    case 15:
		event.key = kbF5;
		break;
	    case 17:
		event.key = kbF6;
		break;
	    case 18:
		event.key = kbF7;
		break;
	    case 19:
		event.key = kbF8;
		break;
	    case 20:
		event.key = kbF9;
		break;
	    case 21:
		event.key = kbF10;
		break;
	    case 23:
		event.key = kbF11;
		break;
	    case 24:
		event.key = kbF12;
		break;
	    default:
		// Unknown
		delete event;
		return null;
	    }

	    break;
	case 2:
	    // Shift
	    switch (key) {
	    case 1:
		event.key = kbShiftHome;
		break;
	    case 2:
		event.key = kbShiftIns;
		break;
	    case 3:
		event.key = kbShiftDel;
		break;
	    case 4:
		event.key = kbShiftEnd;
		break;
	    case 5:
		event.key = kbShiftPgUp;
		break;
	    case 6:
		event.key = kbShiftPgDn;
		break;
	    case 15:
		event.key = kbShiftF5;
		break;
	    case 17:
		event.key = kbShiftF6;
		break;
	    case 18:
		event.key = kbShiftF7;
		break;
	    case 19:
		event.key = kbShiftF8;
		break;
	    case 20:
		event.key = kbShiftF9;
		break;
	    case 21:
		event.key = kbShiftF10;
		break;
	    case 23:
		event.key = kbShiftF11;
		break;
	    case 24:
		event.key = kbShiftF12;
		break;
	    default:
		// Unknown
		delete event;
		return null;
	    }
	    break;

	case 3:
	    // Alt
	    switch (key) {
	    case 1:
		event.key = kbAltHome;
		break;
	    case 2:
		event.key = kbAltIns;
		break;
	    case 3:
		event.key = kbAltDel;
		break;
	    case 4:
		event.key = kbAltEnd;
		break;
	    case 5:
		event.key = kbAltPgUp;
		break;
	    case 6:
		event.key = kbAltPgDn;
		break;
	    case 15:
		event.key = kbAltF5;
		break;
	    case 17:
		event.key = kbAltF6;
		break;
	    case 18:
		event.key = kbAltF7;
		break;
	    case 19:
		event.key = kbAltF8;
		break;
	    case 20:
		event.key = kbAltF9;
		break;
	    case 21:
		event.key = kbAltF10;
		break;
	    case 23:
		event.key = kbAltF11;
		break;
	    case 24:
		event.key = kbAltF12;
		break;
	    default:
		// Unknown
		delete event;
		return null;
	    }
	    break;

	case 5:
	    // Ctrl
	    switch (key) {
	    case 1:
		event.key = kbCtrlHome;
		break;
	    case 2:
		event.key = kbCtrlIns;
		break;
	    case 3:
		event.key = kbCtrlDel;
		break;
	    case 4:
		event.key = kbCtrlEnd;
		break;
	    case 5:
		event.key = kbCtrlPgUp;
		break;
	    case 6:
		event.key = kbCtrlPgDn;
		break;
	    case 15:
		event.key = kbCtrlF5;
		break;
	    case 17:
		event.key = kbCtrlF6;
		break;
	    case 18:
		event.key = kbCtrlF7;
		break;
	    case 19:
		event.key = kbCtrlF8;
		break;
	    case 20:
		event.key = kbCtrlF9;
		break;
	    case 21:
		event.key = kbCtrlF10;
		break;
	    case 23:
		event.key = kbCtrlF11;
		break;
	    case 24:
		event.key = kbCtrlF12;
		break;
	    default:
		// Unknown
		delete event;
		return null;
	    }
	    break;

	default:
	    // Unknown
	    delete event;
	    return null;
	}

	return event;
    }

    /**
     * Produce mouse events based on "Any event tracking" and UTF-8
     * coordinates.  See
     * http://invisible-island.net/xterm/ctlseqs/ctlseqs.html#Mouse%20Tracking
     *
     * Returns:
     *    One MOUSE_MOTION, MOUSE_UP, or MOUSE_DOWN event
     */
    private TInputEvent parseMouse() {
	dchar buttons = params[0][0] - 32;
	dchar x = params[0][1] - 32 - 1;
	dchar y = params[0][2] - 32 - 1;

	// Clamp X and Y to the physical screen coordinates.
	if (x >= windowResize.width) {
	    x = windowResize.width - 1;
	}
	if (y >= windowResize.height) {
	    y = windowResize.height - 1;
	}

	TMouseEvent event = new TMouseEvent(TMouseEvent.Type.MOUSE_DOWN);
	event.x = x;
	event.y = y;
	event.absoluteX = x;
	event.absoluteY = y;

	// std.stdio.stderr.writef("buttons: %04x\r\n", buttons);

	switch (buttons) {
	case 0:
	    event.mouse1 = true;
	    mouse1 = true;
	    break;
	case 1:
	    event.mouse2 = true;
	    mouse2 = true;
	    break;
	case 2:
	    event.mouse3 = true;
	    mouse3 = true;
	    break;
	case 3:
	    // Release or Move
	    if (!mouse1 && !mouse2 && !mouse3) {
		event.type = TMouseEvent.Type.MOUSE_MOTION;
	    } else {
		event.type = TMouseEvent.Type.MOUSE_UP;
	    }
	    if (mouse1) {
		mouse1 = false;
		event.mouse1 = true;
	    }
	    if (mouse2) {
		mouse2 = false;
		event.mouse2 = true;
	    }
	    if (mouse3) {
		mouse3 = false;
		event.mouse3 = true;
	    }
	    break;

	case 32:
	    // Dragging with mouse1 down
	    event.mouse1 = true;
	    mouse1 = true;
	    event.type = TMouseEvent.Type.MOUSE_MOTION;
	    break;

	case 33:
	    // Dragging with mouse2 down
	    event.mouse2 = true;
	    mouse2 = true;
	    event.type = TMouseEvent.Type.MOUSE_MOTION;
	    break;

	case 34:
	    // Dragging with mouse3 down
	    event.mouse3 = true;
	    mouse3 = true;
	    event.type = TMouseEvent.Type.MOUSE_MOTION;
	    break;

	case 96:
	    // Dragging with mouse2 down after wheelUp
	    event.mouse2 = true;
	    mouse2 = true;
	    event.type = TMouseEvent.Type.MOUSE_MOTION;
	    break;

	case 97:
	    // Dragging with mouse2 down after wheelDown
	    event.mouse2 = true;
	    mouse2 = true;
	    event.type = TMouseEvent.Type.MOUSE_MOTION;
	    break;

	case 64:
	    event.mouseWheelUp = true;
	    break;

	case 65:
	    event.mouseWheelDown = true;
	    break;

	default:
	    // Unknown, just make it motion
	    event.type = TMouseEvent.Type.MOUSE_MOTION;
	    break;
	}
	return event;
    }

    /**
     * Parses the next character of input to see if an InputEvent is
     * fully here.
     *
     * Params:
     *    ch = Unicode code point
     *    noChar = if true, ignore ch.  This is currently used to
     *    return a bare ESC and RESIZE events.
     *
     * Returns:
     *    list of new events (which may be empty)
     */
    public TInputEvent [] getEvents(dchar ch, bool noChar = false) {
	TInputEvent [] events;

	// ESCDELAY type timeout
	if (state == STATE.ESCAPE) {
	    long escDelay = Clock.currStdTime() - escapeTime;
	    // escDelay is in hnsecs, convert to millis
	    escDelay /= 10000;
	    if (escDelay > 250) {
		// After 0.25 seconds, assume a true escape character
		events ~= controlChar(C_ESC);
		reset();
	    }
	}

	if (noChar == true) {
	    auto newWidth = getPhysicalWidth();
	    auto newHeight = getPhysicalHeight();
	    if ((newWidth != windowResize.width) ||
		(newHeight != windowResize.height)) {
		TResizeEvent event = new TResizeEvent(TResizeEvent.Type.Screen,
		    newWidth, newHeight);
		windowResize.width = newWidth;
		windowResize.height = newHeight;
		events ~= event;
	    }

	    // Nothing else to do, bail out
	    return events;
	}

	// std.stdio.stderr.writef("state: %s ch %c\r\n", state, ch);

	switch (state) {
	case STATE.GROUND:

	    if (ch == C_ESC) {
		state = STATE.ESCAPE;
		escapeTime = Clock.currStdTime();
		return events;
	    }

	    if (ch <= 0x1F) {
		// Control character
		events ~= controlChar(ch);
		reset();
		return events;
	    }

	    if (ch >= 0x20) {
		// Normal character
		TKeypressEvent keypress = new TKeypressEvent();
		keypress.key.isKey = false;
		keypress.key.ch = ch;
		events ~= keypress;
		reset();
		return events;
	    }

	    break;

	case STATE.ESCAPE:
	    if (ch <= 0x1F) {
		// ALT-Control character
		TKeypressEvent keypress = controlChar(ch);
		keypress.key.alt = true;
		events ~= keypress;
		reset();
		return events;
	    }

	    if (ch == 'O') {
		// This will be one of the function keys
		state = STATE.ESCAPE_INTERMEDIATE;
		return events;
	    }

	    // '[' goes to STATE.CSI_ENTRY
	    if (ch == '[') {
		state = STATE.CSI_ENTRY;
		return events;
	    }

	    // Everything else is assumed to be Alt-keystroke
	    TKeypressEvent keypress = new TKeypressEvent();
	    keypress.key.isKey = false;
	    keypress.key.ch = ch;
	    keypress.key.alt = true;
	    if ((ch >= 'A') && (ch <= 'Z')) {
		keypress.key.shift = true;
	    }
	    events ~= keypress;
	    reset();
	    return events;

	case STATE.ESCAPE_INTERMEDIATE:
	    if ((ch >= 'P') && (ch <= 'S')) {
		// Function key
		TKeypressEvent keypress = new TKeypressEvent();
		keypress.key.isKey = true;
		switch (ch) {
		case 'P':
		    keypress.key.fnKey = TKeypress.F1;
		    break;
		case 'Q':
		    keypress.key.fnKey = TKeypress.F2;
		    break;
		case 'R':
		    keypress.key.fnKey = TKeypress.F3;
		    break;
		case 'S':
		    keypress.key.fnKey = TKeypress.F4;
		    break;
		default:
		    break;
		}
		events ~= keypress;
		reset();
		return events;
	    }

	    // Unknown keystroke, ignore
	    reset();
	    return events;

	case STATE.CSI_ENTRY:
	    // Numbers - parameter values
	    if ((ch >= '0') && (ch <= '9')) {
		params[paramI] ~= ch;
		state = STATE.CSI_PARAM;
		return events;
	    }
	    // Parameter separator
	    if (ch == ';') {
		paramI++;
		params.length++;
		params[paramI] = "";
		return events;
	    }

	    if ((ch >= 0x30) && (ch <= 0x7E)) {
		switch (ch) {
		case 'A':
		    // Up
		    TKeypressEvent keypress = new TKeypressEvent();
		    keypress.key.isKey = true;
		    keypress.key.fnKey = TKeypress.UP;
		    if (params.length > 1) {
			if (params[1] == "2") {
			    keypress.key.shift = true;
			}
			if (params[1] == "5") {
			    keypress.key.ctrl = true;
			}
			if (params[1] == "3") {
			    keypress.key.alt = true;
			}
		    }
		    events ~= keypress;
		    reset();
		    return events;
		case 'B':
		    // Down
		    TKeypressEvent keypress = new TKeypressEvent();
		    keypress.key.isKey = true;
		    keypress.key.fnKey = TKeypress.DOWN;
		    if (params.length > 1) {
			if (params[1] == "2") {
			    keypress.key.shift = true;
			}
			if (params[1] == "5") {
			    keypress.key.ctrl = true;
			}
			if (params[1] == "3") {
			    keypress.key.alt = true;
			}
		    }
		    events ~= keypress;
		    reset();
		    return events;
		case 'C':
		    // Right
		    TKeypressEvent keypress = new TKeypressEvent();
		    keypress.key.isKey = true;
		    keypress.key.fnKey = TKeypress.RIGHT;
		    if (params.length > 1) {
			if (params[1] == "2") {
			    keypress.key.shift = true;
			}
			if (params[1] == "5") {
			    keypress.key.ctrl = true;
			}
			if (params[1] == "3") {
			    keypress.key.alt = true;
			}
		    }
		    events ~= keypress;
		    reset();
		    return events;
		case 'D':
		    // Left
		    TKeypressEvent keypress = new TKeypressEvent();
		    keypress.key.isKey = true;
		    keypress.key.fnKey = TKeypress.LEFT;
		    if (params.length > 1) {
			if (params[1] == "2") {
			    keypress.key.shift = true;
			}
			if (params[1] == "5") {
			    keypress.key.ctrl = true;
			}
			if (params[1] == "3") {
			    keypress.key.alt = true;
			}
		    }
		    events ~= keypress;
		    reset();
		    return events;
		case 'H':
		    // Home
		    TKeypressEvent keypress = new TKeypressEvent();
		    keypress.key.isKey = true;
		    keypress.key.fnKey = TKeypress.HOME;
		    events ~= keypress;
		    reset();
		    return events;
		case 'F':
		    // End
		    TKeypressEvent keypress = new TKeypressEvent();
		    keypress.key.isKey = true;
		    keypress.key.fnKey = TKeypress.END;
		    events ~= keypress;
		    reset();
		    return events;
		case 'Z':
		    // CBT - Cursor backward X tab stops (default 1)
		    TKeypressEvent keypress = new TKeypressEvent();
		    keypress.key.isKey = true;
		    keypress.key.fnKey = TKeypress.BTAB;
		    events ~= keypress;
		    reset();
		    return events;
		case 'M':
		    // Mouse position
		    state = STATE.MOUSE;
		    return events;
		default:
		    break;
		}
	    }

	    // Unknown keystroke, ignore
	    reset();
	    return events;

	case STATE.CSI_PARAM:
	    // Numbers - parameter values
	    if ((ch >= '0') && (ch <= '9')) {
		params[paramI] ~= ch;
		state = STATE.CSI_PARAM;
		return events;
	    }
	    // Parameter separator
	    if (ch == ';') {
		paramI++;
		params.length++;
		params[paramI] = "";
		return events;
	    }

	    if (ch == '~') {
		events ~= csiFnKey();
		reset();
		return events;
	    }

	    if ((ch >= 0x30) && (ch <= 0x7E)) {
		switch (ch) {
		case 'A':
		    // Up
		    TKeypressEvent keypress = new TKeypressEvent();
		    keypress.key.isKey = true;
		    keypress.key.fnKey = TKeypress.UP;
		    if (params.length > 1) {
			if (params[1] == "2") {
			    keypress.key.shift = true;
			}
			if (params[1] == "5") {
			    keypress.key.ctrl = true;
			}
			if (params[1] == "3") {
			    keypress.key.alt = true;
			}
		    }
		    events ~= keypress;
		    reset();
		    return events;
		case 'B':
		    // Down
		    TKeypressEvent keypress = new TKeypressEvent();
		    keypress.key.isKey = true;
		    keypress.key.fnKey = TKeypress.DOWN;
		    if (params.length > 1) {
			if (params[1] == "2") {
			    keypress.key.shift = true;
			}
			if (params[1] == "5") {
			    keypress.key.ctrl = true;
			}
			if (params[1] == "3") {
			    keypress.key.alt = true;
			}
		    }
		    events ~= keypress;
		    reset();
		    return events;
		case 'C':
		    // Right
		    TKeypressEvent keypress = new TKeypressEvent();
		    keypress.key.isKey = true;
		    keypress.key.fnKey = TKeypress.RIGHT;
		    if (params.length > 1) {
			if (params[1] == "2") {
			    keypress.key.shift = true;
			}
			if (params[1] == "5") {
			    keypress.key.ctrl = true;
			}
			if (params[1] == "3") {
			    keypress.key.alt = true;
			}
		    }
		    events ~= keypress;
		    reset();
		    return events;
		case 'D':
		    // Left
		    TKeypressEvent keypress = new TKeypressEvent();
		    keypress.key.isKey = true;
		    keypress.key.fnKey = TKeypress.LEFT;
		    if (params.length > 1) {
			if (params[1] == "2") {
			    keypress.key.shift = true;
			}
			if (params[1] == "5") {
			    keypress.key.ctrl = true;
			}
			if (params[1] == "3") {
			    keypress.key.alt = true;
			}
		    }
		    events ~= keypress;
		    reset();
		    return events;
		default:
		    break;
		}
	    }

	    // Unknown keystroke, ignore
	    reset();
	    return events;

	case STATE.MOUSE:
	    params[0] ~= ch;
	    if (params[0].length == 3) {
		// We have enough to generate a mouse event
		events ~= parseMouse();
		reset();
	    }
	    return events;

	default:
	    break;
	}

	// This "should" be impossible to reach
	return events;
    }

    /**
     * Tell (u)xterm that we want alt- keystrokes to send escape +
     * character rather than set the 8th bit.  Anyone who wants UTF8
     * should want this enabled.
     *
     * Params:
     *    on = if true, enable metaSendsEscape
     *
     * Returns:
     *    the string to emit to xterm
     */
    public static string xtermMetaSendsEscape(bool on = true) {
	if (on) {
	    return "\033[?1036h\033[?1034l";
	}
	return "\033[?1036l";
    }

    /**
     * Convert a list of SGR parameters into a full escape sequence.
     * This also eliminates a trailing ';' which would otherwise reset
     * everything to white-on-black not-bold.
     *
     * Params:
     *    str = string of parameters, e.g. "31;1;"
     *
     * Returns:
     *    the string to emit to an ANSI / ECMA-style terminal, e.g. "\033[31;1m"
     */
    public static string addHeaderSGR(string str) {
	if (str.length > 0) {
	    // Nix any trailing ';' because that resets all attributes
	    if (str[$ - 1] == ';') {
		str = str[0 .. $ - 1];
	    }
	}
	return "\033[" ~ str ~ "m";
    }

    /**
     * Create a SGR parameter sequence for a single color change.
     *
     * Params:
     *    color = one of the Color.WHITE, Color.BLUE, etc. constants
     *    foreground = if true, this is a foreground color
     *    header = if true, make the full header, otherwise just emit
     *    the color parameter e.g. "42;"
     *
     * Returns:
     *    the string to emit to an ANSI / ECMA-style terminal, e.g. "\033[42m"
     */
    public static string color(Color color, bool foreground,
	bool header = true) {

	uint ecmaColor = color;

	// Convert Color.* values to SGR numerics
	if (foreground == true) {
	    ecmaColor += 30;
	} else {
	    ecmaColor += 40;
	}

	auto writer = appender!string();
	if (header) {
	    formattedWrite(writer, "\033[%dm", ecmaColor);
	} else {
	    formattedWrite(writer, "%d;", ecmaColor);
	}
	return writer.data;
    }

    /**
     * Create a SGR parameter sequence for both foreground and
     * background color change.
     *
     * Params:
     *    foreColor = one of the Color.WHITE, Color.BLUE, etc. constants
     *    backColor = one of the Color.WHITE, Color.BLUE, etc. constants
     *    header = if true, make the full header, otherwise just emit
     *    the color parameter e.g. "31;42;"
     *
     * Returns:
     *    the string to emit to an ANSI / ECMA-style terminal, e.g. "\033[31;42m"
     */
    public static string color(Color foreColor, Color backColor,
	bool header = true) {

	uint ecmaForeColor = foreColor;
	uint ecmaBackColor = backColor;

	// Convert Color.* values to SGR numerics
	ecmaBackColor += 40;
	ecmaForeColor += 30;

	auto writer = appender!string();
	if (header) {
	    formattedWrite(writer, "\033[%d;%dm", ecmaForeColor, ecmaBackColor);
	} else {
	    formattedWrite(writer, "%d;%d;", ecmaForeColor, ecmaBackColor);
	}
	return writer.data;
    }

    /**
     * Create a SGR parameter sequence for foreground, background, and
     * several attributes.  This sequence first resets all attributes
     * to default, then sets attributes as per the parameters.
     *
     * Params:
     *    foreColor = one of the Color.WHITE, Color.BLUE, etc. constants
     *    backColor = one of the Color.WHITE, Color.BLUE, etc. constants
     *    bold = if true, set bold
     *    reverse = if true, set reverse
     *    blink = if true, set blink
     *
     * Returns:
     *    the string to emit to an ANSI / ECMA-style terminal, e.g. "\033[0;1;31;42m"
     */
    public static string color(Color foreColor, Color backColor, bool bold,
	bool reverse, bool blink, bool underline) {

	uint ecmaForeColor = foreColor;
	uint ecmaBackColor = backColor;

	// Convert Color.* values to SGR numerics
	ecmaBackColor += 40;
	ecmaForeColor += 30;

	auto writer = appender!string();
	if        (  bold &&  reverse &&  blink && !underline ) {
	    writer.put("\033[0;1;7;5;");
	} else if (  bold &&  reverse && !blink && !underline ) {
	    writer.put("\033[0;1;7;");
	} else if ( !bold &&  reverse &&  blink && !underline ) {
	    writer.put("\033[0;7;5;");
	} else if (  bold && !reverse &&  blink && !underline ) {
	    writer.put("\033[0;1;5;");
	} else if (  bold && !reverse && !blink && !underline ) {
	    writer.put("\033[0;1;");
	} else if ( !bold &&  reverse && !blink && !underline ) {
	    writer.put("\033[0;7;");
	} else if ( !bold && !reverse &&  blink && !underline) {
	    writer.put("\033[0;5;");
	} else if (  bold &&  reverse &&  blink &&  underline ) {
	    writer.put("\033[0;1;7;5;4;");
	} else if (  bold &&  reverse && !blink &&  underline ) {
	    writer.put("\033[0;1;7;4;");
	} else if ( !bold &&  reverse &&  blink &&  underline ) {
	    writer.put("\033[0;7;5;4;");
	} else if (  bold && !reverse &&  blink &&  underline ) {
	    writer.put("\033[0;1;5;4;");
	} else if (  bold && !reverse && !blink &&  underline ) {
	    writer.put("\033[0;1;4;");
	} else if ( !bold &&  reverse && !blink &&  underline ) {
	    writer.put("\033[0;7;4;");
	} else if ( !bold && !reverse &&  blink &&  underline) {
	    writer.put("\033[0;5;4;");
	} else if ( !bold && !reverse && !blink &&  underline) {
	    writer.put("\033[0;4;");
	} else {
	    assert(!bold && !reverse && !blink && !underline);
	    writer.put("\033[0;");
	}
	formattedWrite(writer, "%d;%dm", ecmaForeColor, ecmaBackColor);
	return writer.data;
    }

    /**
     * Create a SGR parameter sequence for enabling reverse color.
     *
     * Params:
     *    on = if true, turn on reverse
     *
     * Returns:
     *    the string to emit to an ANSI / ECMA-style terminal, e.g. "\033[7m"
     */
    public static string reverse(bool on) {
	if (on) {
	    return "\033[7m";
	}
	return "\033[27m";
    }

    /**
     * Create a SGR parameter sequence to reset to defaults.
     *
     * Params:
     *    header = if true, make the full header, otherwise just emit
     *    the bare parameter e.g. "0;"
     *
     * Returns:
     *    the string to emit to an ANSI / ECMA-style terminal, e.g. "\033[0m"
     */
    public static string normal(bool header = true) {
	if (header) {
	    return "\033[0;37;40m";
	}
	return "0;37;40";
    }

    /**
     * Create a SGR parameter sequence for enabling boldface.
     *
     * Params:
     *    on = if true, turn on bold
     *    header = if true, make the full header, otherwise just emit
     *    the bare parameter e.g. "1;"
     *
     * Returns:
     *    the string to emit to an ANSI / ECMA-style terminal, e.g. "\033[1m"
     */
    public static string bold(bool on, bool header = true) {
	if (header) {
	    if (on) {
		return "\033[1m";
	    }
	    return "\033[22m";
	}
	if (on) {
	    return "1;";
	}
	return "22;";
    }

    /**
     * Create a SGR parameter sequence for enabling blinking text.
     *
     * Params:
     *    on = if true, turn on blink
     *    header = if true, make the full header, otherwise just emit
     *    the bare parameter e.g. "5;"
     *
     * Returns:
     *    the string to emit to an ANSI / ECMA-style terminal, e.g. "\033[5m"
     */
    public static string blink(bool on, bool header = true) {
	if (header) {
	    if (on) {
		return "\033[5m";
	    }
	    return "\033[25m";
	}
	if (on) {
	    return "5;";
	}
	return "25;";
    }

    /**
     * Create a SGR parameter sequence for enabling underline /
     * underscored text.
     *
     * Params:
     *    on = if true, turn on underline
     *
     * Returns:
     *    the string to emit to an ANSI / ECMA-style terminal, e.g. "\033[4m"
     */
    public static string underline(bool on) {
	if (on) {
	    return "\033[4m";
	}
	return "\033[24m";
    }

    /**
     * Create a SGR parameter sequence for enabling the visible cursor.
     *
     * Params:
     *    on = if true, turn on cursor
     *
     * Returns:
     *    the string to emit to an ANSI / ECMA-style terminal
     */
    public string cursor(bool on) {
	if (on && (cursorOn == false)) {
	    cursorOn = true;
	    return "\033[?25h";
	}
	if (!on && (cursorOn == true)) {
	    cursorOn = false;
	    return "\033[?25l";
	}
	return "";
    }

    /**
     * Clear the entire screen.  Because some terminals use back-color-erase,
     * set the color to white-on-black beforehand.
     *
     * Returns:
     *    the string to emit to an ANSI / ECMA-style terminal
     */
    public static string clearAll() {
	return "\033[0;37;40m\033[2J";
    }

    /**
     * Clear the line from the cursor (inclusive) to the end of the screen.
     * Because some terminals use back-color-erase, set the color to
     * white-on-black beforehand.
     *
     * Returns:
     *    the string to emit to an ANSI / ECMA-style terminal
     */
    public static string clearRemainingLine() {
	return "\033[0;37;40m\033[K";
    }

    /**
     * Clear the line up the cursor (inclusive).  Because some terminals use
     * back-color-erase, set the color to white-on-black beforehand.
     *
     * Returns:
     *    the string to emit to an ANSI / ECMA-style terminal
     */
    public static string clearPreceedingLine() {
	return "\033[0;37;40m\033[1K";
    }

    /**
     * Clear the line.  Because some terminals use back-color-erase, set the
     * color to white-on-black beforehand.
     *
     * Returns:
     *    the string to emit to an ANSI / ECMA-style terminal
     */
    public static string clearLine() {
	return "\033[0;37;40m\033[2K";
    }

    /**
     * Move the cursor to the top-left corner.
     *
     * Returns:
     *    the string to emit to an ANSI / ECMA-style terminal
     */
    public static string home() {
	return "\033[H";
    }

    /**
     * Move the cursor to (x, y).
     *
     * Params:
     *    x = column coordinate.  0 is the left-most column.
     *    y = row coordinate.  0 is the top-most row.
     *
     * Returns:
     *    the string to emit to an ANSI / ECMA-style terminal
     */
    public static string gotoXY(uint x, uint y) {
	auto writer = appender!string();
	formattedWrite(writer, "\033[%d;%dH", y + 1, x + 1);
	return writer.data;
    }

    /**
     * Tell (u)xterm that we want to receive mouse events based on
     * "Any event tracking" and UTF-8 coordinates.  See
     * http://invisible-island.net/xterm/ctlseqs/ctlseqs.html#Mouse%20Tracking
     *
     * Finally, this sets the alternate screen buffer.
     *
     * Params:
     *    on = if true, enable mouse report
     *
     * Returns:
     *    the string to emit to xterm
     */
    public static string mouse(bool on) {
	if (on) {
	    return "\033[?1003;1005h\033[?1049h";
	}
	return "\033[?1003;1005l\033[?1049l";
    }

};

/**
 * This class uses an xterm/ANSI/ECMA-type terminal to provide a
 * screen, keyboard, and mouse to TApplication.
 */
public class ECMABackend : Backend {

    /// Input events are processed by this Terminal.
    private ECMATerminal terminal;

    /// Socket to the remote user, or null if using stdio
    private Socket socket;

    /**
     * Public constructor.
     *
     * Params:
     *    socket = remote socket to the user, or null if using stdio.  Note that the socket must be in blocking mode.
     */
    public this(Socket socket = null) {
	this.socket = socket;

	// Create a terminal and explicitly set stdin into raw mode
	terminal = new ECMATerminal(socket);

	// Create a screen
	screen = new ECMAScreen(terminal);

	// Reset the screen size
	screen.setDimensions(terminal.getPhysicalWidth(),
	    terminal.getPhysicalHeight());

	// Clear the screen
	terminal.writef(terminal.clearAll());
	terminal.flush();
    }

    /**
     * Sync the logical screen to the physical device.
     */
    override public void flushScreen() {
	screen.flushPhysical();
    }

    // We use select() in getEvents()
    SocketSet readSockets = new SocketSet();
    SocketSet writeSockets = new SocketSet();
    SocketSet exceptSockets = new SocketSet();

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

	if (socket is null) {
	    version(Posix) {
		// Poll on stdin.
		pollfd pfd;
		pfd.fd = std.stdio.stdin.fileno();
		pfd.events = POLLIN;
		pfd.revents = 0;
		auto poll_rc = poll(&pfd, 1, timeout);
		if (poll_rc > 0) {
		    // We have something to read
		    dchar ch = terminal.getCharStdin();
		    return terminal.getEvents(ch);
		}
	    }
	} else {
	    if (!terminal.socketAlive) {
		events ~= new TCommandEvent(cmAbort);
		return events;
	    }

	    // Select on the socket.  Last parameter is microseconds,
	    // so convert to millis.
	    readSockets.reset();
	    writeSockets.reset();
	    exceptSockets.reset();
	    readSockets.add(socket);

	    // For now, disregard writeSockets and exceptSockets.
	    // exceptSockets.add(socket);
	    // writeSockets.add(socket);
	    auto rc = Socket.select(readSockets, writeSockets,
		exceptSockets, timeout * 1000);

	    if (rc < 0) {
		if (errno != EAGAIN) {
		    // Interrupt or other error
		    // std.stdio.stderr.writefln("ERROR select(): %d %s", errno, to!string(strerror(errno)));
		    // std.stdio.stderr.flush();
		}
	    }

	    if (rc == 0) {
		// Timeout
		events ~= terminal.getEvents(0, true);
	    }

	    if ((rc > 0) && (readSockets.isSet(socket))) {
		// socket is readable, go get data
		dchar ch = terminal.getCharSocket();
		events ~= terminal.getEvents(ch);
	    }
	}

	while (terminal.backlog()) {
	    // We had something from the last read
	    dchar ch = terminal.getCharSocket();
	    events ~= terminal.getEvents(ch);
	}

	// Timeout case
	return events;
    }

    /**
     * Subclasses must provide an implementation that closes sockets,
     * restores console, etc.
     */
    override public void shutdown() {
	terminal.shutdown();
    }

}

// Functions -----------------------------------------------------------------
