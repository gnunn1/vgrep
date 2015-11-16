/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gtk.threads;

import gdk.Threads;

import std.algorithm;
import std.stdio;

 /**
  * Simple structure that contains a pointer to a delegate. This is necessary because delegates are not directly
  * convertable to a simple pointer (which is needed to pass as data to a C callback).
  * 
  * This code from grestful (https://github.com/Gert-dev/grestful)
  */
 struct DelegatePointer(S, U...)
 {
     S delegateInstance;

     U parameters;

     /**
      * Constructor.
      *
      * @param delegateInstance The delegate to invoke.
      * @param parameters       The parameters to pass to the delegate.
      */
     public this(S delegateInstance, U parameters)
     {
         this.delegateInstance = delegateInstance;
         this.parameters = parameters;
     }
 }

 /**
  * Callback that will invoke the passed DelegatePointer's delegate when it is called. This very useful method can be
  * used to pass delegates to gdk.Threads.threadsAddIdle instead of having to define a callback with C linkage and a
  * different method for every different action.
  * 
  * This code from grestful (https://github.com/Gert-dev/grestful), one change to return true by default and false on exception
  *
  * @param data The data that is passed to the method.
  *
  * @return Whether or not the method should continue executing.
  */
 extern(C) nothrow static bool invokeDelegatePointerFunc(S)(void* data)
 {
     try
     {
        auto callbackPointer = cast(S*) data;

    	callbackPointer.delegateInstance(callbackPointer.parameters);
	}
     catch (Exception e)
     {
		auto callbackPointer = cast(S*) data;

		//Remove DelegatePointer struct from reference holder
		for (int i=0; i<activeCallbacks.length; i++) { 
			if (activeCallbacks[i]==callbackPointer) {
				remove(activeCallbacks, i);
				break;
			}
		}
		return false;
     }

     return true;
 }

/**
 * Convenience method that allows scheduling a delegate to be executed with gdk.Threads.threadsAddIdle instead of a
 * traditional callback with C linkage.
 *
 * @param theDelegate The delegate to schedule.
 * @param parameters  A tuple of parameters to pass to the delegate when it is invoked.
 *
 * @example
 *     auto myMethod = delegate(string name, string value) { do_something_with_name_and_value(); }
 *     threadsAddIdleDelegate(myMethod, "thisIsAName", "thisIsAValue");
 */
void threadsAddIdleDelegate(T, parameterTuple...)(T theDelegate, parameterTuple parameters)
{
	auto dp = new DelegatePointer!(T, parameterTuple)(theDelegate, parameters);
	//Need to maintain a reference so D doesn't GC it
	activeCallbacks ~= dp;

	gdk.Threads.threadsAddIdle(
		cast(GSourceFunc) &invokeDelegatePointerFunc!(DelegatePointer!(T, parameterTuple)),
		cast(void*) dp
		);
}

DelegatePointer!(void delegate())*[] activeCallbacks;
