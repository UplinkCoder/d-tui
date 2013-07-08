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

	resetTabStops();

	// Start at the top
	if (vScroller is null) {
	    vScroller = new TVScroller(this, width - 1, 0, height - 1);
	} else {
	    vScroller.x = width - 1;
	    vScroller.height = height - 1;
	}
	vScroller.bottomValue = cast(int)lines.length - height + 1;
	vScroller.topValue = 0;
	vScroller.value = 0;
	if (vScroller.bottomValue < 0) {
	    vScroller.bottomValue = 0;
	}
	vScroller.bigChange = height - 1;

	// Start at the left
	if (hScroller is null) {
	    hScroller = new THScroller(this, 0, height - 1, width - 1);
	} else {
	    hScroller.y = height - 1;
	    hScroller.width = width - 1;
	}
	hScroller.rightValue = getLineWidth() - width + 2;
	hScroller.leftValue = 0;
	hScroller.value = 0;
	if (hScroller.rightValue < 0) {
	    hScroller.rightValue = 0;
	}
	hScroller.bigChange = width - 1;
    }

    /**
     * Returns my active widget.
     *
     * Returns:
     *    widget that is active, or this if no children
     */
    override public TWidget getActiveChild() {
	// Always return me so that the cursor will be here and not on the
	// scrollbars.
	return this;
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
     *    colorKey = ColorTheme key color to use for foreground text.  Default is "ttext"
     */
    public this(TWidget parent, uint x, uint y, uint width,
	uint height) {

	// Set parent and window
	super(parent);

	this.x = x;
	this.y = y;
	this.width = width;
	this.height = height;
	this.hasCursor = true;

	// Start with one blank line
	// lines ~= "";
	lines ~= "12345678901234567890abcdefg1234567890abcdefgh1234567890zyxwvu0987654321hgfedbc-a-";

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
     * Handle mouse press events.
     *
     * Params:
     *    mouse = mouse button press event
     */
    override protected void onMouseDown(TMouseEvent mouse) {
	if (mouse.mouseWheelUp) {
	    moveUp();
	}
	if (mouse.mouseWheelDown) {
	    moveDown();
	}

	// TODO: reposition cursor

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
	// Pass to children
	super.onMouseDown(mouse);

	// Update visible window
	updateCursor();
    }

    /**
     * Handle mouse release events.
     *
     * Params:
     *    mouse = mouse button release event
     */
    override protected void onMouseUp(TMouseEvent mouse) {
	// Pass to children
	super.onMouseDown(mouse);

	// Update visible window
	updateCursor();
    }

    /// Update the cursor position
    private void updateCursor() {

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
	if (hScroller.value + (width - 2) > lines[editingRow].length - 1) {
	    hScroller.value = cast(uint)lines[editingRow].length - (width/2);
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
     *    event = keystroke event
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
		if (vScroller.value > 0) {
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
	// TODO
    }

    /**
     * Page down
     */
    private void pageDown() {
	// TODO
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
	hScroller.value = 0;
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
}


// Functions -----------------------------------------------------------------
