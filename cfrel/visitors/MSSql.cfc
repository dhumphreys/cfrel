<cfcomponent extends="sql" output="false">

	<cffunction name="visit_relation" returntype="any" access="private" hint="Generate SQL for a relation specific to MSSQL">
		<cfscript>
			var loc = {};
			
			// get private sql scope of relation
			loc.obj = injectInspector(arguments.obj);
			loc.sql = loc.obj._inspect().sql;
			
			// see if limits or offsets exist
			loc.limit = StructKeyExists(loc.sql, "limit");
			loc.offset = StructKeyExists(loc.sql, "offset");
			
			// if limit is found
			if (loc.limit) {
				
				// duplicate relation to keep old one intact
				loc.obj = injectInspector(loc.obj.clone());
				loc.sql = loc.obj._inspect().sql;
				
				// use ROW_NUMBER() in a sub-query to accomplish pagination
				if (loc.offset) {
					
					// calculate row number range
					loc.start = loc.sql.offset + 1;
					loc.end = loc.sql.offset + loc.sql.limit;
					
					// throw error if there is no ORDER BY
					if (ArrayLen(loc.sql.orders) EQ 0)
						throwException("ORDER BY clause is required for pagination");
					
					// create new SELECT item from inner query
					ArrayAppend(loc.sql.select, "ROW_NUMBER() OVER (ORDER BY #ArrayToList(loc.sql.orders, ', ')#) AS rowNum");
					
					// remove LIMIT and OFFSET from inner query
					StructDelete(loc.sql, "limit");
					StructDelete(loc.sql, "offset");
					
					// get SQL for inner query and return inside of SELECT
					return "SELECT * FROM (#super.visit_relation(obj=loc.obj)#) WHERE rowNum BETWEEN #loc.start# AND #loc.end#";
				
				// use TOP to restrict dataset instead of LIMIT
				} else {
					ArrayAppend(loc.sql.selectFlags, "TOP #loc.sql.limit#");
					StructDelete(loc.sql, "limit");
				}
			
			// if only offset is found
			} else if (loc.offset) {
				throwException("OFFSET not supported in Microsoft SQL Server");
			}
			
			return super.visit_relation(obj=loc.obj);
		</cfscript>
	</cffunction>
</cfcomponent>