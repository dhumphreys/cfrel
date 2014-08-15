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
		// NOTE: we are checking these types in order of most likely to occur (or as dictated by type conflicts)
			
		// simple string/numeric values
		if (IsSimpleValue(arguments.obj)) {
			return "simple";

		// check for binary or array data (in that order)
		} else if (IsBinary(arguments.obj)) {
			return "binary";
		} else if (IsArray(arguments.obj)) {
			return "array";

		// check for queries or custom function pointers
		} else if (IsQuery(arguments.obj)) {
			return "query";
		} else if (IsCustomFunction(arguments.obj)) {
			return "function";
			
		// if all else fails, use getMetaData() to determine if it is an object or a struct
		} else {
			var meta = getMetaData(arguments.obj);
			
			// if the argument is a component/object, return its path
			if (IsArray(meta) EQ false AND StructKeyExists(meta, "fullname")) {
				if (REFindNoCase("(^|\.)models\.", meta.fullname) EQ 0)
					return stripCfcPrefix(meta.fullname);
				else
					return "model";

			// otherwise, it is just a struct (but could be a cfrel node with $class set)
			} else {
				return StructKeyExists(arguments.obj, "$class") ? arguments.obj.$class : "struct";
			}
		}
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

<cffunction name="javaArray" returntype="any" access="private" hint="Return a Java array list object">
	<cfreturn CreateObject("java", "java.util.ArrayList").init() />
</cffunction>

<cffunction name="uniqueScopeKey" returntype="string" access="private" hint="Create a unique, meaningful key for a certain scope">
	<cfargument name="key" type="string" required="true" />
	<cfargument name="prefix" type="string" default="" />
	<cfargument name="scope" type="struct" required="true" />
	<cfargument name="alwaysNumber" type="boolean" default="false" hint="Setting to 'true' causes code to skip straight to numbering keys" />
	<cfargument name="start" type="numeric" default="2" />
	<cfscript>
		var loc = {};
		loc.key = arguments.key;
				
		// if key already used, try prepending a prefix
		if (StructKeyExists(arguments.scope, loc.key) AND Len(arguments.prefix))
			loc.key = arguments.key = arguments.prefix & arguments.key;

		// if we are always numbering the key, append the start number and increment it
		if (arguments.alwaysNumber)
			loc.key = arguments.key & arguments.start++;
			
		// if key still conflicts, start appending numbers
		for (loc.j = arguments.start; StructKeyExists(arguments.scope, loc.key); loc.j++)
			loc.key = arguments.key & loc.j;
		
		return loc.key;
	</cfscript>
</cffunction>

<cffunction name="sqlArrayToString" returntype="string" access="private" hint="Turn SQL tree into a string">
	<cfargument name="sql" type="array" required="true" />
	<cfargument name="interpolateParams" type="boolean" default="false" />
	<cfscript>
		var loc = {};
		loc.sql = "";
		loc.prev = "";

		// get parameter list
		loc.params = getParameters();
		loc.paramCounter = 1;

		// loop over each fragment of the sql array
		loc.iEnd = ArrayLen(arguments.sql);
		for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
			loc.rtn = arguments.sql[loc.i];

			// if fragment is a set of cfqueryparam options, do some additional work
			if (IsStruct(loc.rtn)) {

				// if we aren't interpolating params, just return a question mark placeholder
				if (NOT arguments.interpolateParams) {
					loc.rtn = "?";

				// if we are interpolating, then do some additional work
				} else {

					// add value to parameter if necessary
					if (StructKeyExists(loc.rtn, "value"))
						loc.param = $paramArguments(loc.rtn);
					else
						loc.param = $paramArguments(loc.rtn, loc.params[loc.paramCounter++]);

					// if the parameter should be null, just return the NULL keyword
					if (StructKeyExists(loc.param, "null") AND loc.param.null EQ true) {
						loc.rtn = "NULL";

					} else {
						loc.rtn = loc.param.value;

						// determine if we should wrap the parameter in quotes
						loc.quoted = NOT REFindNoCase("^cf_sql_((big|tiny|small)?int|float|numeric|decimal|double|real|bit|money*)$", loc.param.cfsqltype);

						// quote the value (or list) if necessary
						if (loc.quoted)
							loc.rtn = ListQualify(loc.rtn, "'", Chr(7));

						// if value is a list, convert it to a comma-separated string
						if (StructKeyExists(loc.param, "list") AND loc.param.list EQ true)
							loc.rtn = ListChangeDelims(loc.rtn, ", ", Chr(7));
					}
				}
			}

			// separate fragments with spaces if necessary
			if (loc.sql NEQ "" AND (NOT REFind("(\(|\.)$", loc.prev) AND NOT REFind("^(,|\.(\D|$)|\))", Left(loc.rtn, 2))))
				loc.rtn = " " & loc.rtn;

			// append fragment
			loc.sql &= loc.rtn;
			loc.prev = loc.rtn;
		}
		return loc.sql;
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

<cffunction name="arrayLast" returntype="any" access="private" hint="Return the last item in an array">
	<cfargument name="array" type="array" required="true" />
	<cfreturn arguments.array[ArrayLen(arguments.array)] />
</cffunction>

<cffunction name="sizeOfHashMap" returntype="numeric" access="public">
	<cfargument name="obj" type="any" required="true" />
	<cfscript>
		var loc = {};
		loc.keySet = arguments.obj.keySet();
		loc.keySetIterator = loc.keySet.iterator();
		loc.size = 0;
		while (loc.keySetIterator.hasNext()) {
			loc.key = loc.keySetIterator.next();
			loc.size += sizeOf(loc.key);
			loc.value = arguments.obj.get(loc.key);
			loc.size += sizeOf(loc.value);
		}

		return loc.size;
	</cfscript>
</cffunction>

<cffunction name="sizeOf" returntype="numeric" access="public">
	<cfargument name="obj" type="any" required="true" />
	<cfscript>
		var loc = {};

		try {
			loc.returnVal = Len(ToBinary(ObjectSave(arguments.obj)));
		} catch (any e) {
			loc.type = typeOf(arguments.obj);
			// CFRelLog(context="sizeOf", data=loc.type & Chr(10), action="immediate-append");

			switch (loc.type) {
				case "array":
					return sizeOfArray(arguments.obj);
				case "struct":
					return sizeOfStruct(arguments.obj);
				case "function":
					return 0;
				default:
					// last ditch effort...
					// may be inaccurate, but better than nothing
					if (Not IsSimpleValue(loc.type)) {
						// loc.returnVal = 16;
						return sizeOfStruct(arguments.obj);
					} else {
						try {
							loc.returnVal = Len(SerializeJSON(arguments.obj));
						} catch (any e) {
							loc.returnVal = 16;
						}
					}
			}
		}

		// CFRelLog(context="sizeOf", data=SerializeJSON(arguments.obj) & Chr(10) & Chr(10), action="immediate-append");
		return loc.returnVal;
	</cfscript>
</cffunction>


<cffunction name="getPrintable" returntype="any" access="public">
	<cfargument name="obj" type="any" required="true" />
	<cfscript>
		if (IsSimpleValue(arguments.obj))
			return Duplicate(arguments.obj);
		else if (IsBinary(arguments.obj))
			return ObjectLoad(arguments.obj);
		else if (IsArray(arguments.obj)) {
			var printableObj = [];	
			for (var i = 1; i < ArrayLen(arguments.obj); i++)
				printableObj[i] = getPrintable(arguments.obj[i]);
		}
		else if (IsStruct(arguments.obj)) {
			var printableObj = {};
			for (var key in arguments.obj) {
				if (StructKeyExists(arguments.obj, key) AND NOT IsCustomFunction(arguments.obj[key]))
					printableObj[key] = getPrintable(arguments.obj[key]);
			}
		}
		else if (IsCustomFunction(arguments.obj))
			return "(cannot be printed)";
		else {
			try {
				printableObj = SerializeJSON(arguments.obj);
			} catch (any e) {
				try {
					printableObj = SerializeJSON(ObjectSave(arguments.obj));
				} catch (any e) {
					return "(cannot be printed)";
				}
			}
		}
		return printableObj;
	</cfscript>
</cffunction>


<cffunction name="sizeOfStruct" returntype="numeric" access="public">
	<cfargument name="obj" type="struct" required="true" />
	<cfscript>
		var loc = {};
		loc.size = 0;
		for (loc.key in arguments.obj) {
			loc.size += sizeOf(loc.key);
			loc.value = arguments.obj[loc.key];
			loc.size += sizeOf(loc.value);
		}
		return loc.size;
	</cfscript>
</cffunction>

<cffunction name="sizeOfArray" returntype="numeric" access="public">
	<cfargument name="obj" type="array" required="true" />
	<cfscript>
		var loc = {};
		loc.size = 0;
		for (loc.value in arguments.obj)
			loc.size += sizeOf(loc.value);
		return loc.size;
	</cfscript>
</cffunction>


<cffunction name="bytesAsMBString" returntype="string" access="public">
	<cfargument name="bytes" type="numeric" required="true" />
	<cfreturn (NumberFormat(arguments.bytes/1024/1024, ".__")) & " MB" />
</cffunction>