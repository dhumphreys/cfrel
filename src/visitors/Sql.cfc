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
		<cfargument name="map" type="struct" required="false" />
		<cfargument name="state" type="struct" required="false" />
		<cfscript>
			var loc = {};
			var method = 0;

			// use a blank mapping table if one is not passed in
			if (NOT StructKeyExists(arguments, "map"))
				arguments.map = emptyMap();

			// create a new state if one is not passed in
			if (NOT StructKeyExists(arguments, "state"))
				arguments.state = newState(map=arguments.map);
			
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
		<cfscript>
			var loc = {};
			
			// create new state and pass in additional mappings
			arguments.map = arguments.obj.getMap();
			arguments.state = newState(map=arguments.map);
			
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

			// set default column and alias from column node
			loc.column = obj.column;
			loc.alias = loc.key = Len(obj.alias) ? obj.alias : obj.column;
			loc.calculated = false;

			// look up more specific mapping if it exists
			if (StructKeyExists(arguments.map.columns, loc.key)) {
				loc.calculated = arguments.map.columns[loc.key].calculated;
				loc.column = arguments.map.columns[loc.key].mapping;
				loc.alias = arguments.map.columns[loc.key].alias;
			} else {
				loc.alias = ListLast(loc.alias, ".");
			}

			// if we are in alias-only mode, just return the alias by itself
			if (arguments.state.aliasOnly)
				return escape(loc.alias);

			// if aliases are disabled, or the column and alias match, and we aren't using a calculated property, just return the column
			if (arguments.state.aliasOff OR (NOT loc.calculated AND ListLast(loc.column, ".") EQ loc.alias))
				return escape(loc.column);
			
			// return the column with its alias
			return escape(loc.column) & " AS " & escape(loc.alias);
		</cfscript>
	</cffunction>

	<cffunction name="visit_nodes_include" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			// look for a mapping that matches the include, erroring if one is not found
			if (NOT StructKeyExists(arguments.map.includes, arguments.obj.includeKey))
				throwException("No mapping found for include: '#arguments.obj.include#'");
			return visit(obj=arguments.map.includes[arguments.obj.includeKey], argumentCollection=arguments);
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
			var loc = {};

			// if no type is present on the parameter, attempt to find out what type it is
			if (StructKeyExists(obj, "column") AND NOT StructKeyExists(obj, "cfsqltype")) {
				loc.key = obj.column;
				StructDelete(obj, "column");

				// if possible, map the parameter to the column it references
				if (StructKeyExists(arguments.map.columns, loc.key) AND StructKeyExists(arguments.map.columns[loc.key], "cfsqltype"))
					obj.cfsqltype = arguments.map.columns[loc.key].cfsqltype;

				// if no mapping is found, give it our best guess
				// TODO: never do IsNumeric() for this check
				else
					obj.cfsqltype = IsNumeric(obj.value) ? "cf_sql_numeric" : "cf_sql_char";
			}
			
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
		<cfreturn ["(", visit(obj=arguments.obj.subject, argumentCollection=arguments), ")", visit(obj=sqlTable(table="subquery", alias=obj.alias), argumentCollection=arguments)] />
	</cffunction>
	
	<cffunction name="visit_nodes_query" returntype="string" access="private" hint="Render a query as a QOQ reference">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn visit(obj=sqlTable(table="query", alias=obj.alias), argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="visit_nodes_table" returntype="string" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};

			// determine default table and alias
			loc.table = obj.table;
			loc.alias = loc.key = Len(obj.alias) ? obj.alias : ListLast(loc.table, ".");

			// if a more reliable alias can be found, then use it and pop it off the stack
			if (StructKeyExists(arguments.state.aliases, loc.key) AND ArrayLen(arguments.state.aliases[loc.key])) {
				loc.alias = arguments.state.aliases[loc.key][1];
				ArrayDeleteAt(arguments.state.aliases[loc.key], 1);
				loc.table = arguments.map.tables[loc.alias].table;
			}

			// just return the table if it matches the alias
			if (ListLast(loc.table, ".") EQ loc.alias)
				return escape(loc.table);

			// otherwise, return the table with its alias
			return escape(loc.table) & " " & escape(loc.alias);
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_model" returntype="string" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn visit(obj=sqlTable(table=arguments.obj.model.$classData().modelName, alias=obj.alias), argumentCollection=arguments) />
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

			var loc = {};
			loc.columns = ArrayNew(1);

			// if aliases are enabled and there are tables/columns to be mapped
			if (NOT arguments.state.aliasOff AND StructCount(arguments.map.tables)) {
				loc.tables = Len(obj.subject) ? [obj.subject] : ListToArray(StructKeyList(arguments.map.tables));
				for (loc.tbl in loc.tables) {
					if (StructKeyExists(arguments.map.tables, loc.tbl)) {
						for (loc.col in arguments.map.tables[loc.tbl].properties)
							ArrayAppend(loc.columns, sqlColumn(
								column=arguments.map.tables[loc.tbl].properties[loc.col].mapping,
								alias=arguments.map.tables[loc.tbl].properties[loc.col].alias
							));
					}
				}
			}
			
			// if we found columns to map to, generate a list of them while skipping mappings
			if (ArrayLen(loc.columns)) {
				return ArrayToList(visit(obj=loc.columns, map=emptyMap(), argumentCollection=arguments), ", ");

			// if we only have a subject, return the subject with a star
			} else if (obj.subject NEQ "") {
				return escape(visit(obj=obj.subject, argumentCollection=arguments)) & ".*";

			// if we have nothing else, just return star
			} else {
				return "*";
			}
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
		<cfargument name="map" type="struct" required="true" />
		<cfscript>
			var loc.state = {};
			loc.state.aliasOnly = false;
			loc.state.aliasOff = false;
			loc.state.aliases = Duplicate(arguments.map.aliases);
			return loc.state;
		</cfscript>
	</cffunction>
</cfcomponent>