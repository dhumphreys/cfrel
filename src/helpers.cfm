<!----------------------
--- Helper Functions ---
----------------------->

<cffunction name="relation" returntype="struct" access="private" hint="Created a new Relation instance">
	<cfreturn CreateObject("component", addCfcPrefix("cfrel.Relation")).init(argumentCollection=arguments) />
</cffunction>

<cffunction name="throwException" returntype="void" access="private" hint="Throw an exception with CFTHROW">
	<cfargument name="message" type="string" required="true" />
	<cfargument name="type" type="string" default="custom_type" />
	<cfargument name="detail" type="string" default="#arguments.message#" />
	<cfthrow attributeCollection="#arguments#" />
</cffunction>

<cffunction name="typeOf" returntype="string" access="private" hint="Return type of object as a string">
	<cfargument name="obj" type="any" required="true" />
	<cfscript>
		var loc = {};
		loc.meta = getMetaData(arguments.obj);
		
		// if the argument is a component/object, return its path
		if (IsArray(loc.meta) EQ false AND StructKeyExists(loc.meta, "fullname"))
			if (REFindNoCase("^models\.", loc.meta.fullname) EQ 0)
				return stripCfcPrefix(loc.meta.fullname);
			else
				return "model";
			
		// a few are easy checks
		else if (IsCustomFunction(arguments.obj))
			return "function";
		else if (IsBinary(arguments.obj))
			return "binary";
		else if (IsArray(arguments.obj))
			return "array";
		else if (IsQuery(arguments.obj))
			return "query";
		// this function requires a value for arguments.obj so we could never return null	
		// else if (!StructKeyExists(arguments, "obj"))
		// 	return "null";
				
		// some will just be structs, but nodes will have $class set
		else if (IsStruct(arguments.obj))
			return StructKeyExists(arguments.obj, "$class") ? arguments.obj.$class : "struct";
			
		// everything else is a simple value
		else
			return "simple";
	</cfscript>
</cffunction>

<cffunction name="addCfcPrefix" returntype="string" access="private" hint="Prepend CFC prefix to path">
	<cfargument name="path" type="string" required="true">
	<cfscript>
		if (IsDefined("application.cfrel.cfcPrefix"))
			arguments.path = REReplace(arguments.path, "^cfrel", application.cfrel.cfcPrefix);
	</cfscript>
	<cfreturn arguments.path />
</cffunction>

<cffunction name="stripCfcPrefix" returntype="string" access="private" hint="Remove CFC prefix from path">
	<cfargument name="path" type="string" required="true">
	<cfscript>
		if (IsDefined("application.cfrel.cfcPrefix"))
			arguments.path = REReplace(arguments.path, "^" & application.cfrel.cfcPrefix, "cfrel");
	</cfscript>
	<cfreturn arguments.path />
</cffunction>

<cffunction name="javaHash" returntype="any" access="private" hint="Return an ordered Java hash map">
	<cfreturn CreateObject("java", "java.util.LinkedHashMap").init() />
</cffunction>

<cffunction name="uniqueScopeKey" returntype="string" access="private" hint="Create a unique, meaningful key for a certain scope">
	<cfargument name="key" type="string" required="true" />
	<cfargument name="prefix" type="string" default="" />
	<cfargument name="scope" type="struct" required="true" />
	<cfscript>
		var loc = {};
		loc.key = arguments.key;
				
		// if key already used, try prepending a prefix
		if (StructKeyExists(arguments.scope, loc.key) AND Len(arguments.prefix))
			loc.key = arguments.key = arguments.prefix & arguments.key;
			
		// if key still conflicts, start appending numbers
		for (loc.j = 1; StructKeyExists(arguments.scope, loc.key); loc.j++)
			loc.key = arguments.key & loc.j;
		
		return loc.key;
	</cfscript>
</cffunction>

<cffunction name="sqlArrayToString" returntype="string" access="private" hint="Turn SQL tree into a string">
	<cfargument name="sql" type="array" required="true" />
	<cfscript>
		var loc = {};
		loc.sql = "";
		loc.prev = "";
		loc.iEnd = ArrayLen(arguments.sql);
		for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
			loc.rtn = arguments.sql[loc.i];
			if (IsStruct(loc.rtn))
				loc.rtn = "?";
			if (loc.sql NEQ "" AND (NOT REFind("(\(|\.)$", loc.prev) AND NOT REFind("^(,|\.(\D|$)|\))", Left(loc.rtn, 2))))
				loc.rtn = " " & loc.rtn;
			loc.sql &= loc.rtn;
			loc.prev = loc.rtn;
		}
		return loc.sql;
	</cfscript>
</cffunction>

<cffunction name="flattenArray" returntype="array" access="private" hint="Turn deep array into a flat one">
	<cfargument name="array" type="any" required="true" />
	<cfargument name="accumulator" type="array" default="#ArrayNew(1)#" />
	<cfscript>
		var loc = {};
		if (NOT IsArray(arguments.array))
			return [arguments.array];
		loc.iEnd = ArrayLen(arguments.array);
		for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
			if (IsArray(arguments.array[loc.i]))
				arguments.accumulator = flattenArray(arguments.array[loc.i], arguments.accumulator);
			else
				ArrayAppend(arguments.accumulator, arguments.array[loc.i]);
		}
		return arguments.accumulator;
	</cfscript>
</cffunction>

<cffunction name="separateArray" returntype="array" access="private" hint="Add a delimeter between array elements">
	<cfargument name="array" type="any" required="true" />
	<cfargument name="delim" type="string" default="," />
	<cfscript>
		var loc = {};
		if (NOT IsArray(arguments.array))
			return [arguments.array];
		loc.iEnd = ArrayLen(arguments.array) - 1;
		for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
			ArrayInsertAt(arguments.array, loc.i * 2, arguments.delim);
		return arguments.array;
	</cfscript>
</cffunction>
