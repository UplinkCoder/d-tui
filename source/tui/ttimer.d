/**
 * D Text User Interface library - TTimer class
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

module tui.ttimer;

// Description ---------------------------------------------------------------

// Imports -------------------------------------------------------------------

import core.time;
import std.datetime;

// Defines -------------------------------------------------------------------

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * TTimer implements a simple timer.
 */
public class TTimer {

    /// The action to perform when the timer ticks
    private void delegate() actionDelegate;
    private void function() actionFunction;

    /// If true, re-schedule after every tick
    public bool recurring = false;

    /// Duration between ticks if this is a recurring timer
    private ulong duration = 0;

    /// The next time this timer needs to be ticked
    public SysTime nextTick;

    /// Tick this timer
    public void tick() {
	if (actionDelegate !is null) {
	    assert(actionFunction is null);
	    actionDelegate();
	}
	if (actionFunction !is null) {
	    assert(actionDelegate is null);
	    actionFunction();
	}
	// Set next tick
	auto ticked = Clock.currTime();
	if (recurring == true) {
	    nextTick = ticked + dur!("msecs")(duration);
	}
    }

    /**
     * Get the number of milliseconds between now and the next tick time.
     *
     * Returns:
     *    number of millis
     */
    public long getMillis() {
	Duration diff = nextTick - Clock.currTime();
	return diff.total!("msecs")();
    }

    /**
     * Private constructor
     *
     * Params:
     *    duration = number of milliseconds to wait between ticks
     *    recurring = if true, re-schedule this timer after every tick
     */
    public this(uint duration, bool recurring = false) {
	this.recurring = recurring;
	this.duration = duration;

	nextTick = Clock.currTime();
	nextTick += dur!("msecs")(duration);
    }

    /**
     * Public constructor
     *
     * Params:
     *    duration = number of milliseconds to wait between ticks
     *    actionFn = function to call when time runs out
     *    recurring = if true, re-schedule this timer after every tick
     */
    public this(uint duration, void function() actionFn, bool recurring = false) {
	this.actionFunction = actionFn;
	this(duration, recurring);
    }

    /**
     * Public constructor
     *
     * Params:
     *    duration = number of milliseconds to wait between ticks
     *    actionFn = function to call when time runs out
     *    recurring = if true, re-schedule this timer after every tick
     */
    public this(uint duration, void delegate() actionFn, bool recurring = false) {
	this.actionDelegate = actionFn;
	this(duration, recurring);
    }

}

// Functions -----------------------------------------------------------------
