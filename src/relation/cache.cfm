<cffunction name="clearCache" returntype="void" access="public" hint="Clear query, result, struct, and object cache">
	<cfset variables.cache = {} />
</cffunction>

<cffunction name="_buildStructCache" returntype="void" access="private" hint="Build internal cache for row structs">
	<cfargument name="deep" type="boolean" default="false" />
	<cfargument name="flat" type="boolean" default="#NOT arguments.deep#" />
	<cfscript>
		var loc.cacheName = _getCacheName(name="structs", argumentCollection=arguments);
		if (NOT StructKeyExists(variables.cache, loc.cacheName))
			variables.cache[loc.cacheName] = mapper().buildStructCache(query=this.query(), model=this.model, argumentCollection=arguments);
	</cfscript>
</cffunction>

<cffunction name="_buildObjectCache" returntype="void" access="private" hint="Build internal cache for row objects">
	<cfargument name="deep" type="boolean" default="true" />
	<cfargument name="flat" type="boolean" default="false" />
	<cfscript>
		var loc.cacheName = _getCacheName(name="objects", argumentCollection=arguments);
		if (NOT StructKeyExists(variables.cache, loc.cacheName))
			variables.cache[loc.cacheName] = mapper().buildObjectCache(query=this.query(), model=this.model, argumentCollection=arguments);
	</cfscript>
</cffunction>

<cffunction name="_getCacheName" returntype="string" access="private" hint="Determine name of cache variable to use">
	<cfargument name="name" type="string" required="true" />
	<cfargument name="deep" type="boolean" default="#arguments.name EQ 'objects'#" />
	<cfargument name="flat" type="boolean" default="#NOT arguments.deep AND arguments.name EQ 'structs'#" />
	<cfreturn (arguments.flat ? "flat" : (arguments.deep ? "deep" : "")) & arguments.name />
</cffunction>