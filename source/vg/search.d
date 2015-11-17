/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module vg.search;

import core.time;
import core.thread;

import std.concurrency;
import std.experimental.logger;
import std.parallelism;

import util.file.search;

alias ResultDelegate = bool delegate(string id, Result result);
alias ProgressDelegate = bool delegate(string id, string path);
alias FinishedDelegate = void delegate(string id, bool aborted, ulong total);

/**
 * SearchManager manages a set of individual search requests, it basically
 * allows multiple file searches to happen concurrently in individual threads
 */
class SearchManager {

private:

	SearchRequest[string] requests;
	ProgressDelegate cbProgress;
	ResultDelegate cbResult;
	FinishedDelegate cbFinished;

public:

	this() {
	}

	void search(Criteria criteria, MarkupTags markup) {
		SearchRequest request = new SearchRequest(criteria, markup);
		requests[criteria.id] = request;
		request.search();
	}

	@property ulong count() {
		return requests.length;
	}

	void stopAll() {
		foreach(SearchRequest request; requests) {
			request.stopSearch();
		}
	}

	void stop(string id) {
		if (id in requests) {
			SearchRequest request = requests[id];
			request.stopSearch();
		}
	}

	bool checkPending(ulong wait) {
		//writeln("Checking messages...");
		try {
			receiveTimeout(dur!("msecs")( wait ), 
				(Status s, string id, ulong total) {
					trace(id, ": Received completed message");
					if (id in requests) {
						SearchRequest request = requests[id];
						if (request !is null && cbFinished !is null) {
							requests.remove(id);
							cbFinished(id, (s==Status.ABORTED), total);
						}
					} else {
						error(id, " :Failed to get request for id");
					}
				},

				(Status s, string id, shared Result result) {
					if (cbResult !is null) {
						//Have to cast here otherwise the delegate must be shared and it just leaks everywhere
						//not optimal solution, works around D's annoying limitation of not being able to 
						//pass immutable via send/receive
						cbResult(id, cast(Result) result);
					}
					trace(id, ": Received result ", result.file);
				},
				(Status s, string id, string path) {
					trace(id, ": Received progress ", path);
					if (cbProgress !is null) {
						cbProgress(id, path);
					}
				}
				);
		} catch (Throwable t) {
			error("Unexpected exception ", t.msg);
		}

		return requests.length>0;

	}

	@property void onProgress(ProgressDelegate progress) {
		this.cbProgress = progress;
	};

	@property void onFinished(FinishedDelegate finished) {
		this.cbFinished = finished;
	}

	@property void onResult(ResultDelegate result) {
		this.cbResult = result;
	}

	bool isSearchInProgress(string id) {
		if (id in requests) return true;
		else return false;
	}
}

/**
 * Represents an individual search request 
 */
class SearchRequest {

private:
	Criteria criteria;
	MarkupTags markup;
	Tid tid;

public:

	this(Criteria criteria, MarkupTags markup) {
		this.criteria = criteria;
		this.markup = markup;
	}

public:

	void search() {
		trace("Putting search task in taskPool");
		tid = spawn(&util.file.search.search, criteria, markup, thisTid);
	}

	void stopSearch() {
		tid.send(ABORT_MESSAGE);
	}
}

