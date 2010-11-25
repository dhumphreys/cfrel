<cfcomponent extends="Node" output="false">
	<cffunction name="init" returntype="struct" access="public">
		<cfargument name="subject" type="any" required="true" />
		<cfargument name="start" type="any" required="true" />
		<cfargument name="end" type="any" required="true" />
		<cfset super.init(argumentCollection=arguments) />
		<cfreturn this />
	</cffunction>
</cfcomponent>