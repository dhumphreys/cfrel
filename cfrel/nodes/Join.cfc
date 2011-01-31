<cfcomponent extends="Node" output="false">
	<cffunction name="init" returntype="struct" access="public">
		<cfargument name="table" type="any" required="true" />
		<cfargument name="condition" type="any" default="false" />
		<cfargument name="type" type="string" default="inner" />
		<cfset super.init(argumentCollection=arguments) />
		<cfreturn this />
	</cffunction>
</cfcomponent>