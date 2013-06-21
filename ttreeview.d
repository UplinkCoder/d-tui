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

import std.array;
import std.format;
import std.string;
import std.utf;
import base;
import codepage;
import tscroll;
import twidget;
import twindow;

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * TTreeItem is a single item in a tree view.
 */
public class TTreeItem {

    /// Hang onto reference to my parent view so I can call reflow() when
    /// needed.
    private TTreeView view;

    /// Displayable text for this item
    public dstring text;

    /// If true, this item is expanded in the tree view
    public bool expanded = true;

    /// Children nodes of this item
    public TTreeItem [] children;

    /// The vertical bars and such along the left side
    private dstring prefix = "";

    /// Whether or not this item is last in its parent's list of children
    private bool last = false;

    /// Tree level
    private uint level = 0;

    /// The column location that has the expand/unexpand button
    public uint expandX = 0;

    /**
     * Public constructor
     *
     * Params:
     *    view = parent TTreeView
     *    text = text for this item
     *    expanded = if true, have it expanded immediately
     */
    public this(TTreeView view, dstring text, bool expanded) {
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
    public TTreeItem addChild(dstring text, bool expanded = true) {
	TTreeItem item = new TTreeItem(view, text, expanded);
	item.level = this.level + 1;
	children ~= item;
	view.reflow();
	return item;
    }

    /**
     * Recursively expand the tree into a linear array of items.
     *
     * Params:
     *    prefix = vertical bar of parent levels and such that is set on each child
     *    last = if true, this is the "last" leaf node of a tree
     *
     * Return:
     *    additional items to add to the array
     */
    public TTreeItem [] expandTree(dstring prefix, bool last) {
	TTreeItem [] array;
	this.last = last;
	this.prefix = prefix;
	array ~= this;

	if ((children.length == 0) || (expanded == false)) {
	    return array;
	}

	dstring newPrefix = prefix;
	if (level > 0) {
	    if (last) {
		newPrefix ~= "  ";
	    } else {
		newPrefix ~= cp437_chars[0xB3];
		newPrefix ~= ' ';
	    }
	}
	for (auto i = 0; i < children.length; i++) {
	    auto p = children[i];
	    array ~= p.expandTree(newPrefix, i == children.length - 1 ? true : false);
	}
	return array;
    }

    /**
     * Draw this item to a window
     *
     * Params:
     *    window = window to draw to
     *    x = column to draw at
     *    y = row to draw at
     *    color = color to use for text
     */
    public void draw(TWindow window, uint x, uint y, CellAttributes color) {
	dstring line = prefix;
	if (level > 0) {
	    if (last) {
		line ~= cp437_chars[0xC0];
	    } else {
		line ~= cp437_chars[0xC3];
	    }
	    line ~= cp437_chars[0xC4];
	    if (expanded) {
		line ~= "[-] ";
	    } else {
		line ~= "[+] ";
	    }
	}
	line ~= text;
	window.putStrXY(x, y, line, color);
    }

    /// Make human-readable description of this Keystroke.
    override public string toString() {
	auto writer = appender!string();
	formattedWrite(writer, "TTreeItem expanded: %s prefix: %s text: %s last: %s children.length: %d",
	    expanded, prefix, text, last, children.length);
	return writer.data;
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

    /// Tree view converted from the B-tree form into a linear list
    private TTreeItem [] treeList;

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
     * Resize text and scrollbars for a new width/height
     */
    public void reflow() {
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

	treeList = treeRoot.expandTree("", true);
	assert(treeList.length > 0);
	std.stdio.stderr.writefln("treeList.length: %d", treeList.length);

	// Update the scroll bars to reflect the recursive data
	foreach (item; treeList) {
	    std.stdio.stderr.writefln("%s", item);

	    if (item.text.length + item.prefix.length > maxLineWidth) {
		maxLineWidth = cast(uint)(item.text.length + item.prefix.length);
	    }
	}
	vScroller.bottomValue = cast(int)treeList.length - height - 1;
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
	for (auto i = begin; i < treeList.length; i++) {
	    TTreeItem item = treeList[i];
	    item.draw(window, hScroller.value, topY, color);
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
