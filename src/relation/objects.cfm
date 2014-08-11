<cffunction name="get" returntype="any" access="public" hint="Get object by index, or false if no record">
	<cfargument name="index" type="numeric" default="#this.currentRow()#" />
	<cfargument name="format" type="string" default="object" hint="Format of record to be returned: struct or object" />
	<cfargument name="flat" type="boolean" required="false" />
	<cfargument name="deep" type="boolean" required="false" />
	<cfscript>
		if (arguments.index LT 0 OR arguments.index GT recordCount())
			return false;
		switch (arguments.format) {
			case "struct":
				return struct(argumentCollection=arguments);
				break;
			case "object":
				return object(argumentCollection=arguments);
				break;
		}
		return false;
	</cfscript>
</cffunction>

<cffunction name="first" returntype="any" access="public" hint="Get current object, or false if no records">
	<cfargument name="format" type="string" default="object" hint="Format of record to be returned: struct or object" />
	<cfargument name="flat" type="boolean" required="false" />
	<cfargument name="deep" type="boolean" required="false" />
	<cfreturn get(index=1, argumentCollection=arguments) />
</cffunction>

<cffunction name="last" returntype="any" access="public" hint="Get current object, or false if no records">
	<cfargument name="format" type="string" default="object" hint="Format of record to be returned: struct or object" />
	<cfargument name="flat" type="boolean" required="false" />
	<cfargument name="deep" type="boolean" required="false" />
	<cfreturn get(index=recordCount(), argumentCollection=arguments) />
</cffunction>

<cffunction name="all" returntype="array" access="public" hint="Get all objects">
	<cfargument name="format" type="string" default="objects" hint="Format of record to be returned: structs or objects" />
	<cfscript>
		switch (arguments.format) {
			case "structs":
				return structs(argumentCollection=arguments);
				break;
			case "objects":
				return objects(argumentCollection=arguments);
				break;
		}
		return ArrayNew(1);
	</cfscript>
</cffunction>

<cffunction name="struct" returntype="any" access="public" hint="Return struct representation of current query row">
	<cfargument name="index" type="numeric" default="#this.currentRow()#" />
	<cfargument name="flat" type="boolean" required="false" />
	<cfargument name="deep" type="boolean" required="false" />
	<cfscript>
		var loc = {};
		if (arguments.index LT 1 OR arguments.index GT recordCount())
			return false;
		_buildStructCache(argumentCollection=arguments);
		loc.cacheName = _getCacheName(name="structs", argumentCollection=arguments);
		if (ArrayLen(variables.cache[loc.cacheName]) LT arguments.index OR NOT ArrayIsDefined(variables.cache[loc.cacheName], arguments.index)) {
			loc.obj = buildBasicStruct(query=this.query(), argumentCollection=arguments);
			ArraySet(variables.cache[loc.cacheName], arguments.index, arguments.index, loc.obj);
		}
		return variables.cache[loc.cacheName][arguments.index];
	</cfscript>
</cffunction>

<cffunction name="structs" returntype="array" access="public" hint="Return struct representation of entire query recordset">
	<cfargument name="flat" type="boolean" required="false" />
	<cfargument name="deep" type="boolean" required="false" />
	<cfscript>
		var loc = {};
		loc.iEnd = recordCount();
		if (loc.iEnd EQ 0)
			return [];
		for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
			struct(index=loc.i, argumentCollection=arguments);
		return variables.cache[_getCacheName(name="structs", argumentCollection=arguments)];
	</cfscript>
</cffunction>

<cffunction name="object" returntype="any" access="public" hint="Return object representation of current query row">
	<cfargument name="index" type="numeric" default="#this.currentRow()#" />
	<cfargument name="flat" type="boolean" required="false" />
	<cfargument name="deep" type="boolean" required="false" />
	<cfscript>
		var loc = {};
		if (arguments.index LT 1 OR arguments.index GT recordCount())
			return false;
		_buildObjectCache(argumentCollection=arguments);
		loc.cacheName = _getCacheName(name="objects", argumentCollection=arguments);
		if (ArrayLen(variables.cache[loc.cacheName]) LT arguments.index OR NOT ArrayIsDefined(variables.cache[loc.cacheName], arguments.index)) {
			loc.obj = buildBasicObject(query=this.query(), argumentCollection=arguments);
			ArraySet(variables.cache[loc.cacheName], arguments.index, arguments.index, loc.obj);
		}
		return variables.cache[loc.cacheName][arguments.index];
	</cfscript>
</cffunction>

<cffunction name="objects" returntype="array" access="public" hint="Return object representation of entire query recordset">
	<cfargument name="flat" type="boolean" required="false" />
	<cfargument name="deep" type="boolean" required="false" />
	<cfscript>
		var loc = {};
		loc.iEnd = recordCount();
		if (loc.iEnd EQ 0)
			return [];
		for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
			object(index=loc.i, argumentCollection=arguments);
		return variables.cache[_getCacheName(name="objects", argumentCollection=arguments)];
	</cfscript>
</cffunction>

<cffunction name="buildBasicStruct" returntype="struct" access="public">
	<cfargument name="query" type="query" required="true" />
	<cfargument name="index" type="numeric" default="#arguments.query.currentRow#" />
	<cfscript>
		var loc = {};
		loc.returnVal = {};
		loc.columns = ListToArray(arguments.query.columnList);
		loc.iEnd = ArrayLen(loc.columns);
		for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
			loc.returnVal[loc.columns[loc.i]] = arguments.query[loc.columns[loc.i]][arguments.index];
		return loc.returnVal;
	</cfscript>
</cffunction>

<cffunction name="buildBasicObject" returntype="struct" access="public">
	<cfargument name="query" type="query" required="true" />
	<cfargument name="index" type="numeric" default="#arguments.query.currentRow#" />
	<cfscript>
		var loc = {};
		loc.returnVal = CreateObject("component", "component");
		loc.columns = ListToArray(arguments.query.columnList);
		loc.iEnd = ArrayLen(loc.columns);
		for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
			loc.returnVal[loc.columns[loc.i]] = arguments.query[loc.columns[loc.i]][arguments.index];
		return loc.returnVal;
	</cfscript>
</cffunction>
