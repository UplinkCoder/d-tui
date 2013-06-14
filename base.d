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
 *		Screen.flush()
 *		Terminal.this() / ~this()
 *		Terminal.getEvents() needs to pull keyboard/mouse events
 *			from the Console
 *		Terminal.getPhysicalWidth()
 *		Terminal.getPhysicalHeight()
 *		Terminal.cursor(bool visible)
 *	Terminal:
 *	ColorTheme:
 *		Read from / write to file
 */

// Description ---------------------------------------------------------------

// Imports -------------------------------------------------------------------

import std.array;
import std.conv;
import std.datetime;
import std.file;
import std.format;
import std.string;
import std.stdio;
import std.utf;
import codepage;

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

/// Black.  Bold + black = dark grey
public static immutable ubyte COLOR_BLACK   = 0;

/// Red
public static immutable ubyte COLOR_RED     = 1;

/// Green
public static immutable ubyte COLOR_GREEN   = 2;

/// Yellow.  Sometimes not-bold yellow is brown
public static immutable ubyte COLOR_YELLOW  = 3;

/// Blue
public static immutable ubyte COLOR_BLUE    = 4;

/// Magenta (purple)
public static immutable ubyte COLOR_MAGENTA = 5;

/// Cyan (blue-green)
public static immutable ubyte COLOR_CYAN    = 6;

/// White
public static immutable ubyte COLOR_WHITE   = 7;

// Classes -------------------------------------------------------------------

/**
 * The attributes used by a Cell: color, bold, blink, etc.
 */
public class CellAttributes {

    //// Bold
    public bool bold;

    /// Blink
    public bool blink;

    /// Reverse
    public bool reverse;

    /// Underline
    public bool underline;

    /// Protected
    public bool protect;

    /// Foreground color.  COLOR_WHITE, COLOR_RED, etc.
    public ubyte foreColor;

    /// Background color.  COLOR_WHITE, COLOR_RED, etc.
    public ubyte backColor;

    /// Set to default not-bold, white foreground on black background
    public void reset() {
	bold = false;
	blink = false;
	reverse = false;
	protect = false;
	underline = false;
	foreColor = COLOR_WHITE;
	backColor = COLOR_BLACK;
    }

    /// Constructor
    public this() {
	reset();
    }

    /// Comparison.  All fields must match to return true.
    override bool opEquals(Object rhs) {
	auto that = cast(CellAttributes)rhs;
	if (!that) {
	    return false;
	}
	return ((bold == that.bold) &&
	    (blink == that.blink) &&
	    (reverse == that.reverse) &&
	    (underline == that.underline) &&
	    (protect == that.protect) &&
	    (foreColor == that.foreColor) &&
	    (backColor == that.backColor));
    }

    /// Set my field values to that's field
    public void setTo(Object rhs) {
	auto that = cast(CellAttributes)rhs;
	assert(that);

	this.bold = that.bold;
	this.blink = that.blink;
	this.reverse = that.reverse;
	this.underline = that.underline;
	this.protect = that.protect;
	this.foreColor = that.foreColor;
	this.backColor = that.backColor;
    }

}

/**
 * A single text cell on the screen
 */
public class Cell : CellAttributes {

    /// The character at this cell
    public dchar ch;

    /// Reset this cell to a blank
    override public void reset() {
	super.reset();
	ch = ' ';
    }

    /// Returns true if this cell has default attributes
    public bool isBlank() {
	if ((foreColor == COLOR_WHITE) &&
	    (backColor == COLOR_BLACK) &&
	    (bold == false) &&
	    (blink == false) &&
	    (reverse == false) &&
	    (underline == false) &&
	    (protect == false) &&
	    (ch == ' ')) {
	    return true;
	}

	return false;
    }

    /// Comparison.  All fields must match to return true.
    override bool opEquals(Object rhs) {
	auto that = cast(Cell)rhs;
	if (!that) {
	    return false;
	}
	return (super.opEquals(rhs) &&
	    (ch == that.ch));
    }

    /// Set my field values to that's field
    override public void setTo(Object rhs) {
	auto thatAttr = cast(CellAttributes)rhs;
	assert(thatAttr);
	super.setTo(thatAttr);

	if (auto that = cast(Cell)rhs) {
	    this.ch = that.ch;
	}
    }

    /// Set my field attr values to that's field
    public void setAttr(CellAttributes that) {
	super.setTo(that);
    }

    /// Constructor
    public this() {
	reset();
    }

    /**
     * Constructor
     *
     * Params:
     *    ch = character to set to
     */
    public this(dchar ch) {
	reset();
	this.ch = ch;
    }

    /// Make human-readable description of this Keystroke.
    override public string toString() {
	auto writer = appender!string();
	formattedWrite(writer, "fore: %d back: %d bold: %s blink: %s ch %c",
	    foreColor, backColor, bold, blink, ch);
	return writer.data;
    }
}

/**
 * This class represents a text-based screen.  Drawing operations
 * write to a logical screen.  Calling flushString() returns a string
 * that contains xterm/ANSI/ECMA-type escape sequences that provides
 * the updates to the physical screen.
 *
 * Win32 would need a new flush() that calls the Console drawing
 * functions.
 */
public class Screen {

    /// Emit debugging to stderr
    public bool debugToStderr;

    /// Width of the visible window
    private uint width;

    /// Height of the visible window
    private uint height;

    /// Drawing offset for x.  Note int and not uint.
    public int offsetX;

    /// Drawing offset for y.  Note int and not uint.
    public int offsetY;

    /// Ignore anything drawn beyond clipX
    public uint clipX;

    /// Ignore anything drawn beyond clipY
    public uint clipY;

    /// The physical screen last sent out on flush()
    private Cell [][] physical;

    /// The logical screen being rendered to
    private Cell [][] logical;

    /// When true, logical != physical
    public bool dirty;

    /**
     * Get the attributes at one location.
     *
     * Params:
     *    x = column coordinate.  0 is the left-most column.
     *    y = row coordinate.  0 is the top-most row.
     *
     * Return:
     *    attributes at (x, y)
     */ 
    public CellAttributes getAttrXY(uint x, uint y) {
	CellAttributes attr = new CellAttributes();
	attr.setTo(logical[x][y]);
	return attr;
    }

    /**
     * Set the attributes at one location.
     *
     * Params:
     *    x = column coordinate.  0 is the left-most column.
     *    y = row coordinate.  0 is the top-most row.
     *    attr = attributes to use (bold, foreColor, backColor)
     *    clip = if true, honor clipping/offset
     */ 
    public void putAttrXY(uint x, uint y, CellAttributes attr, bool clip = true) {

	int X = x;
	int Y = y;

	if (clip) {
	    if ((x >= clipX) || (y >= clipY)) {
		return;
	    }
	    X += offsetX;
	    Y += offsetY;
	}

	if ((X >= 0) && (X < width) && (Y >= 0) && (Y < height)) {
	    dirty = true;
	    logical[X][Y].foreColor = attr.foreColor;
	    logical[X][Y].backColor = attr.backColor;
	    logical[X][Y].bold = attr.bold;
	    logical[X][Y].blink = attr.blink;
	    logical[X][Y].reverse = attr.reverse;
	    logical[X][Y].underline = attr.underline;
	    logical[X][Y].protect = attr.protect;
	}
    }

    /**
     * Fill the entire screen with one character with attributes.
     *
     * Params:
     *    ch = character to draw
     *    attr = attributes to use (bold, foreColor, backColor)
     */ 
    public void putAll(dchar ch, CellAttributes attr) {
	for (auto x = 0; x < width; x++) {
	    for (auto y = 0; y < height; y++) {
		putCharXY(x, y, ch, attr);
	    }
	}
    }

    /**
     * Render one character with attributes.
     *
     * Params:
     *    x = column coordinate.  0 is the left-most column.
     *    y = row coordinate.  0 is the top-most row.
     *    ch = character + attributes to draw
     */ 
    public void putCharXY(uint x, uint y, Cell ch) {
	putCharXY(x, y, ch.ch, ch);
    }

    /**
     * Render one character with attributes.
     *
     * Params:
     *    x = column coordinate.  0 is the left-most column.
     *    y = row coordinate.  0 is the top-most row.
     *    ch = character to draw
     *    attr = attributes to use (bold, foreColor, backColor)
     */ 
    public void putCharXY(uint x, uint y, dchar ch, CellAttributes attr) {
	if ((x >= clipX) || (y >= clipY)) {
	    return;
	}

	int X = x + offsetX;
	int Y = y + offsetY;

	// stderr.writefln("putCharXY: %d, %d, %c", X, Y, ch);
	
	if ((X >= 0) && (X < width) && (Y >= 0) && (Y < height)) {
	    dirty = true;
	    logical[X][Y].ch = ch;
	    logical[X][Y].foreColor = attr.foreColor;
	    logical[X][Y].backColor = attr.backColor;
	    logical[X][Y].bold = attr.bold;
	    logical[X][Y].blink = attr.blink;
	    logical[X][Y].reverse = attr.reverse;
	    logical[X][Y].underline = attr.underline;
	    logical[X][Y].protect = attr.protect;
	}
    }

    /**
     * Render one character without changing the underlying
     * attributes.
     *
     * Params:
     *    x = column coordinate.  0 is the left-most column.
     *    y = row coordinate.  0 is the top-most row.
     *    ch = character to draw
     */ 
    public void putCharXY(uint x, uint y, dchar ch) {
	if ((x >= clipX) || (y >= clipY)) {
	    return;
	}

	int X = x + offsetX;
	int Y = y + offsetY;

	// stderr.writefln("putCharXY: %d, %d, %c", X, Y, ch);
	
	if ((X >= 0) && (X < width) && (Y >= 0) && (Y < height)) {
	    dirty = true;
	    logical[X][Y].ch = ch;
	}
    }

    /**
     * Render a string.  Does not wrap if the string exceeds the line.
     *
     * Params:
     *    x = column coordinate.  0 is the left-most column.
     *    y = row coordinate.  0 is the top-most row.
     *    str = string to draw
     *    attr = attributes to use (bold, foreColor, backColor)
     */
    public void putStrXY(uint x, uint y, dstring str, CellAttributes attr) {
	auto i = x;
	foreach (ch; str) {
	    putCharXY(i, y, ch, attr);
	    i++;
	    if (i == width) {
		break;
	    }
	}
    }

    /**
     * Render a string without changing the underlying attribute.
     * Does not wrap if the string exceeds the line.
     *
     * Params:
     *    x = column coordinate.  0 is the left-most column.
     *    y = row coordinate.  0 is the top-most row.
     *    str = string to draw
     */
    public void putStrXY(uint x, uint y, dstring str) {
	auto i = x;
	foreach (ch; str) {
	    putCharXY(i, y, ch);
	    i++;
	    if (i == width) {
		break;
	    }
	}
    }

    /**
     * Draw a vertical line from (x, y) to (x, y + n)
     *
     * Params:
     *    x = column coordinate.  0 is the left-most column.
     *    y = row coordinate.  0 is the top-most row.
     *    n = number of characters to draw
     *    ch = character to draw
     *    attr = attributes to use (bold, foreColor, backColor)
     */
    public void vLineXY(uint x, uint y, uint n, dchar ch, CellAttributes attr) {
	for (auto i = y; i < y + n; i++) {
	    putCharXY(x, i, ch, attr);
	}
    }

    /**
     * Draw a horizontal line from (x, y) to (x + n, y)
     *
     * Params:
     *    x = column coordinate.  0 is the left-most column.
     *    y = row coordinate.  0 is the top-most row.
     *    n = number of characters to draw
     *    ch = character to draw
     *    attr = attributes to use (bold, foreColor, backColor)
     */
    public void hLineXY(uint x, uint y, uint n, dchar ch, CellAttributes attr) {
	for (auto i = x; i < x + n; i++) {
	    putCharXY(i, y, ch, attr);
	}
    }

    /**
     * Reallocate screen buffers.
     * 
     * Params:
     *    width = new width
     *    height = new height
     */
    private void reallocate(uint width, uint height) {
	if (logical !is null) {
	    for (auto row = 0; row < this.height; row++) {
		for (auto col = 0; col < this.width; col++) {
		    delete logical[col][row];
		}
	    }
	    delete logical;
	}
	logical = new Cell[][](width, height);
	if (physical !is null) {
	    for (auto row = 0; row < this.height; row++) {
		for (auto col = 0; col < this.width; col++) {
		    delete physical[col][row];
		}
	    }
	    delete physical;
	}
	physical = new Cell[][](width, height);

	for (auto row = 0; row < height; row++) {
	    for (auto col = 0; col < width; col++) {
		physical[col][row] = new Cell();
		logical[col][row] = new Cell();
	    }
	}

	this.width = width;
	this.height = height;

	clipX = width;
	clipY = height;

	reallyCleared = true;
	dirty = true;
    }

    /**
     * Change the width.  Everything on-screen will be destroyed and
     * must be redrawn.
     *
     * Params:
     *    width = new screen width
     */
    public void setWidth(uint width) {
	reallocate(width, this.height);
    }

    /**
     * Change the height.  Everything on-screen will be destroyed and
     * must be redrawn.
     *
     * Params:
     *    height = new screen height
     */
    public void setHeight(uint height) {
	reallocate(this.width, height);
    }

    /**
     * Change the width and height.  Everything on-screen will be
     * destroyed and must be redrawn.
     *
     * Params:
     *    width = new screen width
     *    height = new screen height
     */
    public void setDimensions(uint width, uint height) {
	reallocate(width, height);
    }

    /**
     * Get the height.
     *
     * Returns:
     *    current screen height
     */
    public uint getHeight() {
	return this.height;
    }

    /**
     * Get the width.
     *
     * Returns:
     *    current screen width
     */
    public uint getWidth() {
	return this.width;
    }

    /// Constructor sets everything to not-bold, white-on-black
    public this() {
	debugToStderr = false;

	offsetX = 0;
	offsetY = 0;

	width = 80;
	height = 24;
	logical = null;
	physical = null;
	reallocate(width, height);
    }

    /// Reset screen to not-bold, white-on-black.  Also flushes the
    /// offset and clip variables.
    public void reset() {
	dirty = true;
	for (auto row = 0; row < height; row++) {
	    for (auto col = 0; col < width; col++) {
		logical[col][row].reset();
	    }
	}
	resetClipping();
    }

    /// Flush the offset and clip variables.
    public void resetClipping() {
	offsetX = 0;
	offsetY = 0;
	clipX = width;
	clipY = height;
    }

    /// Set if the user explicitly wants to redraw everything starting
    /// with a Terminal.clearAll()
    private bool reallyCleared;

    /// Force the screen to be fully cleared and redrawn on the next
    /// flush().
    public void clear() {
	reset();
    }

    /**
     * Perform a somewhat-optimal rendering of a line
     *
     * Params:
     *    y = row coordinate.  0 is the top-most row.
     *    writer = appender to write escape sequences to
     */ 
    private void flushLine(uint y, Appender!(string) writer) {
	Cell lastCell = new Cell();
	uint lastCellX = -1;
	bool first = true;

	int textBegin = -1;
	int textEnd = width - 1;

	// Find the boundaries of the logical screen
	for (auto x = 0; x < width; x++) {
	    auto lCell = logical[x][y];
	    if (lCell.isBlank()) {
		if (textBegin == (x - 1)) {
		    textBegin++;
		}
	    } else {
		textEnd = x;
	    }
	}
	// Push textEnd to the beginning of the blank area
	textEnd++;

	for (auto x = 0; x < width; x++) {
	    auto lCell = logical[x][y];
	    auto pCell = physical[x][y];

	    if ((lCell != pCell) || (reallyCleared == true)) {

		if (x <= textBegin) {
		    // This cell should be blank, skip it
		    assert(lCell.isBlank());
		    continue;
		}
		if (x == textBegin + 1) {
		    // Place the cell
		    assert(lastCellX == -1);
		    assert(lastCell.isBlank());
		    writer.put(Terminal.gotoXY(x, y));

		    if (x > 0) {
			// Clear everything up to here
			writer.put(Terminal.clearPreceedingLine());
		    }
		}
		if ((x == textEnd) && (textEnd < width - 1)) {
		    assert(lCell.isBlank());

		    // Clear remaining line
		    writer.put(Terminal.clearRemainingLine());
		    break;
		}

		// Place the cell
		if (lastCellX != (x - 1)) {
		    // Advancing at least one cell
		    writer.put(Terminal.gotoXY(x, y));
		} else {
		    assert(lastCellX == (x - 1));
		}

		if (debugToStderr) {
		    stderr.writefln("lastCell: %s", lastCell);
		    stderr.writefln("   lCell: %s", lCell);
		    stderr.writefln("   pCell: %s", pCell);
		}

		if (first) {
		    assert(lastCell.isBlank());

		    // Begin with normal attributes
		    writer.put(Terminal.normal());
		    first = false;
		}

		// Now emit only the modified attributes
		if ((lCell.foreColor != lastCell.foreColor) &&
		    (lCell.backColor != lastCell.backColor) &&
		    (lCell.bold != lastCell.bold) &&
		    (lCell.reverse != lastCell.reverse) &&
		    (lCell.underline != lastCell.underline) &&
		    (lCell.blink != lastCell.blink)) {

		    if (debugToStderr) {
			stderr.writefln("1 Set all attributes");
		    }
		    
		    // Everything is different
		    writer.put(Terminal.color(lCell.foreColor, lCell.backColor,
			    lCell.bold, lCell.reverse, lCell.blink,
			    lCell.underline));

		} else if ((lCell.foreColor != lastCell.foreColor) &&
		    (lCell.backColor != lastCell.backColor) &&
		    (lCell.bold == lastCell.bold) &&
		    (lCell.reverse == lastCell.reverse) &&
		    (lCell.underline == lastCell.underline) &&
		    (lCell.blink == lastCell.blink)) {

		    // Both colors changed, attributes the same
		    writer.put(Terminal.color(lCell.foreColor,
			    lCell.backColor));

		    if (debugToStderr) {
			stderr.writefln("2 Change both colors");
		    }

		} else if ((lCell.foreColor != lastCell.foreColor) &&
		    (lCell.backColor == lastCell.backColor) &&
		    (lCell.bold == lastCell.bold) &&
		    (lCell.reverse == lastCell.reverse) &&
		    (lCell.underline == lastCell.underline) &&
		    (lCell.blink == lastCell.blink)) {

		    // Attributes same, foreColor different
		    writer.put(Terminal.color(lCell.foreColor, true));

		    if (debugToStderr) {
			stderr.writefln("3 Change foreColor");
		    }

		} else if ((lCell.foreColor == lastCell.foreColor) &&
		    (lCell.backColor != lastCell.backColor) &&
		    (lCell.bold == lastCell.bold) &&
		    (lCell.reverse == lastCell.reverse) &&
		    (lCell.underline == lastCell.underline) &&
		    (lCell.blink == lastCell.blink)) {

		    // Attributes same, backColor different
		    writer.put(Terminal.color(lCell.backColor, false));

		    if (debugToStderr) {
			stderr.writefln("4 Change backColor");
		    }

		} else if ((lCell.foreColor == lastCell.foreColor) &&
		    (lCell.backColor == lastCell.backColor) &&
		    (lCell.bold == lastCell.bold) &&
		    (lCell.reverse == lastCell.reverse) &&
		    (lCell.underline == lastCell.underline) &&
		    (lCell.blink == lastCell.blink)) {

		    // All attributes the same, just print the char
		    // NOP

		    if (debugToStderr) {
			stderr.writefln("5 Only emit character");
		    }

		} else {
		    // Just reset everything again
		    writer.put(Terminal.color(lCell.foreColor, lCell.backColor,
			    lCell.bold, lCell.reverse, lCell.blink,
			    lCell.underline));

		    if (debugToStderr) {
			stderr.writefln("6 Change all attributes");
		    }

		}

		// Emit the character
		writer.put(dcharToString(lCell.ch));

		// Save the last rendered cell
		lastCellX = x;
		lastCell.setTo(lCell);

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

	auto writer = appender!string();
	if (reallyCleared == true) {
	    writer.put(Terminal.clearAll());
	}

	for (auto y = 0; y < height; y++) {
	    flushLine(y, writer);
	}

	dirty = false;
	reallyCleared = false;

	string result = writer.data;
	if (debugToStderr) {
	    stderr.writefln("flushString(): %s", result);
	}
	return result;
    }

    /**
     * Draw a box with a border and empty background.
     *
     * Params:
     *    left = left column of box.  0 is the left-most row.
     *    top = top row of the box.  0 is the top-most row.
     *    right = right column of box
     *    bottom = bottom row of the box
     *    border = attributes to use for the border (bold, foreColor, backColor)
     *    background = attributes to use for the background
     *    borderType = 1: single-line border
     *                 2: double-line borders
     *                 3: double-line top/bottom edges and single-line left/right edges
     *    shadow = if true, draw a "shadow" on the box
     */
    public void drawBox(uint left, uint top, uint right, uint bottom,
	CellAttributes border, CellAttributes background, uint borderType = 1,
	bool shadow = false) {

	auto boxTop = top;
	auto boxLeft = left;
	auto boxWidth = right - left;
	auto boxHeight = bottom - top;

	dchar cTopLeft;
	dchar cTopRight;
	dchar cBottomLeft;
	dchar cBottomRight;
	dchar cHSide;
	dchar cVSide;

	final switch (borderType) {
	case 1:
	    cTopLeft = GraphicsChars.ULCORNER;
	    cTopRight = GraphicsChars.URCORNER;
	    cBottomLeft = GraphicsChars.LLCORNER;
	    cBottomRight = GraphicsChars.LRCORNER;
	    cHSide = GraphicsChars.SINGLE_BAR;
	    cVSide = GraphicsChars.WINDOW_SIDE;
	    break;

	case 2:
	    cTopLeft = GraphicsChars.WINDOW_LEFT_TOP_DOUBLE;
	    cTopRight = GraphicsChars.WINDOW_RIGHT_TOP_DOUBLE;
	    cBottomLeft = GraphicsChars.WINDOW_LEFT_BOTTOM_DOUBLE;
	    cBottomRight = GraphicsChars.WINDOW_RIGHT_BOTTOM_DOUBLE;
	    cHSide = GraphicsChars.DOUBLE_BAR;
	    cVSide = GraphicsChars.WINDOW_SIDE_DOUBLE;
	    break;
	    
	case 3:
	    cTopLeft = GraphicsChars.WINDOW_LEFT_TOP;
	    cTopRight = GraphicsChars.WINDOW_RIGHT_TOP;
	    cBottomLeft = GraphicsChars.WINDOW_LEFT_BOTTOM;
	    cBottomRight = GraphicsChars.WINDOW_RIGHT_BOTTOM;
	    cHSide = GraphicsChars.WINDOW_TOP;
	    cVSide = GraphicsChars.WINDOW_SIDE;
	    break;
	}


	// Place the corner characters
	putCharXY(left, top, cTopLeft, border);
	putCharXY(left + boxWidth - 1, top, cTopRight, border);
	putCharXY(left, top + boxHeight - 1, cBottomLeft, border);
	putCharXY(left + boxWidth - 1, top + boxHeight - 1, cBottomRight,
	    border);

	// Draw the box lines
	hLineXY(left + 1, top, boxWidth - 2, cHSide, border);
	vLineXY(left, top + 1, boxHeight - 2, cVSide, border);
	hLineXY(left + 1, top + boxHeight - 1, boxWidth - 2, cHSide, border);
	vLineXY(left + boxWidth - 1, top + 1, boxHeight - 2, cVSide, border);

	// Fill in the interior background
	for (auto i = 1; i < boxHeight - 1; i++) {
	    hLineXY(1 + left, i + top, boxWidth - 2, ' ', background);
	}

	if (shadow) {
	    // Draw a shadow
	    drawBoxShadow(left, top, right, bottom);
	}
    }

    /**
     * Draw a box shadow
     *
     * Params:
     *    left = left column of box.  0 is the left-most row.
     *    top = top row of the box.  0 is the top-most row.
     *    right = right column of box
     *    bottom = bottom row of the box
     */
    public void drawBoxShadow(uint left, uint top, uint right, uint bottom) {

	auto boxTop = top;
	auto boxLeft = left;
	auto boxWidth = right - left;
	auto boxHeight = bottom - top;
	CellAttributes shadowAttr = new CellAttributes();

	// Shadows do not honor clipping but they DO honor offset.
	uint oldClipX = clipX;
	uint oldClipY = clipY;
	clipX = width;
	clipY = height;
	
	for (auto i = 0; i < boxHeight; i++) {
	    putAttrXY(boxLeft + boxWidth, boxTop + 1 + i, shadowAttr);
	    putAttrXY(boxLeft + boxWidth + 1, boxTop + 1 + i, shadowAttr);
	}
	for (auto i = 0; i < boxWidth; i++) {
	    putAttrXY(boxLeft + 2 + i, boxTop + boxHeight, shadowAttr);
	}
	clipX = oldClipX;
	clipY = oldClipY;
    }
}

/**
 * This struct represents keystrokes.
 */
public struct TKeypress {

    // Various special keystrokes

    /// Function key F1
    public static immutable ubyte F1	= 1;
    /// Function key F2
    public static immutable ubyte F2	= 2;
    /// Function key F3
    public static immutable ubyte F3	= 3;
    /// Function key F4
    public static immutable ubyte F4	= 4;
    /// Function key F5
    public static immutable ubyte F5	= 5;
    /// Function key F6
    public static immutable ubyte F6	= 6;
    /// Function key F7
    public static immutable ubyte F7	= 7;
    /// Function key F8
    public static immutable ubyte F8	= 8;
    /// Function key F9
    public static immutable ubyte F9	= 9;
    /// Function key F10
    public static immutable ubyte F10	= 10;
    /// Function key F11
    public static immutable ubyte F11	= 11;
    /// Function key F12
    public static immutable ubyte F12	= 12;
    /// Home
    public static immutable ubyte HOME	= 20;
    /// End
    public static immutable ubyte END	= 21;
    /// Page up
    public static immutable ubyte PGUP	= 22;
    /// Page down
    public static immutable ubyte PGDN	= 23;
    /// Insert
    public static immutable ubyte INS	= 24;
    /// Delete
    public static immutable ubyte DEL	= 25;
    /// Right arrow
    public static immutable ubyte RIGHT	= 30;
    /// Left arrow
    public static immutable ubyte LEFT	= 31;
    /// Up arrow
    public static immutable ubyte UP	= 32;
    /// Down arrow
    public static immutable ubyte DOWN	= 33;
    /// Tab
    public static immutable ubyte TAB	= 40;
    /// Back-tab (shift-tab)
    public static immutable ubyte BTAB	= 41;
    /// Enter
    public static immutable ubyte ENTER	= 42;
    /// Escape
    public static immutable ubyte ESC	= 43;

    /// If true, ch is meaningless, use fnKey instead.
    public bool isKey;

    /// Will be set to F1, F2, HOME, END, etc. if isKey is true.
    public ubyte fnKey;

    /// Keystroke modifier ALT
    public bool alt;

    /// Keystroke modifier CTRL
    public bool ctrl;

    /// Keystroke modifier SHIFT
    public bool shift;

    /// The character received
    public dchar ch;

    /// Convenience constructor for immutable instance
    public this(bool isKey, ubyte fnKey, dchar ch, bool alt, bool ctrl, bool shift) {
	this.isKey = isKey;
	this.fnKey = fnKey;
	this.ch = ch;
	this.alt = alt;
	this.ctrl = ctrl;
	this.shift = shift;
    }

    /// Comparison.  All fields must match to return true.
    bool opEquals(ref const TKeypress that) {
	return ((isKey == that.isKey) &&
	    (fnKey == that.fnKey) &&
	    (ch == that.ch) &&
	    (alt == that.alt) &&
	    (ctrl == that.ctrl) &&
	    (shift == that.shift)
	);
    }

    /// Make human-readable description of this Keystroke.
    public dstring toString() {
	auto writer = appender!dstring();
	if (isKey) {
	    switch (fnKey) {
	    case F1:
		formattedWrite(writer, "F1");
		break;
	    case F2:
		formattedWrite(writer, "F2");
		break;
	    case F3:
		formattedWrite(writer, "F3");
		break;
	    case F4:
		formattedWrite(writer, "F4");
		break;
	    case F5:
		formattedWrite(writer, "F5");
		break;
	    case F6:
		formattedWrite(writer, "F6");
		break;
	    case F7:
		formattedWrite(writer, "F7");
		break;
	    case F8:
		formattedWrite(writer, "F8");
		break;
	    case F9:
		formattedWrite(writer, "F9");
		break;
	    case F10:
		formattedWrite(writer, "F10");
		break;
	    case F11:
		formattedWrite(writer, "F11");
		break;
	    case F12:
		formattedWrite(writer, "F12");
		break;
	    case HOME:
		formattedWrite(writer, "HOME");
		break;
	    case END:
		formattedWrite(writer, "END");
		break;
	    case PGUP:
		formattedWrite(writer, "PGUP");
		break;
	    case PGDN:
		formattedWrite(writer, "PGDN");
		break;
	    case INS:
		formattedWrite(writer, "INS");
		break;
	    case DEL:
		formattedWrite(writer, "DEL");
		break;
	    case RIGHT:
		formattedWrite(writer, "RIGHT");
		break;
	    case LEFT:
		formattedWrite(writer, "LEFT");
		break;
	    case UP:
		formattedWrite(writer, "UP");
		break;
	    case DOWN:
		formattedWrite(writer, "DOWN");
		break;
	    case TAB:
		formattedWrite(writer, "TAB");
		break;
	    case BTAB:
		formattedWrite(writer, "BTAB");
		break;
	    case ENTER:
		formattedWrite(writer, "ENTER");
		break;
	    case ESC:
		formattedWrite(writer, "ESC");
		break;
	    default:
		formattedWrite(writer, "--UNKNOWN--");
		break;
	    }
	} else {
	    if (alt && !shift && !ctrl) {
		// Alt-X
		formattedWrite(writer, "Alt-%c", toUppercase(ch));
	    } else if (!alt && shift && !ctrl) {
		// Shift-X
		formattedWrite(writer, "%c", ch);
	    } else if (!alt && !shift && ctrl) {
		// Ctrl-X
		formattedWrite(writer, "Ctrl-%c", ch);
	    } else if (alt && shift && !ctrl) {
		// Alt-Shift-X
		formattedWrite(writer, "Alt-Shift-%c", ch);
	    } else if (!alt && shift && ctrl) {
		// Ctrl-Shift-X
		formattedWrite(writer, "Ctrl-Shift-%c", ch);
	    } else if (alt && !shift && ctrl) {
		// Ctrl-Alt-X
		formattedWrite(writer, "Ctrl-Alt-%c", toUppercase(ch));
	    } else if (alt && shift && ctrl) {
		// Ctrl-Alt-Shift-X
		formattedWrite(writer, "Ctrl-Alt-Shift-%c", toUppercase(ch));
	    } else {
		// X
		formattedWrite(writer, "%c", ch);
	    }
	}
	return writer.data;
    }
}

/**
 * Convert a keypress to lowercase.  Function keys are not converted.
 *
 * Params:
 *    key = keypress to convert
 *
 * Returns:
 *    a new struct with the key converted
 */
public TKeypress toLower(TKeypress key) {
    TKeypress newKey = TKeypress(key.isKey, key.fnKey, key.ch, key.alt, key.ctrl, key.shift);
    newKey.shift = false;
    if (!(key.isKey) && (key.ch >= 'A') && (key.ch <= 'Z')) {
	newKey.ch -= 32;
    }
    return newKey;
}

/**
 * Convert a keypress to uppercase.  Function keys are not converted.
 *
 * Params:
 *    key = keypress to convert
 *
 * Returns:
 *    a new struct with the key converted
 */
public TKeypress toUpper(TKeypress key) {
    TKeypress newKey = TKeypress(key.isKey, key.fnKey, key.ch, key.alt, key.ctrl, key.shift);
    newKey.shift = false;
    if (!(key.isKey) && (key.ch >= 'a') && (key.ch <= 'z')) {
	newKey.ch += 32;
    }
    return newKey;
}

/**
 * Convert a a-z character to uppercase.
 *
 * Params:
 *    ch = character to convert
 *
 * Returns:
 *    ch in uppercase
 */
public dchar toUppercase(dchar ch) {
    if ((ch >= 'a') && (ch <= 'z')) {
	return ch - 32;
    }
    return ch;
}

/**
 * Convert a A-Z character to lowercase.
 *
 * Params:
 *    ch = character to convert
 *
 * Returns:
 *    ch in lowercase
 */
public dchar toLowercase(dchar ch) {
    if ((ch >= 'A') && (ch <= 'Z')) {
	return ch + 32;
    }
    return ch;
}

public immutable TKeypress kbF1 = TKeypress(true, TKeypress.F1, ' ', false, false, false);
public immutable TKeypress kbF2 = TKeypress(true, TKeypress.F2, ' ', false, false, false);
public immutable TKeypress kbF3 = TKeypress(true, TKeypress.F3, ' ', false, false, false);
public immutable TKeypress kbF4 = TKeypress(true, TKeypress.F4, ' ', false, false, false);
public immutable TKeypress kbF5 = TKeypress(true, TKeypress.F5, ' ', false, false, false);
public immutable TKeypress kbF6 = TKeypress(true, TKeypress.F6, ' ', false, false, false);
public immutable TKeypress kbF7 = TKeypress(true, TKeypress.F7, ' ', false, false, false);
public immutable TKeypress kbF8 = TKeypress(true, TKeypress.F8, ' ', false, false, false);
public immutable TKeypress kbF9 = TKeypress(true, TKeypress.F9, ' ', false, false, false);
public immutable TKeypress kbF10 = TKeypress(true, TKeypress.F10, ' ', false, false, false);
public immutable TKeypress kbF11 = TKeypress(true, TKeypress.F11, ' ', false, false, false);
public immutable TKeypress kbF12 = TKeypress(true, TKeypress.F12, ' ', false, false, false);
public immutable TKeypress kbAltF1 = TKeypress(true, TKeypress.F1, ' ', true, false, false);
public immutable TKeypress kbAltF2 = TKeypress(true, TKeypress.F2, ' ', true, false, false);
public immutable TKeypress kbAltF3 = TKeypress(true, TKeypress.F3, ' ', true, false, false);
public immutable TKeypress kbAltF4 = TKeypress(true, TKeypress.F4, ' ', true, false, false);
public immutable TKeypress kbAltF5 = TKeypress(true, TKeypress.F5, ' ', true, false, false);
public immutable TKeypress kbAltF6 = TKeypress(true, TKeypress.F6, ' ', true, false, false);
public immutable TKeypress kbAltF7 = TKeypress(true, TKeypress.F7, ' ', true, false, false);
public immutable TKeypress kbAltF8 = TKeypress(true, TKeypress.F8, ' ', true, false, false);
public immutable TKeypress kbAltF9 = TKeypress(true, TKeypress.F9, ' ', true, false, false);
public immutable TKeypress kbAltF10 = TKeypress(true, TKeypress.F10, ' ', true, false, false);
public immutable TKeypress kbAltF11 = TKeypress(true, TKeypress.F11, ' ', true, false, false);
public immutable TKeypress kbAltF12 = TKeypress(true, TKeypress.F12, ' ', true, false, false);
public immutable TKeypress kbCtrlF1 = TKeypress(true, TKeypress.F1, ' ', false, true, false);
public immutable TKeypress kbCtrlF2 = TKeypress(true, TKeypress.F2, ' ', false, true, false);
public immutable TKeypress kbCtrlF3 = TKeypress(true, TKeypress.F3, ' ', false, true, false);
public immutable TKeypress kbCtrlF4 = TKeypress(true, TKeypress.F4, ' ', false, true, false);
public immutable TKeypress kbCtrlF5 = TKeypress(true, TKeypress.F5, ' ', false, true, false);
public immutable TKeypress kbCtrlF6 = TKeypress(true, TKeypress.F6, ' ', false, true, false);
public immutable TKeypress kbCtrlF7 = TKeypress(true, TKeypress.F7, ' ', false, true, false);
public immutable TKeypress kbCtrlF8 = TKeypress(true, TKeypress.F8, ' ', false, true, false);
public immutable TKeypress kbCtrlF9 = TKeypress(true, TKeypress.F9, ' ', false, true, false);
public immutable TKeypress kbCtrlF10 = TKeypress(true, TKeypress.F10, ' ', false, true, false);
public immutable TKeypress kbCtrlF11 = TKeypress(true, TKeypress.F11, ' ', false, true, false);
public immutable TKeypress kbCtrlF12 = TKeypress(true, TKeypress.F12, ' ', false, true, false);
public immutable TKeypress kbShiftF1 = TKeypress(true, TKeypress.F1, ' ', false, false, true);
public immutable TKeypress kbShiftF2 = TKeypress(true, TKeypress.F2, ' ', false, false, true);
public immutable TKeypress kbShiftF3 = TKeypress(true, TKeypress.F3, ' ', false, false, true);
public immutable TKeypress kbShiftF4 = TKeypress(true, TKeypress.F4, ' ', false, false, true);
public immutable TKeypress kbShiftF5 = TKeypress(true, TKeypress.F5, ' ', false, false, true);
public immutable TKeypress kbShiftF6 = TKeypress(true, TKeypress.F6, ' ', false, false, true);
public immutable TKeypress kbShiftF7 = TKeypress(true, TKeypress.F7, ' ', false, false, true);
public immutable TKeypress kbShiftF8 = TKeypress(true, TKeypress.F8, ' ', false, false, true);
public immutable TKeypress kbShiftF9 = TKeypress(true, TKeypress.F9, ' ', false, false, true);
public immutable TKeypress kbShiftF10 = TKeypress(true, TKeypress.F10, ' ', false, false, true);
public immutable TKeypress kbShiftF11 = TKeypress(true, TKeypress.F11, ' ', false, false, true);
public immutable TKeypress kbShiftF12 = TKeypress(true, TKeypress.F12, ' ', false, false, true);
public immutable TKeypress kbEnter = TKeypress(true, TKeypress.ENTER, ' ', false, false, false);
public immutable TKeypress kbTab = TKeypress(true, TKeypress.TAB, ' ', false, false, false);
public immutable TKeypress kbEsc = TKeypress(true, TKeypress.ESC, ' ', false, false, false);
public immutable TKeypress kbHome = TKeypress(true, TKeypress.HOME, ' ', false, false, false);
public immutable TKeypress kbEnd = TKeypress(true, TKeypress.END, ' ', false, false, false);
public immutable TKeypress kbPgUp = TKeypress(true, TKeypress.PGUP, ' ', false, false, false);
public immutable TKeypress kbPgDn = TKeypress(true, TKeypress.PGDN, ' ', false, false, false);
public immutable TKeypress kbIns = TKeypress(true, TKeypress.INS, ' ', false, false, false);
public immutable TKeypress kbDel = TKeypress(true, TKeypress.DEL, ' ', false, false, false);
public immutable TKeypress kbUp = TKeypress(true, TKeypress.UP, ' ', false, false, false);
public immutable TKeypress kbDown = TKeypress(true, TKeypress.DOWN, ' ', false, false, false);
public immutable TKeypress kbLeft = TKeypress(true, TKeypress.LEFT, ' ', false, false, false);
public immutable TKeypress kbRight = TKeypress(true, TKeypress.RIGHT, ' ', false, false, false);
public immutable TKeypress kbAltEnter = TKeypress(true, TKeypress.ENTER, ' ', true, false, false);
public immutable TKeypress kbAltTab = TKeypress(true, TKeypress.TAB, ' ', true, false, false);
public immutable TKeypress kbAltEsc = TKeypress(true, TKeypress.ESC, ' ', true, false, false);
public immutable TKeypress kbAltHome = TKeypress(true, TKeypress.HOME, ' ', true, false, false);
public immutable TKeypress kbAltEnd = TKeypress(true, TKeypress.END, ' ', true, false, false);
public immutable TKeypress kbAltPgUp = TKeypress(true, TKeypress.PGUP, ' ', true, false, false);
public immutable TKeypress kbAltPgDn = TKeypress(true, TKeypress.PGDN, ' ', true, false, false);
public immutable TKeypress kbAltIns = TKeypress(true, TKeypress.INS, ' ', true, false, false);
public immutable TKeypress kbAltDel = TKeypress(true, TKeypress.DEL, ' ', true, false, false);
public immutable TKeypress kbAltUp = TKeypress(true, TKeypress.UP, ' ', true, false, false);
public immutable TKeypress kbAltDown = TKeypress(true, TKeypress.DOWN, ' ', true, false, false);
public immutable TKeypress kbAltLeft = TKeypress(true, TKeypress.LEFT, ' ', true, false, false);
public immutable TKeypress kbAltRight = TKeypress(true, TKeypress.RIGHT, ' ', true, false, false);
public immutable TKeypress kbCtrlEnter = TKeypress(true, TKeypress.ENTER, ' ', false, true, false);
public immutable TKeypress kbCtrlTab = TKeypress(true, TKeypress.TAB, ' ', false, true, false);
public immutable TKeypress kbCtrlEsc = TKeypress(true, TKeypress.ESC, ' ', false, true, false);
public immutable TKeypress kbCtrlHome = TKeypress(true, TKeypress.HOME, ' ', false, true, false);
public immutable TKeypress kbCtrlEnd = TKeypress(true, TKeypress.END, ' ', false, true, false);
public immutable TKeypress kbCtrlPgUp = TKeypress(true, TKeypress.PGUP, ' ', false, true, false);
public immutable TKeypress kbCtrlPgDn = TKeypress(true, TKeypress.PGDN, ' ', false, true, false);
public immutable TKeypress kbCtrlIns = TKeypress(true, TKeypress.INS, ' ', false, true, false);
public immutable TKeypress kbCtrlDel = TKeypress(true, TKeypress.DEL, ' ', false, true, false);
public immutable TKeypress kbCtrlUp = TKeypress(true, TKeypress.UP, ' ', false, true, false);
public immutable TKeypress kbCtrlDown = TKeypress(true, TKeypress.DOWN, ' ', false, true, false);
public immutable TKeypress kbCtrlLeft = TKeypress(true, TKeypress.LEFT, ' ', false, true, false);
public immutable TKeypress kbCtrlRight = TKeypress(true, TKeypress.RIGHT, ' ', false, true, false);
public immutable TKeypress kbShiftEnter = TKeypress(true, TKeypress.ENTER, ' ', false, false, true);
public immutable TKeypress kbShiftTab = TKeypress(true, TKeypress.TAB, ' ', false, false, true);
public immutable TKeypress kbBackTab = TKeypress(true, TKeypress.BTAB, ' ', false, false, false);
public immutable TKeypress kbShiftEsc = TKeypress(true, TKeypress.ESC, ' ', false, false, true);
public immutable TKeypress kbShiftHome = TKeypress(true, TKeypress.HOME, ' ', false, false, true);
public immutable TKeypress kbShiftEnd = TKeypress(true, TKeypress.END, ' ', false, false, true);
public immutable TKeypress kbShiftPgUp = TKeypress(true, TKeypress.PGUP, ' ', false, false, true);
public immutable TKeypress kbShiftPgDn = TKeypress(true, TKeypress.PGDN, ' ', false, false, true);
public immutable TKeypress kbShiftIns = TKeypress(true, TKeypress.INS, ' ', false, false, true);
public immutable TKeypress kbShiftDel = TKeypress(true, TKeypress.DEL, ' ', false, false, true);
public immutable TKeypress kbShiftUp = TKeypress(true, TKeypress.UP, ' ', false, false, true);
public immutable TKeypress kbShiftDown = TKeypress(true, TKeypress.DOWN, ' ', false, false, true);
public immutable TKeypress kbShiftLeft = TKeypress(true, TKeypress.LEFT, ' ', false, false, true);
public immutable TKeypress kbShiftRight = TKeypress(true, TKeypress.RIGHT, ' ', false, false, true);
public immutable TKeypress kbA = TKeypress(false, 0, 'a', false, false, false);
public immutable TKeypress kbB = TKeypress(false, 0, 'b', false, false, false);
public immutable TKeypress kbC = TKeypress(false, 0, 'c', false, false, false);
public immutable TKeypress kbD = TKeypress(false, 0, 'd', false, false, false);
public immutable TKeypress kbE = TKeypress(false, 0, 'e', false, false, false);
public immutable TKeypress kbF = TKeypress(false, 0, 'f', false, false, false);
public immutable TKeypress kbG = TKeypress(false, 0, 'g', false, false, false);
public immutable TKeypress kbH = TKeypress(false, 0, 'h', false, false, false);
public immutable TKeypress kbI = TKeypress(false, 0, 'i', false, false, false);
public immutable TKeypress kbJ = TKeypress(false, 0, 'j', false, false, false);
public immutable TKeypress kbK = TKeypress(false, 0, 'k', false, false, false);
public immutable TKeypress kbL = TKeypress(false, 0, 'l', false, false, false);
public immutable TKeypress kbM = TKeypress(false, 0, 'm', false, false, false);
public immutable TKeypress kbN = TKeypress(false, 0, 'n', false, false, false);
public immutable TKeypress kbO = TKeypress(false, 0, 'o', false, false, false);
public immutable TKeypress kbP = TKeypress(false, 0, 'p', false, false, false);
public immutable TKeypress kbQ = TKeypress(false, 0, 'q', false, false, false);
public immutable TKeypress kbR = TKeypress(false, 0, 'r', false, false, false);
public immutable TKeypress kbS = TKeypress(false, 0, 's', false, false, false);
public immutable TKeypress kbT = TKeypress(false, 0, 't', false, false, false);
public immutable TKeypress kbU = TKeypress(false, 0, 'u', false, false, false);
public immutable TKeypress kbV = TKeypress(false, 0, 'v', false, false, false);
public immutable TKeypress kbW = TKeypress(false, 0, 'w', false, false, false);
public immutable TKeypress kbX = TKeypress(false, 0, 'x', false, false, false);
public immutable TKeypress kbY = TKeypress(false, 0, 'y', false, false, false);
public immutable TKeypress kbZ = TKeypress(false, 0, 'z', false, false, false);
public immutable TKeypress kbSpace = TKeypress(false, 0, ' ', false, false, false);
public immutable TKeypress kbAltA = TKeypress(false, 0, 'a', true, false, false);
public immutable TKeypress kbAltB = TKeypress(false, 0, 'b', true, false, false);
public immutable TKeypress kbAltC = TKeypress(false, 0, 'c', true, false, false);
public immutable TKeypress kbAltD = TKeypress(false, 0, 'd', true, false, false);
public immutable TKeypress kbAltE = TKeypress(false, 0, 'e', true, false, false);
public immutable TKeypress kbAltF = TKeypress(false, 0, 'f', true, false, false);
public immutable TKeypress kbAltG = TKeypress(false, 0, 'g', true, false, false);
public immutable TKeypress kbAltH = TKeypress(false, 0, 'h', true, false, false);
public immutable TKeypress kbAltI = TKeypress(false, 0, 'i', true, false, false);
public immutable TKeypress kbAltJ = TKeypress(false, 0, 'j', true, false, false);
public immutable TKeypress kbAltK = TKeypress(false, 0, 'k', true, false, false);
public immutable TKeypress kbAltL = TKeypress(false, 0, 'l', true, false, false);
public immutable TKeypress kbAltM = TKeypress(false, 0, 'm', true, false, false);
public immutable TKeypress kbAltN = TKeypress(false, 0, 'n', true, false, false);
public immutable TKeypress kbAltO = TKeypress(false, 0, 'o', true, false, false);
public immutable TKeypress kbAltP = TKeypress(false, 0, 'p', true, false, false);
public immutable TKeypress kbAltQ = TKeypress(false, 0, 'q', true, false, false);
public immutable TKeypress kbAltR = TKeypress(false, 0, 'r', true, false, false);
public immutable TKeypress kbAltS = TKeypress(false, 0, 's', true, false, false);
public immutable TKeypress kbAltT = TKeypress(false, 0, 't', true, false, false);
public immutable TKeypress kbAltU = TKeypress(false, 0, 'u', true, false, false);
public immutable TKeypress kbAltV = TKeypress(false, 0, 'v', true, false, false);
public immutable TKeypress kbAltW = TKeypress(false, 0, 'w', true, false, false);
public immutable TKeypress kbAltX = TKeypress(false, 0, 'x', true, false, false);
public immutable TKeypress kbAltY = TKeypress(false, 0, 'y', true, false, false);
public immutable TKeypress kbAltZ = TKeypress(false, 0, 'z', true, false, false);
public immutable TKeypress kbCtrlA = TKeypress(false, 0, 'A', false, true, false);
public immutable TKeypress kbCtrlB = TKeypress(false, 0, 'B', false, true, false);
public immutable TKeypress kbCtrlC = TKeypress(false, 0, 'C', false, true, false);
public immutable TKeypress kbCtrlD = TKeypress(false, 0, 'D', false, true, false);
public immutable TKeypress kbCtrlE = TKeypress(false, 0, 'E', false, true, false);
public immutable TKeypress kbCtrlF = TKeypress(false, 0, 'F', false, true, false);
public immutable TKeypress kbCtrlG = TKeypress(false, 0, 'G', false, true, false);
public immutable TKeypress kbCtrlH = TKeypress(false, 0, 'H', false, true, false);
public immutable TKeypress kbCtrlI = TKeypress(false, 0, 'I', false, true, false);
public immutable TKeypress kbCtrlJ = TKeypress(false, 0, 'J', false, true, false);
public immutable TKeypress kbCtrlK = TKeypress(false, 0, 'K', false, true, false);
public immutable TKeypress kbCtrlL = TKeypress(false, 0, 'L', false, true, false);
public immutable TKeypress kbCtrlM = TKeypress(false, 0, 'M', false, true, false);
public immutable TKeypress kbCtrlN = TKeypress(false, 0, 'N', false, true, false);
public immutable TKeypress kbCtrlO = TKeypress(false, 0, 'O', false, true, false);
public immutable TKeypress kbCtrlP = TKeypress(false, 0, 'P', false, true, false);
public immutable TKeypress kbCtrlQ = TKeypress(false, 0, 'Q', false, true, false);
public immutable TKeypress kbCtrlR = TKeypress(false, 0, 'R', false, true, false);
public immutable TKeypress kbCtrlS = TKeypress(false, 0, 'S', false, true, false);
public immutable TKeypress kbCtrlT = TKeypress(false, 0, 'T', false, true, false);
public immutable TKeypress kbCtrlU = TKeypress(false, 0, 'U', false, true, false);
public immutable TKeypress kbCtrlV = TKeypress(false, 0, 'V', false, true, false);
public immutable TKeypress kbCtrlW = TKeypress(false, 0, 'W', false, true, false);
public immutable TKeypress kbCtrlX = TKeypress(false, 0, 'X', false, true, false);
public immutable TKeypress kbCtrlY = TKeypress(false, 0, 'Y', false, true, false);
public immutable TKeypress kbCtrlZ = TKeypress(false, 0, 'Z', false, true, false);
public immutable TKeypress kbAltShiftA = TKeypress(false, 0, 'A', true, false, true);
public immutable TKeypress kbAltShiftB = TKeypress(false, 0, 'B', true, false, true);
public immutable TKeypress kbAltShiftC = TKeypress(false, 0, 'C', true, false, true);
public immutable TKeypress kbAltShiftD = TKeypress(false, 0, 'D', true, false, true);
public immutable TKeypress kbAltShiftE = TKeypress(false, 0, 'E', true, false, true);
public immutable TKeypress kbAltShiftF = TKeypress(false, 0, 'F', true, false, true);
public immutable TKeypress kbAltShiftG = TKeypress(false, 0, 'G', true, false, true);
public immutable TKeypress kbAltShiftH = TKeypress(false, 0, 'H', true, false, true);
public immutable TKeypress kbAltShiftI = TKeypress(false, 0, 'I', true, false, true);
public immutable TKeypress kbAltShiftJ = TKeypress(false, 0, 'J', true, false, true);
public immutable TKeypress kbAltShiftK = TKeypress(false, 0, 'K', true, false, true);
public immutable TKeypress kbAltShiftL = TKeypress(false, 0, 'L', true, false, true);
public immutable TKeypress kbAltShiftM = TKeypress(false, 0, 'M', true, false, true);
public immutable TKeypress kbAltShiftN = TKeypress(false, 0, 'N', true, false, true);
public immutable TKeypress kbAltShiftO = TKeypress(false, 0, 'O', true, false, true);
public immutable TKeypress kbAltShiftP = TKeypress(false, 0, 'P', true, false, true);
public immutable TKeypress kbAltShiftQ = TKeypress(false, 0, 'Q', true, false, true);
public immutable TKeypress kbAltShiftR = TKeypress(false, 0, 'R', true, false, true);
public immutable TKeypress kbAltShiftS = TKeypress(false, 0, 'S', true, false, true);
public immutable TKeypress kbAltShiftT = TKeypress(false, 0, 'T', true, false, true);
public immutable TKeypress kbAltShiftU = TKeypress(false, 0, 'U', true, false, true);
public immutable TKeypress kbAltShiftV = TKeypress(false, 0, 'V', true, false, true);
public immutable TKeypress kbAltShiftW = TKeypress(false, 0, 'W', true, false, true);
public immutable TKeypress kbAltShiftX = TKeypress(false, 0, 'X', true, false, true);
public immutable TKeypress kbAltShiftY = TKeypress(false, 0, 'Y', true, false, true);
public immutable TKeypress kbAltShiftZ = TKeypress(false, 0, 'Z', true, false, true);

/// Backspace as ^H
public immutable TKeypress kbBackspace = TKeypress(false, 0, 'H', false, true, false);

/// Backspace as ^?
public immutable TKeypress kbBackspaceDel = TKeypress(false, 0, 0x7F, false, false, false);

/**
 * This class encapsulates several kinds of user commands.  A user command
 * can be generated by a menu action or keyboard accelerator.
 */
public struct TCommand {

    enum Type {
	/// File open dialog
	OPEN,
	/// Exit application
	EXIT, };
    
    /// Type of command, one of EXIT, etc.
    public Type type;

    /// Contructor
    public this(Type type) {
	this.type = type;
    }

    /// Make human-readable description of this event
    public string toString() {
	auto writer = appender!string();
	formattedWrite(writer, "%s", type);
	return writer.data;
    }
}
public immutable TCommand cmExit = TCommand(TCommand.Type.EXIT);
public immutable TCommand cmQuit = TCommand(TCommand.Type.EXIT);
public immutable TCommand cmOpen = TCommand(TCommand.Type.OPEN);

/**
 * This is the parent class of all events received from the Terminal.
 */
public class TInputEvent {

    /// Time at which event was generated
    public SysTime time;

    /// Contructor
    public this() {
	time = Clock.currTime();
    }
}

/**
 * This class encapsulates several kinds of mouse input events.
 */
public class TMouseEvent : TInputEvent {

    enum Type {
	/// Mouse motion.  X and Y will have screen coordinates.
	MOUSE_MOTION,

	/// Mouse button down.  X and Y will have screen coordinates.
	MOUSE_DOWN,

	/// Mouse button up.  X and Y will have screen coordinates.
	MOUSE_UP, };
    
    /// Type of event, one of MOUSE_MOTION, MOUSE_UP, or MOUSE_DOWN, or KEYPRESS
    public Type type;

    /// Mouse X - relative coordinates
    public int x;

    /// Mouse Y - relative coordinates
    public int y;

    /// Mouse X - absolute screen coordinates
    public int absoluteX;

    /// Mouse Y - absolute screen coordinate
    public int absoluteY;

    /// Mouse button 1 (left button)
    public bool mouse1;

    /// Mouse button 2 (right button)
    public bool mouse2;

    /// Mouse button 3 (middle button)
    public bool mouse3;

    /// Mouse wheel UP (button 4)
    public bool mouseWheelUp;

    /// Mouse wheel DOWN (button 5)
    public bool mouseWheelDown;

    /// Contructor
    public this(Type type) {
	this.type = type;
    }

    /// Make human-readable description of this event
    override public string toString() {
	auto writer = appender!string();
	formattedWrite(writer, "Mouse: %s x %d y %d absoluteX %d absoluteY %d 1 %s 2 %s 3 %s DOWN %s UP %s",
	    type,
	    x, y,
	    absoluteX, absoluteY,
	    mouse1,
	    mouse2,
	    mouse3,
	    mouseWheelUp,
	    mouseWheelDown);
	return writer.data;
    }

}

/**
 * This class encapsulates a screen or window resize event.
 */
public class TResizeEvent : TInputEvent {

    /// New width
    public uint width;

    /// New height
    public uint height;

    /// Contructor
    public this(uint width, uint height) {
	this.width = width;
	this.height = height;
    }

    /// Make human-readable description of this event
    override public string toString() {
	auto writer = appender!string();
	formattedWrite(writer, "Resize: width = %d height = %d", width, height);
	return writer.data;
    }

}

/**
 * This class encapsulates a keyboard input event.
 */
public class TKeypressEvent : TInputEvent {

    /// Keystroke received
    public TKeypress key;

    /// Contructor
    public this() {
	key = TKeypress(false, 0, ' ', false, false, false);
    }

    /// Contructor
    public this(TKeypress key) {
	this.key = key;
    }

    /// Make human-readable description of this event
    override public string toString() {
	auto writer = appender!string();
	formattedWrite(writer, "Keypress: %s", key.toString());
	return writer.data;
    }
}

/**
 * This class encapsulates a user command event.
 */
public class TCommandEvent : TInputEvent {

    /// Command dispatched
    public TCommand cmd;

    /// Contructor
    public this(TCommand cmd) {
	this.cmd = cmd;
    }

    /// Make human-readable description of this event
    override public string toString() {
	auto writer = appender!string();
	formattedWrite(writer, "CommandEvent: %s", cmd.toString());
	return writer.data;
    }
}

/**
 * This class has convenience methods for emitting output to ANSI
 * X3.64 / ECMA-48 type terminals e.g. xterm, linux, vt100, ansi.sys,
 * etc.
 */
public class Terminal {

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

    /// Set by the SIGWINCH handler to expose window resize events
    private TResizeEvent windowResize = null;

    /// When true, the terminal is sending non-UTF8 bytes when
    /// reporting mouse events.
    private bool brokenTerminalUTFMouse = false;

    /// Reset keyboard/mouse input parser
    private void reset() {
	state = STATE.GROUND;
	paramI = 0;
	params.length = 1;
	params[0] = "";
    }

    /// If true, then we changed stdin and need to change it back
    private bool setRawMode;

    // Used for raw mode
    version(Posix) {
	import core.sys.posix.termios;
	import core.sys.posix.unistd;
	import core.stdc.errno;
	import core.stdc.string;

	// This definition is taken from the Linux man page
	public static void cfmakeraw(termios * termios_p) {
	    termios_p.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON);
	    termios_p.c_oflag &= ~OPOST;
	    termios_p.c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
	    termios_p.c_cflag &= ~(CSIZE | PARENB);
	    termios_p.c_cflag |= CS8;
	}

	private termios oldTermios;

    } else version(Windows) {
	// I'm keeping this for reference, but it doesn't do anything useful
	// for the Terminal class at the moment.
	import core.sys.windows.windows;
    }

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
     * Read one Unicode code point from stdin.
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
	    read(stdin.fileno(), buffer.ptr, 1);
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
	    read(stdin.fileno(), cast(void *)(buffer.ptr) + 1, len);
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

    // Used for getPhsyicalWidth/Height
    version(Posix) {
	private import core.sys.posix.sys.ioctl;
    }
    
    /** 
     * Get the width of the physical console.
     *
     * Returns:
     *    width of console stdin is attached to
     */
    public uint getPhysicalWidth() {
	version(Posix) {
	    // We use TIOCGWINSZ
	    winsize consoleSize;
	    if (ioctl(stdin.fileno(), TIOCGWINSZ, &consoleSize) < 0) {
		// Error.  So assume 80
		return 80;
	    }
	    return consoleSize.ws_col;
	}
    }

    /** 
     * Get the height of the physical console.
     *
     * Returns:
     *    height of console stdin is attached to
     */
    public uint getPhysicalHeight() {
	version(Posix) {
	    // We use TIOCGWINSZ
	    winsize consoleSize;
	    if (ioctl(stdin.fileno(), TIOCGWINSZ, &consoleSize) < 0) {
		// Error.  So assume 24
		return 24;
	    }
	    return consoleSize.ws_row;
	}
    }

    /** 
     * Constructor sets up state for getEvent()
     *
     * Params:
     *    setupStdin = if true, put stdin in raw mode.  The destructor will
     *                 restore to whatever it was.
     */
    public this(bool setupStdin = false) {
	reset();
	mouse1 = false;
	mouse2 = false;
	mouse3 = false;
	if (setupStdin) {
	    version(Posix) {
		termios newTermios;
		tcgetattr(stdin.fileno(), &oldTermios);
		newTermios = oldTermios;
		cfmakeraw(&newTermios);
		tcsetattr(stdin.fileno(), TCSANOW, &newTermios);
	    }
	    setRawMode = true;

	    // Enable mouse reporting and metaSendsEscape
	    stdout.writef("%s%s", mouse(true), xtermMetaSendsEscape(true));
	}

	// Hang onto the window size
	windowResize = new TResizeEvent(getPhysicalWidth(), getPhysicalHeight());
    }

    /// Destructor restores terminal to normal state
    public ~this() {
	if (setRawMode) {
	    version(Posix) {
		tcsetattr(stdin.fileno(), TCSANOW, &oldTermios);
	    }
	    // Disable mouse reporting and show cursor
	    stdout.writef("%s%s", mouse(false), cursor(true));
	}
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

	// stderr.writef("controlChar: %02x\n", ch);

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

	// stderr.writef("buttons: %04x\r\n", buttons);

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
		TResizeEvent event = new TResizeEvent(newWidth, newHeight);
		windowResize.width = newWidth;
		windowResize.height = newHeight;
		events ~= event;
	    }

	    // Nothing else to do, bail out
	    return events;
	}

	// stderr.writef("state: %s ch %c\r\n", state, ch);

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
		    events ~= keypress;
		    reset();
		    return events;
		case 'B':
		    // Down
		    TKeypressEvent keypress = new TKeypressEvent();
		    keypress.key.isKey = true;
		    keypress.key.fnKey = TKeypress.DOWN;
		    events ~= keypress;
		    reset();
		    return events;
		case 'C':
		    // Right
		    TKeypressEvent keypress = new TKeypressEvent();
		    keypress.key.isKey = true;
		    keypress.key.fnKey = TKeypress.RIGHT;
		    events ~= keypress;
		    reset();
		    return events;
		case 'D':
		    // Left
		    TKeypressEvent keypress = new TKeypressEvent();
		    keypress.key.isKey = true;
		    keypress.key.fnKey = TKeypress.LEFT;
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
     *    color = one of the COLOR_WHITE, COLOR_BLUE, etc. constants
     *    foreground = if true, this is a foreground color
     *    header = if true, make the full header, otherwise just emit
     *    the color parameter e.g. "42;"
     *    
     * Returns:
     *    the string to emit to an ANSI / ECMA-style terminal, e.g. "\033[42m"
     */
    public static string color(ubyte color, bool foreground, bool header = true) {
	// Convert COLOR_* values to SGR numerics
	if (foreground) {
	    color += 30;
	} else {
	    color += 40;
	}

	auto writer = appender!string();
	if (header) {
	    formattedWrite(writer, "\033[%dm", color);
	} else {
	    formattedWrite(writer, "%d;", color);
	}
	return writer.data;
    }

    /**
     * Create a SGR parameter sequence for both foreground and
     * background color change.
     *
     * Params:
     *    foreColor = one of the COLOR_WHITE, COLOR_BLUE, etc. constants
     *    backColor = one of the COLOR_WHITE, COLOR_BLUE, etc. constants
     *    header = if true, make the full header, otherwise just emit
     *    the color parameter e.g. "31;42;"
     *    
     * Returns:
     *    the string to emit to an ANSI / ECMA-style terminal, e.g. "\033[31;42m"
     */
    public static string color(ubyte foreColor, ubyte backColor, bool header = true) {
	// Convert COLOR_* values to SGR numerics
	backColor += 40;
	foreColor += 30;

	auto writer = appender!string();
	if (header) {
	    formattedWrite(writer, "\033[%d;%dm", foreColor, backColor);
	} else {
	    formattedWrite(writer, "%d;%d;", foreColor, backColor);
	}
	return writer.data;
    }

    /**
     * Create a SGR parameter sequence for foreground, background, and
     * several attributes.  This sequence first resets all attributes
     * to default, then sets attributes as per the parameters.
     *
     * Params:
     *    foreColor = one of the COLOR_WHITE, COLOR_BLUE, etc. constants
     *    backColor = one of the COLOR_WHITE, COLOR_BLUE, etc. constants
     *    bold = if true, set bold
     *    reverse = if true, set reverse
     *    blink = if true, set blink
     *
     * Returns:
     *    the string to emit to an ANSI / ECMA-style terminal, e.g. "\033[0;1;31;42m"
     */
    public static string color(ubyte foreColor, ubyte backColor, bool bold, bool reverse, bool blink, bool underline) {
	// Convert COLOR_* values to SGR numerics
	backColor += 40;
	foreColor += 30;

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
	formattedWrite(writer, "%d;%dm", foreColor, backColor);
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
	return "0;37;40;";
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
     *    the string to emit to an ANSI / ECMA-style terminal, e.g. "\033[4m"
     */
    public static string cursor(bool on) {
	if (on) {
	    return "\033[?25h";
	}
	return "\033[?25l";
    }

    /**
     * Clear the entire screen.  Because some terminals use
     * back-color-erase, set the color to blank beforehand.
     * 
     * Returns:
     *    the string to emit to an ANSI / ECMA-style terminal
     */
    public static string clearAll() {
	return "\033[0;37;40m\033[2J";
    }

    /**
     * Clear the line up the cursor (inclusive).  Because some
     * terminals use back-color-erase, set the color to blank
     * beforehand.
     * 
     * Returns:
     *    the string to emit to an ANSI / ECMA-style terminal
     */
    public static string clearRemainingLine() {
	return "\033[0;37;40m\033[K";
    }

    /**
     * Clear the line from the cursor (inclusive) to the end of the
     * screen.  Because some terminals use back-color-erase, set the
     * color to blank beforehand.
     * 
     * Returns:
     *    the string to emit to an ANSI / ECMA-style terminal
     */
    public static string clearPreceedingLine() {
	return "\033[0;37;40m\033[1K";
    }

    /**
     * Clear the line.  Because some terminals use back-color-erase,
     * set the color to blank beforehand.
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
     * This also sends the sequence to hide the X11 pointer in the
     * window, but they don't seem to work.
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
	    return "\033[?1003;1005h\033[>2p\033[?1049h";
	}
	return "\033[?1003;1005l\033[>1p\033[?1049l";
    }

};

/**
 * ColorTheme is a collection of colors keyed by string.
 */
public class ColorTheme {

    /// The current theme colors
    private CellAttributes[string] colors;

    /**
     * Retrieve the CellAttributes by name.
     *
     * Params:
     *    name = hash key
     *
     * Returns:
     *    color associated with hash key
     *
     * Throws:
     *    RangeException if no color associated with key
     */ 
    public CellAttributes getColor(string name) {
	CellAttributes attr = colors[name];
	return attr;
    }

    /// Sets to defaults that resemble the Borland IDE colors.
    public void setDefaultTheme() {
	CellAttributes color;

	// TWindow border
	color = new CellAttributes();
	color.foreColor = COLOR_WHITE;
	color.backColor = COLOR_BLUE;
	color.bold = true;
	colors["twindow.border"] = color;

	// TWindow background
	color = new CellAttributes();
	color.foreColor = COLOR_YELLOW;
	color.backColor = COLOR_BLUE;
	color.bold = true;
	colors["twindow.background"] = color;

	// TWindow border - inactive
	color = new CellAttributes();
	color.foreColor = COLOR_BLACK;
	color.backColor = COLOR_BLUE;
	color.bold = true;
	colors["twindow.border.inactive"] = color;

	// TWindow background - inactive
	color = new CellAttributes();
	color.foreColor = COLOR_YELLOW;
	color.backColor = COLOR_BLUE;
	color.bold = true;
	colors["twindow.background.inactive"] = color;

	// TWindow border - modal
	color = new CellAttributes();
	color.foreColor = COLOR_WHITE;
	color.backColor = COLOR_WHITE;
	color.bold = true;
	colors["twindow.border.modal"] = color;

	// TWindow background - modal
	color = new CellAttributes();
	color.foreColor = COLOR_BLACK;
	color.backColor = COLOR_WHITE;
	color.bold = false;
	colors["twindow.background.modal"] = color;

	// TWindow border - modal + inactive
	color = new CellAttributes();
	color.foreColor = COLOR_BLACK;
	color.backColor = COLOR_WHITE;
	color.bold = true;
	colors["twindow.border.modal.inactive"] = color;

	// TWindow background - modal + inactive
	color = new CellAttributes();
	color.foreColor = COLOR_BLACK;
	color.backColor = COLOR_WHITE;
	color.bold = false;
	colors["twindow.background.modal.inactive"] = color;

	// TWindow border - during window movement - modal
	color = new CellAttributes();
	color.foreColor = COLOR_GREEN;
	color.backColor = COLOR_WHITE;
	color.bold = true;
	colors["twindow.border.modal.windowmove"] = color;

	// TWindow border - during window movement
	color = new CellAttributes();
	color.foreColor = COLOR_GREEN;
	color.backColor = COLOR_BLUE;
	color.bold = true;
	colors["twindow.border.windowmove"] = color;

	// TWindow background - during window movement
	color = new CellAttributes();
	color.foreColor = COLOR_YELLOW;
	color.backColor = COLOR_BLUE;
	color.bold = false;
	colors["twindow.background.windowmove"] = color;

	// TApplication background
	color = new CellAttributes();
	color.foreColor = COLOR_BLUE;
	color.backColor = COLOR_WHITE;
	color.bold = false;
	colors["tapplication.background"] = color;

	// TButton text
	color = new CellAttributes();
	color.foreColor = COLOR_BLACK;
	color.backColor = COLOR_GREEN;
	color.bold = false;
	colors["tbutton.inactive"] = color;
	color = new CellAttributes();
	color.foreColor = COLOR_WHITE;
	color.backColor = COLOR_GREEN;
	color.bold = true;
	colors["tbutton.active"] = color;

	// TLabel text
	color = new CellAttributes();
	color.foreColor = COLOR_WHITE;
	color.backColor = COLOR_BLUE;
	color.bold = true;
	colors["tlabel"] = color;

	// TText text
	color = new CellAttributes();
	color.foreColor = COLOR_BLACK;
	color.backColor = COLOR_CYAN;
	color.bold = false;
	colors["ttext"] = color;
	
	// TField text
	color = new CellAttributes();
	color.foreColor = COLOR_WHITE;
	color.backColor = COLOR_BLUE;
	color.bold = false;
	colors["tfield.inactive"] = color;
	color = new CellAttributes();
	color.foreColor = COLOR_YELLOW;
	color.backColor = COLOR_BLACK;
	color.bold = true;
	colors["tfield.active"] = color;

	// TCheckbox
	color = new CellAttributes();
	color.foreColor = COLOR_WHITE;
	color.backColor = COLOR_BLUE;
	color.bold = false;
	colors["tcheckbox.inactive"] = color;
	color = new CellAttributes();
	color.foreColor = COLOR_YELLOW;
	color.backColor = COLOR_BLACK;
	color.bold = true;
	colors["tcheckbox.active"] = color;


	// TRadioButton
	color = new CellAttributes();
	color.foreColor = COLOR_WHITE;
	color.backColor = COLOR_BLUE;
	color.bold = false;
	colors["tradiobutton.inactive"] = color;
	color = new CellAttributes();
	color.foreColor = COLOR_YELLOW;
	color.backColor = COLOR_BLACK;
	color.bold = true;
	colors["tradiobutton.active"] = color;

	// TRadioGroup
	color = new CellAttributes();
	color.foreColor = COLOR_WHITE;
	color.backColor = COLOR_BLUE;
	color.bold = false;
	colors["tradiogroup.inactive"] = color;
	color = new CellAttributes();
	color.foreColor = COLOR_YELLOW;
	color.backColor = COLOR_BLUE;
	color.bold = true;
	colors["tradiogroup.active"] = color;

	// TMenu
	color = new CellAttributes();
	color.foreColor = COLOR_BLACK;
	color.backColor = COLOR_WHITE;
	color.bold = false;
	colors["tmenu"] = color;
	color = new CellAttributes();
	color.foreColor = COLOR_BLACK;
	color.backColor = COLOR_GREEN;
	color.bold = false;
	colors["tmenu.highlighted"] = color;
	color = new CellAttributes();
	color.foreColor = COLOR_RED;
	color.backColor = COLOR_WHITE;
	color.bold = false;
	colors["tmenu.accelerator"] = color;
	color = new CellAttributes();
	color.foreColor = COLOR_RED;
	color.backColor = COLOR_GREEN;
	color.bold = false;
	colors["tmenu.accelerator.highlighted"] = color;

    }

    /// Public constructor.
    public this() {
	setDefaultTheme();
    }
}

// Functions -----------------------------------------------------------------
