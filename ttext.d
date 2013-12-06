/**
 * D Text User Interface library - TText class
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

import std.string;
import std.utf;
import base;
import codepage;
import twidget;
import tscroll;

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * TText implements a simple text.
 */
public class TText : TWidget {

    /// Text to display
    public dstring text;

    /// Text converted to lines
    protected dstring [] lines;

    /// Text color
    protected string colorKey;

    /// Vertical scrollbar
    protected TVScroller vScroller;

    /// Horizontal scrollbar
    protected THScroller hScroller;

    /// Maximum width of a single line
    protected uint maxLineWidth;

    /// Number of lines between each paragraph
    public uint lineSpacing = 1;

    /**
     * Convenience method used by TWindowLoggerOutput
     *
     * Params:
     *    line = new line to add
     */
    public void addLine(dstring line) {
	if (text.length == 0) {
	    text = line;
	} else {
	    text ~= "\n\n";
	    text ~= line;
	}
	reflow();
    }

    /**
     * Recompute the bounds for the scrollbars
     */
    private void computeBounds() {
	maxLineWidth = 0;
	foreach (line; lines) {
	    if (line.length > maxLineWidth) {
		maxLineWidth = cast(uint)line.length;
	    }
	}

	vScroller.bottomValue = cast(int)lines.length - height + 1;
	if (vScroller.bottomValue < 0) {
	    vScroller.bottomValue = 0;
	}
	if (vScroller.value > vScroller.bottomValue) {
	    vScroller.value = vScroller.bottomValue;
	}

	hScroller.rightValue = maxLineWidth - width + 1;
	if (hScroller.rightValue < 0) {
	    hScroller.rightValue = 0;
	}
	if (hScroller.value > hScroller.rightValue) {
	    hScroller.value = hScroller.rightValue;
	}
    }

    /**
     * Resize text and scrollbars for a new width/height
     */
    public void reflow() {
	// Reset the lines
	lines.length = 0;

	// Break up text into paragraphs
	dstring [] paragraphs = split(text, "\n\n");
	foreach (p; paragraphs) {
	    dstring paragraph = wrap!(dstring)(p, width - 1);
	    lines ~= splitLines!(dstring)(paragraph);
	    for (auto i = 0; i < lineSpacing; i++) {
		lines ~= "";
	    }
	}

	// Start at the top
	if (vScroller is null) {
	    vScroller = new TVScroller(this, width - 1, 0, height - 1);
	    vScroller.topValue = 0;
	    vScroller.value = 0;
	} else {
	    vScroller.x = width - 1;
	    vScroller.height = height - 1;
	}
	vScroller.bigChange = height - 1;

	// Start at the left
	if (hScroller is null) {
	    hScroller = new THScroller(this, 0, height - 1, width - 1);
	    hScroller.leftValue = 0;
	    hScroller.value = 0;
	} else {
	    hScroller.y = height - 1;
	    hScroller.width = width - 1;
	}
	hScroller.bigChange = width - 1;

	computeBounds();
    }

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    text = text on the screen
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = width of text area
     *    height = height of text area
     *    colorKey = ColorTheme key color to use for foreground text.  Default is "ttext"
     */
    public this(TWidget parent, dstring text, uint x, uint y, uint width,
	uint height, string colorKey = "ttext") {

	// Set parent and window
	super(parent);

	this.x = x;
	this.y = y;
	this.width = width;
	this.height = height;
	this.text = text;
	this.colorKey = colorKey;

	reflow();
    }

    /// Draw a static text
    override public void draw() {
	// Setup my color
	CellAttributes color = window.application.theme.getColor(colorKey);

	uint begin = vScroller.value;
	uint topY = 0;
	for (auto i = begin; i < lines.length; i++) {
	    dstring line = lines[i];
	    if (hScroller.value < line.length) {
		line = line[hScroller.value .. $];
	    } else {
		line = "";
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

	// Pass to children
	super.onMouseDown(mouse);
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
