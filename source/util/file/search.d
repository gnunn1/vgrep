/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module util.file.search;

import std.algorithm;
import std.array;
import std.concurrency;
import std.experimental.logger;
import std.file;
import std.path;
import std.regex;
import std.stdio;
import std.string;
import std.uuid;

import glib.SimpleXML;

/**
 * The criteria to search
 */
struct Criteria {

	/**
	 * Unique id used to identify this search
	 */
	string id;

	/**
	 * Pattern to search files for 
 	 */
	string pattern;

	/**
	 * Whether the search is case sensitive 
	 */
	bool caseInsensitive = false;

	/**
	 * Path within to search 
	 */
	string path;

	/**
	 * Wildcard pattern to optionally match files to
	 */
	string wildcardPattern;

	/**
	 * Include subdirectories in search
	 */
	bool searchSubdirectories;

	/**
	 * Follow symbolic links
	 */
	bool followSymbolic;
}

struct MarkupTags {

	bool pangoMarkup = false;

	string pre;

	string post;
}

/**
 * Represents a single match within a file
 */
struct Match {

	string line;
	ulong lineNo;
	ulong startPos;
	ulong endPos;
}

/**
 * All matches for a single file
 */
struct Result {
	string file;
	Match[] matches;
}

enum Status {PROGRESS_PATH, PROGRESS_RESULT, COMPLETED};

void search(Criteria criteria, MarkupTags markup, Tid tid) {
	trace(criteria.id, ": Starting search");
	char[] flags;

	if (criteria.caseInsensitive) flags ~='i';

	auto r = regex(criteria.pattern, flags);

	ulong lastProgress = 0;
	string lastPath;
	string currentPath = null;

	SpanMode mode = (criteria.searchSubdirectories?SpanMode.depth:SpanMode.shallow);

	string wildcard = criteria.wildcardPattern;
	if (wildcard.length==0) wildcard = "*";

	ulong matchCount = 0;

	foreach (DirEntry entry; dirEntries(criteria.path, wildcard, mode, criteria.followSymbolic).filter!(a => a.isFile)) {
		string path = dirName(entry.name);
		if (!path.equal(currentPath)) {
			currentPath = path;
			tid.send(Status.PROGRESS_PATH, criteria.id, currentPath);
		}
		auto f = File(entry.name,"r");
		string line;
		ulong count = 1;
		shared Match[] matches;
		while ((line = f.readln()) !is null) {
			foreach (m; matchAll(line,r)) {
				if (markup.pangoMarkup) {
					line = chomp(escapeText(m.pre()) ~ markup.pre ~ escapeText(m.hit()) ~ markup.post ~ escapeText(m.post()));
				} else {
					line = chomp(line);
				}
				shared Match match = {line, count, m.pre().length, m.pre().length + m.hit().length};
				trace("Match at line:",match.lineNo,", start: ",match.startPos,",end: ",match.endPos);
				matches = matches ~ match;
			}
			count++;
		}

		if (matches.length>0) {
			shared Result result = {entry.name, matches};
			matchCount = matchCount + matches.length;
			tid.send(Status.PROGRESS_RESULT, criteria.id, result);

		}
	}
	tid.send(Status.COMPLETED, criteria.id, matchCount);
}

private string escapeText(string s) {
	return SimpleXML.markupEscapeText(s, s.length);
}