/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module util.file.search;

import core.time;

import std.algorithm;
import std.array;
import std.concurrency;
import std.conv;
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

	/**
	 * Maximum number of matches to capture. The search routine will still
	 * count matches over this number but only the number of matches up to
	 * this number will be returned.
	 */
	ulong maximumMatches;
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
	/**
	 * The file name for which matches were found
	 */
	string file;

	/**
	 * An array of matches found up to the maximum number
	 * specified in the Criteria
	 */
	Match[] matches;

	/**
	 * The total number of matches found, this can be greater
	 * then the number of matches returned in the matches array
	 * if the maximum number of matches was exceeded.
	 */
	ulong matchCount;
}

enum Status {PROGRESS_PATH, PROGRESS_RESULT, COMPLETED, ABORTED};

immutable string ABORT_MESSAGE = "abort";

void search(Criteria criteria, MarkupTags markup, Tid tid) {

	trace(criteria.id, ": Starting search");
	bool abort = false;

	char[] flags;
	if (criteria.caseInsensitive) flags ~='i';
	auto r = regex(criteria.pattern, flags);

	ulong lastProgress = 0;
	string lastPath;
	string currentPath = null;

	SpanMode mode = (criteria.searchSubdirectories?SpanMode.depth:SpanMode.shallow);

	string wildcard = criteria.wildcardPattern;
	if (wildcard.length==0) wildcard = "*";

	ulong totalMatchCount = 0;

	foreach (DirEntry entry; dirEntries(criteria.path, wildcard, mode, criteria.followSymbolic).filter!(a => a.isFile)) {
		info("Searching file ", entry.name);
		char[] buf;
		string path = dirName(entry.name);
		if (!path.equal(currentPath)) {
			currentPath = path;
			tid.send(Status.PROGRESS_PATH, criteria.id, currentPath);
		}
		auto f = File(entry.name,"r");
		ulong lineCount = 1;
		ulong matchCount = 0;
		shared Match[] matches;
		while (f.readln(buf)) {
			string line;
			foreach (m; matchAll(buf,r)) {
				if (matchCount < criteria.maximumMatches) {
					if (line.length==0) line ~= chomp(buf);
					if (markup.pangoMarkup) {
						line = chomp(escapeText(to!string(m.pre())) ~ markup.pre ~ escapeText(to!string(m.hit())) ~ markup.post ~ escapeText(to!string(m.post())));
					} 
					shared Match match = {line, lineCount, m.pre().length, m.pre().length + m.hit().length};
					//trace("Match at line:",match.lineNo,", start: ",match.startPos,",end: ",match.endPos);
					matches = matches ~ match;
				}
				matchCount++;
			}
			lineCount++;
			if (lineCount % 10000 == 0) {
				trace(format("Processed %d lines with %d total matches", lineCount, matches.length));
				abort = isAborted();
				if (abort) break;
			}
		}

		if (matches.length>0) {
			info("Found %d matches in %s", matchCount, entry.name);
			shared Result result = {entry.name, matches, matchCount};
			totalMatchCount = totalMatchCount + matchCount;
			tid.send(Status.PROGRESS_RESULT, criteria.id, result);

		}
		if (abort || isAborted()) {
			break;
		}
	}

	tid.send(abort?Status.ABORTED:Status.COMPLETED, criteria.id, totalMatchCount);
}

private bool isAborted() {
	bool result = false;
	receiveTimeout(dur!("msecs")( 0 ), 
		(string msg) {
			if (ABORT_MESSAGE.equal(msg)) {
				result = true;
			}
		}
	);

	return result;
}

private string escapeText(string s) {
	return SimpleXML.markupEscapeText(s, s.length);
}