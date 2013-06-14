/**
 * D Text User Interface library - TTerminal class
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

/*
 * TODO:
 *
 *     pass vttest
 *     handle resizable window
 *     xterm mouse reporting
 *     split state machine into ECMA48 and VT52
 *
 */

// Description ---------------------------------------------------------------

// Imports -------------------------------------------------------------------

import std.array;
import std.conv;
import std.file;
import std.format;
import std.string;
import std.utf;
import base;
import codepage;
import tapplication;
import twindow;

// Defines -------------------------------------------------------------------

private immutable size_t ECMA48_MAX_LINE_LENGTH = 256;

// DEC VT100/VT220 translation maps ------------------------------------------

// US - Normal "international" (ASCII)
private static immutable wchar dec_us_chars[128] = [
	0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007,
	0x0008, 0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x000E, 0x000F,
	0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017,
	0x0018, 0x0019, 0x001A, 0x001B, 0x001C, 0x001D, 0x001E, 0x001F,
	0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027,
	0x0028, 0x0029, 0x002A, 0x002B, 0x002C, 0x002D, 0x002E, 0x002F,
	0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037,
	0x0038, 0x0039, 0x003A, 0x003B, 0x003C, 0x003D, 0x003E, 0x003F,
	0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047,
	0x0048, 0x0049, 0x004A, 0x004B, 0x004C, 0x004D, 0x004E, 0x004F,
	0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057,
	0x0058, 0x0059, 0x005A, 0x005B, 0x005C, 0x005D, 0x005E, 0x005F,
	0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067,
	0x0068, 0x0069, 0x006A, 0x006B, 0x006C, 0x006D, 0x006E, 0x006F,
	0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077,
	0x0078, 0x0079, 0x007A, 0x007B, 0x007C, 0x007D, 0x007E, 0x0020
];

// VT100 drawing characters
private static immutable wchar dec_special_graphics_chars[128] = [
	0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007,
	0x0008, 0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x000E, 0x000F,
	0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017,
	0x0018, 0x0019, 0x001A, 0x001B, 0x001C, 0x001D, 0x001E, 0x001F,
	0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027,
	0x0028, 0x0029, 0x002A, 0x002B, 0x002C, 0x002D, 0x002E, 0x002F,
	0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037,
	0x0038, 0x0039, 0x003A, 0x003B, 0x003C, 0x003D, 0x003E, 0x003F,
	0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047,
	0x0048, 0x0049, 0x004A, 0x004B, 0x004C, 0x004D, 0x004E, 0x004F,
	0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057,
	0x0058, 0x0059, 0x005A, 0x005B, 0x005C, 0x005D, 0x005E, 0x005F,
	0x2666, 0x2592, 0x2409, 0x240C, 0x240D, 0x240A, 0x00B0, 0x00B1,
	0x2424, 0x240B, 0x2518, 0x2510, 0x250C, 0x2514, 0x253C, 0x23BA,
	0x23BB, 0x2500, 0x23BC, 0x23BD, 0x251C, 0x2524, 0x2534, 0x252C,
	0x2502, 0x2264, 0x2265, 0x03C0, 0x2260, 0x00A3, 0x00B7, 0x0020
];

// Dec Supplemental (DEC multinational)
private static immutable wchar dec_supplemental_chars[128] = [
	0x0080, 0x0081, 0x0082, 0x0083, 0x0084, 0x0085, 0x0086, 0x0087,
	0x0088, 0x0089, 0x008A, 0x008B, 0x008C, 0x008D, 0x008E, 0x008F,
	0x0090, 0x0091, 0x0092, 0x0093, 0x0094, 0x0095, 0x0096, 0x0097,
	0x0098, 0x0099, 0x009A, 0x009B, 0x009C, 0x009D, 0x009E, 0x009F,
	0x0020, 0x00A1, 0x00A2, 0x00A3, 0x00A8, 0x00A5, 0x0020, 0x00A7,
	0x00A4, 0x00A9, 0x00AA, 0x00AB, 0x0020, 0x0020, 0x0020, 0x0020,
	0x00B0, 0x00B1, 0x00B2, 0x00B3, 0x0020, 0x00B5, 0x00B6, 0x00B7,
	0x0020, 0x00B9, 0x00BA, 0x00BB, 0x00BC, 0x00BD, 0x0020, 0x00BF,
	0x00C0, 0x00C1, 0x00C2, 0x00C3, 0x00C4, 0x00C5, 0x00C6, 0x00C7,
	0x00C8, 0x00C9, 0x00CA, 0x00CB, 0x00CC, 0x00CD, 0x00CE, 0x00CF,
	0x0020, 0x00D1, 0x00D2, 0x00D3, 0x00D4, 0x00D5, 0x00D6, 0x0157,
	0x00D8, 0x00D9, 0x00DA, 0x00DB, 0x00DC, 0x0178, 0x0020, 0x00DF,
	0x00E0, 0x00E1, 0x00E2, 0x00E3, 0x00E4, 0x00E5, 0x00E6, 0x00E7,
	0x00E8, 0x00E9, 0x00EA, 0x00EB, 0x00EC, 0x00ED, 0x00EE, 0x00EF,
	0x0020, 0x00F1, 0x00F2, 0x00F3, 0x00F4, 0x00F5, 0x00F6, 0x0153,
	0x00F8, 0x00F9, 0x00FA, 0x00FB, 0x00FC, 0x00FF, 0x0020, 0x0020
];

// UK
private static immutable wchar dec_uk_chars[128] = [
	0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007,
	0x0008, 0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x000E, 0x000F,
	0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017,
	0x0018, 0x0019, 0x001A, 0x001B, 0x001C, 0x001D, 0x001E, 0x001F,
	0x0020, 0x0021, 0x0022, 0x00A3, 0x0024, 0x0025, 0x0026, 0x0027,
	0x0028, 0x0029, 0x002A, 0x002B, 0x002C, 0x002D, 0x002E, 0x002F,
	0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037,
	0x0038, 0x0039, 0x003A, 0x003B, 0x003C, 0x003D, 0x003E, 0x003F,
	0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047,
	0x0048, 0x0049, 0x004A, 0x004B, 0x004C, 0x004D, 0x004E, 0x004F,
	0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057,
	0x0058, 0x0059, 0x005A, 0x005B, 0x005C, 0x005D, 0x005E, 0x005F,
	0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067,
	0x0068, 0x0069, 0x006A, 0x006B, 0x006C, 0x006D, 0x006E, 0x006F,
	0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077,
	0x0078, 0x0079, 0x007A, 0x007B, 0x007C, 0x007D, 0x007E, 0x0020
];

// DUTCH
private static immutable wchar dec_nl_chars[128] = [
	0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007,
	0x0008, 0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x000E, 0x000F,
	0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017,
	0x0018, 0x0019, 0x001A, 0x001B, 0x001C, 0x001D, 0x001E, 0x001F,
	0x0020, 0x0021, 0x0022, 0x00A3, 0x0024, 0x0025, 0x0026, 0x0027,
	0x0028, 0x0029, 0x002A, 0x002B, 0x002C, 0x002D, 0x002E, 0x002F,
	0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037,
	0x0038, 0x0039, 0x003A, 0x003B, 0x003C, 0x003D, 0x003E, 0x003F,
	0x00BE, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047,
	0x0048, 0x0049, 0x004A, 0x004B, 0x004C, 0x004D, 0x004E, 0x004F,
	0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057,
	0x0058, 0x0059, 0x005A, 0x0133, 0x00BD, 0x007C, 0x005E, 0x005F,
	0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067,
	0x0068, 0x0069, 0x006A, 0x006B, 0x006C, 0x006D, 0x006E, 0x006F,
	0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077,
	0x0078, 0x0079, 0x007A, 0x00A8, 0x0066, 0x00BC, 0x00B4, 0x0020
];

// FINNISH
private static immutable wchar dec_fi_chars[128] = [
	0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007,
	0x0008, 0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x000E, 0x000F,
	0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017,
	0x0018, 0x0019, 0x001A, 0x001B, 0x001C, 0x001D, 0x001E, 0x001F,
	0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027,
	0x0028, 0x0029, 0x002A, 0x002B, 0x002C, 0x002D, 0x002E, 0x002F,
	0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037,
	0x0038, 0x0039, 0x003A, 0x003B, 0x003C, 0x003D, 0x003E, 0x003F,
	0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047,
	0x0048, 0x0049, 0x004A, 0x004B, 0x004C, 0x004D, 0x004E, 0x004F,
	0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057,
	0x0058, 0x0059, 0x005A, 0x00C4, 0x00D6, 0x00C5, 0x00DC, 0x005F,
	0x00E9, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067,
	0x0068, 0x0069, 0x006A, 0x006B, 0x006C, 0x006D, 0x006E, 0x006F,
	0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077,
	0x0078, 0x0079, 0x007A, 0x00E4, 0x00F6, 0x00E5, 0x00FC, 0x0020
];

// FRENCH
private static immutable wchar dec_fr_chars[128] = [
	0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007,
	0x0008, 0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x000E, 0x000F,
	0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017,
	0x0018, 0x0019, 0x001A, 0x001B, 0x001C, 0x001D, 0x001E, 0x001F,
	0x0020, 0x0021, 0x0022, 0x00A3, 0x0024, 0x0025, 0x0026, 0x0027,
	0x0028, 0x0029, 0x002A, 0x002B, 0x002C, 0x002D, 0x002E, 0x002F,
	0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037,
	0x0038, 0x0039, 0x003A, 0x003B, 0x003C, 0x003D, 0x003E, 0x003F,
	0x00E0, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047,
	0x0048, 0x0049, 0x004A, 0x004B, 0x004C, 0x004D, 0x004E, 0x004F,
	0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057,
	0x0058, 0x0059, 0x005A, 0x00B0, 0x00E7, 0x00A7, 0x005E, 0x005F,
	0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067,
	0x0068, 0x0069, 0x006A, 0x006B, 0x006C, 0x006D, 0x006E, 0x006F,
	0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077,
	0x0078, 0x0079, 0x007A, 0x00E9, 0x00F9, 0x00E8, 0x00A8, 0x0020
];

// FRENCH_CA
private static immutable wchar dec_fr_CA_chars[128] = [
	0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007,
	0x0008, 0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x000E, 0x000F,
	0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017,
	0x0018, 0x0019, 0x001A, 0x001B, 0x001C, 0x001D, 0x001E, 0x001F,
	0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027,
	0x0028, 0x0029, 0x002A, 0x002B, 0x002C, 0x002D, 0x002E, 0x002F,
	0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037,
	0x0038, 0x0039, 0x003A, 0x003B, 0x003C, 0x003D, 0x003E, 0x003F,
	0x00E0, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047,
	0x0048, 0x0049, 0x004A, 0x004B, 0x004C, 0x004D, 0x004E, 0x004F,
	0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057,
	0x0058, 0x0059, 0x005A, 0x00E2, 0x00E7, 0x00EA, 0x00EE, 0x005F,
	0x00F4, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067,
	0x0068, 0x0069, 0x006A, 0x006B, 0x006C, 0x006D, 0x006E, 0x006F,
	0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077,
	0x0078, 0x0079, 0x007A, 0x00E9, 0x00F9, 0x00E8, 0x00FB, 0x0020
];

// GERMAN
private static immutable wchar dec_de_chars[128] = [
	0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007,
	0x0008, 0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x000E, 0x000F,
	0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017,
	0x0018, 0x0019, 0x001A, 0x001B, 0x001C, 0x001D, 0x001E, 0x001F,
	0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027,
	0x0028, 0x0029, 0x002A, 0x002B, 0x002C, 0x002D, 0x002E, 0x002F,
	0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037,
	0x0038, 0x0039, 0x003A, 0x003B, 0x003C, 0x003D, 0x003E, 0x003F,
	0x00A7, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047,
	0x0048, 0x0049, 0x004A, 0x004B, 0x004C, 0x004D, 0x004E, 0x004F,
	0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057,
	0x0058, 0x0059, 0x005A, 0x00C4, 0x00D6, 0x00DC, 0x005E, 0x005F,
	0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067,
	0x0068, 0x0069, 0x006A, 0x006B, 0x006C, 0x006D, 0x006E, 0x006F,
	0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077,
	0x0078, 0x0079, 0x007A, 0x00E4, 0x00F6, 0x00FC, 0x00DF, 0x0020
];

// ITALIAN
private static immutable wchar dec_it_chars[128] = [
	0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007,
	0x0008, 0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x000E, 0x000F,
	0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017,
	0x0018, 0x0019, 0x001A, 0x001B, 0x001C, 0x001D, 0x001E, 0x001F,
	0x0020, 0x0021, 0x0022, 0x00A3, 0x0024, 0x0025, 0x0026, 0x0027,
	0x0028, 0x0029, 0x002A, 0x002B, 0x002C, 0x002D, 0x002E, 0x002F,
	0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037,
	0x0038, 0x0039, 0x003A, 0x003B, 0x003C, 0x003D, 0x003E, 0x003F,
	0x00A7, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047,
	0x0048, 0x0049, 0x004A, 0x004B, 0x004C, 0x004D, 0x004E, 0x004F,
	0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057,
	0x0058, 0x0059, 0x005A, 0x00B0, 0x00E7, 0x00E9, 0x005E, 0x005F,
	0x00F9, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067,
	0x0068, 0x0069, 0x006A, 0x006B, 0x006C, 0x006D, 0x006E, 0x006F,
	0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077,
	0x0078, 0x0079, 0x007A, 0x00E0, 0x00F2, 0x00E8, 0x00EC, 0x0020
];

// NORWEGIAN
private static immutable wchar dec_no_chars[128] = [
	0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007,
	0x0008, 0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x000E, 0x000F,
	0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017,
	0x0018, 0x0019, 0x001A, 0x001B, 0x001C, 0x001D, 0x001E, 0x001F,
	0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027,
	0x0028, 0x0029, 0x002A, 0x002B, 0x002C, 0x002D, 0x002E, 0x002F,
	0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037,
	0x0038, 0x0039, 0x003A, 0x003B, 0x003C, 0x003D, 0x003E, 0x003F,
	0x00C4, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047,
	0x0048, 0x0049, 0x004A, 0x004B, 0x004C, 0x004D, 0x004E, 0x004F,
	0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057,
	0x0058, 0x0059, 0x005A, 0x00C6, 0x00D8, 0x00C5, 0x00DC, 0x005F,
	0x00E4, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067,
	0x0068, 0x0069, 0x006A, 0x006B, 0x006C, 0x006D, 0x006E, 0x006F,
	0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077,
	0x0078, 0x0079, 0x007A, 0x00E6, 0x00F8, 0x00E5, 0x00FC, 0x0020
];

// SPANISH
private static immutable wchar dec_es_chars[128] = [
	0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007,
	0x0008, 0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x000E, 0x000F,
	0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017,
	0x0018, 0x0019, 0x001A, 0x001B, 0x001C, 0x001D, 0x001E, 0x001F,
	0x0020, 0x0021, 0x0022, 0x00A3, 0x0024, 0x0025, 0x0026, 0x0027,
	0x0028, 0x0029, 0x002A, 0x002B, 0x002C, 0x002D, 0x002E, 0x002F,
	0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037,
	0x0038, 0x0039, 0x003A, 0x003B, 0x003C, 0x003D, 0x003E, 0x003F,
	0x00A7, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047,
	0x0048, 0x0049, 0x004A, 0x004B, 0x004C, 0x004D, 0x004E, 0x004F,
	0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057,
	0x0058, 0x0059, 0x005A, 0x00A1, 0x00D1, 0x00BF, 0x005E, 0x005F,
	0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067,
	0x0068, 0x0069, 0x006A, 0x006B, 0x006C, 0x006D, 0x006E, 0x006F,
	0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077,
	0x0078, 0x0079, 0x007A, 0x00B0, 0x00F1, 0x00E7, 0x007E, 0x0020
];

// SWEDISH
private static immutable wchar dec_sv_chars[128] = [
	0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007,
	0x0008, 0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x000E, 0x000F,
	0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017,
	0x0018, 0x0019, 0x001A, 0x001B, 0x001C, 0x001D, 0x001E, 0x001F,
	0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027,
	0x0028, 0x0029, 0x002A, 0x002B, 0x002C, 0x002D, 0x002E, 0x002F,
	0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037,
	0x0038, 0x0039, 0x003A, 0x003B, 0x003C, 0x003D, 0x003E, 0x003F,
	0x00C9, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047,
	0x0048, 0x0049, 0x004A, 0x004B, 0x004C, 0x004D, 0x004E, 0x004F,
	0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057,
	0x0058, 0x0059, 0x005A, 0x00C4, 0x00D6, 0x00C5, 0x00DC, 0x005F,
	0x00E9, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067,
	0x0068, 0x0069, 0x006A, 0x006B, 0x006C, 0x006D, 0x006E, 0x006F,
	0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077,
	0x0078, 0x0079, 0x007A, 0x00E4, 0x00F6, 0x00E5, 0x00FC, 0x0020
];

// SWISS
private static immutable wchar dec_swiss_chars[128] = [
	0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007,
	0x0008, 0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x000E, 0x000F,
	0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017,
	0x0018, 0x0019, 0x001A, 0x001B, 0x001C, 0x001D, 0x001E, 0x001F,
	0x0020, 0x0021, 0x0022, 0x00F9, 0x0024, 0x0025, 0x0026, 0x0027,
	0x0028, 0x0029, 0x002A, 0x002B, 0x002C, 0x002D, 0x002E, 0x002F,
	0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037,
	0x0038, 0x0039, 0x003A, 0x003B, 0x003C, 0x003D, 0x003E, 0x003F,
	0x00E0, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047,
	0x0048, 0x0049, 0x004A, 0x004B, 0x004C, 0x004D, 0x004E, 0x004F,
	0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057,
	0x0058, 0x0059, 0x005A, 0x00E9, 0x00E7, 0x00EA, 0x00EE, 0x00E8,
	0x00F4, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067,
	0x0068, 0x0069, 0x006A, 0x006B, 0x006C, 0x006D, 0x006E, 0x006F,
	0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077,
	0x0078, 0x0079, 0x007A, 0x00E4, 0x00F6, 0x00FC, 0x00FB, 0x0020
];

// VT52 drawing characters
private static immutable wchar vt52_special_graphics_chars[128] = [
	0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007,
	0x0008, 0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x000E, 0x000F,
	0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017,
	0x0018, 0x0019, 0x001A, 0x001B, 0x001C, 0x001D, 0x001E, 0x001F,
	0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027,
	0x0028, 0x0029, 0x002A, 0x002B, 0x002C, 0x002D, 0x002E, 0x002F,
	0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037,
	0x0038, 0x0039, 0x003A, 0x003B, 0x003C, 0x003D, 0x003E, 0x003F,
	0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047,
	0x0048, 0x0049, 0x004A, 0x004B, 0x004C, 0x004D, 0x004E, 0x004F,
	0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057,
	0x0058, 0x0059, 0x005A, 0x005B, 0x005C, 0x005D, 0x0020, 0x0020,
	0x0020, 0x2588, 0x215F, 0x2592, 0x2592, 0x2592, 0x00B0, 0x00B1,
	0x2190, 0x2026, 0x00F7, 0x2193, 0x23BA, 0x23BA, 0x23BB, 0x23BB,
	0x2500, 0x2500, 0x23BC, 0x23BC, 0x2080, 0x2081, 0x2082, 0x2083,
	0x2084, 0x2085, 0x2086, 0x2087, 0x2088, 0x2089, 0x00B6, 0x0020
];

// Globals -------------------------------------------------------------------

// Classes -------------------------------------------------------------------

/**
 * This implements a complex ANSI ECMA-48/ISO 6429/ANSI X3.64 type
 * consoles, including a scrollback buffer.
 *
 * It currently implements VT100, VT102, VT220, and XTERM with the
 * following caveats:
 * 
 * - Smooth scrolling, printing, keyboard locking, keyboard leds, and
 *   tests from VT100 are not supported.
 *
 * - User-defined keys (DECUDK), downloadable fonts (DECDLD), and
 *   VT100/ANSI compatibility mode (DECSCL) from VT220 are not
 *   supported.  (Also, because DECSCL is not supported, it will fail
 *   the last part of the vttest "Test of VT52 mode" if DeviceType is
 *   set to VT220.)
 *
 * - Numeric/application keys from the number pad are not supported
 *   because they are not exposed from the D-TUI TKeypress API.
 *
 * - VT52 HOLD SCREEN mode is not supported.
 *
 * - In VT52 graphics mode, the 3/, 5/, and 7/ characters (fraction
 *   numerators) are not rendered correctly.
 *
 * - All data meant for the 'printer' (CSI Pc ? i) is discarded.
 */
private class ECMA48 {

    private import std.stdio;

    /// This controls what is sent back from the "Device Attributes"
    /// function.
    public enum DeviceType {
	VT100,
	VT102,
	VT220,
	XTERM };

    /**
     * Return the proper primary Device Attributes string
     *
     * Returns:
     *    string to send to remote side that is appropriate for the this.type
     */
    private dstring deviceTypeResponse() {
	final switch (type) {
	case DeviceType.VT100:
	    // "I am a VT100 with advanced video option" (often VT102)
	    return "\033[?1;2c";

	case DeviceType.VT102:
	    // "I am a VT102"
	    return "\033[?6c";

	case DeviceType.VT220:
	    // "I am a VT220" - 7 bit version
	    if (!s8c1t) {
		return "\033[?62;1;6c";
	    }
	    // "I am a VT220" - 8 bit version
	    return "\u009b?62;1;6c";
	case DeviceType.XTERM:
	    // "I am a VT100 with advanced video option" (often VT102)
	    return "\033[?1;2c";
	}
    }

    /**
     * Return the proper TERM for this device type
     *
     * Returns:
     *    "TERM=vt100", "TERM=xterm", etc.
     */
    public string deviceTypeTerm() {
	final switch (type) {
	case DeviceType.VT100:
	    return "TERM=vt100";

	case DeviceType.VT102:
	    return "TERM=vt102";

	case DeviceType.VT220:
	    return "TERM=vt220";

	case DeviceType.XTERM:
	    return "TERM=xterm";
	}
    }

    /**
     * Return the proper LANG for this device type.  Only XTERM devices know
     * about UTF-8, the others are defined by their standard to be either
     * 7-bit or 8-bit characters only.
     *
     * Params:
     *    baseLang = a base language without UTF-8 flag such as "C" or "en_US"
     *
     * Returns:
     *    "LANG=en_US", "LANG=en_US.UTF-8", etc.
     */
    public string deviceTypeLang(string baseLang) {
	final switch (type) {
	case DeviceType.VT100:
	    return "LANG=" ~ baseLang;

	case DeviceType.VT102:
	    return "LANG=" ~ baseLang;

	case DeviceType.VT220:
	    return "LANG=" ~ baseLang;

	case DeviceType.XTERM:
	    return "LANG=" ~ baseLang ~ ".UTF-8";
	}
    }

    /// The type of emulator to be
    private DeviceType type = DeviceType.VT102;
    
    /// This represents a single line of the display buffer
    private class DisplayLine {

	/// The characters/attributes of the line
	public Cell [] chars;

	/// Double-width line
	public bool doubleWidth = false;

	/**
	 * Double-height line flag:
	 *
	 *   0 = single height
	 *   1 = top half double height
	 *   2 = bottom half double height
	 */
	public int doubleHeight = 0;

	/// DECSCNM - reverse video.  We copy the flag to the line so that
	/// reverse-mode scrollback lines still show inverted colors
	/// correctly.
	public bool reverseColor = false;

	/// Constructor sets everything to normal attributes
	public this() {
	    chars.length = ECMA48_MAX_LINE_LENGTH;
	    for (auto i = 0; i < chars.length; i++) {
		chars[i] = new Cell();
		chars[i].setTo(currentState.attr);
	    }
	}
    };

    /// The scrollback buffer characters + attributes
    private DisplayLine [] scrollback;

    /// The raw display buffer characters + attributes
    private DisplayLine [] display;

    /// Parser character scan states
    enum ScanState {
	GROUND,
	ESCAPE,
	ESCAPE_INTERMEDIATE,
	CSI_ENTRY,
	CSI_PARAM,
	CSI_INTERMEDIATE,
	CSI_IGNORE,
	DCS_ENTRY,
	DCS_INTERMEDIATE,
	DCS_PARAM,
	DCS_PASSTHROUGH,
	DCS_IGNORE,
	SOSPMAPC_STRING,
	OSC_STRING,
	VT52_DIRECT_CURSOR_ADDRESS };

    /// Current scanning state
    private ScanState scanState;

    /// The selected number pad mode (DECKPAM, DECKPNM).  We record this, but
    /// can't really use it in keypress() because we do not see number pad
    /// events from Terminal.processEvents().
    enum KeypadMode {
	Application,
	Numeric };

    /// Arrow keys can emit three different sequences (DECCKM or VT52 submode)
    enum ArrowKeyMode {
	VT52,
	ANSI,
	VT100 };

    /// Available character sets for GL, GR, G0, G1, G2, G3
    enum CharacterSet {
	US,
	UK,
	DRAWING,
	ROM,
	ROM_SPECIAL,
	VT52_GRAPHICS,
	DEC_SUPPLEMENTAL,
	NRC_DUTCH,
	NRC_FINNISH,
	NRC_FRENCH,
	NRC_FRENCH_CA,
	NRC_GERMAN,
	NRC_ITALIAN,
	NRC_NORWEGIAN,
	NRC_SPANISH,
	NRC_SWEDISH,
	NRC_SWISS };

    /// Single-shift states used by the C1 control characters SS2 (0x8E) and
    /// SS3 (0x8F)
    enum Singleshift {
	NONE,
	SS2,
	SS3 };

    /// VT220+ lockshift states
    enum LockshiftMode {
	NONE,
	G1_GR,
	G2_GR,
	G2_GL,
	G3_GR,
	G3_GL };

    /// Physical display width.  We start at 80x24, but the user can resize
    /// us bigger/smaller.
    public int width;

    /// Physical display height.  We start at 80x24, but the user can resize
    /// us bigger/smaller.
    public int height;

    /// Several functions are supposed to send text directly to the other
    /// side.  This function is called to deliver that text.
    private void function(dstring) remoteFn;
    private void delegate(dstring) remoteDg;

    /// Top margin of the scrolling region
    private int scrollRegionTop;

    /// Bottom margin of the scrolling region
    private int scrollRegionBottom;

    /// Right margin
    private int rightMargin;

    /// Last character printed
    private dchar repCh;

    /**
     * VT100-style line wrapping: a character is placed in column 80 (or
     * 132), but the line does NOT wrap until another character is written to
     * column 1 of the next line, after which the cursor moves to column 2.
     */
    private bool wrapLineFlag;

    /// VT220 single shift flag
    private Singleshift singleshift = Singleshift.NONE;

    /// true = insert characters, false = overwrite
    private bool insertMode = false;

    /// VT52 mode as selected by DECANM.  True means VT52, false means ANSI. Default is ANSI.
    private bool vt52Mode = false;

    /// Visible cursor (DECTCEM)
    public bool visibleCursor = true;

    /// Screen title
    public dstring screenTitle = "";

    /// Array of flags that have come in, e.g. '?' (DEC private mode), '=', '>', ...
    private char [] csiFlags;

    /// Parameter characters being collected
    private int [] csiParams;

    /// Non-csi collect buffer
    private dchar [] collectBuffer;

    /// When true, use the G1 character set
    private bool shiftOut = false;

    /// Horizontal tab stops
    private int [] tabStops;

    /// S8C1T.  True means 8bit controls, false means 7bit controls.
    private bool s8c1t = false;

    /// Printer mode.  True means send all output to printer, which discards it.
    private bool printerControllerMode = false;

    /// LMN line mode.  If true, linefeed() puts the cursor on the first
    /// column of the next line.  If false, linefeed() puts the cursor one
    /// line down on the current line.  The default is false.
    private bool newLineMode = false;

    /// Whether arrow keys send ANSI, VT100, or VT52 sequences
    private ArrowKeyMode arrowKeyMode;

    /// Whether number pad keys send VT100 or VT52, application or
    /// numeric sequences.
    private KeypadMode keypadMode;

    /// When true, the terminal is in 132-column mode (DECCOLM)
    private bool columns132 = false;

    /// true = reverse video.  Set by DECSCNM.
    private bool reverseVideo = false;

    /// false = echo characters locally.
    private bool fullDuplex = true;

    /**
     * DECSC/DECRC save/restore a subset of the total state.  This class
     * encapsulates those specific flags/modes.
     */
    private class SaveableState {

	/// When true, cursor positions are relative to the scrolling region
	public bool originMode = false;

	/// The current editing X position
	public uint cursorX = 0;

	/// The current editing Y position
	public uint cursorY = 0;

	/// Which character set is currently selected in G0
	public CharacterSet g0Charset = CharacterSet.US;

	/// Which character set is currently selected in G1
	public CharacterSet g1Charset = CharacterSet.DRAWING;

	public CharacterSet g2Charset = CharacterSet.US;
	public CharacterSet g3Charset = CharacterSet.US;
	public CharacterSet grCharset = CharacterSet.DRAWING;

	/// The current drawing attributes
	public CellAttributes attr;

	/// When a lockshift command comes in
	public LockshiftMode glLockshift = LockshiftMode.NONE;
	public LockshiftMode grLockshift = LockshiftMode.NONE;

	/// Line wrap
	public bool lineWrap = true;

	/// Reset to defaults
	public void reset() {
	    originMode		= false;
	    cursorX		= 0;
	    cursorY		= 0;
	    g0Charset		= CharacterSet.US;
	    g1Charset		= CharacterSet.DRAWING;
	    g2Charset		= CharacterSet.US;
	    g3Charset		= CharacterSet.US;
	    grCharset		= CharacterSet.DRAWING;
	    attr		= new CellAttributes();
	    glLockshift		= LockshiftMode.NONE;
	    grLockshift		= LockshiftMode.NONE;
	    lineWrap		= true;
	}

	/**
	 * Copy attributes from another instance
	 *
	 * Params:
	 *    that = the other instance to match
	 */
	public void setTo(SaveableState that) {
	    this.originMode		= that.originMode;
	    this.cursorX		= that.cursorX;
	    this.cursorY		= that.cursorY;
	    this.g0Charset		= that.g0Charset;
	    this.g1Charset		= that.g1Charset;
	    this.g2Charset		= that.g2Charset;
	    this.g3Charset		= that.g3Charset;
	    this.grCharset		= that.grCharset;
	    this.attr			= new CellAttributes();
	    this.attr.setTo(that.attr);
	    this.glLockshift		= that.glLockshift;
	    this.grLockshift		= that.grLockshift;
	    this.lineWrap		= that.lineWrap;
	}

	/// Constructor
	public this() {
	    reset();
	}
    }

    /// The current terminal state
    private SaveableState currentState;

    /// The last saved terminal state
    private SaveableState savedState;

    /**
     * Clear the CSI parameters and flags
     */
    private void toGround() {
	csiParams.length = 0;
	csiFlags.length = 0;
	collectBuffer.length = 0;
	scanState = ScanState.GROUND;
    }

    /**
     * Reset the tab stops list
     */
    private void resetTabStops() {
	tabStops.length = 0;
	for (int i = 0; (i * 8) < width; i++) {
	    tabStops.length++;
	    tabStops[i] = i * 8;
	}
    }

    /**
     * Reset the emulation state
     */
    private void reset() {
	currentState		= new SaveableState();
	savedState		= new SaveableState();
	scanState		= ScanState.GROUND;
	width			= 80;
	height			= 24;
	scrollRegionTop		= 0;
	scrollRegionBottom	= height - 1;
	rightMargin		= 79;
	newLineMode		= false;
	arrowKeyMode		= ArrowKeyMode.ANSI;
	keypadMode		= KeypadMode.Numeric;
	wrapLineFlag		= false;

	// Flags
	shiftOut		= false;
	vt52Mode		= false;
	insertMode		= false;
	columns132		= false;
	newLineMode		= false;
	reverseVideo		= false;
	fullDuplex		= true;
	visibleCursor		= true;

	// VT220
	singleshift		= Singleshift.NONE;
	s8c1t			= false;
	printerControllerMode	= false;

	// Tab stops
	resetTabStops();

	// Clear CSI stuff
	toGround();
    }

    /**
     * Public constructor
     *
     * Params:
     *    type = one of the DeviceType constants to select VT100, VT102, VT220, or XTERM
     *    remoteFn = function to call to deliver text to the remote side
     */
    public this(DeviceType type, void function(dstring) remoteFn) {
	this.type = type;
	this.remoteFn = remoteFn;
	reset();
	for (auto i = 0; i < height; i++) {
	    display ~= new DisplayLine();
	}
    }

    /**
     * Public constructor
     *
     * Params:
     *    type = one of the DeviceType constants to select VT100, VT102, VT220, or XTERM
     *    remoteDg = delegate to call to deliver text to the remote side
     */
    public this(DeviceType type, void delegate(dstring) remoteDg) {
	this.type = type;
	this.remoteDg = remoteDg;
	reset();
	for (auto i = 0; i < height; i++) {
	    display ~= new DisplayLine();
	}
    }

    /**
     * Append a new line to the bottom of the display, adding lines off the
     * top to the scrollback buffer.
     */
    private void newDisplayLine() {
	// Scroll the top line off into the scrollback buffer
	scrollback ~= display[0];
	display = display[1 .. $];
	display ~= new DisplayLine();
	display[$ - 1].reverseColor = reverseVideo;
    }

    /**
     * Wraps the current line
     */
    private void wrapCurrentLine() {
	if (currentState.cursorY == height) {
	    newDisplayLine();
	}
	if (currentState.cursorY < height - 1) {
	    currentState.cursorY++;
	}
	currentState.cursorX = 0;
    }

    /**
     * Handle a carriage return
     */
    private void carriageReturn() {
	currentState.cursorX = 0;
	wrapLineFlag = false;
    }

    /**
     * Reverse the color of the visible display
     */
    private void invertDisplayColors() {
	foreach (line; display) {
	    line.reverseColor = !line.reverseColor;
	}
    }

    /**
     * Handle a linefeed
     */
    private void linefeed(bool newLineMode) {
	int i;

	if (currentState.cursorY < scrollRegionBottom) {
	    // Increment screen y
	    currentState.cursorY++;
	} else {

	    // Screen y does not increment

	    /*
	     * Two cases: either we're inside a scrolling region or not.  If
	     * the scrolling region bottom is the bottom of the screen, then
	     * push the top line into the buffer.  Else scroll the scrolling
	     * region up.
	     */
	    if ((scrollRegionBottom == height - 1) && (scrollRegionTop == 0)) {

		// We're at the bottom of the scroll region, AND the scroll
		// region is the entire screen.

		// New line
		newDisplayLine();

	    } else {
		// We're at the bottom of the scroll region, AND the scroll
		// region is NOT the entire screen.
		scrollingRegionScrollUp(scrollRegionTop, scrollRegionBottom, 1);
	    }
	}

	if (newLineMode == true) {
	    currentState.cursorX = 0;
	}
	wrapLineFlag = false;
    }

    /**
     * Prints one character to the display buffer.
     *
     * Params:
     *     ch = character to display
     */
    private void printCharacter(dchar ch) {
	size_t rightMargin = this.rightMargin;

	// Check if we have double-width, and if so chop at 40/66
	// instead of 80/132
	if (display[currentState.cursorY].doubleWidth == true) {
	    rightMargin = ((rightMargin + 1) / 2) - 1;
	}

	// Check the unusually-complicated line wrapping conditions...
	if (currentState.cursorX == rightMargin) {

	    if (currentState.lineWrap == true) {
		/*
		 * This case happens when: the cursor was already on the
		 * right margin (either through printing or by an explicit
		 * placement command), and a character was printed.
		 * 
		 * The line wraps only when a new character arrives AND the
		 * cursor is already on the right margin AND has placed a
		 * character in its cell.  Easier to see than to explain.
		 */
		if (wrapLineFlag == false) {
		    /*
		     * This block marks the case that we are in the margin
		     * and the first character has been received and printed.
		     */
		    wrapLineFlag = true;
		} else {
		    /*
		     * This block marks the case that we are in the margin
		     * and the second character has been received and
		     * printed.
		     */
		    wrapLineFlag = false;
		    wrapCurrentLine();
		}
	    }
	} else if (currentState.cursorX <= rightMargin) {
	    /*
	     * This is the normal case: a character came in and was printed
	     * to the left of the right margin column.
	     */

	    // Turn off VT100 special-case flag
	    wrapLineFlag = false;
	}

	// "Print" the character
	Cell newCell = new Cell(ch);
	CellAttributes newCellAttributes = cast(CellAttributes)newCell;
	newCellAttributes.setTo(currentState.attr);
	DisplayLine line = display[currentState.cursorY];
 	// Insert mode special case
	if (insertMode == true) {
	    line.chars =
		    line.chars[0 .. currentState.cursorX] ~
		    newCell ~
		    line.chars[currentState.cursorX .. $ - 1];
	} else {
	    // Replace an existing character
	    line.chars[currentState.cursorX] = newCell;
	}
	assert(line.chars.length == ECMA48_MAX_LINE_LENGTH);

	// Increment horizontal
	if (wrapLineFlag == false) {
	    currentState.cursorX++;
	    if (currentState.cursorX > rightMargin) {
		currentState.cursorX--;
	    }
	}
    }

    /**
     * Translate the keyboard press to a VT100 sequence.
     *
     * Params:
     *    keystroke = keypress received from the local user
     *
     * Returns:
     *    string to transmit to the remote side
     */
    public dstring keypress(TKeypress keystroke) {

	if ((fullDuplex == false) && (!keystroke.isKey)) {
	    /*
	     * If this is a control character, process it like it came from
	     * the remote side.
	     */
	    if (keystroke.ch < 0x20) {
		handleControlChar(keystroke.ch);
	    } else {
		// Local echo for everything else
		printCharacter(keystroke.ch);
	    }
	}

	if ((newLineMode == true) && (keystroke == kbEnter)) {
	    // NLM: send CRLF
	    return "\015\012";
	}

	// Handle control characters
	if ((keystroke.ctrl) && (!keystroke.isKey)) {
	    dstring str = "";
	    dchar ch = keystroke.ch;
	    ch -= 0x40;
	    str ~= ch;
	    return str;
	}

	// Handle alt characters
	if ((keystroke.alt) && (!keystroke.isKey)) {
	    dstring str = "\033";
	    dchar ch = keystroke.ch;
	    str ~= ch;
	    return str;
	}

	if (keystroke == kbBackspace) {
	    final switch (type) {
	    case DeviceType.VT100:
		return "\010";
	    case DeviceType.VT102:
		return "\010";
	    case DeviceType.VT220:
		return "\177";
	    case DeviceType.XTERM:
		return "\177";
	    }
	}

	if (keystroke == kbLeft) {
	    final switch (arrowKeyMode) {
	    case ArrowKeyMode.ANSI:
		return "\033[D";
	    case ArrowKeyMode.VT52:
		return "\033D";
	    case ArrowKeyMode.VT100:
		return "\033OD";
	    }
	}

	if (keystroke == kbRight) {
	    final switch (arrowKeyMode) {
	    case ArrowKeyMode.ANSI:
		return "\033[C";
	    case ArrowKeyMode.VT52:
		return "\033C";
	    case ArrowKeyMode.VT100:
		return "\033OC";
	    }
	}
	
	if (keystroke == kbUp) {
	    final switch (arrowKeyMode) {
	    case ArrowKeyMode.ANSI:
		return "\033[A";
	    case ArrowKeyMode.VT52:
		return "\033A";
	    case ArrowKeyMode.VT100:
		return "\033OA";
	    }
	}
	
	if (keystroke == kbDown) {
	    final switch (arrowKeyMode) {
	    case ArrowKeyMode.ANSI:
		return "\033[B";
	    case ArrowKeyMode.VT52:
		return "\033B";
	    case ArrowKeyMode.VT100:
		return "\033OB";
	    }
	}
	
	if (keystroke == kbHome) {
	    final switch (arrowKeyMode) {
	    case ArrowKeyMode.ANSI:
		return "\033[H";
	    case ArrowKeyMode.VT52:
		return "\033H";
	    case ArrowKeyMode.VT100:
		return "\033OH";
	    }
	}
	
	if (keystroke == kbEnd) {
	    final switch (arrowKeyMode) {
	    case ArrowKeyMode.ANSI:
		return "\033[F";
	    case ArrowKeyMode.VT52:
		return "\033F";
	    case ArrowKeyMode.VT100:
		return "\033OF";
	    }
	}
	
	if (keystroke == kbF1) {
	    // PF1
	    if (vt52Mode) {
		return "\033P";
	    }
	    return "\033OP";
	}
	
	if (keystroke == kbF2) {
	    // PF2
	    if (vt52Mode) {
		return "\033Q";
	    }
	    return "\033OQ";
	}
	
	if (keystroke == kbF3) {
	    // PF3
	    if (vt52Mode) {
		return "\033R";
	    }
	    return "\033OR";
	}
	
	if (keystroke == kbF4) {
	    // PF4
	    if (vt52Mode) {
		return "\033S";
	    }
	    return "\033OS";
	}
	
	if (keystroke == kbF5) {
	    return "\033Ot";
	}
	
	if (keystroke == kbF6) {
	    return "\033Ou";
	}
	
	if (keystroke == kbF7) {
	    return "\033Ov";
	}
	
	if (keystroke == kbF8) {
	    return "\033Ol";
	}
	
	if (keystroke == kbF9) {
	    return "\033Ow";
	}
	
	if (keystroke == kbF10) {
	    return "\033Ox";
	}
	
	if (keystroke == kbF11) {
	    return "\033[23~";
	}
	
	if (keystroke == kbF12) {
	    return "\033[24~";
	}
	
	if (keystroke == kbShiftF1) {
	    // Shifted PF1
	    if (vt52Mode) {
		return "\0332P";
	    }
	    return "\033O2P";
	}
	
	if (keystroke == kbShiftF1) {
	    // Shifted PF2
	    if (vt52Mode) {
		return "\0332Q";
	    }
	    return "\033O2Q";
	}

	if (keystroke == kbShiftF1) {
	    // Shifted PF3
	    if (vt52Mode) {
		return "\0332R";
	    }
	    return "\033O2R";
	}
	
	if (keystroke == kbShiftF1) {
	    // Shifted PF4
	    if (vt52Mode) {
		return "\0332S";
	    }
	    return "\033O2S";
	}
	
	if (keystroke == kbShiftF1) {
	    // Shifted F5
	    return "\033[15;2~";
	}
	
	if (keystroke == kbShiftF1) {
	    // Shifted F6
	    return "\033[17;2~";
	}

	if (keystroke == kbShiftF1) {
	    // Shifted F7
	    return "\033[18;2~";
	}
	
	if (keystroke == kbShiftF1) {
	    // Shifted F8
	    return "\033[19;2~";
	}
	
	if (keystroke == kbShiftF1) {
	    // Shifted F9
	    return "\033[20;2~";
	}
	
	if (keystroke == kbShiftF1) {
	    // Shifted F10
	    return "\033[21;2~";
	}
	
	if (keystroke == kbShiftF1) {
	    // Shifted F11
	    return "\033[23;2~";
	}
	
	if (keystroke == kbShiftF1) {
	    // Shifted F12
	    return "\033[24;2~";
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control PF1
	    if (vt52Mode) {
		return "\0335P";
	    }
	    return "\033O5P";
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control PF2
	    if (vt52Mode) {
		return "\0335Q";
	    }
	    return "\033O5Q";
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control PF3
	    if (vt52Mode) {
		return "\0335R";
	    }
	    return "\033O5R";
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control PF4
	    if (vt52Mode) {
		return "\0335S";
	    }
	    return "\033O5S";
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control F5
	    return "\033[15;5~";
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control F6
	    return "\033[17;5~";
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control F7
	    return "\033[18;5~";
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control F8
	    return "\033[19;5~";
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control F9
	    return "\033[20;5~";
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control F10
	    return "\033[21;5~";
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control F11
	    return "\033[23;5~";
	}
	
	if (keystroke == kbCtrlF1) {
	    // Control F12
	    return "\033[24;5~";
	}
	
	if (keystroke == kbPgUp) {
	    return "\033[5~";
	}
	
	if (keystroke == kbPgDn) {
	    return "\033[6~";
	}
	
	if (keystroke == kbIns) {
	    return "\033[2~";
	}
	
	if (keystroke == kbShiftIns) {
	    // This is what xterm sends for SHIFT-INS
	    return "\033[2;2~";
	    // This is what xterm sends for CTRL-INS
	    // return "\033[2;5~";
	}
	
	if (keystroke == kbShiftDel) {
	    // This is what xterm sends for SHIFT-DEL
	    return "\033[3;2~";
	    // This is what xterm sends for CTRL-DEL
	    // return "\033[3;5~";
	}
	
	if (keystroke == kbDel) {
	    // Delete sends real delete for VTxxx
	    return "\177";
	    // return "\033[3~";
	}
	
	if (keystroke == kbEnter) {
	    return "\015";
	}

	if (keystroke == kbTab) {
	    return "\011";
	}

	// Non-alt, non-ctrl characters
	if (!keystroke.isKey) {
	    dstring str = "";
	    str ~= keystroke.ch;
	    return str;
	}
	return "";
    }


    /**
     * Map a symbol in any one of the VT100/VT220 character sets to a
     * Unicode symbol
     *
     * Params:
     *    ch = 8-bit character from the remote side
     *    charsetGl = character set defined for GL
     *    charsetGr = character set defined for GR
     *
     * Return:
     *    character to display on the screen
     */
    private dchar mapCharacterCharset(dchar ch,
	CharacterSet charsetGl,
	CharacterSet charsetGr) {

	ubyte lookupChar = cast(ubyte)ch;
	CharacterSet lookupCharset = charsetGl;

	if (ch >= 0x80) {
	    assert((type == DeviceType.VT220) || (type == DeviceType.XTERM));
	    lookupCharset = charsetGr;
	    lookupChar &= 0x7F;
	}

	final switch (lookupCharset) {

	case CharacterSet.DRAWING:
	    return dec_special_graphics_chars[lookupChar];

	case CharacterSet.UK:
	    return dec_uk_chars[lookupChar];

	case CharacterSet.US:
	    return dec_us_chars[lookupChar];

	case CharacterSet.NRC_DUTCH:
	    return dec_nl_chars[lookupChar];

	case CharacterSet.NRC_FINNISH:
	    return dec_fi_chars[lookupChar];

	case CharacterSet.NRC_FRENCH:
	    return dec_fr_chars[lookupChar];

	case CharacterSet.NRC_FRENCH_CA:
	    return dec_fr_CA_chars[lookupChar];

	case CharacterSet.NRC_GERMAN:
	    return dec_de_chars[lookupChar];

	case CharacterSet.NRC_ITALIAN:
	    return dec_it_chars[lookupChar];

	case CharacterSet.NRC_NORWEGIAN:
	    return dec_no_chars[lookupChar];

	case CharacterSet.NRC_SPANISH:
	    return dec_es_chars[lookupChar];

	case CharacterSet.NRC_SWEDISH:
	    return dec_sv_chars[lookupChar];

	case CharacterSet.NRC_SWISS:
	    return dec_swiss_chars[lookupChar];

	case CharacterSet.DEC_SUPPLEMENTAL:
	    return dec_supplemental_chars[lookupChar];

	case CharacterSet.VT52_GRAPHICS:
	    return vt52_special_graphics_chars[lookupChar];

	case CharacterSet.ROM:
	    return dec_us_chars[lookupChar];

	case CharacterSet.ROM_SPECIAL:
	    return dec_us_chars[lookupChar];
	}
    }

    /**
     * Map an 8-bit byte into a printable character
     *
     * Params:
     *    ch = UTF-decoded character from the remote side
     *
     * Return:
     *    character to display on the screen
     */
    private dchar mapCharacter(dchar ch) {
	if (ch >= 0x100) {
	    // Unicode character, just return it
	    return ch;
	}

	CharacterSet charsetGl = currentState.g0Charset;
	CharacterSet charsetGr = currentState.grCharset;

	if (vt52Mode == true) {
	    if (shiftOut == true) {
		// Shifted out character, pull from VT52 graphics
		charsetGl = currentState.g1Charset;
		charsetGr = CharacterSet.US;
	    } else {
		// Normal
		charsetGl = currentState.g0Charset;
		charsetGr = CharacterSet.US;
	    }

	    // Pull the character
	    return mapCharacterCharset(ch, charsetGl, charsetGr);
	}

	// shiftOout
	if (shiftOut == true) {
	    // Shifted out character, pull from G1
	    charsetGl = currentState.g1Charset;
	    charsetGr = currentState.grCharset;

	    // Pull the character
	    return mapCharacterCharset(ch, charsetGl, charsetGr);
	}

	// SS2
	if (singleshift == Singleshift.SS2) {

	    singleshift = Singleshift.NONE;

	    // Shifted out character, pull from G2
	    charsetGl = currentState.g2Charset;
	    charsetGr = currentState.grCharset;
	}

	// SS3
	if (singleshift == Singleshift.SS3) {

	    singleshift = Singleshift.NONE;

	    // Shifted out character, pull from G3
	    charsetGl = currentState.g3Charset;
	    charsetGr = currentState.grCharset;
	}

	if ((type == DeviceType.VT220) || (type == DeviceType.XTERM)) {
	    // Check for locking shift

	    final switch (currentState.glLockshift) {

	    case LockshiftMode.G1_GR:
		assert(1 == 0);

	    case LockshiftMode.G2_GR:
		assert(1 == 0);

	    case LockshiftMode.G3_GR:
		assert(1 == 0);

	    case LockshiftMode.G2_GL:
		// LS2
		charsetGl = currentState.g2Charset;
		break;

	    case LockshiftMode.G3_GL:
		// LS3
		charsetGl = currentState.g3Charset;
		break;

	    case LockshiftMode.NONE:
		// Normal
		charsetGl = currentState.g0Charset;
		break;
	    }

	    final switch (currentState.grLockshift) {

	    case LockshiftMode.G2_GL:
		assert(1 == 0);

	    case LockshiftMode.G3_GL:
		assert(1 == 0);

	    case LockshiftMode.G1_GR:
		// LS1R
		charsetGr = currentState.g1Charset;
		break;

	    case LockshiftMode.G2_GR:
		// LS2R
		charsetGr = currentState.g2Charset;
		break;

	    case LockshiftMode.G3_GR:
		// LS3R
		charsetGr = currentState.g3Charset;
		break;

	    case LockshiftMode.NONE:
		// Normal
		charsetGr = CharacterSet.DEC_SUPPLEMENTAL;
		break;
	    }


	}

	// Pull the character
	return mapCharacterCharset(ch, charsetGl, charsetGr);
    }

    /**
     * Scroll the text within a scrolling region up n lines.
     *
     * Params:
     *    regionTop = top row of the scrolling region
     *    regionBottom = bottom row of the scrolling region
     *    n = number of lines to scroll
     */
    private void scrollingRegionScrollUp(int regionTop, int regionBottom, int n) {
	if (regionTop >= regionBottom) {
	    return;
	}

	// Sanity check: see if there will be any characters left
	// after the scroll
	if (regionBottom + 1 - regionTop <= n) {
	    // There won't be anything left in the region, so just
	    // call eraseScreen() and return.
	    eraseScreen(regionTop, 0, regionBottom, width - 1, false);
	    return;
	}

	auto remaining = regionBottom + 1 - regionTop - n;
	auto displayTop = display[0 .. regionTop];
	auto displayBottom = display[regionBottom + 1 .. $];
	auto displayMiddle = display[regionBottom + 1 - remaining .. regionBottom + 1];
	display = displayTop ~ displayMiddle;
	for (auto i = 0; i < n; i++) {
	    display ~= new DisplayLine();
	    display[$ - 1].reverseColor = reverseVideo;
	}
	display ~= displayBottom;

	assert(display.length == height);
    }

    /**
     * Scroll the text within a scrolling region down n lines.
     *
     * Params:
     *    regionTop = top row of the scrolling region
     *    regionBottom = bottom row of the scrolling region
     *    n = number of lines to scroll
     */
    private void scrollingRegionScrollDown(int regionTop, int regionBottom, int n) {
	if (regionTop >= regionBottom) {
	    return;
	}

	// Sanity check: see if there will be any characters left
	// after the scroll
	if (regionBottom + 1 - regionTop <= n) {
	    // There won't be anything left in the region, so just
	    // call eraseScreen() and return.
	    eraseScreen(regionTop, 0, regionBottom, width - 1, false);
	    return;
	}

	auto remaining = regionBottom + 1 - regionTop - n;
	auto displayTop = display[0 .. regionTop];
	auto displayBottom = display[regionBottom + 1 .. $];
	auto displayMiddle = display[regionTop .. regionTop + remaining];
	display = displayTop;
	for (auto i = 0; i < n; i++) {
	    display ~= new DisplayLine();
	    display[$ - 1].reverseColor = reverseVideo;
	}
	display ~= displayMiddle;
	display ~= displayBottom;

	assert(display.length == height);
    }

    /**
     * Process a control character
     *
     * Params:
     *    ch = UTF-decoded character from the remote side
     */
    private void handleControlChar(dchar ch) {
	assert((ch <= 0x1F) || ((ch >= 0x7F) && (ch <= 0x9F)));

	switch (ch) {

	case 0x00:
	    // NUL - discard
	    return;

	case 0x05:
	    // ENQ

	    // Transmit the answerback message.
	    // Not supported
	    break;

	case 0x07:
	    // BEL
	    // Not supported
	    break;

	case 0x08:
	    // BS
	    cursorLeft(1, false);
	    break;

	case 0x09:
	    // HT
	    advanceToNextTabStop();
	    break;

	case 0x0A:
	    // LF
	    linefeed(newLineMode);
	    break;

	case 0x0B:
	    // VT
	    linefeed(newLineMode);
	    break;

	case 0x0C:
	    // FF
	    linefeed(newLineMode);
	    break;

	case 0x0D:
	    // CR
	    carriageReturn();
	    break;

	case 0x0E:
	    // SO
	    shiftOut = true;
	    currentState.glLockshift = LockshiftMode.NONE;
	    break;

	case 0x0F:
	    // SI
	    shiftOut = false;
	    currentState.glLockshift = LockshiftMode.NONE;
	    break;

	case 0x84:
	    // IND
	    ind();
	    break;

	case 0x85:
	    // NEL
	    nel();
	    break;

	case 0x88:
	    // HTS
	    hts();
	    break;

	case 0x8D:
	    // RI
	    ri();
	    break;

	case 0x8E:
	    // SS2
	    singleshift = Singleshift.SS2;
	    break;

	case 0x8F:
	    // SS3
	    singleshift = Singleshift.SS3;
	    break;

	default:
	    break;
	}


    }

    /**
     * Advance the cursor to the next tab stop
     */
    private void advanceToNextTabStop() {
	if (tabStops.length == 0) {
	    // Go to the rightmost column
	    cursorRight(width - 1 - currentState.cursorX, false);
	    return;
	}
	foreach (stop; tabStops) {
	    if (stop > currentState.cursorX) {
		cursorRight(stop - currentState.cursorX, false);
		return;
	    }
	}
	/*
	 * We got here, meaning there isn't a tab stop beyond the current
	 * cursor position.  Place the cursor of the right-most edge of the
	 * screen.
	 */
	cursorRight(width - 1 - currentState.cursorX, false);
    }

    /**
     * Write a string directly to the remote side
     *
     * Params:
     *    str = string to send
     */
    private void writeRemote(dstring str) {
	if (remoteFn !is null) {
	    remoteFn(str);
	} else if (remoteDg !is null) {
	    remoteDg(str);
	}
    }

    /**
     * Save a character into the collect buffer
     *
     * Params:
     *    ch = character to save
     */
    private void collect(dchar ch) {
	collectBuffer ~= ch;
    }

    /**
     * Save a byte into the CSI parameters buffer
     *
     * Params:
     *    ch = byte to save
     */
    private void param(byte ch) {
	if (csiParams.length == 0) {
	    csiParams.length = 1;
	    csiParams[$ - 1] = 0;
	}
	if ((ch >= '0') && (ch <= '9')) {
	    csiParams[$ - 1] *= 10;
	    csiParams[$ - 1] += (ch - '0');
	}
	if (ch == ';') {
	    csiParams.length++;
	    csiParams[$ - 1] = 0;
	}
    }

    /**
     * Get a CSI parameter value, with a default
     *
     * Params:
     *    position = parameter index.  0 is the first parameter.
     *    defaultValue = value to use if csiParams[position] doesn't exist
     *
     * Return:
     *    parameter value
     */
    private int getCsiParam(uint position, int defaultValue) {
	if (csiParams.length < position + 1) {
	    return defaultValue;
	}
	return csiParams[position];
    }

    /**
     * Get a CSI parameter value, clamped to within min/max
     *
     * Params:
     *    position = parameter index.  0 is the first parameter.
     *    defaultValue = value to use if csiParams[position] doesn't exist
     *    minValue = minimum value inclusive
     *    maxValue = maximum value inclusive
     *
     * Return:
     *    parameter value
     */
    private int getCsiParam(uint position, int defaultValue,
	int minValue, int maxValue) {

	assert(minValue <= maxValue);
	int value = getCsiParam(position, defaultValue);
	if (value < minValue) {
	    value = minValue;
	}
	if (value > maxValue) {
	    value = maxValue;
	}
	return value;
    }

    /**
     * Set or unset a toggle.  value is 'true' for set ('h'), false
     * for reset ('l').
     */
    private void setToggle(bool value) {
	bool decPrivateModeFlag = false;
	foreach (ch; collectBuffer) {
	    if (ch == '?') {
		decPrivateModeFlag = true;
	    }
	}

	foreach (i; csiParams) {

	    switch (i) {

	    case 1:
		if (decPrivateModeFlag == true) {
		    // DECCKM
		    if (value == true) {
			// Use application arrow keys
			arrowKeyMode = ArrowKeyMode.VT100;
		    } else {
			// Use ANSI arrow keys
			arrowKeyMode = ArrowKeyMode.ANSI;
		    }
		}
		break;
	    case 2:
		if (decPrivateModeFlag == true) {
		    if (value == false) {

			// DECANM
			vt52Mode = true;
			arrowKeyMode = ArrowKeyMode.VT52;

			/*
			 * From the VT102 docs: "You use ANSI mode to select
			 * most terminal features; the terminal uses the same
			 * features when it switches to VT52 mode. You
			 * cannot, however, change most of these features in
			 * VT52 mode."
			 *
			 * In other words, do not reset any other attributes
			 * when switching between VT52 submode and ANSI.
			 *
			 * HOWEVER, the real vt100 does switch the character
			 * set according to Usenet.
			 */
			currentState.g0Charset = CharacterSet.US;
			currentState.g1Charset = CharacterSet.DRAWING;
			shiftOut = false;

			if ((type == DeviceType.VT220) || (type == DeviceType.XTERM)) {
			    // VT52 mode is explicitly 7-bit
			    s8c1t = false;
			    singleshift = Singleshift.NONE;
			}
		    }
		} else {
		    // KAM
		    if (value == true) {
			// Turn off keyboard
			// Not supported
		    } else {
			// Turn on keyboard
			// Not supported
		    }
		}
		break;
	    case 3:
		if (decPrivateModeFlag == true) {
		    // DECCOLM
		    if (value == true) {
			// 132 columns
			columns132 = true;
			rightMargin = 131;
		    } else {
			// 80 columns
			columns132 = false;
			rightMargin = 79;
		    }
		    // Entire screen is cleared, and scrolling region is reset
		    eraseScreen(0, 0, height - 1, width - 1, false);
		    scrollRegionTop = 0;
		    scrollRegionBottom = height - 1;
		    // Also home the cursor
		    cursorPosition(0, 0);
		}
		break;
	    case 4:
		if (decPrivateModeFlag == true) {
		    // DECSCLM
		    if (value == true) {
			// Smooth scroll
			// Not supported
		    } else {
			// Jump scroll
			// Not supported
		    }
		} else {
		    // IRM
		    if (value == true) {
			insertMode = true;
		    } else {
			insertMode = false;
		    }
		}
		break;
	    case 5:
		if (decPrivateModeFlag == true) {
		    // DECSCNM
		    if (value == true) {
			/*
			 * Set selects reverse screen, a white screen
			 * background with black characters.
			 */
			if (reverseVideo != true) {
			    /*
			     * If in normal video, switch it back
			     */
			    invertDisplayColors();
			}
			reverseVideo = true;
		    } else {
			/*
			 * Reset selects normal screen, a black screen
			 * background with white characters.
			 */
			if (reverseVideo == true) {
			    /*
			     * If in reverse video already, switch it back
			     */
			    invertDisplayColors();
			}
			reverseVideo = false;
		    }
		}
		break;
	    case 6:
		if (decPrivateModeFlag == true) {
		    // DECOM
		    if (value == true) {
			// Origin is relative to scroll region cursor.
			// Cursor can NEVER leave scrolling region.
			currentState.originMode = true;
			cursorPosition(0, 0);
		    } else {
			// Origin is absolute to entire screen.
			// Cursor can leave the scrolling region via
			// cup() and hvp().
			currentState.originMode = false;
			cursorPosition(0, 0);
		    }
		}
		break;
	    case 7:
		if (decPrivateModeFlag == true) {
		    // DECAWM
		    if (value == true) {
			// Turn linewrap on
			currentState.lineWrap = true;
		    } else {
			// Turn linewrap off
			currentState.lineWrap = false;
		    }
		}
		break;
	    case 8:
		if (decPrivateModeFlag == true) {
		    // DECARM
		    if (value == true) {
			// Keyboard auto-repeat on
			// Not supported
		    } else {
			// Keyboard auto-repeat off
			// Not supported
		    }
		}
		break;
	    case 12:
		if (decPrivateModeFlag == false) {
		    // SRM
		    if (value == true) {
			// Local echo off
			fullDuplex = true;
		    } else {
			// Local echo on
			fullDuplex = false;
		    }
		}
		break;
	    case 18:
		if (decPrivateModeFlag == true) {
		    // DECPFF
		    // Not supported
		}
		break;
	    case 19:
		if (decPrivateModeFlag == true) {
		    // DECPEX
		    // Not supported
		}
		break;
	    case 20:
		if (decPrivateModeFlag == false) {
		    // LNM
		    if (value == true) {
			/*
			 * Set causes a received linefeed, form feed, or
			 * vertical tab to move cursor to first column of
			 * next line. RETURN transmits both a carriage return
			 * and linefeed. This selection is also called new
			 * line option.
			 */
			newLineMode = true;
		    } else {
			/*
			 * Reset causes a received linefeed, form feed, or
			 * vertical tab to move cursor to next line in
			 * current column. RETURN transmits a carriage
			 * return.
			 */
			newLineMode = false;
		    }
		}
		break;

	    case 25:
		if ((type == DeviceType.VT220) || (type == DeviceType.XTERM)) {
		    if (decPrivateModeFlag == true) {
			// DECTCEM
			if (value == true) {
			    // Visible cursor
			    visibleCursor = true;
			} else {
			    // Invisible cursor
			    visibleCursor = false;
			}
		    }
		}
		break;

	    case 42:
		if ((type == DeviceType.VT220) || (type == DeviceType.XTERM)) {
		    if (decPrivateModeFlag == true) {
			// DECNRCM
			if (value == true) {
			    // Select national mode NRC
			    // Not supported
			} else {
			    // Select multi-national mode
			    // Not supported
			}
		    }
		}

		break;

	    default:
		break;

	    }
	}
    }

    /**
     * DECSC - Save cursor
     */
    private void decsc() {
	savedState.setTo(currentState);
    }

    /**
     * DECRC - Restore cursor
     */
    private void decrc() {
	currentState.setTo(savedState);
    }

    /**
     * IND - Index
     */
    private void ind() {
	// Move the cursor and scroll if necessary.  If at the bottom
	// line already, a scroll up is supposed to be performed.
	if (currentState.cursorY == scrollRegionBottom) {
	    scrollingRegionScrollUp(scrollRegionTop, scrollRegionBottom, 1);
	}
	cursorDown(1, true);
    }

    /**
     * RI - Reverse index
     */
    private void ri() {
	// Move the cursor and scroll if necessary.  If at the top
	// line already, a scroll down is supposed to be performed.
	if (currentState.cursorY == scrollRegionTop) {
	    scrollingRegionScrollDown(scrollRegionTop, scrollRegionBottom, 1);
	}
	cursorUp(1, true);
    }

    /**
     * NEL - Next line
     */
    private void nel() {
	// Move the cursor and scroll if necessary.  If at the bottom
	// line already, a scroll up is supposed to be performed.
	if (currentState.cursorY == scrollRegionBottom) {
	    scrollingRegionScrollUp(scrollRegionTop, scrollRegionBottom, 1);
	}
	cursorDown(1, true);

	// Reset to the beginning of the next line
	currentState.cursorX = 0;
    }

    /**
     * DECKPAM - Keypad application mode
     */
    private void deckpam() {
	keypadMode = KeypadMode.Application;
    }

    /**
     * DECKPNM - Keypad numeric mode
     */
    private void deckpnm() {
	keypadMode = KeypadMode.Numeric;
    }

    /**
     * Move up n spaces
     *
     * Param:
     *    n = number of spaces to move
     *    honorScrollRegion = if true, then do nothing if the cursor is outside the scrolling region
     */
    private void cursorUp(int n, bool honorScrollRegion) {
	int top;

	/*
	 * Special case: if a user moves the cursor from the right margin,
	 * we have to reset the VT100 right margin flag.
	 */
	if (n > 0) {
	    wrapLineFlag = false;
	}

	for (auto i = 0; i < n; i++) {
	    if (honorScrollRegion == true) {
		// Honor the scrolling region
		if ((currentState.cursorY < scrollRegionTop) ||
		    (currentState.cursorY > scrollRegionBottom)
		) {
		    // Outside region, do nothing
		    return;
		}
		// Inside region, go up
		top = scrollRegionTop;
	    } else {
		// Non-scrolling case
		top = 0;
	    }

	    if (currentState.cursorY > top) {
		currentState.cursorY--;
	    }
	}
    }

    /**
     * Move down n spaces
     *
     * Param:
     *    n = number of spaces to move
     *    honorScrollRegion = if true, then do nothing if the cursor is outside the scrolling region
     */
    private void cursorDown(int n, bool honorScrollRegion) {
	int bottom;

	/*
	 * Special case: if a user moves the cursor from the right margin,
	 * we have to reset the VT100 right margin flag.
	 */
	if (n > 0) {
	    wrapLineFlag = false;
	}

	for (auto i = 0; i < n; i++) {

	    if (honorScrollRegion == true) {
		// Honor the scrolling region
		if (currentState.cursorY > scrollRegionBottom) {
		    // Outside region, do nothing
		    return;
		}
		// Inside region, go down
		bottom = scrollRegionBottom;
	    } else {
		// Non-scrolling case
		bottom = height - 1;
	    }

	    if (currentState.cursorY < bottom) {
		currentState.cursorY++;
	    }
	}
    }

    /**
     * Move left n spaces
     *
     * Param:
     *    n = number of spaces to move
     *    honorScrollRegion = if true, then do nothing if the cursor is outside the scrolling region
     */
    private void cursorLeft(int n, bool honorScrollRegion) {
	/*
	 * Special case: if a user moves the cursor from the right margin,
	 * we have to reset the VT100 right margin flag.
	 */
	if (n > 0) {
	    wrapLineFlag = false;
	}

	for (auto i = 0; i < n; i++) {
	    if (honorScrollRegion == true) {
		// Honor the scrolling region
		if ((currentState.cursorY < scrollRegionTop) ||
		    (currentState.cursorY > scrollRegionBottom)
		) {
		    // Outside region, do nothing
		    return;
		}
	    }

	    if (currentState.cursorX > 0) {
		currentState.cursorX--;
	    }
	}
    }

    /**
     * Move right n spaces
     *
     * Param:
     *    n = number of spaces to move
     *    honorScrollRegion = if true, then do nothing if the cursor is outside the scrolling region
     */
    private void cursorRight(int n, bool honorScrollRegion) {
	int rightMargin;

	/*
	 * Special case: if a user moves the cursor from the right margin,
	 * we have to reset the VT100 right margin flag.
	 */
	if (n > 0) {
	    wrapLineFlag = false;
	}

	if (this.rightMargin > 0) {
	    rightMargin = this.rightMargin;
	} else {
	    rightMargin = width - 1;
	}
	if (display[currentState.cursorY].doubleWidth == true) {
	    rightMargin = ((rightMargin + 1) / 2) - 1;
	}

	for (auto i = 0; i < n; i++) {
	    if (honorScrollRegion == true) {
		// Honor the scrolling region
		if ((currentState.cursorY < scrollRegionTop) ||
		    (currentState.cursorY > scrollRegionBottom)
		) {
		    // Outside region, do nothing
		    return;
		}
	    }

	    if (currentState.cursorX < rightMargin) {
		currentState.cursorX++;
	    }
	}
    }

    /**
     * Move cursor to (col, row) where (0, 0) is the top-left corner
     *
     * Param:
     *    row = row to move to
     *    col = column to move to
     */
    private void cursorPosition(int row, int col) {
	int rightMargin;

	assert(col >= 0);
	assert(row >= 0);

	if (this.rightMargin > 0) {
	    rightMargin = this.rightMargin;
	} else {
	    rightMargin = width - 1;
	}
	if (display[currentState.cursorY].doubleWidth == true) {
	    rightMargin = ((rightMargin + 1) / 2) - 1;
	}

	// Set column number
	currentState.cursorX = col;
	if (currentState.cursorX > width - 1) {
	    currentState.cursorX = width - 1;
	}

	// Sanity check, bring column back to margin.
	if (this.rightMargin > 0) {
	    if (currentState.cursorX > rightMargin) {
		currentState.cursorX = rightMargin;
	    }
	}

	// Set row number
	if (currentState.originMode == true) {
	    row += scrollRegionTop;
	}
	if (currentState.cursorY < row) {
	    cursorDown(row - currentState.cursorY, false);
	} else if (currentState.cursorY > row) {
	    cursorUp(currentState.cursorY - row, false);
	}

	wrapLineFlag = false;
    }

    /*
     * HTS - Horizontal tabulation set
     */
    private void hts() {
	foreach (stop; tabStops) {
	    if (stop == currentState.cursorX) {
		// Already have a tab stop here
		return;
	    }
	}

	// Append a tab stop to the end of the array and resort them
	tabStops ~= currentState.cursorX;
	tabStops.sort;
    }

    /**
     * DECSWL - Single-width line
     */
    private void decswl() {
	display[currentState.cursorY].doubleWidth = false;
	display[currentState.cursorY].doubleHeight = 0;
    }

    /**
     * DECDWL - Double-width line
     */
    private void decdwl() {
	display[currentState.cursorY].doubleWidth = true;
	display[currentState.cursorY].doubleHeight = 0;
    }

    /**
     * DECHDL - Double-height + double-width line
     */
    private void dechdl(bool topHalf) {
	display[currentState.cursorY].doubleWidth = true;
	if (topHalf == true) {
	    display[currentState.cursorY].doubleHeight = 1;
	} else {
	    display[currentState.cursorY].doubleHeight = 2;
	}
    }

    /**
     * DECALN - Screen alignment display
     */
    private void decaln() {
	foreach (line; display) {
	    foreach (ch; line.chars) {
		ch.reset();
		ch.ch = 'E';
	    }
	}
    }

    /**
     * DECSCL - Compatibility level
     */
    private void decscl() {
	auto i = getCsiParam(0, 0);
	auto j = getCsiParam(1, 0);

	if (i == 61) {
	    // Reset fonts
	    currentState.g0Charset = CharacterSet.US;
	    currentState.g1Charset = CharacterSet.DRAWING;
	    s8c1t = false;
	} else if (i == 62) {

	    if ((j == 0) || (j == 2)) {
		s8c1t = true;
	    } else if (j == 1) {
		s8c1t = false;
	    }
	}
    }

    /**
     * CUD - Cursor down
     */
    private void cud() {
	cursorDown(getCsiParam(0, 1, 1, height), true);
    }

    /**
     * CUF - Cursor forward
     */
    private void cuf() {
	cursorRight(getCsiParam(0, 1, 1, width), true);
    }

    /**
     * CUB - Cursor backward
     */
    private void cub() {
	cursorLeft(getCsiParam(0, 1, 1, currentState.cursorX + 1), true);
    }

    /**
     * CUU - Cursor up
     */
    private void cuu() {
	cursorUp(getCsiParam(0, 1, 1, currentState.cursorY + 1), true);
    }

    /**
     * CUP - Cursor position
     */
    private void cup() {
	cursorPosition(getCsiParam(0, 1, 1, height) - 1,
	    getCsiParam(1, 1, 1, width) - 1);
    }

    /**
     * CNL - Cursor down and to column 1
     */
    private void cnl() {
	cursorDown(getCsiParam(0, 1, 1, height), true);
	// To column 0
	cursorLeft(currentState.cursorX, true);
    }

    /**
     * CPL - Cursor up and to column 1
     */
    private void cpl() {
	cursorUp(getCsiParam(0, 1, 1, currentState.cursorY + 1), true);
	// To column 0
	cursorLeft(currentState.cursorX, true);
    }

    /**
     * CHA - Cursor to column # in current row
     */
    private void cha() {
	cursorPosition(currentState.cursorY,
	    getCsiParam(0, 1, 1, width) - 1);
    }

    /**
     * VPA - Cursor to row #, same column
     */
    private void vpa() {
	cursorPosition(getCsiParam(0, 1, 1, height) - 1,
	    currentState.cursorX);
    }

    /**
     * ED - Erase in display
     */
    private void ed() {
	bool honorProtected = false;
	bool decPrivateModeFlag = false;

	foreach (ch; collectBuffer) {
	    if (ch == '?') {
		decPrivateModeFlag = true;
	    }
	}

	if (((type == DeviceType.VT220) || (type == DeviceType.XTERM)) &&
	    (decPrivateModeFlag == true)) {
	    honorProtected = true;
	}

	auto i = getCsiParam(0, 0);

	if (i == 0) {
	    // Erase from here to end of screen
	    if (currentState.cursorY < height - 1) {
		eraseScreen(currentState.cursorY + 1, 0, height - 1, width - 1,
		    honorProtected);
	    }
	    eraseLine(currentState.cursorX, width - 1, honorProtected);
	} else if (i == 1) {
	    // Erase from beginning of screen to here
	    eraseScreen(0, 0, currentState.cursorY - 1, width - 1,
		honorProtected);
	    eraseLine(0, currentState.cursorX, honorProtected);
	} else if (i == 2) {
	    // Erase entire screen
	    eraseScreen(0, 0, height - 1, width - 1, honorProtected);
	}
    }

    /**
     * EL - Erase in line
     */
    private void el() {
	bool honorProtected = false;
	bool decPrivateModeFlag = false;

	foreach (ch; collectBuffer) {
	    if (ch == '?') {
		decPrivateModeFlag = true;
	    }
	}

	if (((type == DeviceType.VT220) || (type == DeviceType.XTERM)) &&
	    (decPrivateModeFlag == true)) {
	    honorProtected = true;
	}

	auto i = getCsiParam(0, 0);

	if (i == 0) {
	    // Erase from here to end of line
	    eraseLine(currentState.cursorX, width - 1, honorProtected);
	} else if (i == 1) {
	    // Erase from beginning of line to here
	    eraseLine(0, currentState.cursorX, honorProtected);
	} else if (i == 2) {
	    // Erase entire line
	    eraseLine(0, width - 1, honorProtected);
	}
    }

    /**
     * ECH - Erase # of characters in current row
     */
    private void ech() {
	auto i = getCsiParam(0, 1, 1, width);

	// Erase from here to i characters
	eraseLine(currentState.cursorX, currentState.cursorX + i - 1, false);
    }

    /**
     * IL - Insert line
     */
    private void il() {
	auto i = getCsiParam(0, 1);

	if ((currentState.cursorY >= scrollRegionTop) &&
	    (currentState.cursorY <= scrollRegionBottom)) {

	    // I can get the same effect with a scroll-down
	    scrollingRegionScrollDown(currentState.cursorY, scrollRegionBottom, i);
	}
    }

    /**
     * DCH - Delete char
     */
    private void dch() {
	auto n = getCsiParam(0, 1);

	DisplayLine line = display[currentState.cursorY];
	line.chars = line.chars[0 .. currentState.cursorX] ~
	line.chars[currentState.cursorX + n .. $];
	Cell [] newCells;
	for (auto i = 0; i < n; i++) {
	    newCells ~= new Cell();
	}
	line.chars ~= newCells;
	assert(line.chars.length == ECMA48_MAX_LINE_LENGTH);
    }

    /**
     * ICH - Insert blank char at cursor
     */
    private void ich() {
	auto n = getCsiParam(0, 1);
	DisplayLine line = display[currentState.cursorY];
	Cell [] newCells;
	for (auto i = 0; i < n; i++) {
	    newCells ~= new Cell();
	}
	line.chars = line.chars[0 .. currentState.cursorX] ~
	newCells ~
	line.chars[currentState.cursorX .. $];
	line.chars.length -= n;
	assert(line.chars.length == ECMA48_MAX_LINE_LENGTH);
    }

    /**
     * DL - Delete line
     */
    private void dl() {
	auto i = getCsiParam(0, 1);

	if ((currentState.cursorY >= scrollRegionTop) &&
	    (currentState.cursorY <= scrollRegionBottom)) {

	    // I can get the same effect with a scroll-down
	    scrollingRegionScrollUp(currentState.cursorY, scrollRegionBottom, i);
	}
    }

    /**
     * HVP - Horizontal and vertical position
     */
    private void hvp() {
	cup();
    }

    /**
     * REP - Repeat character
     */
    private void rep() {
	auto n = getCsiParam(0, 1);
	for (auto i = 0; i < n; i++) {
	    printCharacter(repCh);
	}
    }

    /**
     * SU - Scroll up
     */
    private void su() {
	scrollingRegionScrollUp(scrollRegionTop, scrollRegionBottom,
	    getCsiParam(0, 1, 1, height));
    }

    /**
     * SD - Scroll down
     */
    private void sd() {
	scrollingRegionScrollDown(scrollRegionTop, scrollRegionBottom,
	    getCsiParam(0, 1, 1, height));
    }

    /**
     * CBT - Go back X tab stops
     */
    private void cbt() {
	auto tabsToMove = getCsiParam(0, 1);
	int tabI;

	for (auto i = 0; i < tabsToMove; i++) {
	    auto j = currentState.cursorX;
	    for (tabI = 0; tabI < tabStops.length; tabI++) {
		if (tabStops[tabI] >= currentState.cursorX) {
		    break;
		}
	    }
	    tabI--;
	    if (tabI <= 0) {
		j = 0;
	    } else {
		j = tabStops[tabI];
	    }
	    cursorPosition(currentState.cursorY, j);
	}
    }

    /**
     * CHT - Advance X tab stops
     */
    private void cht() {
	auto n = getCsiParam(0, 1);
	for (auto i = 0; i < n; i++) {
	    advanceToNextTabStop();
	}
    }

    /*
     * SGR - Select graphics rendition
     */
    private void sgr() {

	if (csiParams.length == 0) {
	    currentState.attr.reset();
	    return;
	}

	foreach (i; csiParams) {

	    switch (i) {

	    case 0:
		// Normal
		currentState.attr.reset();
		break;

	    case 1:
		// Bold
		currentState.attr.bold = true;
		break;

	    case 4:
		// Underline
		currentState.attr.underline = true;
		break;

	    case 5:
		// Blink
		currentState.attr.blink = true;
		break;

	    case 7:
		// Reverse
		currentState.attr.reverse = true;
		break;

	    default:
		break;
	    }

	    if (type == DeviceType.XTERM) {

		switch (i) {

		case 8:
		    // Invisible
		    // TODO
		    break;

		default:
		    break;
		}
	    }

	    if ((type == DeviceType.VT220) ||
		(type == DeviceType.XTERM)) {

		switch (i) {

		case 22:
		    // Normal intensity
		    currentState.attr.bold = false;
		    break;

		case 24:
		    // No underline
		    currentState.attr.underline = false;
		    break;

		case 25:
		    // No blink
		    currentState.attr.blink = false;
		    break;

		case 27:
		    // Un-reverse
		    currentState.attr.reverse = false;
		    break;

		default:
		    break;
		}
	    }

	    // A true VT100/102/220 does not support color, however
	    // everyone is used to their terminal emulator supporting
	    // color so we will unconditionally support color for all
	    // DeviceType's.

	    switch(i) {

	    case 30:
		// Set black foreground
		currentState.attr.foreColor = COLOR_BLACK;
		break;
	    case 31:
		// Set red foreground
		currentState.attr.foreColor = COLOR_RED;
		break;
	    case 32:
		// Set green foreground
		currentState.attr.foreColor = COLOR_GREEN;
		break;
	    case 33:
		// Set yellow foreground
		currentState.attr.foreColor = COLOR_YELLOW;
		break;
	    case 34:
		// Set blue foreground
		currentState.attr.foreColor = COLOR_BLUE;
		break;
	    case 35:
		// Set magenta foreground
		currentState.attr.foreColor = COLOR_MAGENTA;
		break;
	    case 36:
		// Set cyan foreground
		currentState.attr.foreColor = COLOR_CYAN;
		break;
	    case 37:
		// Set white foreground
		currentState.attr.foreColor = COLOR_WHITE;
		break;
	    case 38:
		// Underscore on, default foreground color
		currentState.attr.underline = true;
		currentState.attr.foreColor = COLOR_WHITE;
		break;
	    case 39:
		// Underscore off, default foreground color
		currentState.attr.underline = false;
		currentState.attr.foreColor = COLOR_WHITE;
		break;
	    case 40:
		// Set black background
		currentState.attr.backColor = COLOR_BLACK;
		break;
	    case 41:
		// Set red background
		currentState.attr.backColor = COLOR_RED;
		break;
	    case 42:
		// Set green background
		currentState.attr.backColor = COLOR_GREEN;
		break;
	    case 43:
		// Set yellow background
		currentState.attr.backColor = COLOR_YELLOW;
		break;
	    case 44:
		// Set blue background
		currentState.attr.backColor = COLOR_BLUE;
		break;
	    case 45:
		// Set magenta background
		currentState.attr.backColor = COLOR_MAGENTA;
		break;
	    case 46:
		// Set cyan background
		currentState.attr.backColor = COLOR_CYAN;
		break;
	    case 47:
		// Set white background
		currentState.attr.backColor = COLOR_WHITE;
		break;
	    case 49:
		// Default background
		currentState.attr.backColor = COLOR_BLACK;
		break;

	    default:
		break;
	    }
	}
    }

    /**
     * DA - Device attributes
     */
    private void da() {
	int extendedFlag = 0;
	int i = 0;

	if (collectBuffer.length > 0) {
	    if (collectBuffer[0] == '>') {
		extendedFlag = 1;
		if (collectBuffer.length >= 2) {
		    i = to!int(collectBuffer[1 .. $]);
		}
	    } else if (collectBuffer[0] == '=') {
		extendedFlag = 2;
		if (collectBuffer.length >= 2) {
		    i = to!int(collectBuffer[1 .. $]);
		}
	    } else {
		// Unknown code, bail out
		return;
	    }
	}

	if ((i != 0) && (i != 1)) {
	    return;
	}

	if ((extendedFlag == 0) && (i == 0)) {
	    // Send string directly to remote side
	    writeRemote(deviceTypeResponse());
	    return;
	}

	if ((type == DeviceType.VT220) || (type == DeviceType.XTERM)) {

	    if ((extendedFlag == 1) && (i == 0)) {
		/*
		 * Request "What type of terminal are you, what is
		 * your firmware version, and what hardware options do
		 * you have installed?"
		 *
		 * Respond: "I am a VT220 (identification code of 1),
		 * my firmware version is _____ (Pv), and I have _____
		 * Po options installed."
		 *
		 * (Same as xterm)
		 *
		 */

		if (s8c1t == true) {
		    writeRemote("\u009b>1;10;0c");
		} else {
		    writeRemote("\033[>1;10;0c");
		}
	    }
	}

	// VT420 and up
	if ((extendedFlag == 2) && (i == 0)) {

	    /*
	     * Request "What is your unit ID?"
	     *
	     * Respond: "I was manufactured at site 00 and have a
	     * unique ID number of 123."
	     *
	     */
	    writeRemote("\033P!|00010203\033\\");
	}
    }

    /**
     * DECSTBM - Set top and bottom margins
     */
    private void decstbm() {
	int top = getCsiParam(0, 1, 1, height) - 1;
	int bottom = getCsiParam(1, height, 1, height) - 1;

	if (top > bottom) {
	    top = bottom;
	}
	scrollRegionTop = top;
	scrollRegionBottom = bottom;

	// Home cursor
	cursorPosition(0, 0);
    }

    /**
     * DECREQTPARM - Request terminal parameters
     */
    private void decreqtparm() {
	auto i = getCsiParam(0, 0);

	if ((i != 0) && (i != 1)) {
		return;
	}

	/*
	 * Request terminal parameters.
	 * 
	 * Respond with:
	 *
	 *     Parity NONE, 8 bits, xmitspeed 38400, recvspeed 38400.
	 *     (CLoCk MULtiplier = 1, STP option flags = 0)
	 *
	 * (Same as xterm)
	 */
	auto writer = appender!dstring;

	if (((type == DeviceType.VT220) || (type == DeviceType.XTERM)) &&
	    (s8c1t == true)) {
	    formattedWrite(writer, "\u009b%u;1;1;128;128;1;0x", i + 2);
	} else {
	    formattedWrite(writer, "\033[%u;1;1;128;128;1;0x", i + 2);
	}
	writeRemote(writer.data);
    }

    /**
     * DECSCA - Select Character Attributes
     */
    private void decsca() {
	auto i = getCsiParam(0, 0);

	if ((i == 0) || (i == 2)) {
	    // Protect mode OFF
	    currentState.attr.protect = false;
	}
	if (i == 1) {
	    // Protect mode ON
	    currentState.attr.protect = true;
	}
    }

    /**
     * DECSTR - Soft Terminal Reset
     */
    private void decstr() {
	// Do exactly like RIS - Reset to initial state
	reset();
	// Do I clear screen too? I think so...
	eraseScreen(0, 0, height - 1, width - 1, false);
	cursorPosition(0, 0);
    }

    /**
     * DSR - Device status report
     */
    private void dsr() {
	bool decPrivateModeFlag = false;

	foreach (ch; collectBuffer) {
	    if (ch == '?') {
		decPrivateModeFlag = true;
	    }
	}

	auto i = getCsiParam(0, 0);

	switch (i) {

	case 5:
	    // Request status report. Respond with "OK, no
	    // malfunction."

	    // Send string directly to remote side
	    if (((type == DeviceType.VT220) || (type == DeviceType.XTERM)) &&
		(s8c1t == true)) {
		writeRemote("\u009b0n");
	    } else {
		writeRemote("\033[0n");
	    }
	    break;

	case 6:
	    // Request cursor position.  Respond with current
	    // position.
	    auto writer = appender!dstring;
	    if (((type == DeviceType.VT220) || (type == DeviceType.XTERM)) &&
		(s8c1t == true)) {
		formattedWrite(writer, "\u009b%u;%uR",
		    currentState.cursorY + 1, currentState.cursorX + 1);
	    } else {
		formattedWrite(writer, "\033[%u;%uR",
		    currentState.cursorY + 1, currentState.cursorX + 1);
	    }

	    // Send string directly to remote side
	    writeRemote(writer.data);
	    break;

	case 15:
	    if (decPrivateModeFlag == true) {

		// Request printer status report.  Respond with
		// "Printer not connected."

		if (((type == DeviceType.VT220) || (type == DeviceType.XTERM)) &&
		    (s8c1t == true)) {
		    writeRemote("\u009b?13n");
		} else {
		    writeRemote("\033[?13n");
		}
	    }
	    break;

	case 25:
	    if (((type == DeviceType.VT220) || (type == DeviceType.XTERM)) &&
		(decPrivateModeFlag == true)) {

		// Request user-defined keys are locked or unlocked.
		// Respond with "User-defined keys are locked."

		if (s8c1t == true) {
		    writeRemote("\u009b?21n");
		} else {
		    writeRemote("\033[?21n");
		}
	    }
	    break;

	case 26:
	    if (((type == DeviceType.VT220) || (type == DeviceType.XTERM)) &&
		(decPrivateModeFlag == true)) {

		// Request keyboard language.  Respond with "Keyboard
		// language is North American."

		if (s8c1t == true) {
		    writeRemote("\u009b?27;1n");
		} else {
		    writeRemote("\033[?27;1n");
		}

	    }
	    break;

	default:
	    // Some other option, ignore
	    break;
	}
    }

    /**
     * TBC - Tabulation clear
     */
    private void tbc() {
	auto i = getCsiParam(0, 0);
	if (i == 0) {
	    int [] newStops;
	    foreach (stop; tabStops) {
		if (stop == currentState.cursorX) {
		    continue;
		}
		newStops ~= stop;
	    }
	    tabStops = newStops;
	}
	if (i == 3) {
	    tabStops.length = 0;
	}
    }

    /**
     * Erase the characters in the current line from the start column to the
     * end column, inclusive.
     *
     * Params:
     *    start = starting column to erase (between 0 and width - 1)
     *    end = ending column to erase (between 0 and width - 1)
     *    honorProtected = if true, do not erase characters with the protected attribute set
     */
    private void eraseLine(int start, int end, bool honorProtected) {
	if (start > end) {
	    return;
	}
	if (end > width - 1) {
	    end = width - 1;
	}
	if (start < 0) {
	    start = 0;
	}

	for (auto i = start; i <= end; i++) {
	    DisplayLine line = display[currentState.cursorY];
	    if ((!honorProtected) ||
		((honorProtected) && (!line.chars[i].protect))) {

		final switch (type) {
		case DeviceType.VT100:
		case DeviceType.VT102:
		case DeviceType.VT220:
		    /*
		     * From the VT102 manual:
		     *
		     * Erasing a character also erases any character
		     * attribute of the character.
		     */
		    line.chars[i].reset();
		    break;
		case DeviceType.XTERM:
		    /*
		     * Erase with the current color a.k.a. back-color
		     * erase (bce).
		     */
		    line.chars[i].ch = ' ';
		    line.chars[i].setTo(currentState.attr);
		    break;
		}
	    }
	}
    }

    /**
     * Erase a rectangular section of the screen, inclusive.
     * end column, inclusive.
     *
     * Params:
     *    startRow = starting row to erase (between 0 and height - 1)
     *    startCol = starting column to erase (between 0 and width - 1)
     *    endRow = ending row to erase (between 0 and height - 1)
     *    endCol = ending column to erase (between 0 and width - 1)
     *    honorProtected = if true, do not erase characters with the protected attribute set
     */
    private void eraseScreen(int startRow, int startCol, int endRow, int endCol,
	bool honorProtected) {
	int oldCursorY;

	if ((startRow < 0) ||
	    (startCol < 0) ||
	    (endRow < 0) ||
	    (endCol < 0) ||
	    (endRow < startRow) ||
	    (endCol < startCol)
	) {
	    return;
	}

	oldCursorY = currentState.cursorY;
	for (auto i = startRow; i <= endRow; i++) {
	    currentState.cursorY = i;
	    eraseLine(startCol, endCol, honorProtected);

	    // Erase display clears the double attributes
	    display[i].doubleWidth = false;
	    display[i].doubleHeight = 0;
	}
	currentState.cursorY = oldCursorY;
    }

    /**
     * VT220 printer functions.  All of these are parsed, but won't do
     * anything.
     */
    private void printerFunctions() {
	bool decPrivateModeFlag = false;
	foreach (ch; collectBuffer) {
	    if (ch == '?') {
		decPrivateModeFlag = true;
	    }
	}

	auto i = getCsiParam(0, 0);

	switch (i) {

	case 0:
	    if (decPrivateModeFlag == false) {
		// Print screen
	    }
	    break;

	case 1:
	    if (decPrivateModeFlag == true) {
		// Print cursor line
	    }
	    break;

	case 4:
	    if (decPrivateModeFlag == true) {
		// Auto print mode OFF
	    } else {
		// Printer controller OFF

		// Characters re-appear on the screen
		printerControllerMode = false;
	    }
	    break;

	case 5:
	    if (decPrivateModeFlag == true) {
		// Auto print mode

	    } else {
		// Printer controller

		// Characters get sucked into oblivion
		printerControllerMode = true;
	    }
	    break;

	default:
	    break;

	}
    }

    /**
     * Handle the SCAN_OSC_STRING state.  Handle this in VT100 because
     * lots of remote systems will send an XTerm title sequence even if TERM
     * isn't xterm.
     */
    private void oscPut(dchar xtermChar) {
	// Collect first
	collectBuffer ~= xtermChar;

	// Xterm cases...
	if (xtermChar == 0x07) {
	    dstring arg = to!dstring(collectBuffer[0 .. $ - 1]);
	    dstring [] p = split(arg, ";");
	    if (p.length > 0) {
		if ((p[0] == "0") || (p[0] == "2")) {
		    if (p.length > 1) {
			// Screen title
			screenTitle = p[1];
		    }
		}
	    }

	    // Go to SCAN_GROUND state
	    toGround();
	    return;
	}
    }

    /**
     * Run this input character through the ECMA48 state machine
     *
     * Params:
     *    ch = UTF-decoded character from the remote side
     */
    public void consume(dchar ch) {

	// DEBUG
	// stderr.writef("%c", ch);

	// Special case for VT10x: 7-bit characters only
	if ((type == DeviceType.VT100) || (type == DeviceType.VT102)) {
	    ch = ch & 0x7F;
	}
	
	// Special "anywhere" states

	// 18, 1A                     --> execute, then switch to SCAN_GROUND
	if ((ch == 0x18) || (ch == 0x1A)) {
	    // CAN and SUB abort escape sequences
	    toGround();
	    return;
	}

	// 80-8F, 91-97, 99, 9A, 9C   --> execute, then switch to SCAN_GROUND

	// 0x1B == C_ESC
	if ((ch == C_ESC) &&
	    (scanState != ScanState.DCS_ENTRY) &&
	    (scanState != ScanState.DCS_INTERMEDIATE) &&
	    (scanState != ScanState.DCS_IGNORE) &&
	    (scanState != ScanState.DCS_PARAM) &&
	    (scanState != ScanState.DCS_PASSTHROUGH)
	) {

	    scanState = ScanState.ESCAPE;
	    return;
	}

	// 0x9B == CSI 8-bit sequence
	if (ch == 0x9B) {
	    scanState = ScanState.CSI_ENTRY;
	    return;
	}

	// 0x9D goes to ScanState.OSC_STRING
	if (ch == 0x9D) {
	    scanState = ScanState.OSC_STRING;
	    return;
	}

	// 0x90 goes to ScanState.DCS_ENTRY
	if (ch == 0x90) {
	    scanState = ScanState.DCS_ENTRY;
	    return;
	}

	// 0x98, 0x9E, and 0x9F go to ScanState.SOSPMAPC_STRING
	if ((ch == 0x98) || (ch == 0x9E) || (ch == 0x9F)) {
	    scanState = ScanState.SOSPMAPC_STRING;
	    return;
	}

	// 0x7F (DEL) is always discarded
	if (ch == 0x7F) {
	    return;
	}

	final switch (scanState) {

	case ScanState.GROUND:
	    // 00-17, 19, 1C-1F --> execute
	    // 80-8F, 91-9A, 9C --> execute
	    if ((ch <= 0x1F) || ((ch >= 0x80) && (ch <= 0x9F))) {
		handleControlChar(ch);
	    }

	    // 20-7F            --> print
	    if (((ch >= 0x20) && (ch <= 0x7F)) ||
		(ch >= 0xA0)
	    ) {

		// VT220 printer --> trash bin
		if (((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) &&
		    (printerControllerMode == true)) {
		    return;
		}

		// Hang onto this character
		repCh = mapCharacter(ch);

		// Print this character
		printCharacter(repCh);
	    }
	    return;

	case ScanState.ESCAPE:
	    // 00-17, 19, 1C-1F --> execute
	    if (ch <= 0x1F) {
		handleControlChar(ch);
		return;
	    }

	    // 20-2F            --> collect, then switch to ScanState.ESCAPE_INTERMEDIATE
	    if ((ch >= 0x20) && (ch <= 0x2F)) {
		collect(ch);
		scanState = ScanState.ESCAPE_INTERMEDIATE;
		return;
	    }

	    // 30-4F, 51-57, 59, 5A, 5C, 60-7E   --> dispatch, then switch to ScanState.GROUND
	    if ((ch >= 0x30) && (ch <= 0x4F)) {
		final switch (ch) {
		case '0':
		case '1':
		case '2':
		case '3':
		case '4':
		case '5':
		case '6':
		    break;
		case '7':
		    // DECSC - Save cursor
		    // Note this code overlaps both ANSI and VT52 mode
		    decsc();
		    break;

		case '8':
		    // DECRC - Restore cursor
		    // Note this code overlaps both ANSI and VT52 mode
		    decrc();
		    break;

		case '9':
		case ':':
		case ';':
		    break;
		case '<':
		    if (vt52Mode == true) {
			// DECANM - Enter ANSI mode
			vt52Mode = false;
			arrowKeyMode = ArrowKeyMode.VT100;

			/*
			 * From the VT102 docs: "You use ANSI mode to select
			 * most terminal features; the terminal uses the same
			 * features when it switches to VT52 mode. You
			 * cannot, however, change most of these features in
			 * VT52 mode."
			 *
			 * In other words, do not reset any other attributes
			 * when switching between VT52 submode and ANSI.
			 */

			// Reset fonts
			currentState.g0Charset = CharacterSet.US;
			currentState.g1Charset = CharacterSet.DRAWING;
			s8c1t = false;
			singleshift = Singleshift.NONE;
			currentState.glLockshift = LockshiftMode.NONE;
			currentState.grLockshift = LockshiftMode.NONE;
		    }
		    break;
		case '=':
		    // DECKPAM - Keypad application mode
		    // Note this code overlaps both ANSI and VT52 mode
		    deckpam();
		    break;
		case '>':
		    // DECKPNM - Keypad numeric mode
		    // Note this code overlaps both ANSI and VT52 mode
		    deckpnm();
		    break;
		case '?':
		case '@':
		    break;
		case 'A':
		    if (vt52Mode == true) {
			// Cursor up, and stop at the top without scrolling
			cursorUp(1, false);
		    }
		    break;
		case 'B':
		    if (vt52Mode == true) {
			// Cursor down, and stop at the bottom without scrolling
			cursorDown(1, false);
		    }
		    break;
		case 'C':
		    if (vt52Mode == true) {
			// Cursor right, and stop at the right without scrolling
			cursorRight(1, false);
		    }
		    break;
		case 'D':
		    if (vt52Mode == true) {
			// Cursor left, and stop at the left without scrolling
			cursorLeft(1, false);
		    } else {
			// IND - Index
			ind();
		    }
		    break;
		case 'E':
		    if (vt52Mode == true) {
			// Nothing
		    } else {
			// NEL - Next line
			nel();
		    }
		    break;
		case 'F':
		    if (vt52Mode == true) {
			// G0 --> Special graphics
			currentState.g0Charset = CharacterSet.VT52_GRAPHICS;
		    }
		    break;
		case 'G':
		    if (vt52Mode == true) {
			// G0 --> ASCII set
			currentState.g0Charset = CharacterSet.US;
		    }
		    break;
		case 'H':
		    if (vt52Mode == true) {
			// Cursor to home
			cursorPosition(0, 0);
		    } else {
			// HTS - Horizontal tabulation set
			hts();
		    }
		    break;
		case 'I':
		    if (vt52Mode == true) {
			// Reverse line feed.  Same as RI.
			ri();
		    }
		    break;
		case 'J':
		    if (vt52Mode == true) {
			// Erase to end of screen
			eraseLine(currentState.cursorX, width - 1, false);
			eraseScreen(currentState.cursorY + 1, 0, height - 1, width - 1, false);
		    }
		    break;
		case 'K':
		    if (vt52Mode == true) {
			// Erase to end of line
			eraseLine(currentState.cursorX, width - 1, false);
		    }
		    break;
		case 'L':
		    break;
		case 'M':
		    if (vt52Mode == true) {
			// Nothing
		    } else {
			// RI - Reverse index
			ri();
		    }
		    break;
		case 'N':
		    if (vt52Mode == false) {
			// SS2
			singleshift = Singleshift.SS2;
		    }
		    break;
		case 'O':
		    if (vt52Mode == false) {
			// SS3
			singleshift = Singleshift.SS3;
		    }
		    break;
		}
		toGround();
		return;
	    }
	    if ((ch >= 0x51) && (ch <= 0x57)) {
		final switch (ch) {
		case 'Q':
		case 'R':
		case 'S':
		case 'T':
		case 'U':
		case 'V':
		case 'W':
		    break;
		}
		toGround();
		return;
	    }
	    if (ch == 0x59) {
		// 'Y'
		if (vt52Mode == true) {
		    scanState = ScanState.VT52_DIRECT_CURSOR_ADDRESS;
		} else {
		    toGround();
		}
		return;
	    }
	    if (ch == 0x5A) {
		// 'Z'
		if (vt52Mode == true) {
		    // Identify
		    // Send string directly to remote side
		    writeRemote("\033/Z",);
		} else {
		    // DECID
		    // Send string directly to remote side
		    writeRemote(deviceTypeResponse());
		}
		toGround();
		return;
	    }
	    if (ch == 0x5C) {
		// '\'
		toGround();
		return;
	    }

	    // VT52 cannot get to any of these other states
	    if (vt52Mode == true) {
		toGround();
		return;
	    }

	    if ((ch >= 0x60) && (ch <= 0x7E)) {
		final switch (ch) {
		case '`':
		case 'a':
		case 'b':
		    break;
		case 'c':
		    // RIS - Reset to initial state
		    reset();
		    // Do I clear screen too? I think so...
		    eraseScreen(0, 0, height - 1, width - 1, false);
		    cursorPosition(0, 0);
		    break;
		case 'd':
		case 'e':
		case 'f':
		case 'g':
		case 'h':
		case 'i':
		case 'j':
		case 'k':
		case 'l':
		case 'm':
		    break;
		case 'n':
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			// VT220 lockshift G2 into GL
			currentState.glLockshift = LockshiftMode.G2_GL;
			shiftOut = false;
		    }
		    break;
		case 'o':
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			// VT220 lockshift G3 into GL
			currentState.glLockshift = LockshiftMode.G3_GL;
			shiftOut = false;
		    }
		    break;
		case 'p':
		case 'q':
		case 'r':
		case 's':
		case 't':
		case 'u':
		case 'v':
		case 'w':
		case 'x':
		case 'y':
		case 'z':
		case '{':
		    break;
		case '|':
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			// VT220 lockshift G3 into GR
			currentState.grLockshift = LockshiftMode.G3_GR;
			shiftOut = false;
		    }
		    break;
		case '}':
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			// VT220 lockshift G2 into GR
			currentState.grLockshift = LockshiftMode.G2_GR;
			shiftOut = false;
		    }
		    break;

		case '~':
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			// VT220 lockshift G1 into GR
			currentState.grLockshift = LockshiftMode.G1_GR;
			shiftOut = false;
		    }
		    break;
		}
		toGround();
	    }

	    // 7F               --> ignore

	    // 0x5B goes to ScanState.CSI_ENTRY
	    if (ch == 0x5B) {
		scanState = ScanState.CSI_ENTRY;
	    }

	    // 0x5D goes to ScanState.OSC_STRING
	    if (ch == 0x5D) {
		scanState = ScanState.OSC_STRING;
	    }

	    // 0x50 goes to ScanState.DCS_ENTRY
	    if (ch == 0x50) {
		scanState = ScanState.DCS_ENTRY;
	    }

	    // 0x58, 0x5E, and 0x5F go to ScanState.SOSPMAPC_STRING
	    if ((ch == 0x58) || (ch == 0x5E) || (ch == 0x5F)) {
		scanState = ScanState.SOSPMAPC_STRING;
	    }

	    return;

	case ScanState.ESCAPE_INTERMEDIATE:
	    // 00-17, 19, 1C-1F    --> execute
	    if (ch <= 0x1F) {
		handleControlChar(ch);
	    }

	    // 20-2F               --> collect
	    if ((ch >= 0x20) && (ch <= 0x2F)) {
		collect(ch);
	    }

	    // 30-7E               --> dispatch, then switch to ScanState.GROUND
	    if ((ch >= 0x30) && (ch <= 0x7E)) {
		final switch (ch) {
		case '0':
		    if ((collectBuffer.length == 1) && (collectBuffer[0] == '(')) {
			// G0 --> Special graphics
			currentState.g0Charset = CharacterSet.DRAWING;
		    }
		    if ((collectBuffer.length == 1) && (collectBuffer[0] == ')')) {
			// G1 --> Special graphics
			currentState.g1Charset = CharacterSet.DRAWING;
		    }
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			if ((collectBuffer.length == 1) && (collectBuffer[0] == '*')) {
			    // G2 --> Special graphics
			    currentState.g2Charset = CharacterSet.DRAWING;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '+')) {
			    // G3 --> Special graphics
			    currentState.g3Charset = CharacterSet.DRAWING;
			}
		    }
		    break;
		case '1':
		    if ((collectBuffer.length == 1) && (collectBuffer[0] == '(')) {
			// G0 --> Alternate character ROM standard character set
			currentState.g0Charset = CharacterSet.ROM;
		    }
		    if ((collectBuffer.length == 1) && (collectBuffer[0] == ')')) {
			// G1 --> Alternate character ROM standard character set
			currentState.g1Charset = CharacterSet.ROM;
		    }
		    break;
		case '2':
		    if ((collectBuffer.length == 1) && (collectBuffer[0] == '(')) {
			// G0 --> Alternate character ROM special graphics
			currentState.g0Charset = CharacterSet.ROM_SPECIAL;
		    }
		    if ((collectBuffer.length == 1) && (collectBuffer[0] == ')')) {
			// G1 --> Alternate character ROM special graphics
			currentState.g1Charset = CharacterSet.ROM_SPECIAL;
		    }
		    break;
		case '3':
		    if ((collectBuffer.length == 1) && (collectBuffer[0] == '#')) {
			// DECDHL - Double-height line (top half)
			dechdl(true);
		    }
		    break;
		case '4':
		    if ((collectBuffer.length == 1) && (collectBuffer[0] == '#')) {
			// DECDHL - Double-height line (bottom half)
			dechdl(false);
		    }
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			if ((collectBuffer.length == 1) && (collectBuffer[0] == '(')) {
			    // G0 --> DUTCH
			    currentState.g0Charset = CharacterSet.NRC_DUTCH;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == ')')) {
			    // G1 --> DUTCH
			    currentState.g1Charset = CharacterSet.NRC_DUTCH;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '*')) {
			    // G2 --> DUTCH
			    currentState.g2Charset = CharacterSet.NRC_DUTCH;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '+')) {
			    // G3 --> DUTCH
			    currentState.g3Charset = CharacterSet.NRC_DUTCH;
			}
		    }
		    break;
		case '5':
		    if ((collectBuffer.length == 1) && (collectBuffer[0] == '#')) {
			// DECSWL - Single-width line
			decswl();
		    }
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			if ((collectBuffer.length == 1) && (collectBuffer[0] == '(')) {
			    // G0 --> FINNISH
			    currentState.g0Charset = CharacterSet.NRC_FINNISH;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == ')')) {
			    // G1 --> FINNISH
			    currentState.g1Charset = CharacterSet.NRC_FINNISH;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '*')) {
			    // G2 --> FINNISH
			    currentState.g2Charset = CharacterSet.NRC_FINNISH;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '+')) {
			    // G3 --> FINNISH
			    currentState.g3Charset = CharacterSet.NRC_FINNISH;
			}
		    }
		    break;
		case '6':
		    if ((collectBuffer.length == 1) && (collectBuffer[0] == '#')) {
			// DECDWL - Double-width line
			decdwl();
		    }
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			if ((collectBuffer.length == 1) && (collectBuffer[0] == '(')) {
			    // G0 --> NORWEGIAN
			    currentState.g0Charset = CharacterSet.NRC_NORWEGIAN;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == ')')) {
			    // G1 --> NORWEGIAN
			    currentState.g1Charset = CharacterSet.NRC_NORWEGIAN;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '*')) {
			    // G2 --> NORWEGIAN
			    currentState.g2Charset = CharacterSet.NRC_NORWEGIAN;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '+')) {
			    // G3 --> NORWEGIAN
			    currentState.g3Charset = CharacterSet.NRC_NORWEGIAN;
			}
		    }
		    break;
		case '7':
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			if ((collectBuffer.length == 1) && (collectBuffer[0] == '(')) {
			    // G0 --> SWEDISH
			    currentState.g0Charset = CharacterSet.NRC_SWEDISH;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == ')')) {
			    // G1 --> SWEDISH
			    currentState.g1Charset = CharacterSet.NRC_SWEDISH;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '*')) {
			    // G2 --> SWEDISH
			    currentState.g2Charset = CharacterSet.NRC_SWEDISH;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '+')) {
			    // G3 --> SWEDISH
			    currentState.g3Charset = CharacterSet.NRC_SWEDISH;
			}
		    }
		    break;
		case '8':
		    if ((collectBuffer.length == 1) && (collectBuffer[0] == '#')) {
			// DECALN - Screen alignment display
			decaln();
		    }
		    break;
		case '9':
		case ':':
		case ';':
		    break;
		case '<':
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			if ((collectBuffer.length == 1) && (collectBuffer[0] == '(')) {
			    // G0 --> DEC_SUPPLEMENTAL
			    currentState.g0Charset = CharacterSet.DEC_SUPPLEMENTAL;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == ')')) {
			    // G1 --> DEC_SUPPLEMENTAL
			    currentState.g1Charset = CharacterSet.DEC_SUPPLEMENTAL;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '*')) {
			    // G2 --> DEC_SUPPLEMENTAL
			    currentState.g2Charset = CharacterSet.DEC_SUPPLEMENTAL;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '+')) {
			    // G3 --> DEC_SUPPLEMENTAL
			    currentState.g3Charset = CharacterSet.DEC_SUPPLEMENTAL;
			}
		    }
		    break;
		case '=':
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			if ((collectBuffer.length == 1) && (collectBuffer[0] == '(')) {
			    // G0 --> SWISS
			    currentState.g0Charset = CharacterSet.NRC_SWISS;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == ')')) {
			    // G1 --> SWISS
			    currentState.g1Charset = CharacterSet.NRC_SWISS;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '*')) {
			    // G2 --> SWISS
			    currentState.g2Charset = CharacterSet.NRC_SWISS;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '+')) {
			    // G3 --> SWISS
			    currentState.g3Charset = CharacterSet.NRC_SWISS;
			}
		    }
		    break;
		case '>':
		case '?':
		case '@':
		    break;
		case 'A':
		    if ((collectBuffer.length == 1) && (collectBuffer[0] == '(')) {
			// G0 --> United Kingdom set
			currentState.g0Charset = CharacterSet.UK;
		    }
		    if ((collectBuffer.length == 1) && (collectBuffer[0] == ')')) {
			// G1 --> United Kingdom set
			currentState.g1Charset = CharacterSet.UK;
		    }
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			if ((collectBuffer.length == 1) && (collectBuffer[0] == '*')) {
			    // G2 --> United Kingdom set
			    currentState.g2Charset = CharacterSet.UK;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '+')) {
			    // G3 --> United Kingdom set
			    currentState.g3Charset = CharacterSet.UK;
			}
		    }
		    break;
		case 'B':
		    if ((collectBuffer.length == 1) && (collectBuffer[0] == '(')) {
			// G0 --> ASCII set
			currentState.g0Charset = CharacterSet.US;
		    }
		    if ((collectBuffer.length == 1) && (collectBuffer[0] == ')')) {
			// G1 --> ASCII set
			currentState.g1Charset = CharacterSet.US;
		    }
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			if ((collectBuffer.length == 1) && (collectBuffer[0] == '*')) {
			    // G2 --> ASCII
			    currentState.g2Charset = CharacterSet.US;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '+')) {
			    // G3 --> ASCII
			    currentState.g3Charset = CharacterSet.US;
			}
		    }
		    break;
		case 'C':
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			if ((collectBuffer.length == 1) && (collectBuffer[0] == '(')) {
			    // G0 --> FINNISH
			    currentState.g0Charset = CharacterSet.NRC_FINNISH;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == ')')) {
			    // G1 --> FINNISH
			    currentState.g1Charset = CharacterSet.NRC_FINNISH;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '*')) {
			    // G2 --> FINNISH
			    currentState.g2Charset = CharacterSet.NRC_FINNISH;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '+')) {
			    // G3 --> FINNISH
			    currentState.g3Charset = CharacterSet.NRC_FINNISH;
			}
		    }
		    break;
		case 'D':
		    break;
		case 'E':
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			if ((collectBuffer.length == 1) && (collectBuffer[0] == '(')) {
			    // G0 --> NORWEGIAN
			    currentState.g0Charset = CharacterSet.NRC_NORWEGIAN;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == ')')) {
			    // G1 --> NORWEGIAN
			    currentState.g1Charset = CharacterSet.NRC_NORWEGIAN;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '*')) {
			    // G2 --> NORWEGIAN
			    currentState.g2Charset = CharacterSet.NRC_NORWEGIAN;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '+')) {
			    // G3 --> NORWEGIAN
			    currentState.g3Charset = CharacterSet.NRC_NORWEGIAN;
			}
		    }
		    break;
		case 'F':
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			if ((collectBuffer.length == 1) && (collectBuffer[0] == ' ')) {
			    // S7C1T
			    s8c1t = false;
			}
		    }
		    break;
		case 'G':
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			if ((collectBuffer.length == 1) && (collectBuffer[0] == ' ')) {
			    // S8C1T
			    s8c1t = true;
			}
		    }
		    break;
		case 'H':
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			if ((collectBuffer.length == 1) && (collectBuffer[0] == '(')) {
			    // G0 --> SWEDISH
			    currentState.g0Charset = CharacterSet.NRC_SWEDISH;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == ')')) {
			    // G1 --> SWEDISH
			    currentState.g1Charset = CharacterSet.NRC_SWEDISH;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '*')) {
			    // G2 --> SWEDISH
			    currentState.g2Charset = CharacterSet.NRC_SWEDISH;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '+')) {
			    // G3 --> SWEDISH
			    currentState.g3Charset = CharacterSet.NRC_SWEDISH;
			}
		    }
		    break;
		case 'I':
		case 'J':
		    break;
		case 'K':
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			if ((collectBuffer.length == 1) && (collectBuffer[0] == '(')) {
			    // G0 --> GERMAN
			    currentState.g0Charset = CharacterSet.NRC_GERMAN;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == ')')) {
			    // G1 --> GERMAN
			    currentState.g1Charset = CharacterSet.NRC_GERMAN;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '*')) {
			    // G2 --> GERMAN
			    currentState.g2Charset = CharacterSet.NRC_GERMAN;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '+')) {
			    // G3 --> GERMAN
			    currentState.g3Charset = CharacterSet.NRC_GERMAN;
			}
		    }
		    break;
		case 'L':
		case 'M':
		case 'N':
		case 'O':
		case 'P':
		    break;
		case 'Q':
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			if ((collectBuffer.length == 1) && (collectBuffer[0] == '(')) {
			    // G0 --> FRENCH_CA
			    currentState.g0Charset = CharacterSet.NRC_FRENCH_CA;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == ')')) {
			    // G1 --> FRENCH_CA
			    currentState.g1Charset = CharacterSet.NRC_FRENCH_CA;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '*')) {
			    // G2 --> FRENCH_CA
			    currentState.g2Charset = CharacterSet.NRC_FRENCH_CA;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '+')) {
			    // G3 --> FRENCH_CA
			    currentState.g3Charset = CharacterSet.NRC_FRENCH_CA;
			}
		    }
		    break;
		case 'R':
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			if ((collectBuffer.length == 1) && (collectBuffer[0] == '(')) {
			    // G0 --> FRENCH
			    currentState.g0Charset = CharacterSet.NRC_FRENCH;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == ')')) {
			    // G1 --> FRENCH
			    currentState.g1Charset = CharacterSet.NRC_FRENCH;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '*')) {
			    // G2 --> FRENCH
			    currentState.g2Charset = CharacterSet.NRC_FRENCH;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '+')) {
			    // G3 --> FRENCH
			    currentState.g3Charset = CharacterSet.NRC_FRENCH;
			}
		    }
		    break;
		case 'S':
		case 'T':
		case 'U':
		case 'V':
		case 'W':
		case 'X':
		    break;
		case 'Y':
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			if ((collectBuffer.length == 1) && (collectBuffer[0] == '(')) {
			    // G0 --> ITALIAN
			    currentState.g0Charset = CharacterSet.NRC_ITALIAN;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == ')')) {
			    // G1 --> ITALIAN
			    currentState.g1Charset = CharacterSet.NRC_ITALIAN;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '*')) {
			    // G2 --> ITALIAN
			    currentState.g2Charset = CharacterSet.NRC_ITALIAN;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '+')) {
			    // G3 --> ITALIAN
			    currentState.g3Charset = CharacterSet.NRC_ITALIAN;
			}
		    }
		    break;
		case 'Z':
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			if ((collectBuffer.length == 1) && (collectBuffer[0] == '(')) {
			    // G0 --> SPANISH
			    currentState.g0Charset = CharacterSet.NRC_SPANISH;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == ')')) {
			    // G1 --> SPANISH
			    currentState.g1Charset = CharacterSet.NRC_SPANISH;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '*')) {
			    // G2 --> SPANISH
			    currentState.g2Charset = CharacterSet.NRC_SPANISH;
			}
			if ((collectBuffer.length == 1) && (collectBuffer[0] == '+')) {
			    // G3 --> SPANISH
			    currentState.g3Charset = CharacterSet.NRC_SPANISH;
			}
		    }
		    break;
		case '[':
		case '\\':
		case ']':
		case '^':
		case '_':
		case '`':
		case 'a':
		case 'b':
		case 'c':
		case 'd':
		case 'e':
		case 'f':
		case 'g':
		case 'h':
		case 'i':
		case 'j':
		case 'k':
		case 'l':
		case 'm':
		case 'n':
		case 'o':
		case 'p':
		case 'q':
		case 'r':
		case 's':
		case 't':
		case 'u':
		case 'v':
		case 'w':
		case 'x':
		case 'y':
		case 'z':
		case '{':
		case '|':
		case '}':
		case '~':
		    break;
		}
		toGround();
	    }

	    // 7F                  --> ignore

	    // 0x9C goes to ScanState.GROUND
	    if (ch == 0x9C) {
		toGround();
	    }

	    return;

	case ScanState.CSI_ENTRY:
	    // 00-17, 19, 1C-1F    --> execute
	    if (ch <= 0x1F) {
		handleControlChar(ch);
	    }

	    // 20-2F               --> collect, then switch to ScanState.CSI_INTERMEDIATE
	    if ((ch >= 0x20) && (ch <= 0x2F)) {
		collect(ch);
		scanState = ScanState.CSI_INTERMEDIATE;
	    }

	    // 30-39, 3B           --> param, then switch to ScanState.CSI_PARAM
	    if ((ch >= '0') && (ch <= '9')) {
		param(cast(byte)ch);
		scanState = ScanState.CSI_PARAM;
	    }
	    if (ch == ';') {
		param(cast(byte)ch);
		scanState = ScanState.CSI_PARAM;
	    }

	    // 3C-3F               --> collect, then switch to ScanState.CSI_PARAM
	    if ((ch >= 0x3C) && (ch <= 0x3F)) {
		collect(ch);
		scanState = ScanState.CSI_PARAM;
	    }

	    // 40-7E               --> dispatch, then switch to ScanState.GROUND
	    if ((ch >= 0x40) && (ch <= 0x7E)) {
		final switch (ch) {
		case '@':
		    // ICH - Insert character
		    ich();
		    break;
		case 'A':
		    // CUU - Cursor up
		    cuu();
		    break;
		case 'B':
		    // CUD - Cursor down
		    cud();
		    break;
		case 'C':
		    // CUF - Cursor forward
		    cuf();
		    break;
		case 'D':
		    // CUB - Cursor backward
		    cub();
		    break;
		case 'E':
		    // CNL - Cursor down and to column 1
		    if (type == DeviceType.XTERM) {
			cnl();
		    }
		    break;
		case 'F':
		    // CPL - Cursor up and to column 1
		    if (type == DeviceType.XTERM) {
			cpl();
		    }
		    break;
		case 'G':
		    // CHA - Cursor to column # in current row
		    if (type == DeviceType.XTERM) {
			cha();
		    }
		    break;
		case 'H':
		    // CUP - Cursor position
		    cup();
		    break;
		case 'I':
		    // CHT - Cursor forward X tab stops (default 1)
		    if (type == DeviceType.XTERM) {
			cht();
		    }
		    break;
		case 'J':
		    // ED - Erase in display
		    ed();
		    break;
		case 'K':
		    // EL - Erase in line
		    el();
		    break;
		case 'L':
		    // IL - Insert line
		    il();
		    break;
		case 'M':
		    // DL - Delete line
		    dl();
		    break;
		case 'N':
		case 'O':
		    break;
		case 'P':
		    // DCH - Delete character
		    dch();
		    break;
		case 'Q':
		case 'R':
		    break;
		case 'S':
		    // Scroll up X lines (default 1)
		    if (type == DeviceType.XTERM) {
			su();
		    }
		    break;
		case 'T':
		    // Scroll down X lines (default 1)
		    if (type == DeviceType.XTERM) {
			sd();
		    }
		    break;
		case 'U':
		case 'V':
		case 'W':
		    break;
		case 'X':
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			// ECH - Erase character
			ech();
		    }
		    break;
		case 'Y':
		    break;
		case 'Z':
		    // CBT - Cursor backward X tab stops (default 1)
		    if (type == DeviceType.XTERM) {
			cbt();
		    }
		    break;
		case '[':
		case '\\':
		case ']':
		case '^':
		case '_':
		    break;
		case '`':
		    // HPA - Cursor to column # in current row.  Same as CHA
		    if (type == DeviceType.XTERM) {
			cha();
		    }
		    break;
		case 'a':
		    // HPR - Cursor right.  Same as CUF
		    if (type == DeviceType.XTERM) {
			cuf();
		    }
		    break;
		case 'b':
		    // REP - Repeat last char X times
		    if (type == DeviceType.XTERM) {
			rep();
		    }
		    break;
		case 'c':
		    // DA - Device attributes
		    da();
		    break;
		case 'd':
		    // VPA - Cursor to row, current column.
		    if (type == DeviceType.XTERM) {
			vpa();
		    }
		    break;
		case 'e':
		    // VPR - Cursor down.  Same as CUD
		    if (type == DeviceType.XTERM) {
			cud();
		    }
		    break;
		case 'f':
		    // HVP - Horizontal and vertical position
		    hvp();
		    break;
		case 'g':
		    // TBC - Tabulation clear
		    tbc();
		    break;
		case 'h':
		    // Sets an ANSI or DEC private toggle
		    setToggle(true);
		    break;
		case 'i':
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			// Printer functions
			printerFunctions();
		    }
		    break;
		case 'j':
		case 'k':
		    break;
		case 'l':
		    // Sets an ANSI or DEC private toggle
		    setToggle(false);
		    break;
		case 'm':
		    // SGR - Select graphics rendition
		    sgr();
		    break;
		case 'n':
		    // DSR - Device status report
		    dsr();
		    break;
		case 'o':
		case 'p':
		    break;
		case 'q':
		    // DECLL - Load leds
		    // Not supported
		    break;
		case 'r':
		    // DECSTBM - Set top and bottom margins
		    decstbm();
		    break;
		case 's':
		    // Save cursor (ANSI.SYS)
		    if (type == DeviceType.XTERM) {
			savedState.cursorX = currentState.cursorX;
			savedState.cursorY = currentState.cursorY;
		    }
		    break;
		case 't':
		    break;
		case 'u':
		    // Restore cursor (ANSI.SYS)
		    if (type == DeviceType.XTERM) {
			cursorPosition(savedState.cursorY, savedState.cursorX);
		    }
		    break;
		case 'v':
		case 'w':
		    break;
		case 'x':
		    // DECREQTPARM - Request terminal parameters
		    decreqtparm();
		    break;
		case 'y':
		case 'z':
		case '{':
		case '|':
		case '}':
		case '~':
		    break;
		}
		toGround();
	    }

	    // 7F                  --> ignore

	    // 0x9C goes to ScanState.GROUND
	    if (ch == 0x9C) {
		toGround();
	    }

	    // 0x3A goes to ScanState.CSI_IGNORE
	    if (ch == 0x3A) {
		scanState = ScanState.CSI_IGNORE;
	    }
	    return;

	case ScanState.CSI_PARAM:
	    // 00-17, 19, 1C-1F    --> execute
	    if (ch <= 0x1F) {
		handleControlChar(ch);
	    }

	    // 20-2F               --> collect, then switch to ScanState.CSI_INTERMEDIATE
	    if ((ch >= 0x20) && (ch <= 0x2F)) {
		collect(ch);
		scanState = ScanState.CSI_INTERMEDIATE;
	    }

	    // 30-39, 3B           --> param
	    if ((ch >= '0') && (ch <= '9')) {
		param(cast(byte)ch);
	    }
	    if (ch == ';') {
		param(cast(byte)ch);
	    }

	    // 0x3A goes to ScanState.CSI_IGNORE
	    if (ch == 0x3A) {
		scanState = ScanState.CSI_IGNORE;
	    }
	    // 0x3C-3F goes to ScanState.CSI_IGNORE
	    if ((ch >= 0x3C) && (ch <= 0x3F)) {
		scanState = ScanState.CSI_IGNORE;
	    }

	    // 40-7E               --> dispatch, then switch to ScanState.GROUND
	    if ((ch >= 0x40) && (ch <= 0x7E)) {
		final switch (ch) {
		case '@':
		    // ICH - Insert character
		    ich();
		    break;
		case 'A':
		    // CUU - Cursor up
		    cuu();
		    break;
		case 'B':
		    // CUD - Cursor down
		    cud();
		    break;
		case 'C':
		    // CUF - Cursor forward
		    cuf();
		    break;
		case 'D':
		    // CUB - Cursor backward
		    cub();
		    break;
		case 'E':
		    // CNL - Cursor down and to column 1
		    if (type == DeviceType.XTERM) {
			cnl();
		    }
		    break;
		case 'F':
		    // CPL - Cursor up and to column 1
		    if (type == DeviceType.XTERM) {
			cpl();
		    }
		    break;
		case 'G':
		    // CHA - Cursor to column # in current row
		    if (type == DeviceType.XTERM) {
			cha();
		    }
		    break;
		case 'H':
		    // CUP - Cursor position
		    cup();
		    break;
		case 'I':
		    // CHT - Cursor forward X tab stops (default 1)
		    if (type == DeviceType.XTERM) {
			cht();
		    }
		    break;
		case 'J':
		    // ED - Erase in display
		    ed();
		    break;
		case 'K':
		    // EL - Erase in line
		    el();
		    break;
		case 'L':
		    // IL - Insert line
		    il();
		    break;
		case 'M':
		    // DL - Delete line
		    dl();
		    break;
		case 'N':
		case 'O':
		    break;
		case 'P':
		    // DCH - Delete character
		    dch();
		    break;
		case 'Q':
		case 'R':
		    break;
		case 'S':
		    // Scroll up X lines (default 1)
		    if (type == DeviceType.XTERM) {
			su();
		    }
		    break;
		case 'T':
		    // Scroll down X lines (default 1)
		    if (type == DeviceType.XTERM) {
			sd();
		    }
		    break;
		case 'U':
		case 'V':
		case 'W':
		    break;
		case 'X':
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			// ECH - Erase character
			ech();
		    }
		    break;
		case 'Y':
		    break;
		case 'Z':
		    // CBT - Cursor backward X tab stops (default 1)
		    if (type == DeviceType.XTERM) {
			cbt();
		    }
		    break;
		case '[':
		case '\\':
		case ']':
		case '^':
		case '_':
		    break;
		case '`':
		    // HPA - Cursor to column # in current row.  Same as CHA
		    if (type == DeviceType.XTERM) {
			cha();
		    }
		    break;
		case 'a':
		    // HPR - Cursor right.  Same as CUF
		    if (type == DeviceType.XTERM) {
			cuf();
		    }
		    break;
		case 'b':
		    // REP - Repeat last char X times
		    if (type == DeviceType.XTERM) {
			rep();
		    }
		    break;
		case 'c':
		    // DA - Device attributes
		    da();
		    break;
		case 'd':
		    // VPA - Cursor to row, current column.
		    if (type == DeviceType.XTERM) {
			vpa();
		    }
		    break;
		case 'e':
		    // VPR - Cursor down.  Same as CUD
		    if (type == DeviceType.XTERM) {
			cud();
		    }
		    break;
		case 'f':
		    // HVP - Horizontal and vertical position
		    hvp();
		    break;
		case 'g':
		    // TBC - Tabulation clear
		    tbc();
		    break;
		case 'h':
		    // Sets an ANSI or DEC private toggle
		    setToggle(true);
		    break;
		case 'i':
		    if ((type == DeviceType.VT220) ||
			(type == DeviceType.XTERM)) {

			// Printer functions
			printerFunctions();
		    }
		    break;
		case 'j':
		case 'k':
		    break;
		case 'l':
		    // Sets an ANSI or DEC private toggle
		    setToggle(false);
		    break;
		case 'm':
		    // SGR - Select graphics rendition
		    sgr();
		    break;
		case 'n':
		    // DSR - Device status report
		    dsr();
		    break;
		case 'o':
		case 'p':
		    break;
		case 'q':
		    // DECLL - Load leds
		    // Not supported
		    break;
		case 'r':
		    // DECSTBM - Set top and bottom margins
		    decstbm();
		    break;
		case 's':
		case 't':
		case 'u':
		case 'v':
		case 'w':
		    break;
		case 'x':
		    // DECREQTPARM - Request terminal parameters
		    decreqtparm();
		    break;
		case 'y':
		case 'z':
		case '{':
		case '|':
		case '}':
		case '~':
		    break;
		}
		toGround();
	    }

	    // 7F                  --> ignore
	    return;

	case ScanState.CSI_INTERMEDIATE:
	    // 00-17, 19, 1C-1F    --> execute
	    if (ch <= 0x1F) {
		handleControlChar(ch);
	    }

	    // 20-2F               --> collect
	    if ((ch >= 0x20) && (ch <= 0x2F)) {
		collect(ch);
	    }

	    // 0x30-3F goes to ScanState.CSI_IGNORE
	    if ((ch >= 0x30) && (ch <= 0x3F)) {
		scanState = ScanState.CSI_IGNORE;
	    }

	    // 40-7E               --> dispatch, then switch to ScanState.GROUND
	    if ((ch >= 0x40) && (ch <= 0x7E)) {
		final switch (ch) {
		case '@':
		case 'A':
		case 'B':
		case 'C':
		case 'D':
		case 'E':
		case 'F':
		case 'G':
		case 'H':
		case 'I':
		case 'J':
		case 'K':
		case 'L':
		case 'M':
		case 'N':
		case 'O':
		case 'P':
		case 'Q':
		case 'R':
		case 'S':
		case 'T':
		case 'U':
		case 'V':
		case 'W':
		case 'X':
		case 'Y':
		case 'Z':
		case '[':
		case '\\':
		case ']':
		case '^':
		case '_':
		case '`':
		case 'a':
		case 'b':
		case 'c':
		case 'd':
		case 'e':
		case 'f':
		case 'g':
		case 'h':
		case 'i':
		case 'j':
		case 'k':
		case 'l':
		case 'm':
		case 'n':
		case 'o':
		    break;
		case 'p':
		    if (((type == DeviceType.VT220) ||
			    (type == DeviceType.XTERM)) &&
			(collectBuffer[$ - 1] == '\"')) {
			// DECSCL - compatibility level
			decscl();
		    }
		    if ((type == DeviceType.XTERM) &&
			(collectBuffer[$ - 1] == '!')) {
			// DECSTR - Soft terminal reset
			decstr();
		    }
		    break;
		case 'q':
		    if (((type == DeviceType.VT220) ||
			    (type == DeviceType.XTERM)) &&
			(collectBuffer[$ - 1] == '\"')) {
			// DECSCA
			decsca();
		    }
		    break;
		case 'r':
		case 's':
		case 't':
		case 'u':
		case 'v':
		case 'w':
		case 'x':
		case 'y':
		case 'z':
		case '{':
		case '|':
		case '}':
		case '~':
		    break;
		}
		toGround();
	    }

	    // 7F                  --> ignore
	    return;

	case ScanState.CSI_IGNORE:
	    // 00-17, 19, 1C-1F    --> execute
	    if (ch <= 0x1F) {
		handleControlChar(ch);
	    }

	    // 20-2F               --> collect
	    if ((ch >= 0x20) && (ch <= 0x2F)) {
		collect(ch);
	    }

	    // 40-7E               --> ignore, then switch to ScanState.GROUND
	    if ((ch >= 0x40) && (ch <= 0x7E)) {
		toGround();
	    }

	    // 20-3F, 7F           --> ignore

	    return;

	case ScanState.DCS_ENTRY:

	    // 0x9C goes to ScanState.GROUND
	    if (ch == 0x9C) {
		toGround();
	    }

	    // 0x1B 0x5C goes to ScanState.GROUND
	    if (ch == 0x1B) {
		collect(ch);
	    }
	    if (ch == 0x5C) {
		if ((collectBuffer.length > 0) &&
		    (collectBuffer[$ - 1] == 0x1B)) {
		    toGround();
		}
	    }

	    // 20-2F               --> collect, then switch to ScanState.DCS_INTERMEDIATE
	    if ((ch >= 0x20) && (ch <= 0x2F)) {
		collect(ch);
		scanState = ScanState.DCS_INTERMEDIATE;
	    }

	    // 30-39, 3B           --> param, then switch to ScanState.DCS_PARAM
	    if ((ch >= '0') && (ch <= '9')) {
		param(cast(byte)ch);
		scanState = ScanState.DCS_PARAM;
	    }
	    if (ch == ';') {
		param(cast(byte)ch);
		scanState = ScanState.DCS_PARAM;
	    }

	    // 3C-3F               --> collect, then switch to ScanState.DCS_PARAM
	    if ((ch >= 0x3C) && (ch <= 0x3F)) {
		collect(ch);
		scanState = ScanState.DCS_PARAM;
	    }

	    // 00-17, 19, 1C-1F, 7F    --> ignore

	    // 0x3A goes to ScanState.DCS_IGNORE
	    if (ch == 0x3F) {
		scanState = ScanState.DCS_IGNORE;
	    }

	    // 0x40-7E goes to ScanState.DCS_PASSTHROUGH
	    if ((ch >= 0x40) && (ch <= 0x7E)) {
		scanState = ScanState.DCS_PASSTHROUGH;
	    }
	    return;

	case ScanState.DCS_INTERMEDIATE:

	    // 0x9C goes to ScanState.GROUND
	    if (ch == 0x9C) {
		toGround();
	    }

	    // 0x1B 0x5C goes to ScanState.GROUND
	    if (ch == 0x1B) {
		collect(ch);
	    }
	    if (ch == 0x5C) {
		if ((collectBuffer.length > 0) &&
		    (collectBuffer[$ - 1] == 0x1B)) {
		    toGround();
		}
	    }

	    // 0x30-3F goes to ScanState.DCS_IGNORE
	    if ((ch >= 0x30) && (ch <= 0x3F)) {
		scanState = ScanState.DCS_IGNORE;
	    }

	    // 0x40-7E goes to ScanState.DCS_PASSTHROUGH
	    if ((ch >= 0x40) && (ch <= 0x7E)) {
		scanState = ScanState.DCS_PASSTHROUGH;
	    }

	    // 00-17, 19, 1C-1F, 7F    --> ignore
	    return;

	case ScanState.DCS_PARAM:

	    // 0x9C goes to ScanState.GROUND
	    if (ch == 0x9C) {
		toGround();
	    }

	    // 0x1B 0x5C goes to ScanState.GROUND
	    if (ch == 0x1B) {
		collect(ch);
	    }
	    if (ch == 0x5C) {
		if ((collectBuffer.length > 0) &&
		    (collectBuffer[$ - 1] == 0x1B)) {
		    toGround();
		}
	    }

	    // 20-2F                   --> collect, then switch to ScanState.DCS_INTERMEDIATE
	    if ((ch >= 0x20) && (ch <= 0x2F)) {
		collect(ch);
		scanState = ScanState.DCS_INTERMEDIATE;
	    }

	    // 30-39, 3B               --> param
	    if ((ch >= '0') && (ch <= '9')) {
		param(cast(byte)ch);
	    }
	    if (ch == ';') {
		param(cast(byte)ch);
	    }

	    // 00-17, 19, 1C-1F, 7F    --> ignore

	    // 0x3A, 3C-3F goes to ScanState.DCS_IGNORE
	    if (ch == 0x3F) {
		scanState = ScanState.DCS_IGNORE;
	    }
	    if ((ch >= 0x3C) && (ch <= 0x3F)) {
		scanState = ScanState.DCS_IGNORE;
	    }

	    // 0x40-7E goes to ScanState.DCS_PASSTHROUGH
	    if ((ch >= 0x40) && (ch <= 0x7E)) {
		scanState = ScanState.DCS_PASSTHROUGH;
	    }
	    return;

	case ScanState.DCS_PASSTHROUGH:
	    // 0x9C goes to ScanState.GROUND
	    if (ch == 0x9C) {
		toGround();
	    }

	    // 0x1B 0x5C goes to ScanState.GROUND
	    if (ch == 0x1B) {
		collect(ch);
	    }
	    if (ch == 0x5C) {
		if ((collectBuffer.length > 0) &&
		    (collectBuffer[$ - 1] == 0x1B)) {
		    toGround();
		}
	    }

	    // 00-17, 19, 1C-1F, 20-7E   --> put
	    // TODO
	    if (ch <= 0x17) {
		return;
	    }
	    if (ch == 0x19) {
		return;
	    }
	    if ((ch >= 0x1C) && (ch <= 0x1F)) {
		return;
	    }
	    if ((ch >= 0x20) && (ch <= 0x7E)) {
		return;
	    }

	    // 7F                        --> ignore

	    return;

	case ScanState.DCS_IGNORE:
	    // 00-17, 19, 1C-1F, 20-7F --> ignore

	    // 0x9C goes to ScanState.GROUND
	    if (ch == 0x9C) {
		toGround();
	    }

	    return;

	case ScanState.SOSPMAPC_STRING:
	    // 00-17, 19, 1C-1F, 20-7F --> ignore

	    // 0x9C goes to ScanState.GROUND
	    if (ch == 0x9C) {
		toGround();
	    }

	    return;

	case ScanState.OSC_STRING:
	    // Special case for Xterm: OSC can pass control characters
	    if ((ch == 0x9C) || (ch <= 0x07)) {
		oscPut(ch);
	    }

	    // 00-17, 19, 1C-1F        --> ignore

	    // 20-7F                   --> osc_put
	    if ((ch >= 0x20) && (ch <= 0x7F)) {
		oscPut(ch);
	    }

	    // 0x9C goes to ScanState.GROUND
	    if (ch == 0x9C) {
		toGround();
	    }

	    return;

	case ScanState.VT52_DIRECT_CURSOR_ADDRESS:
	    // This is a special case for the VT52 sequence "ESC Y l c"
	    if (collectBuffer.length == 0) {
		collect(ch);
	    } else if (collectBuffer.length == 1) {
		// We've got the two characters, one in the buffer and the
		// other in ch.
		cursorPosition(collectBuffer[0] - '\040', ch - '\040');
		toGround();
	    }
	    return;
	}

    }

    /**
     * Expose current cursor X to outside world
     *
     * Return:
     *    current cursor X
     */
    public uint getCursorX() {
	return currentState.cursorX;
    }

    /**
     * Expose current cursor Y to outside world
     *
     * Return:
     *    current cursor Y
     */
    public uint getCursorY() {
	return currentState.cursorY;
    }

}

version (Posix) {
    // Posix systems get a shell through forkpty()
    private import core.sys.posix.signal;
    private import core.sys.posix.stdlib;
    private import core.sys.posix.termios;
    private import core.sys.posix.sys.ioctl;

    extern (C) {
	pid_t forkpty(int * amaster, char * name, termios * termp,
	    winsize * winp);
    }
}

/**
 * TTerminal exposes a ECMA-48 / ANSI X3.64 style terminal in a window.
 */
public class TTerminal : TWindow {

    private import std.stdio;

    /// The emulator
    private ECMA48 emulator;

    /// The shell process stdin/stdout handle
    private int shellFD = -1;

    /// The shell process pid
    private int shellPid = -1;

    /// If true, the process is still running
    private bool processRunning = false;

    /// If true, we expect to see UTF-8 in the streams to/from the
    /// shell process
    private bool utf8 = true;

    private import core.stdc.errno;
    private import core.stdc.string;

    private void makeShell() {

	shellPid = forkpty(&shellFD, null, null, null);

	if (shellPid == 0) {
	    // This is the child, exec bash
	    string [] args = ["/bin/bash", "--login"];

	    // Convert program name and arguments to C-style strings.
	    auto argz = new const(char)*[args.length + 1];
	    argz[0] = toStringz(args[0]);
	    foreach (i; 1 .. args.length) {
		argz[i] = toStringz(args[i]);
	    }
	    argz[$ - 1] = null;

	    // Set TERM
	    string termString = emulator.deviceTypeTerm();
	    core.sys.posix.stdlib.putenv(cast(char *)toStringz(termString));

	    // We set LANG, but lots of shells don't honor it
	    string langString = emulator.deviceTypeLang("en_US");
	    core.sys.posix.stdlib.putenv(cast(char *)toStringz(langString));

	    // Execute the shell
	    core.sys.posix.unistd.execvp(argz[0], argz.ptr);

	    // Should never get here
	    stderr.writefln("exec() failed: %d (%s)", errno,
		to!string(strerror(errno)));
	    stderr.flush();
	    exit(-1);
	}
	processRunning = true;
    }

    /**
     * Public constructor.
     *
     * Params:
     *    application = TApplication that manages this window
     *    x = column relative to parent
     *    y = row relative to parent
     *    flags = mask of CENTERED, or MODAL (RESIZABLE is stripped)
     */
    public this(TApplication application, int x, int y,
	Flag flags = Flag.CENTERED) {

	super(application, "Terminal", x, y, 80 + 2, 24 + 2,
	    flags & ~Flag.RESIZABLE);

	emulator = new ECMA48(ECMA48.DeviceType.XTERM,
	    delegate(dstring str) {
		if (processRunning) {
		    ubyte [] utf8Buffer;
		    foreach (ch; str) {
			if (utf8) {
			    encodeUTF8(ch, utf8Buffer);
			} else {
			    utf8Buffer ~= ch & 0xFF;
			}
		    }
		    core.sys.posix.unistd.write(shellFD, utf8Buffer.ptr,
			utf8Buffer.length);
		    core.sys.posix.unistd.fsync(shellFD);
		}
	    });

	makeShell();

	readEmulatorState();
    }

    /// Draw the display buffer
    override public void draw() {
	// Draw the box using my superclass
	super.draw();

	// Now draw the emulator screen
	int row = 1;
	foreach (line; emulator.display) {
	    int widthMax = emulator.width;
	    if (line.doubleWidth) {
		widthMax /= 2;
	    }
	    for (auto i = 0; i < widthMax; i++) {
		Cell ch = line.chars[i];
		Cell newCell = new Cell();
		newCell.setTo(ch);
		bool reverse = line.reverseColor ^ ch.reverse;
		newCell.reverse = false;
		if (reverse) {
		    newCell.backColor = ch.foreColor;
		    newCell.foreColor = ch.backColor;
		}
		if (line.doubleWidth) {
		    screen.putCharXY((i * 2) + 1, row, newCell);
		    screen.putCharXY((i * 2) + 2, row, ' ', newCell);
		} else {
		    screen.putCharXY(i + 1, row, newCell);
		}
	    }
	    row++;
	}
	assert(row + 1 == height);
    }

    /**
     * Handle window close
     */
    override public void onClose() {
	if (processRunning) {
	    kill(shellPid, SIGTERM);
	    processRunning = false;
	}
    }

    version(Posix) {
	// Used in doIdle() to poll process
	private import core.sys.posix.poll;
    }

    /**
     * Copy out variables from the emulator that TTerminal has to
     * expose on screen.
     */
    private void readEmulatorState() {
	cursorX = emulator.getCursorX() + 1;
	cursorY = emulator.getCursorY() + 1;
	hasCursor = emulator.visibleCursor;
	if (cursorX > width - 2) {
	    cursorX = width - 2;
	}
	if (cursorY > height - 2) {
	    cursorY = height - 2;
	}
	if (emulator.screenTitle.length > 0) {
	    title = emulator.screenTitle;
	}
    }

    /**
     * Poll data from the child process
     */
    override public void onIdle() {
	if (!processRunning) {
	    return;
	}
	pollfd pfd;
	int i = 0;
	int poll_rc = -1;
	do {
	    assert(shellFD > 0);

	    pfd.fd = shellFD;
	    pfd.events = POLLIN;
	    pfd.revents = 0;
	    poll_rc = poll(&pfd, 1, 0);
	    if (poll_rc > 0) {
		application.repaint = true;

		// We have data, read it
		try {
		    if (utf8) {
			try {
			    emulator.consume(Terminal.getCharFileno(shellFD));
			} catch (UTFException e) {
			    // The remote side is sending non-UTF, so
			    // stop trying to decode UTF8 from here on
			    // out.
			    utf8 = false;
			}
		    } else {
			emulator.consume(Terminal.getByteFileno(shellFD));
		    }
		    readEmulatorState();
		} catch (FileException e) {
		    // We got EOF, close the file
		    title = title ~ " (Offline)";
		    processRunning = false;
		    int status;
		    waitpid(shellPid, &status, WNOHANG);
		    return;
		}
	    }
	    i++;
	} while ((poll_rc > 0) && (i < 1024)) ;
    }

    /**
     * Handle keystrokes.
     *
     * Params:
     *    event = keystroke event
     */
    override protected void onKeypress(TKeypressEvent event) {
	if (processRunning) {
	    dstring response = emulator.keypress(event.key);
	    ubyte [] utf8Buffer;
	    foreach (ch; response) {
		if (utf8) {
		    encodeUTF8(ch, utf8Buffer);
		} else {
		    utf8Buffer ~= ch & 0xFF;
		}
	    }
	    core.sys.posix.unistd.write(shellFD, utf8Buffer.ptr,
		utf8Buffer.length);
	    core.sys.posix.unistd.fsync(shellFD);
	    readEmulatorState();
	}
    }

}

// Functions -----------------------------------------------------------------
