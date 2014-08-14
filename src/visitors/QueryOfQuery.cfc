<cfcomponent extends="Sql" output="false">
	<!--- cfrel.visitors.Sql should give correct query of queries syntax --->
	
	<cffunction name="escape" returntype="string" access="private"  hint="Escape SQL column and table names">
		<cfargument name="subject" type="string" required="true" />
		<cfscript>
      arguments.subject = REReplace(arguments.subject, "[\[\]""`]", "", "ALL");
			return "[" & Replace(arguments.subject, ".", "].[", "ALL") & "]";
		</cfscript>
	</cffunction>
</cfcomponent>