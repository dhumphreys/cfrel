<cfcomponent extends="Sql" output="false">
	<!--- cfrel.visitors.Sql should give correct query of queries syntax --->
	
	<cffunction name="_escapeSqlEntity" returntype="string" access="private"  hint="Escape SQL column and table names">
		<cfargument name="subject" type="string" required="true" />
		<cfscript>
			var loc = {};
			loc.reg = "[^ \t'.,\[\]\(\)]+";
			if (REFind("^(#loc.reg#)(\.#loc.reg#)*$", arguments.subject) EQ 0)
				return arguments.subject;
			return REReplace(arguments.subject, "(^|\.)(#loc.reg#)", "\1[\2]", "ALL");
		</cfscript>
	</cffunction>
</cfcomponent>