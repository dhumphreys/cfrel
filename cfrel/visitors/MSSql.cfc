<cfcomponent extends="sql" output="false">

	<cffunction name="visit_relation" returntype="any" access="private" hint="Generate SQL for a relation specific to MSSQL">
		<cfscript>
			var loc = {};
			
			// get private sql scope of relation
			loc.obj = injectInspector(arguments.obj)._inspect();
			
			// see if limits or offsets exist
			loc.limit = StructKeyExists(loc.obj.sql, "limit");
			loc.offset = StructKeyExists(loc.obj.sql, "offset");
			
			// if limit is found
			if (loc.limit) {
				
				// subquery to accomplish pagination
				if (loc.offset) {
					throwException("Pagination not yet implemented for Microsoft SQL Server");
				
				// add TOP flag to restrict dataset
				} else {
					ArrayAppend(loc.obj.sql.selectFlags, "TOP #loc.obj.sql.limit#");
				}
				
				// remove limit from sql
				StructDelete(loc.obj.sql, "limit");
			
			// if only offset is found
			} else if (loc.offset) {
				throwException("OFFSET not supported in Microsoft SQL Server");
			}
			
			return super.visit_relation(obj=arguments.obj);
		</cfscript>
	</cffunction>
</cfcomponent>