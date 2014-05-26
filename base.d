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
import std.datetime;
import std.format;
import std.stdio;
import codepage;

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

enum Color {

    /// Black.  Bold + black = dark grey
    BLACK   = 0,

    /// Red
    RED     = 1,

    /// Green
    GREEN   = 2,

    /// Yellow.  Sometimes not-bold yellow is brown
    YELLOW  = 3,

    /// Blue
    BLUE    = 4,

    /// Magenta (purple)
    MAGENTA = 5,

    /// Cyan (blue-green)
    CYAN    = 6,

    /// White
    WHITE   = 7,
}

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
    public Color foreColor;

    /// Background color.  COLOR_WHITE, COLOR_RED, etc.
    public Color backColor;

    /// Set to default not-bold, white foreground on black background
    public void reset() {
	bold = false;
	blink = false;
	reverse = false;
	protect = false;
	underline = false;
	foreColor = Color.WHITE;
	backColor = Color.BLACK;
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

    /**
     * Convert enum to string
     *
     * Param:
     *    color = Color.RED, Color.BLUE, etc.
     *
     * Returns:
     *    "red", "blue", etc.
     */
    private string stringFromColor(Color color) {
	final switch (color) {
	case Color.BLACK:
	    return "black";
	case Color.WHITE:
	    return "white";
	case Color.RED:
	    return "red";
	case Color.CYAN:
	    return "cyan";
	case Color.GREEN:
	    return "green";
	case Color.MAGENTA:
	    return "magenta";
	case Color.BLUE:
	    return "blue";
	case Color.YELLOW:
	    return "yellow";
	}
    }

    /**
     * Convert string to enum
     *
     * Param:
     *    "red", "blue", etc.
     *
     * Returns:
     *    color = Color.RED, Color.BLUE, etc.
     */
    static private Color colorFromString(string color) {
	switch (std.string.toLower(color)) {
	case "black":
	    return Color.BLACK;
	case "white":
	    return Color.WHITE;
	case "red":
	    return Color.RED;
	case "cyan":
	    return Color.CYAN;
	case "green":
	    return Color.GREEN;
	case "magenta":
	    return Color.MAGENTA;
	case "blue":
	    return Color.BLUE;
	case "yellow":
	    return Color.YELLOW;
	case "brown":
	    return Color.YELLOW;
	default:
	    return Color.WHITE;
	}
    }

    /// Make human-readable description of this CellAttributes
    override public string toString() {
	auto writer = appender!string();
	formattedWrite(writer, "%s%s on %s",
	    bold ? "bold " : "",
	    stringFromColor(foreColor),
	    stringFromColor(backColor));
	return writer.data;
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
	if ((foreColor == Color.WHITE) &&
	    (backColor == Color.BLACK) &&
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

    /// Make human-readable description of this Cell
    override public string toString() {
	auto writer = appender!string();
	formattedWrite(writer, "fore: %d back: %d bold: %s blink: %s ch %c",
	    foreColor, backColor, bold, blink, ch);
	return writer.data;
    }
}

/**
 * This class represents a text-based screen.  Drawing operations
 * write to a logical screen.
 */
public class Screen {

    /// Emit debugging to stderr
    public bool debugToStderr;

    /// Width of the visible window
    protected uint width;

    /// Height of the visible window
    protected uint height;

    /// Drawing offset for x.  Note int and not uint.
    public int offsetX;

    /// Drawing offset for y.  Note int and not uint.
    public int offsetY;

    /// Ignore anything drawn right of clipRight
    public int clipRight;

    /// Ignore anything drawn below clipBottom
    public int clipBottom;

    /// Ignore anything drawn left of clipLeft
    public int clipLeft;

    /// Ignore anything drawn above clipTop
    public int clipTop;

    /// The physical screen last sent out on flush()
    protected Cell [][] physical;

    /// The logical screen being rendered to
    protected Cell [][] logical;

    /// When true, logical != physical
    public bool dirty;

    /// Set if the user explicitly wants to redraw everything starting
    /// with a ECMATerminal.clearAll()
    protected bool reallyCleared;

    /// If true, the cursor is visible and should be placed onscreen at
    /// (cursorX, cursorY) during a call to flushPhysical()
    protected bool cursorVisible;

    /// Cursor X position if visible
    protected uint cursorX;

    /// Cursor Y position if visible
    protected uint cursorY;

    /**
     * Get the attributes at one location.
     *
     * Params:
     *    x = column coordinate.  0 is the left-most column.
     *    y = row coordinate.  0 is the top-most row.
     *
     * Returns:
     *    attributes at (x, y)
     */
    public CellAttributes getAttrXY(int x, int y) {
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
    public void putAttrXY(int x, int y, CellAttributes attr, bool clip = true) {

	int X = x;
	int Y = y;

	if (clip) {
	    if ((x < clipLeft) || (x >= clipRight) || (y < clipTop) || (y >= clipBottom)) {
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
    public void putCharXY(int x, int y, Cell ch) {
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
    public void putCharXY(int x, int y, dchar ch, CellAttributes attr) {
	if ((x < clipLeft) || (x >= clipRight) || (y < clipTop) || (y >= clipBottom)) {
	    return;
	}

	int X = x + offsetX;
	int Y = y + offsetY;

	// stderr.writefln("putCharXY: %d, %d, %c", X, Y, ch);

	if ((X >= 0) && (X < width) && (Y >= 0) && (Y < height)) {
	    dirty = true;

	    // Do not put control characters on the display
	    assert(ch >= 0x20);
	    assert(ch != 0x7F);

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
    public void putCharXY(int x, int y, dchar ch) {
	if ((x < clipLeft) || (x >= clipRight) || (y < clipTop) || (y >= clipBottom)) {
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
    public void putStrXY(int x, int y, dstring str, CellAttributes attr) {
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
    public void putStrXY(int x, int y, dstring str) {
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
    public void vLineXY(int x, int y, int n, dchar ch, CellAttributes attr) {
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
    public void hLineXY(int x, int y, int n, dchar ch, CellAttributes attr) {
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

	clipLeft = 0;
	clipTop = 0;
	clipRight = width;
	clipBottom = height;

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
	clipLeft = 0;
	clipTop = 0;
	clipRight = width;
	clipBottom = height;
    }

    /// Force the screen to be fully cleared and redrawn on the next
    /// flush().
    public void clear() {
	reset();
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
    public void drawBox(int left, int top, int right, int bottom,
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
    public void drawBoxShadow(int left, int top, int right, int bottom) {

	auto boxTop = top;
	auto boxLeft = left;
	auto boxWidth = right - left;
	auto boxHeight = bottom - top;
	CellAttributes shadowAttr = new CellAttributes();

	// Shadows do not honor clipping but they DO honor offset.
	int oldClipRight = clipRight;
	int oldClipBottom = clipBottom;
	clipRight = boxWidth + 2;
	clipBottom = boxHeight + 1;

	for (auto i = 0; i < boxHeight; i++) {
	    putAttrXY(boxLeft + boxWidth, boxTop + 1 + i, shadowAttr);
	    putAttrXY(boxLeft + boxWidth + 1, boxTop + 1 + i, shadowAttr);
	}
	for (auto i = 0; i < boxWidth; i++) {
	    putAttrXY(boxLeft + 2 + i, boxTop + boxHeight, shadowAttr);
	}
	clipRight = oldClipRight;
	clipBottom = oldClipBottom;
    }

    /// Subclasses must provide an implementation to push the logical
    /// screen to the physical device.
    abstract public void flushPhysical();

    /**
     * Put the cursor at (x,y).
     *
     * Params:
     *    visible = if true, the cursor should be visible
     *    x = column coordinate to put the cursor on
     *    y = column coordinate to put the cursor on
     */
    public void putCursor(bool visible, uint x, uint y) {
	cursorVisible = visible;
	cursorX = x;
	cursorY = y;
    }

    /**
     * Hide the cursor
     */
    public void hideCursor() {
	cursorVisible = false;
    }
}

/**
 * This struct represents keystrokes.
 */
public struct TKeypress {

    // Various special keystrokes

    /// "No key"
    public static immutable ubyte NONE	= 255;

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
    const bool opEquals(ref const TKeypress that) {
	return ((isKey == that.isKey) &&
	    (fnKey == that.fnKey) &&
	    (ch == that.ch) &&
	    (alt == that.alt) &&
	    (ctrl == that.ctrl) &&
	    (shift == that.shift)
	);
    }

    /// Make human-readable description of this Keystroke.
    public const dstring toString() {
	auto writer = appender!dstring();
	if (isKey) {
	    switch (fnKey) {
	    case F1:
		formattedWrite(writer, "%s%s%sF1",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case F2:
		formattedWrite(writer, "%s%s%sF2",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case F3:
		formattedWrite(writer, "%s%s%sF3",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case F4:
		formattedWrite(writer, "%s%s%sF4",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case F5:
		formattedWrite(writer, "%s%s%sF5",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case F6:
		formattedWrite(writer, "%s%s%sF6",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case F7:
		formattedWrite(writer, "%s%s%sF7",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case F8:
		formattedWrite(writer, "%s%s%sF8",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case F9:
		formattedWrite(writer, "%s%s%sF9",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case F10:
		formattedWrite(writer, "%s%s%sF10",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case F11:
		formattedWrite(writer, "%s%s%sF11",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case F12:
		formattedWrite(writer, "%s%s%sF12",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case HOME:
		formattedWrite(writer, "%s%s%sHOME",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case END:
		formattedWrite(writer, "%s%s%sEND",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case PGUP:
		formattedWrite(writer, "%s%s%sPGUP",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case PGDN:
		formattedWrite(writer, "%s%s%sPGDN",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case INS:
		formattedWrite(writer, "%s%s%sINS",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case DEL:
		formattedWrite(writer, "%s%s%sDEL",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case RIGHT:
		formattedWrite(writer, "%s%s%sRIGHT",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case LEFT:
		formattedWrite(writer, "%s%s%sLEFT",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case UP:
		formattedWrite(writer, "%s%s%sUP",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case DOWN:
		formattedWrite(writer, "%s%s%sDOWN",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case TAB:
		formattedWrite(writer, "%s%s%sTAB",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case BTAB:
		formattedWrite(writer, "%s%s%sBTAB",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case ENTER:
		formattedWrite(writer, "%s%s%sENTER",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    case ESC:
		formattedWrite(writer, "%s%s%sESC",
		    ctrl ? "Ctrl+" : "",
		    alt ? "Alt+" : "",
		    shift ? "Shift+" : "");
		break;
	    default:
		formattedWrite(writer, "--UNKNOWN--");
		break;
	    }
	} else {
	    if (alt && !shift && !ctrl) {
		// Alt-X
		formattedWrite(writer, "Alt+%c", toUppercase(ch));
	    } else if (!alt && shift && !ctrl) {
		// Shift-X
		formattedWrite(writer, "%c", ch);
	    } else if (!alt && !shift && ctrl) {
		// Ctrl-X
		formattedWrite(writer, "Ctrl+%c", ch);
	    } else if (alt && shift && !ctrl) {
		// Alt-Shift-X
		formattedWrite(writer, "Alt+Shift+%c", ch);
	    } else if (!alt && shift && ctrl) {
		// Ctrl-Shift-X
		formattedWrite(writer, "Ctrl+Shift+%c", ch);
	    } else if (alt && !shift && ctrl) {
		// Ctrl-Alt-X
		formattedWrite(writer, "Ctrl+Alt+%c", toUppercase(ch));
	    } else if (alt && shift && ctrl) {
		// Ctrl-Alt-Shift-X
		formattedWrite(writer, "Ctrl+Alt+Shift+%c", toUppercase(ch));
	    } else {
		// X
		formattedWrite(writer, "%c", ch);
	    }
	}
	return writer.data;
    }
}

/**
 * Convert a keypress to lowercase.  Function keys and ctrl keys are not converted.
 *
 * Params:
 *    key = keypress to convert
 *
 * Returns:
 *    a new struct with the key converted
 */
public TKeypress toLower(TKeypress key) {
    TKeypress newKey = TKeypress(key.isKey, key.fnKey, key.ch, key.alt, key.ctrl, key.shift);
    if (!(key.isKey) && (key.ch >= 'A') && (key.ch <= 'Z') && (!key.ctrl)) {
	newKey.shift = false;
	newKey.ch += 32;
    }
    return newKey;
}

/**
 * Convert a keypress to uppercase.  Function keys and ctrl keys are not converted.
 *
 * Params:
 *    key = keypress to convert
 *
 * Returns:
 *    a new struct with the key converted
 */
public TKeypress toUpper(TKeypress key) {
    TKeypress newKey = TKeypress(key.isKey, key.fnKey, key.ch, key.alt, key.ctrl, key.shift);
    if (!(key.isKey) && (key.ch >= 'a') && (key.ch <= 'z') && (!key.ctrl)) {
	newKey.shift = true;
	newKey.ch -= 32;
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

// Special "no-key" keypress, used to ignore undefined keystrokes
public immutable TKeypress kbNoKey = TKeypress(true, TKeypress.NONE, ' ', false, false, false);
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
	/// Immediately abort the application (e.g. remote side closed connection)
	ABORT,

	/// File open dialog
	OPEN,
	/// Exit application
	EXIT,
	/// Spawn OS shell window
	SHELL,
	/// Cut selected text and copy to the clipboard
	CUT,
	/// Copy selected text to clipboard
	COPY,
	/// Paste from clipboard
	PASTE,
	/// Clear selected text without copying it to the clipboard
	CLEAR,
	/// Tile windows
	TILE,
	/// Cascade windows
	CASCADE,
	/// Close all windows
	CLOSE_ALL,
	/// Move (move/resize) window
	WINDOW_MOVE,
	/// Zoom (maximize/restore) window
	WINDOW_ZOOM,
	/// Next window (like Alt-TAB)
	WINDOW_NEXT,
	/// Previous window (like Shift-Alt-TAB)
	WINDOW_PREVIOUS,
	/// Close window
	WINDOW_CLOSE,

    }

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
public immutable TCommand cmAbort = TCommand(TCommand.Type.ABORT);
public immutable TCommand cmExit = TCommand(TCommand.Type.EXIT);
public immutable TCommand cmQuit = TCommand(TCommand.Type.EXIT);
public immutable TCommand cmOpen = TCommand(TCommand.Type.OPEN);
public immutable TCommand cmShell = TCommand(TCommand.Type.SHELL);
public immutable TCommand cmCut = TCommand(TCommand.Type.CUT);
public immutable TCommand cmCopy = TCommand(TCommand.Type.COPY);
public immutable TCommand cmPaste = TCommand(TCommand.Type.PASTE);
public immutable TCommand cmClear = TCommand(TCommand.Type.CLEAR);
public immutable TCommand cmTile = TCommand(TCommand.Type.TILE);
public immutable TCommand cmCascade = TCommand(TCommand.Type.CASCADE);
public immutable TCommand cmCloseAll = TCommand(TCommand.Type.CLOSE_ALL);
public immutable TCommand cmWindowMove = TCommand(TCommand.Type.WINDOW_MOVE);
public immutable TCommand cmWindowZoom = TCommand(TCommand.Type.WINDOW_ZOOM);
public immutable TCommand cmWindowNext = TCommand(TCommand.Type.WINDOW_NEXT);
public immutable TCommand cmWindowPrevious = TCommand(TCommand.Type.WINDOW_PREVIOUS);
public immutable TCommand cmWindowClose = TCommand(TCommand.Type.WINDOW_CLOSE);

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
	MOUSE_UP, }

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

    /// Resize events can be generated for either a total screen resize or a
    /// widget/window resize.
    public enum Type {
	Screen,
	Widget, }

    /// The type of resize
    public Type type;

    /// New width
    public uint width;

    /// New height
    public uint height;

    /// Contructor
    public this(Type type, uint width, uint height) {
	this.type = type;
	this.width = width;
	this.height = height;
    }

    /// Make human-readable description of this event
    override public string toString() {
	auto writer = appender!string();
	formattedWrite(writer, "Resize: %s width = %d height = %d", type, width, height);
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
 * This class encapsulates a menu selection event.
 * TApplication.getMenuItem(id) can be used to obtain the TMenuItem itself,
 * say for setting enabled/disabled/checked/etc.
 */
public class TMenuEvent : TInputEvent {

    /// MenuItem ID
    public short id;

    /// Contructor
    public this(short id) {
	this.id = id;
    }

    /// Make human-readable description of this event
    override public string toString() {
	auto writer = appender!string();
	formattedWrite(writer, "MenuEvent: %d", id);
	return writer.data;
    }
}

/**
 * SessionInfo is used to store per-session properties that are determined at
 * different layers of the communication stack.
 */
public interface SessionInfo {

    /// Username getter
    @property public string username();

    /// Username getter/setter
    @property public string username(string name);

    /// Language getter
    @property public string language();

    /// Language getter/setter
    @property public string language(string lang);

    /// Text window width getter
    public uint windowWidth();

    /// Text window height getter
    public uint windowHeight();
}

/**
 * TSessionInfo provides a default session implementation.  The username is
 * blank, language is "en_US", with a 80x24 text window.
 */
public class TSessionInfo : SessionInfo {

    /// User name
    private string name = "";

    /// Language
    private string lang = "en_US";

    /// Text window width
    private uint width = 80;

    /// Text window height
    private uint height = 24;

    /// Username getter
    @property public string username() {
	return this.name;
    }

    /// Username getter/setter
    @property public string username(string name) {
	this.name = name;
	return this.name;
    }

    /// Language getter
    @property public string language() {
	return this.lang;
    }

    /// Language getter/setter
    @property public string language(string lang) {
	this.lang = lang;
	return this.lang;
    }

    /// Text window width getter
    public uint windowWidth() {
	return width;
    }

    /// Text window height getter
    public uint windowHeight() {
	return height;
    }
}

/**
 * This abstract class provides a screen, keyboard, and mouse to
 * TApplication.  It also exposes session information as gleaned from lower
 * levels of the communication stack.
 */
public class Backend {

    /// The session information
    public SessionInfo session;

    /// The screen to draw on
    public Screen screen;

    /**
     * Subclasses must provide an implementation that syncs the
     * logical screen to the physical device.
     */
    abstract public void flushScreen();

    /**
     * Subclasses must provide an implementation to get keyboard,
     * mouse, and screen resize events.
     *
     * Params:
     *    timeout = maximum amount of time to wait for an event
     *
     * Returns:
     *    events received, or an empty list if the timeout was reached
     */
    abstract public TInputEvent [] getEvents(uint timeout);

    /**
     * Subclasses must provide an implementation that closes sockets,
     * restores console, etc.
     */
    abstract public void shutdown();

}

/**
 * MnemonicString is used to render a string like "&File" into a highlighted
 * 'F' and the rest of 'ile'.  To insert a literal '&', use two '&&'
 * characters, e.g. "&File && Stuff" would be "File & Stuff" with the first
 * 'F' highlighted.
 */
public class MnemonicString {

    /// Keyboard shortcut to activate this item
    public dchar shortcut;

    /// Location of the highlighted character
    public int shortcutIdx = -1;

    /// The raw (uncolored) string
    public dstring rawLabel;

    /**
     * Public constructor
     *
     * Params:
     *    label = widget label or title.  Label must contain a keyboard shortcut, denoted by prefixing a letter with "&", e.g. "&File"
     */
    public this(dstring label) {

	// Setup the menu shortcut
	dstring newLabel = "";
	bool foundAmp = false;
	bool foundShortcut = false;
	uint shortcutIdx = 0;
	foreach (c; label) {
	    if (c == '&') {
		if (foundAmp == true) {
		    newLabel ~= '&';
		    shortcutIdx++;
		} else {
		    foundAmp = true;
		}
	    } else {
		newLabel ~= c;
		if (foundAmp == true) {
		    if (foundShortcut == false) {
			shortcut = c;
			foundAmp = false;
			foundShortcut = true;
			this.shortcutIdx = shortcutIdx;
		    }
		} else {
		    shortcutIdx++;
		}
	    }
	}
	this.rawLabel = newLabel;
    }
}

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

    /**
     * Save the colors to an ASCII file
     *
     * Params:
     *    filename = file to write to
     */
    public void save(string filename) {
	auto file = File(filename, "wt");
	foreach (string key; colors.keys.sort) {
	    CellAttributes color = colors[key];
	    file.writefln("%s = %s", key, color);
	}
    }

    /**
     * Read colors from an ASCII file
     *
     * Params:
     *    filename = file to read from
     */
    public void load(string filename) {
	string text = std.file.readText!(string)(filename);
	foreach (line; std.string.splitLines!(string)(text)) {
	    string key;
	    string bold;
	    string foreColor;
	    string on;
	    string backColor;
	    auto tokenCount = formattedRead(line, "%s = %s %s %s %s",
		&key, &bold, &foreColor, &on, &backColor);
	    if (tokenCount == 4) {
		std.stdio.stderr.writefln("1 %s = %s %s %s %s",
		    key, bold, foreColor, on, backColor);

		// "key = blah on blah"
		foreColor = bold;
		backColor = on;
		bold = "";
	    } else if (tokenCount == 5) {
		// "key = bold blah on blah"
		std.stdio.stderr.writefln("2 %s = %s %s %s %s",
		    key, bold, foreColor, on, backColor);
	    } else {
		// Unknown line, skip this one
		continue;
	    }
	    CellAttributes color = new CellAttributes();
	    if (bold == "bold") {
		color.bold = true;
	    }
	    color.foreColor = CellAttributes.colorFromString(foreColor);
	    color.backColor = CellAttributes.colorFromString(backColor);
	    colors[key] = color;
	}
    }

    /// Sets to defaults that resemble the Borland IDE colors.
    public void setDefaultTheme() {
	CellAttributes color;

	// TWindow border
	color = new CellAttributes();
	color.foreColor = Color.WHITE;
	color.backColor = Color.BLUE;
	color.bold = true;
	colors["twindow.border"] = color;

	// TWindow background
	color = new CellAttributes();
	color.foreColor = Color.YELLOW;
	color.backColor = Color.BLUE;
	color.bold = true;
	colors["twindow.background"] = color;

	// TWindow border - inactive
	color = new CellAttributes();
	color.foreColor = Color.BLACK;
	color.backColor = Color.BLUE;
	color.bold = true;
	colors["twindow.border.inactive"] = color;

	// TWindow background - inactive
	color = new CellAttributes();
	color.foreColor = Color.YELLOW;
	color.backColor = Color.BLUE;
	color.bold = true;
	colors["twindow.background.inactive"] = color;

	// TWindow border - modal
	color = new CellAttributes();
	color.foreColor = Color.WHITE;
	color.backColor = Color.WHITE;
	color.bold = true;
	colors["twindow.border.modal"] = color;

	// TWindow background - modal
	color = new CellAttributes();
	color.foreColor = Color.BLACK;
	color.backColor = Color.WHITE;
	color.bold = false;
	colors["twindow.background.modal"] = color;

	// TWindow border - modal + inactive
	color = new CellAttributes();
	color.foreColor = Color.BLACK;
	color.backColor = Color.WHITE;
	color.bold = true;
	colors["twindow.border.modal.inactive"] = color;

	// TWindow background - modal + inactive
	color = new CellAttributes();
	color.foreColor = Color.BLACK;
	color.backColor = Color.WHITE;
	color.bold = false;
	colors["twindow.background.modal.inactive"] = color;

	// TWindow border - during window movement - modal
	color = new CellAttributes();
	color.foreColor = Color.GREEN;
	color.backColor = Color.WHITE;
	color.bold = true;
	colors["twindow.border.modal.windowmove"] = color;

	// TWindow border - during window movement
	color = new CellAttributes();
	color.foreColor = Color.GREEN;
	color.backColor = Color.BLUE;
	color.bold = true;
	colors["twindow.border.windowmove"] = color;

	// TWindow background - during window movement
	color = new CellAttributes();
	color.foreColor = Color.YELLOW;
	color.backColor = Color.BLUE;
	color.bold = false;
	colors["twindow.background.windowmove"] = color;

	// TApplication background
	color = new CellAttributes();
	color.foreColor = Color.BLUE;
	color.backColor = Color.WHITE;
	color.bold = false;
	colors["tapplication.background"] = color;

	// TButton text
	color = new CellAttributes();
	color.foreColor = Color.BLACK;
	color.backColor = Color.GREEN;
	color.bold = false;
	colors["tbutton.inactive"] = color;
	color = new CellAttributes();
	color.foreColor = Color.WHITE;
	color.backColor = Color.GREEN;
	color.bold = true;
	colors["tbutton.active"] = color;
	color = new CellAttributes();
	color.foreColor = Color.BLACK;
	color.backColor = Color.WHITE;
	color.bold = true;
	colors["tbutton.disabled"] = color;
	color = new CellAttributes();
	color.foreColor = Color.YELLOW;
	color.backColor = Color.GREEN;
	color.bold = true;
	colors["tbutton.mnemonic"] = color;
	color = new CellAttributes();
	color.foreColor = Color.YELLOW;
	color.backColor = Color.GREEN;
	color.bold = true;
	colors["tbutton.mnemonic.highlighted"] = color;

	// TLabel text
	color = new CellAttributes();
	color.foreColor = Color.WHITE;
	color.backColor = Color.BLUE;
	color.bold = true;
	colors["tlabel"] = color;

	// TText text
	color = new CellAttributes();
	color.foreColor = Color.WHITE;
	color.backColor = Color.BLACK;
	color.bold = false;
	colors["ttext"] = color;

	// TField text
	color = new CellAttributes();
	color.foreColor = Color.WHITE;
	color.backColor = Color.BLUE;
	color.bold = false;
	colors["tfield.inactive"] = color;
	color = new CellAttributes();
	color.foreColor = Color.YELLOW;
	color.backColor = Color.BLACK;
	color.bold = true;
	colors["tfield.active"] = color;

	// TCheckbox
	color = new CellAttributes();
	color.foreColor = Color.WHITE;
	color.backColor = Color.BLUE;
	color.bold = false;
	colors["tcheckbox.inactive"] = color;
	color = new CellAttributes();
	color.foreColor = Color.YELLOW;
	color.backColor = Color.BLACK;
	color.bold = true;
	colors["tcheckbox.active"] = color;


	// TRadioButton
	color = new CellAttributes();
	color.foreColor = Color.WHITE;
	color.backColor = Color.BLUE;
	color.bold = false;
	colors["tradiobutton.inactive"] = color;
	color = new CellAttributes();
	color.foreColor = Color.YELLOW;
	color.backColor = Color.BLACK;
	color.bold = true;
	colors["tradiobutton.active"] = color;

	// TRadioGroup
	color = new CellAttributes();
	color.foreColor = Color.WHITE;
	color.backColor = Color.BLUE;
	color.bold = false;
	colors["tradiogroup.inactive"] = color;
	color = new CellAttributes();
	color.foreColor = Color.YELLOW;
	color.backColor = Color.BLUE;
	color.bold = true;
	colors["tradiogroup.active"] = color;

	// TMenu
	color = new CellAttributes();
	color.foreColor = Color.BLACK;
	color.backColor = Color.WHITE;
	color.bold = false;
	colors["tmenu"] = color;
	color = new CellAttributes();
	color.foreColor = Color.BLACK;
	color.backColor = Color.GREEN;
	color.bold = false;
	colors["tmenu.highlighted"] = color;
	color = new CellAttributes();
	color.foreColor = Color.RED;
	color.backColor = Color.WHITE;
	color.bold = false;
	colors["tmenu.mnemonic"] = color;
	color = new CellAttributes();
	color.foreColor = Color.RED;
	color.backColor = Color.GREEN;
	color.bold = false;
	colors["tmenu.mnemonic.highlighted"] = color;
	color = new CellAttributes();
	color.foreColor = Color.BLACK;
	color.backColor = Color.WHITE;
	color.bold = true;
	colors["tmenu.disabled"] = color;

	// TProgressBar
	color = new CellAttributes();
	color.foreColor = Color.BLUE;
	color.backColor = Color.BLUE;
	color.bold = true;
	colors["tprogressbar.complete"] = color;
	color = new CellAttributes();
	color.foreColor = Color.WHITE;
	color.backColor = Color.BLUE;
	color.bold = false;
	colors["tprogressbar.incomplete"] = color;

	// THScroller / TVScroller
	color = new CellAttributes();
	color.foreColor = Color.CYAN;
	color.backColor = Color.BLUE;
	color.bold = false;
	colors["tscroller.bar"] = color;
	color = new CellAttributes();
	color.foreColor = Color.BLUE;
	color.backColor = Color.CYAN;
	color.bold = false;
	colors["tscroller.arrows"] = color;

	// TTreeView
	color = new CellAttributes();
	color.foreColor = Color.WHITE;
	color.backColor = Color.BLUE;
	color.bold = false;
	colors["ttreeview"] = color;
	color = new CellAttributes();
	color.foreColor = Color.GREEN;
	color.backColor = Color.BLUE;
	color.bold = true;
	colors["ttreeview.expandbutton"] = color;
	color = new CellAttributes();
	color.foreColor = Color.BLACK;
	color.backColor = Color.CYAN;
	color.bold = false;
	colors["ttreeview.selected"] = color;
	color = new CellAttributes();
	color.foreColor = Color.RED;
	color.backColor = Color.BLUE;
	color.bold = false;
	colors["ttreeview.unreadable"] = color;
	color = new CellAttributes();
	color.foreColor = Color.BLACK;
	color.backColor = Color.BLUE;
	color.bold = true;
	colors["ttreeview.inactive"] = color;

	// TText text
	color = new CellAttributes();
	color.foreColor = Color.WHITE;
	color.backColor = Color.BLUE;
	color.bold = false;
	colors["tdirectorylist"] = color;
	color = new CellAttributes();
	color.foreColor = Color.BLACK;
	color.backColor = Color.CYAN;
	color.bold = false;
	colors["tdirectorylist.selected"] = color;
	color = new CellAttributes();
	color.foreColor = Color.BLACK;
	color.backColor = Color.CYAN;
	color.bold = false;
	colors["tdirectorylist.unreadable"] = color;
	color = new CellAttributes();
	color.foreColor = Color.BLACK;
	color.backColor = Color.BLUE;
	color.bold = true;
	colors["tdirectorylist.inactive"] = color;

	// TEditor
	color = new CellAttributes();
	color.foreColor = Color.WHITE;
	color.backColor = Color.BLACK;
	color.bold = false;
	colors["teditor"] = color;


    }

    /// Public constructor.
    public this() {
	setDefaultTheme();
    }
}

// Functions -----------------------------------------------------------------

/**
 * Invert a color in the same way as (CGA/VGA color XOR 0x7).
 *
 * Params:
 *    color = color to change
 *
 * Returns:
 *    the inverted color
 */
public Color invertColor(Color color) {
    final switch (color) {
    case Color.BLACK:
	return Color.WHITE;
    case Color.WHITE:
	return Color.BLACK;
    case Color.RED:
	return Color.CYAN;
    case Color.CYAN:
	return Color.RED;
    case Color.GREEN:
	return Color.MAGENTA;
    case Color.MAGENTA:
	return Color.GREEN;
    case Color.BLUE:
	return Color.YELLOW;
    case Color.YELLOW:
	return Color.BLUE;
    }
}
