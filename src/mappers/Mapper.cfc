<cfcomponent displayName="Mapper" output="false">
	<cfinclude template="../functions.cfm" />
	
	<cffunction name="init" returntype="struct" access="public" hint="Constructor">
		<cfreturn this />
	</cffunction>
	
	<cffunction name="aliasName" returntype="string" access="public" hint="Return alias name to reference in query">
		<cfargument name="model" type="any" required="true" />
		<cfscript>
			if (StructKeyExists(arguments.model, "alias") AND Len(arguments.model.alias))
				return arguments.model.alias;
			return arguments.model.table;
		</cfscript>
	</cffunction>
	
	<cffunction name="tableName" returntype="string" access="public" hint="Return table name to reference in query">
		<cfargument name="model" type="any" required="true" />
		<cfreturn arguments.model.table />
	</cffunction>
	
	<cffunction name="properties" returntype="struct" access="public" hint="Return all database properties in a structure">
		<cfargument name="model" type="any" required="true" />
		<cfreturn StructNew() />
	</cffunction>
	
	<cffunction name="calculatedProperties" returntype="struct" access="public" hint="Return all calculated properties in a structure">
		<cfargument name="model" type="any" required="true" />
		<cfreturn StructNew() />
	</cffunction>
	
	<cffunction name="association" returntype="struct" access="public" hint="Return specific association details">
		<cfargument name="model" returntype="any" required="true" />
		<cfargument name="association" type="string" required="true" />
		<cfset throwException("Association `#arguments.association#` not found.") />
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