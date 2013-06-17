/**
 * D Text User Interface library - TTreeView class
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
import tscroll;
import twidget;

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * TTreeItem is a single item in a tree view.
 */
public class TTreeItem : TWidget {

    /// Hang onto reference to my parent view so I can call reflow() when
    /// needed.
    private TTreeView view;

    /// Displayable text for this item
    public dstring text;

    /// If true, this item is expanded in the tree view
    public bool expanded = false;

    /// Children nodes of this item
    public TTreeItem [] children;

    /// The vertical bars and such along the left side
    public dstring prefix = "";
    
    /**
     * Public constructor
     *
     * Params:
     *    view = parent TTreeView
     *    text = text for this item
     *    expanded = if true, have it expanded immediately
     */
    public this(TTreeView view, dstring text, bool expanded = false) {
	super(view);

	this.text = text;
	this.expanded = expanded;
	this.view = view;
	view.reflow();
    }
    
    /**
     * Add a child item
     *
     * Params:
     *    text = text for this item
     *    expanded = if true, have it expanded immediately
     *
     * Returns:
     */
    public TTreeItem addChild(dstring text, bool expanded = false) {
	TTreeItem item = new TTreeItem(view, text, expanded);
	children ~= item;
	view.reflow();
	return item;
    }

    /// Draw this item
    override public void draw() {

    }

}

/**
 * TTreeView implements a simple tree view.
 */
public class TTreeView : TWidget {

    /// Vertical scrollbar
    private TVScroller vScroller;

    /// Horizontal scrollbar
    private THScroller hScroller;

    /// Root of the tree
    public TTreeItem treeRoot;

    /// Tree view converted to lines
    private dstring [] lines;

    /// Maximum width of a single line
    private uint maxLineWidth;

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = width of tree view
     *    height = height of tree view
     */
    public this(TWidget parent, uint x, uint y, uint width, uint height) {
	// Set parent and window
	super(parent);

	this.x = x;
	this.y = y;
	this.height = height;
	this.width = width;
    }

    /**
     * Recursively draw the view to the lines[] array.
     *
     * Params:
     *    level = recursion level (root is 0)
     *    prefix = vertical bar of parent levels and such
     *    item = tree item to draw
     *    row = row number to render to
     *    last = if true, this is the "last" leaf node of a tree
     *
     * Return:
     *    the number of lines displayed
     */
    private uint drawTree(uint level, dstring prefix, TTreeItem item, uint row, bool last) {
	CellAttributes color = window.application.theme.getColor("ttreeview");
	dstring line = prefix;
	if (level > 0) {
	    if (last) {
		line ~= cp437_chars[0xC0];
	    } else {
		line ~= cp437_chars[0xC3];
	    }
	    line ~= cp437_chars[0xC4];
	}
	line ~= item.text;
	if (hScroller.value < line.length) {
	    line = line[hScroller.value .. $];
	} else {
	    line = "";
	}
	lines ~= line;

	uint lineNumber = 1;
	dstring newPrefix = prefix;
	if (level > 0) {
	    if (last) {
		newPrefix ~= "  ";
	    } else {
		newPrefix ~= cp437_chars[0xB3];
		newPrefix ~= ' ';
	    }
	}
	for (auto i = 0; i < item.children.length; i++) {
	    auto p = item.children[i];
	    lineNumber += drawTree(level + 1, newPrefix, p, lineNumber + row,
		i == item.children.length - 1 ? true : false);
	}
	return lineNumber;
    }

    /**
     * Resize text and scrollbars for a new width/height
     */
    public void reflow() {
	lines.length = 0;

	if (treeRoot is null) {
	    return;
	}
	
	// Start at the top
	if (vScroller is null) {
	    vScroller = new TVScroller(this, width - 1, 0, height - 1);
	} else {
	    vScroller.x = width - 1;
	    vScroller.height = height - 1;
	}
	vScroller.topValue = 0;
	vScroller.value = 0;
	vScroller.bigChange = height - 1;

	// Start at the left
	if (hScroller is null) {
	    hScroller = new THScroller(this, 0, height - 1, width - 1);
	} else {
	    hScroller.y = height - 1;
	    hScroller.width = width - 1;
	}
	hScroller.leftValue = 0;
	hScroller.value = 0;
	hScroller.bigChange = width - 1;

	drawTree(0, "", treeRoot, 0, true);

	// Update the scroll bars to reflect the recursive data
	foreach (line; lines) {
	    if (line.length > maxLineWidth) {
		maxLineWidth = cast(uint)line.length;
	    }
	}
	vScroller.bottomValue = cast(int)lines.length - height - 1;
	if (vScroller.bottomValue < 0) {
	    vScroller.bottomValue = 0;
	}
	hScroller.rightValue = maxLineWidth - width + 1;
	if (hScroller.rightValue < 0) {
	    hScroller.rightValue = 0;
	}
    }

    /// Draw a tree view
    override public void draw() {
	if (treeRoot is null) {
	    return;
	}
	CellAttributes color = window.application.theme.getColor("ttreeview");
	uint begin = vScroller.value;
	uint topY = 0;
	for (auto i = begin; i < lines.length - 1; i++) {
	    dstring line = lines[i];
	    if (hScroller.value < line.length) {
		line = line[hScroller.value .. $];
	    } else {
		line = "";
	    }
	    window.putStrXY(0, topY,
		leftJustify!(dstring)(line, this.width - 1), color);
	    topY++;
	}
    }

    /**
     * Handle mouse motion events.
     *
     * Params:
     *    mouse = mouse button release event
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
     *    event = keystroke event
     */
    override protected void onKeypress(TKeypressEvent keypress) {
	TKeypress key = keypress.key;
	if (key == kbLeft) {
	    hScroller.decrement();
	    return;
	}
	if (key == kbRight) {
	    hScroller.increment();
	    return;
	}
	if (key == kbUp) {
	    vScroller.decrement();
	    return;
	}
	if (key == kbDown) {
	    vScroller.increment();
	    return;
	}
	if (key == kbPgUp) {
	    vScroller.bigDecrement();
	    return;
	}
	if (key == kbPgDn) {
	    vScroller.bigIncrement();
	    return;
	}
	if (key == kbHome) {
	    vScroller.toTop();
	    return;
	}
	if (key == kbEnd) {
	    vScroller.toBottom();
	    return;
	}

	// Pass other keys (tab etc.) on
	super.onKeypress(keypress);
    }

}

// Functions -----------------------------------------------------------------
