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

module tui.ttreeview;

// Description ---------------------------------------------------------------

// Imports -------------------------------------------------------------------

import std.array;
import std.file;
import std.format;
import std.path;
import std.string;
import std.utf;
import tui.base;
import tui.codepage;
import tui.tscroll;
import tui.twidget;
import tui.twindow;

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * TDirTreeItem is a single item in a disk directory tree view.
 */
public class TDirTreeItem : TTreeItem {

    /// Directory entry corresponding to this list item
    DirEntry dir;

    /**
     * Called when this item is expanded or collapsed.  this.expanded
     * will be true if this item was just expanded from a mouse click
     * or keypress.
     */
    override public void onExpand() {
	if (dir is null) {
	    return;
	}
	children.length = 0;

	// To be selectable, we must be both readable AND executable on Posix.
	version (Posix) {
	    selectable = true;
	    if (dir.isDir()) {
		if (core.sys.posix.unistd.access(toStringz(dir.name), core.sys.posix.unistd.X_OK) != 0) {
		    selectable = false;
		}
	    }
	    if (core.sys.posix.unistd.access(toStringz(dir.name), core.sys.posix.unistd.R_OK) != 0) {
		selectable = false;
	    }
	}

	assert(dir.isDir());
	expandable = true;

	if ((expanded == false) || (expandable == false)) {
	    view.reflow();
	    return;
	}

	// Refresh my child list
	foreach (string name; dirEntries(dir.name, SpanMode.shallow)) {
	    if (baseName(name)[0] == '.') {
		continue;
	    }
	    if (!isDir(DirEntry(name))) {
		continue;
	    }

	    TDirTreeItem item = new TDirTreeItem(view, toUTF32(name),
		false, false);

	    item.level = this.level + 1;
	    children ~= item;
	}
	children.sort;

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
    override public TTreeItem addChild(dstring text, bool expanded = true) {
	throw new FileException("Do not call addChild(), use onExpand() instead");
    }

    /**
     * Public constructor
     *
     * Params:
     *    view = root TTreeView
     *    text = text for this item
     *    expanded = if true, have it expanded immediately
     *    openParents = if true, expand all paths up the root path and return the root path entry
     */
    public this(TTreeView view, dstring text, bool expanded = false,
	bool openParents = true) {

	TDirTreeItem [] parentItems;
	dstring [] parentPaths;
	bool oldExpanded = expanded;

	if (openParents == true) {
	    expanded = true;

	    // Go up the directory tree
	    string rootPath = buildNormalizedPath(absolutePath(toUTF8(text)));
	    while (rootPath != rootName(rootPath)) {
		parentPaths ~= toUTF32(baseName(rootPath));
		rootPath = dirName(rootPath);
	    }

	    text = toUTF32(rootPath);
	}

	super(view, text, expanded);
	dir = DirEntry(toUTF8(text));
	this.text = baseName(text);
	onExpand();

	if (openParents == true) {
	    TDirTreeItem childPath = this;
	    foreach (p; parentPaths.reverse) {
		foreach (w; childPath.children) {
		    TDirTreeItem child = cast(TDirTreeItem)w;
		    if (child.text == p) {
			childPath = child;
			childPath.expanded = true;
			childPath.onExpand();
			break;
		    }
		}
	    }
	    unselect();
	    view.setSelected(childPath);
	    expanded = oldExpanded;
	}
	view.reflow();
    }
}

/**
 * TTreeItem is a single item in a tree view.
 */
public class TTreeItem : TWidget {

    /// Hang onto reference to my parent TTreeView so I can call its reflow()
    /// when I add a child node.
    private TTreeView view;

    /// Displayable text for this item
    public dstring text;

    /// If true, this item is expanded in the tree view
    public bool expanded = true;

    /// If true, this item can be expanded in the tree view
    public bool expandable = false;

    /// The vertical bars and such along the left side
    private dstring prefix = "";

    /// Whether or not this item is last in its parent's list of children
    private bool last = false;

    /// Tree level
    private uint level = 0;

    /// If true, this item will not be drawn
    public bool invisible = false;

    /// True means selected
    public bool selected = false;

    /// True means select-able
    public bool selectable = true;

    /// Comparison operator sorts on text
    public override int opCmp(Object rhs) {
	auto that = cast(TTreeItem)rhs;
	if (!that) {
	    return 0;
	}
	return text > that.text;
    }

    /**
     * Public constructor
     *
     * Params:
     *    view = root TTreeView
     *    text = text for this item
     *    expanded = if true, have it expanded immediately
     */
    public this(TTreeView view, dstring text, bool expanded) {
	super(view);
	this.text = text;
	this.expanded = expanded;
	this.view = view;

	this.x = 0;
	this.y = 0;
	this.height = 1;
	this.width = view.width - 3;

	if (view.treeRoot is null) {
	    view.setTreeRoot(this, true);
	}

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
     * Returns:
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
	    TTreeItem item = cast(TTreeItem)children[i];
	    assert(item);
	    array ~= item.expandTree(newPrefix, i == children.length - 1 ? true : false);
	}
	return array;
    }

    /**
     * Get the x spot for the + or - to expand/collapse
     *
     * Returns:
     *    column of the expand/collapse button
     */
    private uint getExpanderX() {
	if ((level == 0) || (!expandable)) {
	    return 0;
	}
	return cast(uint)prefix.length + 3;
    }

    /**
     * Recursively unselect my or my children
     */
    private void unselect() {
	if (selected == true) {
	    selected = false;
	    view.setSelected(null);
	}
	foreach (w; children) {
	    TTreeItem item = cast(TTreeItem)w;
	    if (item) {
		item.unselect();
	    }
	}
    }

    /**
     * Handle mouse release events.
     *
     * Params:
     *    mouse = mouse button release event
     */
    override protected void onMouseUp(TMouseEvent mouse) {
	if ((mouse.x == (getExpanderX() - view.hScroller.value)) &&
	    (mouse.y == 0)
	) {
	    if (selectable) {
		// Flip expanded flag
		expanded = !expanded;
		if (expanded == false) {
		    // Unselect children that became invisible
		    unselect();
		}
	    }
	    // Let subclasses do something with this
	    onExpand();
	} else if (mouse.y == 0) {
	    view.setSelected(this);
	    view.dispatch();
	}

	// Update the screen after any thing has expanded/contracted
	view.reflow();
    }

    /**
     * Called when this item is expanded or collapsed.  this.expanded will be
     * true if this item was just expanded from a mouse click or keypress.
     */
    public void onExpand() {
	// Default: do nothing.
	if (!expandable) {
	    return;
	}
    }

    /**
     * Draw this item to a window
     */
    override public void draw() {
	if (invisible) {
	    return;
	}
	int offset = -view.hScroller.value;

	CellAttributes color = window.application.theme.getColor("ttreeview");
	CellAttributes textColor = window.application.theme.getColor("ttreeview");
	CellAttributes expanderColor = window.application.theme.getColor("ttreeview.expandbutton");
	CellAttributes selectedColor = window.application.theme.getColor("ttreeview.selected");

	if (!parent.getAbsoluteActive()) {
	    color = window.application.theme.getColor("ttreeview.inactive");
	    textColor = window.application.theme.getColor("ttreeview.inactive");
	}

	if (!selectable) {
	    textColor = window.application.theme.getColor("ttreeview.unreadable");
	}

	// Blank out the background
	window.hLineXY(0, 0, width, ' ', color);

	uint expandX = 0;
	dstring line = prefix;
	if (level > 0) {
	    if (last) {
		line ~= cp437_chars[0xC0];
	    } else {
		line ~= cp437_chars[0xC3];
	    }
	    line ~= cp437_chars[0xC4];
	    if (expandable) {
		line ~= "[ ] ";
	    }
	}
	window.putStrXY(offset, 0, line, color);
	if (selected) {
	    window.putStrXY(offset + cast(uint)line.length, 0, text, selectedColor);
	} else {
	    window.putStrXY(offset + cast(uint)line.length, 0, text, textColor);
	}
	if ((level > 0) && (expandable)) {
	    if (expanded) {
		window.putCharXY(offset + getExpanderX(), 0, '-', expanderColor);
	    } else {
		window.putCharXY(offset + getExpanderX(), 0, '+', expanderColor);
	    }
	}
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
    private TTreeItem treeRoot;

    /// Maximum width of a single line
    private uint maxLineWidth;

    /// Only one of my children can be selected
    private TTreeItem selectedItem = null;

    /// If true, move the window to put the selected item in view.  This
    /// normally only happens once after setting treeRoot.
    public bool centerWindow = false;

    /// The action to perform when the user selects an item
    private void delegate(TTreeItem) actionDelegate;
    private void function(TTreeItem) actionFunction;

    /// Dispatch to the action function/delegate.
    private void dispatch() {
	assert(selectedItem !is null);
	if (actionFunction !is null) {
	    actionFunction(selectedItem);
	}
	if (actionDelegate !is null) {
	    actionDelegate(selectedItem);
	}
    }

    /**
     * Set treeRoot
     *
     * Params:
     *    treeRoot = ultimate root of tree
     *    centerWindow = if true, move the window to put the root in view
     */
    public void setTreeRoot(TTreeItem treeRoot, bool centerWindow = false) {
	this.treeRoot = treeRoot;
	this.centerWindow = centerWindow;
    }

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
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = width of tree view
     *    height = height of tree view
     *    actionFn = function to call when an item is selected
     */
    public this(TWidget parent, uint x, uint y, uint width, uint height,
	void delegate(TTreeItem) actionFn) {

	this.actionFunction = null;
	this.actionDelegate = actionFn;
	this(parent, x, y, width, height);
    }

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = width of tree view
     *    height = height of tree view
     *    actionFn = function to call when an item is selected
     */
    public this(TWidget parent, uint x, uint y, uint width, uint height,
	void function(TTreeItem) actionFn) {

	this.actionDelegate = null;
	this.actionFunction = actionFn;
	this(parent, x, y, width, height);
    }

    /**
     * Get the tree view item that was selected.
     *
     * Returns:
     *    the selected item, or null if no item is selected
     */
    public TTreeItem getSelected() {
	return selectedItem;
    }

    /**
     * Set the new selected tree view item.
     *
     * Params:
     *    item = new item that became selected
     */
    private void setSelected(TTreeItem item) {
	if (item !is null) {
	    item.selected = true;
	}
	if ((selectedItem !is null) && (selectedItem !is item)) {
	    selectedItem.selected = false;
	}
	selectedItem = item;
    }

    /**
     * Update (or instantiate) vScroller and hScroller
     */
    private void updateScrollers() {
	// Setup vertical scroller
	if (vScroller is null) {
	    vScroller = new TVScroller(this, width - 1, 0, height - 1);
	    vScroller.value = 0;
	    vScroller.topValue = 0;
	}
	vScroller.x = width - 1;
	vScroller.height = height - 1;
	vScroller.bigChange = height - 1;

	// Setup horizontal scroller
	if (hScroller is null) {
	    hScroller = new THScroller(this, 0, height - 1, width - 1);
	    hScroller.value = 0;
	    hScroller.leftValue = 0;
	}
	hScroller.y = height - 1;
	hScroller.width = width - 1;
	hScroller.bigChange = width - 1;
    }

    /**
     * Resize text and scrollbars for a new width/height
     */
    public void reflow() {
	uint selectedRow = 0;
	bool foundSelectedRow = false;

	updateScrollers();
	if (treeRoot is null) {
	    return;
	}

	// Make each child invisible/inactive to start, expandTree() will
	// reactivate the visible ones.
	foreach (w; children) {
	    TTreeItem item = cast(TTreeItem)w;
	    if (item) {
		item.invisible = true;
		item.enabled = false;
	    }
	}

	// Expand the tree into a linear list
	children.length = 0;
	children ~= treeRoot.expandTree("", true);
	foreach (w; children) {
	    TTreeItem item = cast(TTreeItem)w;
	    assert(item);

	    if (item is selectedItem) {
		foundSelectedRow = true;
	    }
	    if (foundSelectedRow == false) {
		selectedRow++;
	    }

	    uint lineWidth = cast(uint)(item.text.length + item.prefix.length + 4);
	    if (lineWidth > maxLineWidth) {
		maxLineWidth = lineWidth;
	    }
	}
	if ((centerWindow) && (foundSelectedRow)) {
	    if ((selectedRow < vScroller.value) ||
		(selectedRow > vScroller.value + height - 2)
	    ) {
		vScroller.value = selectedRow;
		centerWindow = false;
	    }
	}
	updatePositions();

	// Rescale the scroll bars
	vScroller.bottomValue = cast(int)children.length - height + 1;
	if (vScroller.bottomValue < 0) {
	    vScroller.bottomValue = 0;
	}
	/+
	if (vScroller.value > vScroller.bottomValue) {
	    vScroller.value = vScroller.bottomValue;
	}
	+/
	hScroller.rightValue = maxLineWidth - width + 3;
	if (hScroller.rightValue < 0) {
	    hScroller.rightValue = 0;
	}
	/+
	if (hScroller.value > hScroller.rightValue) {
	    hScroller.value = hScroller.rightValue;
	}
	+/
	children ~= hScroller;
	children ~= vScroller;
    }

    /**
     * Update the Y positions of all the children items
     */
    private void updatePositions() {
	if (treeRoot is null) {
	    return;
	}

	uint begin = vScroller.value;
	uint topY = 0;
	for (auto i = 0; i < children.length; i++) {
	    TTreeItem item = cast(TTreeItem)children[i];
	    if (!item) {
		// Skip
		continue;
	    }

	    if (i < begin) {
		// Render invisible
		item.enabled = false;
		item.invisible = true;
		continue;
	    }

	    if (topY >= height - 1) {
		// Render invisible
		item.enabled = false;
		item.invisible = true;
		continue;
	    }

	    item.y = topY;
	    item.enabled = true;
	    item.invisible = false;
	    item.width = width - 1;
	    topY++;
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
	} else if (mouse.mouseWheelDown) {
	    vScroller.increment();
	} else {
	    // Pass to children
	    super.onMouseDown(mouse);
	}

	// Update the screen after the scrollbars have moved
	reflow();
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

	// Update the screen after any thing has expanded/contracted
	reflow();
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
	} else if (key == kbEnter) {
	    if (selectedItem !is null) {
		dispatch();
	    }
	} else {
	    // Pass other keys (tab etc.) on
	    super.onKeypress(keypress);
	}

	// Update the screen after any thing has expanded/contracted
	reflow();
    }

}

// Functions -----------------------------------------------------------------
