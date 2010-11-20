<cfcomponent extends="Node" output="false">
	<cffunction name="init" returntype="struct" access="public">
		<cfargument name="column" type="string" required="true" />
		<cfargument name="table" type="any" default="" />
		<cfargument name="alias" type="string" default="" />
		<cfset super.init(argumentCollection=arguments) />
		<cfreturn this />
	</cffunction>
</cfcomponent>