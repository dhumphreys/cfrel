<cffunction name="qoq" returntype="struct" access="public" hint="Return a QoQ relation with the current recordset as the FROM">
	<cfreturn this.new().from(this.query()) />
</cffunction>

<cffunction name="_queryColumnDataType" returntype="string" access="private" hint="Use query properties to return datatype of column">
	<cfargument name="column" type="string" required="true" />
	<cfscript>
		var loc = {};
		
		// determine which query in the FROM clause the column is in
		if (REFind("^query\d+\.", arguments.column) EQ 1)
			loc.queryIndex = REReplace(arguments.column, "^query(\d+)\..+$", "\1");
		else
			loc.queryIndex = 1;
			
		// grab only column from arguments
		arguments.column = ListLast(arguments.column, ".");
		
		// return default type if no qoq, no column, or invalid query index
		if (NOT variables.qoq OR arguments.column EQ "" OR loc.queryIndex LT 1 OR loc.queryIndex GT ArrayLen(this.sql.froms))
			return "cf_sql_char";
		
		// look at metadata for query
		loc.meta = GetMetaData(this.sql.froms[loc.queryIndex]);
		
		// try to find correct column
		loc.iEnd = ArrayLen(loc.meta);
		for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
			if (loc.meta[loc.i].name EQ arguments.column AND StructKeyExists(loc.meta[loc.i], "typeName")) {
				loc.type = ListFirst(loc.meta[loc.i].typeName, " ");
				
				// deal with type mismatches
				switch (loc.type) {
					case "datetime":
						return "cf_sql_date";
						break;
					case "int":
					case "int4":
						return "cf_sql_integer";
						break;
					case "nchar":
						return "cf_sql_char";
						break;
					default:
						return "cf_sql_" & loc.type;
				}
			}
		}
		
		// return default type if no column match
		return "cf_sql_char";
	</cfscript>
</cffunction>
