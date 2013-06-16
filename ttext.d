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

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * TText implements a simple text.
 */
public class TText : TWidget {

    /// Text converted to paragraphs
    private dstring [] paragraphs;

    /// Text color
    private CellAttributes color;

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    text = text on the screen
     *    x = column relative to parent
     *    y = row relative to parent
     *    colorKey = ColorTheme key color to use for foreground text.  Default is "ttext"
     */
    public this(TWidget parent, dstring text, uint x, uint y,
	string colorKey = "ttext") {

	// Do this before the twidget constructor
	this.enabled = false;

	// Set parent and window
	super(parent);

	this.x = x;
	this.y = y;

	// Break up text into paragraphs
	this.paragraphs = split(text, "\n\n");

	// Set my size
	onResize(new TResizeEvent(parent.width, parent.height));

	// Setup my color
	color = window.application.theme.getColor(colorKey);
    }

    /// Draw a static text
    override public void draw() {
	height = 0;
	foreach (p; paragraphs) {
	    dstring paragraph = wrap!(dstring)(p, this.width);
	    dstring [] lines = splitLines!(dstring)(paragraph);
	    for (auto i = 0; i < lines.length; i++) {
		window.putStrXY(0, i + height, leftJustify!(dstring)(lines[i],
			this.width), color);
	    }
	    height += cast(uint)lines.length;
	    window.hLineXY(0, height, this.width, ' ', color);
	    height++;
	}
    }

    /**
     * Handle window resize.
     *
     * Params:
     *    resize = resize event
     */
    override protected void onResize(TResizeEvent resize) {
	this.width = parent.width - this.x - 3;

	this.height = 0;
	foreach (p; paragraphs) {
	    dstring paragraph = wrap!(dstring)(p, this.width);
	    dstring [] lines = splitLines!(dstring)(paragraph);
	    this.height += cast(uint)lines.length + 1;
	}
    }

}

// Functions -----------------------------------------------------------------
