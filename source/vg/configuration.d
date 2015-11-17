/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module vg.configuration;

import std.algorithm;
import std.array;
import std.container;
import std.conv;
import std.file;
import std.path;
import std.stdio;

import glib.Util;

import sdlang;

import gtk.util;

import util.mixins.singleton;

/**
 * This class saves and loads configuration data for
 * the app to an SDL file. The code here is pretty horrific,
 * in Java I'd probably use automated class serialization driven
 * by annotations approach. Need to figure out the besy way to do
 * this in D.
 */
class Configuration {

	mixin Singleton;

private:

	immutable int MAXIMUM_ENTRIES = 20;

	immutable string CONFIG_FILE_NAME = "vgrep.sdl";
	immutable string CONFIG_PATH = "vgrep";

	immutable string TAG_ELEMENT = "Element";
	immutable string TAG_MAX_MATCHES = "MaxMatches";
	immutable string TAG_PATTERNS = "Patterns";
	immutable string TAG_PATHS = "Paths";
	immutable string TAG_MASKS = "Masks";
	immutable string TAG_VGREP = "VGrep";
	immutable string TAG_WDS = "Window";

	immutable string TAG_X = "x";
	immutable string TAG_Y = "y";
	immutable string TAG_H = "h";
	immutable string TAG_W = "w";
	immutable string TAG_S = "s";

	Array!string paths;
	Array!string patterns;
	Array!string masks;

	long maxMatches = 1000;

	WindowDisplayState wds;

	string getConfig() {
		//Note root tag cannot have namespace
		Tag config = new Tag(null, TAG_VGREP);

		saveArray(config, TAG_PATTERNS, patterns);
		saveArray(config, TAG_PATHS, paths);
		saveArray(config, TAG_MASKS, masks);

		//Save Max Matches
		new Tag(config, null, TAG_MAX_MATCHES, [Value(maxMatches)]);

		Tag mainWindow = new Tag(config, null, TAG_WDS);
		saveWindow(mainWindow, wds);

		return config.toSDLDocument();
	}

	void saveWindow(Tag main, WindowDisplayState value) {
		new Tag(main, null, TAG_X, [Value(value.x)]);
		new Tag(main, null, TAG_Y, [Value(value.y)]);
		new Tag(main, null, TAG_W, [Value(value.w)]);
		new Tag(main, null, TAG_H, [Value(value.h)]);
		new Tag(main, null, TAG_S, [Value(cast(int)(value.s))]);
	}

	void loadWindow(Tag main) {
		wds.x = main.tags[TAG_X][0].values[0].get!int();
		wds.y = main.tags[TAG_Y][0].values[0].get!int();
		wds.w = main.tags[TAG_W][0].values[0].get!int();
		wds.h = main.tags[TAG_H][0].values[0].get!int();
		wds.s = cast(WindowState) main.tags[TAG_S][0].values[0].get!int();
	}

	Tag saveArray(Tag parent, string name, Array!string values) {
		Tag result = new Tag(parent, null, name);
		//new Tag(result, null, "Length", [Value(to!int(values.length))]);
		int count = 0;
		foreach(string value; values) {
			count++;
			new Tag(result, null, TAG_ELEMENT, [Value(value)]);
		}
		return result;
	}

	Array!string loadArray(Tag tag) {
		Array!string result;
		if (TAG_ELEMENT in tag.tags) {
			foreach(Tag child; tag.tags[TAG_ELEMENT]) {
				string value = child.values[0].get!string();
				result.insertBack(value);
			}
		}
		return result;
	}

	
	void setConfig(string sdl) {
		Tag root = parseSource(sdl);
		if (TAG_PATTERNS in root.tags) {
			patterns = loadArray(root.tags[TAG_PATTERNS][0]);
		}
		if (TAG_PATHS in root.tags) {
			paths = loadArray(root.tags[TAG_PATHS][0]);
		}
		if (TAG_MASKS in root.tags) {
			masks = loadArray(root.tags[TAG_MASKS][0]);
		}
		if (TAG_MAX_MATCHES in root.tags) {
			maxMatches = root.tags[TAG_MAX_MATCHES][0].values[0].get!long();
		}
		if (TAG_WDS in root.tags) {
			loadWindow(root.tags[TAG_WDS][0]);
		}

	}

	void addValue(ref Array!string values, string value) {
		if (values[].find(value).length>0) {
			values.linearRemove(values[].find(value)[0..1]);
			values.insertBefore(values[0..0], value);
		} else {
			values.insertBefore(values[0..0], value);
			if (values.length > MAXIMUM_ENTRIES) {
				values.removeBack();
			}
		}
	}

public:

	@property string config() {
		return getConfig();
	}

	@property void config(string sdl) {
		setConfig(sdl);
	}

	@property ulong maximumMatches() {
		return maxMatches;
	}

	@property void maximumMatches(ulong value) {
		maxMatches = value;
	}

	@property WindowDisplayState mainWindow() {
		return wds;
	}

	@property void mainWindow(WindowDisplayState value) {
		wds = value;
	}

	void addPath(string path) {
		addValue(paths, path);
	}

	Array!string getPaths() {
		return paths;
	}

	void addPattern(string pattern) {
		addValue(patterns, pattern);
	}
	
	Array!string getPatterns() {
		return patterns;
	}

	void addMasks(string mask) {
		addValue(masks, mask);
	}
	
	Array!string getMasks() {
		return masks;
	}

	void saveConfig() {
		string path = chainPath(Util.getUserConfigDir, CONFIG_PATH).array;
		mkdirRecurse(path);
		File f = File(chainPath(path, CONFIG_FILE_NAME),"w");
		f.write(Configuration.instance.config);
		f.close();
	}
	
	void loadConfig() {
		auto filename = chainPath(Util.getUserConfigDir,CONFIG_PATH,CONFIG_FILE_NAME);
		if (exists(filename)) {
			Configuration.instance.config = readText(filename);
		}
	}
}