<cfcomponent extends="Visitor" output="false">
	
	<cffunction name="init">
		<cfscript>
			variables.aliasOnly = false;
			variables.aliasOff = false;
			return this;
		</cfscript>
	</cffunction>
	
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
				if (IsSimpleValue(obj.sql.from) OR typeOf(obj.sql.from) EQ "cfrel.nodes.table")
					ArrayAppend(loc.fragments, "FROM #visit(obj.sql.from)#");
				else if (IsQuery(obj.sql.from))
					ArrayAppend(loc.fragments, "FROM resultSet");
				else
					ArrayAppend(loc.fragments, "FROM (#visit(obj.sql.from)#) subquery");
					
			// error if neither SELECT or FROM was specified
			} else if (loc.select EQ false) {
				throwException("Either SELECT or FROM must be specified in relation");
			}
			
			// turn aliasing off outside of SELECT clause
			variables.aliasOff = true;
 			
			// append joins
			if (ArrayLen(obj.sql.joins) GT 0)
				ArrayAppend(loc.fragments, ArrayToList(visit(obj.sql.joins), " "));
			
			// generate other clauses
			loc.fragments = _appendConditionsClause("WHERE", loc.fragments, obj.sql.wheres);
			loc.fragments = _appendFieldsClause("GROUP BY", loc.fragments, obj.sql.groups);
			loc.fragments = _appendConditionsClause("HAVING", loc.fragments, obj.sql.havings);
			loc.fragments = _appendFieldsClause("ORDER BY", loc.fragments, obj.sql.orders);
			
			// turn aliasing back on
			variables.aliasOff = false;
			
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
	
	<cffunction name="visit_model" returntype="string" access="private" hint="Visit a CFWheels model">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			// todo: move logic to mapper
			return arguments.obj.$classData().tableName;
		</cfscript>
	</cffunction>
	
	<!-------------------
	--- Node Visitors ---
	-------------------->
	
	<cffunction name="visit_nodes_alias" returntype="string" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			
			// only use alias
			if (variables.aliasOnly) {
				loc.sql = visit(obj.alias);
				
			// don't use alias, only subject
			} else if (variables.aliasOff) {
				loc.sql = visit(obj.subject);
				
			// use both, but ignore any aliases inside of subject
			} else {
				
				variables.aliasOff = true;
				loc.sql = "#visit(obj.subject)# AS #visit(obj.alias)#";
				variables.aliasOff = false;
			}
			
			return loc.sql;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_between" returntype="string" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn "#visit(obj.subject)# BETWEEN #visit(obj.start)# AND #visit(obj.end)#" />
	</cffunction>
	
	<cffunction name="visit_nodes_binaryOp" returntype="string" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			
			// render the parts of the operation
			loc.op = REReplace(obj.op, "_", " ", "ALL");
			loc.left = visit(obj.left);
			loc.right = visit(obj.right);
			return "#loc.left# #loc.op# #loc.right#";
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_cast" returntype="string" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			return "CAST(#visit(obj.subject)# AS #visit(obj.type)#)";
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_column" returntype="string" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			// todo: escape field correctly
			var loc = {};
			
			// read alias unless we have them turned off
			loc.alias = NOT variables.aliasOff AND Len(obj.alias) ? " AS #obj.alias#" : "";
			
			// only use alias if we have asked to do so
			if (variables.aliasOnly AND Len(loc.alias))
				return obj.alias;
			
			if (StructKeyExists(obj, "mapping"))
				return visit(obj.mapping.value) & loc.alias;
			
			// read table specified for column
			loc.table = Len(obj.table) ? obj.table & "." : "";
			
			return loc.table & obj.column & loc.alias;
		</cfscript>
	</cffunction>
 	
	<cffunction name="visit_nodes_join" returntype="string" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			loc.join = (obj.type EQ "outer") ? "LEFT JOIN " : "JOIN ";
			loc.join &= visit(obj.table);
			if (IsStruct(obj.condition) OR obj.condition EQ false)
				loc.join &= " ON #visit(obj.condition)#";
			return loc.join;
		</cfscript>
		<cfreturn arguments.obj.content />
	</cffunction>
	
	<cffunction name="visit_nodes_literal" returntype="string" access="private" hint="Render a literal SQL string">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn arguments.obj.subject />
	</cffunction>
	
	<cffunction name="visit_nodes_function" returntype="string" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			loc.tmpAliasOff = variables.aliasOff;
			variables.aliasOff = true;
			loc.fn = "#obj.name#(#ArrayToList(visit(obj.args), ', ')#)";
			variables.aliasOff = loc.tmpAliasOff;
			return loc.fn;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_order" returntype="string" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn obj.descending ? "#visit(obj.subject)# DESC" : "#visit(obj.subject)# ASC" />
	</cffunction>
	
	<cffunction name="visit_nodes_paren" returntype="string" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			loc.subject = visit(obj.subject);
			if (IsArray(loc.subject))
				loc.subject = ArrayToList(loc.subject, ", ");
			return "(#loc.subject#)";
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_table" returntype="string" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			if (Len(obj.table) EQ 0)
				throwException("No table defined.");
			loc.table = obj.table;
			if (Len(obj.alias))
				loc.table &= " " & obj.alias;
			return loc.table;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_type" returntype="string" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			loc.type = obj.name;
			if (Len(obj.val1) GT 0) {
				loc.type &= "(#obj.val1#";
				if (Len(obj.val2) GT 0)
					loc.type &= ",#obj.val2#";
				loc.type &= ")";
			}
			return loc.type;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_unaryOp" returntype="string" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn "#obj.op# #visit(obj.subject)#" />
	</cffunction>
	
	<cffunction name="visit_nodes_wildcard" returntype="string" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			if (NOT variables.aliasOff AND StructKeyExists(obj, "mapping") AND Len(obj.mapping))
				return obj.mapping;
			else
				return obj.subject NEQ "" ? "#visit(obj.subject)#.*" : "*";
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
			
			// visit arguments
			arguments.src = visit(arguments.src);
			
			// quit execution if needed
			if (loc.iEnd EQ 0)
				return arguments.dest;
				
			// wrap clauses containing OR in parenthesis
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
				if (loc.iEnd GT 1 AND REFind("\bOR\b", arguments.src[loc.i]) GT 0)
					arguments.src[loc.i] = "(#arguments.src[loc.i]#)";
			
			// append and return array
			ArrayAppend(arguments.dest, "#UCase(arguments.clause)# " & ArrayToList(visit(arguments.src), " AND "));
			return arguments.dest;
		</cfscript>
	</cffunction>
</cfcomponent>