<cfcomponent extends="Node" output="false">
	<cffunction name="init" returntype="struct" access="public">
		<cfargument name="table" type="string" required="true" />
		<cfargument name="alias" type="string" default="" />
		<cfset super.init(argumentCollection=arguments) />
		<cfreturn this />
	</cffunction>
</cfcomponent>