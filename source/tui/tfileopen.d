/**
 * D Text User Interface library - TFileOpenBox class
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

module tui.tfileopen;

// Description ---------------------------------------------------------------

// Imports -------------------------------------------------------------------

import core.thread;
import std.file;
import std.path;
import std.string;
import std.utf;
import tui.base;
import tui.codepage;
import tui.tapplication;
import tui.tbutton;
import tui.tdirlist;
import tui.tfield;
import tui.ttreeview;
import tui.twindow;

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * TFileOpenBox is a system-modal dialog for selecting a file to open.
 * Call it like:
 *
 *     filename = application.fileOpenBox("/path/to/file.ext",
 *         TFileOpenBox.Type.OPEN);
 *     if (filename !is null) {
 *        ... the user selected a file, go open it ...
 *     }
 *
 */
public class TFileOpenBox : TWindow {

    public enum Type {
	OPEN,
	SAVE }

    /// String to return, or null if the user canceled
    public dstring filename = null;

    /// Tree view
    private TTreeView treeView;
    private TDirTreeItem treeViewRoot;

    /// Directory list
    private TDirectoryList directoryList;

    /// Text field
    private TField entryField;

    /// Open or Save button
    private TButton openButton;

    /**
     * Update the fields in response to other field updates.
     *
     * Params:
     *    enter = if true, the user manually entered a filename
     */
    private void onUpdate(bool enter) {
	string newFilename = toUTF8(entryField.text);
	if (exists(newFilename)) {
	    if (enter) {
		if (isFile(newFilename)) {
		    filename = entryField.text;
		    application.closeWindow(this);
		}
		if (isDir(newFilename)) {
		    treeViewRoot = new TDirTreeItem(treeView,
			entryField.text, true);
		    treeView.setTreeRoot(treeViewRoot, true);
		    treeView.reflow();
		}
		openButton.enabled = false;
	    } else {
		if (isFile(newFilename)) {
		    openButton.enabled = true;
		} else {
		    openButton.enabled = false;
		}
	    }
	} else {
	    openButton.enabled = false;
	}
    }

    /**
     * Public constructor.  The file open box will be centered on
     * screen.
     *
     * Params:
     *    application = TApplication that manages this window
     *    path = path of selected file
     *    type = one of the Type constants.  Default is Type.OPEN.
     */
    public this(TApplication application, dstring path,
	Type type = Type.OPEN) {

	width = 76;
	height = 22;

	// Register with the TApplication
	super(application, title, 0, 0, this.width, this.height, Flag.MODAL);

	// Add text field
	entryField = addField(1, 1, width - 4, false,
	    toUTF32(buildNormalizedPath(absolutePath(toUTF8(path)))),
	    delegate(bool enter)
	    {
		string newFilename = toUTF8(entryField.text);
		if (exists(newFilename) && isDir(newFilename) && enter) {
		    directoryList.path = entryField.text;
		    directoryList.reflow();
		}
		onUpdate(enter);
	    }
	);

	// Add directory treeView
	treeView = addTreeView(1, 3, 30, height - 6,
	    delegate(TTreeItem item) {
		TDirTreeItem dirItem = cast(TDirTreeItem)item;
		entryField.text = toUTF32(dirItem.dir.name) ~ "/";
		if (exists(dirItem.dir.name) && isDir(dirItem.dir.name)) {
		    directoryList.path = entryField.text;
		    directoryList.reflow();
		}
		onUpdate(false);
	    }
	);
	treeViewRoot = new TDirTreeItem(treeView, path, true);

	// Add directory files list
	directoryList = addDirectoryList(path, 34, 3, 28, height - 6,
	    delegate() {
		entryField.text = directoryList.path;
		onUpdate(false);
	    }
	);

	dstring openLabel = "";
	final switch (type) {
	case Type.OPEN:
	    openLabel = " &Open ";
	    title = "Open File...";
	    break;
	case Type.SAVE:
	    openLabel = " &Save ";
	    title = "Save File...";
	    break;
	}

	// Setup button actions
	openButton = addButton(openLabel, this.width - 12, 3,
	    delegate void() {
		onUpdate(true);
	    }
	);
	openButton.enabled = false;

	addButton("&Cancel", this.width - 12, 5,
	    delegate void() {
		filename = null;
		application.closeWindow(this);
	    }
	);

	// Set the secondaryFiber to run me
	application.enableSecondaryEventReceiver(this);

	// Yield my fiber.  When I come back from the constructor
	// response will already be set.
	Fiber.yield();
    }

    /// Draw a static text
    override public void draw() {
	super.draw();
	screen.vLineXY(33, 4, height - 6, GraphicsChars.WINDOW_SIDE, getBackground());
    }

    /**
     * Handle keystrokes.
     *
     * Params:
     *    keypress = keystroke event
     */
    override protected void onKeypress(TKeypressEvent keypress) {
	// Escape - behave like cancel
	if (keypress.key == kbEsc) {
	    // Close window
	    filename = null;
	    application.closeWindow(this);
	    return;
	}

	// Pass to my parent
	super.onKeypress(keypress);
    }

}

// Functions -----------------------------------------------------------------
