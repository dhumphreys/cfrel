<cffunction name="loadCache" returntype="any" access="public">
	<cfargument name="cacheName" type="any" required="true" hint="string">
	<cfargument name="key" type="any" required="true">
	<cfscript>
		// load from cache
		var cacheEntry = Application.cfrel.cache[arguments.cacheName].get(arguments.key);

		// log the hit for future LFU/LRU determination
		cacheEntry.accessHistory.offer(request.cfrel.startTime);

		return cacheEntry.data;
	</cfscript>
</cffunction>

<cffunction name="saveCache" returntype="void" access="public">
	<cfargument name="cacheName" type="any" required="true" hint="string">
	<cfargument name="key" type="any" required="true">
	<cfargument name="cacheData" type="any" required="false">
	<cfscript>
		// setup entry to be saved
		var cacheEntry = {data=arguments.cacheData, accessHistory=Application.cfrel.javaProxies.concurrentLinkedQueue.init()};

		// save to cache
		Application.cfrel.cache[arguments.cacheName].put(arguments.key, cacheEntry);

	</cfscript>
</cffunction>

<cffunction name="inCache" returntype="any" access="public" hint="Returns true if the specified key is in the cache and false otherwise.">
	<cfargument name="cacheName" type="any" required="true" hint="string">
	<cfargument name="key" type="any" required="true">
	<cfscript>
		// get the boolean specifying whether the cache contains the key
		var returnVal = Application.cfrel.cache[arguments.cacheName].containsKey(arguments.key);

		return returnVal;
	</cfscript>
</cffunction>

<cffunction name="noCache" returntype="any" access="public">
	<cfscript>
		variables.allowCaching = false;
		variables.cacheSql = false;
		variables.cacheMap = false;
		variables.cacheParse = false;
		return this;
	</cfscript>
</cffunction>