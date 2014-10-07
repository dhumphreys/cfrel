<cffunction name="findByKey" returntype="any" access="public" hint="Find a scoped record by key">
	<cfargument name="key" type="string" required="true" />
	<cfscript>
		var loc = {};
		loc.args = {};
		
		// get primary keys from mapper
		loc.keys = ListToArray(arguments.key);
		loc.primaryKey = ListToArray(mapper().primaryKey(this.model));
		loc.iEnd = ArrayLen(loc.primaryKey);
		
		// check for errors
		if (loc.iEnd EQ 0)
			throwException("No primary key structure found.");
		else if (loc.iEnd NEQ ArrayLen(loc.keys))
			throwException("Invalid key list. Does not match primary key for this table.");
		
		// add each key / value to arguments
		for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
			loc.args[loc.primaryKey[loc.i]] = loc.keys[loc.i];
		
		// execute WHERE to find record matching key
		loc.rel = clone().where(argumentCollection=loc.args).clearPagination().limit(1);
		
		// if records are found, return object
		if (loc.rel.recordCount() GT 0)
			return loc.rel.object(1);
		
		return false;
	</cfscript>
</cffunction>

<cffunction name="select" returntype="struct" access="public" hint="Append to the SELECT clause of the relation">
	<cfscript>
		if (variables.executed)
			return this.clone().select(argumentCollection=arguments);

		if (variables.cacheSql)
			appendSignature(GetFunctionCalledName(), arguments);

		_appendFieldsToClause("SELECT", "select", arguments);
		return this;
	</cfscript>
</cffunction>

<cffunction name="distinct" returntype="struct" access="public" hint="Set DISTINCT flag for SELECT">
	<cfscript>
		if (variables.executed)
			return this.clone().distinct(argumentCollection=arguments);

		if (variables.cacheSql)
			appendSignature(GetFunctionCalledName(), arguments);

		if (NOT ArrayFind(this.sql.selectFlags, "DISTINCT"))
			ArrayAppend(this.sql.selectFlags, "DISTINCT");
		return this;
	</cfscript>
</cffunction>

<cffunction name="from" returntype="struct" access="public" hint="Specify FROM target of either a table or another relation">
	<cfargument name="target" type="any" required="true" />
	<cfscript>
		var loc = {};
		
		// auto-clone if relation already executed
		if (variables.executed)
			return this.clone().from(argumentCollection=arguments);

		if (variables.cacheSql)
			appendSignature(GetFunctionCalledName(), arguments);
		
		// make decision based on argument type
		switch(typeOf(arguments.target)) {
			
			// wrap simple strings in table nodes
			case "simple":
				arguments.target = sqlTable(arguments.target);
			case "cfrel.nodes.Table":
				break;
			
			// wrap relations in subquery nodes
			case "cfrel.Relation":
				arguments.target = sqlSubquery(arguments.target);
			case "cfrel.nodes.SubQuery":
				break;
			
			// wrap models in model nodes
			case "model":
				arguments.target = sqlModel(arguments.target.$classData().modelName);
			case "cfrel.nodes.Model":

				// set default soft delete behavior
				if (NOT StructKeyExists(arguments.target, "includeSoftDeletes"))
					arguments.target.includeSoftDeletes = variables.includeSoftDeletes;
			
				// set model for mapper behavior
				if (this.model EQ false)
					this.model = arguments.target.model;
				break;
			
			// wrap queries in query nodes
			case "query":
				arguments.target = sqlQuery(arguments.target);
			case "cfrel.nodes.Query":
			
				// change visitor for QoQ operations
				variables.qoq = true;
				variables.visitorClass = "QueryOfQuery";
				break;
				
			// and reject all other arguments by throwing an error
			default:
				throwException("Only a table names, relations, queries, or models can be in FROM clause");
		}
		
		// put the target onto the FROM stack
		ArrayAppend(this.sql.froms, arguments.target);
		return this;
	</cfscript>
</cffunction>

<cffunction name="join" returntype="struct" access="public" hint="Add a JOIN to the relation">
	<cfargument name="target" type="any" required="true" />
	<cfargument name="condition" type="any" default="false" />
	<cfargument name="params" type="array" default="#[]#" />
	<cfargument name="type" type="string" default="inner" hint="inner, outer, natural, or cross" />
	<cfscript>
		var loc = {};
		if (variables.executed)
			return this.clone().join(argumentCollection=arguments);

		if (variables.cacheSql)
			appendSignature(GetFunctionCalledName(), arguments);
			
		// correctly set condition of join
		if (NOT IsSimpleValue(arguments.condition)) {
			loc.condition = arguments.condition;
		} else if (arguments.condition NEQ false) {
			loc.condition = parse(arguments.condition);
		} else {
			loc.condition = false;
		}
			
		// create table object
		switch(typeOf(arguments.target)) {
			
			// wrap strings in table nodes
			case "simple":
				arguments.target = sqlTable(table=arguments.target);
			case "cfrel.nodes.table":
				break;
				
			// add a model to a new table object
			case "model":
				arguments.target = sqlModel(arguments.target.$classData().modelName);
			case "cfrel.nodes.model":

				// set default soft delete behavior
				if (NOT StructKeyExists(arguments.target, "includeSoftDeletes"))
					arguments.target.includeSoftDeletes = variables.includeSoftDeletes;

				break;
				
			// use another relation as a subquery
			case "cfrel.relation":
				arguments.target = sqlSubQuery(arguments.target);
				break;
				
			// if using a query
			case "query":
				arguments.target = sqlQuery(arguments.target);
			case "cfrel.nodes.query":
				if (variables.qoq EQ false)
					throwException("Cannot join a query object if relation is not a QoQ");
					
				// add the query as an additional from instead of joining
				ArrayAppend(this.sql.froms, arguments.target);
				
				// put conditions in where clause if not a cross join
				// TODO: make up some fancy way to handle QoQ natural joins
				if (arguments.type NEQ "cross")
					this.where(arguments.condition, arguments.params);
				break;
				
			// throw error if invalid target
			default:
				throwException("Only table names or table nodes can be target of JOIN");
				
		}
		
		// append join to sql structure unless this is a qoq
		if (NOT variables.qoq) {
			ArrayAppend(this.sql.joins, sqlJoin(arguments.target, loc.condition, arguments.type));
			ArrayAppend(this.params.joins, arguments.params, true);
		}
		
		return this;
	</cfscript>
</cffunction>

<cffunction name="where" returntype="struct" access="public" hint="Append to the WHERE clause of the relation">
	<cfargument name="$clause" type="any" required="false" />
	<cfargument name="$params" type="array" required="false" />
	<cfscript>
		if (variables.executed)
			return this.qoq().where(argumentCollection=arguments);

		_appendConditionsToClause("WHERE", "wheres", arguments);
		return this;
	</cfscript>
</cffunction>

<cffunction name="group" returntype="struct" access="public" hint="Append to GROUP BY clause of the relation">
	<cfscript>
		if (variables.executed)
			return this.clone().group(argumentCollection=arguments);

		if (variables.cacheSql)
			appendSignature(GetFunctionCalledName(), arguments);

		_appendFieldsToClause("GROUP BY", "groups", arguments);
		return this;
	</cfscript>
</cffunction>

<cffunction name="having" returntype="struct" access="public" hint="Append to HAVING clause of the relation">
	<cfargument name="$clause" type="any" required="false" />
	<cfargument name="$params" type="array" required="false" />
	<cfscript>
		if (variables.executed)
			return this.clone().having(argumentCollection=arguments);

		_appendConditionsToClause("HAVING", "havings", arguments);
		return this;
	</cfscript>
</cffunction>

<cffunction name="order" returntype="struct" access="public" hint="Append to ORDER BY clause of the relation">
	<cfscript>
		if (variables.executed)
			return this.clone().order(argumentCollection=arguments);

		if (variables.cacheSql)
			appendSignature(GetFunctionCalledName(), arguments);

		_appendFieldsToClause("ORDER BY", "orders", arguments);
		return this;
	</cfscript>
</cffunction>

<cffunction name="limit" returntype="struct" access="public" hint="Restrict the number of records when querying">
	<cfargument name="value" type="numeric" required="true" />
	<cfscript>
		if (variables.executed)
			return this.clone().limit(argumentCollection=arguments);

		if (variables.cacheSql)
			appendSignature(GetFunctionCalledName(), arguments);

		if (variables.qoq)
			this.maxRows = Int(arguments.value);
		else
			this.sql.limit = Int(arguments.value);
		return this;
	</cfscript>
</cffunction>

<cffunction name="offset" returntype="struct" access="public" hint="Skip some records when querying">
	<cfargument name="value" type="numeric" required="true" />
	<cfscript>
		if (variables.executed)
			return this.clone().offset(argumentCollection=arguments);

		if (variables.cacheSql)
			appendSignature(GetFunctionCalledName(), arguments);

		this.sql.offset = Int(arguments.value);
		return this;
	</cfscript>
</cffunction>

<cffunction name="clearSelect" returntype="struct" access="public" hint="Remove all SELECT options">
	<cfscript>
		if (variables.executed)
			return this.clone().clearSelect(argumentCollection=arguments);

		if (variables.cacheSql)
			removeFromSignature({"select"=1});

		this.sql.select = [];
		this.sql.selectFlags = [];
		return this;
	</cfscript>
</cffunction>

<cffunction name="clearWhere" returntype="struct" access="public" hint="Remove all WHERE options">
	<cfscript>
		if (variables.executed)
			return this.clone().clearWhere(argumentCollection=arguments);

		if (variables.cacheSql)
			removeFromSignature({"where"=1});

		this.sql.wheres = [];
		this.params.wheres = [];
		return this;
	</cfscript>
</cffunction>

<cffunction name="clearGroup" returntype="struct" access="public" hint="Remove all GROUP BY options">
	<cfscript>
		if (variables.executed)
			return this.clone().clearGroup(argumentCollection=arguments);

		if (variables.cacheSql)
			removeFromSignature({"group"=1});

		this.sql.groups = [];
		return this;
	</cfscript>
</cffunction>

<cffunction name="clearHaving" returntype="struct" access="public" hint="Remove all HAVING options">
	<cfscript>
		if (variables.executed)
			return this.clone().clearHaving(argumentCollection=arguments);

		if (variables.cacheSql)
			removeFromSignature({"having"=1});

		this.sql.havings = [];
		this.params.havings = [];
		return this;
	</cfscript>
</cffunction>

<cffunction name="clearOrder" returntype="struct" access="public" hint="Remove all ORDER BY options">
	<cfscript>
		if (variables.executed)
			return this.clone().clearOrder(argumentCollection=arguments);

		if (variables.cacheSql)
			removeFromSignature({"order"=1});

		this.sql.orders = [];
		return this;
	</cfscript>
</cffunction>

<cffunction name="selectGroup" returntype="struct" access="public" hint="Append to the SELECT and GROUP clauses of the relation">
	<cfreturn iif(variables.executed, "this.clone()", "this").select(argumentCollection=arguments).group(argumentCollection=arguments) />
</cffunction>

<cffunction name="innerJoin" returntype="struct" access="public" hint="Add an INNER JOIN to the relation">
	<cfargument name="target" type="any" required="true" />
	<cfargument name="condition" type="any" default="false" />
	<cfargument name="params" type="array" default="#[]#" />
	<cfreturn this.join(argumentCollection=arguments, type="inner") />
</cffunction>

<cffunction name="outerJoin" returntype="struct" access="public" hint="Add a LEFT OUTER JOIN to the relation">
	<cfargument name="target" type="any" required="true" />
	<cfargument name="condition" type="any" default="false" />
	<cfargument name="params" type="array" default="#[]#" />
	<cfreturn this.join(argumentCollection=arguments, type="outer") />
</cffunction>

<cffunction name="naturalJoin" returntype="struct" access="public" hint="Add a NATURAL JOIN to the relation">
	<cfargument name="target" type="any" required="true" />
	<cfreturn this.join(argumentCollection=arguments, type="natural") />
</cffunction>

<cffunction name="crossJoin" returntype="struct" access="public" hint="Add a CROSS JOIN to the relation">
	<cfargument name="target" type="any" required="true" />
	<cfreturn this.join(argumentCollection=arguments, type="cross") />
</cffunction>

<cffunction name="include" returntype="struct" access="public" hint="Add a JOIN to the relation using predefined relationships">
	<cfargument name="include" type="string" required="true" />
	<cfargument name="params" type="array" default="#[]#" />
	<cfargument name="joinType" type="string" default="" />
	<cfargument name="merge" type="boolean" default="true" />
	<cfscript>
		var loc = {};

		if (variables.executed)
			return this.clone().include(argumentCollection=arguments);

		if (variables.cacheSql)
			appendSignature(GetFunctionCalledName(), arguments);

		// always append parameters to the relation
		ArrayAppend(this.params.joins, arguments.params, true);

		// merge with a previous include statement if we can
		loc.len = ArrayLen(this.sql.joins);
		if (arguments.merge AND loc.len GT 0 AND typeOf(this.sql.joins[loc.len]) EQ "cfrel.nodes.include") {
			this.sql.joins[loc.len] = mergeIncludes(this.sql.joins[loc.len], arguments.include, arguments.joinType);

		// otherwise, append a new include statement to the join list
		} else {
			loc.include = sqlInclude(include=arguments.include, includeKey=ListAppend(arguments.joinType, arguments.include, ':'), tree=includeTree(arguments.include, arguments.joinType), includeSoftDeletes=variables.includeSoftDeletes);
			ArrayAppend(this.sql.joins, loc.include);
		}
			
		return this;
	</cfscript>
</cffunction>

<cffunction name="mergeIncludes" returntype="struct" access="private" hint="Merge two include statements into one">
	<cfargument name="dest" type="struct" required="true" />
	<cfargument name="include" type="string" required="true" />
	<cfargument name="joinType" type="string" default="" />
	<cfscript>
		arguments.dest.include = ListAppend(arguments.dest.include, arguments.include);
		arguments.dest.includeKey = ListAppend(arguments.dest.includeKey, ListAppend(arguments.joinType, arguments.include, ':'), ';');
		arguments.dest.tree = includeTree(arguments.include, arguments.joinType, arguments.dest.tree);
		return arguments.dest;
	</cfscript>
</cffunction>

<cffunction name="includeTree" returntype="struct" access="private">
	<cfargument name="include" type="string" required="true" />
	<cfargument name="joinType" type="string" required="true" />
	<cfargument name="dest" type="struct" required="false" />
	<cfscript>
		var loc = {};

		// return value: join options and the order in which they occur
		if (NOT StructKeyExists(arguments, "dest")) {
			arguments.dest = StructNew();
			arguments.dest.options = StructNew();
			arguments.dest.order = ArrayNew(1);
		}

		// track join prefix and depth
		loc.prefix = "";
		loc.depth = 0;

    // split include string into meaningful tokens
    loc.regex = "(\w+(\[[^\]]+\])?|\(|\))";
    loc.tokens = REMatch(loc.regex, arguments.include);

    // loop over each token
    loc.curr = "";
    loc.iEnd = ArrayLen(loc.tokens);
    for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
    	switch (loc.tokens[loc.i]) {

    		// on left paren, push the current association name onto the prefix
    		case "(": 
    			loc.prefix = ListAppend(loc.prefix, loc.curr, "_");
    			loc.depth++;
    			break;

    		// on right paren, pop the last association name off the prefix
    		case ")":
					if (loc.depth GT 0)
						loc.prefix = ListDeleteAt(loc.prefix, loc.depth--, "_");
					break;

				// for identifiers, make a new entry
    		default:
    			loc.curr = loc.tokens[loc.i];
    			loc.options = StructNew();
    			loc.options.joinType = arguments.joinType;

					// extract additional conditioning from include statement if it exists
					loc.startPos = Find("[", loc.curr);
					if (loc.startPos GT 1) {
						loc.endPos = Find("]", loc.curr, loc.startPos);
						if (loc.endPos LTE loc.startPos)
							throwException("Invalid format found in include condition: '#loc.curr#'");
						loc.options.condition = parse(Mid(loc.curr, loc.startPos + 1, loc.endPos - loc.startPos - 1));
						loc.curr = Left(loc.curr, loc.startPos - 1);
					}

					// save the include options for return
					loc.joinKey = ListAppend(loc.prefix, loc.curr, "_");
					if (NOT StructKeyExists(arguments.dest.options, loc.joinKey)) {
						ArrayAppend(arguments.dest.order, loc.joinKey);
						arguments.dest.options[loc.joinKey] = loc.options;
					}
    	}
    }

    return arguments.dest;
	</cfscript>
</cffunction>

<cffunction name="includeString" returntype="string" access="public" hint="Return minimized include string">
	<cfscript>
		var loc = {};
		loc.finalInclude = "";

		// process each include for this relation's joins
		for (loc.join in this.sql.joins) {
			if (loc.join.$class EQ "cfrel.nodes.include") {

				// keep lists of join segments and segments which are redundant
				loc.segments = Duplicate(loc.join.tree.order);
				loc.redundant = false;
				loc.redundantSegments = [];

				// sort the include segments in order of descendents
				loc.segmentCount = ArrayLen(loc.segments);
				for (loc.i = 1; loc.i LTE loc.segmentCount; loc.i++) {

					// build a regex for detecting direct children of this node
					loc.regex = "^" & loc.segments[loc.i] & "_[^_\W]+$";

					// for each segment, search for direct children in the rest of the segments
					loc.nextPos = loc.i + 1;
					for (loc.j = loc.nextPos; loc.j LTE loc.segmentCount; loc.j++) {

						// if we find one, move it to the correct position
						if (REFind(loc.regex, loc.segments[loc.j])) {

							// only physically move the child if it is not already in the correct place
							if (loc.j NEQ loc.nextPos) {
								loc.tmp = loc.segments[loc.j];
								ArrayDeleteAt(loc.segments, loc.j);
								ArrayInsertAt(loc.segments, loc.nextPos, loc.tmp);
							}

 							// mark this redundant segment for removal and increment the next segment placing
							loc.redundant = true;
							loc.nextPos++;
						}
					}

					// if we found a redundant segment, log it and remove it
					if (loc.redundant) {
						ArrayAppend(loc.redundantSegments, loc.segments[loc.i]);
						ArrayDeleteAt(loc.segments, loc.i);

						// adjust counters to continue looping
						loc.i--;
						loc.segmentCount--;
						loc.redundant = false;
					}
				}

				// loop over redundant segments (in reverse order) and combine segments that are direct children
				for (loc.i = ArrayLen(loc.redundantSegments); loc.i GTE 1; loc.i--) {
					loc.regex = "^" & loc.redundantSegments[loc.i] & "_(.+)$";

					// search for a direct child of the redundant prefix
					for (loc.j = 1; loc.j LTE loc.segmentCount; loc.j++) {
						if (REFind(loc.regex, loc.segments[loc.j])) {

							// strip out prefix and surround with parenthesis
							loc.matches = balancedParen(REReplace(loc.segments[loc.j], loc.regex, "\1"));
							loc.secondMatch = false;

							// try to find other matches in a row
							while (loc.j + 1 LTE loc.segmentCount) {

								// break if we don't find one immediately
								if (NOT REFind(loc.regex, loc.segments[loc.j + 1]))
									break;

								// if we did find one, strip out prefix, append to matches, and remove from segment array
								loc.matches &= "," & balancedParen(REReplace(loc.segments[loc.j + 1], loc.regex, "\1"));
								ArrayDeleteAt(loc.segments, loc.j + 1);
								loc.segmentCount--;
								loc.secondMatch = true;
							}

							// if we found more than one match, combine into single segment
							if (loc.secondMatch)
								loc.segments[loc.j] = loc.redundantSegments[loc.i] & "_" & loc.matches;
						}
					}
				}

				// add parenthesis to each include string and append them to the return list
				for (loc.i = 1; loc.i LTE loc.segmentCount; loc.i++)
					loc.finalInclude = ListAppend(loc.finalInclude, balancedParen(loc.segments[loc.i]));
			}
		}

		return loc.finalInclude;
	</cfscript>
</cffunction>

<cffunction name="balancedParen" returntype="string" access="private" hint="Replace underscores in strings with balanced parenthesis">
	<cfargument name="str" type="string" required="true" />
	<cfreturn Replace(arguments.str, "_", "(", "ALL") & RepeatString(")", ListLen(arguments.str, "_") - 1) />
</cffunction>

<cffunction name="_appendFieldsToClause" returntype="void" access="private" hint="Append list(s) to the ">
	<cfargument name="clause" type="string" required="true" />
	<cfargument name="scope" type="string" required="true" />
	<cfargument name="args" type="struct" required="true" />
	<cfscript>
		var loc = {};
		
		// do not allow empty set of arguments
		loc.iEnd = StructCount(arguments.args);
		if (loc.iEnd EQ 0) {
			throwException("Arguments are required in #UCase(arguments.clause)#");
		} else {
			
			// parse each parameter and append to desired scope
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
				loc.value = _transformInput(arguments.args[loc.i], arguments.clause);
				if (IsArray(loc.value)) {
					loc.jEnd = ArrayLen(loc.value);
					for (loc.j = 1; loc.j LTE loc.jEnd; loc.j++)
						ArrayAppend(this.sql[arguments.scope], loc.value[loc.j]);
				} else {
					ArrayAppend(this.sql[arguments.scope], loc.value);
				}
			}
		}
	</cfscript>
</cffunction>

<cffunction name="_appendConditionsToClause" returntype="void" access="private" hint="Take conditions and parameters and append to arrays">
	<cfargument name="clause" type="string" required="true" />
	<cfargument name="scope" type="string" required="true" />
	<cfargument name="args" type="struct" required="true" />
	<cfparam name="arguments.args.$params" default="#ArrayNew(1)#" />
	<cfscript>
		var loc = {};
		
		// do not allow empty set of arguments
		loc.argumentCount = StructCount(arguments.args);
		if (loc.argumentCount EQ 0) {
			throwException(message="Relation requires arguments for #UCase(arguments.clause)#");
			
		// if a text clause was passed, we need to parse entire clause and add passed in params
		} else if (StructKeyExists(arguments.args, "$clause")) {
		
			if (variables.cacheSql)
				appendSignature(arguments.clause, {$clause=arguments.args.$clause});
				
			// append clause and parameters to relation object
			ArrayAppend(this.sql[arguments.scope], _transformInput(arguments.args.$clause, arguments.clause));
			ArrayAppend(this.params[arguments.scope], arguments.args.$params, true);
			
		// if key/value pairs were passed, comparison nodes should be added with parameters
		} else {

			// store a hypothetical clause with parameter placeholders for caching purposes
			loc.cacheClause = [];

			// loop over each key=value pair in the clause
			for (loc.key in arguments.args) {
				
				// FIXME: (1) railo seems to keep these arguments around
				if (ListFindNoCase("$clause,$params", loc.key))
					continue;
				
				// use an IN if value is an array
				if (IsArray(arguments.args[loc.key])) {
					loc.clause = sqlBinaryOp(sqlColumn(column=loc.key), "IN", sqlParam(column=loc.key));
					ArrayAppend(loc.cacheClause, "#loc.key# IN ?");
					
				// use an equality check if value is simple
				} else if (IsSimpleValue(arguments.args[loc.key])) {
					loc.clause = sqlBinaryOp(sqlColumn(column=loc.key), "=", sqlParam(column=loc.key));
					ArrayAppend(loc.cacheClause, "#loc.key# = ?");
					
				// throw an error otherwise
				} else {
					throwException("Invalid parameter to #UCase(arguments.clause)# clause. Only arrays and simple values may be used.");
				}

				// append parameters to the relation
				ArrayAppend(this.params[arguments.scope], arguments.args[loc.key]);
				
				// FIXME: (2) note that we found a good value
				loc.success = true;
					
				// append clause to correct scope
				ArrayAppend(this.sql[arguments.scope], _transformInput(loc.clause, arguments.clause));

				// blank out named argument for caching purposes
				arguments.args[loc.key] = "";
			}
		
			// store signature with a hypothetical conditional clause, as if we weren't using key=value params
			if (variables.cacheSql)
				appendSignature(arguments.clause, {$clause=ArrayToList(loc.cacheClause, " AND ")});
			
			// FIXME: (3) throw an error if a good value was not found
			if (NOT StructKeyExists(loc, "success"))
				throwException(message="Relation requires arguments for #UCase(arguments.clause)#");
		}
	</cfscript>
</cffunction>

<cffunction name="_transformInput" returntype="any" access="private">
	<cfargument name="obj" type="any" required="true">
	<cfargument name="clause" type="string" default="SELECT">
	<cfscript>
		// parse simple values with parser
		if (IsSimpleValue(arguments.obj))
			return parse(arguments.obj, arguments.clause);

		// nodes should pass straight through
		if (REFindNoCase("^cfrel\.nodes\.", typeOf(arguments.obj)) GT 0)
			return arguments.obj;
			
		// throw error if we haven't found it yet
		throwException("Invalid object type passed into #UCase(arguments.clause)#");
	</cfscript>
</cffunction>
