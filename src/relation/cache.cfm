<cffunction name="clearCache" returntype="void" access="public" hint="Clear query, result, struct, and object cache">
	<cfset variables.cache = {} />
</cffunction>

<cffunction name="_buildStructCache" returntype="void" access="private" hint="Build internal cache for row structs">
	<cfscript>
		if (NOT StructKeyExists(variables.cache, "structs"))
			variables.cache.structs = this.mapper.buildStructCache(this.query(), this.model);
	</cfscript>
</cffunction>

<cffunction name="_buildObjectCache" returntype="void" access="private" hint="Build internal cache for row objects">
	<cfscript>
		if (NOT StructKeyExists(variables.cache, "objects"))
			variables.cache.objects = this.mapper.buildObjectCache(this.query(), this.model);
	</cfscript>
</cffunction>
