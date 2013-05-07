/**
 * D Text User Interface library - codepages and miscellaneous text functions
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

import std.conv;
import std.utf;

// Defines -------------------------------------------------------------------

// Commonly used ASCII characters

public static immutable ubyte C_NUL	= 0x00;		/// NUL
public static immutable ubyte C_SOH	= 0x01;		/// SOH
public static immutable ubyte C_STX	= 0x02;		/// STX
public static immutable ubyte C_EOT	= 0x04;		/// EOT
public static immutable ubyte C_ACK	= 0x06;		/// ACK
public static immutable ubyte C_LF	= 0x0A;		/// Line feed '\n'
public static immutable ubyte C_CR	= 0x0D;		/// Carriage return '\r'
public static immutable ubyte C_XON	= 0x11;		/// XON, also known as DC1
public static immutable ubyte C_XOFF	= 0x13;		/// XOFF, also known as DC3
public static immutable ubyte C_NAK	= 0x15;		/// NAK
public static immutable ubyte C_CAN	= 0x18;		/// CAN
public static immutable ubyte C_SUB	= 0x1A;		/// SUB
public static immutable ubyte C_ESC	= 0x1B;		/// ESC

// Globals -------------------------------------------------------------------

/// CP437 translation map
public static immutable wchar cp437_chars[256] = [
    '\u2007', '\u263A', '\u263B', '\u2665', '\u2666', '\u2663', '\u2660', '\u2022',
    '\u25D8', '\u25CB', '\u25D9', '\u2642', '\u2640', '\u266A', '\u266B', '\u263C',
    '\u25BA', '\u25C4', '\u2195', '\u203C', '\u00B6', '\u00A7', '\u25AC', '\u21A8',
    '\u2191', '\u2193', '\u2192', '\u2190', '\u221F', '\u2194', '\u25B2', '\u25BC',
    '\u0020', '\u0021', '\u0022', '\u0023', '\u0024', '\u0025', '\u0026', '\u0027',
    '\u0028', '\u0029', '\u002a', '\u002b', '\u002c', '\u002d', '\u002e', '\u002f',
    '\u0030', '\u0031', '\u0032', '\u0033', '\u0034', '\u0035', '\u0036', '\u0037',
    '\u0038', '\u0039', '\u003a', '\u003b', '\u003c', '\u003d', '\u003e', '\u003f',
    '\u0040', '\u0041', '\u0042', '\u0043', '\u0044', '\u0045', '\u0046', '\u0047',
    '\u0048', '\u0049', '\u004a', '\u004b', '\u004c', '\u004d', '\u004e', '\u004f',
    '\u0050', '\u0051', '\u0052', '\u0053', '\u0054', '\u0055', '\u0056', '\u0057',
    '\u0058', '\u0059', '\u005a', '\u005b', '\u005c', '\u005d', '\u005e', '\u005f',
    '\u0060', '\u0061', '\u0062', '\u0063', '\u0064', '\u0065', '\u0066', '\u0067',
    '\u0068', '\u0069', '\u006a', '\u006b', '\u006c', '\u006d', '\u006e', '\u006f',
    '\u0070', '\u0071', '\u0072', '\u0073', '\u0074', '\u0075', '\u0076', '\u0077',
    '\u0078', '\u0079', '\u007a', '\u007b', '\u007c', '\u007d', '\u007e', '\u007f',
    '\u00c7', '\u00fc', '\u00e9', '\u00e2', '\u00e4', '\u00e0', '\u00e5', '\u00e7',
    '\u00ea', '\u00eb', '\u00e8', '\u00ef', '\u00ee', '\u00ec', '\u00c4', '\u00c5',
    '\u00c9', '\u00e6', '\u00c6', '\u00f4', '\u00f6', '\u00f2', '\u00fb', '\u00f9',
    '\u00ff', '\u00d6', '\u00dc', '\u00a2', '\u00a3', '\u00a5', '\u20a7', '\u0192',
    '\u00e1', '\u00ed', '\u00f3', '\u00fa', '\u00f1', '\u00d1', '\u00aa', '\u00ba',
    '\u00bf', '\u2310', '\u00ac', '\u00bd', '\u00bc', '\u00a1', '\u00ab', '\u00bb',
    '\u2591', '\u2592', '\u2593', '\u2502', '\u2524', '\u2561', '\u2562', '\u2556',
    '\u2555', '\u2563', '\u2551', '\u2557', '\u255d', '\u255c', '\u255b', '\u2510',
    '\u2514', '\u2534', '\u252c', '\u251c', '\u2500', '\u253c', '\u255e', '\u255f',
    '\u255a', '\u2554', '\u2569', '\u2566', '\u2560', '\u2550', '\u256c', '\u2567',
    '\u2568', '\u2564', '\u2565', '\u2559', '\u2558', '\u2552', '\u2553', '\u256b',
    '\u256a', '\u2518', '\u250c', '\u2588', '\u2584', '\u258c', '\u2590', '\u2580',
    '\u03b1', '\u00df', '\u0393', '\u03c0', '\u03a3', '\u03c3', '\u00b5', '\u03c4',
    '\u03a6', '\u0398', '\u03a9', '\u03b4', '\u221e', '\u03c6', '\u03b5', '\u2229',
    '\u2261', '\u00b1', '\u2265', '\u2264', '\u2320', '\u2321', '\u00f7', '\u2248',
    '\u00b0', '\u2219', '\u00b7', '\u221a', '\u207f', '\u00b2', '\u25a0', '\u00a0'
];

// Classes -------------------------------------------------------------------

public class GraphicsChars {

    public static immutable dchar HATCH		= cp437_chars[0xB0];
    public static immutable dchar DOUBLE_BAR	= cp437_chars[0xCD];
    public static immutable dchar BOX		= cp437_chars[0xFE];
    public static immutable dchar CHECK		= cp437_chars[0xFB];
    public static immutable dchar TRIPLET	= cp437_chars[0xF0];
    public static immutable dchar OMEGA		= cp437_chars[0xEA];
    public static immutable dchar PI		= cp437_chars[0xE3];
    public static immutable dchar UPARROW	= cp437_chars[0x18];
    public static immutable dchar DOWNARROW	= cp437_chars[0x19];
    public static immutable dchar RIGHTARROW	= cp437_chars[0x1A];
    public static immutable dchar LEFTARROW	= cp437_chars[0x1B];
    public static immutable dchar SINGLE_BAR	= cp437_chars[0xC4];
    public static immutable dchar BACK_ARROWHEAD	= cp437_chars[0x11];
    public static immutable dchar LRCORNER	= cp437_chars[0xD9];
    public static immutable dchar URCORNER	= cp437_chars[0xBF];
    public static immutable dchar LLCORNER	= cp437_chars[0xC0];
    public static immutable dchar ULCORNER	= cp437_chars[0xDA];
    public static immutable dchar DEGREE	= cp437_chars[0xF8];
    public static immutable dchar PLUSMINUS	= cp437_chars[0xF1];
    public static immutable dchar WINDOW_TOP		= cp437_chars[0xCD];
    public static immutable dchar WINDOW_LEFT_TOP	= cp437_chars[0xD5];
    public static immutable dchar WINDOW_RIGHT_TOP	= cp437_chars[0xB8];
    public static immutable dchar WINDOW_SIDE		= cp437_chars[0xB3];
    public static immutable dchar WINDOW_LEFT_BOTTOM	= cp437_chars[0xD4];
    public static immutable dchar WINDOW_RIGHT_BOTTOM	= cp437_chars[0xBE];
    public static immutable dchar WINDOW_LEFT_TEE	= cp437_chars[0xC6];
    public static immutable dchar WINDOW_RIGHT_TEE	= cp437_chars[0xB5];
    public static immutable dchar WINDOW_SIDE_DOUBLE		= cp437_chars[0xBA];
    public static immutable dchar WINDOW_LEFT_TOP_DOUBLE	= cp437_chars[0xC9];
    public static immutable dchar WINDOW_RIGHT_TOP_DOUBLE	= cp437_chars[0xBB];
    public static immutable dchar WINDOW_LEFT_BOTTOM_DOUBLE	= cp437_chars[0xC8];
    public static immutable dchar WINDOW_RIGHT_BOTTOM_DOUBLE	= cp437_chars[0xBC];
}

// Functions -----------------------------------------------------------------

/// Encode one character to UTF8
public void encodeUTF8(dchar ch, ref ubyte [] utf8Buffer) {
    if (ch <= 0x7F) {
	utf8Buffer.length += 1;
	utf8Buffer[$ - 1] = ch & 0x7F;
    } else if (ch <= 0x7FF) {
	utf8Buffer.length += 2;
	utf8Buffer[$ - 2] = 0xC0 | ((ch >>  6) & 0x1F);
	utf8Buffer[$ - 1] = 0x80 |  (ch        & 0x3F);
    } else if (ch <= 0xFFFF) {
	utf8Buffer.length += 3;
	utf8Buffer[$ - 3] = 0xE0 | ((ch >> 12) & 0x0F);
	utf8Buffer[$ - 2] = 0x80 | ((ch >>  6) & 0x3F);
	utf8Buffer[$ - 1] = 0x80 |  (ch        & 0x3F);
    } else if (ch <= 0x10FFFF) {
	utf8Buffer.length += 4;
	utf8Buffer[$ - 4] = 0xF0 | ((ch >> 18) & 0x07);
	utf8Buffer[$ - 3] = 0x80 | ((ch >> 12) & 0x3F);
	utf8Buffer[$ - 2] = 0x80 | ((ch >>  6) & 0x3F);
	utf8Buffer[$ - 1] = 0x80 |  (ch        & 0x3F);
    } else {
	// This isn't a defined UTF-8 character, throw exception
	throw new UTFException("Not a valid UTF dchar");
    }
}

/// Encode string to UTF8
public void encodeUTF8(string str, ref ubyte [] utf8Buffer) {
    foreach (ch; str) {
	encodeUTF8(ch, utf8Buffer);
    }
}

/// Encode string to UTF8
public void encodeUTF8(wstring str, ref ubyte [] utf8Buffer) {
    foreach (ch; str) {
	encodeUTF8(ch, utf8Buffer);
    }
}

/// Convert a ubyte [] to a string
public string ubyteToString(ubyte [] bytes) {
    string str = "";
    foreach (b; bytes) {
	str ~= to!(char)(b);
    }
    return str;
}

/// Convert one dchar to UTF8
public string dcharToString(dchar ch) {
    string str = "";
    char [] utf8str;
    encode(utf8str, ch);
    str ~= utf8str;
    return str;
}
