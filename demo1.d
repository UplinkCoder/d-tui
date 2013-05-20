/**
 * D Text User Interface library - demonstration program
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
import std.stdio;
import tui;

private TApplication app;
private TWindow window1;
private TWindow window2;

private void doSomething1() {
    window2 = new TWindow(app, "Demo modal", 0, 0, 70, 15, TWindow.MODAL);
    TButton button = new TButton(window2, "Close", 20, 1, &doSomething2);
}

private void doSomething2() {
    app.closeWindow(window2);
}

public void main(string [] args) {
    app = new TApplication();
    TWindow window;
    window = new TWindow(app, "Demo boring", 10, 10, 50, 10);
    window1 = new TWindow(app, "Demo buttonized", 20, 3, 60, 10,
	TWindow.CENTERED | TWindow.RESIZABLE);
    TButton button = new TButton(window1, "Open modal dialog", 20, 1, &doSomething1);
    button = new TButton(window1, "Open modal dialog", 20, 3, &doSomething1);
    app.run();
}

