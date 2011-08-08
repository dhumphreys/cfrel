<cfcomponent displayName="Mapper" output="false">
	<cfinclude template="../functions.cfm" />
	
	<cffunction name="init" returntype="struct" access="public" hint="Constructor">
		<cfargument name="includeSoftDeletes" type="boolean" default="false" />
		<cfscript>
			variables.models = [];
			variables.tables = {};
			variables.columns = {};
			variables.includeSoftDeletes = arguments.includeSoftDeletes;
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="clearMapping" returntype="void" access="public">
		<cfscript>
			variables.models = [];
			variables.tables = {};
			variables.columns = {};
		</cfscript>
	</cffunction>
	
	<cffunction name="buildMapping" returntype="void" access="public">
		<cfargument name="relation" type="any" required="true" />
		<!--- do nothing here --->
	</cffunction>
	
	<cffunction name="mapObject" returntype="void" access="public">
		<cfargument name="obj" type="any" required="true" />
		<cfargument name="useAlias" type="boolean" default="true" />
		<!--- do nothing here --->
	</cffunction>
	
	<cffunction name="mapIncludes" returntype="void" access="public">
		<cfargument name="relation" type="any" required="true" />
		<cfargument name="include" type="string" required="true" />
		<cfargument name="joinType" type="string" default="" />
		<cfset throwException("Current mapper does not support includes") />
	</cffunction>
	
	<cffunction name="columnDataType" returntype="string" access="public">
		<cfargument name="column" type="string" required="true" />
		<cfscript>
			return "cf_sql_char";
		</cfscript>
	</cffunction>
	
	<cffunction name="queryRowToStruct" returntype="struct" access="public">
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
	
	<cffunction name="structToObject" returntype="struct" access="public">
		<cfargument name="data" type="struct" required="true" />
		<cfargument name="model" type="any" default="false" />
		<cfscript>
			var loc = {};
			loc.comp = CreateObject("component", "component");
			for (loc.key in arguments.data)
				loc.comp[loc.key] = arguments.data[loc.key];
			return loc.comp;
		</cfscript>
	</cffunction>
	
	<cffunction name="afterFind" returntype="query" access="public" hint="Do after-find query processing">
		<cfargument name="model" type="any" required="true" />
		<cfargument name="query" type="query" required="true" />
		<cfreturn arguments.query />
	</cffunction>
	
	<cffunction name="primaryKey" returntype="array" access="public" hint="Get primary key array from model">
		<cfargument name="model" type="any" required="true" />
		<cfreturn ArrayNew(1) />
	</cffunction>
	
	<cffunction name="columnsFor" returntype="any" access="private">
		<cfargument name="table" type="string" default="" />
		<cfscript>
			var loc = {};
			loc.columns = ArrayNew(1);
			for (loc.key in variables.columns) {
				loc.col = variables.columns[loc.key];
				if (StructKeyExists(loc.col, "table") AND (Len(arguments.table) EQ 0 OR loc.col.table EQ arguments.table))
					ArrayAppend(loc.columns, sqlColumn(column=loc.col.value, alias=loc.key));
			}
			return loc.columns;
		</cfscript>
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
			for (loc.j = 2; StructKeyExists(arguments.scope, loc.key); loc.j++)
				loc.key = arguments.key & loc.j;
			
			return loc.key;
		</cfscript>
	</cffunction>
</cfcomponent>