<cffunction name="throwException" returntype="void" access="public" hint="Throw an exception with CFTHROW">
	<cfargument name="message" type="string" required="false" />
	<cfargument name="type" type="string" required="false" />
	<cfargument name="detail" type="string" required="false" />
	<cfthrow attributeCollection="#arguments#" />
</cffunction>