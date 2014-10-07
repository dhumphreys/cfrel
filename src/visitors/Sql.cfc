<cfcomponent output="false">
	<cfinclude template="../functions.cfm" />
	
	<cffunction name="init" returntype="any" access="public" hint="Constructor">
		<cfscript>
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="traverseToString" returntype="string" access="public" hint="Return tree traversal as SQL string">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn sqlArrayToString(visit(argumentCollection=arguments)) />
	</cffunction>
	
	<cffunction name="visit" returntype="array" access="public" hint="Visit a particular object">
		<cfargument name="obj" type="any" required="true" />
		<cfargument name="rtn" type="any" required="false" />
		<cfargument name="map" type="struct" required="false" />
		<cfargument name="state" type="struct" required="false" />
		<cfscript>
			var loc = {};
			var method = 0;

			// set up an empty accumulator as a Java ArrayList object
			if (NOT StructKeyExists(arguments, "rtn"))
				arguments.rtn = javaArray();

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

	<cffunction name="visit_list" returntype="array" access="public" hint="Visit an array of objects, separating them with a delimeter">
		<cfargument name="obj" type="any" required="true" />
		<cfargument name="delim" type="string" default="," />
		<cfscript>
			var loc = {};

			// if object passed in was not an array, just generate sql for the object
			if (NOT IsArray(arguments.obj))
				return visit(obj=arguments.obj, rtn=arguments.rtn, map=arguments.map, state=arguments.state);

			// count the items in the array
			loc.iEnd = ArrayLen(arguments.obj);

			// generate the first item by itself
			if (loc.iEnd GT 0)
				arguments.rtn = visit(obj=arguments.obj[1], rtn=arguments.rtn, map=arguments.map, state=arguments.state);

			// separate further items with the delimeter as they are generated
			for (loc.i = 2; loc.i LTE loc.iEnd; loc.i++) {
				ArrayAppend(arguments.rtn, arguments.delim);
				arguments.rtn = visit(obj=arguments.obj[loc.i], rtn=arguments.rtn, map=arguments.map, state=arguments.state);
			}

			return arguments.rtn;
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
			
			// turn aliasing on in select clause
			loc.aliasOff = arguments.state.aliasOff;
			arguments.state.aliasOff = false;
			
			// generate SELECT clause
			ArrayAppend(arguments.rtn, "SELECT");
			if (ArrayLen(obj.sql.selectFlags) GT 0)
				arguments.rtn = visit(obj=obj.sql.selectFlags, argumentCollection=arguments);
			if (ArrayLen(obj.sql.select) EQ 0) {
				arguments.rtn = visit(obj=sqlWildcard(), argumentCollection=arguments);
			} else {
				arguments.rtn = visit_list(obj=obj.sql.select, argumentCollection=arguments);
				loc.select = true;
			}
			
			// generate FROM arguments
			if (ArrayLen(obj.sql.froms) GT 0) {
				ArrayAppend(arguments.rtn, "FROM");
				arguments.state.softDeleteContext = "from";
				arguments.rtn = visit_list(obj=obj.sql.froms, argumentCollection=arguments);
				arguments.state.softDeleteContext = "other";
					
			// error if neither SELECT or FROM was specified
			} else if (loc.select EQ false) {
				throwException("Either SELECT or FROM must be specified in relation");
			}
			
			// turn aliasing off outside of SELECT clause
			arguments.state.aliasOff = true;
 			
			// append joins
			if (ArrayLen(obj.sql.joins) GT 0) {
				arguments.state.softDeleteContext = "join";
				arguments.rtn = visit(obj=obj.sql.joins, argumentCollection=arguments);
				arguments.state.softDeleteContext = "other";
			}
			
			// append where clause and/or soft deletes
			if (ArrayLen(obj.sql.wheres) OR ArrayLen(arguments.state.softDeletes.wheres)) {
				ArrayAppend(arguments.rtn, "WHERE");
				loc.wheres = [];
				ArrayAppend(loc.wheres, obj.sql.wheres, true);
				ArrayAppend(loc.wheres, arguments.state.softDeletes.wheres, true);
				arguments.rtn = visit_list(obj=loc.wheres, delim="AND", argumentCollection=arguments);
			}

			// append group by clause
			if (ArrayLen(obj.sql.groups)) {
				ArrayAppend(arguments.rtn, "GROUP BY");
				arguments.rtn = visit_list(obj=obj.sql.groups, argumentCollection=arguments);
			}

			// append having clause
			if (ArrayLen(obj.sql.havings)) {
				ArrayAppend(arguments.rtn, "HAVING");
				arguments.rtn = visit_list(obj=obj.sql.havings, delim="AND", argumentCollection=arguments);
			}

			// append order clause
			if (ArrayLen(obj.sql.orders)) {
				ArrayAppend(arguments.rtn, "ORDER BY");
				arguments.rtn = visit_list(obj=obj.sql.orders, argumentCollection=arguments);
			}
			
			// turn aliasing back on
			arguments.state.aliasOff = loc.aliasOff;
			
			// generate LIMIT clause
			if (StructKeyExists(obj.sql, "limit"))
				ArrayAppend(arguments.rtn, "LIMIT #obj.sql.limit#");
				
			// generate OFFSET clause
			if (StructKeyExists(obj.sql, "offset") AND obj.sql.offset GT 0)
				ArrayAppend(arguments.rtn, "OFFSET #obj.sql.offset#");
				
			// return sql array
			return arguments.rtn;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_simple" returntype="array" access="private" hint="Render a simple value by just returning it">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			ArrayAppend(arguments.rtn, arguments.obj);
			return arguments.rtn;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_array" returntype="array" access="private" hint="Call visit on each element of array">
		<cfargument name="obj" type="array" required="true" />
		<cfscript>
			var loc = {};
			loc.iEnd = ArrayLen(arguments.obj);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
				arguments.rtn = visit(obj=arguments.obj[loc.i], argumentCollection=arguments);
			return arguments.rtn;
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
				ArrayAppend(arguments.rtn, escape(obj.alias));
				
			// don't use alias, only subject
			} else if (arguments.state.aliasOff) {
				arguments.rtn = visit(obj=obj.subject, argumentCollection=arguments);
				
			// use both, but ignore any aliases inside of subject
			} else {
				
				loc.aliasOff = arguments.state.aliasOff;
				arguments.state.aliasOff = true;
				arguments.rtn = visit(obj=obj.subject, argumentCollection=arguments);
				ArrayAppend(arguments.rtn, "AS #escape(obj.alias)#");
				arguments.state.aliasOff = loc.aliasOff;
			}
			
			return arguments.rtn;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_between" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			arguments.rtn = visit(obj=obj.subject, argumentCollection=arguments);
			ArrayAppend(arguments.rtn, "BETWEEN");
			arguments.rtn = visit(obj=obj.start, argumentCollection=arguments);
			ArrayAppend(arguments.rtn, "AND");
			arguments.rtn = visit(obj=obj.end, argumentCollection=arguments);
			return arguments.rtn;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_binaryOp" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			// if we are doing an OR, then surround the expression in parenthesis to make sure order of operations stands
			if (obj.op EQ "OR")
				ArrayAppend(arguments.rtn, "(");

			// generate the left hand side and operator
			arguments.rtn = visit(obj=obj.left, argumentCollection=arguments);
			ArrayAppend(arguments.rtn, REReplace(obj.op, "_", " ", "ALL"));

			// if the operator is an IN, treat the right hand side like a list
			if (obj.op CONTAINS "IN") {
				ArrayAppend(arguments.rtn, "(");
				arguments.rtn = visit_list(obj=obj.right, argumentCollection=arguments);
				ArrayAppend(arguments.rtn, ")");

			// otherwise, just generate the right side
			} else {
				arguments.rtn = visit(obj=obj.right, argumentCollection=arguments);
			}

			// if we are doing an OR, then surround the expression in parenthesis to make sure order of operations stands
			if (obj.op EQ "OR")
				ArrayAppend(arguments.rtn, ")");

			return arguments.rtn;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_case" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};

			// begin the CASE statement
			ArrayAppend(arguments.rtn, "CASE");

			// generate subject of CASE statement if passed
			if (NOT IsSimpleValue(obj.subject) OR obj.subject NEQ "")
				arguments.rtn = visit(obj=obj.subject, argumentCollection=arguments);

			// generate each WHEN statement
			if (ArrayLen(obj.cases))
				arguments.rtn = visit(obj=obj.cases, argumentCollection=arguments);

			// generate the ELSE statement if passed
			if (NOT IsSimpleValue(obj.els) OR obj.els NEQ "") {
				ArrayAppend(arguments.rtn, "ELSE");
				arguments.rtn = visit(obj=obj.els, argumentCollection=arguments);
			}

			// close the CASE statement
			ArrayAppend(arguments.rtn, "END");

			return arguments.rtn;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_caseCondition" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			ArrayAppend(arguments.rtn, "WHEN");
			arguments.rtn = visit(obj=obj.condition, argumentCollection=arguments);
			ArrayAppend(arguments.rtn, "THEN");
			arguments.rtn = visit(obj=obj.subject, argumentCollection=arguments);
			return arguments.rtn;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_cast" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			ArrayAppend(arguments.rtn, "CAST(");
			arguments.rtn = visit(obj=obj.subject, argumentCollection=arguments);
			ArrayAppend(arguments.rtn, "AS");
			arguments.rtn = visit(obj=obj.type, argumentCollection=arguments);
			ArrayAppend(arguments.rtn, ")");
			return arguments.rtn;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_column" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};

			// set default column and alias from column node
			loc.column = loc.key = obj.column;
			loc.alias = obj.alias;
			loc.calculated = false;

			// look up more specific mapping if it exists
			if (StructKeyExists(arguments.map.columns, loc.key)) {
				loc.calculated = arguments.map.columns[loc.key].calculated;
				loc.column = arguments.map.columns[loc.key].mapping;
				if (Len(loc.alias) EQ 0)
					loc.alias = arguments.map.columns[loc.key].alias;
			} else if (Len(loc.alias) EQ 0) {
				loc.alias = ListLast(loc.column, ".");
			}

			// if we are in alias-only mode, just return the alias by itself
			if (arguments.state.aliasOnly)
				ArrayAppend(arguments.rtn, escape(loc.alias));

			// if aliases are disabled, or the column and alias match, and we aren't using a calculated property, just return the column
			else if (arguments.state.aliasOff OR (NOT loc.calculated AND ListLast(loc.column, ".") EQ loc.alias))
				ArrayAppend(arguments.rtn, loc.calculated ? loc.column : escape(loc.column));

			// return the calculated property sql with its alias
			else if (loc.calculated)
				ArrayAppend(arguments.rtn, loc.column & " AS " & escape(loc.alias));

			// return the column with its alias
			else
				ArrayAppend(arguments.rtn, escape(loc.column) & " AS " & escape(loc.alias));

			return arguments.rtn;
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

			// set the correct type of JOIN
			switch(obj.type) {
				case "outer": ArrayAppend(arguments.rtn, "LEFT JOIN"); break;
				case "cross": ArrayAppend(arguments.rtn, "CROSS JOIN"); break;
				case "natural": ArrayAppend(arguments.rtn, "NATURAL JOIN"); break;
				default: ArrayAppend(arguments.rtn, "JOIN");
			}

			// generate the table part of the JOIN
			arguments.rtn = visit(obj=obj.table, argumentCollection=arguments);

			// generate the ON clause if conditions or soft deletes are present for this join
			loc.hasJoinConditions = IsStruct(obj.condition) OR obj.condition NEQ false;
			if (loc.hasJoinConditions OR ArrayLen(arguments.state.softDeletes.joins)) {
				ArrayAppend(arguments.rtn, "ON");

				// combine the conditions and soft deletes into a single array
				loc.conditions = [];
				if (loc.hasJoinConditions)
					ArrayAppend(loc.conditions, obj.condition);
				ArrayAppend(loc.conditions, arguments.state.softDeletes.joins, true);
				arguments.state.softDeletes.joins = [];

				// generate the ON clause content and concatenate the fragments with AND
				arguments.rtn = visit_list(obj=loc.conditions, delim="AND", argumentCollection=arguments);
			}

			return arguments.rtn;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_literal" returntype="array" access="private" hint="Render a literal SQL string">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			ArrayAppend(arguments.rtn, arguments.obj.subject);
			return arguments.rtn;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_function" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};

			// turn off aliases for function arguments
			loc.aliasOff = arguments.state.aliasOff;
			arguments.state.aliasOff = true;

			// prepend scope for function if present
			if (NOT IsSimpleValue(obj.scope) OR obj.scope NEQ "") {
				arguments.rtn = visit(obj=obj.scope, argumentCollection=arguments);
				ArrayAppend(arguments.rtn, ".");
			}

			// generate the function name
			ArrayAppend(arguments.rtn, "#obj.name#(");

			// append the DISTINCT keyword if present
			if (obj.distinct)
				ArrayAppend(arguments.rtn, "DISTINCT");

			// append the function arguments and close the call
			arguments.rtn = visit_list(obj=obj.args, argumentCollection=arguments);
			ArrayAppend(arguments.rtn, ")");

			// switch aliasing back on
			arguments.state.aliasOff = loc.aliasOff;

			return arguments.rtn;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_order" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			arguments.rtn = visit(obj=obj.subject, argumentCollection=arguments);
			if (obj.descending)
				ArrayAppend(arguments.rtn, "DESC");
			else
				ArrayAppend(arguments.rtn, "ASC");
			return arguments.rtn;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_param" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};

			// duplicate param node so as not to corrupt a cached sql tree
			loc.obj = Duplicate(arguments.obj);

			// if no type is present on the parameter, attempt to find out what type it is
			if (StructKeyExists(loc.obj, "column")) {
				loc.key = loc.obj.column;
				StructDelete(loc.obj, "column");

				// if possible, map the parameter to the column it references
				if (StructKeyExists(arguments.map.columns, loc.key) AND StructKeyExists(arguments.map.columns[loc.key], "cfsqltype"))
					loc.obj.cfsqltype = arguments.map.columns[loc.key].cfsqltype;
			}

			// append parameter object as it is
			ArrayAppend(arguments.rtn, loc.obj);
			
			return arguments.rtn;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_paren" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			ArrayAppend(arguments.rtn, "(");
			arguments.rtn = visit(obj=arguments.obj.subject, argumentCollection=arguments);
			ArrayAppend(arguments.rtn, ")");
			return arguments.rtn;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_subquery" returntype="array" access="private" hint="Render a subquery with an alias">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			ArrayAppend(arguments.rtn, "(");
			arguments.rtn = visit(obj=arguments.obj.subject, argumentCollection=arguments);
			ArrayAppend(arguments.rtn, ")");
			arguments.rtn = visit(obj=sqlTable(table="subquery", alias=obj.alias), argumentCollection=arguments);
			return arguments.rtn;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_query" returntype="array" access="private" hint="Render a query as a QOQ reference">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn visit(obj=sqlTable(table="query", alias=obj.alias), argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="visit_nodes_table" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};

			// determine default table and alias
			loc.table = loc.key = obj.table;
			loc.alias = Len(obj.alias) ? obj.alias : ListLast(loc.table, ".");

			// if a more reliable alias can be found, then use it and pop it off the stack
			if (StructKeyExists(arguments.state.aliases, loc.key) AND ArrayLen(arguments.state.aliases[loc.key])) {
				loc.alias = arguments.state.aliases[loc.key][1];
				ArrayDeleteAt(arguments.state.aliases[loc.key], 1);
				loc.table = arguments.map.tables[loc.alias].table;

				// append soft delete to where clause or on clause
				if (StructKeyExists(arguments.map.tables, loc.alias) AND IsStruct(arguments.map.tables[loc.alias].softDelete)) {
					if (arguments.state.softDeleteContext EQ "join")
						ArrayAppend(arguments.state.softDeletes.joins, arguments.map.tables[loc.alias].softDelete);
					else
						ArrayAppend(arguments.state.softDeletes.wheres, arguments.map.tables[loc.alias].softDelete);
				}
			}

			// just return the table if it matches the alias
			if (ListLast(loc.table, ".") EQ loc.alias)
				ArrayAppend(arguments.rtn, escape(loc.table));

			// otherwise, return the table with its alias
			else
				ArrayAppend(arguments.rtn, escape(loc.table) & " " & escape(loc.alias));

			return arguments.rtn;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_model" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn visit(obj=sqlTable(table=arguments.obj.model, alias=obj.alias), argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="visit_nodes_type" returntype="array" access="private">
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
			ArrayAppend(arguments.rtn, loc.type);
			return arguments.rtn;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_unaryOp" returntype="array" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			ArrayAppend(arguments.rtn, obj.op);
			arguments.rtn = visit(obj=obj.subject, argumentCollection=arguments);
			return arguments.rtn;
		</cfscript>
	</cffunction>
	
	<cffunction name="visit_nodes_wildcard" returntype="array" access="private">
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
				arguments.rtn = visit_list(obj=loc.columns, map=emptyMap(), argumentCollection=arguments);

			// if we only have a subject, return the subject with a star
			} else if (obj.subject NEQ "") {
				ArrayAppend(arguments.rtn, escape(obj.subject) & ".*");

			// if we have nothing else, just return star
			} else {
				ArrayAppend(arguments.rtn, "*");
			}

			return arguments.rtn;
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
			loc.state.softDeletes = {wheres=[], joins=[]};
			loc.state.softDeleteContext = "other";
			return loc.state;
		</cfscript>
	</cffunction>
</cfcomponent>