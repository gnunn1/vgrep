/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module vg.application;

import std.experimental.logger;

import gio.Menu;
import gio.SimpleAction;

import glib.Variant;
import glib.VariantType;

import gtk.AboutDialog;
import gtk.Application;
import gtk.Dialog;

import gtk.util;

import i18n.l10n;

import vg.appwindow;
import vg.constants;
import vg.configuration;

class VisualGrep: Application {

private:

	private MainWindow window;

	/**
     * Maps actions registered to the application by their action name.
     * 
	 * This code from grestful (https://github.com/Gert-dev/grestful)
     */
	SimpleAction[string] registeredActions;

	/**
     * Retrieves the action with the specified name. The action must exist. If an attempt is made to fetch a
     * non-existing action, it is a programmatic error and it will be caught by an assert in debug mode.
	 *
	 * This code from grestful (https://github.com/Gert-dev/grestful)
	 *
     * @param name The name of the action to retrieve.
     *
     * @return The action (which must exist or the method will fail).
     */
	SimpleAction getAction(string name)
	{
		assert(name in this.registeredActions);
		return this.registeredActions[name];
	}
	
	/**
     * Convenience function to quickly set an action as enabled or disabled.
     *
	 * This code from grestful (https://github.com/Gert-dev/grestful)
     *
     * @param name    The name of the action.
     * @param enabled Whether to enable the action or not.
     */
	void setActionEnabled(string name, bool enabled)
	{
		this.getAction(name).setEnabled(enabled);
	}
	
	/**
     * Adds a new action to the specified menu. An action is automatically added to the application that invokes the
     * specified callback when the actual menu item is activated.
     * 
	 * This code from grestful (https://github.com/Gert-dev/grestful)
     *
     * @param id                   The ID to give to the action. This can be used in other places to refer to the action
     *                             by a string. Must always start with "app.".
     * @param accelerator          The (application wide) keyboard accelerator to activate the action.
     * @param callback             The callback to invoke when the action is invoked.
     * @param type                 The type of data passed as parameter to the action when activated.
     * @param acceleratorParameter The parameter to pass to the callback when the action is invoked by its
     *                             accelerator.
     *
     * @return The registered action.
     */
	SimpleAction registerAction(
		string id,
		string accelerator = null,
		void delegate(Variant, SimpleAction) callback = null,
		VariantType type = null,
		Variant acceleratorParameter = null
		) {
		// Application registered actions expect a prefix of app. and we need to specify the name
		// without 'app' here.
		SimpleAction action = new SimpleAction(id[4 .. $], type);
		this.registeredActions[id] = action;
		
		if (callback !is null)
			action.addOnActivate(callback);
		
		this.addAction(action);
		
		if (accelerator)
			this.addAccelerator(accelerator, id, acceleratorParameter);
		
		return action;
	}

	/**
     * Installs the application menu. This is the menu that drops down in gnome-shell when you click the application
     * name next to Activities.
     * 
	 * This code adapted from grestful (https://github.com/Gert-dev/grestful)
     */
	void installAppMenu()
	{
		Menu menu;
		
		this.registerAction("app.about", null, delegate(Variant, SimpleAction) {
				this.showAboutDialog();
			});
		
		this.registerAction("app.quit", null, delegate(Variant, SimpleAction) {
				this.window.close();
			});

		with (menu = new Menu())
		{
			append(_("About"), "app.about");
			append(_("Quit"), "app.quit");
		}
		
		this.setAppMenu(menu);
	}

	/**
     * Shows the about dialog.
     * 
	 * This code adapted from grestful (https://github.com/Gert-dev/grestful)
     */
	void showAboutDialog()
	{
		AboutDialog dialog;
		
		with (dialog = new AboutDialog())
		{
			setDestroyWithParent(true);
			setTransientFor(this.window);
			setModal(true);
			
			setWrapLicense(true);
			setLogoIconName(null);
			setName(APPLICATION_NAME);
			setComments(APPLICATION_COMMENTS);
			setVersion(APPLICATION_VERSION);
			setCopyright(APPLICATION_COPYRIGHT);
			setAuthors(APPLICATION_AUTHORS.dup);
			setArtists(APPLICATION_ARTISTS.dup);
			setDocumenters(APPLICATION_DOCUMENTERS.dup);
			setTranslatorCredits(APPLICATION_TRANSLATORS);
			setLicense(APPLICATION_LICENSE);
			//addCreditSection(_("Credits"), [])
			
			addOnResponse(delegate(int responseId, Dialog sender) {
					if (responseId == ResponseType.CANCEL || responseId == ResponseType.DELETE_EVENT)
						sender.hideOnDelete(); // Needed to make the window closable (and hide instead of be deleted).
				});
			
			present();
		}
	}

	void appActivate(GioApplication app) { 
		window = new MainWindow(this);
		restoreWindowDisplayState(window, Configuration.instance.mainWindow);
		window.showAll();
	}

	void appStartup(GioApplication app) { 
		trace("Startup Signal");
		Configuration.instance.loadConfig();
		installAppMenu();
	}

	void appShutdown(GioApplication app) { 
		trace("Quit Signal");
		Configuration.instance.saveConfig();
	}

public:

	this() {
		super(APPLICATION_ID, ApplicationFlags.FLAGS_NONE);

		this.addOnActivate(&appActivate);
		this.addOnStartup(&appStartup);
		this.addOnShutdown(&appShutdown);
	}
}
