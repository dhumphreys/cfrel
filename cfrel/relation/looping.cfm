<cffunction name="recordCount" returntype="numeric" access="public" hint="Get count of rows in recordset">
	<cfreturn query().recordCount />
</cffunction>

<cffunction name="currentRow" returntype="numeric" access="public" hint="Get current row of loop">
	<cfscript>
		exec();
		if (variables.currentRow EQ 0)
			variables.currentRow++;
		return variables.currentRow;
	</cfscript>
</cffunction>

<cffunction name="reset" returntype="void" access="public" hint="Reset row counter">
	<cfset variables.currentRow = 0 />
</cffunction>

<cffunction name="curr" returntype="any" access="public" hint="Get current object, or false if no more rows">
	<cfargument name="format" type="string" default="object" hint="Format of record to be returned: struct or object" />
	<cfscript>
		exec();
		if (this.currentRow() GT recordCount())
			return false;
		switch (arguments.format) {
			case "struct":
				return struct(variables.currentRow);
				break;
			case "object":
				return object(variables.currentRow);
				break;
		}
		return false;
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
		exec();
		if (variables.currentRow GT 0)
			variables.currentRow -= 1;
		return (variables.currentRow GT 0);
	</cfscript>
</cffunction>
