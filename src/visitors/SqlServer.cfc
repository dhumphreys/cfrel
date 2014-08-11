<cfcomponent extends="Sql" output="false">

	<cffunction name="visit_relation" returntype="any" access="private" hint="Generate SQL for a relation specific to SqlServer">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			
			// see if limits or offsets exist
			loc.limit = StructKeyExists(arguments.obj.sql, "limit");
			loc.offset = StructKeyExists(arguments.obj.sql, "offset");
			
			// if limit is found
			if (loc.limit) {
				
				// duplicate relation so that we can change some things
				loc.obj = arguments.obj.clone();
				
				// use ROW_NUMBER() in a sub-query to accomplish pagination
				if (loc.offset) {
					
					// calculate row number range
					loc.start = loc.obj.sql.offset + 1;
					loc.end = loc.obj.sql.offset + loc.obj.sql.limit;
					
					// throw error if there is no ORDER BY
					if (ArrayLen(loc.obj.sql.orders) EQ 0)
						throwException("ORDER BY clause is required for pagination");
					
					// force a GROUP BY if trying to get DISTINCT rows in subquery
					if (ArrayContains(loc.obj.sql.selectFlags, "DISTINCT") AND ArrayLen(loc.obj.sql.groups) EQ 0)
						loc.obj.sql.groups = Duplicate(loc.obj.sql.select);

					
					// create new SELECT entry to count row numbers
					arguments.state.aliasOff = true;
					ArrayAppend(loc.obj.sql.select, ["ROW_NUMBER() OVER (ORDER BY", visit_list(obj=loc.obj.sql.orders, rtn=[], argumentCollection=arguments), ") AS [rowNum]"], false);
					arguments.state.aliasOff = false;
					
					// wipe out ORDER BY in inner query
					loc.obj.sql.orders = [];
					
					// remove LIMIT and OFFSET from inner query
					StructDelete(loc.obj.sql, "limit");
					StructDelete(loc.obj.sql, "offset");
					
					// generate SQL for inner query and return inside of SELECT
					ArrayAppend(arguments.rtn,"SELECT * FROM (");
					arguments.rtn = super.visit_relation(obj=loc.obj, argumentCollection=arguments);
					ArrayAppend(arguments.rtn, ") [paged_query] WHERE [rowNum] BETWEEN #loc.start# AND #loc.end# ORDER BY [rowNum] ASC");
				
				// use TOP to restrict dataset instead of LIMIT
				} else {
					ArrayAppend(loc.obj.sql.selectFlags, "TOP #loc.obj.sql.limit#");
					StructDelete(loc.obj.sql, "limit");
					arguments.rtn = super.visit_relation(obj=loc.obj, argumentCollection=arguments);
				}
			
			// if only offset is found, error out
			} else if (loc.offset) {
				throwException("OFFSET not supported in Microsoft SQL Server");

			// just generate relation the default way
			} else {
				arguments.rtn = super.visit_relation(argumentCollection=arguments);
			}
			
			return arguments.rtn;
		</cfscript>
	</cffunction>
	
	<cffunction name="escape" returntype="string" access="private"  hint="Escape SQL column and table names">
		<cfargument name="subject" type="string" required="true" />
		<cfscript>
			var loc = {};
			loc.reg = "[^ \t'.,\]\[\(\)]+";
			if (REFind("^(#loc.reg#)(\.#loc.reg#)*$", arguments.subject) EQ 0)
				return arguments.subject;
			return REReplace(arguments.subject, "(^|\.)(#loc.reg#)", "\1[\2]", "ALL");
		</cfscript>
	</cffunction>
</cfcomponent>