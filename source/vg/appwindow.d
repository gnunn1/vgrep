/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module vg.appwindow;

import std.concurrency;
import std.experimental.logger;
import std.format;
import std.process;
import std.uuid;

import gdk.RGBA;
import gdk.Threads;

import gtk.Application: Application;
import gio.Application: GioApplication = Application;
import gtk.ApplicationWindow: ApplicationWindow;
import gtkc.giotypes: GApplicationFlags;

import gtk.Box;
import gtk.Button;
import gtk.CellRendererText;
import gdk.Event;
import gtk.HeaderBar;
import gtk.Label;
import gtk.ListStore;
import gtk.Notebook;
import gtk.Paned;
import gtk.ScrolledWindow;
import gtk.Statusbar;
import gtk.StyleContext;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.TreeStore;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.Widget;

import gtk.color;
import gtk.widget.tablabel;
import gtk.util;
import gtk.threads;
import util.file.search;

import vg.configuration;
import vg.finddialog;
import vg.search;

/**
 * The main window of the application
 */
class MainWindow: ApplicationWindow {

private:

	Button btnFind;
	HeaderBar hb;
	Notebook nb;
	SearchManager manager;
	ResultPage[string] pages;

	bool idleHandlerEnabled = false;

	private bool delegate() cbThreadIdle;

	void createUI() {
		//Create header bar
		hb = new HeaderBar();
		hb.setShowCloseButton(true);
		hb.setTitle("Visual Grep");
		this.setTitlebar(hb);
		
		//Create Find button
		btnFind = new Button(StockID.FIND);
		btnFind.setAlwaysShowImage(true);
		btnFind.addOnClicked(&showFindDialog);
		btnFind.setTooltipText("Initiate new search");

		hb.packStart(btnFind);
		
		//Create New Button
		Button btnNew = new Button("tab-new-symbolic", IconSize.BUTTON);
		btnNew.setAlwaysShowImage(true);
		btnNew.addOnClicked(&createNewTab);
		btnNew.setTooltipText("Create a new tab");

		hb.packStart(btnNew);

		//Create Notebook
		nb = new Notebook();
		nb.addOnSwitchPage(&pageChanged);
		this.add(nb);
		
		createNewSearchPage();

		this.setDefaultSize(1024,640);
	}
	
	void createNewTab(Button button) {
		createNewSearchPage();
	}

	void pageChanged(Widget page, uint pageNum, Notebook notebook) {
		updateUIState();
	}

	void createNewSearchPage() {
		string id = randomUUID.toString();
		ResultPage page = new ResultPage(manager, id);
		pages[id] = page;
		TabLabel label = new TabLabel("Search", page);
		label.addOnCloseClicked(&closePage);
		nb.appendPage(page, label);
		nb.showAll();
		nb.setCurrentPage(nb.getNPages()-1);

		updateUIState();
	}

	void closePage(TabLabel label, Widget widget) {
		ResultPage page = cast(ResultPage) widget;
		manager.stop(page.id);
		if (page.id in pages) {
			pages.remove(page.id);
		}
		nb.remove(page);

		updateUIState();
	}
	
	void showFindDialog(Button button) {
		ResultPage page = cast(ResultPage)nb.getNthPage(nb.getCurrentPage());
		if (!page) return;

		TabLabel label = cast(TabLabel) nb.getTabLabel(page);

		FindDialog dialog = new FindDialog(this, label.text, page.criteria);
		scope(exit) dialog.destroy;

		dialog.showAll();
		if (dialog.run()==ResponseType.OK) {
			Criteria criteria = dialog.criteria();
			label.text = dialog.searchName;
			Configuration.instance().addPath(criteria.path);
			Configuration.instance().addPattern(criteria.pattern);
			page.searchStart(criteria);
			MarkupTags markup = page.getMarkupTags();
			doSearch(criteria, markup);
		}

		updateUIState();
	}

	/**
	 * Updates the UI state in terms of enabling/disabling elements, etc.  
	 */
	void updateUIState() {
		// Only show tabs when more then one tab is present, emulate gedit and files behavior in gnome
		nb.setShowTabs((nb.getNPages()>1));

		// Check if any search is in progress for the current page and disable find button if it
		if (nb.getCurrentPage()>=0) {
			ResultPage page = cast(ResultPage)nb.getNthPage(nb.getCurrentPage());
			btnFind.setSensitive(!manager.isSearchInProgress(page.id));
		}
	}

	bool progress(string id, string currentPath) {
		ResultPage page;
		try {
			page = pages[id];
		} catch (Throwable t) {
			error(id,": Failed to find page for id");
			return true;
		}
		page.searchProgress(currentPath);

		updateUIState();
		return false;
	}
	
	bool result(string id, Result result) {
		ResultPage page = pages[id];
		if (page is null) {
			return true;
		} else {
			page.searchResult(result);
		}
		updateUIState();
		return false;
	}

	void finished(string id, bool aborted, ulong total) {
		info(id, ": Finished");
		ResultPage page;
		try {
			page = pages[id];
		} catch (Throwable t) {
			error(id,": Failed to find page for id");
			return;
		}
		//Todo - Should show the total matches found
		page.searchCompleted(aborted, total);
		updateUIState();
	}

	void doSearch(Criteria criteria, MarkupTags markup) {
		trace("Calling manager to do search...");
		manager.search(criteria, markup);
		if (!idleHandlerEnabled) {
			trace("Adding idle handler...");
			threadsAddIdleDelegate(cbThreadIdle);
		}
	}

	bool checkPendingSearches() {
		//writeln("Checking pending messages...", thisTid);
		if (!manager.checkPending(1)) {
			idleHandlerEnabled = false;
			trace("Stopping idle handler...");
			return false;
		}
		return true;
	}

	bool windowClosed(Event event, Widget widget) {
		Configuration.instance.mainWindow = getWindowDisplayState(this);
		manager.stopAll();
		return false;
	}

public:

	this(Application application) {
		super(application);
		cbThreadIdle = &this.checkPendingSearches;
		setTitle("Visual Grep");
		setIconName("search");

		manager = new SearchManager();
		manager.onResult = &result;
		manager.onProgress = &progress;
		manager.onFinished = &finished;
		createUI();

		this.addOnDelete(&windowClosed);
	}
}

/**
 * The individual pages of the notebook where the search results are displayed
 */
class ResultPage: Box {
	
private:
	SearchManager manager;

	TreeView tvResults;
	TreeView tvMatches;
	Statusbar sbStatus;
	Button btnAbort;
	
	Criteria _criteria;
	
	ListStore lsResults;
	ListStore lsMatches;
	
	Result[] results;
	
	void  createUI() {
		Paned paned = new Paned(GtkOrientation.VERTICAL);
		
		//Results View
		tvResults = new TreeView();
		tvResults.setHexpand(true);
		tvResults.setVexpand(true);
		tvResults.setActivateOnSingleClick(false);
		
		ScrolledWindow scrollResults = new ScrolledWindow();
		scrollResults.add(tvResults);
		
		TreeViewColumn column = new TreeViewColumn("File", new CellRendererText(), "text", 0);
		column.setExpand(true);
		tvResults.appendColumn(column);
		tvResults.appendColumn(new TreeViewColumn("Matches", new CellRendererText(), "text", 1));
		lsResults = new ListStore([GType.STRING, GType.LONG]);
		tvResults.setModel(lsResults);
		
		tvResults.addOnRowActivated(&rowActivatedResults);
		tvResults.addOnCursorChanged(&rowSelectedResults);
		
		//Matches View
		tvMatches = new TreeView();
		tvMatches.setHexpand(true);
		tvMatches.setVexpand(true);
		tvMatches.setActivateOnSingleClick(false);
		
		lsMatches = new ListStore([GType.LONG, GType.STRING]);
		tvMatches.setModel(lsMatches);
		
		ScrolledWindow scrollMatches = new ScrolledWindow();
		scrollMatches.add(tvMatches);
		
		tvMatches.appendColumn(new TreeViewColumn("Line", new CellRendererText(), "text", 0));
		column = new TreeViewColumn("Match", new CellRendererText(), "markup", 1);
		column.setExpand(true);
		tvMatches.appendColumn(column);
		
		paned.add(scrollResults,scrollMatches);
		add(paned);
		paned.setPosition(300);
		
		//Status button and abort button
		Box b = new Box(Orientation.HORIZONTAL, 0);
		
		sbStatus = new Statusbar();
		sbStatus.setHexpand(true);
		b.add(sbStatus);
		
		btnAbort = new Button("window-close-symbolic", IconSize.MENU);
		btnAbort.setRelief(ReliefStyle.NONE);
		btnAbort.setFocusOnClick(false);
		btnAbort.setSensitive(false);
		btnAbort.setTooltipText("Abort the current search");
		btnAbort.addOnClicked(&abortSearch);
		b.add(btnAbort);
		
		add(b);
		
	}
	
	void rowSelectedResults(TreeView tv) {
		lsMatches.clear();
		TreeIter selected = tv.getSelectedIter();
		if (selected !is null) {
			TreePath path = lsResults.getPath(selected);
			auto index = path.getIndices()[0];
			foreach(Match match; results[index].matches) {
				TreeIter iter = lsMatches.createIter();
				lsMatches.setValue(iter, 0, cast(int)match.lineNo);
				lsMatches.setValue(iter, 1, match.line );
			}
		}
	}
	
	void rowActivatedResults(TreePath path, TreeViewColumn column, TreeView tv) {
		if (path.getIndices().length>0) {
			TreeIter selectedIter = new TreeIter();
			if (tv.getModel().getIter(selectedIter, path)) {
				auto index = path.getIndices()[0];
				trace("Launching application for file ", results[index].file);
				executeShell(format("xdg-open \"%s\"", results[index].file));
			}
		}
	}

	void abortSearch(Button button) {
		manager.stop(_criteria.id);
		button.setSensitive(false);
	}

package:

	/**
	 * Gets the Pango markup tags to highlight search results, uses the
	 * selection colors of the treeview for the highlight.
	 */
	MarkupTags getMarkupTags() {
		RGBA bg;
		RGBA fg;
		StyleContext context = tvMatches.getStyleContext();
		context.getBackgroundColor(StateFlags.SELECTED, bg);
		context.getColor(StateFlags.SELECTED, fg);
		
		MarkupTags result = {true, format("<span background='#%s' foreground='#%s'>",rgbaToHex(bg), rgbaToHex(fg)), "</span>"};
		return result;
	}

	void clear() {
		lsMatches.clear();
		lsResults.clear();
		results = [];
		sbStatus.removeAll(0);
	}

public:
	
	this(SearchManager manager, string id) {
		super(GtkOrientation.VERTICAL,0);
		this.manager = manager;
		_criteria.id = id;
		createUI();
	}
	
	@property string id() {
		return _criteria.id;
	};

	@property Criteria criteria() {
		return _criteria;
	}

	void searchStart(Criteria value) {
		this._criteria = value;
		clear();
		sbStatus.push(1, "Starting...");
		btnAbort.setSensitive(true);
	}

	void searchProgress(string currentPath) {
		sbStatus.push(1, format("Search %s", currentPath));
	}

	void searchResult(Result result) {
		TreeIter iter = lsResults.createIter();
		lsResults.setValue(iter, 0, result.file);
		lsResults.setValue(iter, 1, cast(int)result.matchCount);
		results ~= result;
		trace("Results length: ", results.length);
	}

	void searchCompleted(bool aborted, ulong total) {
		sbStatus.removeAll(1);
		sbStatus.push(0, format("%s, total matches found %d", aborted?"Aborted":"Completed", total));
		btnAbort.setSensitive(false);
	}
}