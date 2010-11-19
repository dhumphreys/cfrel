<cfcomponent extends="sql" output="false">

	<cffunction name="visit_relation" returntype="any" access="private" hint="Generate SQL for a relation specific to MSSQL">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			
			// see if limits or offsets exist
			loc.limit = StructKeyExists(obj.sql, "limit");
			loc.offset = StructKeyExists(obj.sql, "offset");
			
			// if limit is found
			if (loc.limit) {
				
				// duplicate relation to keep old one intact
				obj = obj.clone();
				
				// use ROW_NUMBER() in a sub-query to accomplish pagination
				if (loc.offset) {
					
					// calculate row number range
					loc.start = obj.sql.offset + 1;
					loc.end = obj.sql.offset + obj.sql.limit;
					
					// throw error if there is no ORDER BY
					if (ArrayLen(obj.sql.orders) EQ 0)
						throwException("ORDER BY clause is required for pagination");
					
					// create new SELECT item from inner query
					ArrayAppend(obj.sql.select, literal("ROW_NUMBER() OVER (ORDER BY #ArrayToList(obj.sql.orders, ', ')#) AS rowNum"));
					
					// remove LIMIT and OFFSET from inner query
					StructDelete(obj.sql, "limit");
					StructDelete(obj.sql, "offset");
					
					// get SQL for inner query and return inside of SELECT
					return "SELECT * FROM (#super.visit_relation(obj)#) WHERE rowNum BETWEEN #loc.start# AND #loc.end#";
				
				// use TOP to restrict dataset instead of LIMIT
				} else {
					ArrayAppend(obj.sql.selectFlags, "TOP #obj.sql.limit#");
					StructDelete(obj.sql, "limit");
				}
			
			// if only offset is found
			} else if (loc.offset) {
				throwException("OFFSET not supported in Microsoft SQL Server");
			}
			
			return super.visit_relation(obj);
		</cfscript>
	</cffunction>
</cfcomponent>