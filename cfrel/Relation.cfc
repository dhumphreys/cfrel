<cfcomponent output="false">
	
	<cffunction name="init" returntype="struct" access="public" hint="Constructor">
	</cffunction>
	
	<cffunction name="clone" returntype="struct" access="public" hint="Duplicate the relation object">
	</cffunction>
	
	<cffunction name="select" returntype="struct" access="public" hint="Append to the SELECT clause of the relation">
	</cffunction>
	
	<cffunction name="join" returntype="struct" access="public" hint="Add a JOIN to the relation">
	</cffunction>
	
	<cffunction name="where" returntype="struct" access="public" hint="Append to the WHERE clause of the relation">
	</cffunction>
	
	<cffunction name="group" returntype="struct" access="public" hint="Append to GROUP BY clause of the relation">
	</cffunction>
	
	<cffunction name="order" returntype="struct" access="public" hint="Append to ORDER BY clause of the relation">
	</cffunction>
	
	<cffunction name="limit" returntype="struct" access="public" hint="Restrict the number of records when querying">
	</cffunction>
	
	<cffunction name="offset" returntype="struct" access="public" hint="Skip some records when querying">
	</cffunction>
	
	<cffunction name="sql" returntype="string" access="public">
	</cffunction>
</cfcomponent>