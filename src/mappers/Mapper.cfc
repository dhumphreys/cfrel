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

			// if a subquery is passed in, map it differently
			if (typeOf(arguments.table) EQ "cfrel.nodes.subQuery")
				return mapSubQuery(arguments.table, arguments.map);

			// look up table information and associate it with an alias
			loc.table = StructNew();
			loc.table.table = arguments.table.table;
			loc.table.alias = arguments.table.alias EQ "" ? arguments.table.table : arguments.table.alias;
			loc.table.alias = uniqueScopeKey(key=loc.table.alias, scope=arguments.map.tables);
			loc.table.properties = StructNew();
			loc.table.calculatedProperties = StructNew();
			loc.table.primaryKey = "";

			// append alias to alias list for this table
			if (NOT structKeyExists(arguments.map.aliases, loc.table.table))
				arguments.map.aliases[loc.table.table] = ArrayNew(1);
			ArrayAppend(arguments.map.aliases[loc.table.table], loc.table.alias);

			// create a unique mapping for the table alias
			arguments.map.tables[loc.table.alias] = loc.table;
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
			loc.table.table = uniqueScopeKey(key="subquery", scope=arguments.map.tables, base=false);
			loc.table.alias = loc.table.table;
			loc.table.properties = StructNew();
			loc.table.calculatedProperties = StructNew();
			loc.table.primaryKey = "";

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

	<cffunction name="buildStruct" returntype="struct" access="public">
		<cfargument name="query" type="query" required="true" />
		<cfargument name="index" type="numeric" default="#arguments.query.currentRow#" />
		<cfargument name="model" type="any" default="false" />
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
	
	<cffunction name="buildStructCache" returntype="array" access="public">
		<cfargument name="query" type="query" required="true" />
		<cfargument name="model" type="any" default="false" />
		<cfreturn ArrayNew(1) />
	</cffunction>
	
	<cffunction name="buildObject" returntype="struct" access="public">
		<cfargument name="query" type="query" required="true" />
		<cfargument name="index" type="numeric" default="#arguments.query.currentRow#" />
		<cfargument name="model" type="any" default="false" />
		<cfscript>
			var loc = {};
			loc.comp = CreateObject("component", "component");
			loc.data = buildStruct(argumentCollection=arguments);
			for (loc.key in loc.data)
				loc.comp[loc.key] = loc.data[loc.key];
			return loc.comp;
		</cfscript>
	</cffunction>
	
	<cffunction name="buildObjectCache" returntype="array" access="public">
		<cfargument name="query" type="query" required="true" />
		<cfargument name="model" type="any" default="false" />
		<cfreturn ArrayNew(1) />
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