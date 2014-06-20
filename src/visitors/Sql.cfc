<cfcomponent output="false">
	<cfinclude template="../functions.cfm" />
	
	<cffunction name="init" returntype="any" access="public" hint="Constructor">
		<cfscript>
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="traverseToString" returntype="string" access="public" hint="Return tree traversal as SQL string">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn sqlArrayToString(traverseToArray(argumentCollection=arguments)) />
	</cffunction>
	
	<cffunction name="traverseToArray" returntype="array" access="public" hint="Return tree traversal as flat array of nodes">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn flattenArray(visit(argumentCollection=arguments)) />
	</cffunction>
	
	<cffunction name="visit" returntype="any" access="public" hint="Visit a particular object">
		<cfargument name="obj" type="any" required="true" />
		<cfargument name="state" type="struct" required="false" />
		<cfscript>
			var loc = {};
			var method = 0;

			// create a new state if one is not passed in
			if (NOT StructKeyExists(arguments, "state"))
				arguments.state = newState();
			
			// find type of object
			loc.type = typeOf(arguments.obj);
			
			// get classname of component passed in (and shorten name for cfrel.xxx.yyy to xxx.yyy)
			if (REFind("^(\w+)(\.\w+)+$", loc.type))
				loc.type = REREplace(Replace(loc.type, ".", "_", "ALL"), "^cfrel_", "");
			
			// construct method name for type. throw exception if it doesnt exist
			loc.method = "visit_#loc.type#";
			if (NOT StructKeyExists(variables, loc.method))
				throwException("No visitor exists for type: #loc.type#");
			
			// call visit_xxx_yyy method
			method = variables[loc.method];
			return method(argumentCollection=arguments);
		</cfscript>
	</cffunction>
	
	<!-------------------
	--- Main Visitors ---
	-------------------->
	
	<cffunction name="visit_relation" returntype="array" access="private" hint="Generate general SQL for a relation">
		<cfargument name="obj" type="any" required="true" />
		<cfargument name="top" type="boolean" default="true" />
		<cfscript>
			var loc = {};
			
			// clear out query and subquery counters when response is top-level
			if (arguments.top)
				arguments.state = newState();
			
			// push relation onto stack for mapping
			ArrayPrepend(arguments.state.relations, arguments.obj);
			
			// set some control variables to reduce load
			loc.select = false;
			
			// set up fragments array
			loc.fragments = [];
			
			// turn aliasing on in select clause
			loc.aliasOff = arguments.state.aliasOff;
			arguments.state.aliasOff = false;
			
			// generate SELECT clause
			ArrayAppend(loc.fragments, "SELECT");
			if (ArrayLen(obj.sql.selectFlags) GT 0)
				ArrayAppend(loc.fragments, visit(obj=obj.sql.selectFlags, argumentCollection=arguments));
			if (ArrayLen(obj.sql.select) EQ 0) {
				ArrayAppend(loc.fragments, visit(obj=sqlWildcard(), argumentCollection=arguments));
			} else {
				ArrayAppend(loc.fragments, separateArray(visit(obj=obj.sql.select, argumentCollection=arguments)));
				loc.select = true;
			}
			
			// generate FROM arguments
			if (ArrayLen(obj.sql.froms) GT 0) {
				ArrayAppend(loc.fragments, ["FROM", separateArray(visit(obj=obj.sql.froms, argumentCollection=arguments))]);
					
			// error if neither SELECT or FROM was specified
			} else if (loc.select EQ false) {
				throwException("Either SELECT or FROM must be specified in relation");
			}
			
			// turn aliasing off outside of SELECT clause
			arguments.state.aliasOff = true;
 			
			// append joins
			if (ArrayLen(obj.sql.joins) GT 0)
				ArrayAppend(loc.fragments, visit(obj=obj.sql.joins, argumentCollection=arguments));
			
			// append where clause
			if (ArrayLen(obj.sql.wheres))
				ArrayAppend(loc.fragments, ["WHERE", separateArray(visit(obj=obj.sql.wheres, argumentCollection=arguments), "AND")]);

			// append group by clause
			if (ArrayLen(obj.sql.groups))
				ArrayAppend(loc.fragments, ["GROUP BY", separateArray(visit(obj=obj.sql.groups, argumentCollection=arguments))]);

			// append having clause
			if (ArrayLen(obj.sql.havings))
				ArrayAppend(loc.fragments, ["HAVING", separateArray(visit(obj=obj.sql.havings, argumentCollection=arguments), "AND")]);

			// append order clause
			if (ArrayLen(obj.sql.orders))
				ArrayAppend(loc.fragments, ["ORDER BY", separateArray(visit(obj=obj.sql.orders, argumentCollection=arguments))]);
			
			// turn aliasing back on
			arguments.state.aliasOff = loc.aliasOff;
			
			// generate LIMIT clause
			if (StructKeyExists(obj.sql, "limit"))
				ArrayAppend(loc.fragments, "LIMIT #obj.sql.limit#");
				
			// generate OFFSET clause
			if (StructKeyExists(obj.sql, "offset") AND obj.sql.offset GT 0)
				ArrayAppend(loc.fragments, "OFFSET #obj.sql.offset#");
			
			// pop relation off of stack for mapping
			ArrayDeleteAt(arguments.state.relations, 1);
				
			// return sql array
			return loc.fragments;
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
				ArrayAppend(loc.rtn, visit(obj=arguments.obj[loc.i], argumentCollection=arguments));
				
			return loc.rtn;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_query" returntype="string" access="private" hint="Render a query as a QOQ reference">
		<cfargument name="obj" type="query" required="true" />
		<cfreturn "query" & arguments.state.queryCounter++ />
	</cffunction>
	
	<cffunction name="visit_model" returntype="string" access="private" hint="Visit a CFWheels model">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			// todo: move logic to mapper
			return escape(arguments.obj.$classData().tableName);
		</cfscript>
	</cffunction>
	
	<!-------------------
	--- Node Visitors ---
	-------------------->
	
	<cffunction name="visit_nodes_alias" returntype="any" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			
			// only use alias
			if (arguments.state.aliasOnly) {
				loc.sql = escape(obj.alias);
				
			// don't use alias, only subject
			} else if (arguments.state.aliasOff) {
				loc.sql = visit(obj=obj.subject, argumentCollection=arguments);
				
			// use both, but ignore any aliases inside of subject
			} else {
				
				loc.aliasOff = arguments.state.aliasOff;
				arguments.state.aliasOff = true;
				loc.sql = [visit(obj=obj.subject, argumentCollection=arguments), "AS #escape(obj.alias)#"];
				arguments.state.aliasOff = loc.aliasOff;
			}
			
			return loc.sql;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_between" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn [visit(obj=obj.subject, argumentCollection=arguments), "BETWEEN", visit(obj=obj.start, argumentCollection=arguments), "AND", visit(obj=obj.end, argumentCollection=arguments)] />
	</cffunction>
	
	<cffunction name="visit_nodes_binaryOp" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			loc.returnValue = [visit(obj=obj.left, argumentCollection=arguments), REReplace(obj.op, "_", " ", "ALL"), visit(obj=obj.right, argumentCollection=arguments)];
			if (obj.op EQ "OR") {
				ArrayPrepend(loc.returnValue, "(");
				ArrayAppend(loc.returnValue, ")");
			}
			return loc.returnValue;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_case" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			loc.output = ["CASE"];
			if (NOT IsSimpleValue(obj.subject) OR obj.subject NEQ "")
				ArrayAppend(loc.output, visit(obj=obj.subject, argumentCollection=arguments));
			if (ArrayLen(obj.cases))
				ArrayAppend(loc.output, visit(obj=obj.cases, argumentCollection=arguments));
			if (NOT IsSimpleValue(obj.els) OR obj.els NEQ "")
				ArrayAppend(loc.output, ["ELSE", visit(obj=obj.els, argumentCollection=arguments)]);
			ArrayAppend(loc.output, "END");
			return loc.output;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_caseCondition" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn ["WHEN", visit(obj=obj.condition, argumentCollection=arguments), "THEN", visit(obj=obj.subject, argumentCollection=arguments)] />
	</cffunction>
	
	<cffunction name="visit_nodes_cast" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn ["CAST(", visit(obj=obj.subject, argumentCollection=arguments), "AS #visit(obj=obj.type, argumentCollection=arguments)#)"] />
	</cffunction>
	
	<cffunction name="visit_nodes_column" returntype="string" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			
			// map the column
			arguments.obj = $relation(arguments.state).mapColumn(arguments.obj);
			
			// read alias unless we have them turned off
			// TODO: clean up this logic
			loc.alias = NOT arguments.state.aliasOff AND Len(obj.alias) ? " AS #escape(obj.alias)#" : "";
			
			// only use alias if we have asked to do so
			if (arguments.state.aliasOnly AND Len(loc.alias))
				return escape(obj.alias);
			
			// use sql mapping instead of column if specified
			if (StructKeyExists(obj, "sql"))
				return escape(visit(obj=obj.sql, argumentCollection=arguments)) & loc.alias;
			
			// remove alias if column equals alias
			if (ListLast(obj.column, ".") EQ obj.alias)
				loc.alias = "";
			
			return escape(obj.column) & loc.alias;
		</cfscript>
	</cffunction>
 	
	<cffunction name="visit_nodes_join" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			loc.join = ["JOIN"];
			switch(obj.type) {
				case "outer": loc.join[1] = "LEFT JOIN"; break;
				case "cross": loc.join[1] = "CROSS JOIN"; break;
				case "natural": loc.join[1] = "NATURAL JOIN"; break;
			}
			ArrayAppend(loc.join, visit(obj=obj.table, argumentCollection=arguments));
			if (IsStruct(obj.condition) OR obj.condition NEQ false)
				ArrayAppend(loc.join, ["ON", visit(obj=obj.condition, argumentCollection=arguments)]);
			return loc.join;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_literal" returntype="string" access="private" hint="Render a literal SQL string">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn arguments.obj.subject />
	</cffunction>
	
	<cffunction name="visit_nodes_function" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			loc.fn = [];
			loc.aliasOff = arguments.state.aliasOff;
			arguments.state.aliasOff = true;
			if (NOT IsSimpleValue(obj.scope) OR obj.scope NEQ "")
				ArrayAppend(loc.fn, [visit(obj=obj.scope, argumentCollection=arguments), "."]);
			ArrayAppend(loc.fn, "#obj.name#(");
			if (obj.distinct)
				ArrayAppend(loc.fn, "DISTINCT");
			ArrayAppend(loc.fn, separateArray(visit(obj=obj.args, argumentCollection=arguments)));
			ArrayAppend(loc.fn, ")");
			arguments.state.aliasOff = loc.aliasOff;
			return loc.fn;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_order" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn [visit(obj=obj.subject, argumentCollection=arguments), iif(obj.descending, DE("DESC"), DE("ASC"))] />
	</cffunction>
	
	<cffunction name="visit_nodes_param" returntype="any" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			// map the parameter data type
			arguments.obj = $relation(arguments.state).mapParameter(arguments.obj);
			
			// if value is an array, set up list params
			if (IsArray(arguments.obj.value)) {
				arguments.obj.null = ArrayLen(arguments.obj.value) EQ 0;
				arguments.obj.value = ArrayToList(arguments.obj.value, Chr(7));
				arguments.obj.list = true;
				arguments.obj.separator = Chr(7);
			}
			
			return arguments.obj;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_paren" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn ["(", visit(obj=arguments.obj.subject, argumentCollection=arguments), ")"] />
	</cffunction>
	
	<cffunction name="visit_nodes_subquery" returntype="array" access="private" hint="Render a subquery with an alias">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn ["(", visit(obj=arguments.obj.subject, top=false), ") subquery#arguments.state.subQueryCounter++#"] />
	</cffunction>
	
	<cffunction name="visit_nodes_table" returntype="string" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			if (Len(obj.table) EQ 0)
				throwException("No table defined.");
			loc.table = escape(obj.table);
			if (Len(obj.alias) AND obj.table NEQ obj.alias)
				loc.table &= " " & escape(obj.alias);
			return loc.table;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_model" returntype="string" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			return "#escape(arguments.obj.table)# #escape(arguments.obj.alias)#";
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
	
	<cffunction name="visit_nodes_unaryOp" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn [obj.op, visit(obj=obj.subject, argumentCollection=arguments)] />
	</cffunction>
	
	<cffunction name="visit_nodes_wildcard" returntype="string" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			// map wildcard
			arguments.obj = $relation(arguments.state).mapWildcard(arguments.obj);
			
			// decide which wildcard behavior to use
			if (NOT arguments.state.aliasOff AND StructKeyExists(obj, "mapping") AND ArrayLen(obj.mapping))
				return ArrayToList(visit(obj=obj.mapping, argumentCollection=arguments), ", ");
			else
				return obj.subject NEQ "" ? "#visit(obj=obj.subject, argumentCollection=arguments)#.*" : "*";
		</cfscript>
	</cffunction>
	
	<!-----------------------
	--- Private Functions ---
	------------------------>
	
	<cffunction name="escape" returntype="string" access="private" hint="Escape SQL column and table names">
		<cfargument name="subject" type="string" required="true" />
		<cfreturn arguments.subject />
	</cffunction>

	<cffunction name="newState" returntype="struct" access="private" hint="Construct an object for holding state-related variables">
		<cfscript>
			var loc.state = {};
			loc.state.aliasOnly = false;
			loc.state.aliasOff = false;
			loc.state.queryCounter = 1;
			loc.state.subQueryCounter = 1;
			loc.state.relations = [];
			return loc.state;
		</cfscript>
	</cffunction>
	
	<cffunction name="$relation" returntype="any" access="private" hint="Return top relation from the stack">
		<cfargument name="state" type="struct" required="true" />
		<cfscript>
			if (ArrayLen(arguments.state.relations) EQ 0)
				return relation();
			return arguments.state.relations[1];
		</cfscript>
	</cffunction>
</cfcomponent>