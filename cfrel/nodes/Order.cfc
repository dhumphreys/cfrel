<cfcomponent extends="Node" output="false">
	<cffunction name="init" returntype="struct" access="public">
		<cfargument name="subject" type="any" required="true" />
		<cfargument name="descending" type="boolean" default="false" />
		<cfset super.init(argumentCollection=arguments) />
		<cfreturn this />
	</cffunction>
</cfcomponent>