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
public class TTreeItem {

    /// Displayable text for this item
    public dstring text;

    /// If true, this item is expanded in the tree view
    public bool expanded = false;

    /// Children nodes of this item
    public TTreeItem [] children;
    
    /**
     * Public constructor
     *
     * Params:
     *    text = text for this item
     *    expanded = if true, have it expanded immediately
     */
    public this(dstring text, bool expanded = false) {
	this.text = text;
	this.expanded = expanded;
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
	TTreeItem item = new TTreeItem(text, expanded);
	children ~= item;
	return item;
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

	// Start at the top
	if (vScroller is null) {
	    vScroller = new TVScroller(this, width - 1, 0, height - 1);
	} else {
	    vScroller.x = width - 1;
	    vScroller.height = height - 1;
	}
	vScroller.bottomValue = height - 1;
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
	hScroller.rightValue = width + 1;
	hScroller.leftValue = 0;
	hScroller.value = 0;
	if (hScroller.rightValue < 0) {
	    hScroller.rightValue = 0;
	}
	hScroller.bigChange = width - 1;
    }

    /**
     * Recursively draw the view
     *
     * Params:
     *    level = recursion level (root is 0)
     *    item = tree item to draw
     *    row = row number to render to
     *
     * Return:
     *    the number of lines displayed
     */
    private uint drawTree(uint level, TTreeItem item, uint row) {
	if (row > width - 1) {
	    return 0;
	}
	CellAttributes color = window.application.theme.getColor("ttreeview");
	dstring line = "";
	if (level > 1) {
	    for (auto i = 0; i < level - 1; i++) {
		line ~= cp437_chars[0xB3];
		line ~= ' ';
	    }
	}
	if (level > 0) {
	    line ~= cp437_chars[0xC0];
	    line ~= cp437_chars[0xC4];
	}
	line ~= item.text;
	if (hScroller.value < line.length) {
	    line = line[hScroller.value .. $];
	} else {
	    line = "";
	}
	window.putStrXY(0, row, leftJustify!(dstring)(line, this.width - 1), color);
	uint lines = 1;
	foreach (p; item.children) {
	    lines += drawTree(level + 1, p, lines + row);
	}
	return lines;
    }

    /// Draw a tree view
    override public void draw() {
	drawTree(0, treeRoot, 0);
    }

}

// Functions -----------------------------------------------------------------
