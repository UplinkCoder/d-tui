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

TUI_DIR = tui

TUI_SRC =	$(TUI_DIR)/package.d $(TUI_DIR)/base.d $(TUI_DIR)/codepage.d $(TUI_DIR)/twidget.d \
		$(TUI_DIR)/tapplication.d $(TUI_DIR)/twindow.d $(TUI_DIR)/tmessagebox.d \
		$(TUI_DIR)/tbutton.d $(TUI_DIR)/tlabel.d $(TUI_DIR)/tfield.d $(TUI_DIR)/tcheckbox.d \
		$(TUI_DIR)/tradio.d $(TUI_DIR)/tmenu.d $(TUI_DIR)/ttimer.d $(TUI_DIR)/ttext.d \
		$(TUI_DIR)/tterminal.d $(TUI_DIR)/tprogress.d $(TUI_DIR)/tscroll.d $(TUI_DIR)/ttreeview.d \
		$(TUI_DIR)/teditor.d $(TUI_DIR)/ecma.d $(TUI_DIR)/tfileopen.d $(TUI_DIR)/tdirlist.d \
		$(TUI_DIR)/win32.d

DC = dmd
INC = -I@srcdir@
DDOCDIR = ./ddoc
# DFLAGS = -w -wi $(INC) -release
DFLAGS = -w -wi -g $(INC) -debug -de -Dd$(DDOCDIR)
LDFLAGS_A = -lib -fPIC
LDFLAGS_SO = -shared -fPIC
LDLIBS_A = -L-lutil libtui.a
LDLIBS_SO = -L-lutil -defaultlib=libphobos2.so -L-L. -L-ltui

all:	libtui.a demos

demos:	demo/demo1

demo/demo1:	tui demo/demo1.d
	$(DC) $(DFLAGS) $(LDLIBS_A) -ofdemo/demo1 demo/demo1.d
#	$(DC) $(DFLAGS) $(LDLIBS_SO) -ofdemo/demo1 demo/demo1.d

clean:	clean-demos
	-rm libtui.o libtui.a libtui.so core *.o

clean-demos:
	-rm demo/demo1.o demo/demo1

libtui.a:	$(TUI_SRC)
	$(DC) $(DFLAGS) $(LDFLAGS_A) -oflibtui $(TUI_SRC)

libtui.so:	$(TUI_SRC)
	$(DC) $(DFLAGS) $(LDFLAGS_SO) -oflibtui.so $(TUI_SRC)
