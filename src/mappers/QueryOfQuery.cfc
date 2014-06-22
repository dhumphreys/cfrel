<cfcomponent extends="Mapper" displayName="QueryOfQuery" output="false">

	<cffunction name="mapTable" returntype="struct" access="public" hint="Append mapping information for a table node (unless it is a model)">
		<cfargument name="table" type="any" required="true" />
		<cfargument name="map" type="struct" default="#emptyMap()#" />
		<cfscript>
			if (typeOf(arguments.table) EQ "cfrel.nodes.query")
				return mapQuery(arguments.table, arguments.map);
			else
				return super.mapTable(arguments.table, arguments.map);
		</cfscript>
	</cffunction>

	<cffunction name="mapQuery" returntype="struct" access="public" hint="Append mapping information for a model and its properties">
		<cfargument name="query" type="any" required="true" />
		<cfargument name="map" type="struct" default="#emptyMap()#" />
		<cfscript>
			var loc = StructNew();

			// look up table information and associate it with an alias
			loc.table = StructNew();
			loc.table.table = uniqueScopeKey(key="query", scope=arguments.map.tables, base=false);
			loc.table.alias = loc.table.table;
			loc.table.properties = StructNew();
			loc.table.calculatedProperties = StructNew();
			loc.table.primaryKey = "";

			// create a unique mapping for the table alias
			arguments.map.tables[loc.table.alias] = loc.table;

			// append alias to alias list for this table
			if (NOT structKeyExists(arguments.map.aliases, "query"))
				arguments.map.aliases["query"] = ArrayNew(1);
			ArrayAppend(arguments.map.aliases["query"], loc.table.alias);

			// look up properties and associate them with an alias
			loc.properties = GetMetaData(arguments.query.subject);
			loc.iEnd = ArrayLen(loc.properties);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
				loc.col = StructNew();
				loc.col.column = loc.properties[loc.i].name;
				loc.col.table = loc.table.alias;
				loc.col.alias = uniqueScopeKey(key=loc.col.column, prefix=loc.table.alias, scope=arguments.map.columns);
				loc.col.mapping = "#loc.col.table#.#loc.col.column#";
				loc.col.cfsqltype = extractDataType(loc.properties[loc.i]);
				loc.col.calculated = false;

				// create unique mappings for [alias], [table].[alias], [table].[column]
				arguments.map.columns[loc.col.alias] = loc.col;
				arguments.map.columns["#loc.col.table#.#loc.col.alias#"] = loc.col;
				if (NOT StructKeyExists(arguments.map.columns, "#loc.col.table#.#loc.col.column#"))
					arguments.map.columns["#loc.col.table#.#loc.col.column#"] = loc.col;

				// add to property list for table mapping
				loc.table.properties[loc.col.column] = loc.col;
			}
		</cfscript>
		<cfreturn arguments.map />
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