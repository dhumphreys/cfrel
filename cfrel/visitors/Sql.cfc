<cfcomponent extends="visitor" output="false">
	
	<cffunction name="visit_relation" returntype="any" access="private" hint="Generate general SQL for a relation">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			
			// set some control variables to reduce load
			loc.select = false;
			
			// set up fragments array
			loc.fragments = [];
			
			// generate SELECT clause
			loc.clause = "SELECT ";
			if (ArrayLen(obj.sql.selectFlags) GT 0)
				loc.clause &= ArrayToList(visit(obj.sql.selectFlags), " ") & " ";
			if (ArrayLen(obj.sql.select) EQ 0) {
				loc.clause &= "*";
			} else {
				loc.clause &= ArrayToList(visit(obj.sql.select), ", ");
				loc.select = true;
			}
			ArrayAppend(loc.fragments, loc.clause);
			
			// generate FROM clause, evaluating another relation if neccessary
			if (StructKeyExists(obj.sql, "from")) {
				if (IsSimpleValue(obj.sql.from))
					ArrayAppend(loc.fragments, "FROM #visit(obj.sql.from)#");
				else if (IsQuery(obj.sql.from))
					ArrayAppend(loc.fragments, "FROM resultSet");
				else
					ArrayAppend(loc.fragments, "FROM (#visit(obj.sql.from)#)");
					
			// error if neither SELECT or FROM was specified
			} else if (loc.select EQ false) {
				throwException("Either SELECT or FROM must be specified in relation");
			}
			
			// generate other clauses
			loc.fragments = _appendConditionsClause("WHERE", loc.fragments, obj.sql.wheres);
			loc.fragments = _appendFieldsClause("ORDER BY", loc.fragments, obj.sql.orders);
			loc.fragments = _appendFieldsClause("GROUP BY", loc.fragments, obj.sql.groups);
			loc.fragments = _appendConditionsClause("HAVING", loc.fragments, obj.sql.havings);
			
			// generate LIMIT clause
			if (StructKeyExists(obj.sql, "limit"))
				ArrayAppend(loc.fragments, "LIMIT #obj.sql.limit#");
				
			// generate OFFSET clause
			if (StructKeyExists(obj.sql, "offset") AND obj.sql.offset GT 0)
				ArrayAppend(loc.fragments, "OFFSET #obj.sql.offset#");
				
			// return sql string
			return ArrayToList(loc.fragments, " ");
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_literal" returntype="string" access="private" hint="Render a literal SQL string">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn arguments.obj.content />
	</cffunction>
	
	<cffunction name="visit_simple" returntype="any" access="private" hint="Render a simple value by just returning it">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn arguments.obj />
	</cffunction>
	
	<cffunction name="visit_array" returntype="array" access="private" hint="Call visit on each element of array">
		<cfargument name="obj" type="array" required="true" />
		<cfscript>
			var loc = {};
			loc.rtn = [];
			loc.iEnd = ArrayLen(arguments.obj);
			
			// loop over each item and call visit
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
				ArrayAppend(loc.rtn, visit(arguments.obj[loc.i]));
				
			return loc.rtn;
		</cfscript>
	</cffunction>
	
	<!-----------------------
	--- Private Functions ---
	------------------------>
	
	<cffunction name="_appendFieldsClause" returntype="array" access="private" hint="Concat and append field list to an array">
		<cfargument name="clause" type="string" required="true" />
		<cfargument name="dest" type="array" required="true" />
		<cfargument name="src" type="array" required="true" />
		<cfscript>
			if (ArrayLen(arguments.src))
				ArrayAppend(arguments.dest, "#UCase(arguments.clause)# " & ArrayToList(visit(arguments.src), ", "));
			return arguments.dest;
		</cfscript>
	</cffunction>
	
	<cffunction name="_appendConditionsClause" returntype="array" access="private" hint="Concat and append conditions to an array">
		<cfargument name="clause" type="string" required="true" />
		<cfargument name="dest" type="array" required="true" />
		<cfargument name="src" type="array" required="true" />
		<cfscript>
			var loc = {};
			loc.iEnd = ArrayLen(arguments.src);
			
			// quit execution if needed
			if (loc.iEnd EQ 0)
				return arguments.dest;
				
			// wrap clauses containing OR in parenthesis
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
				if (REFind("\bOR\b", arguments.src[loc.i]) GT 0)
					arguments.src[loc.i] = "(#arguments.src[loc.i]#)";
			
			// append and return array
			ArrayAppend(arguments.dest, "#UCase(arguments.clause)# " & ArrayToList(arguments.src, " AND "));
			return arguments.dest;
		</cfscript>
	</cffunction>
</cfcomponent>