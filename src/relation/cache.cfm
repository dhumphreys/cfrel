<cffunction name="clearCache" returntype="void" access="public" hint="Clear query, result, struct, and object cache">
	<cfset variables.cache = {} />
</cffunction>

<cffunction name="_buildStructCache" returntype="void" access="private" hint="Build internal cache for row structs">
	<cfargument name="deep" type="boolean" default="false" />
	<cfargument name="flat" type="boolean" default="#NOT arguments.deep#" />
	<cfscript>
		var loc.cacheName = _getCacheName(name="structs", argumentCollection=arguments);
		if (NOT StructKeyExists(variables.cache, loc.cacheName))
			variables.cache[loc.cacheName] = buildStructCache(query=this.query(), argumentCollection=arguments);
	</cfscript>
</cffunction>

<cffunction name="_buildObjectCache" returntype="void" access="private" hint="Build internal cache for row objects">
	<cfargument name="deep" type="boolean" default="true" />
	<cfargument name="flat" type="boolean" default="false" />
	<cfscript>
		var loc.cacheName = _getCacheName(name="objects", argumentCollection=arguments);
		if (NOT StructKeyExists(variables.cache, loc.cacheName))
			variables.cache[loc.cacheName] = buildObjectCache(query=this.query(), argumentCollection=arguments);
	</cfscript>
</cffunction>

<cffunction name="_getCacheName" returntype="string" access="private" hint="Determine name of cache variable to use">
	<cfargument name="name" type="string" required="true" />
	<cfargument name="deep" type="boolean" default="#arguments.name EQ 'objects'#" />
	<cfargument name="flat" type="boolean" default="#NOT arguments.deep AND arguments.name EQ 'structs'#" />
	<cfreturn (arguments.flat ? "flat" : (arguments.deep ? "deep" : "")) & arguments.name />
</cffunction>

<cffunction name="buildStructCache" returntype="array" access="public">
	<cfargument name="query" type="query" required="true" />
	<cfargument name="deep" type="boolean" default="false" />
	<cfargument name="flat" type="boolean" default="#NOT arguments.deep#" />
	<cfscript>
		if (this.model NEQ false AND NOT arguments.flat)
			return mapper().model(this.model).$serializeQueryToStructs(arguments.query, includeString(), false, arguments.deep);
		return ArrayNew(1);
	</cfscript>
</cffunction>

<cffunction name="buildObjectCache" returntype="array" access="public">
	<cfargument name="query" type="query" required="true" />
	<cfargument name="deep" type="boolean" default="true" />
	<cfargument name="flat" type="boolean" default="false" />
	<cfscript>
		var loc = {};
		if (this.model NEQ false) {
			loc.array = mapper().model(this.model).$serializeQueryToObjects(arguments.query, includeString(), false, arguments.deep AND NOT arguments.flat);
			if (arguments.flat) {
				loc.iEnd = ArrayLen(loc.array);
				for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
					loc.array[loc.i].setProperties(buildBasicStruct(arguments.query, loc.i));
			}
			return loc.array;
		}
		return ArrayNew(1);
	</cfscript>
</cffunction>