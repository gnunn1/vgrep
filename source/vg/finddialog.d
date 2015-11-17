/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module vg.finddialog;

import std.container;

import gtk.Box;
import gtk.Button;
import gtk.Dialog;
import gtk.Entry;
import gtk.Grid;
import gtk.ComboBoxText;
import gtk.FileChooserDialog;
import gtk.Label;
import gtk.Switch;
import gtk.Widget;
import gtk.Window;

import util.file.search;

import vg.configuration;

class FindDialog: Dialog {

private:
	ComboBoxText cbPattern;
	ComboBoxText cbPath;
	ComboBoxText cbMask;
	Entry eSearchName;
	Switch swCaseInsensitive;
	Switch swSearchSubdirectories;
	Switch swFollowSymbolic;

	string id;

	void createUI() {
		setDefaultSize(800,300);

		//Create Grid Layour
		Grid grid = new Grid();
		
		grid.setColumnSpacing(12);
		grid.setRowSpacing(6);
		grid.setMarginTop(18);
		grid.setMarginBottom(18);
		grid.setMarginLeft(18);
		grid.setMarginRight(18);

		int row = 0;
		//Search Label Title Text
		Label label = new Label("<b>Search Name</b>");
		label.setUseMarkup(true);
		label.setHalign(Align.START);
		grid.attach(label,0,row,2,1);
		row++;

		//Search Label
		grid.attach(createLabel("Name"),0,row,1,1);
		eSearchName = new Entry();
		grid.attach(eSearchName, 1,row,1,1);
		row++;

		//Search Text Title Label
		label = new Label("<b>Search Text</b>");
		label.setUseMarkup(true);
		label.setHalign(Align.START);
		label.setMarginTop(18);
		grid.attach(label,0,row,2,1);
		row++;

		//Search Pattern
		grid.attach(createLabel("Pattern"),0,row,1,1);
		cbPattern = new ComboBoxText(true);
		cbPattern.setHexpand(true);
		cbPattern.addOnChanged(&changeListener);
		grid.attach(cbPattern,1,row,1,1);
		row++;

		//Case Insensitive
		swCaseInsensitive = new Switch();
		swCaseInsensitive.setHalign(GtkAlign.START);
		grid.attach(createLabel("Case Insenstive"),0,row,1,1);
		grid.attach(swCaseInsensitive,1,row,1,1);
		row++;

		//Search Path Ttitle Label
		label = new Label("<b>Search Path</b>");
		label.setUseMarkup(true);
		label.setHalign(Align.START);
		label.setMarginTop(18);
		grid.attach(label,0,row,2,1);
		row++;

		//Search Path
		grid.attach(createLabel("Path"),0,row,1,1);
		cbPath = new ComboBoxText(true);
		cbPath.setHexpand(true);
		cbPath.addOnChanged(&changeListener);
		Box box = new Box(Orientation.HORIZONTAL, 0);
		box.add(cbPath);
		//Select Directory
		Button button = new Button("folder-symbolic", IconSize.MENU);
		box.add(button);
		button.addOnClicked(&selectPath);
		grid.attach(box,1,row,1,1);
		row++;

		//Mask
		grid.attach(createLabel("File Mask"),0,row,1,1);
		cbMask = new ComboBoxText(true);
		cbMask.setHexpand(true);
		cbMask.addOnChanged(&changeListener);
		grid.attach(cbMask,1,row,1,1);
		row++;

		//Create Search Subdirectories
		swSearchSubdirectories = new Switch();
		swSearchSubdirectories.setHalign(GtkAlign.START);
		grid.attach(createLabel("Search Subdirectories"),0,row,1,1);
		grid.attach(swSearchSubdirectories,1,row,1,1);
		row++;

		//Create Follow Symlinks Row
		swFollowSymbolic = new Switch();
		swFollowSymbolic.setHalign(GtkAlign.START);
		grid.attach(createLabel("Follow Symlinks"),0,row,1,1);
		grid.attach(swFollowSymbolic,1,row,1,1);
		row++;

		getContentArea().add(grid);
	}

	Label createLabel(string text) {
		Label label = new Label(text);
		label.setHalign(GtkAlign.END);
		label.setMarginLeft(12);
		return label;
	}

	void updateUIState() {
		bool okEnabled = (cbPattern.getActiveText().length>0 && cbPath.getActiveText().length>0);
		setResponseSensitive(ResponseType.OK, okEnabled);
	}

	void changeListener(ComboBoxText cbt) {
		updateUIState();
	}

	void selectPath(Button button) {
		FileChooserDialog dialog = new FileChooserDialog("Select Path", this, FileChooserAction.SELECT_FOLDER, ["Open", "Cancel"], [ResponseType.OK, ResponseType.CANCEL]);
		scope(exit) dialog.destroy();
		dialog.setDefaultResponse(ResponseType.OK);

		if (cbPath.getActiveText().length>0) {
			dialog.setFilename(cbPath.getActiveText());
		}
		if (dialog.run()) {
			Widget widget = cbPath.getChild();
			if (widget !is null) {
				Entry entry = new Entry(cast(GtkEntry*)widget.getWidgetStruct());
				entry.setText(dialog.getFilename());
			}		
		}
	}


public:
	this(Window parent, string id) {
		super("Find",parent,GtkDialogFlags.MODAL+GtkDialogFlags.USE_HEADER_BAR,[StockID.CANCEL,StockID.OK],[ResponseType.CANCEL,ResponseType.OK]);
		setDefaultResponse(ResponseType.OK);
		this.id = id;
		createUI();
	}

	this(Window parent, string searchName, Criteria criteria) {
		this(parent, criteria.id);

		eSearchName.setText(searchName);

		foreach(pattern; Configuration.instance.getPatterns()) cbPattern.appendText(pattern);
		foreach(path; Configuration.instance.getPaths()) cbPath.appendText(path);
		foreach(mask; Configuration.instance.getMasks()) cbMask.appendText(mask);

		if (criteria.pattern.length>0) {
			cbPattern.setActiveText(criteria.pattern);
		} else {
			cbPattern.setActive(-1);
		}

		if (criteria.path.length>0) {
			cbPath.setActiveText(criteria.path);
		} else {
			cbPath.setActive(-1);
		}

		if (criteria.wildcardPattern.length>0) {
			cbMask.setActiveText(criteria.wildcardPattern);
		} else {
			cbMask.setActive(-1);
		}

		swCaseInsensitive.setActive(criteria.caseInsensitive);
		swFollowSymbolic.setActive(criteria.followSymbolic);
		swSearchSubdirectories.setActive(criteria.searchSubdirectories);
		updateUIState();
	}

	Criteria criteria() {
		Criteria criteria = {id, 
			cbPattern.getActiveText(), 
			swCaseInsensitive.getActive(), 
			cbPath.getActiveText(), 
			cbMask.getActiveText(), 
			swSearchSubdirectories.getActive(), 
			swFollowSymbolic.getActive(),
			Configuration.instance.maximumMatches};
		return criteria;
	}

	@property string searchName() {
		return eSearchName.getText();
	}

	@property void setSearchName(string name) {
		eSearchName.setText(name);
	}
}

