/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gtk.color;

import std.conv;
import std.format;

import gdk.RGBA;

string rgbaToHex(RGBA color) {
	int red = to!(int)(color.red() * 255);
	int green = to!(int)(color.green() * 255);
	int blue = to!(int)(color.blue() * 255);
	int alpha = to!(int)(color.alpha() * 255);

	return format("%X%X%X%X",red,green,blue,alpha);
}

