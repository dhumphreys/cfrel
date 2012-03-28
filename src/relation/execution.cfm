<cffunction name="toSql" returntype="string" access="public" hint="Convert relational data into a SQL string">
	<cfargument name="interpolateParams" type="boolean" default="false" />
	<cfscript>
		var loc = {};
		
		// run mappings before converting to SQL
		_applyMappings();
		
		// convert relation into SQL
		loc.sql = this.visitor.visit(this);
		
		// if necessary, replace placeholders with parameter values
		if (arguments.interpolateParams) {
			
			// loop over params and types to interpolate them
			loc.parameters = getParameters();
			loc.parameterColumnTypes = getParameterColumnTypes();
			loc.iEnd = ArrayLen(loc.parameters);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
				loc.value = Duplicate(loc.parameters[loc.i]);
				
				// determine if we should wrap the parameter in quotes
				loc.quoted = NOT REFindNoCase("^cf_sql_((big|tiny|small)?int|float|numeric|decimal|double|real|bit|money*)$", loc.parameterColumnTypes[loc.i]);
				
				// see if param is an array
				if (IsArray(loc.value)) {
					loc.jEnd = ArrayLen(loc.value);
					
					// if there is an empty array, set the value to NULL
					if (loc.jEnd EQ 0) {
						loc.value = "NULL";
					} else {
						
						// quote each array value if necessary
						if (loc.quoted)
							for (loc.j = 1; loc.j LTE loc.jEnd; loc.j++)
								loc.value[loc.j] = "'#loc.value[loc.j]#'";
						
						// turn array into a list
						loc.value = ArrayToList(loc.value, ", ");
					}
				
				// quote scalar values
				} else if (loc.quoted) {
					loc.value = "'#loc.value#'";
				};
				
				// replace the next non-quoted question mark with the value
				loc.sql = REReplace(loc.sql, "(^[^'\?]*(?:'[^']*'[^'\?]*)*)*\?", "\1#loc.value#");
			}
		}
		
		// return the raw sql statement
		return loc.sql;
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

<cffunction name="$query" returntype="query" access="public" hint="Lazily execute and return query object">
	<cfargument name="callbacks" type="boolean" default="true" />
	<cfargument name="allowSpecialPaging" type="boolean" default="false" />
	<cfscript>
		var loc = {};
				
		// run before find callbacks on relation
		if (arguments.callbacks)
			this.mapper.beforeFind(this);
		
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
				
				// create the new query object
				loc.query = new query();
				
				// generate SQL for query
				loc.sql = this.toSql();
				
				// use max rows if specified
				if (this.maxRows GT 0)
					loc.query.setMaxRows(this.maxRows);
				
				// if we are using query of a query, set dbtype and resultset
				if (variables.qoq) {
					loc.queryArgs = {};
					loc.iEnd = ArrayLen(this.sql.froms);
					for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
						loc.queryArgs["query" & loc.i] = this.sql.froms[loc.i];
					loc.query.setAttributes(dbType="query", argumentCollection=loc.queryArgs);
					
				} else {
			
					// set up a datasource
					if (Len(this.datasource) EQ 0)
						throwException("Cannot execute query without a datasource");
					loc.query.setDatasource(this.datasource);
				}
				
				// stack on parameters
				loc.parameters = getParameters();
				loc.parameterColumnTypes = getParameterColumnTypes();
				loc.iEnd = ArrayLen(loc.parameters);
				for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
					
					// see if param is an array
					loc.paramIsList = IsArray(loc.parameters[loc.i]);
					
					// see if param should be NULL
					loc.paramIsNull = (loc.paramIsList AND ArrayLen(loc.parameters[loc.i]) EQ 0);
					
					// add parameter, converting to list if necessary
					loc.paramValue = loc.paramIsList ? ArrayToList(loc.parameters[loc.i], Chr(7)) : loc.parameters[loc.i];
					loc.query.addParam(value=loc.paramValue, cfsqltype=loc.parameterColumnTypes[loc.i], list=loc.paramIsList, null=loc.paramIsNull, separator=Chr(7));
				}
				
				// execute query
				loc.result = loc.query.execute(sql=loc.sql);
				
				// save objects
				variables.cache.query = loc.result.getResult();
				variables.cache.result = loc.result.getPrefix();
				
				// run after find callbacks on query
				if (arguments.callbacks AND IsObject(this.model))
					this.mapper.afterFind(this.model, variables.cache.query);
				
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
		
			// call the mapper to cache data as needed
			this.mapper.cacheData(this, variables.cache.query, variables.cache.result);
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
