/**
 * D Text User Interface library - TLabel class
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

module tui.tlabel;

// Description ---------------------------------------------------------------

// Imports -------------------------------------------------------------------

import std.utf;
import tui.base;
import tui.codepage;
import tui.twidget;

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * TLabel implements a simple label.
 */
public class TLabel : TWidget {

    /// Label text
    public dstring text = "";

    /// Label color
    private string colorKey;

    /**
     * Public constructor
     *
     * Params:
     *    parent = parent widget
     *    text = label on the screen
     *    x = column relative to parent
     *    y = row relative to parent
     *    colorKey = ColorTheme key color to use for foreground text.  Default is "tlabel"
     */
    public this(TWidget parent, dstring text, uint x, uint y,
	string colorKey = "tlabel") {

	// Do this before the twidget constructor
	this.enabled = false;

	// Set parent and window
	super(parent);

	this.text = text;
	this.x = x;
	this.y = y;
	this.height = 1;
	this.width = cast(uint)text.length;
	this.colorKey = colorKey;
    }

    /// Draw a static label
    override public void draw() {
	// Setup my color
	CellAttributes color = new CellAttributes();
	color.setTo(window.application.theme.getColor(colorKey));
	CellAttributes background = window.getBackground();
	color.backColor = background.backColor;

	window.putStrXY(0, 0, text, color);
    }

}

// Functions -----------------------------------------------------------------
