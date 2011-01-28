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
	
	<cffunction name="buildMapping" returntype="void" access="public">
		<cfargument name="relation" type="any" required="true" />
		<!--- do nothing here --->
	</cffunction>
	
	<cffunction name="applyMapping" returntype="void" access="public">
		<cfargument name="relation" type="any" required="true" />
		<!--- do nothing here --->
	</cffunction>
	
	<cffunction name="columnsFor" returntype="string" access="private">
		<cfargument name="table" type="string" default="" />
		<cfscript>
			var loc = {};
			loc.columns = "";
			for (loc.key in variables.columns) {
				loc.col = variables.columns[loc.key];
				if (StructKeyExists(loc.col, "table") AND (Len(arguments.table) EQ 0 OR loc.col.table EQ arguments.table))
					loc.columns = ListAppend(loc.columns, loc.key & " AS " & loc.col.table);
			}
			return loc.columns;
		</cfscript>
	</cffunction>
</cfcomponent>