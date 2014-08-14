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
				
				// use ROW_NUMBER() in a sub-query to accomplish pagination
				if (loc.offset) {

					// temporarily keep references to SQL sub-trees that might be altered
					loc.alteredSql = {
						select=Duplicate(arguments.obj.sql.select),
						groups=arguments.obj.sql.groups,
						orders=arguments.obj.sql.orders,
						limit=arguments.obj.sql.limit,
						offset=arguments.obj.sql.offset
					};
					
					// calculate row number range
					loc.start = arguments.obj.sql.offset + 1;
					loc.end = arguments.obj.sql.offset + arguments.obj.sql.limit;
					
					// throw error if there is no ORDER BY
					if (ArrayLen(arguments.obj.sql.orders) EQ 0)
						throwException("ORDER BY clause is required for pagination");
					
					// force a GROUP BY if trying to get DISTINCT rows in subquery
					if (ArrayContains(arguments.obj.sql.selectFlags, "DISTINCT") AND ArrayLen(arguments.obj.sql.groups) EQ 0)
						arguments.obj.sql.groups = Duplicate(arguments.obj.sql.select);

					// make sure there is at least a wildcard in the select list
					if (ArrayLen(arguments.obj.sql.select) EQ 0)
						ArrayAppend(arguments.obj.sql.select, sqlWildcard());
					
					// create new SELECT entry to count row numbers
					arguments.state.aliasOff = true;
					ArrayAppend(arguments.obj.sql.select, ["ROW_NUMBER() OVER (ORDER BY", visit_list(obj=arguments.obj.sql.orders, rtn=[], argumentCollection=arguments), ") AS [rowNum]"], false);
					arguments.state.aliasOff = false;
					
					// wipe out ORDER BY in inner query
					arguments.obj.sql.orders = [];
					
					// remove LIMIT and OFFSET from inner query
					StructDelete(arguments.obj.sql, "limit");
					StructDelete(arguments.obj.sql, "offset");
					
					// generate SQL for inner query and return inside of SELECT
					ArrayAppend(arguments.rtn,"SELECT * FROM (");
					arguments.rtn = super.visit_relation(obj=arguments.obj, argumentCollection=arguments);
					ArrayAppend(arguments.rtn, ") [paged_query] WHERE [rowNum] BETWEEN #loc.start# AND #loc.end# ORDER BY [rowNum] ASC");

					// replace altered SQL sub-trees in the original relation
					StructAppend(arguments.obj.sql, loc.alteredSql, true);
				
				// use TOP to restrict dataset instead of LIMIT
				} else {

					// temporarily keep references to SQL sub-trees that might be altered
					loc.alteredSql = {
						selectFlags=Duplicate(arguments.obj.sql.selectFlags),
						limit=arguments.obj.sql.limit
					};

					// generate the SQL using TOP instead of LIMIT
					ArrayAppend(arguments.obj.sql.selectFlags, "TOP #arguments.obj.sql.limit#");
					StructDelete(arguments.obj.sql, "limit");
					arguments.rtn = super.visit_relation(obj=arguments.obj, argumentCollection=arguments);

					// replace altered SQL sub-trees in the original relation
					StructAppend(arguments.obj.sql, loc.alteredSql, true);
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
			arguments.subject = REReplace(arguments.subject, "[\[\]""`]", "", "ALL");
			return "[" & Replace(arguments.subject, ".", "].[", "ALL") & "]";
		</cfscript>
	</cffunction>
</cfcomponent>