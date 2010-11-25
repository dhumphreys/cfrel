<cfcomponent extends="Node" output="false">
	<cffunction name="init" returntype="struct" access="public">
		<cfargument name="name" type="any" required="true" />
		<cfargument name="val1" type="string" default="" />
		<cfargument name="val2" type="string" default="" />
		<cfset super.init(argumentCollection=arguments) />
		<cfreturn this />
	</cffunction>
</cfcomponent>