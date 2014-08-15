<cffunction name="sampleCacheEntrySize" returntype="numeric" access="public">
	<cfargument name="cacheName" type="string" required="true">
	<cfscript>
		var cache = Application.cfrel.cache[arguments.cacheName];
		
		if (StructIsEmpty(cache))
			return 0;

		var cacheKeys = StructKeyArray(cache);

		var sampleEntryKey = cacheKeys[RandRange(1, ArrayLen(cacheKeys))];
		var sampleEntryValue = cache.get(sampleEntryKey);
		var bytes = sizeOf(sampleEntryKey) + sizeOf(sampleEntryValue);

		Application.cfrel.cacheSizeSamples[arguments.cacheName].offer(bytes);

		var cacheSizeSamplesArray = CreateObject("java", "java.util.ArrayList").init(Application.cfrel.cacheSizeSamples[arguments.cacheName]);

		var avgEntrySize = ArrayAvg(cacheSizeSamplesArray);
		
		return Round(avgEntrySize);
	</cfscript>
</cffunction>

<cffunction name="collectCacheStats" returntype="any" access="private">
	<cfscript>
		var stats = {};
		stats.totals = {totalSize = 0, entryCount = 0};
		stats.entries = [];
		stats.caches = {};
		
		var arrayListProxy = CreateObject("java", "java.util.ArrayList");

		var daysOldCollection = [];
		var hitCountCollection = [];
		for (var cacheName IN Application.cfrel.cache) {
			var cache = Application.cfrel.cache[cacheName];
			
			if (StructIsEmpty(cache))
				continue;

			stats.caches[cacheName] = {};
			
			stats.caches[cacheName].entryCount = StructCount(cache);
			stats.caches[cacheName].avgEntrySize = sampleCacheEntrySize(cacheName);
			stats.caches[cacheName].totalSize = stats.caches[cacheName].entryCount * stats.caches[cacheName].avgEntrySize;
			
			stats.totals.entryCount += stats.caches[cacheName].entryCount;
			stats.totals.totalSize += stats.caches[cacheName].totalSize;

			var cacheKeys = StructKeyArray(cache);

			for (var key IN cacheKeys) {
				if (NOT cache.containsKey(key))
					continue;

				var cacheEntry = cache.get(key);

				var statEntry = {"cacheName"=cacheName, "key"=key};

				var accessHistory = cacheEntry.accessHistory;
				if (accessHistory.isEmpty()) {
					// entry has never been used
					// use special logic here to make sure it gets removed first
					statEntry.hitCount = 0;
					statEntry.daysOld = 1000000;
				} else {
					// needs to be reinitialized as an array to get its last element and count the number of elements more quickly
					var accessHistoryArray = arrayListProxy.init(accessHistory);

					statEntry.hitCount = ArrayLen(accessHistoryArray);
					statEntry.daysOld = Now() - accessHistoryArray[statEntry.hitCount];

					ArrayAppend(daysOldCollection, statEntry.daysOld);
				}

				ArrayAppend(hitCountCollection, statEntry.hitCount);
				ArrayAppend(stats.entries, statEntry);
			}
		}

		stats.totals.avgDaysOld = ArrayAvg(daysOldCollection);
		stats.totals.avgHitCount = ArrayAvg(hitCountCollection);

		return stats;
	</cfscript>
</cffunction>

<cffunction name="trimCacheByDaysOld" returntype="void" access="public" hint="Removes all entries up to (but not including) daysOldLimit days old.">
	<cfargument name="daysOldLimit" type="numeric" required="true">
	<cfscript>
		variables.daysOldLimit = arguments.daysOldLimit;
		trimCache(filterFunction = function(entry) {
			return entry.daysOld > variables.daysOldLimit;
		});
	</cfscript>
</cffunction>


<cffunction name="trimCacheLRU" returntype="void" access="public" hint="Sorts entries least recently used first. Removes entries from beginning until keepCount entries are left.">
	<cfargument name="keepCount" type="numeric" required="true">
	<cfscript>
		trimCache(keepCount=arguments.keepCount, sortFunction = 
			function(entry1, entry2) {
				if (entry1.daysOld > entry2.daysOld)
					return -1;
				if (entry1.daysOld < entry2.daysOld)
					return 1;
				return 0;
			}
		);
	</cfscript>
</cffunction>


<cffunction name="trimCache" returntype="void" access="public" hint="Sorts and filters entry array. Removes entries from cache starting at beginning of sorted entry array until keepCount entries are left (if specified).">
	<cfargument name="keepCount" type="numeric" required="false">
	<cfargument name="filterFunction" type="function" required="false" hint="Filter the entry array down to just the entries to be removed.">
	<cfargument name="sortFunction" type="function" required="false" hint="Sort the entry array by entries to be removed first.">
	<cfscript>
		var stats = collectCacheStats();

		if (stats.totals.entryCount EQ 0) {
			WriteOutput("No entries in any cache.");
			return;
		}

		// ArrayFilter returns a new array
		if (StructKeyExists(arguments, "filterFunction"))
			stats.entries = ArrayFilter(stats.entries, arguments.filterFunction);

		// ArraySort sorts the array in place
		if (StructKeyExists(arguments, "sortFunction"))
			ArraySort(stats.entries, arguments.sortFunction);

		// get normalized counts (avg entry size / total average entry size)
		var normalizedTotalCount = 0;
		for (var cacheName in stats.caches) {
			var cacheSpecificStats = stats.caches[cacheName];

			cacheSpecificStats.sizePercentOfTotal = cacheSpecificStats.totalSize / stats.totals.totalSize;
			cacheSpecificStats.normalizedCount = Round(stats.totals.entryCount * cacheSpecificStats.sizePercentOfTotal);
			cacheSpecificStats.entryWorth = cacheSpecificStats.normalizedCount / cacheSpecificStats.entryCount;

			normalizedTotalCount += cacheSpecificStats.normalizedCount;
		}

		// get the number of entries to be removed
		if (NOT StructKeyExists(arguments, "keepCount"))
			arguments.keepCount = normalizedTotalCount;

		// check if entries need to be removed
		if (normalizedTotalCount < arguments.keepCount) {
			WriteOutput("Number of cache entries is already less than specified keepCount. (#normalizedTotalCount# < #arguments.keepCount#)");
			abort;
		}
		
		// remove entries
		var normalizedEntriesRemoved = 0;
		for (var entry IN stats.entries) {
			var entryCacheName = entry.cacheName;
			var entryWorth = stats.caches[entryCacheName].entryWorth;

			normalizedTotalCount -= entryWorth;
			normalizedEntriesRemoved += entryWorth;

			if (normalizedTotalCount <= arguments.keepCount) {
				// Don't actually remove the last entry (want to keep at least keepCount entries)
				normalizedTotalCount += entryWorth;
				normalizedEntriesRemoved -= entryWorth;
				break;
			}
			removeFromCache(entryCacheName, entry.key);
		}

		WriteOutput("Removed " & Round(normalizedEntriesRemoved) & " entries.<br>");
		WriteOutput(Round(normalizedTotalCount) & " entries left.");
		abort;

	</cfscript>
</cffunction>

<cffunction name="removeFromCache" returntype="void" access="public">
	<cfargument name="cacheName" type="string" required="true">
	<cfargument name="key" type="any" required="true">
	<cfscript>
		Application.cfrel.cache[arguments.cacheName].remove(arguments.key);
	</cfscript>
</cffunction>

<cffunction name="clearCaches" returntype="void" access="public">
	<cfscript>
		for (var cacheName in Application.cfrel.cache) {
			Application.cfrel.cache[cacheName].clear();
			Application.cfrel.cacheSizeSamples[cacheName].clear();
		}

		writeOutput("CFRel caches cleared.");
		abort;
	</cfscript>
</cffunction>

<cffunction name="getPrintableVersionOfHashMap" returntype="any" access="public">
	<cfargument name="hashMapObj" type="any" required="true" />
	<cfargument name="keysOnly" type="boolean" required="false" default="false" />
	<cfargument name="find" type="string" required="false" default="" />
	<cfargument name="toJSON" type="boolean" required="false" default="true" />
	<cfargument name="entryLimit" type="numeric" required="false" default="1000000000000" />
	<cfscript>
		if (StructIsEmpty(arguments.hashMapObj))
			return "Hashmap is empty.";

		var cacheKeys = StructKeyArray(arguments.hashMapObj);

		var outputData = [];

		var entriesUsed = 0;
		for (var key IN cacheKeys) {
			var entry = arguments.keysOnly ? key : {key=key, value=arguments.hashMapObj.get(key)};

			entry = getPrintable(entry);
			if (Len(arguments.find) > 0) {
				
				var entryText = SerializeJSON(entry);
				if (NOT FindNoCase(entryText, arguments.find))
					continue;
			}

			ArrayAppend(outputData, entry);
			entriesUsed++;

			if (entriesUsed > arguments.entryLimit)
				break;
		}

		if (arguments.toJSON)
			outputData = SerializeJSON(outputData);
		return outputData;
	</cfscript>
</cffunction>

<cffunction name="printAllCaches" returntype="void" access="public">
	<cfargument name="find" type="string" required="false" default="" />
	<cfargument name="entryLimit" type="numeric" required="false" default="100000" />
	<cfscript>
		var dumps = {};
		for (var cacheName IN Application.cfrel.cache) {

			var cache = Application.cfrel.cache[cacheName];
			dumps[cacheName] = dumpHashMap(
				hashMapObj = cache, 
				entryLimit = arguments.entryLimit,
				find = arguments.find, 
				toJSON = false
			);
		}

		WriteOutput(SerializeJSON(dumps));abort;
	</cfscript>
</cffunction>
