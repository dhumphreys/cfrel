<cfcomponent extends="Mapper" displayName="QueryOfQuery" output="false">
	
	<cffunction name="aliasName" returntype="string" access="public" hint="Return alias name to reference in query">
		<cfargument name="model" type="any" required="true" />
		<cfreturn "query" />
	</cffunction>
	
	<cffunction name="tableName" returntype="string" access="public" hint="Return table name to reference in query">
		<cfargument name="model" type="any" required="true" />
		<cfreturn "query" />
	</cffunction>
	
	<cffunction name="properties" returntype="struct" access="public" hint="Return all query columns in a structure">
		<cfargument name="model" type="any" required="true" />
		<cfscript>
			var loc = {};
			loc.returnValue = StructNew();
			
			// loop over database properties
			loc.properties = GetMetaData(arguments.model);
			loc.iEnd = ArrayLen(loc.properties);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
				loc.col = loc.properties[loc.i];
				
				// create new column entry with specified
				loc.newCol = StructNew();
				loc.newCol.property = loc.col.name;
				loc.newCol.column = loc.col.name;
				loc.newCol.cfsqltype = extractDataType(loc.col);
				
				// append column to return list
				loc.returnValue[loc.col.name] = loc.newCol;
			}
			
			return loc.returnValue;
		</cfscript>
	</cffunction>
	
	<cffunction name="extractDataType" returntype="string" access="private" hint="Extract cfsqltype from QoQ column">
		<cfargument name="column" type="struct" required="true" />
		<cfscript>
			var loc = {};
			
			// search for correct type for column
			if (StructKeyExists(arguments.column, "typeName")) {
				loc.type = ListFirst(arguments.column.typeName, " ");
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
			
			// return default type if no type was found
			} else {
				return "cf_sql_char";
			}
		</cfscript>
	</cffunction>
	
</cfcomponent>