<cffunction name="toSql" returntype="string" access="public" hint="Convert relational data into a SQL string">
	<cfargument name="interpolateParams" type="boolean" default="false" />
	<cfreturn sqlArrayToString(toSqlArray(), arguments.interpolateParams) />
</cffunction>

<cffunction name="toSqlArray" returntype="array" access="public" hint="Convert relational data into flat SQL array">
	<cfscript>
		if (variables.cacheSql) {
			var signature = this.buildSignature;

			var sqlInCache = inCache("sql", signature);
			var sql = sqlInCache ? loadCache("sql", signature) : visitor().visit(obj=this, map=getMap());

			if (NOT sqlInCache)
				saveCache("sql", signature, sql);

		} else {
			var sql = visitor().visit(obj=this, map=getMap());
		}

		return sql;
	</cfscript>
</cffunction>

<cffunction name="getParameters" returntype="array" access="public" hint="Return array of all parameters used in query and subqueries">
	<cfargument name="stack" type="array" default="#ArrayNew(1)#" />
	<cfscript>
		var loc = {};

		// stack on parameters from subqueries
		loc.iEnd = ArrayLen(this.sql.froms);
		for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
			if (typeOf(this.sql.froms[loc.i]) EQ "cfrel.nodes.SubQuery")
				arguments.stack = this.sql.froms[loc.i].subject.getParameters(arguments.stack);

		// stack on parameters from join subqueries
		loc.iEnd = ArrayLen(this.sql.joins);
		for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
			if (typeOf(this.sql.joins[loc.i]) EQ "cfrel.nodes.join" AND typeOf(this.sql.joins[loc.i].table) EQ "cfrel.nodes.SubQuery")
				arguments.stack = this.sql.joins[loc.i].table.subject.getParameters(arguments.stack);

		// stack on join parameters
		ArrayAppend(arguments.stack, this.params.joins, true);

		// stack on where parameters
		ArrayAppend(arguments.stack, this.params.wheres, true);

		// stack on having parameters
		ArrayAppend(arguments.stack, this.params.havings, true);

		return arguments.stack;
	</cfscript>
</cffunction>

<cffunction name="exec" returntype="struct" access="public" hint="Run query() but return the relation">
	<cfargument name="callbacks" type="boolean" default="true" />
	<cfscript>
		this.query(argumentCollection=arguments);
		return this;
	</cfscript>
</cffunction>

<cffunction name="reload" returntype="struct" access="public" hint="Execute again to reload dataset">
	<cfargument name="callbacks" type="boolean" default="true" />
	<cfscript>
		variables.executed = false;
		return this.exec(argumentCollection=arguments);
	</cfscript>
</cffunction>

<cffunction name="query" returntype="query" access="public" hint="Lazily execute and return query object">
	<cfargument name="callbacks" type="boolean" default="true" />
	<cfargument name="allowSpecialPaging" type="boolean" default="false" />
	<cfscript>
		var loc = {};
				
		// run before find callbacks on relation
		if (arguments.callbacks)
			mapper().beforeFind(this);
		
		// drop into query logic if we don't have a query yet
		if (variables.executed EQ false OR NOT StructKeyExists(variables.cache, "query")) {
			clearCache();
			
			// do some special handling for paged SqlServer queries with aggregates
			if (arguments.allowSpecialPaging AND variables.visitorClass EQ "SqlServer" AND variables.paged AND ArrayLen(this.sql.groups)) {
				
				// get values for rows that don't use aggregates
				loc.valueRel = minimizedRelation();
				loc.valueQuery = loc.valueRel.query(false, false);
				
				// create a new clone without pagination
				loc.dataRel = clone().clearPagination();
				
				// loop over items that were in last select
				loc.iEnd = ArrayLen(loc.valueRel.sql.select);
				for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
					
					// get key + value list for 
					loc.item = loc.valueRel.sql.select[loc.i];
					loc.key = loc.item.alias;
					loc.keyValues = ListToArray(Evaluate("ValueList(loc.valueQuery.#loc.key#, Chr(7))"), Chr(7));
					
					// add new where clause entries for IN statements
					loc.dataRel.where(sqlBinaryOp(left=loc.item, op='IN', right='(?)'), [loc.keyValues]);
				}
				
				// save objects into current relation
				variables.cache.query = loc.dataRel.query(arguments.callbacks, false);
				variables.cache.result = loc.dataRel.result();
			
			} else {
				
				// set up arguments for query execution
				loc.queryArgs = {};
				loc.queryArgs.sql = this.toSqlArray();
				
				// use max rows if specified
				if (this.maxRows GT 0)
					loc.queryArgs.maxRows = this.maxRows;
				
				// if we are using query of a query, set dbtype and resultsets
				if (variables.qoq) {
					loc.queryArgs.dbType = "query";
					loc.iEnd = ArrayLen(this.sql.froms);
					for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
						loc.queryArgs["query" & loc.i] = this.sql.froms[loc.i].subject;
					}
					
				} else {
			
					// set up a datasource
					if (Len(this.datasource) EQ 0)
						throwException("Cannot execute query without a datasource");
					loc.queryArgs.datasource = this.datasource;
				}
				
				// execute query using a wrapper
				$executeQuery(argumentCollection=loc.queryArgs);
				
				// run after find callbacks on query
				if (arguments.callbacks AND this.model NEQ false)
					mapper().afterFind(this.model, variables.cache.query);
				
				// set up looping counter
				variables.currentRow = 0;
			}
			
			// build pagination data
			// todo: lazy loading?
			if (variables.paged) {
				variables.paginationData = {
					currentPage = (this.sql.offset / this.sql.limit) + 1,
					perPage = this.sql.limit
				};
			}
			
			// change state
			variables.executed = true;
		}
		
		return variables.cache.query;
	</cfscript>
</cffunction>

<cffunction name="result" returntype="struct" access="public" hint="Return result object generated by query()">
	<cfscript>
		if (variables.executed EQ false OR NOT StructKeyExists(variables.cache, "result"))
			this.query();
		return variables.cache.result;
	</cfscript>
</cffunction>

<cffunction name="pagination" returntype="struct" access="public" hint="Return structure describing pagination state">
	<cfscript>
		if (variables.paged EQ false OR NOT IsStruct(variables.paginationData))
			return false;
		return variables.paginationData;
	</cfscript>
</cffunction>

<cffunction name="$executeQuery" returntype="void" access="private" hint="Execute a cfquery with parameters">
	<cfargument name="sql" type="array" required="true" hint="Flat array of statements to execute" />
	<cfscript>
		var loc = {};
		loc.sql = arguments.sql;
		StructDelete(arguments, "sql");
		loc.params = getParameters();
		loc.paramCounter = 1;
	</cfscript>
	<cfquery name="variables.cache.query" result="variables.cache.result" attributeCollection="#arguments#">
		<cfloop array="#loc.sql#" index="loc.fragment"><cfif IsStruct(loc.fragment)><cfif StructKeyExists(loc.fragment, "value")><cfqueryparam attributeCollection="#$paramArguments(loc.fragment)#" /><cfelse><cfqueryparam attributeCollection="#$paramArguments(loc.fragment, loc.params[loc.paramCounter++])#" /></cfif><cfelse> #PreserveSingleQuotes(loc.fragment)# </cfif></cfloop>
	</cfquery>
</cffunction>

<cffunction name="$paramArguments" returntype="struct" access="private" hint="Add important options to cfqueryparam arguments">
	<cfargument name="param" type="struct" required="true" />
	<cfargument name="value" type="any" required="false" />
	<cfscript>
		var loc = {};
		loc.param = Duplicate(arguments.param);

		// assign value to param if it was passed in
		if (StructKeyExists(arguments, "value"))
			loc.param.value = arguments.value;

		// if no type has been set, default to a string
		if (NOT StructKeyExists(loc.param, "cfsqltype"))
			loc.param.cfsqltype = "cf_sql_char";
					
		
		// if value is an array, set up list params
		if (IsArray(loc.param.value)) {
			loc.param.null = ArrayLen(loc.param.value) EQ 0;
			loc.param.value = ArrayToList(loc.param.value, Chr(7));
			loc.param.list = true;
			loc.param.separator = Chr(7);

		// if value is simple and empty, then pass it as an empty string
		} else if (Len(loc.param.value) EQ 0) {
			loc.param.cfsqltype = "cf_sql_char";
		}

		return loc.param;
	</cfscript>
</cffunction>
