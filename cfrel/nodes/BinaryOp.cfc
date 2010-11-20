<cfcomponent extends="Node" output="false">
	<cffunction name="init" returntype="struct" access="public">
		<cfargument name="left" type="any" required="true" />
		<cfargument name="op" type="string" required="true" />
		<cfargument name="right" type="string" required="true" />
		<cfset super.init(argumentCollection=arguments) />
		<cfreturn this />
	</cffunction>
</cfcomponent>