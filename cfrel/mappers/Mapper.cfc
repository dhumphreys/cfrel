<cfcomponent displayName="Mapper" output="false">
	<cfinclude template="../functions.cfm" />
	
	<cffunction name="init" returntype="struct" access="public" hint="Constructor">
		<cfscript>
			variables.models = [];
			variables.tables = {};
			variables.columns = {};
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
		<cfset throwException("Current mapper does not support includes") />
	</cffunction>
	
	<cffunction name="columnDataType" returntype="string" access="public">
		<cfargument name="column" type="string" required="true" />
		<cfscript>
			return "cf_sql_char";
		</cfscript>
	</cffunction>
	
	<cffunction name="columnsFor" returntype="string" access="private">
		<cfargument name="table" type="string" default="" />
		<cfscript>
			var loc = {};
			loc.columns = "";
			for (loc.key in variables.columns) {
				loc.col = variables.columns[loc.key];
				if (StructKeyExists(loc.col, "table") AND (Len(arguments.table) EQ 0 OR loc.col.table EQ arguments.table))
					loc.columns = ListAppend(loc.columns, loc.col.value & " AS " & loc.key);
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