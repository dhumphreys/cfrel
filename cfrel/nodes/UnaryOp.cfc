<cfcomponent extends="Node" output="false">
	<cffunction name="init" returntype="struct" access="public">
		<cfargument name="op" type="string" required="true" />
		<cfargument name="subject" type="any" required="true" />
		<cfset super.init(argumentCollection=arguments) />
		<cfreturn this />
	</cffunction>
</cfcomponent>