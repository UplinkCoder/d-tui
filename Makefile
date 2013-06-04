# D Text User Interface library Makefile
# $Id$
#
# This program is licensed under the GNU Lesser General Public License
# Version 3.  Please see the file "COPYING" in this directory for more
# information about the GNU Lesser General Public License Version 3.
#
#     Copyright (C) 2013  Kevin Lamonte
#
# This library is free software; you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this program; if not, see
# http://www.gnu.org/licenses/, or write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301
# USA

default:	all

.SUFFIXES: .o .d

TUI_SRC =	tui.d base.d codepage.d twidget.d tapplication.d twindow.d \
		tmessagebox.d tbutton.d tlabel.d tfield.d tcheckbox.d tradio.d \
		tmenu.d ttimer.d ttext.d

TUI_OBJS =	tui.o base.o codepage.o twidget.o tapplication.o twindow.o \
		tmessagebox.o tbutton.o tlabel.o tfield.o tcheckbox.o tradio.o \
		tmenu.o ttimer.o ttext.o

DC = dmd
INC = -I@srcdir@
DDOCDIR = ./ddoc
# DFLAGS = -w -wi -g $(INC) -release
DFLAGS = -w -wi -g $(INC) -debug -de -Dd$(DDOCDIR)
LDLIBS =
LDFLAGS = -lib $(LDLIBS)

all:	tui demo1

demo1:	tui demo1.d
	$(DC) $(DFLAGS) -ofdemo1 demo1.d libtui.a

clean:
	rm libtui.a core *.o demo1

tui:	$(TUI_OBJS)
	$(DC) $(LDFLAGS) -oflibtui $(TUI_OBJS)

.d.o:
	$(DC) $(DFLAGS) -Dd$(DDOCDIR) -of$@ -c $<
