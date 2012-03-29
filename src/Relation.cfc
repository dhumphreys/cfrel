<cfcomponent output="false">
	<cfinclude template="functions.cfm" />
	<cfinclude template="relation/accessors.cfm" />
	<cfinclude template="relation/cache.cfm" />
	<cfinclude template="relation/execution.cfm" />
	<cfinclude template="relation/initialization.cfm" />
	<cfinclude template="relation/looping.cfm" />
	<cfinclude template="relation/models.cfm" />
	<cfinclude template="relation/objects.cfm" />
	<cfinclude template="relation/onMissingMethod.cfm" />
	<cfinclude template="relation/pagination.cfm" />
	<cfinclude template="relation/qoq.cfm" />
	<cfinclude template="relation/query.cfm" />
	
	<!--- HACK: define query() and struct() in a CFC to get around Railo handling reserved words --->
	<cffunction name="query" returntype="query" access="public" hint="Lazily execute and return query object">
		<cfreturn this.$query(argumentCollection=arguments) />
	</cffunction>
	<cffunction name="struct" returntype="struct" access="public" hint="Return struct representation of current query row">
		<cfreturn this.$struct(argumentCollection=arguments) />
	</cffunction>
</cfcomponent>