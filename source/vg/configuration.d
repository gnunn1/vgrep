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

import util.mixins.singleton;

class Configuration {

	mixin Singleton;

private:

	immutable int MAXIMUM_ENTRIES = 20;

	immutable string CONFIG_FILE_NAME = "vgrep.sdl";
	immutable string CONFIG_PATH = "vgrep";

	Array!string paths;
	Array!string patterns;
	Array!string masks;

	string getConfig() {
		//Note root tag cannot have namespace
		Tag config = new Tag(null,"VGrep");

		saveArray(config, "Patterns", patterns);
		saveArray(config, "Paths", paths);
		saveArray(config, "Masks", masks);http://www.webservicex.com/stockquote.asmx?WSDL

		return config.toSDLDocument();
	}

	Tag saveArray(Tag parent, string name, Array!string values) {
		Tag result = new Tag(parent, null, name);
		//new Tag(result, null, "Length", [Value(to!int(values.length))]);
		int count = 0;
		foreach(string value; values) {
			count++;
			string e = "Element";// ~ to!string(count);
			new Tag(result, null, e, [Value(value)]);
		}
		return result;
	}


	Array!string loadArray(Tag tag) {
		Array!string result;
		if ("Element" in tag.tags) {
			foreach(Tag child; tag.tags["Element"]) {
				string value = child.values[0].get!string();
				result.insertBack(value);
			}
		}
		return result;
	}

	
	void setConfig(string sdl) {
		Tag root = parseSource(sdl);
		if ("Patterns" in root.tags) {
			patterns = loadArray(root.tags["Patterns"][0]);
		}
		if ("Paths" in root.tags) {
			paths = loadArray(root.tags["Paths"][0]);
		}
		if ("Masks" in root.tags) {
			masks = loadArray(root.tags["Masks"][0]);
		}
	}

	void addValue(ref Array!string values, string value) {
		if (values[].find(value).length>0) {
			values.linearRemove(values[].find(value)[0..1]);
			values.insertBefore(values[0..0], value);
		} else {
			writeln("Inserting value ",value);
			values.insertBefore(values[0..0], value);
			writeln("Values length ", values.length);
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