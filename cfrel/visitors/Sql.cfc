<cfcomponent extends="visitor" output="false">
	
	<cffunction name="visit_relation" returntype="any" access="private">
		<cfscript>
			var loc = {};
			
			// set some control variables to reduce load
			loc.select = false;
			
			// get private sql scope of relation
			injectInspector(arguments.obj);
			loc.sql = arguments.obj._inspect().sql;
			
			// set up fragments array
			loc.fragments = [];
			
			// generate SELECT clause
			if (ArrayLen(loc.sql.select) EQ 0) {
				ArrayAppend(loc.fragments, "SELECT *");
			} else {
				ArrayAppend(loc.fragments, "SELECT " & ArrayToList(loc.sql.select, ", "));
				loc.select = true;
			}
			
			// generate FROM clause, evaluating another relation if neccessary
			if (StructKeyExists(loc.sql, "from")) {
				if (IsSimpleValue(loc.sql.from))
					ArrayAppend(loc.fragments, "FROM #loc.sql.from#");
				else
					ArrayAppend(loc.fragments, "FROM (#visit(loc.sql.from)#)");
					
			// error if neither SELECT or FROM was specified
			} else if (loc.select EQ false) {
				throwException("Either SELECT or FROM must be specified in relation");
			}
			
			// generate other clauses
			_appendConditionsClause("WHERE", loc.fragments, loc.sql.wheres);
			_appendFieldsClause("ORDER BY", loc.fragments, loc.sql.orders);
			_appendFieldsClause("GROUP BY", loc.fragments, loc.sql.groups);
			_appendConditionsClause("HAVING", loc.fragments, loc.sql.havings);
			
			// generate LIMIT clause
			if (StructKeyExists(loc.sql, "limit"))
				ArrayAppend(loc.fragments, "LIMIT #loc.sql.limit#");
				
			// generate OFFSET clause
			if (StructKeyExists(loc.sql, "offset") AND loc.sql.offset GT 0)
				ArrayAppend(loc.fragments, "OFFSET #loc.sql.offset#")
				
			// return sql string
			return ArrayToList(loc.fragments, " ");
		</cfscript>
	</cffunction>
	
	<!-----------------------
	--- Private Functions ---
	------------------------>
	
	<cffunction name="_appendFieldsClause" returntype="void" access="private">
		<cfargument name="clause" type="string" required="true" />
		<cfargument name="dest" type="array" required="true" />
		<cfargument name="src" type="array" required="true" />
		<cfscript>
			if (ArrayLen(arguments.src))
				ArrayAppend(arguments.dest, "#UCase(arguments.clause)# " & ArrayToList(arguments.src, ", "));
		</cfscript>
	</cffunction>
	
	<cffunction name="_appendConditionsClause" returntype="void" access="private">
		<cfargument name="clause" type="string" required="true" />
		<cfargument name="dest" type="array" required="true" />
		<cfargument name="src" type="array" required="true" />
		<cfscript>
			var loc = {};
			loc.iEnd = ArrayLen(arguments.src);
			
			// quit execution if needed
			if (loc.iEnd EQ 0)
				return;
				
			// wrap clauses containing OR in parenthesis
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
				if (REFind("\bOR\b", arguments.src[loc.i]) GT 0)
					arguments.src[loc.i] = "(#arguments.src[loc.i]#)";
			
			ArrayAppend(arguments.dest, "#UCase(arguments.clause)# " & ArrayToList(arguments.src, " AND "));
		</cfscript>
	</cffunction>
</cfcomponent>