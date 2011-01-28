<cfcomponent extends="Node" output="false">
	<cffunction name="init" returntype="struct" access="public">
		<cfargument name="table" type="string" default="" />
		<cfargument name="alias" type="string" default="" />
		<cfargument name="model" type="any" default="false" />
		<cfset super.init(argumentCollection=arguments) />
		<cfreturn this />
	</cffunction>
</cfcomponent>