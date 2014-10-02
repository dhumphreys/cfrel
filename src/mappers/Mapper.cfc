<cfcomponent displayName="Mapper" output="false">
	<cfinclude template="../functions.cfm" />
	
	<cffunction name="init" returntype="struct" access="public" hint="Constructor">
		<cfreturn this />
	</cffunction>

	<cffunction name="map" returntype="struct" access="public" hint="Generate mapping struct for a relation">
		<cfargument name="relation" type="any" required="true" />
		<cfargument name="map" type="struct" default="#emptyMap()#" />
		<cfscript>
			var loc = {};
			loc.iEnd = ArrayLen(arguments.relation.sql.froms);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
				arguments.map = mapTable(arguments.relation.sql.froms[loc.i], arguments.map);
			arguments.map = mapJoins(arguments.relation, arguments.map);
		</cfscript>
		<cfreturn arguments.map />
	</cffunction>

	<cffunction name="mapTable" returntype="struct" access="public" hint="Append mapping information for a table node">
		<cfargument name="table" type="any" required="true" />
		<cfargument name="map" type="struct" default="#emptyMap()#" />
		<cfscript>
			var loc = StructNew();

			// if queries or subqueries are passed in, map them different
			switch(typeOf(arguments.table)) {
				case "cfrel.nodes.subQuery":
					return mapSubQuery(arguments.table, arguments.map);
					break;
				case "cfrel.nodes.query":
					return mapQuery(arguments.table, arguments.map);
					break;
				case "cfrel.nodes.table":
			}

			// look up table information and associate it with an alias
			loc.table = StructNew();
			loc.table.table = arguments.table.table;
			loc.table.alias = arguments.table.alias EQ "" ? arguments.table.table : arguments.table.alias;
			loc.table.alias = uniqueScopeKey(key=loc.table.alias, scope=arguments.map.tables);
			loc.table.properties = StructNew();
			loc.table.calculatedProperties = StructNew();
			loc.table.primaryKey = "";
			loc.table.softDelete = false;

			// append alias to alias list for this table
			if (NOT structKeyExists(arguments.map.aliases, loc.table.table))
				arguments.map.aliases[loc.table.table] = ArrayNew(1);
			ArrayAppend(arguments.map.aliases[loc.table.table], loc.table.alias);

			// create a unique mapping for the table alias
			arguments.map.tables[loc.table.alias] = loc.table;
		</cfscript>
		<cfreturn arguments.map />
	</cffunction>

	<cffunction name="mapQuery" returntype="struct" access="public" hint="Append mapping information for a query object and its columns">
		<cfargument name="query" type="any" required="true" />
		<cfargument name="map" type="struct" default="#emptyMap()#" />
		<cfscript>
			var loc = StructNew();

			// look up table information and associate it with an alias
			loc.table = StructNew();
			loc.table.table = uniqueScopeKey(key="query", scope=arguments.map.tables, alwaysNumber=true, start=1);
			loc.table.alias = loc.table.table;
			loc.table.properties = StructNew();
			loc.table.calculatedProperties = StructNew();
			loc.table.primaryKey = "";
			loc.table.softDelete = false;

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
				loc.col.alias = uniqueScopeKey(key=loc.col.column, prefix="query", scope=arguments.map.columns);
				loc.col.mapping = "#loc.col.table#.#loc.col.column#";
				loc.col.cfsqltype = extractDataTypeFromQuery(loc.properties[loc.i]);
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

	<cffunction name="mapSubQuery" returntype="struct" access="public" hint="Append mapping information for a subquery node">
		<cfargument name="sub" type="any" required="true" />
		<cfargument name="map" type="struct" default="#emptyMap()#" />
		<cfscript>
			var loc = StructNew();

			// look up table information and associate it with an alias
			loc.table = StructNew();
			loc.table.table = uniqueScopeKey(key="subquery", scope=arguments.map.tables, alwaysNumber=true, start=1);
			loc.table.alias = loc.table.table;
			loc.table.properties = StructNew();
			loc.table.calculatedProperties = StructNew();
			loc.table.primaryKey = "";
			loc.table.softDelete = false;

			// TODO: look up properties from underlying relation and associate them with an alias

			// append alias to alias list for subqueries
			if (NOT structKeyExists(arguments.map.aliases, "subquery"))
				arguments.map.aliases["subquery"] = ArrayNew(1);
			ArrayAppend(arguments.map.aliases["subquery"], loc.table.alias);

			// create a unique mapping for the table alias
			arguments.map.tables[loc.table.alias] = loc.table;
		</cfscript>
		<cfreturn arguments.map />
	</cffunction>

	<cffunction name="mapJoins" returntype="struct" access="public" hint="Append mapping information for joins on a relation">
		<cfargument name="relation" type="any" required="true" />
		<cfargument name="map" type="struct" default="#emptyMap()#" />
		<cfscript>
			var loc = StructNew();

			// loop over each join from the relation
			var loc.iEnd = ArrayLen(arguments.relation.sql.joins);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
				loc.join = arguments.relation.sql.joins[loc.i];
				switch(typeOf(loc.join)) {

					// if it is a standard join, map the table used in the join
					case "cfrel.nodes.join":
						arguments.map = mapTable(loc.join.table, arguments.map);
						break;

					// if it is an include, map the include into more joins
					case "cfrel.nodes.include":
						arguments.map = mapInclude(arguments.relation, loc.join, arguments.map);
						break;

					// if it is anything else, throw an exception
					default:
						throwException("Unknown join node type encountered during mapping.");
				}
			}
		</cfscript>
		<cfreturn arguments.map />
	</cffunction>

	<cffunction name="mapInclude" returntype="struct" access="public" hint="Fail if includes are attempted">
		<cfargument name="relation" type="any" required="true" />
		<cfargument name="include" type="any" required="true" />
		<cfargument name="map" type="struct" default="#emptyMap()#" />
		<cfscript>
			throwException("Cannot map includes with this type of relation.");
		</cfscript>
	</cffunction>
	
	<cffunction name="extractDataTypeFromQuery" returntype="string" access="private" hint="Extract cfsqltype from QoQ column">
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
	
	<cffunction name="scopes" returntype="any" access="public">
		<cfargument name="model" type="any" required="true" />
		<cfreturn StructNew() />
	</cffunction>
	
	<cffunction name="beforeFind" returntype="void" access="public" hint="Do before-find relation logic">
		<cfargument name="relation" type="any" required="true" />
	</cffunction>
	
	<cffunction name="afterFind" returntype="query" access="public" hint="Do after-find query processing">
		<cfargument name="model" type="any" required="true" />
		<cfargument name="query" type="query" required="true" />
		<cfreturn arguments.query />
	</cffunction>
	
	<cffunction name="primaryKey" returntype="string" access="public" hint="Get primary key list from model">
		<cfargument name="model" type="any" required="true" />
		<cfreturn "" />
	</cffunction>
</cfcomponent>