/**
 * D Text User Interface library - TTerminal class
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

import std.file;
import std.process;
import std.stdio;
import std.string;
import std.utf;
import base;
import codepage;
import tapplication;
import twindow;

// Defines -------------------------------------------------------------------

private immutable size_t ECMA48_PARAM_LENGTH = 16;
private immutable size_t ECMA48_PARAM_MAX = 16;

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * This is a base class for complex ANSI ECMA-48/ISO 6429/ANSI X3.64 type
 * consoles.  It currently lacks a scrollback buffer.
 */
private class ECMA48 {

    /// This represents a single line of the display buffer
    private class DisplayLine {

	/// The characters/attributes of the line
	public Cell [] chars;

	/// Double-width line
	public bool doubleWidth = false;

	/**
	 * Double-height line flag:
	 *
	 *   0 = single height
	 *   1 = top half double height
	 *   2 = bottom half double height
	 */
	public int doubleHeight = 0;
	
	/// DECSCNM - reverse video
	public bool reverseColor = false;

	/// Constructor sets everything to normal attributes
	public this() {
	    chars.length = 255;
	    for (auto i = 0; i < chars.length; i++) {
		chars[i] = new Cell();
	    }
	}

    };

    /// This class represents a Display buffer
    private class Display {

	/// The raw buffer characters + attributes
	private DisplayLine [] buffer;

	/// The current editing X position in the scrollback buffer
	public uint cursorX = 0;

	/// The current editing Y position in the scrollback buffer
	public uint cursorY = 0;

	/// Display width.  This is generalized here, but in practice will be
	/// either 80 or 132.
	public uint width = 80;

	/// Display height.  This will always be 24 for now.
	public static immutable uint height = 24;


	/// Constructor
	public this() {
	    for (auto i = 0; i < height; i++) {
		buffer ~= new DisplayLine();
	    }
	}

	/**
	 * Wrap a line.
	 */
	private void wrapCurrentLine() {
	    // Wrap the line
	    if (cursorY < display.height - 1) {
		cursorY++;
	    } else {
		// Wrap the top line off the buffer
		buffer = buffer[1 .. $];
		buffer ~= new DisplayLine();
	    }
	    cursorX = 0;
	}

	/*
	public void cursor_up(const int count, const bool honor_scroll_region);
	public void cursor_down(const int count, const bool honor_scroll_region);
	public void cursor_left(const int count, const bool honor_scroll_region);
	public void cursor_right(const int count, const bool honor_scroll_region);
	public void cursor_position(int row, int col);
	public void erase_line(const int start, const int end, const bool honor_protected);
	public void fill_line_with_character(const int start, const int end, wchar_t character, const bool honor_protected);
	public void erase_screen(const int start_row, const int start_col, const int end_row, const int end_col, const bool honor_protected);
	public void cursor_formfeed();
	public void cursor_carriage_return();
	public void cursor_linefeed(const bool new_line_mode);
	public void scrolling_region_scroll_down(const int region_top, const int region_bottom, const int count);
	public void scrolling_region_scroll_up(const int region_top, const int region_bottom, const int count);
	public void scroll_down(const int count);
	public void scroll_up(const int count);
	public void delete_character(const int count);
	public void insert_blanks(const int count);
	public void invert_scrollback_colors();
	public void deinvert_scrollback_colors();
	public void set_double_width(Q_BOOL double_width);
	public void set_double_height(int double_height);
	 */
    }

    /// The display buffer
    public Display display;
	    
    /// The current rendering color
    private CellAttributes currentColor;

    /// Right margin
    private uint rightMargin;

    /**
     * VT100-style line wrapping: a character is placed in column 80 (or
     * 132), but the line does NOT wrap until another character is written to
     * column 1 of the next line, after which the cursor moves to column 2.
     */
    private bool wrapLineFlag;

    // Local buffer for multiple returned characters.
    dchar [] emul_buffer;

    /// Parser character scan states
    enum SCAN_STATE {
	SCAN_GROUND,
	SCAN_ESCAPE,
	SCAN_ESCAPE_INTERMEDIATE,
	SCAN_CSI_ENTRY,
	SCAN_CSI_PARAM,
	SCAN_CSI_INTERMEDIATE,
	SCAN_CSI_IGNORE,
	SCAN_DCS_ENTRY,
	SCAN_DCS_INTERMEDIATE,
	SCAN_DCS_PARAM,
	SCAN_DCS_PASSTHROUGH,
	SCAN_DCS_IGNORE,
	SCAN_SOSPMAPC_STRING,
	SCAN_OSC_STRING,
	SCAN_VT52_DIRECT_CURSOR_ADDRESS };

    /// Current scanning state
    private SCAN_STATE scanState;


    /**
     * Prints one character to the scrollback buffer.
     *
     * Params:
     *     ch = character to display
     */
    void printCharacter(dchar ch) {
	size_t rightMargin = this.rightMargin;

	// BEL
	if (ch == 0x07) {
	    // screen_beep();
	    return;
	}

	// Check if we have double-width, and if so chop at 40/66 instead of 80/132
	if (display.buffer[display.cursorY].doubleWidth == true) {
	    rightMargin = ((rightMargin + 1) / 2) - 1;
	}

	// Check the unusually-complicated line wrapping conditions...
	if (display.cursorX == rightMargin) {

	    /*
	     * This case happens when: the cursor was already on the right
	     * margin (either through printing or by an explicit placement
	     * command), and a character was printed.
	     * 
	     * For VT100-ish terminals, the line wraps only when a new
	     * character arrives AND the cursor is already on the right
	     * margin AND has placed a character in its cell.  Easier to see
	     * than to explain.
	     */
	    if (wrapLineFlag == false) {
		/*
		 * This block marks the case that we are
		 * in the margin and the first character
		 * has been received and printed.
		 */
		wrapLineFlag = true;
	    } else {
		/*
		 * This block marks the case that we are in the margin and
		 * the second character has been received and printed.
		 */
		wrapLineFlag = false;
		display.wrapCurrentLine();
	    }

	} else if (display.cursorX <= rightMargin) {
	    /*
	     * This is the normal case: a character came in and was printed
	     * to the left of the right margin column.
	     */

	    // Turn off VT100 special-case flag
	    wrapLineFlag = false;
	}

	// "Print" the character
	Cell newCell = new Cell(ch);
	CellAttributes newCellAttributes = cast(CellAttributes)newCell;
	newCellAttributes.setTo(currentColor);
	// Insert mode special case
	if (state.insertMode == true) {
	    display.buffer[display.cursorY].chars =
		    display.buffer[display.cursorY].chars[0 .. display.cursorX] ~
		    newCell ~
		    display.buffer[display.cursorY].chars[display.cursorX .. $ - 1];
	} else {
	    // Replace an existing character
	    display.buffer[display.cursorY].chars[display.cursorX] = newCell;
	}

	// Increment horizontal
	if (wrapLineFlag == false) {
	    display.cursorX++;
	    if (display.cursorX > rightMargin) {
		display.cursorX--;
	    }
	}
    }

    enum Q_KEYPAD_MODE {
	/// Application mode
	Q_KEYPAD_MODE_APPLICATION,
	/// Numeric mode
	Q_KEYPAD_MODE_NUMERIC };

    /// Available terminal emulation modes.
    enum Q_EMULATION {
	Q_EMUL_ANSI,
	Q_EMUL_VT52,
	Q_EMUL_VT100,
	};

    struct q_keypad_mode {
	Q_EMULATION emulation;
	Q_KEYPAD_MODE keypad_mode;
    };

    /// Available character sets
    enum VT100_CHARACTER_SET {
	CHARSET_US,
	CHARSET_UK,
	CHARSET_DRAWING,
	CHARSET_ROM,
	CHARSET_ROM_SPECIAL,
	CHARSET_VT52_GRAPHICS,
	CHARSET_DEC_SUPPLEMENTAL,
	CHARSET_NRC_DUTCH,
	CHARSET_NRC_FINNISH,
	CHARSET_NRC_FRENCH,
	CHARSET_NRC_FRENCH_CA,
	CHARSET_NRC_GERMAN,
	CHARSET_NRC_ITALIAN,
	CHARSET_NRC_NORWEGIAN,
	CHARSET_NRC_SPANISH,
	CHARSET_NRC_SWEDISH,
	CHARSET_NRC_SWISS };

    /// Single-shift states
    enum SINGLESHIFT {
	SS_NONE,
	SS2,
	SS3 };

    /// VT220 lockshift states
    enum LOCKSHIFT_MODE {
	LOCKSHIFT_NONE,
	LOCKSHIFT_G1_GR,
	LOCKSHIFT_G2_GR,
	LOCKSHIFT_G2_GL,
	LOCKSHIFT_G3_GR,
	LOCKSHIFT_G3_GL };

    /// The various states of a virtual VT100/VT220 type terminal.
    private struct vt100_state {

	/// VT220 single shift flag
	SINGLESHIFT singleshift = SINGLESHIFT.SS_NONE;

	/// true = insert characters, false = overwrite
	bool insertMode = false;

	/// VT52 mode.  True means VT52, false means ANSI. Default is ANSI.
	bool vt52_mode = false;

	/// DEC private mode flag, set when CSI is followed by '?'
	bool dec_private_mode_flag = false;

	/// When true, use the G1 character set
	bool shift_out = false;

	/// When true, cursor positions are relative to the scrolling region
	bool saved_origin_mode = false;

	/// When true, the terminal is in 132-column mode
	bool columns_132 = false;

	/// Which character set is currently selected in G0
	VT100_CHARACTER_SET g0_charset = VT100_CHARACTER_SET.CHARSET_US;

	/// Which character set is currently selected in G1
	VT100_CHARACTER_SET g1_charset = VT100_CHARACTER_SET.CHARSET_DRAWING;

	// Saved cursor position
	int saved_cursor_x = -1;
	int saved_cursor_y = -1;

	/// Horizontal tab stops
	int [] tab_stops;

	/// Saved drawing attributes
	CellAttributes saved_attributes;
	VT100_CHARACTER_SET saved_g0_charset = VT100_CHARACTER_SET.CHARSET_US;
	VT100_CHARACTER_SET saved_g1_charset = VT100_CHARACTER_SET.CHARSET_DRAWING;

	// VT220

	/// S8C1T.  True means 8bit controls, false means 7bit controls.
	bool s8c1t_mode = false;

	/// Printer mode.  True means send all output to printer, which discards it.
	bool printer_controller_mode = false;

	VT100_CHARACTER_SET g2_charset = VT100_CHARACTER_SET.CHARSET_US;
	VT100_CHARACTER_SET g3_charset = VT100_CHARACTER_SET.CHARSET_US;
	VT100_CHARACTER_SET gr_charset = VT100_CHARACTER_SET.CHARSET_DRAWING;

	VT100_CHARACTER_SET saved_g2_charset = VT100_CHARACTER_SET.CHARSET_US;
	VT100_CHARACTER_SET saved_g3_charset = VT100_CHARACTER_SET.CHARSET_US;
	VT100_CHARACTER_SET saved_gr_charset = VT100_CHARACTER_SET.CHARSET_DRAWING;

	/// VT220 saves linewrap flag on decsc()/decrc()
	bool saved_linewrap = true;

	/// VT220 saves lockshift flag on decsc()/decrc()
	LOCKSHIFT_MODE saved_lockshift_gl = LOCKSHIFT_MODE.LOCKSHIFT_NONE;
	LOCKSHIFT_MODE saved_lockshift_gr = LOCKSHIFT_MODE.LOCKSHIFT_NONE;

	/// When a lockshift command comes in
	LOCKSHIFT_MODE lockshift_gl = LOCKSHIFT_MODE.LOCKSHIFT_NONE;
	LOCKSHIFT_MODE lockshift_gr = LOCKSHIFT_MODE.LOCKSHIFT_NONE;

	/// Parameters characters being collected
	/// Sixteen rows with sixteen columns
	dchar [][] params;

	/// If true, cursor_linefeed() puts the cursor on the first
	/// column of the next line.  If false, cursor_linefeed() puts
	/// the cursor one line down on the current line.  The default
	/// is false.
	bool new_line_mode = false;

	/// Whether arrow keys send ANSI, VT100, or VT52 sequences
	Q_EMULATION arrow_keys;

	/// Whether number pad keys send VT100 or VT52, application or
	/// numeric sequences.
	q_keypad_mode keypad_mode;

    }

    /// The current terminal state
    private vt100_state state;

    /**
     * Clear the parameter list
     */
    private void clear_params() {
	state.params = new dchar[][](ECMA48_PARAM_MAX, ECMA48_PARAM_LENGTH);
	state.dec_private_mode_flag = false;
	emul_buffer.length = 0;
    }

    /**
     * Reset the tab stops list
     */
    private void reset_tab_stops() {
	state.tab_stops.length = 0;
	for (int i = 0; (i * 8) < display.width; i++) {
	    state.tab_stops.length++;
	    state.tab_stops[i] = i * 8;
	}
    }

    /**
     * Reset the emulation state
     */
    private void reset() {
	currentColor = new CellAttributes();

	scanState = SCAN_STATE.SCAN_GROUND;
	clear_params();

	// Reset vt100_state
	state.saved_cursor_x		= -1;
	state.saved_cursor_y		= -1;
	rightMargin			= 79;
	state.new_line_mode		= false;
	state.arrow_keys		= Q_EMULATION.Q_EMUL_ANSI;
	state.keypad_mode.keypad_mode	= Q_KEYPAD_MODE.Q_KEYPAD_MODE_NUMERIC;
	wrapLineFlag			= false;

	// Default character sets
	state.g0_charset		= VT100_CHARACTER_SET.CHARSET_US;
	state.g1_charset		= VT100_CHARACTER_SET.CHARSET_DRAWING;

	// Curses attributes representing normal
	state.saved_attributes = new CellAttributes();
	state.saved_attributes.setTo(currentColor);
	state.saved_origin_mode		= false;
	state.saved_g0_charset		= VT100_CHARACTER_SET.CHARSET_US;
	state.saved_g1_charset		= VT100_CHARACTER_SET.CHARSET_DRAWING;

	// Tab stops
	reset_tab_stops();

	// Flags
	state.shift_out			= false;
	state.vt52_mode			= false;
	state.insertMode		= false;
	state.dec_private_mode_flag	= false;
	state.columns_132		= false;

	// VT220
	state.singleshift		= SINGLESHIFT.SS_NONE;
	state.s8c1t_mode		= false;
	state.printer_controller_mode	= false;
	state.g2_charset		= VT100_CHARACTER_SET.CHARSET_US;
	state.g3_charset		= VT100_CHARACTER_SET.CHARSET_US;
	state.gr_charset		= VT100_CHARACTER_SET.CHARSET_DEC_SUPPLEMENTAL;
	state.lockshift_gl		= LOCKSHIFT_MODE.LOCKSHIFT_NONE;
	state.lockshift_gr		= LOCKSHIFT_MODE.LOCKSHIFT_NONE;
	state.saved_lockshift_gl	= LOCKSHIFT_MODE.LOCKSHIFT_NONE;
	state.saved_lockshift_gr	= LOCKSHIFT_MODE.LOCKSHIFT_NONE;

	state.saved_g2_charset		= VT100_CHARACTER_SET.CHARSET_US;
	state.saved_g3_charset		= VT100_CHARACTER_SET.CHARSET_US;
	state.saved_gr_charset		= VT100_CHARACTER_SET.CHARSET_DEC_SUPPLEMENTAL;
    }


    /// Public constructor
    public this() {
	display = new Display();
	reset();
    }

    /// Run this input character through the ECMA48 state machine
    public void consume(dchar ch) {
	// For now, print it all
	printCharacter(cp437_chars[ch & 0xFF]);




    }

    /**
     * Translate the keyboard press to a VT100 sequence.
     *
     * Params:
     *    keystroke = keypress received from the local user
     *
     * Returns:
     *    string to transmit to the remote side
     */
    public dstring keypress(TKeypress keystroke) {

	if (keystroke == kbBackspace) {
	    return "\177";
	}

	if (keystroke == kbLeft) {
	    switch (state.arrow_keys) {
	    case Q_EMULATION.Q_EMUL_ANSI:
		return "\033[D";
	    case Q_EMULATION.Q_EMUL_VT52:
		return "\033D";
	    default:
		return "\033OD";
	    }
	}

	if (keystroke == kbRight) {
	    switch (state.arrow_keys) {
	    case Q_EMULATION.Q_EMUL_ANSI:
		return "\033[C";
	    case Q_EMULATION.Q_EMUL_VT52:
		return "\033C";
	    default:
		return "\033OC";
	    }
	}
	
	if (keystroke == kbUp) {
	    switch (state.arrow_keys) {
	    case Q_EMULATION.Q_EMUL_ANSI:
		return "\033[A";
	    case Q_EMULATION.Q_EMUL_VT52:
		return "\033A";
	    default:
		return "\033OA";
	    }
	}
	
	if (keystroke == kbDown) {
	    switch (state.arrow_keys) {
	    case Q_EMULATION.Q_EMUL_ANSI:
		return "\033[B";
	    case Q_EMULATION.Q_EMUL_VT52:
		return "\033B";
	    default:
		return "\033OB";
	    }
	}
	
	if (keystroke == kbHome) {
	    switch (state.arrow_keys) {
	    case Q_EMULATION.Q_EMUL_ANSI:
		return "\033[H";
	    case Q_EMULATION.Q_EMUL_VT52:
		return "\033H";
	    default:
		return "\033OH";
	    }
	}
	
	if (keystroke == kbEnd) {
	    switch (state.arrow_keys) {
	    case Q_EMULATION.Q_EMUL_ANSI:
		return "\033[F";
	    case Q_EMULATION.Q_EMUL_VT52:
		return "\033F";
	    default:
		return "\033OF";
	    }
	}
	
	if (keystroke == kbF1) {
	    // PF1
	    switch (state.keypad_mode.emulation) {
	    case Q_EMULATION.Q_EMUL_VT52:
		return "\033P";
	    default:
		return "\033OP";
	    }
	}
	
	if (keystroke == kbF2) {
	    // PF2
	    switch (state.keypad_mode.emulation) {
	    case Q_EMULATION.Q_EMUL_VT52:
		return "\033Q";
	    default:
		return "\033OQ";
	    }
	}
	
	if (keystroke == kbF3) {
	    // PF3
	    switch (state.keypad_mode.emulation) {
	    case Q_EMULATION.Q_EMUL_VT52:
		return "\033R";
	    default:
		return "\033OR";
	    }
	}
	
	if (keystroke == kbF4) {
	    // PF4
	    switch (state.keypad_mode.emulation) {
	    case Q_EMULATION.Q_EMUL_VT52:
		return "\033S";
	    default:
		return "\033OS";
	    }
	}
	
	if (keystroke == kbF5) {
	    return "\033Ot";
	}
	
	if (keystroke == kbF6) {
	    return "\033Ou";
	}
	
	if (keystroke == kbF7) {
	    return "\033Ov";
	}
	
	if (keystroke == kbF8) {
	    return "\033Ol";
	}
	
	if (keystroke == kbF9) {
	    return "\033Ow";
	}
	
	if (keystroke == kbF10) {
	    return "\033Ox";
	}
	
	if (keystroke == kbF11) {
	    return "\033[23~";
	}
	
	if (keystroke == kbF12) {
	    return "\033[24~";
	}
	
	if (keystroke == kbShiftF1) {
	    // Shifted PF1
	    switch (state.keypad_mode.emulation) {
	    case Q_EMULATION.Q_EMUL_VT52:
		return "\0332P";
	    default:
		return "\033O2P";
	    }
	}
	
	if (keystroke == kbShiftF1) {
	    // Shifted PF2
	    switch (state.keypad_mode.emulation) {
	    case Q_EMULATION.Q_EMUL_VT52:
		return "\0332Q";
	    default:
		return "\033O2Q";
	    }
	}

	if (keystroke == kbShiftF1) {
	    // Shifted PF3
	    switch (state.keypad_mode.emulation) {
	    case Q_EMULATION.Q_EMUL_VT52:
		return "\0332R";
	    default:
		return "\033O2R";
	    }
	}
	
	if (keystroke == kbShiftF1) {
	    // Shifted PF4
	    switch (state.keypad_mode.emulation) {
	    case Q_EMULATION.Q_EMUL_VT52:
		return "\0332S";
	    default:
		return "\033O2S";
	    }
	}
	
	if (keystroke == kbShiftF1) {
	    // Shifted F5
	    return "\033[15;2~";
	}
	
	if (keystroke == kbShiftF1) {
	    // Shifted F6
	    return "\033[17;2~";
	}

	if (keystroke == kbShiftF1) {
	    // Shifted F7
	    return "\033[18;2~";
	}
	
	if (keystroke == kbShiftF1) {
	    // Shifted F8
	    return "\033[19;2~";
	}
	
	if (keystroke == kbShiftF1) {
	    // Shifted F9
	    return "\033[20;2~";
	}
	
	if (keystroke == kbShiftF1) {
	    // Shifted F10
	    return "\033[21;2~";
	}
	
	if (keystroke == kbShiftF1) {
	    // Shifted F11
	    return "\033[23;2~";
	}
	
	if (keystroke == kbShiftF1) {
	    // Shifted F12
	    return "\033[24;2~";
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control PF1
	    switch (state.keypad_mode.emulation) {
	    case Q_EMULATION.Q_EMUL_VT52:
		return "\0335P";
	    default:
		return "\033O5P";
	    }
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control PF2
	    switch (state.keypad_mode.emulation) {
	    case Q_EMULATION.Q_EMUL_VT52:
		return "\0335Q";
	    default:
		return "\033O5Q";
	    }
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control PF3
	    switch (state.keypad_mode.emulation) {
	    case Q_EMULATION.Q_EMUL_VT52:
		return "\0335R";
	    default:
		return "\033O5R";
	    }
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control PF4
	    switch (state.keypad_mode.emulation) {
	    case Q_EMULATION.Q_EMUL_VT52:
		return "\0335S";
	    default:
		return "\033O5S";
	    }
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control F5
	    return "\033[15;5~";
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control F6
	    return "\033[17;5~";
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control F7
	    return "\033[18;5~";
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control F8
	    return "\033[19;5~";
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control F9
	    return "\033[20;5~";
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control F10
	    return "\033[21;5~";
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control F11
	    return "\033[23;5~";
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control F12
	    return "\033[24;5~";
	}
	
	if (keystroke == kbPgUp) {
	    return "\033[5~";
	}
	
	if (keystroke == kbPgDn) {
	    return "\033[6~";
	}
	
	if (keystroke == kbIns) {
	    return "\033[2~";
	}
	
	if (keystroke == kbShiftIns) {
	    // This is what xterm sends for SHIFT-INS
	    return "\033[2;2~";
	    // This is what xterm sends for CTRL-INS
	    // return "\033[2;5~";
	}
	
	if (keystroke == kbShiftDel) {
	    // This is what xterm sends for SHIFT-DEL
	    return "\033[3;2~";
	    // This is what xterm sends for CTRL-DEL
	    // return "\033[3;5~";
	}
	
	if (keystroke == kbDel) {
	    // Delete sends real delete for VTxxx
	    return "\177";
	    // return "\033[3~";
	}
	
	if (keystroke == kbEnter) {
	    return "\015";
	}
    
	if (!keystroke.isKey) {
	    dstring str = "";
	    str ~= keystroke.ch;
	    return str;
	}
	return "";
    }

}

/**
 * TTerminal implements a ECMA-48 / ANSI X3.64 style terminal.
 */
public class TTerminal : TWindow {

    /// The emulator
    private ECMA48 emulator;

    /// The shell process
    private ProcessPipes process;

    /// If true, the process is still running
    private bool processRunning;

    // Used for raw mode
    version(Posix) {
	import core.sys.posix.termios;
	import core.sys.posix.unistd;
    }
    
    /**
     * Public constructor.
     *
     * Params:
     *    application = TApplication that manages this window
     *    x = column relative to parent
     *    y = row relative to parent
     *    flags = mask of CENTERED, or MODAL (RESIZABLE is stripped)
     */
    public this(TApplication application, int x, int y,
	Flag flags = Flag.CENTERED) {

	super(application, "Terminal", x, y, 80 + 2, 24 + 2, flags & ~Flag.RESIZABLE);
	emulator = new ECMA48();

	process = pipeProcess(["setsid", "/bin/bash", "-i"],
	    Redirect.stdin | Redirect.stderrToStdout | Redirect.stdout);

	version(Posix) {
	    termios newTermios;
	    termios oldTermios;
	    tcgetattr(process.stdout.fileno(), &oldTermios);
	    newTermios = oldTermios;
	    Terminal.cfmakeraw(&newTermios);
	    tcsetattr(process.stdout.fileno(), TCSANOW, &newTermios);
	}

	processRunning = true;
    }

    /// Draw the display buffer
    override public void draw() {
	// Draw the box using my superclass
	super.draw();
	int row = 1;
	foreach (line; emulator.display.buffer) {
	    for (auto i = 0; i < emulator.display.width; i++) {
		screen.putCharXY(i + 1, row, line.chars[i]);
	    }
	    row++;
	}
    }

    /**
     * Handle window close
     */
    override public void onClose() {
	if (processRunning) {
	    kill(process.pid);
	    processRunning = false;
	}
    }

    version(Posix) {
	// Used in doIdle() to poll process
	import core.sys.posix.poll;
    }

    /**
     * Poll data from the child process
     */
    override public void onIdle() {
	if (!processRunning) {
	    return;
	}
	pollfd pfd;
	int i = 0;
	int poll_rc = -1;
	do {
	    pfd.fd = process.stdout.fileno();
	    pfd.events = POLLIN;
	    pfd.revents = 0;
	    poll_rc = poll(&pfd, 1, 0);
	    if (poll_rc > 0) {
		application.repaint = true;

		// We have data, read it
		try {
		    dchar ch = Terminal.getCharFileno(process.stdout.fileno());
		    emulator.consume(ch);
		} catch (FileException e) {
		    // We got EOF, close the file
		    title = title ~ " (Offline)";
		    processRunning = false;
		    break;
		}
	    }
	    i++;
	} while ((poll_rc > 0) && (i < 1024)) ;
    }

    /**
     * Handle keystrokes.
     *
     * Params:
     *    event = keystroke event
     */
    override protected void onKeypress(TKeypressEvent event) {
	dstring response = emulator.keypress(event.key);
	process.stdin.write(response);
	process.stdin.flush();
    }

}

// Functions -----------------------------------------------------------------
