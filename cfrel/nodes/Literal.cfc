<cfcomponent output="false">
	<cffunction name="init" returntype="struct" access="public">
		<cfargument name="content" type="string" required="true" />
		<cfset this.content = arguments.content />
		<cfreturn this />
	</cffunction>
</cfcomponent>