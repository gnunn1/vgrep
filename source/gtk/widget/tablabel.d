/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gtk.widget.tablabel;

import gtk.Button;
import gtk.Box;
import gtk.Label;
import gtk.Widget;

alias OnCloseClickedDelegate = void delegate(TabLabel label, Widget Page);

class TabLabel: Box {

private:
	Button button;
	Label label;
	Widget page;

	OnCloseClickedDelegate[] closeClickedHandlers;

	void closeClicked(Button button) {
		foreach (OnCloseClickedDelegate handler; closeClickedHandlers) {
			handler(this, page);
		}
	}

public:

	this(string label, Widget page) {
		super(Orientation.HORIZONTAL, 5);

		this.page = page;

		Label l = new Label(label);
		l.setHexpand(true);
		add(l);

		button = new Button("window-close-symbolic", IconSize.MENU);
		button.setRelief(ReliefStyle.NONE);
		button.setFocusOnClick(false);

		button.addOnClicked(&closeClicked);

		add(button);

		showAll();
	}

	void addOnCloseClicked(OnCloseClickedDelegate handler) {
		closeClickedHandlers ~= handler;
	}

}
