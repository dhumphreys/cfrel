<cffunction name="literal" returntype="any" access="private" hint="Create a Literal SQL node">
	<cfargument name="content" type="string" required="true" />
	<cfreturn CreateObject("component", "cfrel.nodes.literal").init(arguments.content) />
</cffunction>

<cffunction name="throwException" returntype="void" access="private" hint="Throw an exception with CFTHROW">
	<cfargument name="message" type="string" required="false" />
	<cfargument name="type" type="string" required="false" />
	<cfargument name="detail" type="string" required="false" />
	<cfthrow attributeCollection="#arguments#" />
</cffunction>