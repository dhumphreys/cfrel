<cffunction name="get" returntype="any" access="public" hint="Get object by index, or false if no record">
	<cfargument name="index" type="numeric" default="#this.currentRow()#" />
	<cfargument name="format" type="string" default="object" hint="Format of record to be returned: struct or object" />
	<cfscript>
		if (arguments.index LT 0 OR arguments.index GT recordCount())
			return false;
		switch (arguments.format) {
			case "struct":
				return struct(arguments.index);
				break;
			case "object":
				return object(arguments.index);
				break;
		}
		return false;
	</cfscript>
</cffunction>

<cffunction name="first" returntype="any" access="public" hint="Get current object, or false if no records">
	<cfargument name="format" type="string" default="object" hint="Format of record to be returned: struct or object" />
	<cfreturn get(index=1, format=arguments.format) />
</cffunction>

<cffunction name="last" returntype="any" access="public" hint="Get current object, or false if no records">
	<cfargument name="format" type="string" default="object" hint="Format of record to be returned: struct or object" />
	<cfreturn get(index=recordCount(), format=arguments.format) />
</cffunction>

<cffunction name="all" returntype="array" access="public" hint="Get all objects">
	<cfargument name="format" type="string" default="objects" hint="Format of record to be returned: structs or objects" />
	<cfscript>
		switch (arguments.format) {
			case "structs":
				return structs();
				break;
			case "objects":
				return objects();
				break;
		}
		return ArrayNew(1);
	</cfscript>
</cffunction>

<cffunction name="struct" returntype="any" access="public" hint="Return struct representation of current query row">
	<cfargument name="index" type="numeric" default="#this.currentRow()#" />
	<cfscript>
		_buildStructCache();
		if (arguments.index LT 1 OR arguments.index GT recordCount())
			return false;
		if (ArrayLen(variables.cache.structs) LT arguments.index OR NOT ArrayIsDefined(variables.cache.structs, arguments.index)) {
			var obj = this.mapper.queryRowToStruct(this.query(), arguments.index, this.model);
			ArraySet(variables.cache.structs, arguments.index, arguments.index, obj);
		}
		return variables.cache.structs[arguments.index];
	</cfscript>
</cffunction>

<cffunction name="structs" returntype="array" access="public" hint="Return struct representation of entire query recordset">
	<cfscript>
		var loc = {};
		_buildStructCache();
		loc.iEnd = recordCount();
		for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
			struct(loc.i);
		return variables.cache.structs;
	</cfscript>
</cffunction>

<cffunction name="object" returntype="any" access="public" hint="Return object representation of current query row">
	<cfargument name="index" type="numeric" default="#this.currentRow()#" />
	<cfscript>
		_buildObjectCache();
		if (arguments.index LT 1 OR arguments.index GT recordCount())
			return false;
		if (ArrayLen(variables.cache.objects) LT arguments.index OR NOT ArrayIsDefined(variables.cache.objects, arguments.index)) {
			var obj = this.mapper.structToObject(struct(arguments.index), this.model);
			ArraySet(variables.cache.objects, arguments.index, arguments.index, obj);
		}
		return variables.cache.objects[arguments.index];
	</cfscript>
</cffunction>

<cffunction name="objects" returntype="array" access="public" hint="Return object representation of entire query recordset">
	<cfscript>
		var loc = {};
		_buildObjectCache();
		loc.iEnd = recordCount();
		for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
			object(loc.i);
		return variables.cache.objects;
	</cfscript>
</cffunction>
