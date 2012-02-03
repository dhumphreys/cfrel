<cffunction name="recordCount" returntype="numeric" access="public" hint="Get count of rows in recordset">
	<cfreturn this.query().recordCount />
</cffunction>

<cffunction name="currentRow" returntype="numeric" access="public" hint="Get current row of loop">
	<cfscript>
		
		// if query has not been executed, we will get the wrong value
		exec();
		
		// if the counter has not been initialized, set it to 1
		if (variables.currentRow EQ 0)
			variables.currentRow = 1;
		return variables.currentRow;
	</cfscript>
</cffunction>

<cffunction name="reset" returntype="void" access="public" hint="Reset row counter">
	<cfset variables.currentRow = 0 />
</cffunction>

<cffunction name="curr" returntype="any" access="public" hint="Get current object, or false if no more rows">
	<cfargument name="format" type="string" default="object" hint="Format of record to be returned: struct or object" />
	<cfscript>
		return get(index=this.currentRow(), format=arguments.format);
	</cfscript>
</cffunction>

<cffunction name="next" returntype="boolean" access="public" hint="Move counter to next row. Return false if no more rows.">
	<cfscript>
		var count = recordCount();
		if (variables.currentRow LTE count)
			variables.currentRow += 1;
		return (variables.currentRow LTE count);
	</cfscript>
</cffunction>

<cffunction name="prev" returntype="boolean" access="public" hint="Move counter to previous row. Return false if no more rows.">
	<cfscript>
		if (variables.currentRow GT 0)
			variables.currentRow -= 1;
		return (variables.currentRow GT 0);
	</cfscript>
</cffunction>
