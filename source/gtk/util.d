/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gtk.util;

import gtk.Window;

enum WindowState {NORMAL, MAXIMIZED};

struct WindowDisplayState {
	int x;
	int y;
	int w;
	int h;
	WindowState s;
}

void restoreWindowDisplayState(Window window, WindowDisplayState wds) {
	window.move(wds.x, wds.y);
	window.setDefaultSize(wds.w, wds.h);
	if (wds.s == WindowState.MAXIMIZED) window.maximize();
}

WindowDisplayState getWindowDisplayState(Window window) {
	WindowDisplayState result;
	result.s = WindowState.NORMAL;
	if (window.isMaximized) {
		result.s = WindowState.MAXIMIZED;
	}
	
	window.getPosition(result.x, result.y);
	window.getSize(result.w, result.h);
	
	return result;
}