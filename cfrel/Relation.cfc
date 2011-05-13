<cfcomponent output="false">
	<cfinclude template="functions.cfm" />
	
	<cffunction name="init" returntype="struct" access="public" hint="Constructor">
		<cfargument name="datasource" type="string" default="" />
		<cfargument name="visitor" type="string" default="Sql" />
		<cfargument name="mapper" type="string" default="Mapper" />
		<cfargument name="cache" type="string" default="" />
		<cfargument name="cacheParse" type="boolean" default="#ListFindNoCase(arguments.cache, 'parse')#" />
		<cfscript>
			
			// store classes used for mapper and visitor
			variables.mapperClass = arguments.mapper;
			variables.visitorClass = arguments.visitor;
			
			// datasource and visitor to use
			this.datasource = arguments.datasource;
			this.visitor = CreateObject("component", addCfcPrefix("cfrel.visitors.#arguments.visitor#")).init();
			this.mapper = CreateObject("component", addCfcPrefix("cfrel.mappers.#arguments.mapper#")).init();
			
			// internal parser
			variables.parser = CreateObject("component", addCfcPrefix("cfrel.Parser")).init(cache=arguments.cacheParse);
			
			// struct to hold SQL tree
			this.sql = {
				select = [],
				selectFlags = [],
				joins = [],
				joinParameters = [],
				joinParameterColumns = [],
				wheres = [],
				whereParameters = [],
				whereParameterColumns = [],
				groups = [],
				havings = [],
				havingParameters = [],
				havingParameterColumns = [],
				orders = []
			};
			
			// set up max rows for cfquery tag
			this.maxRows = 0;
			
			// internal control and value variables
			variables.query = false;
			variables.result = false;
			variables.executed = false;
			variables.mapped = false;
			variables.qoq = false;
			variables.paged = false;
			variables.paginationData = false;
			
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="new" returntype="struct" access="public" hint="Create new instance of relation">
		<cfscript>
			return relation(argumentCollection=arguments);
		</cfscript>
	</cffunction>
	
	<cffunction name="clone" returntype="struct" access="public" hint="Duplicate the relation object">
		<cfscript>
			var loc = {};
			
			// duplicate object and sql
			loc.rel = Duplicate(this);
			loc.rel.executed = false;
			
			// remove query values that should not be kept in new instance
			if (variables.executed EQ true OR IsObject(variables.query)) {
				loc.private = injectInspector(loc.rel)._inspect();
				loc.private.query = false;
				loc.private.result = false;
				loc.private.executed = false;
				loc.private.mapped = false;
			}
			
			// remove pagination variables
			if (variables.paged EQ true) {
				loc.private = injectInspector(loc.rel)._inspect();
				loc.private.paginationData = false;
			}
			
			return loc.rel;
		</cfscript>
	</cffunction>
	
	<cffunction name="select" returntype="struct" access="public" hint="Append to the SELECT clause of the relation">
		<cfscript>
			if (variables.executed)
				return this.clone().select(argumentCollection=arguments);
				
			_appendFieldsToClause("SELECT", "select", arguments);
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="distinct" returntype="struct" access="public" hint="Set DISTINCT flag for SELECT">
		<cfscript>
			if (variables.executed)
				return this.clone().distinct(argumentCollection=arguments);
				
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
			
			// make decision based on argument type
			switch(typeOf(arguments.target)) {
				
				// accept relations, models, and stings
				case "cfrel.Relation":
					this.sql.from = arguments.target;
					break;
				
				// accept model and add model to mapping
				case "model":
					this.sql.from = sqlTable(model=arguments.target);
					this.mapper.buildMapping(this.sql.from, this);
					break;
					
				case "simple":
					this.sql.from = sqlTable(arguments.target);
					break;
				
				// accept queries for QoQ operations
				case "query":
					this.sql.from = arguments.target;
					variables.qoq = true;
					break;
					
				// and reject all others by throwing an error
				default:
					throwException("Only a table name or another relation can be in FROM clause");
			}
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="include" returntype="struct" access="public" hint="Add a JOIN to the relation using predefined relationships">
		<cfargument name="include" type="string" required="true" />
		<cfscript>
			var loc = {};
			if (variables.executed)
				return this.clone().include(argumentCollection=arguments);
				
			// make sure a from has been specified
			if (NOT StructKeyExists(this.sql, "from"))
				throwException("Includes cannot be specified before FROM clause");
				
			// let mapper do the work with includes
			this.mapper.mapIncludes(this, arguments.include);
				
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="join" returntype="struct" access="public" hint="Add a JOIN to the relation">
		<cfargument name="target" type="any" required="true" />
		<cfargument name="condition" type="any" default="false" />
		<cfargument name="params" type="array" default="#[]#" />
		<cfargument name="type" type="string" default="inner" hint="INNER or OUTER join" />
		<cfargument name="$skipMapping" type="boolean" default="false" />
		<cfscript>
			var loc = {};
			if (variables.executed)
				return this.clone().join(argumentCollection=arguments);
				
			// correctly set condition of join
			if (typeOf(arguments.condition) NEQ "simple") {
				loc.condition = arguments.condition;
			} else if (arguments.condition NEQ false) {
				loc.condition = variables.parser.parse(arguments.condition);
				loc.parameterColumns = variables.parser.getParameterColumns();
			} else {
				loc.condition = false;
			}
				
			// create table object
			switch(typeOf(arguments.target)) {
				
				// assume simple values are names
				case "simple":
					loc.table = sqlTable(table=arguments.target);
					break;
					
				// add a model to a new table object
				case "model":
					loc.table = sqlTable(model=arguments.target);
					
					// map the models using the mapper
					if (NOT arguments.$skipMapping)
						this.mapper.buildMapping(loc.table, this);
					break;
					
				// just use raw table object
				case "cfrel.nodes.table":
					loc.table = arguments.target;
					break;
					
				// throw error if invalid target
				default:
					throwException("Only table names or table nodes can be target of JOIN");
					
			}
			
			// append join to sql structure
			ArrayAppend(this.sql.joins, sqlJoin(loc.table, loc.condition, arguments.type));
			
			// handle parameters for join
			loc.iEnd = ArrayLen(arguments.params);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
				ArrayAppend(this.sql.joinParameters, arguments.params[loc.i]);
				
				// if we did not get parameter columns, we still need to account for this parameter
				if (NOT StructKeyExists(loc, "parameterColumns"))
					ArrayAppend(this.sql.joinParameterColumns, "");
			}
			
			// append parameter column mappings
			if (StructKeyExists(loc, "parameterColumns")) {
				loc.iEnd = ArrayLen(loc.parameterColumns);
				for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
					ArrayAppend(this.sql.joinParameterColumns, loc.parameterColumns[loc.i]);
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
				
			_appendConditionsToClause("WHERE", "wheres", "whereParameters", "whereParameterColumns", arguments);
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="group" returntype="struct" access="public" hint="Append to GROUP BY clause of the relation">
		<cfscript>
			if (variables.executed)
				return this.clone().group(argumentCollection=arguments);
				
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
				
			_appendConditionsToClause("HAVING", "havings", "havingParameters", "havingParameterColumns", arguments);
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="order" returntype="struct" access="public" hint="Append to ORDER BY clause of the relation">
		<cfscript>
			if (variables.executed)
				return this.clone().order(argumentCollection=arguments);
				
			_appendFieldsToClause("ORDER BY", "orders", arguments);
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="limit" returntype="struct" access="public" hint="Restrict the number of records when querying">
		<cfargument name="value" type="numeric" required="true" />
		<cfscript>
			if (variables.executed)
				return this.clone().limit(argumentCollection=arguments);
				
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
				
			this.sql.offset = Int(arguments.value);
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="paginate" returntype="struct" access="public" hint="Calculate LIMIT and OFFSET with page number and per-page constraint">
		<cfargument name="page" type="numeric" required="true" />
		<cfargument name="perPage" type="numeric" required="true" />
		<cfscript>
			if (variables.executed)
				return this.clone().paginate(argumentCollection=arguments);
			
			// throw error if bad values are passed
			if (arguments.page LT 1 OR arguments.perPage LT 1)
				throwException("Page and per-page must be greater than zero");
			
			// calculate limit and offset
			this.sql.limit = Int(arguments.perPage);
			this.sql.offset = (Int(arguments.page) - 1) * this.sql.limit;
			
			// set variable showing this is paged
			variables.paged = true;
			
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="clearPagination" returntype="struct" access="public" hint="Remove all limits, offsets, and pagination from the current relation">
		<cfscript>
			if (variables.executed)
				return this.clone().clearPagination(argumentCollection=arguments);
			
			// remove limits and offsets
			if (StructKeyExists(this.sql, "limit"))
				StructDelete(this.sql, "limit");
			if (StructKeyExists(this.sql, "offset"))
				StructDelete(this.sql, "offset");
			
			// reset max rows variable
			this.maxRows = 0;
			
			// unset variable showing this is paged
			variables.paged = false;
			
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="minimizedRelation" returntype="struct" access="public" hint="Return a new relation without aggregate selects">
		<cfscript>
			var loc = {};
			
			// run mappings before we clone
			_applyMappings();
			
			// clone query
			loc.rel = this.clone();
			
			// eliminate aggregates from count if using GROUP BY
			if (ArrayLen(this.sql.groups) GT 0) {
					
				// make query distinct
				loc.rel.distinct();
				
				// use GROUP BY as SELECT
				loc.rel.sql.select = Duplicate(loc.rel.sql.groups);
			}
			
			// make sure select columns have aliases
			loc.iEnd = ArrayLen(loc.rel.sql.select);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
				if (ListFindNoCase("Column,Alias,Literal,Wildcard", ListLast(typeOf(loc.rel.sql.select[loc.i]), ".")) EQ 0)
					loc.rel.sql.select[loc.i] = sqlAlias(subject=loc.rel.sql.select[loc.i], alias="countColumn#loc.i#");
					
			return loc.rel;
		</cfscript>
	</cffunction>
	
	<cffunction name="countRelation" returntype="struct" access="public" hint="Create relation to calculate number of records that would be returned if pagination was not used">
		<cfscript>
			var loc = {};
			
			// get back a relation with only columns needed
			loc.rel = this.minimizedRelation();
			
			// remove order by and paging since we just care about count
			loc.rel.sql.orders = [];
			if (variables.paged) {
				loc.private = injectInspector(loc.rel)._inspect();
				loc.private.paged = false;
				StructDelete(loc.rel.sql, "limit");
				StructDelete(loc.rel.sql, "offset");
			}
					
			// create new relation to contain subquery
			loc.rel2 = relation(datasource=this.datasource, mapper=variables.mapperClass, visitor=variables.visitorClass);
			loc.rel2.select(sqlLiteral("COUNT(*) AS numberOfRows"));
			loc.rel2.from(loc.rel);
			
			return loc.rel2;
		</cfscript>
	</cffunction>
	
	<cffunction name="countTotalRecords" returntype="numeric" access="public" hint="Calculate number of records that would be returned if pagination was not used">
		<cfreturn this.countRelation().query().numberOfRows />
	</cffunction>
	
	<cffunction name="toSql" returntype="string" access="public" hint="Convert relational data into a SQL string">
		<cfscript>
			if (ArrayLen(this.sql.select) EQ 0)
				ArrayAppend(this.sql.select, sqlWildcard());
			
			// run mappings before converting to SQL
			_applyMappings();
			
			return this.visitor.visit(this);
		</cfscript>
	</cffunction>
	
	<cffunction name="exec" returntype="struct" access="public" hint="Run query() but return the relation">
		<cfscript>
			this.query();
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="reload" returntype="struct" access="public" hint="Execute again to reload dataset">
		<cfscript>
			variables.executed = false;
			return this.exec();
		</cfscript>
	</cffunction>
	
	<cffunction name="qoq" returntype="struct" access="public" hint="Return a QoQ relation with the current recordset as the FROM">
		<cfreturn this.new().from(this.query()) />
	</cffunction>
	
	<cffunction name="query" returntype="query" access="public" hint="Lazily execute and return query object">
		<cfargument name="allowSpecialPaging" type="boolean" default="true" />
		<cfscript>
			var loc = {};
			
			// drop into query logic if we don't have a query yet
			if (variables.executed EQ false OR NOT IsQuery(variables.query)) {
				
				// do some special handling for paged SqlServer queries with aggregates
				if (arguments.allowSpecialPaging AND variables.visitorClass EQ "SqlServer" AND variables.paged AND ArrayLen(this.sql.groups)) {
					
					// get values for rows that don't use aggregates
					loc.valueRel = minimizedRelation();
					loc.valueQuery = loc.valueRel.query(false);
					
					// create a new clone without pagination, but leave LIMIT alone
					loc.dataRel = injectInspector(clone());
					StructDelete(loc.dataRel.sql, "limit");
					StructDelete(loc.dataRel.sql, "offset");
					loc.dataRelPrivate = loc.dataRel._inspect();
					loc.dataRelPrivate.paged = false;
					
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
					variables.query = loc.dataRel.query(false);
					variables.result = loc.dataRel.result();
				
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
						loc.query.setAttributes(dbType="query", resultSet=this.sql.from);
						
					} else {
				
						// set up a datasource
						if (Len(this.datasource) EQ 0)
							throwException("Cannot execute query without a datasource");
						loc.query.setDatasource(this.datasource);
					}
					
					// stack on parameters
					loc.parameters = getParameters();
					loc.parameterColumns = getParameterColumns();
					loc.iEnd = ArrayLen(loc.parameters);
					for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
						
						// see if param is an array
						loc.paramIsList = IsArray(loc.parameters[loc.i]);
						
						// see if param should be NULL
						loc.paramIsNull = (loc.paramIsList AND ArrayLen(loc.parameters[loc.i]) EQ 0);
						
						// find type based on column name
						if (variables.qoq)
							loc.paramType = _queryColumnDataType(loc.parameterColumns[loc.i]);
						else
							loc.paramType = this.mapper.columnDataType(loc.parameterColumns[loc.i]);
						
						// add parameter, converting to list if necessary
						loc.paramValue = loc.paramIsList ? ArrayToList(loc.parameters[loc.i], Chr(7)) : loc.parameters[loc.i];
						loc.query.addParam(value=loc.paramValue, cfsqltype=loc.paramType, list=loc.paramIsList, null=loc.paramIsNull, separator=Chr(7));
					}
						
					// execute query
					loc.result = loc.query.execute(sql=loc.sql);
					
					// save objects
					variables.query = loc.result.getResult();
					variables.result = loc.result.getPrefix();
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
			
			return variables.query;
		</cfscript>
	</cffunction>
	
	<cffunction name="result" returntype="struct" access="public" hint="Return result object generated by query()">
		<cfscript>
			if (variables.executed EQ false OR NOT IsStruct(variables.result))
				this.query();
			return variables.result;
		</cfscript>
	</cffunction>
	
	<cffunction name="pagination" returntype="struct" access="public" hint="Return structure describing pagination state">
		<cfscript>
			if (variables.paged EQ false OR NOT IsStruct(variables.paginationData))
				return false;
			return variables.paginationData;
		</cfscript>
	</cffunction>
	
	<cffunction name="getModels" returntype="array" access="public" hint="Return array of all models involved in query">
		<cfargument name="stack" type="array" default="#[]#" />
		<cfscript>
			var loc = {};
			
			// add model from FROM clause
			if (StructKeyExists(this.sql, "from")) {
				loc.fromType = typeOf(this.sql.from);
				if (loc.fromType EQ "cfrel.Relation")
					arguments.stack = this.sql.from.getModels(arguments.stack);
				else if (loc.fromType EQ "cfrel.nodes.Table" AND IsObject(this.sql.from.model))
					ArrayAppend(arguments.stack, this.sql.from);
			}
				
			// add models from JOIN clauses
			loc.iEnd = ArrayLen(this.sql.joins);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
				if (IsObject(this.sql.joins[loc.i].table.model))
					ArrayAppend(arguments.stack, this.sql.joins[loc.i].table);
			
			return arguments.stack;
		</cfscript>
	</cffunction>
	
	<cffunction name="getParameters" returntype="array" access="public" hint="Return array of all parameters used in query and subqueries">
		<cfargument name="stack" type="array" default="#[]#" />
		<cfscript>
			var loc = {};
				
			// stack on parameters from subquery
			if (StructKeyExists(this.sql, "from") AND typeOf(this.sql.from) EQ "cfrel.Relation")
				arguments.stack = this.sql.from.getParameters(arguments.stack);
				
			// stack on join parameters
			loc.iEnd = ArrayLen(this.sql.joinParameters);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
				ArrayAppend(arguments.stack, this.sql.joinParameters[loc.i]);
			
			// stack on where parameters
			loc.iEnd = ArrayLen(this.sql.whereParameters);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
				ArrayAppend(arguments.stack, this.sql.whereParameters[loc.i]);
			
			// stack on having parameters
			loc.iEnd = ArrayLen(this.sql.havingParameters);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
				ArrayAppend(arguments.stack, this.sql.havingParameters[loc.i]);
				
			return arguments.stack;
		</cfscript>
	</cffunction>
	
	<cffunction name="getParameterColumns" returntype="array" access="public" hint="Return array of all columns referenced by parameters">
		<cfargument name="stack" type="array" default="#[]#" />
		<cfscript>
			var loc = {};
				
			// stack on parameters columns from subquery
			if (StructKeyExists(this.sql, "from") AND typeOf(this.sql.from) EQ "cfrel.Relation")
				arguments.stack = this.sql.from.getParameterColumns(arguments.stack);
				
			// stack on join parameter columns
			loc.iEnd = ArrayLen(this.sql.joinParameterColumns);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
				ArrayAppend(arguments.stack, this.sql.joinParameterColumns[loc.i]);
			
			// stack on where parameter columns
			loc.iEnd = ArrayLen(this.sql.whereParameterColumns);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
				ArrayAppend(arguments.stack, this.sql.whereParameterColumns[loc.i]);
			
			// stack on having parameter columns
			loc.iEnd = ArrayLen(this.sql.havingParameterColumns);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
				ArrayAppend(arguments.stack, this.sql.havingParameterColumns[loc.i]);
				
			return arguments.stack;
		</cfscript>
	</cffunction>
	
	<!---------------------
	--- Private Methods ---
	---------------------->
	
	<cffunction name="_applyMappings" returntype="void" access="public" hint="Use Mapper to map model columns to database columns">
		<cfscript>
			if (NOT variables.mapped) {
				if (typeOf(this.sql.from) EQ "cfrel.Relation")
					this.sql.from._applyMappings();
				this.mapper.mapObject(this);
				variables.mapped = true;
			}
		</cfscript>
	</cffunction>
	
	<cffunction name="_appendFieldsToClause" returntype="void" access="private" hint="Take either lists or name/value pairs and append to an array">
		<cfargument name="clause" type="string" required="true" />
		<cfargument name="scope" type="string" required="true" />
		<cfargument name="args" type="struct" required="true" />
		<cfscript>
			var loc = {};
			loc.iEnd = StructCount(arguments.args);
			
			// do not allow empty call
			if (loc.iEnd EQ 0) {
				throwException("Arguments are required in #UCase(arguments.clause)#");
				
			} else {
			
				// loop over all arguments
				for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
					loc.value = _transformInput(arguments.args[loc.i], arguments.clause);
					
					if (IsStruct(loc.value)) {
						ArrayAppend(this.sql[arguments.scope], loc.value);
					} else if (IsArray(loc.value)) {
						loc.jEnd = ArrayLen(loc.value);
						for (loc.j = 1; loc.j LTE loc.jEnd; loc.j++)
							ArrayAppend(this.sql[arguments.scope], loc.value[loc.j]);
					} else {
						throwException("Unknown return from parser in #UCase(arguments.clause)#");
					}
				}
			}
		</cfscript>
	</cffunction>
	
	<cffunction name="_appendConditionsToClause" returntype="void" access="private" hint="Take conditions and parameters and append to arrays">
		<cfargument name="clause" type="string" required="true" />
		<cfargument name="scope" type="string" required="true" />
		<cfargument name="parameterScope" type="string" required="true" />
		<cfargument name="parameterColumnScope" type="string" required="true" />
		<cfargument name="args" type="struct" required="true" />
		<cfscript>
			var loc = {};
			
			// get count of arguments
			loc.argumentCount = StructCount(arguments.args);
			
			// if arguments are empty
			if (loc.argumentCount EQ 0) {
				throwException(message="Relation requires arguments for #UCase(arguments.clause)#");
				
			// if a text clause was passed
			} else if (StructKeyExists(arguments.args, "$clause")) {
						
				// get data type of clause
				loc.type = typeOf(arguments.args.$clause);
				
				// get count of parameters passed in
				loc.parameterCount = iif(StructKeyExists(arguments.args, "$params"), "ArrayLen(arguments.args.$params)", DE(0));
					
				// go ahead and confirm parameter count unless clause is literal
				if (loc.type EQ "simple") {
				
					// make sure string has length
					if (Len(arguments.args.$clause) EQ 0)
						throwException(message="#UCase(arguments.clause)# clause strings must have length > 0");
					
					// count the number of placeholders in clause and argument array
					loc.placeholderCount = Len(arguments.args.$clause) - Len(Replace(arguments.args.$clause, "?", "", "ALL"));
					
					// make sure the numbers are equal
					if (loc.placeholderCount NEQ loc.parameterCount)
						throwException(message="Parameter count does not match number of placeholders in #UCase(arguments.clause)# clause");
				}
					
				// append clause and parameters to sql options
				ArrayAppend(this.sql[arguments.scope], _transformInput(arguments.args.$clause, arguments.clause));
				for (loc.i = 1; loc.i LTE loc.parameterCount; loc.i++) {
					ArrayAppend(this.sql[arguments.parameterScope], arguments.args.$params[loc.i]);
					if (loc.type NEQ "simple")
						ArrayAppend(this.sql[arguments.parameterColumnScope], "");
				}
			
				// append parameter column mappings
				if (loc.type EQ "simple") {
					loc.parameterColumns = variables.parser.getParameterColumns();
					loc.iEnd = ArrayLen(loc.parameterColumns);
					for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
						ArrayAppend(this.sql[arguments.parameterColumnScope], loc.parameterColumns[loc.i]);
				}
				
			} else {
				
				// loop over parameters
				for (loc.key in arguments.args) {
					
					// FIXME: (1) railo seems to keep these arguments around
					if (ListFindNoCase("$clause,$params", loc.key))
						continue;
					
					// grab the value from arguments and decide its type
					loc.value = arguments.args[loc.key];
					loc.type = typeOf(loc.value);
					
					// use an IN if value is an array
					if (loc.type EQ "array")
						loc.clause = "#loc.key# IN (?)";
						
					// use an equality check if value is simple
					else if (loc.type EQ "simple")
						loc.clause = "#loc.key# = ?";
						
					// throw an error otherwise
					else
						throwException("Invalid parameter to #UCase(arguments.clause)# clause. Only arrays and simple values may be used.");
					
					// FIXME: (2) note that we found a good value
					loc.success = true;
						
					// append clause and parameters
					ArrayAppend(this.sql[arguments.scope], _transformInput(loc.clause, arguments.clause));
					ArrayAppend(this.sql[arguments.parameterScope], loc.value);
					ArrayAppend(this.sql[arguments.parameterColumnScope], loc.key);
				}
				
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
			var loc = {};
			loc.type = typeOf(arguments.obj);
			
			// nodes should pass straight through
			if (REFindNoCase("^cfrel\.nodes\.", loc.type) GT 0)
				return arguments.obj;

			// parse simple values with parser
			if (loc.type EQ "simple")
				return variables.parser.parse(arguments.obj, arguments.clause);
				
			// throw error if we havent found it yet
			throwException("Invalid object type passed into #UCase(arguments.clause)#");
		</cfscript>
	</cffunction>
	
	<cffunction name="_queryColumnDataType" returntype="string" access="private" hint="Use query properties to return datatype of column">
		<cfargument name="column" type="string" required="true" />
		<cfscript>
			var loc = {};
			
			// return default type if no qoq or column
			if (NOT variables.qoq OR arguments.column EQ "")
				return "cf_sql_char";
			
			// look at metadata for query
			loc.meta = GetMetaData(this.sql.from);
			
			// try to find correct column
			loc.iEnd = ArrayLen(loc.meta);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
				if (loc.meta[loc.i].name EQ arguments.column) {
					loc.type = ListFirst(loc.meta[loc.i].typeName, " ");
					
					// deal with type mismatches
					switch (loc.type) {
						case "datetime":
							return "cf_sql_date";
							break;
						case "int":
							return "cf_sql_integer";
							break;
						case "nchar":
							return "cf_sql_char";
							break;
						default:
							return "cf_sql_" & loc.type;
					}
				}
			}
			
			// return default type if no column match
			return "cf_sql_char";
		</cfscript>
	</cffunction>
</cfcomponent>