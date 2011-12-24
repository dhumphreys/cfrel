<cfcomponent output="false">
	<cfinclude template="../functions.cfm" />
	
	<cffunction name="init">
		<cfscript>
			variables.aliasOnly = false;
			variables.aliasOff = false;
			variables.queryCounter = 1;
			variables.subQueryCounter = 1;
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="traverseToString" returntype="string" access="public" hint="Return tree traversal as SQL string">
		<cfargument name="tree" type="any" required="true" />
		<cfreturn sqlArrayToString(traverseToArray(arguments.tree)) />
	</cffunction>
	
	<cffunction name="traverseToArray" returntype="array" access="public" hint="Return tree traversal as flat array of nodes">
		<cfargument name="tree" type="any" required="true" />
		<cfreturn flattenArray(visit(arguments.tree)) />
	</cffunction>
	
	<cffunction name="visit" returntype="any" access="public" hint="Visit a particular object">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			var method = 0;
			
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
				variables.queryCounter = variables.subQueryCounter = 1;
			
			// set some control variables to reduce load
			loc.select = false;
			
			// set up fragments array
			loc.fragments = [];
			
			// turn aliasing on in select clause
			loc.aliasOff = variables.aliasOff;
			variables.aliasOff = false;
			
			// generate SELECT clause
			ArrayAppend(loc.fragments, "SELECT");
			if (ArrayLen(obj.sql.selectFlags) GT 0)
				ArrayAppend(loc.fragments, visit(obj.sql.selectFlags));
			if (ArrayLen(obj.sql.select) EQ 0) {
				ArrayAppend(loc.fragments, "*");
			} else {
				ArrayAppend(loc.fragments, separateArray(visit(obj.sql.select)));
				loc.select = true;
			}
			
			// generate FROM arguments
			if (ArrayLen(obj.sql.froms) GT 0) {
				ArrayAppend(loc.fragments, ["FROM", separateArray(visit(obj.sql.froms))]);
					
			// error if neither SELECT or FROM was specified
			} else if (loc.select EQ false) {
				throwException("Either SELECT or FROM must be specified in relation");
			}
			
			// turn aliasing off outside of SELECT clause
			variables.aliasOff = true;
 			
			// append joins
			if (ArrayLen(obj.sql.joins) GT 0)
				ArrayAppend(loc.fragments, visit(obj.sql.joins));
			
			// generate other clauses
			loc.fragments = _appendConditionsClause("WHERE", loc.fragments, obj.sql.wheres);
			loc.fragments = _appendFieldsClause("GROUP BY", loc.fragments, obj.sql.groups);
			loc.fragments = _appendConditionsClause("HAVING", loc.fragments, obj.sql.havings);
			loc.fragments = _appendFieldsClause("ORDER BY", loc.fragments, obj.sql.orders);
			
			// turn aliasing back on
			variables.aliasOff = loc.aliasOff;
			
			// generate LIMIT clause
			if (StructKeyExists(obj.sql, "limit"))
				ArrayAppend(loc.fragments, "LIMIT #obj.sql.limit#");
				
			// generate OFFSET clause
			if (StructKeyExists(obj.sql, "offset") AND obj.sql.offset GT 0)
				ArrayAppend(loc.fragments, "OFFSET #obj.sql.offset#");
				
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
				ArrayAppend(loc.rtn, visit(arguments.obj[loc.i]));
				
			return loc.rtn;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_query" returntype="string" access="private" hint="Render a query as a QOQ reference">
		<cfargument name="obj" type="query" required="true" />
		<cfreturn "query" & variables.queryCounter++ />
	</cffunction>
	
	<cffunction name="visit_model" returntype="string" access="private" hint="Visit a CFWheels model">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			// todo: move logic to mapper
			return _escapeSqlEntity(arguments.obj.$classData().tableName);
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
			if (variables.aliasOnly) {
				loc.sql = _escapeSqlEntity(obj.alias);
				
			// don't use alias, only subject
			} else if (variables.aliasOff) {
				loc.sql = visit(obj.subject);
				
			// use both, but ignore any aliases inside of subject
			} else {
				
				loc.aliasOff = variables.aliasOff;
				variables.aliasOff = true;
				loc.sql = [visit(obj.subject), "AS #_escapeSqlEntity(obj.alias)#"];
				variables.aliasOff = loc.aliasOff;
			}
			
			return loc.sql;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_between" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn [visit(obj.subject), "BETWEEN", visit(obj.start), "AND", visit(obj.end)] />
	</cffunction>
	
	<cffunction name="visit_nodes_binaryOp" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			loc.returnValue = [visit(obj.left), REReplace(obj.op, "_", " ", "ALL"), visit(obj.right)];
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
				ArrayAppend(loc.output, visit(obj.subject));
			if (ArrayLen(obj.cases))
				ArrayAppend(loc.output, visit(obj.cases));
			if (NOT IsSimpleValue(obj.els) OR obj.els NEQ "")
				ArrayAppend(loc.output, ["ELSE", visit(obj.els)]);
			ArrayAppend(loc.output, "END");
			return loc.output;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_caseCondition" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn ["WHEN", visit(obj.condition), "THEN", visit(obj.subject)] />
	</cffunction>
	
	<cffunction name="visit_nodes_cast" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn ["CAST(", visit(obj.subject), "AS #visit(obj.type)#)"] />
	</cffunction>
	
	<cffunction name="visit_nodes_column" returntype="string" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			
			// read alias unless we have them turned off
			loc.alias = NOT variables.aliasOff AND Len(obj.alias) ? " AS #_escapeSqlEntity(obj.alias)#" : "";
			
			// only use alias if we have asked to do so
			if (variables.aliasOnly AND Len(loc.alias))
				return _escapeSqlEntity(obj.alias);
			
			if (StructKeyExists(obj, "mapping"))
				return _escapeSqlEntity(visit(obj.mapping.value)) & loc.alias;
			
			// read table specified for column
			loc.table = Len(obj.table) ? _escapeSqlEntity(obj.table) & "." : "";
			
			return loc.table & _escapeSqlEntity(obj.column) & loc.alias;
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
			ArrayAppend(loc.join, visit(obj.table));
			if (IsStruct(obj.condition) OR obj.condition NEQ false)
				ArrayAppend(loc.join, ["ON", visit(obj.condition)]);
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
			loc.aliasOff = variables.aliasOff;
			variables.aliasOff = true;
			if (NOT IsSimpleValue(obj.scope) OR obj.scope NEQ "")
				ArrayAppend(loc.fn, [visit(obj.scope), "."]);
			ArrayAppend(loc.fn, "#obj.name#(");
			if (obj.distinct)
				ArrayAppend(loc.fn, "DISTINCT");
			ArrayAppend(loc.fn, separateArray(visit(obj.args)));
			ArrayAppend(loc.fn, ")");
			variables.aliasOff = loc.aliasOff;
			return loc.fn;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_order" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn [visit(obj.subject), iif(obj.descending, DE("DESC"), DE("ASC"))] />
	</cffunction>
	
	<cffunction name="visit_nodes_param" returntype="any" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			// TODO: map column type here
			if (StructKeyExists(arguments.obj, "column"))
				StructDelete(arguments, "column");
			
			// if value is an array, set up list params
			if (IsArray(arguments.obj.value)) {
				arguments.obj.value = ArrayToList(arguments.obj.value, Chr(7));
				arguments.obj.list = true;
				arguments.obj.null = ArrayLen(loc.parameters[loc.i]) EQ 0;
				arguments.obj.separator = Chr(7);
			}
			
			return arguments.obj;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_paren" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			loc.subject = separateArray(arguments.obj.subject);
			ArrayPrepend(loc.subject, "(");
			ArrayAppend(loc.subject, ")");
			return loc.subject;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_subquery" returntype="array" access="private" hint="Render a subquery with an alias">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn ["(", visit(obj=arguments.obj.subject, top=false), ") subquery#variables.subQueryCounter++#"] />
	</cffunction>
	
	<cffunction name="visit_nodes_table" returntype="string" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			if (Len(obj.table) EQ 0)
				throwException("No table defined.");
			loc.table = _escapeSqlEntity(obj.table);
			if (Len(obj.alias))
				loc.table &= " " & _escapeSqlEntity(obj.alias);
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
	
	<cffunction name="visit_nodes_unaryOp" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn [obj.op, visit(obj.subject)] />
	</cffunction>
	
	<cffunction name="visit_nodes_wildcard" returntype="string" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			// TODO: perform wildcard mapping here
			if (NOT variables.aliasOff AND StructKeyExists(obj, "mapping") AND ArrayLen(obj.mapping))
				return ArrayToList(visit(obj.mapping), ",");
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
				ArrayAppend(arguments.dest, [UCase(arguments.clause), separateArray(visit(arguments.src))]);
			return arguments.dest;
		</cfscript>
	</cffunction>
	
	<cffunction name="_appendConditionsClause" returntype="array" access="private" hint="Concat and append conditions to an array">
		<cfargument name="clause" type="string" required="true" />
		<cfargument name="dest" type="array" required="true" />
		<cfargument name="src" type="array" required="true" />
		<cfscript>
			var loc = {};
			
			// don't do anything if array is empty
			if (ArrayLen(arguments.src) EQ 0)
				return arguments.dest;
			
			// append and return array with new conditions
			ArrayAppend(arguments.dest, [UCase(arguments.clause), separateArray(visit(arguments.src), "AND")]);
			return arguments.dest;
		</cfscript>
	</cffunction>
	
	<cffunction name="_escapeSqlEntity" returntype="string" access="private" hint="Escape SQL column and table names">
		<cfargument name="subject" type="string" required="true" />
		<cfreturn arguments.subject />
	</cffunction>
</cfcomponent>