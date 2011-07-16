<cffunction name="struct" returntype="struct" access="public" hint="Return struct representation of current query row">
	<cfargument name="index" type="numeric" default="#this.currentRow()#" />
	<cfscript>
		_buildStructCache();
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

<cffunction name="object" returntype="struct" access="public" hint="Return object representation of current query row">
	<cfargument name="index" type="numeric" default="#this.currentRow()#" />
	<cfscript>
		_buildObjectCache();
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
