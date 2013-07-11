/**
 * D Text User Interface library - TDirectoryList class
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
import std.file;
import std.format;
import std.path;
import std.string;
import std.utf;
import base;
import codepage;
import tscroll;
import twidget;

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * TDirectoryList shows the files within a directory.
 */
public class TDirectoryList : TWidget {

    /// Files in the directory
    private DirEntry [] files;

    /// Selected file
    private int selectedFile = -1;

    /// Root path containing files to display
    public dstring path;

    /// Vertical scrollbar
    protected TVScroller vScroller;

    /// Horizontal scrollbar
    protected THScroller hScroller;

    /// Maximum width of a single line
    protected uint maxLineWidth;

    /// The action to perform when the user selects an item
    private void delegate() actionDelegate;
    private void function() actionFunction;

    /// Dispatch to the action function/delegate.
    private void dispatch() {
	assert(selectedFile >= 0);
	assert(selectedFile < files.length);
	if (actionFunction !is null) {
	    actionFunction();
	}
	if (actionDelegate !is null) {
	    actionDelegate();
	}
    }

    /**
     * Format one of the entries for drawing on the screen.
     *
     * Params:
     *    index = index into files
     *
     * Returns:
     *    the line to draw
     */
    private dstring renderFile(uint index) {
	DirEntry file = files[index];
	auto writer = appender!dstring();
	string name = baseName(file.name);
	if (name.length > 20) {
	    name = name[0 .. 17] ~ "...";
	}
	formattedWrite(writer, "%-20s %5uk", name, (file.size / 1024));
	return writer.data;
    }

    /**
     * Resize for a new width/height
     */
    public void reflow() {

	// Convert to absolute path
	path = toUTF32(buildNormalizedPath(absolutePath(toUTF8(path))));

	// Reset the lines
	selectedFile = -1;
	maxLineWidth = 0;
	files.length = 0;

	// Build a list of files in this directory
	foreach (string name; dirEntries(toUTF8(path), SpanMode.shallow)) {
	    if (baseName(name)[0] == '.') {
		continue;
	    }
	    if (isDir(DirEntry(name))) {
		continue;
	    }
	    DirEntry child = dirEntry(name);
	    files ~= child;
	}

	for (auto i = 0; i < files.length; i++) {
	    dstring line = renderFile(i);
	    if (line.length > maxLineWidth) {
		maxLineWidth = cast(uint)line.length;
	    }
	}

	// Start at the top
	if (vScroller is null) {
	    vScroller = new TVScroller(this, width - 1, 0, height - 1);
	} else {
	    vScroller.x = width - 1;
	    vScroller.height = height - 1;
	}
	vScroller.bottomValue = cast(int)files.length - height - 1;
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
	hScroller.rightValue = maxLineWidth - width + 1;
	hScroller.leftValue = 0;
	hScroller.value = 0;
	if (hScroller.rightValue < 0) {
	    hScroller.rightValue = 0;
	}
	hScroller.bigChange = width - 1;
    }

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    path = directory path, must be a directory
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = width of text area
     *    height = height of text area
     */
    public this(TWidget parent, dstring path, uint x, uint y, uint width,
	uint height) {

	// Set parent and window
	super(parent);

	this.x = x;
	this.y = y;
	this.width = width;
	this.height = height;
	this.path = path;

	reflow();
    }

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    path = directory path, must be a directory
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = width of text area
     *    height = height of text area
     *    actionFn = function to call when an item is selected
     */
    public this(TWidget parent, dstring path, uint x, uint y, uint width,
	uint height, void delegate() actionFn) {

	this.actionFunction = null;
	this.actionDelegate = actionFn;
	this(parent, path, x, y, width, height);
    }

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    path = directory path, must be a directory
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = width of text area
     *    height = height of text area
     *    actionFn = function to call when an item is selected
     */
    public this(TWidget parent, dstring path, uint x, uint y, uint width,
	uint height, void function() actionFn) {

	this.actionDelegate = null;
	this.actionFunction = actionFn;
	this(parent, path, x, y, width, height);
    }

    /// Draw a static text
    override public void draw() {
	CellAttributes color;
	uint begin = vScroller.value;
	uint topY = 0;
	for (int i = begin; i < cast(int)files.length - 1; i++) {
	    dstring line = renderFile(i);
	    if (hScroller.value < line.length) {
		line = line[hScroller.value .. $];
	    } else {
		line = "";
	    }
	    if (i == selectedFile) {
		color = window.application.theme.getColor("tdirectorylist.selected");
	    } else if (getAbsoluteActive()) {
		color = window.application.theme.getColor("tdirectorylist");
	    } else {
		color = window.application.theme.getColor("tdirectorylist.inactive");
	    }
	    window.putStrXY(0, topY, leftJustify!(dstring)(line, this.width - 1), color);

	    topY++;
	    if (topY >= height - 1) {
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
	    vScroller.decrement();
	    return;
	}
	if (mouse.mouseWheelDown) {
	    vScroller.increment();
	    return;
	}

	if ((mouse.x < width - 1) &&
	    (mouse.y < height - 1)) {
	    if (vScroller.value + mouse.y < files.length) {
		selectedFile = vScroller.value + mouse.y;
	    }
	    path = toUTF32(files[selectedFile].name);
	    dispatch();
	    return;
	}

	// Pass to children
	super.onMouseDown(mouse);
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
	    hScroller.decrement();
	} else if (key == kbRight) {
	    hScroller.increment();
	} else if (key == kbUp) {
	    vScroller.decrement();
	} else if (key == kbDown) {
	    vScroller.increment();
	} else if (key == kbPgUp) {
	    vScroller.bigDecrement();
	} else if (key == kbPgDn) {
	    vScroller.bigIncrement();
	} else if (key == kbHome) {
	    vScroller.toTop();
	} else if (key == kbEnd) {
	    vScroller.toBottom();
	} else {
	    // Pass other keys (tab etc.) on
	    super.onKeypress(keypress);
	}
    }

}

// Functions -----------------------------------------------------------------
