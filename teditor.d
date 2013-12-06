/**
 * D Text User Interface library - TEditor class
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
import std.format;
import std.string;
import std.utf;
import base;
import codepage;
import tapplication;
import tscroll;
import twindow;
import twidget;

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * TEditorWidget implements an editable text area.
 */
public class TEditorWidget : TWidget {

    /// Lines of text being edited
    private dstring [] lines;

    /// Current editing line
    private uint editingRow = 0;

    /// Current editing column
    private uint editingColumn = 0;

    /// When true, insert rather than overwrite
    private bool insertMode = true;

    /// Horizontal tab stops
    private uint [] tabStops;

    /// Vertical scrollbar
    private TVScroller vScroller;

    /// Horizontal scrollbar
    private THScroller hScroller;

    /**
     * Reset the tab stops list
     */
    private void resetTabStops() {
	tabStops.length = 0;
	for (int i = 0; (i * 8) <= width; i++) {
	    tabStops.length++;
	    tabStops[i] = i * 8;
	}
    }

    /**
     * Get the maximum width of the lines with text
     *
     * Returns:
     *    the maximum width
     */
    private uint getLineWidth() {
	uint maxLineWidth = 0;
	foreach (line; lines) {
	    if (line.length > maxLineWidth) {
		maxLineWidth = cast(uint)line.length;
	    }
	}
	return maxLineWidth;
    }

    /**
     * Resize text and scrollbars for a new width/height
     */
    public void reflow() {
	// Set vertical scroll bar
	vScroller.x = width - 1;
	vScroller.height = height - 1;
	vScroller.bottomValue = cast(int)lines.length - height + 1;
	if (vScroller.bottomValue < 0) {
	    vScroller.bottomValue = 0;
	}
	vScroller.bigChange = height - 1;

	// Set horizontal scroll bar
	hScroller.y = height - 1;
	hScroller.width = width - 1;
	hScroller.rightValue = getLineWidth() - width + 2;
	if (hScroller.rightValue < 0) {
	    hScroller.rightValue = 0;
	}
	hScroller.bigChange = width - 1;

	// Update scroll bars
	updateCursor();

	// Move the edit position to keep it in the window
	while (editingRow - vScroller.value > height - 2) {
	    editingRow--;
	    updateCursor();
	}
	while (editingColumn - hScroller.value > width - 2) {
	    editingColumn--;
	    updateCursor();
	}

    }

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = width of text area
     *    height = height of text area
     */
    public this(TWidget parent, uint x, uint y, uint width, uint height) {

	// Set parent and window
	super(parent);

	this.x = x;
	this.y = y;
	this.width = width;
	this.height = height;
	this.hasCursor = true;

	resetTabStops();
	vScroller = new TVScroller(this, width - 1, 0, height - 1);
	vScroller.topValue = 0;
	vScroller.value = vScroller.topValue;

	hScroller = new THScroller(this, 0, height - 1, width - 1);
	hScroller.leftValue = 0;
	hScroller.value = hScroller.leftValue;

	// Start with one blank line
	lines ~= "";
	reflow();
    }

    /**
     * Convert a text line to displayable printable characters.
     *
     * Params:
     *    line = text line
     *
     * Returns:
     *    displayable line
     */
    private dstring toDisplayableLine(dstring line) {
	dstring newLine = "";
	uint x = 0;
	foreach (ch; line) {
	    if (ch == 0x09) {
		if (x == 0) {
		    newLine ~= " ";
		    x++;
		}
		while ((x % 8) != 0) {
		    newLine ~= " ";
		    x++;
		}
		continue;
	    }
	    if ((ch < 0x20) || (ch == 0x7F)) {
		newLine ~= "^";
		newLine ~= (ch + 'A');
		x += 2;
		continue;
	    }
	    newLine ~= ch;
	    x++;
	}
	return newLine;
    }

    /**
     * Open a file in this editor.
     *
     * Params:
     *    filename = name of file to open
     */
    public void loadFile(dstring filename) {
	try {
	    string text = std.file.readText!(string)(toUTF8(filename));
	    foreach (line; splitLines!(string)(text)) {
		lines ~= toDisplayableLine(toUTF32(line));
	    }
	} catch (UTFException e) {
	    lines.length = 0;
	    lines ~= "--- Binary File ---";
	}
	editingRow = 0;
	editingColumn = 0;
	reflow();
    }

    /// Draw a static text
    override public void draw() {
	CellAttributes color = window.application.theme.getColor("teditor");
	uint begin = vScroller.value;
	uint topY = 0;
	for (auto i = begin; i < lines.length; i++) {
	    dstring line = lines[i];
	    if (hScroller.value < line.length) {
		line = line[hScroller.value .. $];
	    } else {
		line = "";
	    }
	    window.putStrXY(0, topY,
		leftJustify!(dstring)(line, this.width - 1), color);
	    topY++;
	    if (topY == height - 1) {
		break;
	    }
	}

	// Pad the rest with blank lines
	for (auto i = topY; i < height - 1; i++) {
	    window.hLineXY(0, i, this.width - 1, ' ', color);
	}
    }

    /**
     * Handle mouse events that go to the scroll bars.
     *
     * Params:
     *    mouse = mouse button press event
     *    fn = function to call
     */
    private void doScroll(TMouseEvent mouse, void delegate(TMouseEvent) fn) {
	uint oldHValue = hScroller.value;
	uint oldVValue = vScroller.value;

	// Pass to children
	fn(mouse);

	// Update horizontal movement
	if (hScroller.value > oldHValue) {
	    editingColumn += hScroller.value - oldHValue;
	} else if (hScroller.value < oldHValue) {
	    if (oldHValue - hScroller.value > editingColumn) {
		editingColumn = 0;
	    } else {
		editingColumn -= (oldHValue - hScroller.value);
	    }
	}

	// Update vertical movement
	if (vScroller.value > oldVValue) {
	    editingRow += vScroller.value - oldVValue;
	} else if (vScroller.value < oldVValue) {
	    if (oldVValue - vScroller.value > editingRow) {
		editingRow = 0;
	    } else {
		editingRow -= (oldVValue - vScroller.value);
	    }
	}

	// Update visible window
	updateCursor();
    }

    /// Clamp editingRow / editingColumn to the valid data range.
    private void clampEditingVars() {
	if (editingRow > lines.length - 1) {
	    editingRow = cast(uint)lines.length - 1;
	}
	if (editingColumn > lines[editingRow].length) {
	    editingColumn = cast(uint)lines[editingRow].length;
	}
    }

    /**
     * Move the cursor based on mouse position.
     *
     * Params:
     *    mouse = mouse button press event
     */
    private void mouseMoveCursor(TMouseEvent mouse) {
	if ((mouse.mouse1) &&
	    (mouse.y >= 0) &&
	    (mouse.y <= height - 2) &&
	    (mouse.x >= 0) &&
	    (mouse.x <= width - 2)
	) {
	    uint deltaX = mouse.x - cursorX;
	    editingColumn += deltaX;
	    uint deltaY = mouse.y - cursorY;
	    editingRow += deltaY;
	}
    }

    /**
     * Handle mouse press events.
     *
     * Params:
     *    mouse = mouse button press event
     */
    override protected void onMouseDown(TMouseEvent mouse) {
	if (mouse.mouseWheelUp) {
	    if (vScroller.value > vScroller.topValue) {
		vScroller.value--;
		if (editingRow > 0) {
		    editingRow--;
		}
	    }
	}
	if (mouse.mouseWheelDown) {
	    if (vScroller.value < vScroller.bottomValue) {
		vScroller.value++;
		if (editingRow < lines.length - 1) {
		    editingRow++;
		}
	    }
	}
	mouseMoveCursor(mouse);

	// Pass to children
	super.onMouseDown(mouse);

	// Update visible window
	updateCursor();
    }

    /**
     * Handle mouse motion events.
     *
     * Params:
     *    mouse = mouse button press event
     */
    override protected void onMouseMotion(TMouseEvent mouse) {
	mouseMoveCursor(mouse);
	doScroll(mouse, &super.onMouseMotion);
    }

    /**
     * Handle mouse release events.
     *
     * Params:
     *    mouse = mouse button release event
     */
    override protected void onMouseUp(TMouseEvent mouse) {
	mouseMoveCursor(mouse);
	doScroll(mouse, &super.onMouseUp);
    }

    /// Update the cursor position
    private void updateCursor() {

	clampEditingVars();

	// Update the scrollbar limit
	hScroller.rightValue = getLineWidth() - width + 2;

	// If we are editing outside the visible window, shift the window.
	uint left = hScroller.value;
	uint right = hScroller.value + width - 2;
	if ((editingColumn < left) || (editingColumn > right)) {
	    int newLeft = editingColumn - ((width * 3/4) - 2);
	    if (newLeft < 0) {
		newLeft = 0;
	    }
	    hScroller.value = newLeft;
	}
	if (hScroller.value > hScroller.rightValue) {
	    hScroller.value = hScroller.rightValue;
	}
	if (hScroller.value < hScroller.leftValue) {
	    hScroller.value = hScroller.leftValue;
	}
	if (editingColumn < hScroller.value) {
	    editingColumn = hScroller.value;
	}

	cursorX = editingColumn - hScroller.value;

	vScroller.bottomValue = cast(int)lines.length - height + 1;
	cursorY = editingRow - vScroller.value;
    }

    /**
     * Handle keystrokes.
     *
     * Params:
     *    keypress = keystroke event
     */
    override protected void onKeypress(TKeypressEvent keypress) {
	TKeypress key = keypress.key;
	if (key == kbLeft) {
	    moveLeft();
	} else if (key == kbRight) {
	    moveRight();
	} else if (key == kbUp) {
	    moveUp();
	} else if (key == kbDown) {
	    moveDown();
	} else if (key == kbPgUp) {
	    pageUp();
	} else if (key == kbPgDn) {
	    pageDown();
	} else if (key == kbHome) {
	    home();
	} else if (key == kbEnd) {
	    end();
	} else if (key == kbIns) {
	    insertMode = !insertMode;
	} else if ((key == kbBackspace) || (key == kbBackspaceDel)) {
	    deleteLeft();
	} else if (key == kbDel) {
	    deleteRight();
	} else if (key == kbTab) {
	    tab();
	} else if (key == kbEnter) {
	    enter();
	} else if (key.isKey == false) {
	    editChar(key.ch);
	}
	updateCursor();
    }

    /**
     * Move cursor left
     */
    private void moveLeft() {
	if ((editingColumn == 0) && (editingRow > 0)) {
	    moveUp();
	    editingColumn = cast(uint)lines[editingRow].length;
	    return;
	}

	if (editingColumn > 0) {
	    editingColumn--;
	}
    }

    /**
     * Move cursor right
     */
    private void moveRight() {
	if ((editingColumn == lines[editingRow].length) &&
	    (editingRow < lines.length - 1)
	) {
	    // Go one line below
	    moveDown();
	    editingColumn = 0;
	    return;
	}

	if (editingColumn < lines[editingRow].length) {
	    editingColumn++;
	}
    }

    /**
     * Move cursor up
     */
    private void moveUp() {
	if (editingRow > 0) {
	    editingRow--;
	    if (cursorY == 0) {
		if (vScroller.value > vScroller.topValue) {
		    vScroller.value--;
		}
	    }
	    if (editingColumn > lines[editingRow].length) {
		editingColumn = cast(uint)lines[editingRow].length;
	    }
	}
    }

    /**
     * Move cursor down
     */
    private void moveDown() {
	if (editingRow < lines.length - 1) {
	    editingRow++;
	    if (cursorY == height - 2) {
		vScroller.value++;
	    }
	    if (editingColumn > lines[editingRow].length) {
		editingColumn = cast(uint)lines[editingRow].length;
	    }
	}
    }

    /**
     * Page up
     */
    private void pageUp() {
	if (editingRow < height - 2) {
	    editingRow = 0;
	    vScroller.value = vScroller.topValue;
	} else {
	    editingRow -= height - 2;
	    vScroller.value -= height - 2;
	    if (vScroller.value < vScroller.topValue) {
		vScroller.value = vScroller.topValue;
	    }
	}
    }

    /**
     * Page down
     */
    private void pageDown() {
	editingRow += height - 2;
	vScroller.value += height - 2;
	if (vScroller.value > vScroller.bottomValue) {
	    vScroller.value = vScroller.bottomValue;
	}
    }

    /**
     * Enter
     */
    private void enter() {
	dstring line = lines[editingRow];
	// Split the line right here
	dstring nextLine = line[editingColumn .. $];
	line = line[0 .. editingColumn];
	lines = lines[0 .. editingRow] ~ line ~ nextLine ~ lines[editingRow + 1 .. $];
	editingRow++;
	if (cursorY == height - 2) {
	    vScroller.value++;
	}
	editingColumn = 0;
	hScroller.value = hScroller.leftValue;
    }

    /**
     * Tab
     */
    private void tab() {
	bool oldInsertMode = insertMode;
	insertMode = true;
	foreach (stop; tabStops) {
	    if (stop > editingColumn) {
		auto n = stop - editingColumn;
		for (auto i = 0; i < n; i++) {
		    editChar(' ');
		}
		break;
	    }
	}
	insertMode = oldInsertMode;
    }

    /**
     * Home
     */
    private void home() {
	editingColumn = 0;
    }

    /**
     * End
     */
    private void end() {
	editingColumn = cast(uint)lines[editingRow].length;
    }

    /**
     * Delete character to the left of the cursor (backspace)
     */
    private void deleteLeft() {
	dstring line = lines[editingRow];

	if ((editingColumn == 0) && (editingRow > 0)) {
	    // Merge this line with the one above
	    editingColumn = cast(uint)lines[editingRow - 1].length;
	    lines[editingRow - 1] ~= line;
	    lines = lines[0 .. editingRow] ~ lines[editingRow + 1 .. $];
	    editingRow--;
	    return;
	}

	if (editingColumn > 0) {
	    assert(line.length > 0);
	    line = line[0 .. editingColumn - 1] ~ line[editingColumn .. $];
	    editingColumn--;
	    lines[editingRow] = line;
	}
    }

    /**
     * Delete character to the right of the cursor (delete)
     */
    private void deleteRight() {
	dstring line = lines[editingRow];

	if ((editingColumn == line.length) && (editingRow < lines.length - 1)) {
	    // Merge this line with the one below
	    line ~= lines[editingRow + 1];
	    lines = lines[0 .. editingRow] ~ line ~ lines[editingRow + 2 .. $];
	    return;
	}

	if (editingColumn < line.length) {
	    line = line[0 .. editingColumn] ~ line[editingColumn + 1 .. $];
	    lines[editingRow] = line;
	}
    }

    /**
     * Handle a new character.  If insert
     *
     * Params:
     *    ch = char to append
     */
    private void editChar(dchar ch) {
	dstring line = lines[editingRow];
	if (editingColumn == line.length) {
	    // Append
	    lines[editingRow] ~= ch;
	    editingColumn++;
	    return;
	}
	if (insertMode) {
	    // Insert
	    line = line[0 .. editingColumn] ~ ch ~ line[editingColumn .. $];
	} else {
	    // Overwrite
	    line = line[0 .. editingColumn] ~ ch ~ line[editingColumn + 1 .. $];
	}
	editingColumn++;
	lines[editingRow] = line;
    }
}

/**
 * This implements a resizable editor window.
 */
public class TEditor : TWindow {

    /// Edit field
    private TEditorWidget editField;

    /**
     * Public constructor.
     *
     * Params:
     *    application = TApplication that manages this window
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = width of window
     *    height = height of window
     *    flags = mask of CENTERED, MODAL, or RESIZABLE
     */
    public this(TApplication application, int x, int y, uint width, uint height,
	Flag flags = Flag.CENTERED | Flag.RESIZABLE) {

	super(application, "Editor", x, y, width, height, flags);
	editField = new TEditorWidget(this, 0, 0, width - 1, height - 1);
	onResize(new TResizeEvent(TResizeEvent.Type.Widget, width, height));
	minimumWindowHeight = 8;
    }

    /**
     * Handle window/screen resize events.
     *
     * Params:
     *    event = resize event
     */
    override protected void onResize(TResizeEvent event) {
	if (event.type == TResizeEvent.Type.Widget) {
	    // Resize the text field
	    editField.width = event.width - 2;
	    editField.height = event.height - 2;
	    editField.reflow();
	    return;
	}

	// Pass to children instead
	foreach (w; children) {
	    w.onResize(event);
	}
    }

    /// Draw a static text
    override public void draw() {
	// Draw the box using my superclass
	super.draw();

	// Draw row, column
	auto writer = appender!dstring();
	formattedWrite(writer, " %d:%d %s", editField.editingRow + 1,
	    editField.editingColumn,
	    editField.insertMode ? "" : "Ovwrt ");
	window.putStrXY(3, height - 1, writer.data, getBorder());
    }

    /**
     * Open a file in this editor.
     *
     * Params:
     *    filename = name of file to open
     */
    public void loadFile(dstring filename) {
	title = filename;
	editField.loadFile(filename);
	width = editField.getLineWidth() + 3;
	if (width > application.backend.screen.getWidth()) {
	    width = application.backend.screen.getWidth();
	}
	// Resize the text field
	editField.width = width - 2;
	editField.reflow();

	// Recenter
	center();
    }

}


// Functions -----------------------------------------------------------------
