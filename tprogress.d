/**
 * D Text User Interface library - TProgressBar class
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

import std.utf;
import base;
import codepage;
import twidget;

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * TProgressBar implements a simple progress bar.
 */
public class TProgressBar : TWidget {

    /// Value that corresponds to 0% progress
    public int minValue = 0;

    /// Value that corresponds to 100% progress
    public int maxValue = 100;

    /// Current value of the progress
    public int value = 0;

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    x = column relative to parent
     *    y = row relative to parent
     *    width = width of progress bar
     *    value = initial value of percent complete
     */
    public this(TWidget parent, uint x, uint y, uint width, int value = 0) {

	// Do this before the twidget constructor
	this.enabled = false;

	// Set parent and window
	super(parent);

	this.x = x;
	this.y = y;
	this.height = 1;
	this.width = width;
	this.value = value;
    }

    /// Draw a static progress bar
    override public void draw() {
	CellAttributes completeColor = window.application.theme.getColor("tprogressbar.complete");
	CellAttributes incompleteColor = window.application.theme.getColor("tprogressbar.incomplete");

	float progress = (cast(float)value - minValue) / (cast(float)maxValue - minValue);
	for (auto i = 0; i < width; i++) {
	    float iProgress = cast(float)i / width;
	    if (iProgress < progress) {
		window.putCharXY(i, 0, GraphicsChars.HATCH, completeColor);
	    } else {
		window.putCharXY(i, 0, GraphicsChars.BOX, incompleteColor);
	    }
	}
    }

}

// Functions -----------------------------------------------------------------
